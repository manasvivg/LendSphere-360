/**
 * @description Test class for LoanApplicationService.
 * @author      LendSphere 360
 */
@isTest
private class LoanApplicationServiceTest {

    @TestSetup
    static void setup() {
        Loan_Product__c prod = TestDataFactory.createLoanProduct();
        Account acc = TestDataFactory.createAccount();
    }

    // ─── handleBeforeInsert ──────────────────────────────────────────────────────

    @isTest
    static void testBeforeInsert_defaultsStatusAndCalculatesEMI() {
        Loan_Product__c prod = [SELECT Id FROM Loan_Product__c LIMIT 1];
        Account acc          = [SELECT Id FROM Account LIMIT 1];

        Loan_Application__c app = new Loan_Application__c(
            Applicant__c     = acc.Id,
            Loan_Product__c  = prod.Id,
            Loan_Amount__c   = 600000,
            Interest_Rate__c = 9.0,
            Tenure_Months__c = 60
        );
        insert app;

        app = [SELECT Status__c, EMI_Amount__c, Application_Date__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertEquals('Draft', app.Status__c, 'Default status should be Draft');
        System.assertNotEquals(null, app.EMI_Amount__c, 'EMI should be calculated');
        System.assertNotEquals(null, app.Application_Date__c, 'Application date should default to today');
    }

    @isTest
    static void testBeforeInsert_zeroInterestRate() {
        Loan_Product__c prod = [SELECT Id FROM Loan_Product__c LIMIT 1];
        Account acc          = [SELECT Id FROM Account LIMIT 1];

        Loan_Application__c app = new Loan_Application__c(
            Applicant__c     = acc.Id,
            Loan_Product__c  = prod.Id,
            Loan_Amount__c   = 120000,
            Interest_Rate__c = 0,
            Tenure_Months__c = 12,
            Status__c        = 'Draft'
        );
        insert app;
        app = [SELECT EMI_Amount__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertEquals(10000, app.EMI_Amount__c, 'Zero-interest EMI = Principal / Tenure');
    }

    // ─── handleBeforeUpdate (status transitions) ─────────────────────────────────

    @isTest
    static void testBeforeUpdate_validTransition_draftToSubmitted() {
        Map<String, SObject> setup = TestDataFactory.createFullApplicationSetup();
        Loan_Application__c app = (Loan_Application__c) setup.get('application');

        // Draft → Submitted should work
        app.Status__c = 'Submitted';
        update app;
        app = [SELECT Status__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertEquals('Submitted', app.Status__c);
    }

    @isTest
    static void testBeforeUpdate_invalidTransition_draftToDisbursed() {
        Map<String, SObject> setup = TestDataFactory.createFullApplicationSetup();
        Loan_Application__c app = (Loan_Application__c) setup.get('application');

        Boolean exceptionThrown = false;
        try {
            app.Status__c = 'Disbursed';
            update app;
        } catch (DmlException e) {
            exceptionThrown = true;
            System.assert(e.getMessage().contains('Invalid status transition'), 'Should throw transition error');
        }
        System.assert(exceptionThrown, 'Invalid transition should throw DmlException');
    }

    @isTest
    static void testBeforeUpdate_sanctionDateStamped() {
        Loan_Product__c prod = [SELECT Id FROM Loan_Product__c LIMIT 1];
        Account acc          = [SELECT Id FROM Account LIMIT 1];

        Loan_Application__c app = TestDataFactory.createLoanApplication(acc.Id, prod.Id, 'Credit Assessment', true);
        TriggerHandler.bypass('LoanApplicationTriggerHandler');
        app.Status__c = 'Sanctioned';
        update app;
        TriggerHandler.clearBypass('LoanApplicationTriggerHandler');

        app = [SELECT Sanction_Date__c, Sanctioned_Amount__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertEquals(Date.today(), app.Sanction_Date__c, 'Sanction date should be stamped');
        System.assertEquals(500000, app.Sanctioned_Amount__c, 'Sanctioned amount should copy from loan amount');
    }

    // ─── handleAfterInsert ───────────────────────────────────────────────────────

    @isTest
    static void testAfterInsert_kycRequestCreated() {
        Loan_Product__c prod = [SELECT Id FROM Loan_Product__c LIMIT 1];
        Account acc          = [SELECT Id FROM Account LIMIT 1];

        Loan_Application__c app = TestDataFactory.createLoanApplication(acc.Id, prod.Id);
        List<KYC_Request__c> kycs = [SELECT Id, KYC_Status__c FROM KYC_Request__c WHERE Loan_Application__c = :app.Id];
        System.assertEquals(1, kycs.size(), 'One KYC request should be auto-created');
        System.assertEquals('Pending', kycs[0].KYC_Status__c);
    }

    // ─── @AuraEnabled Methods ────────────────────────────────────────────────────

    @isTest
    static void testGetActiveLoanProducts() {
        List<Loan_Product__c> prods = LoanApplicationService.getActiveLoanProducts();
        System.assert(!prods.isEmpty(), 'Should return at least one active product');
    }

    @isTest
    static void testCreateLoanApplicationFromPortal() {
        Loan_Product__c prod = [SELECT Id FROM Loan_Product__c LIMIT 1];
        Account acc          = [SELECT Id FROM Account LIMIT 1];

        Id appId = LoanApplicationService.createLoanApplicationFromPortal(acc.Id, prod.Id, 400000, 48);
        System.assertNotEquals(null, appId, 'Should return the new application Id');

        Loan_Application__c app = [SELECT Status__c, Loan_Amount__c FROM Loan_Application__c WHERE Id = :appId];
        System.assertEquals('Draft', app.Status__c);
        System.assertEquals(400000, app.Loan_Amount__c);
    }

    @isTest
    static void testGetCustomerDashboardData() {
        Loan_Product__c prod = [SELECT Id FROM Loan_Product__c LIMIT 1];
        Account acc          = [SELECT Id FROM Account LIMIT 1];
        TestDataFactory.createLoanApplication(acc.Id, prod.Id);

        List<Loan_Application__c> apps = LoanApplicationService.getCustomerDashboardData(acc.Id);
        System.assert(!apps.isEmpty(), 'Should return customer applications');
    }

    @isTest
    static void testGetDocumentsByApplication() {
        Loan_Product__c prod = [SELECT Id FROM Loan_Product__c LIMIT 1];
        Account acc          = [SELECT Id FROM Account LIMIT 1];
        Loan_Application__c app = TestDataFactory.createLoanApplication(acc.Id, prod.Id);

        // Should return empty list without error
        List<Document__c> docs = LoanApplicationService.getDocumentsByApplication(app.Id);
        System.assertNotEquals(null, docs);
    }
}
