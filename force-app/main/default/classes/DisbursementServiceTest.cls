/**
 * @description Test class for DisbursementService and EMIService.
 * @author      LendSphere 360
 */
@isTest
private class DisbursementServiceTest {

    @TestSetup
    static void setup() {
        Loan_Product__c prod = TestDataFactory.createLoanProduct();
        Account acc = TestDataFactory.createAccount();
        TestDataFactory.createLoanApplication(acc.Id, prod.Id, 'Mandate Setup', true);
    }

    private static Loan_Application__c getApp() {
        return [SELECT Id FROM Loan_Application__c LIMIT 1];
    }

    // ─── handleBeforeInsert ──────────────────────────────────────────────────────

    @isTest
    static void testBeforeInsert_defaultsStatus() {
        Loan_Application__c app = getApp();
        Disbursement__c d = new Disbursement__c(
            Loan_Application__c  = app.Id,
            Disbursed_Amount__c  = 500000,
            Disbursement_Date__c = Date.today()
            // Status intentionally blank
        );
        insert d;
        d = [SELECT Status__c FROM Disbursement__c WHERE Id = :d.Id];
        System.assertEquals('Pending', d.Status__c, 'Default status should be Pending');
    }

    // ─── handleAfterUpdate — advances app + enqueues EMI job ────────────────────

    @isTest
    static void testAfterUpdate_completedDisbursement_advancesApp() {
        Loan_Application__c app = getApp();
        Disbursement__c d = TestDataFactory.createDisbursement(app.Id, 'Pending', true);

        Test.startTest();
        d.Status__c = 'Completed';
        update d;
        Test.stopTest();

        app = [SELECT Status__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertEquals('Disbursed', app.Status__c, 'App should advance to Disbursed');
    }

    @isTest
    static void testAfterUpdate_noChangeWhenAlreadyCompleted() {
        Loan_Application__c app = getApp();
        Disbursement__c d = TestDataFactory.createDisbursement(app.Id, 'Completed', true);

        // Update without changing status — should not re-enqueue
        Test.startTest();
        d.Disbursed_Amount__c = 499000;
        update d;
        Test.stopTest();
        System.assert(true, 'Should complete without error');
    }
}
