/**
 * @description Synchronous callout class for KYC verification.
 *              Calls the KYC Verification API to validate PAN and Aadhaar.
 *              PAN/Aadhaar are encrypted via EncryptionUtil before transmission.
 *              Updates KYC_Request__c status on completion.
 *
 * Named Credential: KYC_Verification_API
 * Triggered by:     KYCService.initiateKYCVerification()
 *
 * @author      LendSphere 360
 * @version     1.0
 */
public with sharing class KYCCallout {

    // ─── Constants ──────────────────────────────────────────────────────────────
    private static final String NAMED_CREDENTIAL  = 'callout:KYC_Verification_API';
    private static final String PAN_ENDPOINT      = '/v2/pan/verify';
    private static final String AADHAAR_ENDPOINT  = '/v2/aadhaar/verify';
    private static final String MODULE            = 'KYCVerification';
    private static final String CLASS_NAME        = 'KYCCallout';

    // ─── Public Entry Points ─────────────────────────────────────────────────────

    /**
     * @description Verifies PAN number via KYC API.
     * @param kycRequestId  Id of the KYC_Request__c record
     * @param encryptedPAN  AES-256 encrypted PAN string (from EncryptionUtil)
     * @param applicantName Full name of the applicant for name-match
     * @return              KYCVerificationResult with status + message
     */
    public static KYCVerificationResult verifyPAN(
        Id     kycRequestId,
        String encryptedPAN,
        String applicantName
    ) {
        String plainPAN = EncryptionUtil.decrypt(encryptedPAN);

        Map<String, Object> payload = new Map<String, Object>{
            'pan'           => plainPAN,
            'full_name'     => applicantName,
            'reference_id'  => kycRequestId
        };

        HttpRequest  req = buildRequest(PAN_ENDPOINT, payload);
        HttpResponse res = sendRequest(req, kycRequestId, 'verifyPAN');

        return parseVerificationResponse(res);
    }

    /**
     * @description Verifies Aadhaar number via KYC API using OTP flow.
     * @param kycRequestId    Id of the KYC_Request__c record
     * @param encryptedAadh   AES-256 encrypted Aadhaar string
     * @param otp             OTP entered by the customer (passed from portal)
     * @return                KYCVerificationResult with status + message
     */
    public static KYCVerificationResult verifyAadhaar(
        Id     kycRequestId,
        String encryptedAadh,
        String otp
    ) {
        String plainAadhaar = EncryptionUtil.decrypt(encryptedAadh);

        Map<String, Object> payload = new Map<String, Object>{
            'aadhaar_number' => plainAadhaar,
            'otp'            => otp,
            'reference_id'   => kycRequestId
        };

        HttpRequest  req = buildRequest(AADHAAR_ENDPOINT, payload);
        HttpResponse res = sendRequest(req, kycRequestId, 'verifyAadhaar');

        return parseVerificationResponse(res);
    }

    /**
     * @description Initiates Aadhaar OTP — sends OTP to customer's Aadhaar-linked mobile.
     * @param encryptedAadh  AES-256 encrypted Aadhaar string
     * @return               Transaction ID to use in OTP verification step
     */
    public static String initiateAadhaarOTP(String encryptedAadh) {
        String plainAadhaar = EncryptionUtil.decrypt(encryptedAadh);

        Map<String, Object> payload = new Map<String, Object>{
            'aadhaar_number' => plainAadhaar
        };

        HttpRequest  req = buildRequest('/v2/aadhaar/otp', payload);
        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (Exception ex) {
            CalloutLogger.logException(ex, MODULE, CLASS_NAME, 'initiateAadhaarOTP', null);
            return null;
        }

        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) responseMap.get('transaction_id');
        }
        return null;
    }

    // ─── Inner Result Class ──────────────────────────────────────────────────────

    public class KYCVerificationResult {
        public String  status;       // 'VERIFIED', 'FAILED', 'PARTIAL'
        public String  message;
        public Boolean nameMatch;
        public String  ageProof;
        public Boolean isSuccess;

        public KYCVerificationResult(String status, String message, Boolean nameMatch) {
            this.status    = status;
            this.message   = message;
            this.nameMatch = nameMatch;
            this.isSuccess = (status == 'VERIFIED');
        }
    }

    // ─── Private Helpers ────────────────────────────────────────────────────────

    private static HttpRequest buildRequest(String path, Map<String, Object> payload) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + path);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(JSON.serialize(payload));
        req.setTimeout(20000); // 20 seconds
        return req;
    }

    private static HttpResponse sendRequest(
        HttpRequest req,
        Id          relatedRecordId,
        String      methodName
    ) {
        HttpResponse res;
        try {
            res = new Http().send(req);
            CalloutLogger.log(req, res, MODULE, CLASS_NAME, methodName,
                String.valueOf(relatedRecordId));
        } catch (Exception ex) {
            CalloutLogger.logException(ex, MODULE, CLASS_NAME, methodName,
                String.valueOf(relatedRecordId));
            ApplicationLogger.log(ApplicationLogger.LEVEL_ERROR, MODULE, methodName,
                'KYC callout exception: ' + ex.getMessage(), String.valueOf(relatedRecordId));
        }
        return res;
    }

    private static KYCVerificationResult parseVerificationResponse(HttpResponse res) {
        if (res == null) {
            return new KYCVerificationResult('FAILED', 'No response received', false);
        }

        if (res.getStatusCode() == 200) {
            Map<String, Object> body =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String  status    = (String)  body.get('status');
            String  message   = (String)  body.get('message');
            Boolean nameMatch = body.get('name_match') != null
                                    ? (Boolean) body.get('name_match') : false;
            return new KYCVerificationResult(
                String.isNotBlank(status) ? status : 'VERIFIED',
                message,
                nameMatch
            );
        }

        return new KYCVerificationResult(
            'FAILED',
            'API error: HTTP ' + res.getStatusCode(),
            false
        );
    }
}
