# Sequence Diagrams

## LendSphere 360 – Process Flow Sequence Diagrams

| Field | Details |
|---|---|
| **Document Version** | 1.0 |
| **Status** | Approved |
| **Prepared By** | Manasvi Gharat |
| **Date** | May 2026 |

---

## Sequence 1: Dealer Loan Application Submission

```mermaid
sequenceDiagram
    actor Dealer as 🏪 Dealer
    participant DP as Dealer Portal (Experience Cloud)
    participant SF as Salesforce Core
    participant LA as Loan_Application__c
    participant DOC as Document__c
    participant PE as Platform Event Bus
    participant OPS as Operations Queue

    Dealer->>DP: Login to Dealer Portal
    DP->>SF: Authenticate (OAuth / SAML)
    SF-->>DP: Session Established

    Dealer->>DP: Navigate to "New Application"
    Dealer->>DP: Search / Create Customer Record
    DP->>SF: Upsert Account + Contact
    SF-->>DP: Customer ID returned

    Dealer->>DP: Fill Loan Application Details
    Note over DP: Product, Amount, Tenure, Co-applicant
    DP->>SF: Create Loan_Application__c (Status: Draft)
    SF->>LA: Insert record
    LA-->>SF: Loan Number auto-generated
    SF-->>DP: Application ID + Loan Number

    Dealer->>DP: Upload Customer Documents
    DP->>SF: ContentVersion + Document__c records
    SF->>DOC: Insert Document records
    DOC-->>SF: Documents linked

    Dealer->>DP: Click "Submit Application"
    DP->>SF: Update Status = "Submitted"
    SF->>LA: Update record

    Note over SF: Trigger fires → afterUpdate
    SF->>PE: Publish Application_Submitted__e
    PE->>OPS: Route to Operations Queue
    OPS-->>SF: Queue item created

    SF-->>DP: Submission Confirmed
    DP-->>Dealer: Show Reference Number + Success Message
    SF->>Dealer: Email: "Application Submitted"
```

---

## Sequence 2: KYC Verification Flow

```mermaid
sequenceDiagram
    actor OPS as 🔍 Operations Officer
    participant SFAPP as Salesforce App
    participant KYC as KYC_Request__c
    participant SRV as KYCService.cls
    participant CALL as KYCCallout.cls
    participant ENC as EncryptionUtil.cls
    participant KYCAPI as KYC Verify API
    participant LOG as Application_Log__c
    participant PE as Platform Event Bus

    OPS->>SFAPP: Open Loan Application from Queue
    SFAPP->>KYC: Load KYC_Request__c record
    KYC-->>SFAPP: Display KYC form

    OPS->>SFAPP: Click "Initiate KYC Verification"
    SFAPP->>SRV: KYCService.initiateKYC(kycRequestId)
    SRV->>KYC: Query Contact PAN + Aadhaar (encrypted)

    SRV->>ENC: decrypt(PAN_Encrypted__c)
    ENC-->>SRV: Plain PAN
    SRV->>ENC: decrypt(Aadhaar_Encrypted__c)
    ENC-->>SRV: Plain Aadhaar

    SRV->>CALL: KYCCallout.verifyPAN(pan, name, dob)
    CALL->>KYCAPI: POST /v1/pan/verify
    Note over CALL,KYCAPI: Header: X-API-Key (Named Credential)
    KYCAPI-->>CALL: {status: SUCCESS, panStatus: ACTIVE, nameMatch: FULL_MATCH}

    CALL->>LOG: logAPICall(endpoint, request, response, 200)

    CALL->>SRV: Return PANVerificationResult
    SRV->>CALL: KYCCallout.verifyAadhaar(aadhaar, name, dob)
    CALL->>KYCAPI: POST /v1/aadhaar/verify
    KYCAPI-->>CALL: {status: SUCCESS, dobMatch: true}

    CALL->>LOG: logAPICall(endpoint, request, response, 200)
    CALL->>SRV: Return AadhaarVerificationResult

    SRV->>KYC: Update KYC_Status__c = "Verified"
    SRV->>PE: Publish KYC_Completed__e
    PE-->>SFAPP: Update Loan Application Status → KYC Verified

    SFAPP-->>OPS: Show "KYC Verified" Success Toast
```

---

## Sequence 3: Credit Bureau API Integration

```mermaid
sequenceDiagram
    participant PE as Platform Event Bus
    participant SUB as Event Subscriber (Trigger Handler)
    participant SRV as CreditService.cls
    participant Q as System.enqueueJob()
    participant CB as CreditBureauCallout.cls (Queueable)
    participant NC as Named Credential (CreditBureauNC)
    participant API as Credit Bureau API
    participant CA as Credit_Assessment__c
    participant LOG as Application_Log__c
    participant PE2 as Platform Event Bus
    participant ANALYST as Credit Analyst

    PE->>SUB: KYC_Completed__e received
    SUB->>SRV: CreditService.initiateCreditAssessment(appId)
    SRV->>CA: Create Credit_Assessment__c (Status: Pending)
    CA-->>SRV: assessmentId

    SRV->>Q: System.enqueueJob(new CreditBureauCallout(appId, assessmentId))
    Q-->>SRV: jobId

    Note over CB: Queueable execution (async)
    CB->>CB: Query Loan_Application__c + Contact PAN
    CB->>NC: Build HttpRequest via Named Credential
    NC->>API: POST /v2/score/enquiry (OAuth 2.0 Bearer Token)

    API-->>NC: HTTP 200 - Credit Score Response
    NC-->>CB: HttpResponse

    alt HTTP 200 - Success
        CB->>SRV: CreditService.storeCreditScore(assessmentId, responseMap)
        SRV->>CA: Update Credit_Score__c, Risk_Grade__c, Bureau_Reference__c
        SRV->>CA: Update Status = "Completed"
        CB->>LOG: logAPICall(endpoint, requestBody, responseBody, 200)
        SRV->>PE2: Publish Credit_Assessment_Completed__e
        PE2->>ANALYST: Email Notification: "New application ready for credit review"
    else HTTP 422 - Record Not Found
        CB->>LOG: logError("Bureau record not found", response, appId)
        SRV->>CA: Update Status = "Failed", Failure_Reason__c = "No Bureau Record"
    else Timeout / 5xx
        CB->>LOG: logError("API Timeout", stackTrace, appId)
        Note over CB: Retry via re-enqueue (max 3 attempts)
    end
```

---

## Sequence 4: Property & Collateral Evaluation

```mermaid
sequenceDiagram
    participant PE as Platform Event Bus
    participant SRV as CreditService.cls
    participant PROP as Property_Detail__c
    participant LA as Loan_Application__c
    participant PROD as Loan_Product__c
    actor VALOFFICER as 🏠 Valuation Officer
    actor LEGAL as ⚖️ Legal Officer
    participant SFAPP as Salesforce App
    participant LOG as Application_Log__c

    Note over PE: Credit_Assessment_Completed__e received (Credit Analyst approved)

    PE->>SRV: Consume Credit_Assessment_Completed__e
    SRV->>LA: Query Loan_Application__c + Loan_Product__c
    SRV->>PROD: Check Requires_Collateral__c flag

    alt Unsecured Product (Personal Loan, Consumer Durable, etc.)
        SRV->>LA: Skip Property Evaluation → Route to Approval Workflow
        Note over SRV: Application proceeds directly to Branch Manager queue
    else Secured Product (Home Loan, Vehicle Loan, LAP, etc.)
        SRV->>PROP: Create Property_Detail__c (Valuation_Status__c: Pending)
        PROP-->>SRV: propertyDetailId
        SRV->>LA: Update Status__c = "Property Evaluation"
        SRV->>SFAPP: Assign to Property Valuation Queue
        SFAPP->>VALOFFICER: Notification: "New property valuation assigned"
        SFAPP->>LEGAL: Notification: "New legal verification assigned"
    end

    Note over VALOFFICER: Conducts physical site visit

    VALOFFICER->>SFAPP: Open Property Valuation Form LWC
    SFAPP->>PROP: Load Property_Detail__c record
    PROP-->>SFAPP: Display valuation form

    VALOFFICER->>SFAPP: Capture: Property Type, Address, Area, Construction Status
    VALOFFICER->>SFAPP: Enter Market Value + Forced Sale Value (FSV)
    VALOFFICER->>SFAPP: Upload site visit photos + valuation report
    SFAPP->>PROP: Update Market_Value__c, Forced_Sale_Value__c
    PROP->>PROP: Auto-calculate LTV_Ratio__c = (Loan_Amount / Market_Value) * 100
    VALOFFICER->>SFAPP: Submit Valuation as "Approved" / "Rejected"
    SFAPP->>PROP: Update Valuation_Status__c
    SFAPP->>LOG: logInfo("Valuation submitted", propertyDetailId)

    Note over LEGAL: Reviews ownership and title documents

    LEGAL->>SFAPP: Open Property_Detail__c record
    LEGAL->>SFAPP: Verify: Title Deed, Ownership Proof, Encumbrance Certificate
    LEGAL->>SFAPP: Set Title_Status__c = "Clear" / "Disputed" / "Encumbered"
    LEGAL->>SFAPP: Enter Legal_Remarks__c
    LEGAL->>SFAPP: Submit Legal Clearance as "Cleared" / "Rejected"
    SFAPP->>PROP: Update Title_Status__c, Legal_Remarks__c
    SFAPP->>LOG: logInfo("Legal verification submitted", propertyDetailId)

    alt Both Valuation Approved AND Legal Cleared
        SFAPP->>LA: Route application to Branch Manager Approval Queue
        SFAPP->>SFAPP: Notify Branch Manager: "Application ready for final sanction"
        Note over SFAPP: Loan_Application__c Status remains "Property Evaluation" until BM acts
    else Valuation Rejected OR Legal Rejected
        SFAPP->>LA: Update Status__c = "Rejected"
        SFAPP->>SFAPP: Capture rejection reason from Property_Detail__c
        SFAPP->>SFAPP: Notify Customer: "Application rejected – property/legal issue"
        SFAPP->>LOG: logError("Property evaluation rejected", propertyDetailId)
    end
```

---

## Sequence 5: UPI Mandate Setup

```mermaid
sequenceDiagram
    actor Customer as 🧑‍💼 Customer
    participant CP as Customer Portal
    participant SF as Salesforce Core
    participant MND as Mandate__c
    participant SRV as MandateService.cls
    participant Q as System.enqueueJob()
    participant CALL as MandateCallout.cls (Queueable)
    participant API as UPI Mandate API (NPCI)
    participant LOG as Application_Log__c
    participant PE as Platform Event Bus

    Note over CP: After Loan_Approved__e - Customer sees "Setup Auto-Pay"

    Customer->>CP: Navigate to "Setup Auto-Pay"
    CP->>SF: Load Loan Application details
    SF-->>CP: Show EMI Amount, Tenure

    Customer->>CP: Choose "UPI Mandate"
    Customer->>CP: Enter UPI ID (VPA): rohan.sharma@upi
    Customer->>CP: Click "Setup Mandate"

    CP->>SF: MandateService.createMandateRequest(appId, vpa)
    SF->>MND: Insert Mandate__c (Status: Pending, Type: UPI)
    MND-->>SF: mandateId

    SF->>Q: System.enqueueJob(new MandateQueueable(mandateId))

    Note over CALL: Queueable execution
    CALL->>CALL: Build HMAC-SHA256 signature
    CALL->>API: POST /v1/upi/mandate/create
    Note over CALL,API: Headers: X-API-Key, X-Signature, X-Timestamp

    API-->>CALL: HTTP 202 - {status: PENDING, mandateId: NPCI-xxx, deepLink: upi://...}

    CALL->>MND: Update Provider_Reference__c = mandateId
    CALL->>CP: Return deepLink for customer to confirm in UPI app
    CALL->>LOG: logAPICall(endpoint, request, response, 202)

    CP-->>Customer: Show UPI deep link / QR code
    Customer->>CP: Approves mandate in UPI app

    API->>SF: Webhook Callback: {event: MANDATE_ACTIVATED, mandateId: NPCI-xxx}
    SF->>MND: Update Status__c = "Active"
    SF->>PE: Publish Mandate_Activated__e
    PE-->>Customer: Email: "Mandate setup successful!"
```

---

## Sequence 6: Loan Disbursement

```mermaid
sequenceDiagram
    participant PE as Platform Event Bus
    participant SUB as Event Subscriber
    participant SRV as DisbursementService.cls
    participant Q as System.enqueueJob()
    participant CALL as CoreBankingCallout.cls (Queueable)
    participant NC as Named Credential (CoreBankingNC)
    participant CBS as Core Banking API
    participant DISB as Disbursement__c
    participant BATCH as EMIGenerationBatch
    participant LOG as Application_Log__c
    participant PE2 as Platform Event Bus
    actor Customer as 🧑‍💼 Customer

    PE->>SUB: Mandate_Activated__e received
    SUB->>SRV: DisbursementService.initiateDisbursement(appId)
    SRV->>DISB: Create Disbursement__c (Status: Pending)
    DISB-->>SRV: disbursementId

    SRV->>Q: System.enqueueJob(new CoreBankingCallout(disbursementId))

    Note over CALL: Queueable execution
    CALL->>CALL: Query Loan_Application__c + bank details
    CALL->>CALL: Generate idempotencyKey (disbursementId)

    CALL->>NC: Build request with mTLS + API Key
    NC->>CBS: POST /v1/loans/disburse
    Note over NC,CBS: X-Idempotency-Key prevents double disbursement

    alt HTTP 200 - Success
        CBS-->>NC: {status: SUCCESS, loanAccountNumber: CBS-LA-xxx, utrNumber: HDFC-xxx}
        NC-->>CALL: HttpResponse

        CALL->>DISB: Update Status = "Completed"
        CALL->>DISB: Update Loan_Account_Number__c, UTR_Number__c, Disbursement_Date__c
        CALL->>LOG: logAPICall(endpoint, request, response, 200)

        SRV->>SRV: Update Loan_Application__c Status = "Disbursed"
        SRV->>PE2: Publish Loan_Disbursed__e

        PE2->>BATCH: Trigger EMIGenerationBatch
        BATCH->>BATCH: Generate EMI_Schedule__c records for all months
        BATCH-->>SRV: EMI Schedule created

        SRV->>Customer: Email: "Your loan of ₹5,00,000 has been disbursed!"
        SRV->>Customer: Email: "Your EMI of ₹16,239 starts from 1st July 2026"

    else HTTP 200 - Already Processed (Idempotency)
        CBS-->>CALL: {status: ALREADY_PROCESSED, ...}
        CALL->>DISB: Verify existing disbursement record matches
        CALL->>LOG: logInfo("Idempotent response received", disbursementId)

    else HTTP 422 / 5xx - Failure
        CBS-->>CALL: {status: FAILED, errorCode: INVALID_BANK_ACCOUNT}
        CALL->>DISB: Update Status = "Failed", Failure_Reason__c = errorMessage
        CALL->>LOG: logError("Disbursement failed", response, disbursementId)
        SRV->>SRV: Send admin alert for manual intervention
    end
```

---

## Sequence 7: Collections Follow-Up (Batch Processing)

```mermaid
sequenceDiagram
    participant SCHED as CollectionsScheduler (Daily 8 AM)
    participant BATCH as CollectionsBatch
    participant EMI as EMI_Schedule__c
    participant COLL as Collection_Case__c
    participant ASSIGN as Assignment Logic
    participant OFFICER as Collections Officer
    participant LOG as Application_Log__c

    Note over SCHED: System.schedule fires daily at 8 AM

    SCHED->>BATCH: Database.executeBatch(new CollectionsBatch(), 200)

    loop For each batch of 200 records
        BATCH->>EMI: Query overdue EMIs (Due_Date < Today, Status != Paid)
        EMI-->>BATCH: List of overdue EMI records

        BATCH->>BATCH: Calculate DPD for each EMI
        BATCH->>BATCH: Assign DPD bucket: 1-30, 31-60, 61-90, 90+

        BATCH->>COLL: Upsert Collection_Case__c records
        Note over BATCH,COLL: Skip if case already exists for loan

        BATCH->>ASSIGN: Assign officer based on geography / load balancing
        ASSIGN-->>COLL: Assigned_To__c = Collections Officer Id

        BATCH->>EMI: Update Status = "Overdue"
    end

    BATCH->>LOG: logInfo("CollectionsBatch complete: X success, Y failed")
    OFFICER->>OFFICER: Receives task assignment notification
    OFFICER->>OFFICER: Opens Collections Dashboard LWC
```
