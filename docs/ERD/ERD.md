# Entity Relationship Diagram (ERD)

## LendSphere 360 – Data Model

| Field | Details |
|---|---|
| **Document Version** | 1.0 |
| **Status** | Approved |
| **Prepared By** | Manasvi Gharat |
| **Date** | May 2026 |

---

## 1. Complete ERD

```mermaid
erDiagram
    Lead {
        Id Id PK
        string FirstName
        string LastName
        string MobilePhone
        string Email
        string City
        string Status
        string LeadSource
        string Loan_Product_Interest__c
        decimal Estimated_Loan_Amount__c
        Id ConvertedAccountId FK
        Id ConvertedContactId FK
    }

    Account {
        Id Id PK
        string Name
        string Type
        string Phone
        string BillingCity
        string BillingState
        string Customer_Segment__c
        Id Dealer_Account__c FK
    }

    Contact {
        Id Id PK
        Id AccountId FK
        string FirstName
        string LastName
        string MobilePhone
        string Email
        date Birthdate
        string PAN_Encrypted__c
        string Aadhaar_Encrypted__c
    }

    Opportunity {
        Id Id PK
        Id AccountId FK
        string Name
        string StageName
        decimal Amount
        date CloseDate
        string Loan_Product_Type__c
    }

    Loan_Product__c {
        Id Id PK
        string Name
        string Product_Type__c
        decimal Min_Amount__c
        decimal Max_Amount__c
        decimal Base_Interest_Rate__c
        integer Min_Tenure_Months__c
        integer Max_Tenure_Months__c
        boolean Is_Active__c
    }

    Loan_Application__c {
        Id Id PK
        string Loan_Number__c
        Id Applicant__c FK
        Id Opportunity__c FK
        Id Loan_Product__c FK
        decimal Loan_Amount__c
        decimal Interest_Rate__c
        integer Tenure_Months__c
        decimal EMI_Amount__c
        string Status__c
        Id Dealer__c FK
        date Application_Date__c
        date Sanction_Date__c
        string Rejection_Reason__c
    }

    KYC_Request__c {
        Id Id PK
        Id Loan_Application__c FK
        Id Contact__c FK
        string PAN_Encrypted__c
        string Aadhaar_Encrypted__c
        string PAN_Verification_Status__c
        string Aadhaar_Verification_Status__c
        string KYC_Status__c
        datetime Verified_Date__c
        string Rejection_Remarks__c
        Id Verified_By__c FK
    }

    Document__c {
        Id Id PK
        Id Loan_Application__c FK
        string Document_Type__c
        string Verification_Status__c
        datetime Upload_Date__c
        string Rejection_Remarks__c
        Id Verified_By__c FK
        datetime Verified_Date__c
        Id ContentDocumentId FK
    }

    Credit_Assessment__c {
        Id Id PK
        Id Loan_Application__c FK
        integer Credit_Score__c
        string Risk_Grade__c
        string Bureau_Reference__c
        datetime Score_Pull_Date__c
        integer Total_Active_Accounts__c
        integer Overdue_Accounts__c
        decimal Total_Outstanding__c
        string Analyst_Decision__c
        string Analyst_Remarks__c
        Id Reviewed_By__c FK
    }

    Property_Detail__c {
        Id Id PK
        string Property_Ref__c
        Id Loan_Application__c FK
        string Property_Type__c
        string Collateral_Category__c
        string Property_Address__c
        string City__c
        string State__c
        string Pincode__c
        decimal Property_Area_SqFt__c
        decimal Plot_Area_SqFt__c
        string Construction_Status__c
        integer Year_Of_Construction__c
        decimal Market_Value__c
        decimal Forced_Sale_Value__c
        decimal LTV_Ratio__c
        string Ownership_Type__c
        string Title_Status__c
        Id Title_Verified_By__c FK
        string Valuation_Status__c
        date Valuation_Date__c
        Id Valuation_Officer__c FK
        string Valuation_Report_Ref__c
        string Valuation_Remarks__c
        string Legal_Remarks__c
    }

    Mandate__c {
        Id Id PK
        Id Loan_Application__c FK
        string Mandate_Type__c
        string Mandate_Status__c
        string VPA__c
        string Bank_Account_Masked__c
        string IFSC_Code__c
        decimal EMI_Amount__c
        date Start_Date__c
        date End_Date__c
        string Mandate_Reference__c
        datetime Activated_Date__c
    }

    Disbursement__c {
        Id Id PK
        Id Loan_Application__c FK
        decimal Disbursed_Amount__c
        date Disbursement_Date__c
        string Disbursement_Reference__c
        string UTR_Number__c
        string Loan_Account_Number__c
        string Status__c
    }

    EMI_Schedule__c {
        Id Id PK
        Id Loan_Application__c FK
        Id Disbursement__c FK
        integer EMI_Number__c
        date Due_Date__c
        decimal EMI_Amount__c
        decimal Principal_Component__c
        decimal Interest_Component__c
        decimal Outstanding_Balance__c
        string Status__c
        date Paid_Date__c
        decimal Paid_Amount__c
    }

    Collection_Case__c {
        Id Id PK
        Id Loan_Application__c FK
        Id EMI_Schedule__c FK
        integer DPD__c
        decimal Overdue_Amount__c
        string Collection_Status__c
        string Bucket__c
        Id Assigned_To__c FK
        date Promise_To_Pay_Date__c
        string Last_Contact_Remarks__c
    }

    Application_Log__c {
        Id Id PK
        string Log_Level__c
        string Module__c
        string Class_Name__c
        string Method_Name__c
        string Message__c
        string Stack_Trace__c
        string Endpoint__c
        string Request_Body__c
        string Response_Body__c
        integer HTTP_Status_Code__c
        Id Related_Record_Id__c
        datetime Log_Timestamp__c
    }

    Case {
        Id Id PK
        Id AccountId FK
        Id ContactId FK
        string Subject
        string Description
        string Status
        string Priority
        string Type
        Id Loan_Application__c FK
    }

    Lead ||--o{ Account : "converts to"
    Lead ||--o{ Contact : "converts to"
    Account ||--o{ Opportunity : "has"
    Account ||--o{ Loan_Application__c : "has"
    Account ||--o{ Contact : "has"
    Opportunity ||--|| Loan_Application__c : "linked to"
    Loan_Product__c ||--o{ Loan_Application__c : "applied for"
    Loan_Application__c ||--|| KYC_Request__c : "has"
    Loan_Application__c ||--o{ Document__c : "has"
    Loan_Application__c ||--|| Credit_Assessment__c : "has"
    Loan_Application__c ||--o| Property_Detail__c : "has"
    Loan_Application__c ||--|| Mandate__c : "has"
    Loan_Application__c ||--|| Disbursement__c : "has"
    Disbursement__c ||--o{ EMI_Schedule__c : "generates"
    Loan_Application__c ||--o{ EMI_Schedule__c : "has"
    EMI_Schedule__c ||--o{ Collection_Case__c : "triggers"
    Loan_Application__c ||--o{ Collection_Case__c : "has"
    Account ||--o{ Case : "has"
    Loan_Application__c ||--o{ Case : "related to"
    Loan_Application__c ||--o{ Application_Log__c : "logged against"
```

---

## 2. Object Summary Table

| Object Type | API Name | Record Count (Expected) | Purpose |
|---|---|---|---|
| Standard | `Lead` | Thousands | Prospective customers |
| Standard | `Account` | Thousands | Customer + Dealer accounts |
| Standard | `Contact` | Thousands | Customer contacts |
| Standard | `Opportunity` | Thousands | Loan pipeline |
| Standard | `Case` | Thousands | Service requests |
| Custom | `Loan_Application__c` | Thousands | Core loan record |
| Custom | `Loan_Product__c` | < 50 | Product catalog |
| Custom | `KYC_Request__c` | Thousands (1:1 with App) | KYC tracking |
| Custom | `Document__c` | Tens of thousands | Document records |
| Custom | `Credit_Assessment__c` | Thousands (1:1 with App) | Credit scores |
| Custom | `Property_Detail__c` | Thousands (conditional) | Collateral evaluation |
| Custom | `Mandate__c` | Thousands (1:1 with App) | Mandate details |
| Custom | `Disbursement__c` | Thousands (1:1 with App) | Disbursement records |
| Custom | `EMI_Schedule__c` | Millions | EMI repayment schedule |
| Custom | `Collection_Case__c` | Tens of thousands | Collections tracking |
| Custom | `Application_Log__c` | Millions | Audit/error log |

---

## 3. Key Relationships

### Primary Relationships

```
Account (1) ──── (M) Loan_Application__c
                         │
                         ├── (1) KYC_Request__c
                         ├── (M) Document__c
                         ├── (1) Credit_Assessment__c
                         ├── (0..1) Property_Detail__c  (conditional: secured products)
                         ├── (1) Mandate__c
                         ├── (1) Disbursement__c
                         │       └── (M) EMI_Schedule__c
                         │               └── (M) Collection_Case__c
                         └── (M) Application_Log__c
```

### Cross-Object Rollup Strategy

| Rollup | Parent Object | Child Object | Aggregation |
|---|---|---|---|
| Total Disbursed | Account | Disbursement__c | SUM(Disbursed_Amount__c) |
| Active Loan Count | Account | Loan_Application__c | COUNT (Status = Disbursed) |
| Total Overdue | Loan_Application__c | EMI_Schedule__c | SUM (Status = Overdue) |
| Total Paid EMIs | Loan_Application__c | EMI_Schedule__c | COUNT (Status = Paid) |

---

## 4. Field-Level Detail: Loan_Application__c

| Field Label | API Name | Data Type | Required | Notes |
|---|---|---|---|---|
| Loan Number | Loan_Number__c | Auto Number | Yes | LSP-{YYYY}-{000000} |
| Applicant | Applicant__c | Lookup (Account) | Yes | Master customer account |
| Opportunity | Opportunity__c | Lookup (Opportunity) | No | Linked opportunity |
| Loan Product | Loan_Product__c | Lookup (Loan_Product__c) | Yes | |
| Loan Amount | Loan_Amount__c | Currency | Yes | Requested amount |
| Sanctioned Amount | Sanctioned_Amount__c | Currency | No | Approved amount |
| Interest Rate | Interest_Rate__c | Percent | Yes | Annual rate |
| Tenure (Months) | Tenure_Months__c | Number | Yes | 12-360 |
| EMI Amount | EMI_Amount__c | Currency | No | Calculated |
| Status | Status__c | Picklist | Yes | See status values |
| Application Date | Application_Date__c | Date | Yes | Default: Today |
| Sanction Date | Sanction_Date__c | Date | No | Set on approval |
| Rejection Reason | Rejection_Reason__c | Textarea | No | Required if rejected |
| Dealer | Dealer__c | Lookup (Account) | No | If dealer-sourced |
| Co-Applicant Name | Co_Applicant_Name__c | Text | No | |
| Co-Applicant PAN | Co_Applicant_PAN__c | Text (Encrypted) | No | |

**Status Picklist Values:**
`Draft` → `Submitted` → `Under Review` → `KYC Verified` → `Credit Assessment` → `Property Evaluation` → `Sanctioned` → `Mandate Pending` → `Mandate Active` → `Disbursed` → `Rejected` → `Closed`

---

## 5. Field-Level Detail: EMI_Schedule__c

| Field Label | API Name | Data Type | Notes |
|---|---|---|---|
| Loan Application | Loan_Application__c | Master-Detail | Parent loan |
| Disbursement | Disbursement__c | Lookup | Parent disbursement |
| EMI Number | EMI_Number__c | Number | Sequential: 1, 2, 3... |
| Due Date | Due_Date__c | Date | Monthly from disbursement |
| EMI Amount | EMI_Amount__c | Currency | Fixed amount |
| Principal Component | Principal_Component__c | Currency | Reducing balance |
| Interest Component | Interest_Component__c | Currency | On outstanding |
| Outstanding Balance | Outstanding_Balance__c | Currency | After EMI payment |
| Status | Status__c | Picklist | Upcoming / Due / Overdue / Paid |
| Paid Date | Paid_Date__c | Date | Actual payment date |
| Paid Amount | Paid_Amount__c | Currency | Actual payment amount |
| Days Past Due | DPD__c | Formula | TODAY() - Due_Date__c if Overdue |

---

## 6. Custom Metadata Types

| CMT Name | API Name | Purpose | Example Records |
|---|---|---|---|
| Integration Config | Integration_Config__mdt | API endpoints, timeout, retry | Credit_Bureau_Config, KYC_Config |
| Loan Product Config | Loan_Product_Config__mdt | Risk thresholds, rate ranges | PL_Config, HL_Config |
| Trigger Switch | Trigger_Switch__mdt | Enable/disable triggers | LoanApplication_Switch |
| Risk Grade Config | Risk_Grade_Config__mdt | Score bands per grade | Grade_A, Grade_B, ... |
| Collections Config | Collections_Config__mdt | DPD bucket thresholds | Bucket_30, Bucket_60, Bucket_90 |
