# High Level Design (HLD)

## LendSphere 360 – Digital Lending Platform

| Field | Details |
|---|---|
| **Document Version** | 1.0 |
| **Status** | Approved |
| **Prepared By** | Manasvi Gharat |
| **Date** | May 2026 |

---

## 1. System Context Diagram

```mermaid
graph TD
    Customer["🧑‍💼 Customer\n(External)"] 
    Dealer["🏪 Dealer\n(External)"]
    SalesExec["👤 Sales Executive\n(Internal)"]
    OpsOfficer["🔍 Operations Officer\n(Internal)"]
    CreditAnalyst["📊 Credit Analyst\n(Internal)"]
    BranchMgr["🏦 Branch Manager\n(Internal)"]
    ServiceAgent["🎧 Service Agent\n(Internal)"]
    CollOfficer["📋 Collections Officer\n(Internal)"]

    LendSphere["🌐 LendSphere 360\nSalesforce Platform"]

    CreditBureau["💳 Credit Bureau API\n(CIBIL/Experian)"]
    KYCApi["🪪 KYC Verify API\n(PAN/Aadhaar)"]
    MandateApi["📱 UPI Mandate API\n(NPCI)"]
    BankingApi["🏦 Core Banking API\n(CBS)"]

    Customer -->|Customer Portal| LendSphere
    Dealer -->|Dealer Portal| LendSphere
    SalesExec -->|Salesforce App| LendSphere
    OpsOfficer -->|Salesforce App| LendSphere
    CreditAnalyst -->|Salesforce App| LendSphere
    BranchMgr -->|Salesforce App| LendSphere
    ServiceAgent -->|Service Console| LendSphere
    CollOfficer -->|Collections App| LendSphere

    LendSphere -->|Credit Enquiry| CreditBureau
    LendSphere -->|PAN/Aadhaar Verify| KYCApi
    LendSphere -->|Mandate Setup| MandateApi
    LendSphere -->|Loan Disbursement| BankingApi
```

---

## 2. End-to-End Loan Lifecycle Flow

```mermaid
flowchart TD
    A["🟢 Lead Captured\n(Sales / Dealer / Customer)"] --> B["Customer Onboarded\n(Account + Contact Created)"]
    B --> C["Loan Application Created\n(Status: Draft)"]
    C --> D["Documents Uploaded\n(Customer / Dealer Portal)"]
    D --> E["Application Submitted\n(Status: Submitted)\n📣 Application_Submitted__e"]
    
    E --> F["Operations Review\n(Document + KYC Verification)"]
    F --> G{"KYC\nPassed?"}
    
    G -->|No| H["🔴 Application Rejected\n(KYC Failed)\nCustomer Notified"]
    G -->|Yes| I["📣 KYC_Completed__e Published\n(Status: KYC Verified)"]
    
    I --> J["🤖 Auto: Credit Bureau API Called\n(Queueable Apex)"]
    J --> K["Credit Score Stored\nRisk Grade Calculated\n📣 Credit_Assessment_Completed__e"]
    
    K --> L["Credit Analyst Reviews\nApprove / Reject"]
    L --> M{"Credit\nApproved?"}
    
    M -->|No| N["🔴 Application Rejected\n(Credit Declined)\nCustomer Notified"]
    M -->|Yes| M2{"Secured\nProduct?"}
    
    M2 -->|No| O["Branch Manager Reviews\nFinal Sanction"]
    M2 -->|Yes| PE1["Property Evaluation Assigned\n(Valuation Officer + Legal Officer)"]
    PE1 --> PE2["Valuation Officer: Site Visit\nMarket Value + FSV Assessed"]
    PE2 --> PE3["Legal Officer: Title Verification\nOwnership + Encumbrance Check"]
    PE3 --> PE4{"Valuation &\nLegal Cleared?"}
    
    PE4 -->|No| PE5["🔴 Application Rejected\n(Property/Legal Issue)\nCustomer Notified"]
    PE4 -->|Yes| O
    
    O --> P{"Sanctioned?"}
    
    P -->|No| Q["🔴 Application Rejected\n(Sanction Declined)\nCustomer Notified"]
    P -->|Yes| R["📣 Loan_Approved__e Published\n(Status: Sanctioned)\nSanction Letter Sent"]
    
    R --> S["Customer Sets Up Mandate\n(UPI / eNACH)"]
    S --> T["🤖 Auto: UPI Mandate API Called\n(Queueable Apex)"]
    T --> U{"Mandate\nActivated?"}
    
    U -->|No| V["🔴 Mandate Failed\nCustomer Retries"]
    V --> S
    U -->|Yes| W["📣 Mandate_Activated__e Published\n(Status: Mandate Active)"]
    
    W --> X["🤖 Auto: Core Banking API Called\n(Queueable Apex - Disbursement)"]
    X --> Y["📣 Loan_Disbursed__e Published\n(Status: Disbursed)\nDisb. Confirmation Sent"]
    
    Y --> Z["EMI Schedule Auto-Generated\n(Batch Apex)"]
    Z --> AA["🟢 Loan Servicing Active\n(EMIs, Cases, Collections)"]
```

---

## 3. Component Interaction Diagram

```mermaid
graph LR
    subgraph "Experience Cloud"
        CP["Customer Portal"]
        DP["Dealer Portal"]
    end

    subgraph "Sales Cloud"
        LA["Loan Application"]
        OP["Opportunity"]
        LD["Lead"]
    end

    subgraph "Service Cloud"
        CASE["Case Management"]
        CONS["Service Console"]
    end

    subgraph "Platform Events"
        PE["Event Bus\n(6 Events)"]
    end

    subgraph "Apex Framework"
        TF["Trigger Framework"]
        SL["Service Layer"]
        IL["Integration Layer"]
        UL["Utility Layer"]
        AQ["Async (Queueable)"]
        BA["Batch Apex"]
        SC["Scheduled Apex"]
    end

    subgraph "Data Layer"
        OBJ["Custom Objects\n(11 objects)"]
        LOG["Application_Log__c"]
        CMD["Custom Metadata"]
    end

    subgraph "External APIs"
        CB["Credit Bureau"]
        KYC["KYC API"]
        UPI["Mandate API"]
        CBS["Core Banking"]
    end

    CP --> LA
    DP --> LA
    LA --> TF --> SL
    SL --> PE
    SL --> OBJ
    SL --> IL
    PE --> AQ
    AQ --> IL
    IL --> CB & KYC & UPI & CBS
    IL --> LOG
    BA --> OBJ
    SC --> BA
    OBJ --> CASE
    CASE --> CONS
    CMD --> SL & IL
```

---

## 4. Module Interaction Matrix

| Module | Depends On | Feeds Into |
|---|---|---|
| Lead Management | - | Customer Onboarding |
| Customer Onboarding | Lead Management | Loan Application |
| Loan Application | Customer Onboarding, Loan Product | KYC, Document Management, Approval |
| KYC Verification | Loan Application | Credit Assessment |
| Document Management | Loan Application | Operations Review |
| Credit Assessment | KYC Verification, Credit Bureau API | Property Evaluation (secured) / Approval Workflow (unsecured) |
| Property Evaluation | Credit Assessment, Loan Product Config | Approval Workflow |
| Approval Workflow | Credit Assessment, Property Evaluation, Document Management | Mandate Setup |
| Mandate Setup | Approval Workflow, UPI API | Disbursement |
| Loan Disbursement | Mandate Setup, Core Banking API | EMI Schedule, Servicing |
| EMI Schedule | Disbursement | Collections, Customer Portal |
| Collections | EMI Schedule | Collection Cases |
| Case Management | Loan Application, EMI Schedule | Service Console |

---

## 5. Platform Event Flow Design

```mermaid
sequenceDiagram
    participant App as Loan Application
    participant PEB as Platform Event Bus
    participant OPS as Operations Handler
    participant CRD as Credit Handler
    participant MND as Mandate Handler
    participant DSB as Disbursement Handler
    participant EMI as EMI Generator

    App->>PEB: Publish Application_Submitted__e
    PEB->>OPS: Subscribe → Route to Operations Queue

    OPS->>PEB: Publish KYC_Completed__e
    PEB->>CRD: Subscribe → Enqueue Credit Bureau Callout

    CRD->>PEB: Publish Credit_Assessment_Completed__e
    PEB->>App: Subscribe → Notify Credit Analyst

    App->>PEB: Publish Loan_Approved__e (after BM sanction)
    PEB->>MND: Subscribe → Trigger Mandate Request to Customer

    MND->>PEB: Publish Mandate_Activated__e
    PEB->>DSB: Subscribe → Enqueue Disbursement Queueable

    DSB->>PEB: Publish Loan_Disbursed__e
    PEB->>EMI: Subscribe → Trigger EMI Generation Batch
```

---

## 6. Async Processing Design

```mermaid
graph TD
    E1["Mandate_Activated__e"] --> Q1["DisbursementQueueable\n(enqueued)"]
    E2["KYC_Completed__e"] --> Q2["CreditBureauQueueable\n(enqueued)"]
    E3["Customer Action"] --> Q3["MandateQueueable\n(enqueued)"]
    
    Q1 --> CBS["Core Banking API"]
    Q2 --> CB["Credit Bureau API"]
    Q3 --> UPI["Mandate API"]
    
    CBS -->|Success| D1["Create Disbursement__c\nPublish Loan_Disbursed__e"]
    CBS -->|Failure| L1["Log Error\nAlert Admin"]
    
    SCHED["Scheduled Apex\n(Daily 8 AM)"] --> BATCH["CollectionsBatch\n(Batch Apex)"]
    BATCH --> COL["Detect Overdue EMIs\nCreate Collection_Case__c"]
    
    SCHED2["Scheduled Apex\n(Daily 6 PM)"] --> BATCH2["EMIReminderBatch"]
    BATCH2 --> REM["Send Reminder\n3 days before due date"]
```

---

## 7. Security Model Overview

```mermaid
graph TD
    subgraph "External Access"
        CUST["Customer\n(Portal User)"]
        DEAL["Dealer\n(Portal User)"]
    end

    subgraph "Internal Access"
        OPS["Operations Officer\nPermission Set: Ops_PS"]
        CA["Credit Analyst\nPermission Set: Credit_PS"]
        BM["Branch Manager\nPermission Set: BM_PS"]
        SA["Service Agent\nPermission Set: SA_PS"]
        CO["Collections Officer\nPermission Set: Coll_PS"]
    end

    subgraph "Data Access"
        LOAN["Loan_Application__c\nOWD: Private"]
        KYC2["KYC_Request__c\nOWD: Private"]
        CREDIT["Credit_Assessment__c\nOWD: Private"]
        COLL2["Collection_Case__c\nOWD: Private"]
    end

    CUST -->|"Own records only\n(Sharing: Portal User)"| LOAN
    DEAL -->|"Own + Referred records"| LOAN
    OPS -->|"Assigned queue records"| LOAN & KYC2
    CA -->|"Referred by Ops"| CREDIT & LOAN
    BM -->|"Full org visibility\n(Role Hierarchy)"| LOAN & CREDIT
    SA -->|"Customer account records"| LOAN
    CO -->|"Assigned DPD records"| COLL2
```

---

## 8. LWC Component Architecture

```mermaid
graph TD
    subgraph "Customer Portal"
        LAW["loanApplicationWizard\n(Multi-step form)"]
        CD["customerDashboard\n(Active loans, EMI due)"]
        LT["loanTracker\n(Status timeline)"]
        DU["documentUpload\n(Drag & drop)"]
        EC["emiCalculator\n(Calculator)"]
    end

    subgraph "Internal Apps"
        CSV["creditScoreViewer\n(Gauge chart)"]
        COLLD["collectionsDashboard\n(DPD aging)"]
        DU2["documentUpload\n(Shared)"]
    end

    subgraph "Salesforce Services"
        WA["@wire adapters"]
        IMP["Imperative Apex calls"]
        PE2["Platform Events\n(empApi)"]
        NAV["NavigationMixin"]
    end

    LAW --> IMP
    CD --> WA
    LT --> WA
    CSV --> IMP
    COLLD --> WA
    DU --> IMP
    EC --> |"Pure JS calculation"| EC
    CD --> PE2
```
