# Low Level Design (LLD)

## LendSphere 360 – Technical Design Specifications

| Field | Details |
|---|---|
| **Document Version** | 1.0 |
| **Status** | Approved |
| **Prepared By** | Manasvi Gharat |
| **Date** | May 2026 |

---

## 1. Trigger Framework Design

### 1.1 Design Principles

- **One Trigger Per Object**: Prevents unpredictable ordering and conflicts
- **Handler Pattern**: All logic lives in Handler classes, never in triggers
- **Abstract Base Class**: `TriggerHandler.cls` provides structure and context
- **Bulkification**: All handlers process `Trigger.new` / `Trigger.newMap` as collections
- **Custom Metadata Switch**: Triggers can be disabled per object via CMT without deployment

### 1.2 TriggerHandler Base Class

```java
// TriggerHandler.cls
public abstract class TriggerHandler {

    // Context flags
    public Boolean isBefore      { get; private set; }
    public Boolean isAfter       { get; private set; }
    public Boolean isInsert      { get; private set; }
    public Boolean isUpdate      { get; private set; }
    public Boolean isDelete      { get; private set; }
    public Boolean isUndelete    { get; private set; }
    public Boolean isExecuting   { get; private set; }
    
    private static Map<String, Set<String>> bypassedHandlers = new Map<String, Set<String>>();

    public TriggerHandler() {
        this.setTriggerContext();
    }

    // Entry point
    public void run() {
        if (!isTriggerEnabled()) return;
        if (this.isBefore) {
            if (this.isInsert)  this.beforeInsert();
            if (this.isUpdate)  this.beforeUpdate();
            if (this.isDelete)  this.beforeDelete();
        }
        if (this.isAfter) {
            if (this.isInsert)   this.afterInsert();
            if (this.isUpdate)   this.afterUpdate();
            if (this.isDelete)   this.afterDelete();
            if (this.isUndelete) this.afterUndelete();
        }
    }

    // Override in handler classes
    protected virtual void beforeInsert()  {}
    protected virtual void afterInsert()   {}
    protected virtual void beforeUpdate()  {}
    protected virtual void afterUpdate()   {}
    protected virtual void beforeDelete()  {}
    protected virtual void afterDelete()   {}
    protected virtual void afterUndelete() {}

    // Check Custom Metadata switch
    private Boolean isTriggerEnabled() {
        String handlerName = String.valueOf(this).split(':')[0];
        List<Trigger_Switch__mdt> switches = [
            SELECT Is_Active__c FROM Trigger_Switch__mdt
            WHERE Handler_Class__c = :handlerName LIMIT 1
        ];
        return switches.isEmpty() || switches[0].Is_Active__c;
    }

    private void setTriggerContext() {
        this.isBefore   = Trigger.isBefore;
        this.isAfter    = Trigger.isAfter;
        this.isInsert   = Trigger.isInsert;
        this.isUpdate   = Trigger.isUpdate;
        this.isDelete   = Trigger.isDelete;
        this.isUndelete = Trigger.isUndelete;
        this.isExecuting = Trigger.isExecuting;
    }
}
```

### 1.3 Loan Application Trigger

```java
// LoanApplicationTrigger.trigger
trigger LoanApplicationTrigger on Loan_Application__c (
    before insert, before update,
    after insert, after update, after delete
) {
    new LoanApplicationTriggerHandler().run();
}
```

### 1.4 Loan Application Trigger Handler

```java
// LoanApplicationTriggerHandler.cls
public class LoanApplicationTriggerHandler extends TriggerHandler {

    private List<Loan_Application__c> newList;
    private List<Loan_Application__c> oldList;
    private Map<Id, Loan_Application__c> newMap;
    private Map<Id, Loan_Application__c> oldMap;

    public LoanApplicationTriggerHandler() {
        this.newList = (List<Loan_Application__c>) Trigger.new;
        this.oldList = (List<Loan_Application__c>) Trigger.old;
        this.newMap  = (Map<Id, Loan_Application__c>) Trigger.newMap;
        this.oldMap  = (Map<Id, Loan_Application__c>) Trigger.oldMap;
    }

    public override void beforeInsert() {
        LoanApplicationService.generateLoanNumbers(this.newList);
        LoanApplicationService.calculateEMIAmounts(this.newList);
    }

    public override void afterInsert() {
        LoanApplicationService.createKYCRequests(this.newList);
        LoanApplicationService.createDocumentChecklist(this.newList);
    }

    public override void afterUpdate() {
        LoanApplicationService.handleStatusChanges(this.newList, this.oldMap);
        LoanApplicationService.publishPlatformEvents(this.newList, this.oldMap);
    }
}
```

---

## 2. Service Layer Design

### 2.1 LoanApplicationService

```java
// LoanApplicationService.cls
public with sharing class LoanApplicationService {

    // Called from Trigger Handler - before insert
    public static void generateLoanNumbers(List<Loan_Application__c> apps) {
        // Auto Number field handles this; this method validates other before-insert logic
        for (Loan_Application__c app : apps) {
            app.Application_Date__c = app.Application_Date__c ?? Date.today();
            app.Status__c = app.Status__c ?? 'Draft';
        }
    }

    // Calculate EMI using reducing balance formula
    public static void calculateEMIAmounts(List<Loan_Application__c> apps) {
        for (Loan_Application__c app : apps) {
            if (app.Loan_Amount__c != null && app.Interest_Rate__c != null && app.Tenure_Months__c != null) {
                app.EMI_Amount__c = calculateEMI(
                    app.Loan_Amount__c, app.Interest_Rate__c, app.Tenure_Months__c
                );
            }
        }
    }

    // EMI Formula: P * r * (1+r)^n / ((1+r)^n - 1)
    public static Decimal calculateEMI(Decimal principal, Decimal annualRate, Integer tenureMonths) {
        Decimal monthlyRate = (annualRate / 100) / 12;
        if (monthlyRate == 0) return principal / tenureMonths;
        Decimal factor = Math.pow((1 + monthlyRate), tenureMonths);
        return (principal * monthlyRate * factor / (factor - 1)).setScale(2, RoundingMode.HALF_UP);
    }

    // Create KYC Request on Loan Application creation
    public static void createKYCRequests(List<Loan_Application__c> apps) {
        List<KYC_Request__c> kycRequests = new List<KYC_Request__c>();
        for (Loan_Application__c app : apps) {
            kycRequests.add(new KYC_Request__c(
                Loan_Application__c = app.Id,
                KYC_Status__c = 'Pending'
            ));
        }
        if (!kycRequests.isEmpty()) {
            insert kycRequests;
        }
    }

    // Handle status transitions and publish events
    public static void handleStatusChanges(
        List<Loan_Application__c> newList,
        Map<Id, Loan_Application__c> oldMap
    ) {
        List<Loan_Application__c> submittedApps = new List<Loan_Application__c>();
        List<Loan_Application__c> approvedApps  = new List<Loan_Application__c>();
        List<Loan_Application__c> disbursedApps = new List<Loan_Application__c>();

        for (Loan_Application__c app : newList) {
            Loan_Application__c oldApp = oldMap.get(app.Id);
            if (oldApp.Status__c != 'Submitted' && app.Status__c == 'Submitted') {
                submittedApps.add(app);
            }
            if (oldApp.Status__c != 'Sanctioned' && app.Status__c == 'Sanctioned') {
                approvedApps.add(app);
                app.Sanction_Date__c = Date.today();
            }
        }

        if (!submittedApps.isEmpty()) publishApplicationSubmittedEvents(submittedApps);
        if (!approvedApps.isEmpty())  publishLoanApprovedEvents(approvedApps);
    }

    // Publish Application_Submitted__e
    private static void publishApplicationSubmittedEvents(List<Loan_Application__c> apps) {
        List<Application_Submitted__e> events = new List<Application_Submitted__e>();
        for (Loan_Application__c app : apps) {
            events.add(new Application_Submitted__e(
                Loan_Application_Id__c = app.Id,
                Applicant_Id__c        = app.Applicant__c,
                Loan_Amount__c         = app.Loan_Amount__c,
                Product_Type__c        = app.Loan_Product__c
            ));
        }
        List<Database.SaveResult> results = EventBus.publish(events);
        ApplicationLogger.logEventPublishResults(results, 'LoanApplicationService', 'publishApplicationSubmittedEvents');
    }

    // Publish Loan_Approved__e
    private static void publishLoanApprovedEvents(List<Loan_Application__c> apps) {
        List<Loan_Approved__e> events = new List<Loan_Approved__e>();
        for (Loan_Application__c app : apps) {
            events.add(new Loan_Approved__e(
                Loan_Application_Id__c  = app.Id,
                Sanctioned_Amount__c    = app.Sanctioned_Amount__c,
                EMI_Amount__c           = app.EMI_Amount__c
            ));
        }
        EventBus.publish(events);
    }
}
```

---

## 3. Integration Layer Design

### 3.1 CreditBureauCallout

```java
// CreditBureauCallout.cls
public class CreditBureauCallout implements Queueable, Database.AllowsCallouts {

    private Id loanApplicationId;
    private Id creditAssessmentId;

    public CreditBureauCallout(Id loanApplicationId, Id creditAssessmentId) {
        this.loanApplicationId  = loanApplicationId;
        this.creditAssessmentId = creditAssessmentId;
    }

    public void execute(QueueableContext context) {
        try {
            Loan_Application__c app = [
                SELECT Id, Loan_Amount__c, Applicant__r.Name,
                       Applicant__r.Contact__r.PAN_Encrypted__c
                FROM Loan_Application__c
                WHERE Id = :loanApplicationId LIMIT 1
            ];

            String requestBody = buildRequestBody(app);
            HttpResponse response = makeCallout(requestBody);

            if (response.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                CreditService.storeCreditScore(creditAssessmentId, responseMap);
                ApplicationLogger.logAPICall(
                    'CreditBureauNC', requestBody, response.getBody(),
                    response.getStatusCode(), loanApplicationId, 'CreditBureauCallout'
                );
            } else {
                ApplicationLogger.logError(
                    'Credit Bureau API returned: ' + response.getStatusCode(),
                    response.getBody(), loanApplicationId, 'CreditBureauCallout'
                );
            }
        } catch (Exception e) {
            ApplicationLogger.logException(e, loanApplicationId, 'CreditBureauCallout');
        }
    }

    private HttpResponse makeCallout(String requestBody) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:CreditBureauNC/v2/score/enquiry');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(requestBody);
        req.setTimeout(30000);
        return new Http().send(req);
    }

    private String buildRequestBody(Loan_Application__c app) {
        Map<String, Object> requestMap = new Map<String, Object>{
            'enquiryPurpose'        => 'LOAN_ORIGINATION',
            'enquiryAmount'         => app.Loan_Amount__c,
            'memberReferenceNumber' => app.Id,
            'applicant'             => new Map<String, Object>{
                'name' => app.Applicant__r.Name,
                'pan'  => EncryptionUtil.decrypt(app.Applicant__r.Contact__r.PAN_Encrypted__c)
            }
        };
        return JSON.serialize(requestMap);
    }
}
```

---

## 4. Utility Layer Design

### 4.1 ApplicationLogger

```java
// ApplicationLogger.cls
public with sharing class ApplicationLogger {

    // Log informational messages
    public static void logInfo(String message, Id relatedId, String className) {
        insert buildLog('INFO', message, null, null, null, null, 200, relatedId, className);
    }

    // Log error messages
    public static void logError(String message, String details, Id relatedId, String className) {
        insert buildLog('ERROR', message, details, null, null, null, 0, relatedId, className);
    }

    // Log API callouts
    public static void logAPICall(String endpoint, String request, String response,
                                   Integer statusCode, Id relatedId, String className) {
        insert buildLog('INFO', 'API Callout: ' + endpoint, null,
                        endpoint, request, response, statusCode, relatedId, className);
    }

    // Log exception
    public static void logException(Exception e, Id relatedId, String className) {
        insert buildLog('ERROR', e.getMessage(), e.getStackTraceString(),
                        null, null, null, 0, relatedId, className);
    }

    // Log Platform Event publish results
    public static void logEventPublishResults(
        List<Database.SaveResult> results, String className, String methodName
    ) {
        List<Application_Log__c> logs = new List<Application_Log__c>();
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                logs.add(buildLog(
                    'ERROR',
                    'Platform Event Publish Failed: ' + sr.getErrors()[0].getMessage(),
                    null, null, null, null, 0, null, className
                ));
            }
        }
        if (!logs.isEmpty()) insert logs;
    }

    private static Application_Log__c buildLog(
        String level, String message, String stackTrace,
        String endpoint, String request, String response,
        Integer statusCode, Id relatedId, String className
    ) {
        return new Application_Log__c(
            Log_Level__c       = level,
            Message__c         = message.abbreviate(32768),
            Stack_Trace__c     = stackTrace?.abbreviate(32768),
            Endpoint__c        = endpoint,
            Request_Body__c    = request?.abbreviate(32768),
            Response_Body__c   = response?.abbreviate(32768),
            HTTP_Status_Code__c = statusCode,
            Related_Record_Id__c = relatedId,
            Class_Name__c      = className,
            Log_Timestamp__c   = System.now()
        );
    }
}
```

### 4.2 EncryptionUtil

```java
// EncryptionUtil.cls
public with sharing class EncryptionUtil {

    private static final String KEY_NAME = 'LendSphere_AES_Key';

    // Encrypt using AES-256
    public static String encrypt(String plainText) {
        if (String.isBlank(plainText)) return null;
        try {
            Blob keyBlob  = getCryptoKey();
            Blob data     = Blob.valueOf(plainText);
            Blob encrypted = Crypto.encryptWithManagedIV('AES256', keyBlob, data);
            return EncodingUtil.base64Encode(encrypted);
        } catch (Exception e) {
            ApplicationLogger.logException(e, null, 'EncryptionUtil.encrypt');
            throw e;
        }
    }

    // Decrypt AES-256
    public static String decrypt(String encryptedText) {
        if (String.isBlank(encryptedText)) return null;
        try {
            Blob keyBlob   = getCryptoKey();
            Blob encrypted = EncodingUtil.base64Decode(encryptedText);
            Blob decrypted = Crypto.decryptWithManagedIV('AES256', keyBlob, encrypted);
            return decrypted.toString();
        } catch (Exception e) {
            ApplicationLogger.logException(e, null, 'EncryptionUtil.decrypt');
            throw e;
        }
    }

    // Hash for searchable index (SHA-256, one-way)
    public static String hashForSearch(String value) {
        if (String.isBlank(value)) return null;
        Blob hash = Crypto.generateDigest('SHA-256', Blob.valueOf(value.toUpperCase()));
        return EncodingUtil.convertToHex(hash);
    }

    // Retrieve key from Protected Custom Setting or Org Secret
    private static Blob getCryptoKey() {
        // In practice: retrieve from Custom Setting or Named Credential
        // For portfolio: generate deterministic key from org ID
        String orgId = UserInfo.getOrganizationId();
        return Crypto.generateDigest('SHA-256', Blob.valueOf(orgId));
    }
}
```

---

## 5. Async Processing Design

### 5.1 EMIGenerationBatch

```java
// EMIGenerationBatch.cls
public class EMIGenerationBatch implements Database.Batchable<SObject>, Database.Stateful {

    private Integer successCount = 0;
    private Integer failureCount = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Loan_Amount__c, Interest_Rate__c, Tenure_Months__c,
                   EMI_Amount__c,
                   (SELECT Id, Disbursement_Date__c FROM Disbursements__r
                    WHERE Status__c = 'Completed' LIMIT 1)
            FROM Loan_Application__c
            WHERE Status__c = 'Disbursed'
            AND Id NOT IN (SELECT Loan_Application__c FROM EMI_Schedule__c)
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Loan_Application__c> apps) {
        List<EMI_Schedule__c> emiList = new List<EMI_Schedule__c>();
        for (Loan_Application__c app : apps) {
            try {
                Date startDate = app.Disbursements__r[0].Disbursement_Date__c.addMonths(1);
                Decimal outstanding = app.Loan_Amount__c;
                Decimal monthlyRate = (app.Interest_Rate__c / 100) / 12;

                for (Integer i = 1; i <= app.Tenure_Months__c; i++) {
                    Decimal interest   = (outstanding * monthlyRate).setScale(2, RoundingMode.HALF_UP);
                    Decimal principal  = (app.EMI_Amount__c - interest).setScale(2, RoundingMode.HALF_UP);
                    outstanding       -= principal;

                    emiList.add(new EMI_Schedule__c(
                        Loan_Application__c    = app.Id,
                        EMI_Number__c          = i,
                        Due_Date__c            = startDate.addMonths(i - 1),
                        EMI_Amount__c          = app.EMI_Amount__c,
                        Principal_Component__c = principal,
                        Interest_Component__c  = interest,
                        Outstanding_Balance__c = outstanding.max(0),
                        Status__c              = 'Upcoming'
                    ));
                }
                successCount++;
            } catch (Exception e) {
                ApplicationLogger.logException(e, app.Id, 'EMIGenerationBatch');
                failureCount++;
            }
        }
        insert emiList;
    }

    public void finish(Database.BatchableContext bc) {
        ApplicationLogger.logInfo(
            'EMIGenerationBatch complete. Success: ' + successCount + ', Failed: ' + failureCount,
            null, 'EMIGenerationBatch'
        );
    }
}
```

### 5.2 CollectionsBatch

```java
// CollectionsBatch.cls
public class CollectionsBatch implements Database.Batchable<SObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date today = Date.today();
        return Database.getQueryLocator([
            SELECT Id, Loan_Application__c, Due_Date__c, EMI_Amount__c, Paid_Amount__c
            FROM EMI_Schedule__c
            WHERE Status__c IN ('Upcoming', 'Due')
            AND Due_Date__c < :today
        ]);
    }

    public void execute(Database.BatchableContext bc, List<EMI_Schedule__c> overdueEMIs) {
        Date today = Date.today();
        List<EMI_Schedule__c> toUpdate = new List<EMI_Schedule__c>();
        List<Collection_Case__c> cases = new List<Collection_Case__c>();

        // Existing collection cases for these loans
        Set<Id> loanIds = new Map<Id, SObject>(overdueEMIs).keySet();
        Map<Id, Collection_Case__c> existingCases = new Map<Id, Collection_Case__c>();
        for (Collection_Case__c cc : [
            SELECT Id, Loan_Application__c, DPD__c
            FROM Collection_Case__c
            WHERE Loan_Application__c IN :loanIds
            AND Collection_Status__c NOT IN ('Closed', 'Settled')
        ]) {
            existingCases.put(cc.Loan_Application__c, cc);
        }

        for (EMI_Schedule__c emi : overdueEMIs) {
            Integer dpd = today.daysBetween(emi.Due_Date__c) * -1;
            emi.Status__c = 'Overdue';
            toUpdate.add(emi);

            if (!existingCases.containsKey(emi.Loan_Application__c)) {
                String bucket = dpd <= 30 ? '1-30 DPD'
                              : dpd <= 60 ? '31-60 DPD'
                              : dpd <= 90 ? '61-90 DPD'
                              : '90+ DPD';
                cases.add(new Collection_Case__c(
                    Loan_Application__c = emi.Loan_Application__c,
                    EMI_Schedule__c     = emi.Id,
                    DPD__c              = dpd,
                    Overdue_Amount__c   = emi.EMI_Amount__c - (emi.Paid_Amount__c ?? 0),
                    Collection_Status__c = 'Open',
                    Bucket__c           = bucket
                ));
                existingCases.put(emi.Loan_Application__c, new Collection_Case__c());
            }
        }

        update toUpdate;
        if (!cases.isEmpty()) insert cases;
    }

    public void finish(Database.BatchableContext bc) {
        ApplicationLogger.logInfo('CollectionsBatch completed', null, 'CollectionsBatch');
    }
}
```

### 5.3 Scheduled Apex

```java
// CollectionsScheduler.cls
public class CollectionsScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        Database.executeBatch(new CollectionsBatch(), 200);
    }
}

// Schedule in Anonymous Apex:
// CollectionsScheduler scheduler = new CollectionsScheduler();
// String cronExp = '0 0 8 * * ?'; // Daily at 8 AM
// System.schedule('Collections Daily Batch', cronExp, scheduler);
```

---

## 6. Platform Event Channel Definitions

### Application_Submitted__e

| Field | Type | Description |
|---|---|---|
| Loan_Application_Id__c | Text(18) | Loan application record ID |
| Applicant_Id__c | Text(18) | Account ID of applicant |
| Loan_Amount__c | Number | Requested loan amount |
| Product_Type__c | Text(50) | Loan product type |

### KYC_Completed__e

| Field | Type | Description |
|---|---|---|
| Loan_Application_Id__c | Text(18) | Loan application record ID |
| KYC_Request_Id__c | Text(18) | KYC request record ID |
| KYC_Status__c | Text(20) | Verified / Failed |

### Loan_Approved__e

| Field | Type | Description |
|---|---|---|
| Loan_Application_Id__c | Text(18) | Loan application record ID |
| Sanctioned_Amount__c | Number | Approved loan amount |
| EMI_Amount__c | Number | Monthly EMI |

### Mandate_Activated__e

| Field | Type | Description |
|---|---|---|
| Mandate_Id__c | Text(18) | Mandate record ID |
| Loan_Application_Id__c | Text(18) | Loan application record ID |
| Mandate_Type__c | Text(20) | UPI / eNACH |

### Loan_Disbursed__e

| Field | Type | Description |
|---|---|---|
| Disbursement_Id__c | Text(18) | Disbursement record ID |
| Loan_Application_Id__c | Text(18) | Loan application record ID |
| Disbursed_Amount__c | Number | Actual disbursed amount |

---

## 7. LWC Component Design

### 7.1 loanApplicationWizard

```javascript
// loanApplicationWizard.js (design spec)
// Steps: Personal Details → Loan Details → Income Details → Documents → Review & Submit

export default class LoanApplicationWizard extends LightningElement {
    currentStep = 1;
    totalSteps = 5;

    // Step navigation
    handleNext()     { this.currentStep++; }
    handlePrevious() { this.currentStep--; }

    // Final submission
    async handleSubmit() {
        const result = await submitApplication({ applicationId: this.applicationId });
        if (result.isSuccess) {
            this.dispatchEvent(new CustomEvent('applicationsubmitted', { detail: result }));
        }
    }
}
```

### 7.2 emiCalculator

```javascript
// emiCalculator.js (design spec)
// Pure frontend calculator - no Apex needed
// Formula: EMI = P * r * (1+r)^n / ((1+r)^n - 1)

calculateEMI() {
    const P = this.loanAmount;
    const r = (this.interestRate / 100) / 12;
    const n = this.tenure;
    if (r === 0) { this.emiAmount = P / n; return; }
    const factor = Math.pow(1 + r, n);
    this.emiAmount = ((P * r * factor) / (factor - 1)).toFixed(2);
    this.totalAmount = (this.emiAmount * n).toFixed(2);
    this.totalInterest = (this.totalAmount - P).toFixed(2);
}
```

---

## 8. Named Credential Metadata

```xml
<!-- CreditBureauNC.namedCredential-meta.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Credit Bureau NC</label>
    <fullName>CreditBureauNC</fullName>
    <endpoint>https://api.creditbureau.mock</endpoint>
    <principalType>NamedUser</principalType>
    <protocol>Oauth</protocol>
    <oauthScope>read write</oauthScope>
    <generateAuthorizationHeader>true</generateAuthorizationHeader>
    <allowMergeFieldsInHeader>false</allowMergeFieldsInHeader>
    <allowMergeFieldsInBody>false</allowMergeFieldsInBody>
</NamedCredential>
```
