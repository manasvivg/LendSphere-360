/**
 * @description Configurable HttpCalloutMock for all LendSphere callout tests.
 *              Set statusCode and body before calling Test.setMock().
 * @author      LendSphere 360
 */
@isTest
public class MockHttpCallout implements HttpCalloutMock {

    private Integer    statusCode;
    private String     status;
    private String     body;

    public MockHttpCallout(Integer statusCode, String status, String body) {
        this.statusCode = statusCode;
        this.status     = status;
        this.body       = body;
    }

    /** Default 200 OK with supplied body */
    public MockHttpCallout(String body) {
        this(200, 'OK', body);
    }

    public HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setStatus(status);
        res.setBody(body);
        return res;
    }

    // ─── Pre-built responses ─────────────────────────────────────────────────────

    /** 200 response simulating a successful credit bureau fetch */
    public static MockHttpCallout creditBureauSuccess() {
        return new MockHttpCallout(200, 'OK',
            '{"credit_score":720,"risk_grade":"B","bureau_reference":"CBR-12345","factors":["Low credit utilisation"]}');
    }

    /** 500 response simulating a credit bureau API failure */
    public static MockHttpCallout creditBureauError() {
        return new MockHttpCallout(500, 'Internal Server Error',
            '{"error":"Service unavailable"}');
    }

    /** 200 response simulating a successful KYC PAN verification */
    public static MockHttpCallout kycPANSuccess() {
        return new MockHttpCallout(200, 'OK',
            '{"status":"VERIFIED","message":"PAN verified successfully","name_match":true}');
    }

    /** 200 response simulating a failed KYC PAN verification */
    public static MockHttpCallout kycPANFailure() {
        return new MockHttpCallout(200, 'OK',
            '{"status":"FAILED","message":"PAN verification failed"}');
    }

    /** 200 response simulating a successful mandate setup */
    public static MockHttpCallout mandateSuccess() {
        return new MockHttpCallout(200, 'OK',
            '{"mandate_id":"MND-67890","status":"ACTIVE","provider_reference":"NPCI-REF-001"}');
    }

    /** 200 response simulating a successful core banking disbursement */
    public static MockHttpCallout coreBankingSuccess() {
        return new MockHttpCallout(200, 'OK',
            '{"transaction_id":"TXN-99999","utr_number":"UTR123456","status":"SUCCESS","loan_account_number":"LAN-001"}');
    }

    /** 422 response simulating a core banking validation error */
    public static MockHttpCallout coreBankingError() {
        return new MockHttpCallout(422, 'Unprocessable Entity',
            '{"error":"Insufficient balance","code":"422"}');
    }
}
