/**
 * @description Test class for LoanApplicationTriggerHandler (via trigger).
 * @author      LendSphere 360
 */
@isTest
private class LoanApplicationTriggerHandlerTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createLoanProduct();
        TestDataFactory.createAccount();
    }

    @isTest
    static void testInsert_createsKYCAndDefaults() {
        Loan_Product__c prod = [SELECT Id FROM Loan_Product__c LIMIT 1];
        Account acc          = [SELECT Id FROM Account LIMIT 1];

        Loan_Application__c app = new Loan_Application__c(
            Applicant__c     = acc.Id,
            Loan_Product__c  = prod.Id,
            Loan_Amount__c   = 500000,
            Interest_Rate__c = 8.5,
            Tenure_Months__c = 60
        );
        insert app;

        app = [SELECT Status__c, EMI_Amount__c, Application_Date__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertEquals('Draft', app.Status__c);
        System.assertNotEquals(null, app.EMI_Amount__c);
        System.assertNotEquals(null, app.Application_Date__c);

        Integer kycCount = [SELECT COUNT() FROM KYC_Request__c WHERE Loan_Application__c = :app.Id];
        System.assertEquals(1, kycCount, 'KYC Request should be auto-created');
    }

    @isTest
    static void testUpdate_emiRecalculated() {
        Loan_Product__c prod = [SELECT Id FROM Loan_Product__c LIMIT 1];
        Account acc          = [SELECT Id FROM Account LIMIT 1];
        Loan_Application__c app = TestDataFactory.createLoanApplication(acc.Id, prod.Id);

        Decimal originalEMI = [SELECT EMI_Amount__c FROM Loan_Application__c WHERE Id = :app.Id].EMI_Amount__c;

        app.Loan_Amount__c = 1000000; // Double the amount
        update app;

        Decimal newEMI = [SELECT EMI_Amount__c FROM Loan_Application__c WHERE Id = :app.Id].EMI_Amount__c;
        System.assert(newEMI > originalEMI, 'EMI should increase with higher loan amount');
    }

    @isTest
    static void testUpdate_bypassPreventsLogic() {
        Loan_Product__c prod = [SELECT Id FROM Loan_Product__c LIMIT 1];
        Account acc          = [SELECT Id FROM Account LIMIT 1];
        Loan_Application__c app = TestDataFactory.createLoanApplication(acc.Id, prod.Id, 'Credit Assessment', true);

        TriggerHandler.bypass('LoanApplicationTriggerHandler');
        app.Status__c = 'Disbursed'; // Would normally be invalid transition
        update app; // Should not throw because handler is bypassed
        TriggerHandler.clearBypass('LoanApplicationTriggerHandler');

        app = [SELECT Status__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertEquals('Disbursed', app.Status__c, 'Bypass should allow invalid transition');
    }
}
