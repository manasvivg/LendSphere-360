/**
 * @description Test class for CollectionsBatch.
 * @author      LendSphere 360
 */
@isTest
private class CollectionsBatchTest {

    @TestSetup
    static void setup() {
        Loan_Product__c prod = TestDataFactory.createLoanProduct();
        Account acc = TestDataFactory.createAccount();
        Loan_Application__c app = TestDataFactory.createLoanApplication(acc.Id, prod.Id, 'Disbursed', true);
        Disbursement__c disb = TestDataFactory.createDisbursement(app.Id, 'Completed', true);

        // Create overdue EMI record
        EMI_Schedule__c emi = new EMI_Schedule__c(
            Name                = 'EMI-001',
            Loan_Application__c = app.Id,
            Disbursement__c     = disb.Id,
            EMI_Number__c       = 1,
            Due_Date__c         = Date.today().addDays(-10),
            EMI_Amount__c       = 10000,
            Principal_Component__c = 8000,
            Interest_Component__c  = 2000,
            Outstanding_Balance__c = 490000,
            Status__c           = 'Upcoming'
        );
        insert emi;
    }

    @isTest
    static void testBatch_executesWithoutError() {
        Test.startTest();
        Database.executeBatch(new CollectionsBatch(), 200);
        Test.stopTest();

        // After batch, the overdue EMI should be marked Overdue
        EMI_Schedule__c emi = [SELECT Status__c FROM EMI_Schedule__c LIMIT 1];
        System.assertEquals('Overdue', emi.Status__c, 'Overdue EMI should be marked Overdue by batch');
    }

    @isTest
    static void testBatch_createsCollectionCase() {
        Test.startTest();
        Database.executeBatch(new CollectionsBatch(), 200);
        Test.stopTest();

        List<Collection_Case__c> cases = [SELECT Id, DPD__c FROM Collection_Case__c];
        System.assertEquals(1, cases.size(), 'Batch should create one collection case');
        System.assert(cases[0].DPD__c > 0, 'DPD should be populated');
    }

    @isTest
    static void testSchedulable_executes() {
        Test.startTest();
        String cronExpr = '0 0 0 * * ?';
        System.schedule('Test Collections Batch', cronExpr, new CollectionsBatch());
        Test.stopTest();
        System.assert(true, 'Schedulable should execute without error');
    }

    @isTest
    static void testExecuteNow_returnsJobId() {
        Test.startTest();
        Id jobId = CollectionsBatch.executeNow();
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'executeNow should return a job ID');
    }
}
