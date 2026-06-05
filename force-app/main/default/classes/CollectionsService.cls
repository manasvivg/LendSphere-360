/**
 * @description       Service layer for Collections operations.
 *                    Identifies overdue EMI records, calculates DPD, assigns
 *                    DPD bucket, and creates or updates Collection_Case__c records.
 *                    Intended to be called from CollectionsBatch (daily scheduled job).
 *
 * @author            LendSphere 360
 * @created           2024
 */
public with sharing class CollectionsService {

    private static final String MODULE = 'CollectionsService';

    // DPD bucket boundaries
    private static final Integer BUCKET_1_MIN = 1;
    private static final Integer BUCKET_1_MAX = 30;
    private static final Integer BUCKET_2_MIN = 31;
    private static final Integer BUCKET_2_MAX = 60;
    private static final Integer BUCKET_3_MIN = 61;
    private static final Integer BUCKET_3_MAX = 90;

    // ───────────────────────────────────────────────────────────────────────────
    // Public — called by CollectionsBatch
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Processes a batch of overdue EMI_Schedule__c records:
     *              1. Marks each as Overdue (if still in Upcoming/Due status).
     *              2. Upserts a Collection_Case__c per Loan Application.
     *              3. Sets DPD and DPD Bucket.
     *
     * @param  overdueEMIs  EMI records with Due_Date__c < today and Status != Paid.
     */
    public static void processOverdueEMIs(List<EMI_Schedule__c> overdueEMIs) {
        if (overdueEMIs == null || overdueEMIs.isEmpty()) return;

        Date today = Date.today();

        // Group by Loan Application — pick the most overdue EMI per loan
        Map<Id, EMI_Schedule__c> mostOverdueByApp = new Map<Id, EMI_Schedule__c>();
        Map<Id, Decimal>         totalOverdueByApp = new Map<Id, Decimal>();

        List<EMI_Schedule__c> emiUpdates = new List<EMI_Schedule__c>();

        for (EMI_Schedule__c emi : overdueEMIs) {
            // Mark EMI as Overdue
            if (emi.Status__c != 'Overdue') {
                emiUpdates.add(new EMI_Schedule__c(Id = emi.Id, Status__c = 'Overdue'));
            }

            // Aggregate totals per loan application
            Id appId = emi.Loan_Application__c;
            Integer dpd = emi.Due_Date__c.daysBetween(today);

            // Track the EMI with the highest DPD for the case record
            if (!mostOverdueByApp.containsKey(appId) ||
                dpd > mostOverdueByApp.get(appId).Due_Date__c.daysBetween(today)) {
                mostOverdueByApp.put(appId, emi);
            }

            Decimal overduePortion = emi.EMI_Amount__c != null ? emi.EMI_Amount__c : 0;
            totalOverdueByApp.put(appId,
                (totalOverdueByApp.containsKey(appId) ? totalOverdueByApp.get(appId) : 0) + overduePortion
            );
        }

        // Update EMI statuses
        if (!emiUpdates.isEmpty()) {
            Database.update(emiUpdates, false);
        }

        // Upsert Collection Cases
        upsertCollectionCases(mostOverdueByApp, totalOverdueByApp, today);
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ───────────────────────────────────────────────────────────────────────────

    private static void upsertCollectionCases(
        Map<Id, EMI_Schedule__c> mostOverdueByApp,
        Map<Id, Decimal>         totalOverdueByApp,
        Date                     today
    ) {
        // Fetch existing open cases for these applications
        Map<Id, Collection_Case__c> existingCases = new Map<Id, Collection_Case__c>();
        for (Collection_Case__c cc : [
            SELECT Id, Loan_Application__c, DPD__c, Collection_Status__c
            FROM   Collection_Case__c
            WHERE  Loan_Application__c IN :mostOverdueByApp.keySet()
              AND  Collection_Status__c NOT IN ('Closed', 'Settled')
        ]) {
            existingCases.put(cc.Loan_Application__c, cc);
        }

        List<Collection_Case__c> toUpsert = new List<Collection_Case__c>();

        for (Id appId : mostOverdueByApp.keySet()) {
            EMI_Schedule__c worstEmi = mostOverdueByApp.get(appId);
            Integer dpd = worstEmi.Due_Date__c.daysBetween(today);
            String bucket = deriveBucket(dpd);

            if (existingCases.containsKey(appId)) {
                // Update existing case
                Collection_Case__c cc = existingCases.get(appId);
                cc.DPD__c            = dpd;
                cc.Bucket__c         = bucket;
                cc.Overdue_Amount__c = totalOverdueByApp.get(appId);
                cc.Collection_Status__c = 'In Progress';
                toUpsert.add(cc);
            } else {
                // Create new case
                toUpsert.add(new Collection_Case__c(
                    Loan_Application__c  = appId,
                    EMI_Schedule__c      = worstEmi.Id,
                    DPD__c               = dpd,
                    Bucket__c            = bucket,
                    Overdue_Amount__c    = totalOverdueByApp.get(appId),
                    Collection_Status__c = 'Open'
                ));
            }
        }

        if (!toUpsert.isEmpty()) {
            try {
                upsert toUpsert;
                ApplicationLogger.log(ApplicationLogger.LEVEL_INFO, MODULE, 'upsertCollectionCases',
                    'Upserted ' + toUpsert.size() + ' Collection Cases.');
            } catch (Exception e) {
                ApplicationLogger.logException(e, MODULE, 'upsertCollectionCases');
            } finally {
                ApplicationLogger.flush();
            }
        }
    }

    @TestVisible
    private static String deriveBucket(Integer dpd) {
        if      (dpd >= BUCKET_1_MIN && dpd <= BUCKET_1_MAX) return '1-30 DPD';
        else if (dpd >= BUCKET_2_MIN && dpd <= BUCKET_2_MAX) return '31-60 DPD';
        else if (dpd >= BUCKET_3_MIN && dpd <= BUCKET_3_MAX) return '61-90 DPD';
        else                                                  return '90+ DPD';
    }

    // ───────────────────────────────────────────────────────────────────────────
    // @AuraEnabled — LWC / Aura entry points
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Returns collection cases with related EMI and loan data for the dashboard.
     */
    @AuraEnabled(cacheable=true)
    public static List<Collection_Case__c> getCollectionDashboardData() {
        return [
            SELECT Id, Name, Loan_Application__c, Loan_Application__r.Name,
                   DPD__c, Bucket__c, Overdue_Amount__c, Collection_Status__c,
                   Assigned_To__c, Assigned_To__r.Name,
                   Promise_To_Pay_Date__c, Last_Contact_Remarks__c,
                   EMI_Schedule__c, EMI_Schedule__r.Due_Date__c
            FROM   Collection_Case__c
            WHERE  Collection_Status__c NOT IN ('Closed', 'Settled')
            ORDER  BY DPD__c DESC NULLS LAST
            LIMIT  200
        ];
    }

    /**
     * @description Updates a collection case with remarks and promise-to-pay date.
     */
    @AuraEnabled
    public static void updateCollectionCase(
        Id     caseId,
        String remarks,
        Date   promiseToPayDate,
        String status
    ) {
        Collection_Case__c cc = new Collection_Case__c(
            Id                   = caseId,
            Last_Contact_Remarks__c = remarks,
            Promise_To_Pay_Date__c  = promiseToPayDate,
            Collection_Status__c    = status
        );
        update cc;
    }
}
