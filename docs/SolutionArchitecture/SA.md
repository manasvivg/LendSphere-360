# Solution Architecture Document

## LendSphere 360 – Digital Lending Platform

| Field | Details |
|---|---|
| **Document Version** | 1.0 |
| **Status** | Approved |
| **Prepared By** | Manasvi Gharat |
| **Date** | May 2026 |
| **Classification** | Architecture |

---

## 1. Architecture Overview

LendSphere 360 is built on a **multi-cloud Salesforce architecture** with an **event-driven, API-integrated** design. The platform leverages three Salesforce clouds, six platform events, four external API integrations, and a custom Apex framework modeled after enterprise lending platforms.

### Core Design Principles

| Principle | Implementation |
|---|---|
| **Event-Driven** | Platform Events decouple workflow stages — no direct object triggers across stages |
| **Single Responsibility** | One Trigger per object, one Handler, dedicated Service classes |
| **Configuration-Driven** | Custom Metadata Types drive integration endpoints, risk thresholds, product parameters |
| **Fail-Safe** | All API callouts have retry logic, timeout handling, and are logged to `Application_Log__c` |
| **Bulkification** | All Apex code processes collections; no SOQL/DML inside loops |
| **Security by Design** | PAN/Aadhaar encrypted at rest; Named Credentials for all external endpoints |

---

## 2. Multi-Cloud Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         EXPERIENCE CLOUD                             │
│  ┌──────────────────────┐     ┌──────────────────────────────────┐  │
│  │   Customer Portal    │     │        Dealer Portal             │  │
│  │  - Self Registration │     │  - Application Creation          │  │
│  │  - Loan Application  │     │  - Document Upload               │  │
│  │  - EMI Schedule View │     │  - Application Tracking          │  │
│  │  - Raise Cases       │     │  - Commission View               │  │
│  │  - Mandate Setup     │     │                                  │  │
│  └──────────────────────┘     └──────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                              Salesforce Core
                                    │
┌──────────────────────────────────┬──────────────────────────────────┐
│         SALES CLOUD              │          SERVICE CLOUD            │
│  Lead Management                 │  Case Management                  │
│  Account / Contact               │  Service Console                  │
│  Loan Application                │  Service Level Agreements         │
│  Opportunity Pipeline            │  Entitlements                     │
│  Approval Workflows              │  Email-to-Case                    │
└──────────────────────────────────┴──────────────────────────────────┘
                                    │
                      ┌─────────────────────────┐
                      │   PLATFORM EVENT BUS     │
                      │  Application_Submitted   │
                      │  KYC_Completed           │
                      │  Credit_Assessment_Done  │
                      │  Loan_Approved           │
                      │  Mandate_Activated       │
                      │  Loan_Disbursed          │
                      └─────────────────────────┘
                                    │
┌──────────────────────────────────────────────────────────────────────┐
│                        INTEGRATION LAYER                              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────┐  │
│  │ Credit Bureau│ │KYC Verify API│ │ UPI Mandate  │ │Core Banking│  │
│  │     API      │ │              │ │     API      │ │    API     │  │
│  │  (CIBIL /    │ │ PAN + Aadhaar│ │ NPCI / eNACH │ │  CBS       │  │
│  │  Experian)   │ │ Verification │ │              │ │            │  │
│  └──────────────┘ └──────────────┘ └──────────────┘ └────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 3. Cloud Architecture Detail

### 3.1 Sales Cloud

**Primary Purpose**: Loan Origination

| Object/Feature | Purpose |
|---|---|
| Lead | Prospective customer capture |
| Account | Customer master record |
| Contact | Customer contact details |
| Opportunity | Loan pipeline tracking |
| `Loan_Application__c` | Core loan application record |
| `Loan_Product__c` | Product catalog |
| Approval Processes | 3-stage loan approval |

**Sales Cloud Automation:**
- Lead Assignment Rules → geography/product-based routing
- Flow: Application Submission → validate → publish Platform Event
- Flow: Status update notifications to customers
- Approval Process: Operations → Credit → Manager

---

### 3.2 Service Cloud

**Primary Purpose**: Post-Disbursement Customer Service

| Feature | Purpose |
|---|---|
| Case | Customer support requests, disputes, statement requests |
| Case Queues | Route to appropriate service team |
| Email-to-Case | Inbound email creates cases automatically |
| SLA/Entitlements | Track case resolution time |
| Service Console | Agent view: 360° customer + case detail |
| Omni-Channel | Route cases across channels |

**Service Cloud Custom Data:**
- Cases linked to `Loan_Application__c` for loan-specific queries
- `EMI_Schedule__c` visible in Service Console for EMI queries
- `Collection_Case__c` linked to overdue cases

---

### 3.3 Experience Cloud

**Portal A: Customer Portal**

| Page | Purpose |
|---|---|
| Registration / Login | Self-service onboarding |
| Dashboard | Active loans, upcoming EMI, notifications |
| Apply for Loan | Loan Application Wizard LWC |
| My Applications | Status tracker |
| Documents | Upload & view uploaded documents |
| EMI Schedule | View repayment table |
| Mandate Setup | UPI / eNACH mandate setup |
| Support | Raise case, track case status |

**Portal B: Dealer Portal**

| Page | Purpose |
|---|---|
| Login | Dealer authentication |
| Create Application | Submit applications on behalf of customers |
| My Applications | Track all submitted applications |
| Documents | Upload customer documents |
| Commission | View commission status |

---

## 4. Integration Architecture

### 4.1 Integration Design Principles

- All integrations use **Named Credentials** for endpoint/auth management
- All callouts are wrapped in **try-catch** with full **request/response logging**
- **Custom Metadata Types** store API configuration (endpoint, timeout, retry count)
- **EncryptionUtil.cls** used for sensitive data before transmission
- All integrations are designed for **Queueable execution** to avoid synchronous limits

### 4.2 Integration Inventory

| Integration | Direction | Auth Method | Trigger | Apex Class |
|---|---|---|---|---|
| Credit Bureau (CIBIL/Experian) | Outbound | OAuth 2.0 | KYC_Completed__e | `CreditBureauCallout.cls` |
| KYC Verification (PAN/Aadhaar) | Outbound | API Key | Operations action | `KYCCallout.cls` |
| UPI Mandate (NPCI/eNACH) | Outbound | HMAC + API Key | Customer action | `MandateCallout.cls` |
| Core Banking System | Outbound | mTLS + API Key | Mandate_Activated__e | `CoreBankingCallout.cls` |

### 4.3 Integration Error Handling

```
API Call Attempt
    │
    ├── Success (2xx) → Parse response → Store result → Publish event
    │
    └── Failure
            ├── 4xx Client Error → Log to Application_Log__c → Do not retry → Notify team
            ├── 5xx Server Error → Log → Retry up to 3 times (exponential backoff)
            ├── Timeout → Log → Enqueue retry
            └── Exception → Log stacktrace → Notify admin via email alert
```

---

## 5. Apex Architecture

### 5.1 Trigger Framework

```
TriggerHandler.cls (Abstract Base Class)
├── Properties: isExecuting, isBefore, isAfter, isInsert, isUpdate, isDelete
├── Abstract Methods: beforeInsert(), afterInsert(), beforeUpdate(), afterUpdate(), ...
└── run() method: calls appropriate abstract methods

Per-Object Trigger (One per object):
  trigger LoanApplicationTrigger on Loan_Application__c (before insert, before update, after insert, after update) {
      new LoanApplicationTriggerHandler().run();
  }

Handler Class:
  LoanApplicationTriggerHandler extends TriggerHandler {
      override void afterInsert() { LoanApplicationService.onInsert(Trigger.new); }
      override void afterUpdate() { LoanApplicationService.onUpdate(Trigger.new, Trigger.oldMap); }
  }
```

**Benefits:**
- Prevents multiple triggers on one object
- Easily disable trigger execution via Custom Metadata
- Clean separation of trigger vs. business logic

### 5.2 Service Layer

```
LoanApplicationService.cls
├── onInsert(List<Loan_Application__c> newList)
├── onUpdate(List<Loan_Application__c> newList, Map<Id,Loan_Application__c> oldMap)
├── submitApplication(Id applicationId)
├── generateLoanNumber(Loan_Application__c app)
└── calculateEMI(Decimal principal, Decimal rate, Integer tenure)

CreditService.cls
├── initiateCreditAssessment(Id applicationId)
├── storeCreditScore(Id applicationId, CreditBureauResponse response)
├── calculateRiskGrade(Integer creditScore)
└── notifyCreditAnalyst(Id applicationId)

KYCService.cls
├── initiateKYC(Id kycRequestId)
├── processKYCResponse(Id kycRequestId, KYCResponse response)
└── publishKYCCompletedEvent(Id applicationId)

MandateService.cls
├── createMandateRequest(Id applicationId)
├── processMandateResponse(Id mandateId, MandateResponse response)
└── publishMandateActivatedEvent(Id mandateId)

DisbursementService.cls
├── initiateDisbursement(Id applicationId)
├── processDisbursementResponse(Id applicationId, DisbursementResponse response)
├── generateEMISchedule(Id disbursementId)
└── publishLoanDisbursedEvent(Id disbursementId)

CollectionService.cls
├── detectOverdueEMIs()
├── createCollectionCases(List<EMI_Schedule__c> overdueEMIs)
├── assignCollectionsCases(List<Collection_Case__c> cases)
└── sendPaymentReminders(List<EMI_Schedule__c> upcomingEMIs)
```

### 5.3 Utility Layer

```
EncryptionUtil.cls
├── encrypt(String plainText) : String           // AES-256-CBC
├── decrypt(String encryptedText) : String
└── hashForSearch(String value) : String         // SHA-256 for search-safe hashing

JsonUtil.cls
├── serialize(Object obj) : String
├── deserialize(String json, Type t) : Object
└── parseApiResponse(String json) : Map<String,Object>

DateUtil.cls
├── calculateEMIDates(Date startDate, Integer tenure) : List<Date>
├── calculateDPD(Date dueDate) : Integer
└── getNextWorkingDay(Date d) : Date

ApplicationLogger.cls
├── logInfo(String message, Id relatedId, String className)
├── logError(String message, String stackTrace, Id relatedId, String className)
├── logAPICall(String endpoint, String request, String response, Integer statusCode)
└── logException(Exception e, Id relatedId, String className)
```

---

## 6. Platform Event Architecture

### Event Flow

```
[Loan Application Submitted]
         │
         ▼
Application_Submitted__e Published
         │
         ▼
[EventBus Subscriber] → Operations Queue Assignment → Notification to Ops Team

[KYC Verification Completed]
         │
         ▼
KYC_Completed__e Published
         │
         ▼
[EventBus Subscriber] → Enqueue CreditBureauCallout Queueable

[Credit Assessment Completed]
         │
         ▼
Credit_Assessment_Completed__e Published
         │
         ▼
[EventBus Subscriber] → Notify Credit Analyst → Update Application Status

[Loan Approved by Branch Manager]
         │
         ▼
Loan_Approved__e Published
         │
         ▼
[EventBus Subscriber] → Create Mandate Request → Notify Customer

[Mandate Activated]
         │
         ▼
Mandate_Activated__e Published
         │
         ▼
[EventBus Subscriber] → Enqueue DisbursementQueueable

[Loan Disbursed]
         │
         ▼
Loan_Disbursed__e Published
         │
         ▼
[EventBus Subscriber] → Trigger EMIGenerationBatch → Customer Notification
```

---

## 7. Security Architecture

### 7.1 OWD (Organization-Wide Defaults)

| Object | Internal OWD | External OWD |
|---|---|---|
| `Loan_Application__c` | Private | Private |
| `KYC_Request__c` | Private | Private |
| `Document__c` | Private | Private |
| `Credit_Assessment__c` | Private | No Access |
| `Property_Detail__c` | Private | No Access |
| `Mandate__c` | Private | Private |
| `Disbursement__c` | Private | Private |
| `EMI_Schedule__c` | Private | Private |
| `Collection_Case__c` | Private | No Access |
| `Application_Log__c` | Private | No Access |

### 7.2 Role Hierarchy

```
CEO / Management
    │
    ├── Branch Manager
    │       ├── Operations Officer
    │       ├── Credit Analyst
    │       ├── Valuation Officer
    │       ├── Legal Officer
    │       └── Customer Service Agent
    │
    └── Collections Manager
            └── Collections Officer
```

### 7.3 Permission Sets

| Permission Set | Assigned To |
|---|---|
| `LendSphere_Operations_PS` | Operations Officers |
| `LendSphere_Credit_PS` | Credit Analysts |
| `LendSphere_Valuation_PS` | Valuation Officers |
| `LendSphere_Legal_PS` | Legal Officers |
| `LendSphere_BranchManager_PS` | Branch Managers |
| `LendSphere_ServiceAgent_PS` | Customer Service Agents |
| `LendSphere_Collections_PS` | Collections Officers |
| `LendSphere_Customer_PS` | Customer Portal Users |
| `LendSphere_Dealer_PS` | Dealer Portal Users |

### 7.4 Data Security

| Data | Protection Method |
|---|---|
| PAN Number | AES-256 encryption at rest, masked in UI |
| Aadhaar Number | AES-256 encryption at rest, last 4 digits only in UI |
| Bank Account Number | Masked (XXXX last 4 digits) |
| API Keys | Named Credentials (never in Apex code) |
| Passwords | Salesforce standard hashing |

---

## 8. DevOps Architecture

### Source Control Strategy

```
main (protected)
    │
    ├── develop
    │       ├── feature/loan-application-wizard
    │       ├── feature/credit-bureau-integration
    │       └── feature/emi-generation-batch
    │
    └── release/v1.0
```

### Deployment Strategy

| Environment | Purpose | Deploy Method |
|---|---|---|
| Developer Sandbox | Development | SFDX Push |
| QA Sandbox | Testing | SFDX Deploy |
| UAT Sandbox | User Acceptance | SFDX Deploy |
| Production | Live | Change Set / SFDX |

### SFDX Commands Reference

```bash
# Authenticate
sf org login web --alias LendSphere-Dev

# Deploy
sf project deploy start --source-dir force-app --target-org LendSphere-Dev

# Run Tests
sf apex run test --test-level RunLocalTests --target-org LendSphere-Dev --result-format human

# Create Scratch Org
sf org create scratch --definition-file config/project-scratch-def.json --alias LendSphere-Scratch

# Generate Password for Scratch Org
sf org generate password --target-org LendSphere-Scratch
```
