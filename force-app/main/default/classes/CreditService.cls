/**
 * @description       Service layer for Credit Assessment operations.
 *                    Handles risk grade derivation from credit score, analyst decision
 *                    processing, and propagation of credit outcomes to Loan Application.
 *
 * @author            LendSphere 360
 * @created           2024
 */
public with sharing class CreditService {

    private static final String MODULE = 'CreditService';

    // ───────────────────────────────────────────────────────────────────────────
    // Before-Insert / Before-Update
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Derives the Risk_Grade__c picklist value from the numeric Credit_Score__c.
     *              Called on both insert and update whenever the score changes.
     */
    public static void handleBeforeInsert(List<Credit_Assessment__c> newRecords) {
        for (Credit_Assessment__c ca : newRecords) {
            deriveRiskGrade(ca);
        }
    }

    public static void handleBeforeUpdate(
        List<Credit_Assessment__c>      newRecords,
        Map<Id, Credit_Assessment__c>   oldMap
    ) {
        for (Credit_Assessment__c ca : newRecords) {
            // Only recalculate if score changed
            if (ca.Credit_Score__c != oldMap.get(ca.Id).Credit_Score__c) {
                deriveRiskGrade(ca);
            }
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    // After-Update — propagate analyst decision to parent Loan Application
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description When the Credit Analyst sets a decision, advance or reject the
     *              parent Loan Application accordingly.
     *              Approved → 'Property Evaluation' (if collateral required) or 'Sanctioned'.
     *              Rejected → 'Rejected'.
     */
    public static void handleAfterUpdate(
        List<Credit_Assessment__c>      newRecords,
        Map<Id, Credit_Assessment__c>   oldMap
    ) {
        // Collect application IDs that need their credit assessment result
        Set<Id> appIds = new Set<Id>();
        Map<Id, String> decisionMap = new Map<Id, String>(); // appId → decision

        for (Credit_Assessment__c ca : newRecords) {
            Credit_Assessment__c old = oldMap.get(ca.Id);
            if (ca.Analyst_Decision__c != old.Analyst_Decision__c
                && ca.Analyst_Decision__c != 'Pending') {
                appIds.add(ca.Loan_Application__c);
                decisionMap.put(ca.Loan_Application__c, ca.Analyst_Decision__c);
            }
        }

        if (appIds.isEmpty()) return;

        // Query parent apps to check if collateral is required (via Loan Product)
        Map<Id, Loan_Application__c> appsMap = new Map<Id, Loan_Application__c>([
            SELECT Id, Status__c, Loan_Product__r.Requires_Collateral__c
            FROM   Loan_Application__c
            WHERE  Id IN :appIds
        ]);

        List<Loan_Application__c> toUpdate = new List<Loan_Application__c>();
        for (Id appId : decisionMap.keySet()) {
            Loan_Application__c app = appsMap.get(appId);
            if (app == null) continue;

            String decision = decisionMap.get(appId);
            String nextStatus;

            if (decision == 'Approved') {
                // Route to property evaluation if product requires collateral
                nextStatus = (app.Loan_Product__r.Requires_Collateral__c == true)
                    ? LoanApplicationService.STATUS_PROPERTY_EVAL
                    : LoanApplicationService.STATUS_SANCTIONED;
            } else if (decision == 'Rejected') {
                nextStatus = LoanApplicationService.STATUS_REJECTED;
            }

            if (nextStatus != null) {
                toUpdate.add(new Loan_Application__c(Id = appId, Status__c = nextStatus));
            }
        }

        if (!toUpdate.isEmpty()) {
            try {
                TriggerHandler.bypass('LoanApplicationTriggerHandler');
                update toUpdate;
                TriggerHandler.clearBypass('LoanApplicationTriggerHandler');
                ApplicationLogger.log(ApplicationLogger.LEVEL_INFO, MODULE, 'handleAfterUpdate',
                    'Propagated credit decision for ' + toUpdate.size() + ' applications.');
            } catch (Exception e) {
                ApplicationLogger.logException(e, MODULE, 'handleAfterUpdate');
            } finally {
                TriggerHandler.clearBypass('LoanApplicationTriggerHandler');
                ApplicationLogger.flush();
            }
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Maps bureau score to internal risk grade.
     *              Grade A = 750+, B = 700-749, C = 650-699, D = 600-649, E = <600
     */
    @TestVisible
    private static void deriveRiskGrade(Credit_Assessment__c ca) {
        if (ca.Credit_Score__c == null) return;
        Integer score = Integer.valueOf(ca.Credit_Score__c);

        if      (score >= 750) ca.Risk_Grade__c = 'A';
        else if (score >= 700) ca.Risk_Grade__c = 'B';
        else if (score >= 650) ca.Risk_Grade__c = 'C';
        else if (score >= 600) ca.Risk_Grade__c = 'D';
        else                   ca.Risk_Grade__c = 'E';
    }

    // ───────────────────────────────────────────────────────────────────────────
    // @AuraEnabled — LWC / Aura entry points
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Records the credit analyst's decision on an assessment.
     * @param assessmentId  Id of the Credit_Assessment__c record
     * @param decision      'Approved' or 'Rejected'
     * @param remarks       Analyst comments
     */
    @AuraEnabled
    public static void submitAnalystDecision(
        Id     assessmentId,
        String decision,
        String remarks
    ) {
        Credit_Assessment__c ca = new Credit_Assessment__c(
            Id                = assessmentId,
            Analyst_Decision__c = decision,
            Analyst_Remarks__c  = remarks,
            Reviewed_By__c      = UserInfo.getUserId()
        );
        update ca;
    }
}
