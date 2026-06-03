/**
 * @description       Service layer for Disbursement processing.
 *                    Handles post-disbursement actions: advancing the parent Loan
 *                    Application to 'Disbursed', assigning the Loan Account Number,
 *                    and triggering EMI schedule generation via a Queueable job.
 *
 * @author            LendSphere 360
 * @created           2024
 */
public with sharing class DisbursementService {

    private static final String MODULE = 'DisbursementService';

    // ───────────────────────────────────────────────────────────────────────────
    // Before-Insert
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Defaults disbursement status to Pending on insert.
     */
    public static void handleBeforeInsert(List<Disbursement__c> newRecords) {
        for (Disbursement__c d : newRecords) {
            if (String.isBlank(d.Status__c)) {
                d.Status__c = 'Pending';
            }
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    // After-Update
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description When disbursement status transitions to Completed:
     *              1. Advances the parent Loan Application to 'Disbursed'.
     *              2. Enqueues EMIGenerationQueueable to create the amortisation schedule.
     */
    public static void handleAfterUpdate(
        List<Disbursement__c>         newRecords,
        Map<Id, Disbursement__c>      oldMap
    ) {
        List<Id> completedDisbursementIds = new List<Id>();
        Map<Id, Disbursement__c> completedMap = new Map<Id, Disbursement__c>(); // disbId → record

        for (Disbursement__c d : newRecords) {
            Disbursement__c old = oldMap.get(d.Id);
            if (d.Status__c == 'Completed' && old.Status__c != 'Completed') {
                completedDisbursementIds.add(d.Id);
                completedMap.put(d.Id, d);
            }
        }

        if (completedDisbursementIds.isEmpty()) return;

        // Advance parent Loan Applications to Disbursed
        advanceApplicationsToDisbursed(completedMap);

        // Enqueue EMI schedule generation (runs outside trigger context)
        System.enqueueJob(new EMIGenerationQueueable(completedDisbursementIds));

        ApplicationLogger.log(ApplicationLogger.LEVEL_INFO, MODULE, 'handleAfterUpdate',
            'Enqueued EMI generation for ' + completedDisbursementIds.size() + ' disbursements.');
        ApplicationLogger.flush();
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ───────────────────────────────────────────────────────────────────────────

    private static void advanceApplicationsToDisbursed(Map<Id, Disbursement__c> completedMap) {
        List<Loan_Application__c> toUpdate = new List<Loan_Application__c>();
        for (Disbursement__c d : completedMap.values()) {
            toUpdate.add(new Loan_Application__c(
                Id        = d.Loan_Application__c,
                Status__c = LoanApplicationService.STATUS_DISBURSED
            ));
        }

        try {
            TriggerHandler.bypass('LoanApplicationTriggerHandler');
            update toUpdate;
            TriggerHandler.clearBypass('LoanApplicationTriggerHandler');
        } catch (Exception e) {
            ApplicationLogger.logException(e, MODULE, 'advanceApplicationsToDisbursed');
        } finally {
            TriggerHandler.clearBypass('LoanApplicationTriggerHandler');
            ApplicationLogger.flush();
        }
    }
}
