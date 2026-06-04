/**
 * @description Queueable Apex class that calls the Core Banking API to
 *              process loan disbursement. Uses mTLS + API Key authentication
 *              via Named Credential. Creates Disbursement__c on success and
 *              publishes Loan_Disbursed__e to trigger EMI generation.
 *
 * Named Credential: Core_Banking_API
 * Triggered by:     DisbursementService.processDisbursement()
 *
 * @author      LendSphere 360
 * @version     1.0
 */
public with sharing class CoreBankingCallout implements Queueable, Database.AllowsCallouts {

    // ─── Constants ──────────────────────────────────────────────────────────────
    private static final String NAMED_CREDENTIAL  = 'callout:Core_Banking_API';
    private static final String DISBURSE_ENDPOINT = '/api/v3/loan/disburse';
    private static final String STATUS_ENDPOINT   = '/api/v3/loan/status';
    private static final String MODULE            = 'CoreBanking';
    private static final String CLASS_NAME        = 'CoreBankingCallout';

    // ─── Fields ─────────────────────────────────────────────────────────────────
    private final Id loanApplicationId;

    // ─── Constructor ────────────────────────────────────────────────────────────
    public CoreBankingCallout(Id loanApplicationId) {
        this.loanApplicationId = loanApplicationId;
    }

    // ─── Queueable Interface ────────────────────────────────────────────────────
    public void execute(QueueableContext ctx) {
        Loan_Application__c app = queryLoanApplication();
        if (app == null) {
            ApplicationLogger.logError(MODULE, CLASS_NAME, 'execute',
                'Loan Application not found: ' + loanApplicationId, loanApplicationId);
            return;
        }

        HttpRequest  req = buildDisbursementRequest(app);
        HttpResponse res;

        try {
            res = new Http().send(req);
        } catch (Exception ex) {
            CalloutLogger.logException(ex, MODULE, CLASS_NAME, 'execute',
                String.valueOf(loanApplicationId));
            handleFailure(app, 'Callout exception: ' + ex.getMessage());
            return;
        }

        CalloutLogger.log(req, res, MODULE, CLASS_NAME, 'execute',
            String.valueOf(loanApplicationId));

        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            handleSuccess(res, app);
        } else {
            handleFailure(app, 'Core Banking API returned HTTP ' + res.getStatusCode()
                               + ': ' + res.getBody());
        }
    }

    // ─── Private Helpers ────────────────────────────────────────────────────────

    private Loan_Application__c queryLoanApplication() {
        List<Loan_Application__c> apps = [
            SELECT Id, Applicant__c, Applicant__r.Name,
                   Sanctioned_Amount__c, Interest_Rate__c, Tenure_Months__c,
                   Status__c, Loan_Product__c
            FROM   Loan_Application__c
            WHERE  Id = :loanApplicationId
            LIMIT  1
        ];
        return apps.isEmpty() ? null : apps[0];
    }

    private HttpRequest buildDisbursementRequest(Loan_Application__c app) {
        Map<String, Object> payload = new Map<String, Object>{
            'loan_reference'     => app.Id,
            'borrower_name'      => app.Applicant__r.Name,
            'disbursement_amount'=> app.Sanctioned_Amount__c,
            'interest_rate'      => app.Interest_Rate__c,
            'tenure_months'      => app.Tenure_Months__c,
            'purpose'            => 'RETAIL_LOAN',
            'request_timestamp'  => String.valueOf(Datetime.now())
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + DISBURSE_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setHeader('X-Idempotency-Key', app.Id); // Prevent double disbursement
        req.setBody(JSON.serialize(payload));
        req.setTimeout(60000); // 60 seconds — banking API can be slow
        return req;
    }

    private void handleSuccess(HttpResponse res, Loan_Application__c app) {
        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        String  utrNumber        = (String)  responseMap.get('utr_number');
        String  loanAccountNo    = (String)  responseMap.get('loan_account_number');
        String  disbDateStr      = (String)  responseMap.get('disbursement_date');
        Decimal disbursedAmount  = getDecimal(responseMap, 'disbursed_amount');

        Date disbDate = String.isNotBlank(disbDateStr)
            ? Date.valueOf(disbDateStr) : Date.today();

        // Create Disbursement record
        Disbursement__c disbursement = new Disbursement__c(
            Loan_Application__c  = loanApplicationId,
            Disbursed_Amount__c  = disbursedAmount != null
                                        ? disbursedAmount : app.Sanctioned_Amount__c,
            Disbursement_Date__c = disbDate,
            UTR_Number__c        = utrNumber,
            Loan_Account_Number__c = loanAccountNo,
            Status__c            = 'Completed'
        );
        insert disbursement;

        // Update Loan Application status
        update new Loan_Application__c(
            Id       = loanApplicationId,
            Status__c= 'Disbursed'
        );

        // Publish Loan_Disbursed__e to trigger EMI generation batch
        Loan_Disbursed__e event = new Loan_Disbursed__e(
            Loan_Application_Id__c = loanApplicationId,
            Disbursement_Id__c     = disbursement.Id,
            UTR_Number__c          = utrNumber,
            Disbursed_Amount__c    = disbursement.Disbursed_Amount__c,
            Loan_Account_Number__c = loanAccountNo
        );
        EventBus.publish(event);

        ApplicationLogger.logInfo(MODULE, CLASS_NAME, 'handleSuccess',
            'Disbursement completed. UTR: ' + utrNumber + ', Account: ' + loanAccountNo,
            loanApplicationId);
    }

    private void handleFailure(Loan_Application__c app, String reason) {
        // Create a failed Disbursement record for audit trail
        insert new Disbursement__c(
            Loan_Application__c = loanApplicationId,
            Disbursed_Amount__c = app.Sanctioned_Amount__c,
            Status__c           = 'Failed',
            Failure_Reason__c   = reason
        );

        // Revert Loan Application to Sanctioned for retry
        update new Loan_Application__c(
            Id        = loanApplicationId,
            Status__c = 'Sanctioned'
        );

        ApplicationLogger.logError(MODULE, CLASS_NAME, 'handleFailure',
            'Disbursement failed: ' + reason, loanApplicationId);
    }

    private static Decimal getDecimal(Map<String, Object> m, String key) {
        Object val = m.get(key);
        return val != null ? Decimal.valueOf(String.valueOf(val)) : null;
    }
}
