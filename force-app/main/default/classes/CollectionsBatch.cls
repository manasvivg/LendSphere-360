/**
 * @description       Daily scheduled Batch Apex that:
 *                    1. Finds all EMI_Schedule__c records that are past due and not paid.
 *                    2. Delegates to CollectionsService.processOverdueEMIs() to mark
 *                       them Overdue and upsert Collection_Case__c records.
 *
 *                    Schedule: Run daily at midnight via Scheduled Apex.
 *                    Anonymous Apex to schedule:
 *                      System.schedule('LendSphere - Daily Collections Batch',
 *                                      '0 0 0 * * ?', new CollectionsBatch());
 *
 * @author            LendSphere 360
 * @created           2024
 */
public class CollectionsBatch implements Database.Batchable<SObject>, Schedulable {

    private static final String MODULE = 'CollectionsBatch';
    private static final Integer BATCH_SIZE = 200;

    // ───────────────────────────────────────────────────────────────────────────
    // Schedulable interface
    // ───────────────────────────────────────────────────────────────────────────

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new CollectionsBatch(), BATCH_SIZE);
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Batchable interface
    // ───────────────────────────────────────────────────────────────────────────

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Date today = Date.today();
        // Fetch all unpaid EMIs that are overdue
        return Database.getQueryLocator([
            SELECT Id,
                   Loan_Application__c,
                   Due_Date__c,
                   EMI_Amount__c,
                   Status__c
            FROM   EMI_Schedule__c
            WHERE  Due_Date__c < :today
              AND  Status__c   NOT IN ('Paid')
        ]);
    }

    public void execute(Database.BatchableContext bc, List<EMI_Schedule__c> scope) {
        try {
            CollectionsService.processOverdueEMIs(scope);
        } catch (Exception e) {
            ApplicationLogger.logException(e, MODULE, 'execute');
            ApplicationLogger.flush();
        }
    }

    public void finish(Database.BatchableContext bc) {
        ApplicationLogger.log(ApplicationLogger.LEVEL_INFO, MODULE, 'finish',
            'CollectionsBatch completed. Job ID: ' + bc.getJobId());
        ApplicationLogger.flush();
    }

    /**
     * @description AuraEnabled entry point for manual batch trigger from LWC.
     * @return      AsyncApexJob Id
     */
    @AuraEnabled
    public static Id executeNow() {
        return Database.executeBatch(new CollectionsBatch(), 200);
    }
}
