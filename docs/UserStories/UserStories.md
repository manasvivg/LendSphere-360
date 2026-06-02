# User Stories

## LendSphere 360 – Agile User Stories

All user stories are written in **BDD format**: *Given / When / Then*

| Field | Details |
|---|---|
| **Document Version** | 1.0 |
| **Status** | Baselined |
| **Prepared By** | Manasvi Gharat |
| **Sprint Mapping** | Stories are grouped by module/epic |

---

## Epic 1: Lead Management

---

### US-001 – Create Lead as Sales Executive

**As a** Sales Executive,
**I want to** create a new Lead in Salesforce with customer contact details and product interest,
**So that** I can track the prospective customer and follow up systematically.

**Acceptance Criteria:**

```gherkin
Given I am logged into the Salesforce internal app as a Sales Executive
When I navigate to the Leads tab and fill in: First Name, Last Name, Mobile, Email, City, Loan Product Interest, Estimated Loan Amount
Then a new Lead record is created with Status = "New"
And the lead is auto-assigned to me based on assignment rules
And an introductory email is sent to the customer
```

**Priority:** High | **Story Points:** 3

---

### US-002 – Create Lead from Dealer Portal

**As a** Dealer,
**I want to** create a customer lead directly from the Dealer Portal,
**So that** I can initiate a loan application on behalf of my customer without visiting a branch.

**Acceptance Criteria:**

```gherkin
Given I am logged into the Dealer Portal
When I navigate to "New Application" and enter customer details
Then a Lead record is created in Salesforce linked to my Dealer Account
And the status is set to "New"
And a confirmation is shown on the portal with a reference number
```

**Priority:** High | **Story Points:** 5

---

### US-003 – Convert Lead to Loan Application

**As a** Sales Executive,
**I want to** convert a qualified Lead into an Account, Contact, and Loan Application,
**So that** the formal loan origination process can begin.

**Acceptance Criteria:**

```gherkin
Given a Lead exists with Status = "Qualified"
When I click "Convert" and confirm the conversion
Then an Account and Contact are created from the Lead data
And a Loan_Application__c record is created with Status = "Draft"
And the Lead is marked as Converted
```

**Priority:** High | **Story Points:** 5

---

## Epic 2: Customer Onboarding

---

### US-004 – Customer Self-Registration on Portal

**As a** Customer,
**I want to** register myself on the Customer Portal,
**So that** I can apply for a loan without visiting a branch.

**Acceptance Criteria:**

```gherkin
Given I navigate to the Customer Portal registration page
When I enter: Name, Mobile, Email, PAN, DOB, City and submit
Then a Contact and Account are created in Salesforce
And I receive an email with my portal login credentials
And my portal profile shows my registered details
```

**Priority:** High | **Story Points:** 8

---

### US-005 – Upload Documents from Customer Portal

**As a** Customer,
**I want to** upload my KYC and income documents from the Customer Portal,
**So that** I do not need to physically visit a branch to submit documents.

**Acceptance Criteria:**

```gherkin
Given I am logged into the Customer Portal and have an active Loan Application
When I navigate to the Documents section and drag-and-drop files
Then the documents are uploaded and linked to my Loan Application
And each document shows status "Uploaded - Pending Verification"
And the Operations team can see the documents in the verification queue
```

**Priority:** High | **Story Points:** 5

---

## Epic 3: Loan Application

---

### US-006 – Submit Loan Application (Customer)

**As a** Customer,
**I want to** fill and submit a loan application online,
**So that** I can apply for a loan from the comfort of my home.

**Acceptance Criteria:**

```gherkin
Given I am logged into the Customer Portal
When I complete the multi-step loan application wizard:
  Step 1: Personal Details
  Step 2: Loan Details (product, amount, tenure)
  Step 3: Employment/Income Details
  Step 4: Document Upload
  Step 5: Review and Submit
Then the Loan Application status changes from "Draft" to "Submitted"
And a Loan Reference Number is generated and displayed
And the Application_Submitted__e platform event is published
And the application appears in the Operations team queue
```

**Priority:** Critical | **Story Points:** 13

---

### US-007 – View Application Status (Customer)

**As a** Customer,
**I want to** track the status of my loan application in real time,
**So that** I know exactly where my application is in the process without calling the bank.

**Acceptance Criteria:**

```gherkin
Given I am logged into the Customer Portal
When I navigate to "My Applications"
Then I can see all my loan applications with current status
And a visual tracker shows the lifecycle stages
And I can see the date/time of the last status change
And any remarks from the operations or credit team are visible
```

**Priority:** High | **Story Points:** 5

---

### US-008 – Dealer Creates Application for Customer

**As a** Dealer,
**I want to** create a loan application on behalf of my customer,
**So that** I can facilitate faster loan processing for my customers at point of sale.

**Acceptance Criteria:**

```gherkin
Given I am logged into the Dealer Portal
When I create a new application by searching/creating a customer and filling loan details
Then a Loan_Application__c record is created with the Dealer Account linked
And all documents uploaded are tagged with my dealer reference
And the customer receives an email notification that an application has been submitted
```

**Priority:** High | **Story Points:** 8

---

## Epic 4: KYC Verification

---

### US-009 – Verify Customer KYC (Operations Officer)

**As an** Operations Officer,
**I want to** verify a customer's PAN and Aadhaar via the system,
**So that** I can complete KYC without manual document scrutiny and reduce errors.

**Acceptance Criteria:**

```gherkin
Given a Loan Application is in "Submitted" status in my Operations queue
When I open the KYC_Request__c record and click "Initiate Verification"
Then the system calls the KYC API with the customer's PAN and Aadhaar
And the verification result (Verified/Failed) is stored on the KYC record
And if Verified: status updates to "KYC Verified" and KYC_Completed__e event is published
And if Failed: status updates to "KYC Failed" and a rejection reason is recorded
```

**Priority:** Critical | **Story Points:** 8

---

## Epic 5: Credit Assessment

---

### US-010 – Auto Credit Bureau Pull

**As the** System,
**I want to** automatically call the Credit Bureau API when KYC is verified,
**So that** credit assessment can begin without manual intervention.

**Acceptance Criteria:**

```gherkin
Given KYC_Completed__e platform event is published
When the platform event trigger handler fires
Then a Queueable Apex job is enqueued to call the Credit Bureau API
And the Credit_Assessment__c record is created with the score and risk grade
And Credit_Assessment_Completed__e platform event is published
And the assigned Credit Analyst receives an email notification
```

**Priority:** Critical | **Story Points:** 8

---

### US-011 – Review Credit Assessment (Credit Analyst)

**As a** Credit Analyst,
**I want to** review the bureau score and risk assessment,
**So that** I can make an informed credit decision on the loan application.

**Acceptance Criteria:**

```gherkin
Given Credit_Assessment_Completed__e has been published for a loan application
When I open the Credit Score Viewer LWC on the application record
Then I can see: Credit Score, Risk Grade, Bureau Reference, Pull Date
And I can see a visual gauge showing the score range
And I can see the full Loan Application details alongside
And I can click "Approve Credit" or "Reject with Reason"
```

**Priority:** High | **Story Points:** 5

---

## Epic 6: Property & Collateral Evaluation

---

### US-012 – Assign Property Valuation (System)

**As the** System,
**I want to** automatically create a Property Evaluation assignment when credit assessment is approved for a secured loan product,
**So that** the valuation and legal verification process begins without manual intervention.

**Acceptance Criteria:**

```gherkin
Given a loan application has passed Credit Assessment
And the linked Loan Product has Requires_Collateral__c = true
When Credit_Assessment_Completed__e is consumed and the analyst approves
Then a Property_Detail__c record is created linked to the Loan Application
And the record is assigned to the Property Valuation Queue
And the Valuation Officer and Legal Officer receive notifications
And the application status changes to "Property Evaluation"
```

**Priority:** High | **Story Points:** 5

---

### US-013 – Complete Property Valuation (Valuation Officer)

**As a** Valuation Officer,
**I want to** capture property details and submit a valuation report after site visit,
**So that** the Branch Manager has accurate collateral value for the sanction decision.

**Acceptance Criteria:**

```gherkin
Given a Property_Detail__c record is assigned to me in the Valuation Queue
When I open the Property Valuation Form LWC
And I capture: Property Type, Address, Area, Construction Status, Market Value, Forced Sale Value
And I upload site visit photos and valuation report
And I submit the valuation as "Approved" or "Rejected"
Then the Property_Detail__c record is updated with all details
And LTV ratio is auto-calculated
And if Rejected: the application is flagged with rejection remarks
```

**Priority:** High | **Story Points:** 8

---

### US-014 – Legal Title Verification (Legal Officer)

**As a** Legal Officer,
**I want to** verify the property title, ownership documents, and encumbrance status,
**So that** the institution is protected against title disputes on the collateral.

**Acceptance Criteria:**

```gherkin
Given a Property_Detail__c record exists for a loan application
When I review the property ownership documents
And I complete: Title Status (Clear/Disputed/Encumbered), Ownership Type, Legal Remarks
And I mark Legal Verification as "Cleared" or "Rejected"
Then the Property_Detail__c record is updated
And if both Valuation and Legal are cleared: the application routes to Branch Manager
And if Rejected: the application is rejected with legal rejection reason
```

**Priority:** High | **Story Points:** 5

---

## Epic 7: Approval Workflow

---

### US-015 – Operations Officer Approval

**As an** Operations Officer,
**I want to** review and approve the KYC and document verification,
**So that** the application moves forward to the credit team.

**Acceptance Criteria:**

```gherkin
Given a loan application is in "Under Review" status
When I verify all documents are Verified and KYC is passed
And I click "Approve" in the Approval Process
Then the application moves to "KYC Verified" status
And the Credit Analyst receives a notification to begin assessment
```

**Priority:** High | **Story Points:** 3

---

### US-016 – Branch Manager Final Sanction

**As a** Branch Manager,
**I want to** review the fully assessed loan application and provide final sanction,
**So that** the loan can be disbursed to the customer.

**Acceptance Criteria:**

```gherkin
Given Credit Analyst has approved the application
And for secured products: Valuation Officer and Legal Officer have both cleared the property
When I review the application, credit score, property valuation (if applicable), and loan terms
And I click "Sanction Loan"
Then the application status changes to "Sanctioned"
And Loan_Approved__e platform event is published
And the customer receives a sanction letter via email
And the system triggers the Mandate setup process
```

**Priority:** Critical | **Story Points:** 5

---

## Epic 8: Mandate Setup

---

### US-017 – Setup UPI Mandate (Customer)

**As a** Customer,
**I want to** set up a UPI mandate for auto-debit of my EMIs,
**So that** I never miss an EMI payment.

**Acceptance Criteria:**

```gherkin
Given my loan has been sanctioned and I receive a mandate request notification
When I log into the Customer Portal and navigate to "Setup Auto-Pay"
And I enter my UPI ID (VPA) and confirm the mandate
Then the system calls the UPI Mandate API
And if successful: Mandate status becomes "Active" and Mandate_Activated__e is published
And if failed: I see an error message and can retry or switch to eNACH
```

**Priority:** High | **Story Points:** 8

---

## Epic 9: Loan Disbursement

---

### US-018 – Loan Disbursement via Core Banking

**As the** System,
**I want to** disburse the loan to the customer's bank account upon mandate activation,
**So that** the disbursement happens automatically without manual banking team intervention.

**Acceptance Criteria:**

```gherkin
Given Mandate_Activated__e event has been published
When the Queueable Apex fires and calls the Core Banking API
Then a Disbursement__c record is created with disbursement amount, date, and reference
And the EMI schedule is auto-generated on EMI_Schedule__c
And Loan_Disbursed__e event is published
And the Loan Application status changes to "Disbursed"
And the customer receives a disbursement confirmation email
```

**Priority:** Critical | **Story Points:** 13

---

## Epic 10: Customer Self-Service

---

### US-019 – View EMI Schedule

**As a** Customer,
**I want to** view my full EMI repayment schedule,
**So that** I can plan my finances accordingly.

**Acceptance Criteria:**

```gherkin
Given my loan has been disbursed
When I log into the Customer Portal and navigate to "My Loans"
Then I can see my EMI schedule with: EMI Number, Due Date, EMI Amount, Principal, Interest, Balance
And overdue EMIs are highlighted in red
And paid EMIs show a green "Paid" badge
```

**Priority:** High | **Story Points:** 5

---

### US-020 – Raise Service Case

**As a** Customer,
**I want to** raise a support case from the Customer Portal,
**So that** I can get help without calling the branch or customer care line.

**Acceptance Criteria:**

```gherkin
Given I am logged into the Customer Portal
When I navigate to "Raise a Request" and select a category (Statement Request, Closure Query, Dispute, etc.) and describe my issue
Then a Case is created in Salesforce linked to my Account
And I receive a Case Reference Number
And a Service Agent receives the case in the appropriate queue
```

**Priority:** Medium | **Story Points:** 5

---

## Epic 11: Collections

---

### US-021 – Auto-Detect Overdue EMIs (System)

**As the** Collections System,
**I want to** automatically identify overdue EMIs every day,
**So that** collections follow-up can begin without manual monitoring.

**Acceptance Criteria:**

```gherkin
Given it is the scheduled Batch Apex execution time (daily at 8 AM)
When the CollectionsBatch runs
Then all EMI_Schedule__c records where Due_Date__c < Today and Status__c != "Paid" are identified
And DPD is calculated for each overdue EMI
And a Collection_Case__c is created (or updated) for the loan
And the case is assigned to the appropriate Collections Officer
```

**Priority:** High | **Story Points:** 8

---

### US-022 – Collections Officer Follow-Up

**As a** Collections Officer,
**I want to** see my portfolio of overdue loans in a dashboard,
**So that** I can prioritize and manage my collections activities effectively.

**Acceptance Criteria:**

```gherkin
Given overdue EMIs exist and Collection_Case__c records are assigned to me
When I open the Collections Dashboard LWC
Then I see: Customer Name, Loan Number, DPD, Outstanding EMI Amount, Contact Number
And cases are sorted by DPD (highest first)
And I can log a call activity directly from the dashboard
And I can mark a case as "Promise to Pay" with a promised date
```

**Priority:** High | **Story Points:** 8

---

## Epic 12: Reporting

---

### US-023 – Management Dashboard

**As a** Branch Manager / Senior Management,
**I want to** see a real-time lending KPI dashboard,
**So that** I can make data-driven decisions on portfolio health.

**Acceptance Criteria:**

```gherkin
Given I am logged into the Management Salesforce App
When I open the Management Dashboard
Then I can see:
  - Total Applications This Month
  - Approval Rate %
  - Rejection Rate % with top reasons
  - Total Disbursement Volume (INR)
  - Average Processing TAT (days)
  - Top Performing Dealers
And all charts auto-refresh when underlying data changes
```

**Priority:** Medium | **Story Points:** 5

---

*Total User Stories: 23 across 12 Epics*
*Total Story Points: 172*
