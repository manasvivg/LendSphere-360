/**
 * @description Shared test data factory for all LendSphere 360 test classes.
 *              Centralises record creation so field changes only need to be
 *              updated in one place.
 *
 * @author      LendSphere 360
 * @created     2024
 */
@isTest
public class TestDataFactory {

    // ─── Loan Product ────────────────────────────────────────────────────────────

    public static Loan_Product__c createLoanProduct() {
        return createLoanProduct('Home Loan', 'Home Loan', true);
    }

    public static Loan_Product__c createLoanProduct(String name, String productType, Boolean doInsert) {
        Loan_Product__c prod = new Loan_Product__c(
            Name                  = name,
            Product_Type__c       = productType,
            Min_Amount__c         = 100000,
            Max_Amount__c         = 10000000,
            Base_Interest_Rate__c = 8.5,
            Min_Tenure_Months__c  = 12,
            Max_Tenure_Months__c  = 240,
            Requires_Collateral__c = (productType == 'Home Loan'),
            Is_Active__c          = true
        );
        if (doInsert) insert prod;
        return prod;
    }

    // ─── Account (Customer) ──────────────────────────────────────────────────────

    public static Account createAccount() {
        return createAccount('Test Customer', true);
    }

    public static Account createAccount(String name, Boolean doInsert) {
        Account acc = new Account(Name = name);
        if (doInsert) insert acc;
        return acc;
    }

    // ─── Loan Application ────────────────────────────────────────────────────────

    public static Loan_Application__c createLoanApplication(Id applicantId, Id productId) {
        return createLoanApplication(applicantId, productId, 'Draft', true);
    }

    public static Loan_Application__c createLoanApplication(
        Id      applicantId,
        Id      productId,
        String  status,
        Boolean doInsert
    ) {
        Loan_Application__c app = new Loan_Application__c(
            Applicant__c     = applicantId,
            Loan_Product__c  = productId,
            Loan_Amount__c   = 500000,
            Interest_Rate__c = 8.5,
            Tenure_Months__c = 60,
            Status__c        = status
        );
        if (doInsert) insert app;
        return app;
    }

    // ─── KYC Request ─────────────────────────────────────────────────────────────

    public static KYC_Request__c createKYCRequest(Id loanApplicationId) {
        return createKYCRequest(loanApplicationId, 'Pending', true);
    }

    public static KYC_Request__c createKYCRequest(
        Id      loanApplicationId,
        String  status,
        Boolean doInsert
    ) {
        KYC_Request__c kyc = new KYC_Request__c(
            Loan_Application__c          = loanApplicationId,
            KYC_Status__c                = status,
            PAN_Verification_Status__c   = 'Pending',
            Aadhaar_Verification_Status__c = 'Pending'
        );
        if (doInsert) insert kyc;
        return kyc;
    }

    // ─── Credit Assessment ───────────────────────────────────────────────────────

    public static Credit_Assessment__c createCreditAssessment(Id loanApplicationId) {
        return createCreditAssessment(loanApplicationId, 720, true);
    }

    public static Credit_Assessment__c createCreditAssessment(
        Id      loanApplicationId,
        Integer creditScore,
        Boolean doInsert
    ) {
        Credit_Assessment__c ca = new Credit_Assessment__c(
            Loan_Application__c = loanApplicationId,
            Credit_Score__c     = creditScore,
            Analyst_Decision__c = 'Pending'
        );
        if (doInsert) insert ca;
        return ca;
    }

    // ─── Property Detail ─────────────────────────────────────────────────────────

    public static Property_Detail__c createPropertyDetail(Id loanApplicationId) {
        return createPropertyDetail(loanApplicationId, 800000, 'Pending', true);
    }

    public static Property_Detail__c createPropertyDetail(
        Id      loanApplicationId,
        Decimal marketValue,
        String  valuationStatus,
        Boolean doInsert
    ) {
        Property_Detail__c prop = new Property_Detail__c(
            Loan_Application__c = loanApplicationId,
            Market_Value__c     = marketValue,
            Valuation_Status__c = valuationStatus,
            Property_Type__c    = 'Residential'
        );
        if (doInsert) insert prop;
        return prop;
    }

    // ─── Disbursement ────────────────────────────────────────────────────────────

    public static Disbursement__c createDisbursement(Id loanApplicationId) {
        return createDisbursement(loanApplicationId, 'Pending', true);
    }

    public static Disbursement__c createDisbursement(
        Id      loanApplicationId,
        String  status,
        Boolean doInsert
    ) {
        Disbursement__c d = new Disbursement__c(
            Loan_Application__c  = loanApplicationId,
            Disbursed_Amount__c  = 500000,
            Disbursement_Date__c = Date.today(),
            Status__c            = status
        );
        if (doInsert) insert d;
        return d;
    }

    // ─── EMI Schedule ────────────────────────────────────────────────────────────

    public static EMI_Schedule__c createEMISchedule(Id loanApplicationId, Id disbursementId, Integer emiNumber, Date dueDate) {
        EMI_Schedule__c emi = new EMI_Schedule__c(
            Name                = 'EMI-' + String.valueOf(emiNumber).leftPad(3, '0'),
            Loan_Application__c = loanApplicationId,
            Disbursement__c     = disbursementId,
            EMI_Number__c       = emiNumber,
            Due_Date__c         = dueDate,
            EMI_Amount__c       = 10000,
            Principal_Component__c = 8000,
            Interest_Component__c  = 2000,
            Outstanding_Balance__c = 490000,
            Status__c           = 'Upcoming'
        );
        insert emi;
        return emi;
    }

    // ─── Collection Case ─────────────────────────────────────────────────────────

    public static Collection_Case__c createCollectionCase(Id loanApplicationId) {
        Collection_Case__c cc = new Collection_Case__c(
            Loan_Application__c  = loanApplicationId,
            DPD__c               = 15,
            Bucket__c            = '1-30 DPD',
            Overdue_Amount__c    = 10000,
            Collection_Status__c = 'Open'
        );
        insert cc;
        return cc;
    }

    // ─── Full Setup Helper ────────────────────────────────────────────────────────

    /**
     * @description Creates a complete Loan Application setup: Product → Account → Application.
     *              Returns a map with keys: 'product', 'account', 'application'
     */
    public static Map<String, SObject> createFullApplicationSetup() {
        Loan_Product__c prod = createLoanProduct();
        Account         acc  = createAccount();
        Loan_Application__c app = createLoanApplication(acc.Id, prod.Id, 'Submitted', true);
        return new Map<String, SObject>{
            'product'     => prod,
            'account'     => acc,
            'application' => app
        };
    }
}
