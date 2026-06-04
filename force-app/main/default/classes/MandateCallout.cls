/**
 * @description Queueable Apex class that calls the UPI / eNACH Mandate API.
 *              Follows NPCI UPI AutoPay and eNACH mandate protocols.
 *              Uses HMAC-SHA256 signature + API Key authentication.
 *              On success, updates Mandate__c and publishes Mandate_Activated__e.
 *
 * Named Credential: UPI_Mandate_API
 * Triggered by:     MandateService.setupMandate()
 *
 * @author      LendSphere 360
 * @version     1.0
 */
public with sharing class MandateCallout implements Queueable, Database.AllowsCallouts {

    // ─── Constants ──────────────────────────────────────────────────────────────
    private static final String NAMED_CREDENTIAL  = 'callout:UPI_Mandate_API';
    private static final String UPI_ENDPOINT      = '/v1/upi/autopay/create';
    private static final String ENACH_ENDPOINT    = '/v1/enach/mandate/create';
    private static final String MODULE            = 'UPIMandate';
    private static final String CLASS_NAME        = 'MandateCallout';

    // ─── Fields ─────────────────────────────────────────────────────────────────
    private final Id mandateId;

    // ─── Constructor ────────────────────────────────────────────────────────────
    public MandateCallout(Id mandateId) {
        this.mandateId = mandateId;
    }

    // ─── Queueable Interface ────────────────────────────────────────────────────
    public void execute(QueueableContext ctx) {
        Mandate__c mandate = queryMandate();
        if (mandate == null) {
            ApplicationLogger.logError(MODULE, CLASS_NAME, 'execute',
                'Mandate record not found: ' + mandateId, mandateId);
            return;
        }

        String endpoint  = mandate.Mandate_Type__c == 'UPI' ? UPI_ENDPOINT : ENACH_ENDPOINT;
        HttpRequest  req = buildRequest(mandate, endpoint);
        HttpResponse res;

        try {
            res = new Http().send(req);
        } catch (Exception ex) {
            CalloutLogger.logException(ex, MODULE, CLASS_NAME, 'execute',
                String.valueOf(mandateId));
            updateMandateStatus(mandateId, 'Failed', null);
            return;
        }

        CalloutLogger.log(req, res, MODULE, CLASS_NAME, 'execute',
            String.valueOf(mandateId));

        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            handleSuccess(res, mandate);
        } else {
            updateMandateStatus(mandateId, 'Failed', null);
            ApplicationLogger.log(ApplicationLogger.LEVEL_ERROR, MODULE, 'execute',
                'Mandate API returned HTTP ' + res.getStatusCode(), String.valueOf(mandateId));
        }
    }

    // ─── Private Helpers ────────────────────────────────────────────────────────

    private Mandate__c queryMandate() {
        List<Mandate__c> mandates = [
            SELECT Id, Loan_Application__c, Mandate_Type__c,
                   VPA__c, Bank_Account_Masked__c, IFSC_Code__c,
                   EMI_Amount__c, Start_Date__c, End_Date__c
            FROM   Mandate__c
            WHERE  Id = :mandateId
            LIMIT  1
        ];
        return mandates.isEmpty() ? null : mandates[0];
    }

    private HttpRequest buildRequest(Mandate__c mandate, String endpointPath) {
        Map<String, Object> payload;

        if (mandate.Mandate_Type__c == 'UPI') {
            payload = new Map<String, Object>{
                'vpa'            => mandate.VPA__c,
                'amount'         => mandate.EMI_Amount__c,
                'frequency'      => 'MONTHLY',
                'start_date'     => String.valueOf(mandate.Start_Date__c),
                'end_date'       => String.valueOf(mandate.End_Date__c),
                'reference_id'   => mandate.Id,
                'purpose'        => 'EMI_REPAYMENT'
            };
        } else {
            // eNACH
            payload = new Map<String, Object>{
                'account_number' => mandate.Bank_Account_Masked__c,
                'ifsc_code'      => mandate.IFSC_Code__c,
                'amount'         => mandate.EMI_Amount__c,
                'frequency'      => 'MONTHLY',
                'start_date'     => String.valueOf(mandate.Start_Date__c),
                'end_date'       => String.valueOf(mandate.End_Date__c),
                'reference_id'   => mandate.Id,
                'scheme_code'    => 'EMI'
            };
        }

        String requestBody = JSON.serialize(payload);
        String signature   = generateHMAC(requestBody);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + endpointPath);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setHeader('X-Signature', signature);
        req.setBody(requestBody);
        req.setTimeout(30000);
        return req;
    }

    private void handleSuccess(HttpResponse res, Mandate__c mandate) {
        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        String providerRef     = (String) responseMap.get('provider_reference');
        String mandateStatus   = (String) responseMap.get('status');
        String activatedDateStr= (String) responseMap.get('activated_date');

        Date activatedDate = String.isNotBlank(activatedDateStr)
            ? Date.valueOf(activatedDateStr) : Date.today();

        // Update Mandate record
        update new Mandate__c(
            Id                   = mandateId,
            Provider_Reference__c= providerRef,
            Mandate_Status__c    = 'Active',
            Activated_Date__c    = activatedDate
        );

        // Publish platform event to trigger disbursement
        Mandate_Activated__e event = new Mandate_Activated__e(
            Loan_Application_Id__c = mandate.Loan_Application__c,
            Mandate_Id__c          = mandateId,
            Provider_Reference__c  = providerRef
        );
        EventBus.publish(event);

        ApplicationLogger.logInfo(MODULE, CLASS_NAME, 'handleSuccess',
            'Mandate activated. Provider Ref: ' + providerRef, mandateId);
    }

    /**
     * @description Generates HMAC-SHA256 signature for the request payload.
     *              Uses a secret key stored in Protected Custom Metadata.
     */
    private static String generateHMAC(String payload) {
        // In production: retrieve secret from Custom Metadata / Protected Custom Setting
        // Here we use a placeholder signing key reference
        Blob key       = Blob.valueOf('MANDATE_SIGNING_KEY_PLACEHOLDER');
        Blob data      = Blob.valueOf(payload);
        Blob hmac      = Crypto.generateMac('HmacSHA256', data, key);
        return EncodingUtil.convertToHex(hmac);
    }

    private static void updateMandateStatus(Id mandateId, String status, String providerRef) {
        update new Mandate__c(
            Id                    = mandateId,
            Mandate_Status__c     = status,
            Provider_Reference__c = providerRef
        );
    }
}
