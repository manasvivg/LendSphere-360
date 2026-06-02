# Business Requirements Document (BRD)

## LendSphere 360 – Digital Lending, Servicing & Collections Platform

| Field                | Details                                                     |
| -------------------- | ----------------------------------------------------------- |
| **Document Version** | 1.0                                                         |
| **Status**           | Approved                                                    |
| **Prepared By**      | Manasvi Gharat                                              |
| **Date**             | May 2026                                                    |
| **Platform**         | Salesforce (Sales Cloud + Service Cloud + Experience Cloud) |

---

## 1. Executive Summary

LendSphere 360 is a unified, Salesforce-powered digital lending platform designed for Banks and Non-Banking Financial Companies (NBFCs) operating in India. The platform covers the **complete loan lifecycle** — from lead capture and customer onboarding through loan origination, credit underwriting, mandate setup, loan disbursement, servicing, and collections.

The platform serves **multiple personas** (customers, dealers, sales teams, operations, credit analysts, branch managers, service agents, and collections officers) through a combination of **internal Salesforce applications** and **Experience Cloud portals**.

This document captures the business requirements, pain points, functional scope, and non-functional requirements for LendSphere 360.

---

## 2. Business Context & Problem Statement

### 2.1 Industry Context

Banks and NBFCs operating across India process millions of loan applications annually, spanning product lines that include:

- Personal Loans
- Home Loans
- Vehicle Loans (Two-wheeler, Auto, Car)
- Business Loans
- Gold Loans
- Consumer Durable Loans

### 2.2 Current Pain Points

#### Customer Pain Points

| Pain Point                                         | Impact                                      |
| -------------------------------------------------- | ------------------------------------------- |
| Cannot track loan application status in real time  | High customer anxiety, repeat branch visits |
| Required to physically visit branch multiple times | High cost, time loss                        |
| No visibility into why application was rejected    | Trust erosion                               |
| Must resubmit documents multiple times             | Poor experience                             |
| No self-service EMI schedule download              | Repeated customer service calls             |

#### Dealer Pain Points

| Pain Point                                     | Impact                           |
| ---------------------------------------------- | -------------------------------- |
| Manual, paper-based application process        | Errors, delays, loss of business |
| No visibility into application approval status | Repeated follow-ups with branch  |
| Delayed commission payouts                     | Reduced dealer satisfaction      |
| No digital document submission                 | High TAT                         |

#### Sales Team Pain Points

| Pain Point                                 | Impact                          |
| ------------------------------------------ | ------------------------------- |
| No centralized lead tracking system        | Lead leakage, missed follow-ups |
| Manual lead-to-application conversion      | Data errors                     |
| No visibility into pipeline and conversion | Poor forecasting                |

#### Operations Team Pain Points

| Pain Point                                   | Impact            |
| -------------------------------------------- | ----------------- |
| Missing documents identified late in process | Rework, delays    |
| Manual KYC verification process              | High TAT, errors  |
| No audit trail for verification decisions    | Compliance risk   |
| No centralized document repository           | Version confusion |

#### Credit Team Pain Points

| Pain Point                           | Impact                         |
| ------------------------------------ | ------------------------------ |
| Credit data scattered across systems | Delayed underwriting decisions |
| Manual credit bureau API calls       | Slow and error-prone           |
| No structured risk grading           | Inconsistent decisions         |
| No audit trail for credit decisions  | Regulatory risk                |

#### Customer Service Pain Points

| Pain Point                             | Impact                                    |
| -------------------------------------- | ----------------------------------------- |
| No unified customer 360° view          | Agents cannot resolve queries efficiently |
| No loan statement generation on demand | High call volumes                         |
| Difficulty tracking and closing cases  | SLA breaches                              |

#### Management Pain Points

| Pain Point                                    | Impact                        |
| --------------------------------------------- | ----------------------------- |
| No real-time dashboards                       | Decisions based on stale data |
| No compliance audit trail                     | Regulatory risk               |
| High operational cost due to manual processes | Reduced profitability         |

---

## 3. Objectives

1. **Digitize the end-to-end loan lifecycle** from lead capture to disbursement and collections
2. **Provide self-service portals** for customers and dealers, reducing branch dependency
3. **Automate KYC and credit bureau verification** using external API integrations
4. **Implement event-driven architecture** for decoupled, real-time workflow processing
5. **Enable multi-level approval workflows** with full audit trail
6. **Automate EMI generation, reminders, and collections** follow-up
7. **Provide role-based dashboards** with real-time visibility for all stakeholders

---

## 4. Scope

### 4.1 In Scope

| Module                | Description                                                 |
| --------------------- | ----------------------------------------------------------- |
| Lead Management       | Lead capture, assignment, tracking                          |
| Customer Onboarding   | Account, Contact creation, KYC data capture                 |
| Loan Application      | Multi-product loan application, co-applicant management     |
| KYC Verification      | PAN & Aadhaar verification via API                          |
| Document Management   | Upload, classify, verify, track documents                   |
| Credit Assessment     | Bureau callout, score storage, risk grading                 |
| Property Evaluation   | Property valuation, legal title verification (secured loans)|
| Approval Workflow     | 4-stage approval (Ops → Credit → Property/Legal → Manager) |
| UPI/eNACH Mandate     | Mandate setup, activation tracking                          |
| Loan Disbursement     | Core banking API integration, disbursement record           |
| EMI Schedule          | Auto-generated schedule post-disbursement                   |
| Customer Self-Service | Portal: view loans, EMI, raise cases, download statements   |
| Dealer Portal         | Portal: create applications, track status, view commissions |
| Case Management       | Inbound support cases, routing, SLA tracking                |
| Collections           | Overdue detection, collections case creation, follow-ups    |
| Reporting             | Dashboards for Management, Ops, Credit, Valuation, Collections |

### 4.2 Out of Scope (Phase 1)

- Mobile app (iOS/Android)
- AI/ML-based credit scoring (beyond bureau integration)
- Direct core banking system write-back (mocked)
- Multi-currency support
- Co-lending module

---

## 5. Functional Requirements

### 5.1 Lead Management

| ID        | Requirement                                                                          |
| --------- | ------------------------------------------------------------------------------------ |
| FR-LM-001 | Sales executives shall be able to create Leads with customer contact information     |
| FR-LM-002 | Dealers shall be able to create Leads from the Dealer Portal                         |
| FR-LM-003 | Leads shall be auto-assigned based on geography/product using assignment rules       |
| FR-LM-004 | Leads shall be convertible to Accounts, Contacts, and Opportunities                  |
| FR-LM-005 | Lead status shall be tracked through: New → Contacted → Qualified → Converted → Lost |

### 5.2 Loan Application

| ID        | Requirement                                                                                                                                    |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| FR-LA-001 | System shall support multiple loan product types: Home Loan, Personal Loan, Vehicle Loan, Business Loan                                        |
| FR-LA-002 | Each loan application shall have a unique system-generated Loan Number                                                                         |
| FR-LA-003 | Applications shall support co-applicant capture                                                                                                |
| FR-LA-004 | Application status shall flow through: Draft → Submitted → Under Review → KYC Verified → Credit Assessment → Sanctioned → Rejected → Disbursed |
| FR-LA-005 | On submission, the system shall publish the `Application_Submitted__e` platform event                                                          |
| FR-LA-006 | System shall auto-calculate EMI using: EMI = P × r × (1+r)^n / ((1+r)^n - 1)                                                                   |

### 5.3 KYC Verification

| ID         | Requirement                                                               |
| ---------- | ------------------------------------------------------------------------- |
| FR-KYC-001 | System shall verify PAN number via external KYC API                       |
| FR-KYC-002 | System shall verify Aadhaar number via external KYC API                   |
| FR-KYC-003 | KYC data (PAN, Aadhaar) shall be encrypted at rest using AES-256          |
| FR-KYC-004 | KYC verification results shall be stored on `KYC_Request__c`              |
| FR-KYC-005 | On KYC completion, system shall publish `KYC_Completed__e` platform event |

### 5.4 Document Management

| ID        | Requirement                                                                                                   |
| --------- | ------------------------------------------------------------------------------------------------------------- |
| FR-DM-001 | Customers and Dealers shall be able to upload documents via drag-and-drop interface                           |
| FR-DM-002 | System shall support document types: Identity Proof, Address Proof, Income Proof, Bank Statements, Photograph |
| FR-DM-003 | Operations officers shall be able to mark documents as Verified/Rejected with remarks                         |
| FR-DM-004 | System shall generate document checklist based on loan product type                                           |

### 5.5 Credit Assessment

| ID        | Requirement                                                                                       |
| --------- | ------------------------------------------------------------------------------------------------- |
| FR-CA-001 | System shall automatically call Credit Bureau API upon KYC verification completion                |
| FR-CA-002 | Credit score, bureau report reference, and pull date shall be stored on `Credit_Assessment__c`    |
| FR-CA-003 | System shall auto-calculate risk grade: A (750+), B (700-749), C (650-699), D (600-649), E (<600) |
| FR-CA-004 | Credit analyst shall be notified via email + in-app notification upon score availability          |
| FR-CA-005 | System shall publish `Credit_Assessment_Completed__e` after score storage                         |

### 5.6 Property & Collateral Evaluation

| ID        | Requirement                                                                                                   |
| --------- | ------------------------------------------------------------------------------------------------------------- |
| FR-PE-001 | Property evaluation shall be conditionally triggered based on `Loan_Product__c.Requires_Collateral__c` flag   |
| FR-PE-002 | For secured loan products, a `Property_Detail__c` record shall be created and linked to the Loan Application  |
| FR-PE-003 | Valuation Officer shall capture: property type, address, area, market value, forced sale value, condition      |
| FR-PE-004 | Legal Officer shall verify: title clearance, ownership documents, encumbrance status, and provide legal opinion|
| FR-PE-005 | System shall auto-calculate LTV (Loan-to-Value) ratio as `(Loan_Amount / Market_Value) * 100`                 |
| FR-PE-006 | Both Valuation Officer approval and Legal Officer clearance are required before Branch Manager sanction        |
| FR-PE-007 | Valuation and legal remarks shall be stored on `Property_Detail__c` with full audit trail                     |

### 5.7 Approval Workflow

| ID        | Requirement                                                                                                                              |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| FR-AW-001 | Applications shall go through 4-stage approval: Operations Review → Credit Approval → Property/Legal Evaluation → Branch Manager Sanction |
| FR-AW-002 | Each approver shall receive email notification when action is pending                                                                    |
| FR-AW-003 | Rejected applications shall capture rejection reason                                                                                     |
| FR-AW-004 | Approval decisions shall be fully audited                                                                                                |
| FR-AW-005 | System shall publish `Loan_Approved__e` upon Branch Manager sanction                                                                     |
| FR-AW-006 | For unsecured products, property/legal evaluation stage shall be automatically skipped                                                   |

### 5.8 Mandate Setup

| ID        | Requirement                                                                                           |
| --------- | ----------------------------------------------------------------------------------------------------- |
| FR-MS-001 | Customer shall be able to set up UPI mandate or eNACH from Customer Portal                            |
| FR-MS-002 | System shall call UPI Mandate API with EMI amount, start date, end date, and VPA/bank account details |
| FR-MS-003 | Mandate status shall be tracked: Pending → Active → Failed → Cancelled                                |
| FR-MS-004 | System shall publish `Mandate_Activated__e` upon mandate activation                                   |

### 5.9 Loan Disbursement

| ID        | Requirement                                                                                |
| --------- | ------------------------------------------------------------------------------------------ |
| FR-LD-001 | System shall call Core Banking API via Queueable Apex to disburse loan                     |
| FR-LD-002 | Disbursement details (amount, date, reference number) shall be stored on `Disbursement__c` |
| FR-LD-003 | System shall auto-generate EMI schedule on `EMI_Schedule__c` post-disbursement             |
| FR-LD-004 | System shall publish `Loan_Disbursed__e` upon successful disbursement                      |
| FR-LD-005 | Customer shall receive disbursement confirmation via email and portal notification         |

### 5.10 Collections

| ID        | Requirement                                                                    |
| --------- | ------------------------------------------------------------------------------ |
| FR-CO-001 | Batch Apex shall run daily to detect overdue EMIs (DPD > 0)                    |
| FR-CO-002 | `Collection_Case__c` shall be auto-created for overdue EMIs                    |
| FR-CO-003 | Collections officer shall be auto-assigned based on geography                  |
| FR-CO-004 | Scheduled Apex shall trigger reminder notifications 3 days before EMI due date |
| FR-CO-005 | DPD (Days Past Due) aging buckets: 1-30, 31-60, 61-90, 90+                     |

---

## 6. Non-Functional Requirements

| Category            | Requirement                                                                    |
| ------------------- | ------------------------------------------------------------------------------ |
| **Performance**     | Portal pages shall load within 3 seconds; API callouts shall have 30s timeout  |
| **Security**        | PAN/Aadhaar data encrypted at rest; Role-based access control enforced         |
| **Availability**    | Platform availability governed by Salesforce SLA (99.9% uptime)                |
| **Auditability**    | All API calls, approval decisions, and status changes shall be logged          |
| **Scalability**     | Batch Apex designed to handle 10,000+ records per execution                    |
| **Governor Limits** | All Apex code shall adhere to Salesforce governor limits; bulkified throughout |
| **Compliance**      | Platform shall support RBI data localization requirements                      |
| **Error Handling**  | All exceptions shall be logged to `Application_Log__c`                         |

---

## 7. Assumptions

1. External APIs (Credit Bureau, KYC, Mandate, Core Banking) are configured with mock endpoints; production deployments connect to live integration providers
2. Salesforce Developer Edition or Sandbox org is used for development and validation
3. Document storage uses Salesforce Files (ContentDocument)
4. Email notifications use Salesforce standard email templates
5. UPI mandate follows NPCI UPI AutoPay and eNACH standards

---

## 8. Stakeholders

| Role                | Name/Type | Interest                              |
| ------------------- | --------- | ------------------------------------- |
| Customer            | External  | Loan access, transparency             |
| Dealer              | External  | Commission, fast approvals            |
| Operations Officer  | Internal  | Efficiency, clear queue               |
| Credit Analyst      | Internal  | Complete data, fast tools             |
| Valuation Officer   | Internal  | Timely site visits, clear assignments |
| Legal Officer       | Internal  | Title clarity, legal compliance       |
| Branch Manager      | Internal  | Risk visibility, controls             |
| Service Agent       | Internal  | Customer 360°, resolution             |
| Collections Officer | Internal  | Portfolio visibility                  |
| Management          | Internal  | Real-time KPIs, compliance            |
