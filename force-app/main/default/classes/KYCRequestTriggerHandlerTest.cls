/**
 * @description Test class for KYCRequestTriggerHandler (via trigger).
 * @author      LendSphere 360
 */
@isTest
private class KYCRequestTriggerHandlerTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createLoanProduct();
        Account acc = TestDataFactory.createAccount();
        Loan_Product__c prod = [SELECT Id FROM Loan_Product__c LIMIT 1];
        TestDataFactory.createLoanApplication(acc.Id, prod.Id, 'KYC In Progress', true);
    }

    @isTest
    static void testInsert_defaultsKYCStatus() {
        Loan_Application__c app = [SELECT Id FROM Loan_Application__c LIMIT 1];
        // The trigger already creates one KYC on app insert; fetch it
        KYC_Request__c kyc = [SELECT KYC_Status__c, PAN_Verification_Status__c FROM KYC_Request__c
                               WHERE Loan_Application__c = :app.Id LIMIT 1];
        System.assertEquals('Pending', kyc.KYC_Status__c);
        System.assertEquals('Pending', kyc.PAN_Verification_Status__c);
    }

    @isTest
    static void testUpdate_bothVerified_advancesApp() {
        Loan_Application__c app = [SELECT Id FROM Loan_Application__c LIMIT 1];
        KYC_Request__c kyc = [SELECT Id FROM KYC_Request__c WHERE Loan_Application__c = :app.Id LIMIT 1];

        kyc.PAN_Verification_Status__c    = 'Verified';
        kyc.Aadhaar_Verification_Status__c = 'Verified';
        update kyc;

        app = [SELECT Status__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertEquals('KYC Verified', app.Status__c);
    }
}
