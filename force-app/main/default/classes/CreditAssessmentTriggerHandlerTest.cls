/**
 * @description Test class for CreditAssessmentTriggerHandler (via trigger).
 * @author      LendSphere 360
 */
@isTest
private class CreditAssessmentTriggerHandlerTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createLoanProduct();
        Account acc = TestDataFactory.createAccount();
        Loan_Product__c prod = [SELECT Id FROM Loan_Product__c LIMIT 1];
        TestDataFactory.createLoanApplication(acc.Id, prod.Id, 'Credit Assessment', true);
    }

    @isTest
    static void testInsert_derivesRiskGrade() {
        Loan_Application__c app = [SELECT Id FROM Loan_Application__c LIMIT 1];
        Credit_Assessment__c ca = new Credit_Assessment__c(
            Loan_Application__c = app.Id,
            Credit_Score__c     = 750,
            Analyst_Decision__c = 'Pending'
        );
        insert ca;

        ca = [SELECT Risk_Grade__c FROM Credit_Assessment__c WHERE Id = :ca.Id];
        System.assertEquals('A', ca.Risk_Grade__c, 'Score 750 should yield grade A');
    }

    @isTest
    static void testUpdate_analystApproved_noCollateral() {
        Loan_Product__c prod = [SELECT Id FROM Loan_Product__c LIMIT 1];
        TriggerHandler.bypass('LoanApplicationTriggerHandler');
        update new Loan_Product__c(Id = prod.Id, Requires_Collateral__c = false);
        TriggerHandler.clearBypass('LoanApplicationTriggerHandler');

        Loan_Application__c app = [SELECT Id FROM Loan_Application__c LIMIT 1];
        Credit_Assessment__c ca = TestDataFactory.createCreditAssessment(app.Id, 720, true);

        ca.Analyst_Decision__c = 'Approved';
        update ca;

        app = [SELECT Status__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertEquals('Sanctioned', app.Status__c);
    }

    @isTest
    static void testUpdate_riskGradeRecalculated() {
        Loan_Application__c app = [SELECT Id FROM Loan_Application__c LIMIT 1];
        Credit_Assessment__c ca = TestDataFactory.createCreditAssessment(app.Id, 720, true);
        ca = [SELECT Risk_Grade__c FROM Credit_Assessment__c WHERE Id = :ca.Id];
        System.assertEquals('B', ca.Risk_Grade__c, 'Score 720 should yield B');

        ca.Credit_Score__c = 800;
        update ca;
        ca = [SELECT Risk_Grade__c FROM Credit_Assessment__c WHERE Id = :ca.Id];
        System.assertEquals('A', ca.Risk_Grade__c, 'Score 800 should yield A');
    }
}
