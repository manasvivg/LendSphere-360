/**
 * @description Queueable Apex class that calls the Credit Bureau REST API to
 *              fetch the applicant's credit score. On success, creates/updates
 *              Credit_Assessment__c and publishes Credit_Assessment_Completed__e.
 *
 * Named Credential: Credit_Bureau_API
 * Triggered by:     LoanApplicationService.initiateApplication()
 *
 * @author      LendSphere 360
 * @version     1.0
 */
public with sharing class CreditBureauCallout implements Queueable, Database.AllowsCallouts {

    // ─── Constants ──────────────────────────────────────────────────────────────
    private static final String NAMED_CREDENTIAL = 'callout:Credit_Bureau_API';
    private static final String ENDPOINT_PATH    = '/v1/credit-score';
    private static final String MODULE           = 'CreditBureau';
    private static final String CLASS_NAME       = 'CreditBureauCallout';

    // ─── Fields ─────────────────────────────────────────────────────────────────
    private final Id loanApplicationId;

    // ─── Constructor ────────────────────────────────────────────────────────────
    public CreditBureauCallout(Id loanApplicationId) {
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

        HttpRequest  req = buildRequest(app);
        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (Exception ex) {
            CalloutLogger.logException(ex, MODULE, CLASS_NAME, 'execute', loanApplicationId);
            ApplicationLogger.logError(MODULE, CLASS_NAME, 'execute',
                'HTTP callout exception: ' + ex.getMessage(), loanApplicationId);
            return;
        }

        CalloutLogger.log(req, res, MODULE, CLASS_NAME, 'execute', loanApplicationId);

        if (res.getStatusCode() == 200) {
            handleSuccess(res, app);
        } else {
            ApplicationLogger.logError(MODULE, CLASS_NAME, 'execute',
                'Credit Bureau API returned HTTP ' + res.getStatusCode(), loanApplicationId);
        }
    }

    // ─── Private Helpers ────────────────────────────────────────────────────────

    private Loan_Application__c queryLoanApplication() {
        List<Loan_Application__c> apps = [
            SELECT Id, Applicant__c, Applicant__r.PAN__c,
                   Loan_Amount__c, Loan_Product__c
            FROM   Loan_Application__c
            WHERE  Id = :loanApplicationId
            LIMIT  1
        ];
        return apps.isEmpty() ? null : apps[0];
    }

    private HttpRequest buildRequest(Loan_Application__c app) {
        // Build request payload — PAN is the key identifier for Bureau lookup
        Map<String, Object> payload = new Map<String, Object>{
            'pan'         => app.Applicant__r.PAN__c,
            'loan_amount' => app.Loan_Amount__c,
            'reference'   => app.Id
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + ENDPOINT_PATH);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Accept', 'application/json');
        req.setBody(JSON.serialize(payload));
        req.setTimeout(30000); // 30 seconds
        return req;
    }

    private void handleSuccess(HttpResponse res, Loan_Application__c app) {
        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        Decimal creditScore      = getDecimal(responseMap, 'credit_score');
        String  bureauRef        = getString(responseMap, 'reference_id');
        Integer activeAccounts   = getInteger(responseMap, 'total_active_accounts');
        Integer overdueAccounts  = getInteger(responseMap, 'overdue_accounts');
        Decimal totalOutstanding = getDecimal(responseMap, 'total_outstanding');
        String  riskGrade        = deriveRiskGrade(creditScore);

        // Upsert Credit_Assessment__c
        Credit_Assessment__c assessment = new Credit_Assessment__c(
            Loan_Application__c     = loanApplicationId,
            Credit_Score__c         = creditScore,
            Risk_Grade__c           = riskGrade,
            Bureau_Reference__c     = bureauRef,
            Score_Pull_Date__c      = Date.today(),
            Total_Active_Accounts__c= activeAccounts,
            Overdue_Accounts__c     = overdueAccounts,
            Total_Outstanding__c    = totalOutstanding
        );
        insert assessment;

        // Publish platform event
        Credit_Assessment_Completed__e event = new Credit_Assessment_Completed__e(
            Loan_Application_Id__c = loanApplicationId,
            Credit_Score__c        = creditScore,
            Risk_Grade__c          = riskGrade
        );
        EventBus.publish(event);

        ApplicationLogger.logInfo(MODULE, CLASS_NAME, 'handleSuccess',
            'Credit assessment created. Score: ' + creditScore + ', Grade: ' + riskGrade,
            loanApplicationId);
    }

    /**
     * @description Derives risk grade from CIBIL credit score.
     * A: 750+, B: 700-749, C: 650-699, D: 600-649, E: <600
     */
    private String deriveRiskGrade(Decimal score) {
        if (score == null)   { return 'E'; }
        if (score >= 750)    { return 'A'; }
        if (score >= 700)    { return 'B'; }
        if (score >= 650)    { return 'C'; }
        if (score >= 600)    { return 'D'; }
        return 'E';
    }

    // ─── JSON Helper Utilities ──────────────────────────────────────────────────

    private static Decimal getDecimal(Map<String, Object> m, String key) {
        Object val = m.get(key);
        if (val == null) { return null; }
        return Decimal.valueOf(String.valueOf(val));
    }

    private static String getString(Map<String, Object> m, String key) {
        Object val = m.get(key);
        return val != null ? String.valueOf(val) : null;
    }

    private static Integer getInteger(Map<String, Object> m, String key) {
        Object val = m.get(key);
        if (val == null) { return null; }
        return Integer.valueOf(String.valueOf(val));
    }
}
