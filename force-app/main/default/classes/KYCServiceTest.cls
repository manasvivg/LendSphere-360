/**
 * @description Test class for KYCService.
 * @author      LendSphere 360
 */
@isTest
private class KYCServiceTest {

    @TestSetup
    static void setup() {
        Loan_Product__c prod = TestDataFactory.createLoanProduct();
        Account acc          = TestDataFactory.createAccount();
        Loan_Application__c app = TestDataFactory.createLoanApplication(acc.Id, prod.Id, 'KYC In Progress', true);
    }

    private static Loan_Application__c getApp() {
        return [SELECT Id FROM Loan_Application__c LIMIT 1];
    }

    // ─── deriveKYCStatus ─────────────────────────────────────────────────────────

    @isTest
    static void testDeriveKYCStatus_bothVerified() {
        KYC_Request__c kyc = new KYC_Request__c(
            KYC_Status__c = 'Pending',
            PAN_Verification_Status__c = 'Verified',
            Aadhaar_Verification_Status__c = 'Verified'
        );
        KYCService.deriveKYCStatus(kyc);
        System.assertEquals('Verified', kyc.KYC_Status__c);
        System.assertNotEquals(null, kyc.Verified_Date__c);
    }

    @isTest
    static void testDeriveKYCStatus_panFailed() {
        KYC_Request__c kyc = new KYC_Request__c(
            KYC_Status__c = 'Pending',
            PAN_Verification_Status__c = 'Failed',
            Aadhaar_Verification_Status__c = 'Pending'
        );
        KYCService.deriveKYCStatus(kyc);
        System.assertEquals('Failed', kyc.KYC_Status__c);
    }

    @isTest
    static void testDeriveKYCStatus_oneVerifiedOneInProgress() {
        KYC_Request__c kyc = new KYC_Request__c(
            KYC_Status__c = 'Pending',
            PAN_Verification_Status__c = 'Verified',
            Aadhaar_Verification_Status__c = 'Pending'
        );
        KYCService.deriveKYCStatus(kyc);
        System.assertEquals('In Progress', kyc.KYC_Status__c);
    }

    // ─── handleBeforeInsert ──────────────────────────────────────────────────────

    @isTest
    static void testBeforeInsert_defaultsStatus() {
        Loan_Application__c app = getApp();
        // KYC is auto-created by trigger — verify defaults
        KYC_Request__c kyc = [SELECT KYC_Status__c, PAN_Verification_Status__c, Aadhaar_Verification_Status__c
                               FROM KYC_Request__c WHERE Loan_Application__c = :app.Id LIMIT 1];
        System.assertEquals('Pending', kyc.KYC_Status__c);
        System.assertEquals('Pending', kyc.PAN_Verification_Status__c);
        System.assertEquals('Pending', kyc.Aadhaar_Verification_Status__c);
    }

    // ─── handleAfterUpdate (parent app propagation) ──────────────────────────────

    @isTest
    static void testAfterUpdate_kycVerified_advancesApplication() {
        Loan_Application__c app = getApp();
        KYC_Request__c kyc = [SELECT Id FROM KYC_Request__c WHERE Loan_Application__c = :app.Id LIMIT 1];

        kyc.PAN_Verification_Status__c    = 'Verified';
        kyc.Aadhaar_Verification_Status__c = 'Verified';
        update kyc;

        app = [SELECT Status__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertEquals('KYC Verified', app.Status__c, 'App should advance to KYC Verified');
    }

    @isTest
    static void testAfterUpdate_kycFailed_rejectsApplication() {
        Loan_Application__c app = getApp();
        KYC_Request__c kyc = [SELECT Id FROM KYC_Request__c WHERE Loan_Application__c = :app.Id LIMIT 1];

        kyc.PAN_Verification_Status__c = 'Failed';
        update kyc;

        app = [SELECT Status__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertEquals('Rejected', app.Status__c, 'App should be Rejected on KYC failure');
    }
}
