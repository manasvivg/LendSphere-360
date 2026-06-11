/**
 * @description Test class for CreditService.
 * @author      LendSphere 360
 */
@isTest
private class CreditServiceTest {

    @TestSetup
    static void setup() {
        Loan_Product__c prod = TestDataFactory.createLoanProduct();
        Account acc = TestDataFactory.createAccount();
        Loan_Application__c app = TestDataFactory.createLoanApplication(acc.Id, prod.Id, 'Credit Assessment', true);
        TestDataFactory.createCreditAssessment(app.Id, 720, true);
    }

    private static Loan_Application__c getApp() {
        return [SELECT Id, Status__c FROM Loan_Application__c LIMIT 1];
    }
    private static Credit_Assessment__c getCA() {
        return [SELECT Id, Risk_Grade__c, Analyst_Decision__c FROM Credit_Assessment__c LIMIT 1];
    }

    // ─── deriveRiskGrade ─────────────────────────────────────────────────────────

    @isTest
    static void testRiskGrade_A() {
        Credit_Assessment__c ca = new Credit_Assessment__c(Credit_Score__c = 780);
        CreditService.deriveRiskGrade(ca);
        System.assertEquals('A', ca.Risk_Grade__c);
    }

    @isTest
    static void testRiskGrade_B() {
        Credit_Assessment__c ca = new Credit_Assessment__c(Credit_Score__c = 720);
        CreditService.deriveRiskGrade(ca);
        System.assertEquals('B', ca.Risk_Grade__c);
    }

    @isTest
    static void testRiskGrade_C() {
        Credit_Assessment__c ca = new Credit_Assessment__c(Credit_Score__c = 670);
        CreditService.deriveRiskGrade(ca);
        System.assertEquals('C', ca.Risk_Grade__c);
    }

    @isTest
    static void testRiskGrade_D() {
        Credit_Assessment__c ca = new Credit_Assessment__c(Credit_Score__c = 620);
        CreditService.deriveRiskGrade(ca);
        System.assertEquals('D', ca.Risk_Grade__c);
    }

    @isTest
    static void testRiskGrade_E() {
        Credit_Assessment__c ca = new Credit_Assessment__c(Credit_Score__c = 550);
        CreditService.deriveRiskGrade(ca);
        System.assertEquals('E', ca.Risk_Grade__c);
    }

    @isTest
    static void testRiskGrade_nullScore() {
        Credit_Assessment__c ca = new Credit_Assessment__c(Credit_Score__c = null);
        CreditService.deriveRiskGrade(ca);
        System.assertEquals(null, ca.Risk_Grade__c, 'Null score should not set grade');
    }

    // ─── handleAfterUpdate — analyst decision propagation ────────────────────────

    @isTest
    static void testAfterUpdate_approved_noCollateral_advancesToSanctioned() {
        // Non-collateral product
        Loan_Product__c prod = [SELECT Id FROM Loan_Product__c LIMIT 1];
        TriggerHandler.bypass('LoanApplicationTriggerHandler');
        update new Loan_Product__c(Id = prod.Id, Requires_Collateral__c = false);
        TriggerHandler.clearBypass('LoanApplicationTriggerHandler');

        Credit_Assessment__c ca = getCA();
        ca.Analyst_Decision__c = 'Approved';
        update ca;

        Loan_Application__c app = getApp();
        System.assertEquals('Sanctioned', app.Status__c, 'No collateral → Sanctioned');
    }

    @isTest
    static void testAfterUpdate_rejected_rejectsApplication() {
        Credit_Assessment__c ca = getCA();
        ca.Analyst_Decision__c = 'Rejected';
        update ca;

        Loan_Application__c app = getApp();
        System.assertEquals('Rejected', app.Status__c, 'Rejected decision → App Rejected');
    }

    // ─── @AuraEnabled submitAnalystDecision ──────────────────────────────────────

    @isTest
    static void testSubmitAnalystDecision() {
        Credit_Assessment__c ca = getCA();
        CreditService.submitAnalystDecision(ca.Id, 'Approved', 'Good profile');

        ca = [SELECT Analyst_Decision__c, Analyst_Remarks__c FROM Credit_Assessment__c WHERE Id = :ca.Id];
        System.assertEquals('Approved', ca.Analyst_Decision__c);
        System.assertEquals('Good profile', ca.Analyst_Remarks__c);
    }
}
