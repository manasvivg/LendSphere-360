/**
 * @description Test class for PropertyDetailTriggerHandler (via trigger).
 * @author      LendSphere 360
 */
@isTest
private class PropertyDetailTriggerHandlerTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createLoanProduct();
        Account acc = TestDataFactory.createAccount();
        Loan_Product__c prod = [SELECT Id FROM Loan_Product__c LIMIT 1];
        TestDataFactory.createLoanApplication(acc.Id, prod.Id, 'Property Evaluation', true);
    }

    @isTest
    static void testInsert_calculatesLTV() {
        Loan_Application__c app = [SELECT Id FROM Loan_Application__c LIMIT 1];
        Property_Detail__c prop = new Property_Detail__c(
            Loan_Application__c = app.Id,
            Market_Value__c     = 1000000,
            Property_Type__c    = 'Residential',
            Valuation_Status__c = 'Pending'
        );
        insert prop;

        prop = [SELECT LTV_Ratio__c FROM Property_Detail__c WHERE Id = :prop.Id];
        System.assertEquals(50.00, prop.LTV_Ratio__c, 'LTV = 500000/1000000 = 50%');
    }

    @isTest
    static void testUpdate_valuationApproved() {
        Loan_Application__c app = [SELECT Id FROM Loan_Application__c LIMIT 1];
        Property_Detail__c prop = TestDataFactory.createPropertyDetail(app.Id, 1000000, 'Pending', true);

        prop.Valuation_Status__c = 'Approved';
        update prop;

        app = [SELECT Status__c FROM Loan_Application__c WHERE Id = :app.Id];
        System.assertEquals('Sanctioned', app.Status__c);
    }

    @isTest
    static void testUpdate_ltvRecalculatedOnMarketValueChange() {
        Loan_Application__c app = [SELECT Id FROM Loan_Application__c LIMIT 1];
        Property_Detail__c prop = TestDataFactory.createPropertyDetail(app.Id, 1000000, 'Pending', true);

        prop.Market_Value__c = 2000000;
        update prop;

        prop = [SELECT LTV_Ratio__c FROM Property_Detail__c WHERE Id = :prop.Id];
        System.assertEquals(25.00, prop.LTV_Ratio__c, 'LTV = 500000/2000000 = 25%');
    }
}
