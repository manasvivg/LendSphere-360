/**
 * @description Test class for PropertyValuationService.
 * @author      LendSphere 360
 */
@isTest
private class PropertyValuationServiceTest {

    @TestSetup
    static void setup() {
        Loan_Product__c prod = TestDataFactory.createLoanProduct();
        Account acc = TestDataFactory.createAccount();
        TestDataFactory.createLoanApplication(acc.Id, prod.Id, 'Property Evaluation', true);
    }

    private static Loan_Application__c getApp() {
        return [SELECT Id, Status__c FROM Loan_Application__c LIMIT 1];
    }

    // ─── calculateLTV ────────────────────────────────────────────────────────────

    @isTest
    static void testCalculateLTV_standard() {
        Loan_Application__c app = getApp();
        Property_Detail__c prop = new Property_Detail__c(
            Loan_Application__c = app.Id,
            Market_Value__c = 1000000,
            Valuation_Status__c = 'Pending',
            Property_Type__c = 'Residential'
        );
        // Loan amount = 500000, Market value = 1000000 → LTV = 50%
        PropertyValuationService.calculateLTV(prop, 500000);
        System.assertEquals(50.00, prop.LTV_Ratio__c, 'LTV should be 50%');
    }

    @isTest
    static void testCalculateLTV_nullMarketValue() {
        Property_Detail__c prop = new Property_Detail__c(Market_Value__c = null);
        PropertyValuationService.calculateLTV(prop, 500000);
        System.assertEquals(null, prop.LTV_Ratio__c, 'Null market value → null LTV');
    }

    @isTest
    static void testCalculateLTV_zeroMarketValue() {
        Property_Detail__c prop = new Property_Detail__c(Market_Value__c = 0);
        PropertyValuationService.calculateLTV(prop, 500000);
        System.assertEquals(null, prop.LTV_Ratio__c, 'Zero market value → null LTV (div by zero guard)');
    }

    // ─── handleAfterUpdate (valuation outcome propagation) ───────────────────────

    @isTest
    static void testAfterUpdate_approved_advancesToSanctioned() {
        Loan_Application__c app = getApp();
        Property_Detail__c prop = TestDataFactory.createPropertyDetail(app.Id, 1000000, 'Pending', true);

        prop.Valuation_Status__c = 'Approved';
        update prop;

        app = [SELECT Status__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertEquals('Sanctioned', app.Status__c, 'Approved valuation → Sanctioned');
    }

    @isTest
    static void testAfterUpdate_rejected_rejectsApplication() {
        Loan_Application__c app = getApp();
        Property_Detail__c prop = TestDataFactory.createPropertyDetail(app.Id, 1000000, 'Pending', true);

        prop.Valuation_Status__c = 'Rejected';
        update prop;

        app = [SELECT Status__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertEquals('Rejected', app.Status__c, 'Rejected valuation → Rejected');
    }

    // ─── @AuraEnabled savePropertyDetail ─────────────────────────────────────────

    @isTest
    static void testSavePropertyDetail_insert() {
        Loan_Application__c app = getApp();
        Property_Detail__c prop = new Property_Detail__c(
            Loan_Application__c = app.Id,
            Market_Value__c     = 900000,
            Property_Type__c    = 'Commercial',
            Valuation_Status__c = 'Pending'
        );
        Id savedId = PropertyValuationService.savePropertyDetail(prop);
        System.assertNotEquals(null, savedId);
    }

    @isTest
    static void testSavePropertyDetail_update() {
        Loan_Application__c app = getApp();
        Property_Detail__c prop = TestDataFactory.createPropertyDetail(app.Id);

        prop.Market_Value__c = 1200000;
        Id savedId = PropertyValuationService.savePropertyDetail(prop);
        System.assertEquals(prop.Id, savedId);

        prop = [SELECT Market_Value__c FROM Property_Detail__c WHERE Id = :prop.Id];
        System.assertEquals(1200000, prop.Market_Value__c);
    }
}
