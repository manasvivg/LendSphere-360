/**
 * @description Test class for CollectionsService.
 * @author      LendSphere 360
 */
@isTest
private class CollectionsServiceTest {

    @TestSetup
    static void setup() {
        Loan_Product__c prod = TestDataFactory.createLoanProduct();
        Account acc = TestDataFactory.createAccount();
        TestDataFactory.createLoanApplication(acc.Id, prod.Id, 'Disbursed', true);
    }

    private static Loan_Application__c getApp() {
        return [SELECT Id FROM Loan_Application__c LIMIT 1];
    }

    // ─── deriveBucket ────────────────────────────────────────────────────────────

    @isTest
    static void testDeriveBucket_1_30() {
        System.assertEquals('1-30 DPD', CollectionsService.deriveBucket(15));
        System.assertEquals('1-30 DPD', CollectionsService.deriveBucket(1));
        System.assertEquals('1-30 DPD', CollectionsService.deriveBucket(30));
    }

    @isTest
    static void testDeriveBucket_31_60() {
        System.assertEquals('31-60 DPD', CollectionsService.deriveBucket(31));
        System.assertEquals('31-60 DPD', CollectionsService.deriveBucket(60));
    }

    @isTest
    static void testDeriveBucket_61_90() {
        System.assertEquals('61-90 DPD', CollectionsService.deriveBucket(75));
        System.assertEquals('61-90 DPD', CollectionsService.deriveBucket(90));
    }

    @isTest
    static void testDeriveBucket_NPA() {
        System.assertEquals('90+ DPD', CollectionsService.deriveBucket(91));
        System.assertEquals('90+ DPD', CollectionsService.deriveBucket(200));
    }

    // ─── processOverdueEMIs ──────────────────────────────────────────────────────

    @isTest
    static void testProcessOverdueEMIs_createsCollectionCase() {
        Loan_Application__c app = getApp();
        Disbursement__c disb = TestDataFactory.createDisbursement(app.Id, 'Completed', true);

        // Create overdue EMI (past due date)
        EMI_Schedule__c emi = new EMI_Schedule__c(
            Name                = 'EMI-001',
            Loan_Application__c = app.Id,
            Disbursement__c     = disb.Id,
            EMI_Number__c       = 1,
            Due_Date__c         = Date.today().addDays(-20),
            EMI_Amount__c       = 10000,
            Principal_Component__c = 8000,
            Interest_Component__c  = 2000,
            Outstanding_Balance__c = 490000,
            Status__c           = 'Upcoming'
        );
        insert emi;

        Test.startTest();
        CollectionsService.processOverdueEMIs(new List<EMI_Schedule__c>{ emi });
        Test.stopTest();

        List<Collection_Case__c> cases = [SELECT Id, DPD__c, Bucket__c FROM Collection_Case__c
                                          WHERE Loan_Application__c = :app.Id];
        System.assertEquals(1, cases.size(), 'One collection case should be created');
        System.assert(cases[0].DPD__c > 0, 'DPD should be positive');
    }

    @isTest
    static void testProcessOverdueEMIs_updatesExistingCase() {
        Loan_Application__c app = getApp();
        Disbursement__c disb = TestDataFactory.createDisbursement(app.Id, 'Completed', true);

        // Pre-existing case
        Collection_Case__c existing = TestDataFactory.createCollectionCase(app.Id);

        EMI_Schedule__c emi = new EMI_Schedule__c(
            Name                = 'EMI-002',
            Loan_Application__c = app.Id,
            Disbursement__c     = disb.Id,
            EMI_Number__c       = 2,
            Due_Date__c         = Date.today().addDays(-35),
            EMI_Amount__c       = 10000,
            Principal_Component__c = 8000,
            Interest_Component__c  = 2000,
            Outstanding_Balance__c = 480000,
            Status__c           = 'Upcoming'
        );
        insert emi;

        Test.startTest();
        CollectionsService.processOverdueEMIs(new List<EMI_Schedule__c>{ emi });
        Test.stopTest();

        existing = [SELECT Collection_Status__c FROM Collection_Case__c WHERE Id = :existing.Id];
        System.assertEquals('In Progress', existing.Collection_Status__c, 'Existing case should be updated');
    }

    @isTest
    static void testProcessOverdueEMIs_emptyList() {
        // Should return without error on empty list
        Test.startTest();
        CollectionsService.processOverdueEMIs(new List<EMI_Schedule__c>());
        Test.stopTest();
        System.assert(true, 'Empty list should not throw');
    }

    // ─── @AuraEnabled methods ────────────────────────────────────────────────────

    @isTest
    static void testGetCollectionDashboardData() {
        Loan_Application__c app = getApp();
        TestDataFactory.createCollectionCase(app.Id);

        List<Collection_Case__c> cases = CollectionsService.getCollectionDashboardData();
        System.assert(!cases.isEmpty(), 'Should return open collection cases');
    }

    @isTest
    static void testUpdateCollectionCase() {
        Loan_Application__c app = getApp();
        Collection_Case__c cc = TestDataFactory.createCollectionCase(app.Id);

        Test.startTest();
        CollectionsService.updateCollectionCase(cc.Id, 'Customer promised payment', Date.today().addDays(7), 'In Progress');
        Test.stopTest();

        cc = [SELECT Last_Contact_Remarks__c, Promise_To_Pay_Date__c, Collection_Status__c FROM Collection_Case__c WHERE Id = :cc.Id];
        System.assertEquals('Customer promised payment', cc.Last_Contact_Remarks__c);
        System.assertEquals(Date.today().addDays(7), cc.Promise_To_Pay_Date__c);
    }
}
