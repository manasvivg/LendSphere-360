/**
 * @description       Service layer for Property & Collateral Evaluation.
 *                    Handles LTV ratio calculation, valuation status transitions,
 *                    and propagation of the evaluation outcome to the parent
 *                    Loan Application (Sanctioned or Rejected).
 *
 * @author            LendSphere 360
 * @created           2024
 */
public with sharing class PropertyValuationService {

    private static final String MODULE = 'PropertyValuationService';

    // ───────────────────────────────────────────────────────────────────────────
    // Before-Insert / Before-Update
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Calculates LTV Ratio = (Loan Amount / Market Value) * 100
     *              on every save where market value is present.
     */
    public static void handleBeforeInsert(List<Property_Detail__c> newRecords) {
        Set<Id> appIds = getAppIds(newRecords);
        Map<Id, Decimal> loanAmountMap = getLoanAmounts(appIds);

        for (Property_Detail__c prop : newRecords) {
            calculateLTV(prop, loanAmountMap.get(prop.Loan_Application__c));
        }
    }

    public static void handleBeforeUpdate(
        List<Property_Detail__c>        newRecords,
        Map<Id, Property_Detail__c>     oldMap
    ) {
        // Only recalculate if market value changed
        List<Property_Detail__c> changed = new List<Property_Detail__c>();
        for (Property_Detail__c prop : newRecords) {
            if (prop.Market_Value__c != oldMap.get(prop.Id).Market_Value__c) {
                changed.add(prop);
            }
        }

        if (changed.isEmpty()) return;

        Set<Id> appIds = getAppIds(changed);
        Map<Id, Decimal> loanAmountMap = getLoanAmounts(appIds);
        for (Property_Detail__c prop : changed) {
            calculateLTV(prop, loanAmountMap.get(prop.Loan_Application__c));
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    // After-Update — propagate valuation outcome to parent Loan Application
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description When Valuation_Status__c reaches Approved or Rejected,
     *              advance or reject the parent Loan Application.
     */
    public static void handleAfterUpdate(
        List<Property_Detail__c>        newRecords,
        Map<Id, Property_Detail__c>     oldMap
    ) {
        List<Loan_Application__c> toUpdate = new List<Loan_Application__c>();

        for (Property_Detail__c prop : newRecords) {
            Property_Detail__c old = oldMap.get(prop.Id);
            if (prop.Valuation_Status__c == old.Valuation_Status__c) continue;

            if (prop.Valuation_Status__c == 'Approved') {
                toUpdate.add(new Loan_Application__c(
                    Id        = prop.Loan_Application__c,
                    Status__c = LoanApplicationService.STATUS_SANCTIONED
                ));
            } else if (prop.Valuation_Status__c == 'Rejected') {
                toUpdate.add(new Loan_Application__c(
                    Id        = prop.Loan_Application__c,
                    Status__c = LoanApplicationService.STATUS_REJECTED
                ));
            }
        }

        if (!toUpdate.isEmpty()) {
            try {
                TriggerHandler.bypass('LoanApplicationTriggerHandler');
                update toUpdate;
                TriggerHandler.clearBypass('LoanApplicationTriggerHandler');
                ApplicationLogger.log(ApplicationLogger.LEVEL_INFO, MODULE, 'handleAfterUpdate',
                    'Propagated property valuation outcome for ' + toUpdate.size() + ' applications.');
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

    @TestVisible
    private static void calculateLTV(Property_Detail__c prop, Decimal loanAmount) {
        if (prop.Market_Value__c == null || prop.Market_Value__c == 0 || loanAmount == null) {
            prop.LTV_Ratio__c = null;
            return;
        }
        prop.LTV_Ratio__c = ((loanAmount / prop.Market_Value__c) * 100).setScale(2, RoundingMode.HALF_UP);
    }

    private static Set<Id> getAppIds(List<Property_Detail__c> records) {
        Set<Id> appIds = new Set<Id>();
        for (Property_Detail__c prop : records) {
            if (prop.Loan_Application__c != null) appIds.add(prop.Loan_Application__c);
        }
        return appIds;
    }

    private static Map<Id, Decimal> getLoanAmounts(Set<Id> appIds) {
        Map<Id, Decimal> result = new Map<Id, Decimal>();
        for (Loan_Application__c app : [
            SELECT Id, Loan_Amount__c FROM Loan_Application__c WHERE Id IN :appIds
        ]) {
            result.put(app.Id, app.Loan_Amount__c);
        }
        return result;
    }
}
