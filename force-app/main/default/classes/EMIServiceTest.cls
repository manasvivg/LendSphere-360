/**
 * @description Test class for EMIService.
 * @author      LendSphere 360
 */
@isTest
private class EMIServiceTest {

    @TestSetup
    static void setup() {
        Loan_Product__c prod = TestDataFactory.createLoanProduct();
        Account acc = TestDataFactory.createAccount();
        Loan_Application__c app = TestDataFactory.createLoanApplication(acc.Id, prod.Id, 'Disbursed', true);
    }

    // ─── buildAmortisationSchedule ───────────────────────────────────────────────

    @isTest
    static void testBuildAmortisationSchedule_correctCount() {
        Loan_Application__c app = [SELECT Id, Interest_Rate__c, Tenure_Months__c, EMI_Amount__c FROM Loan_Application__c LIMIT 1];
        Disbursement__c disb = new Disbursement__c(
            Loan_Application__c  = app.Id,
            Disbursed_Amount__c  = 500000,
            Disbursement_Date__c = Date.today(),
            Status__c            = 'Completed'
        );
        insert disb;

        List<EMI_Schedule__c> schedule = EMIService.buildAmortisationSchedule(disb, app);
        System.assertEquals(Integer.valueOf(app.Tenure_Months__c), schedule.size(),
            'Schedule count should equal tenure months');
    }

    @isTest
    static void testBuildAmortisationSchedule_dueDateSequence() {
        Loan_Application__c app = [SELECT Id, Interest_Rate__c, Tenure_Months__c, EMI_Amount__c FROM Loan_Application__c LIMIT 1];
        Disbursement__c disb = new Disbursement__c(
            Loan_Application__c  = app.Id,
            Disbursed_Amount__c  = 500000,
            Disbursement_Date__c = Date.newInstance(2024, 1, 15),
            Status__c            = 'Completed'
        );
        insert disb;

        List<EMI_Schedule__c> schedule = EMIService.buildAmortisationSchedule(disb, app);
        System.assertEquals(Date.newInstance(2024, 2, 15), schedule[0].Due_Date__c, 'First due date = disbursement date + 1 month');
        System.assertEquals('Upcoming', schedule[0].Status__c, 'Initial status should be Upcoming');
    }

    @isTest
    static void testBuildAmortisationSchedule_lastEMIRounding() {
        Loan_Application__c app = [SELECT Id, Interest_Rate__c, Tenure_Months__c, EMI_Amount__c FROM Loan_Application__c LIMIT 1];
        Disbursement__c disb = new Disbursement__c(
            Loan_Application__c  = app.Id,
            Disbursed_Amount__c  = 500000,
            Disbursement_Date__c = Date.today(),
            Status__c            = 'Completed'
        );
        insert disb;

        List<EMI_Schedule__c> schedule = EMIService.buildAmortisationSchedule(disb, app);
        EMI_Schedule__c lastEMI = schedule[schedule.size() - 1];
        System.assert(lastEMI.Outstanding_Balance__c == 0 || lastEMI.Outstanding_Balance__c >= 0,
            'Last EMI outstanding balance should be 0 or non-negative');
    }

    // ─── generateSchedules ───────────────────────────────────────────────────────

    @isTest
    static void testGenerateSchedules_insertsRecords() {
        Loan_Application__c app = [SELECT Id FROM Loan_Application__c LIMIT 1];
        Disbursement__c disb = TestDataFactory.createDisbursement(app.Id, 'Completed', true);

        Test.startTest();
        EMIService.generateSchedules(new List<Id>{ disb.Id });
        Test.stopTest();

        List<EMI_Schedule__c> schedules = [SELECT Id FROM EMI_Schedule__c WHERE Loan_Application__c = :app.Id];
        System.assertEquals(60, schedules.size(), 'Should generate 60 EMI records for 60-month tenure');
    }

    @isTest
    static void testGenerateSchedules_emptyList() {
        Test.startTest();
        EMIService.generateSchedules(new List<Id>());
        Test.stopTest();
        System.assert(true, 'Empty list should not throw');
    }

    @isTest
    static void testGenerateSchedules_nullList() {
        Test.startTest();
        EMIService.generateSchedules(null);
        Test.stopTest();
        System.assert(true, 'Null list should not throw');
    }
}
