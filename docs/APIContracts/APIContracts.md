# API Contracts

## LendSphere 360 – External Integration API Contracts

| Field | Details |
|---|---|
| **Document Version** | 1.0 |
| **Status** | Draft (Mocked for Portfolio) |
| **Prepared By** | Manasvi Gharat |
| **Date** | May 2026 |
| **Note** | API contracts are modeled after real NBFC integration patterns. Actual endpoint URLs are mocked. |

---

## Integration 1: Credit Bureau API

### Overview

| Attribute | Value |
|---|---|
| **Provider** | CIBIL / Experian (mocked) |
| **Purpose** | Fetch customer credit score and report |
| **Trigger** | KYC_Completed__e platform event |
| **Apex Class** | `CreditBureauCallout.cls` |
| **Named Credential** | `CreditBureauNC` |
| **Auth Method** | OAuth 2.0 Client Credentials |
| **Timeout** | 30 seconds |
| **Retry** | 3 attempts with exponential backoff |

---

### Endpoint

```
POST https://api.creditbureau.mock/v2/score/enquiry
Authorization: Bearer {access_token}
Content-Type: application/json
```

### Request Payload

```json
{
  "enquiryPurpose": "LOAN_ORIGINATION",
  "enquiryAmount": 500000,
  "product": "PERSONAL_LOAN",
  "applicant": {
    "firstName": "Rohan",
    "lastName": "Sharma",
    "dateOfBirth": "1990-05-15",
    "gender": "M",
    "mobile": "9876543210",
    "email": "rohan.sharma@email.com",
    "pan": "ABCPS1234D",
    "addresses": [
      {
        "addressType": "CURRENT",
        "addressLine1": "101, Green Park",
        "city": "Mumbai",
        "state": "Maharashtra",
        "pincode": "400001"
      }
    ]
  },
  "memberReferenceNumber": "LSP-APP-2026-00001"
}
```

### Success Response (200 OK)

```json
{
  "status": "SUCCESS",
  "enquiryId": "ENQ-CB-20260531-00012",
  "reportGeneratedAt": "2026-05-31T08:30:00Z",
  "applicant": {
    "name": "Rohan Sharma",
    "pan": "ABCPS1234D"
  },
  "creditScore": {
    "score": 748,
    "scoreType": "CIBIL_TRANSUNION",
    "ratingBand": "GOOD",
    "scoreDate": "2026-05-31"
  },
  "creditSummary": {
    "totalAccounts": 5,
    "activeAccounts": 3,
    "closedAccounts": 2,
    "overdueAccounts": 0,
    "totalOutstandingBalance": 125000,
    "totalSanctionedAmount": 750000,
    "oldestAccount": "2018-03-01",
    "recentEnquiries30Days": 1
  },
  "derogatorySummary": {
    "writeoffs": 0,
    "settlements": 0,
    "suitFiled": 0,
    "wilfulDefault": false
  },
  "memberReferenceNumber": "LSP-APP-2026-00001"
}
```

### Error Response (422 Unprocessable Entity)

```json
{
  "status": "FAILED",
  "errorCode": "RECORD_NOT_FOUND",
  "errorMessage": "No credit record found for the provided PAN",
  "memberReferenceNumber": "LSP-APP-2026-00001"
}
```

### Salesforce Logging

All requests and responses are logged to `Application_Log__c` with:
- `Log_Level__c` = "INFO" (success) or "ERROR" (failure)
- `Endpoint__c` = API URL
- `Request_Body__c` = JSON request (PAN masked)
- `Response_Body__c` = JSON response
- `HTTP_Status_Code__c` = Response code
- `Related_Record_Id__c` = `Credit_Assessment__c` Id

---

---

## Integration 2: KYC Verification API

### Overview

| Attribute | Value |
|---|---|
| **Provider** | KYC Verification Provider (mocked) |
| **Purpose** | Verify PAN and Aadhaar identity |
| **Trigger** | Operations Officer action |
| **Apex Class** | `KYCCallout.cls` |
| **Named Credential** | `KYCVerifyNC` |
| **Auth Method** | API Key in Header |
| **Timeout** | 20 seconds |
| **Data Security** | PAN/Aadhaar encrypted via EncryptionUtil before sending |

---

### PAN Verification Endpoint

```
POST https://api.kycverify.mock/v1/pan/verify
X-API-Key: {api_key}
Content-Type: application/json
```

#### PAN Request

```json
{
  "pan": "ABCPS1234D",
  "nameToMatch": "Rohan Sharma",
  "dateOfBirth": "1990-05-15",
  "referenceId": "LSP-KYC-2026-00001"
}
```

#### PAN Success Response

```json
{
  "status": "SUCCESS",
  "referenceId": "LSP-KYC-2026-00001",
  "pan": "ABCPS1234D",
  "panStatus": "ACTIVE",
  "nameMatch": "FULL_MATCH",
  "nameOnPAN": "ROHAN SHARMA",
  "dobMatch": true,
  "verifiedAt": "2026-05-31T09:00:00Z"
}
```

#### PAN Failure Response

```json
{
  "status": "FAILED",
  "referenceId": "LSP-KYC-2026-00001",
  "errorCode": "INVALID_PAN",
  "errorMessage": "PAN number is invalid or does not exist in ITD records"
}
```

---

### Aadhaar Verification Endpoint

```
POST https://api.kycverify.mock/v1/aadhaar/verify
X-API-Key: {api_key}
Content-Type: application/json
```

#### Aadhaar Request

```json
{
  "aadhaar": "XXXX-XXXX-1234",
  "nameToMatch": "Rohan Sharma",
  "dateOfBirth": "1990-05-15",
  "referenceId": "LSP-KYC-2026-00001"
}
```

> **Note:** Full Aadhaar number is AES-256 encrypted in transit. Only last 4 digits stored in Salesforce.

#### Aadhaar Success Response

```json
{
  "status": "SUCCESS",
  "referenceId": "LSP-KYC-2026-00001",
  "aadhaarLast4": "1234",
  "nameMatch": "PARTIAL_MATCH",
  "dobMatch": true,
  "aadhaarLinkedMobile": true,
  "verifiedAt": "2026-05-31T09:01:00Z"
}
```

---

---

## Integration 3: UPI Mandate API

### Overview

| Attribute | Value |
|---|---|
| **Provider** | NPCI / Payment Aggregator (mocked) |
| **Purpose** | Setup UPI AutoPay / eNACH mandate for EMI auto-debit |
| **Trigger** | Customer action on portal |
| **Apex Class** | `MandateCallout.cls` |
| **Named Credential** | `MandateProviderNC` |
| **Auth Method** | HMAC-SHA256 signature + API Key |
| **Timeout** | 30 seconds |
| **Reflects** | Bajaj Finserv UPI mandate experience |

---

### Create UPI Mandate Endpoint

```
POST https://api.mandateprovider.mock/v1/upi/mandate/create
X-API-Key: {api_key}
X-Signature: {hmac_sha256_signature}
X-Timestamp: {unix_timestamp}
Content-Type: application/json
```

#### UPI Mandate Request

```json
{
  "merchantReferenceId": "LSP-MANDATE-2026-00001",
  "customerVPA": "rohan.sharma@upi",
  "customerName": "Rohan Sharma",
  "customerMobile": "9876543210",
  "mandateDetails": {
    "amount": 12500.00,
    "currency": "INR",
    "frequency": "MONTHLY",
    "startDate": "2026-07-01",
    "endDate": "2029-06-30",
    "remark": "LendSphere EMI - LSP-APP-2026-00001"
  },
  "callbackUrl": "https://yourorg.salesforce.com/services/apexrest/mandate/callback"
}
```

#### UPI Mandate Pending Response (202 Accepted)

```json
{
  "status": "PENDING",
  "mandateId": "NPCI-MNDT-20260531-00043",
  "merchantReferenceId": "LSP-MANDATE-2026-00001",
  "deepLink": "upi://mandate?pa=merchant@upi&pn=LendSphere&mc=6012&am=12500&mam=12500&cu=INR&tn=LendSphere+EMI&tr=LSP-MANDATE-2026-00001&mn=NPCI-MNDT-20260531-00043",
  "expiresAt": "2026-05-31T09:30:00Z"
}
```

#### Mandate Status Callback (Webhook)

```json
{
  "event": "MANDATE_ACTIVATED",
  "mandateId": "NPCI-MNDT-20260531-00043",
  "merchantReferenceId": "LSP-MANDATE-2026-00001",
  "status": "ACTIVE",
  "customerVPA": "rohan.sharma@upi",
  "activatedAt": "2026-05-31T09:15:00Z"
}
```

---

### Create eNACH Mandate Endpoint

```
POST https://api.mandateprovider.mock/v1/enach/mandate/create
X-API-Key: {api_key}
Content-Type: application/json
```

#### eNACH Mandate Request

```json
{
  "merchantReferenceId": "LSP-ENACH-2026-00001",
  "customerName": "Rohan Sharma",
  "customerMobile": "9876543210",
  "bankDetails": {
    "accountNumber": "XXXXXXXXXXXX1234",
    "ifscCode": "HDFC0001234",
    "accountType": "SAVINGS",
    "bankName": "HDFC Bank"
  },
  "mandateDetails": {
    "amount": 12500.00,
    "maxAmount": 15000.00,
    "currency": "INR",
    "frequency": "MONTHLY",
    "startDate": "2026-07-01",
    "endDate": "2029-06-30",
    "remark": "LendSphere EMI - LSP-APP-2026-00001"
  }
}
```

---

---

## Integration 4: Core Banking API

### Overview

| Attribute | Value |
|---|---|
| **Provider** | Core Banking System / CBS (mocked) |
| **Purpose** | Disburse sanctioned loan to customer bank account |
| **Trigger** | Mandate_Activated__e platform event |
| **Apex Class** | `CoreBankingCallout.cls` (Queueable) |
| **Named Credential** | `CoreBankingNC` |
| **Auth Method** | mTLS Certificate + API Key |
| **Timeout** | 60 seconds |
| **Criticality** | HIGH – financial transaction |
| **Idempotency** | `idempotencyKey` ensures no double disbursement |

---

### Loan Disbursement Endpoint

```
POST https://api.corebanking.mock/v1/loans/disburse
X-API-Key: {api_key}
X-Idempotency-Key: {idempotency_key}
Content-Type: application/json
```

#### Disbursement Request

```json
{
  "idempotencyKey": "LSP-DISB-2026-00001",
  "loanAccountDetails": {
    "loanReferenceNumber": "LSP-APP-2026-00001",
    "sanctionedAmount": 500000.00,
    "disbursementAmount": 500000.00,
    "interestRate": 10.5,
    "tenureMonths": 36,
    "productCode": "PL",
    "emiAmount": 16239.00
  },
  "beneficiary": {
    "customerName": "Rohan Sharma",
    "bankAccountNumber": "XXXXXXXXXXXX1234",
    "ifscCode": "HDFC0001234",
    "bankName": "HDFC Bank",
    "accountType": "SAVINGS"
  },
  "disbursementMode": "NEFT",
  "disbursementDate": "2026-06-01",
  "remarks": "Loan Disbursement - LendSphere 360"
}
```

#### Disbursement Success Response (200 OK)

```json
{
  "status": "SUCCESS",
  "loanAccountNumber": "CBS-LA-2026-00001",
  "disbursementReferenceNumber": "NEFT-2026-00043521",
  "disbursedAmount": 500000.00,
  "disbursementDate": "2026-06-01",
  "disbursementTimestamp": "2026-06-01T10:30:00Z",
  "emiStartDate": "2026-07-01",
  "emiAmount": 16239.00,
  "totalEMIs": 36,
  "utrNumber": "HDFC26152000012345",
  "loanReferenceNumber": "LSP-APP-2026-00001"
}
```

#### Disbursement Failure Response (422)

```json
{
  "status": "FAILED",
  "errorCode": "INVALID_BANK_ACCOUNT",
  "errorMessage": "Beneficiary bank account validation failed. Please verify IFSC code and account number.",
  "loanReferenceNumber": "LSP-APP-2026-00001",
  "idempotencyKey": "LSP-DISB-2026-00001"
}
```

#### Idempotency Response (200 - Already Processed)

```json
{
  "status": "ALREADY_PROCESSED",
  "message": "This disbursement request was already processed.",
  "loanAccountNumber": "CBS-LA-2026-00001",
  "disbursementReferenceNumber": "NEFT-2026-00043521",
  "loanReferenceNumber": "LSP-APP-2026-00001"
}
```

---

## Named Credential Configuration Reference

| Named Credential Label | API Name | Endpoint | Auth Protocol |
|---|---|---|---|
| Credit Bureau NC | CreditBureauNC | https://api.creditbureau.mock | OAuth 2.0 JWT |
| KYC Verify NC | KYCVerifyNC | https://api.kycverify.mock | Named Principal (API Key) |
| Mandate Provider NC | MandateProviderNC | https://api.mandateprovider.mock | Named Principal (API Key) |
| Core Banking NC | CoreBankingNC | https://api.corebanking.mock | Named Principal (mTLS) |

---

## Error Code Reference

| Error Code | Meaning | Action |
|---|---|---|
| `RECORD_NOT_FOUND` | No bureau record exists | Log, notify analyst, manual review |
| `INVALID_PAN` | PAN validation failed | Notify customer, re-verify |
| `TIMEOUT` | API did not respond in time | Retry 3x with backoff |
| `INVALID_BANK_ACCOUNT` | Account validation failed | Notify customer to update details |
| `ALREADY_PROCESSED` | Duplicate request | Log, use existing response |
| `MANDATE_EXPIRED` | Mandate setup link expired | Generate new mandate request |
| `INSUFFICIENT_LIMIT` | CBS daily limit exceeded | Queue for next working day |
