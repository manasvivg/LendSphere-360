/**
 * @description       Service layer for EMI Schedule operations.
 *                    Generates a full amortisation schedule using the reducing-balance
 *                    formula and handles payment status transitions.
 *
 *                    Called by EMIGenerationQueueable (not directly from triggers)
 *                    to avoid governor limits during large disbursement batches.
 *
 * @author            LendSphere 360
 * @created           2024
 */
public with sharing class EMIService {

    private static final String MODULE = 'EMIService';

    // ───────────────────────────────────────────────────────────────────────────
    // Public — EMI Schedule Generation
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Generates all EMI_Schedule__c records for a list of Disbursement IDs.
     *              Computes principal/interest split per instalment using reducing balance.
     * @param  disbursementIds  IDs of completed Disbursement__c records.
     */
    public static void generateSchedules(List<Id> disbursementIds) {
        if (disbursementIds == null || disbursementIds.isEmpty()) return;

        // Fetch disbursements with parent application details
        List<Disbursement__c> disbursements = [
            SELECT Id,
                   Disbursed_Amount__c,
                   Disbursement_Date__c,
                   Loan_Application__c,
                   Loan_Application__r.Interest_Rate__c,
                   Loan_Application__r.Tenure_Months__c,
                   Loan_Application__r.EMI_Amount__c
            FROM   Disbursement__c
            WHERE  Id IN :disbursementIds
        ];

        List<EMI_Schedule__c> schedules = new List<EMI_Schedule__c>();

        for (Disbursement__c disb : disbursements) {
            Loan_Application__c app = disb.Loan_Application__r;
            if (app.Interest_Rate__c == null || app.Tenure_Months__c == null || disb.Disbursed_Amount__c == null) {
                ApplicationLogger.log(ApplicationLogger.LEVEL_WARN, MODULE, 'generateSchedules',
                    'Skipping EMI generation for disbursement ' + disb.Id + ' — missing financial fields.');
                continue;
            }

            schedules.addAll(buildAmortisationSchedule(disb, app));
        }

        if (!schedules.isEmpty()) {
            try {
                insert schedules;
                ApplicationLogger.log(ApplicationLogger.LEVEL_INFO, MODULE, 'generateSchedules',
                    'Inserted ' + schedules.size() + ' EMI schedule records.');
            } catch (Exception e) {
                ApplicationLogger.logException(e, MODULE, 'generateSchedules');
            } finally {
                ApplicationLogger.flush();
            }
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Private — Amortisation Schedule Builder
    // ───────────────────────────────────────────────────────────────────────────

    @TestVisible
    private static List<EMI_Schedule__c> buildAmortisationSchedule(
        Disbursement__c        disb,
        Loan_Application__c    app
    ) {
        List<EMI_Schedule__c> rows = new List<EMI_Schedule__c>();

        Integer  n           = Integer.valueOf(app.Tenure_Months__c);
        Decimal  principal   = disb.Disbursed_Amount__c;
        Decimal  annualRate  = app.Interest_Rate__c;
        Decimal  monthlyRate = (annualRate / 100) / 12;
        Decimal  emi         = app.EMI_Amount__c;
        Decimal  balance     = principal;
        Date     startDate   = disb.Disbursement_Date__c != null
                               ? disb.Disbursement_Date__c.addMonths(1)
                               : Date.today().addMonths(1);

        for (Integer i = 1; i <= n; i++) {
            Decimal interest  = (balance * monthlyRate).setScale(2, RoundingMode.HALF_UP);
            Decimal principalComponent = (emi - interest).setScale(2, RoundingMode.HALF_UP);

            // Adjust last EMI for rounding residue
            if (i == n) {
                principalComponent = balance;
                emi = (principalComponent + interest).setScale(2, RoundingMode.HALF_UP);
            }

            balance = (balance - principalComponent).setScale(2, RoundingMode.HALF_UP);

            rows.add(new EMI_Schedule__c(
                Name                    = 'EMI-' + String.valueOf(i).leftPad(3, '0'),
                Loan_Application__c     = disb.Loan_Application__c,
                Disbursement__c         = disb.Id,
                EMI_Number__c           = i,
                Due_Date__c             = startDate.addMonths(i - 1),
                EMI_Amount__c           = emi,
                Principal_Component__c  = principalComponent,
                Interest_Component__c   = interest,
                Outstanding_Balance__c  = (balance < 0) ? 0 : balance,
                Status__c               = 'Upcoming'
            ));
        }

        return rows;
    }
}
