List<ApexClass> classes = [
    SELECT Name, Status
    FROM ApexClass
    WHERE Name IN (
        'TriggerHandler','ApplicationLogger','EncryptionUtil',
        'LoanApplicationService','KYCService','CreditService',
        'PropertyValuationService','DisbursementService','EMIService',
        'CollectionsService','EMIGenerationQueueable','CollectionsBatch',
        'LoanApplicationTriggerHandler','KYCRequestTriggerHandler',
        'CreditAssessmentTriggerHandler','PropertyDetailTriggerHandler',
        'DisbursementTriggerHandler'
    )
    ORDER BY Name
];
System.debug('=== Phase 3 Apex Classes in Org: ' + classes.size() + '/17 ===');
for (ApexClass c : classes) {
    System.debug('✓ ' + c.Name + ' [' + c.Status + ']');
}

List<ApexTrigger> triggers = [
    SELECT Name, Status
    FROM ApexTrigger
    WHERE Name IN (
        'LoanApplicationTrigger','KYCRequestTrigger',
        'CreditAssessmentTrigger','PropertyDetailTrigger','DisbursementTrigger'
    )
    ORDER BY Name
];
System.debug('=== Phase 3 Triggers in Org: ' + triggers.size() + '/5 ===');
for (ApexTrigger t : triggers) {
    System.debug('✓ ' + t.Name + ' [' + t.Status + ']');
}
