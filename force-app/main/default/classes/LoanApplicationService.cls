/**
 * @description       Service layer for Loan Application lifecycle operations.
 *                    Centralises all business logic so triggers, flows, and LWCs
 *                    call one consistent entry point.
 *
 *                    Responsibilities:
 *                      - Status transition validation (state machine)
 *                      - EMI amount calculation (reducing-balance method)
 *                      - Auto-population of calculated fields
 *                      - Orchestration of downstream record creation
 *
 * @author            LendSphere 360
 * @created           2024
 */
public with sharing class LoanApplicationService {

    private static final String MODULE = 'LoanApplicationService';

    // ───────────────────────────────────────────────────────────────────────────
    // Status constants — mirrors Loan_Application__c.Status__c picklist
    // ───────────────────────────────────────────────────────────────────────────

    public static final String STATUS_DRAFT              = 'Draft';
    public static final String STATUS_SUBMITTED          = 'Submitted';
    public static final String STATUS_KYC_IN_PROGRESS    = 'KYC In Progress';
    public static final String STATUS_KYC_VERIFIED       = 'KYC Verified';
    public static final String STATUS_DOC_COLLECTION     = 'Document Collection';
    public static final String STATUS_CREDIT_ASSESSMENT  = 'Credit Assessment';
    public static final String STATUS_PROPERTY_EVAL      = 'Property Evaluation';
    public static final String STATUS_SANCTIONED         = 'Sanctioned';
    public static final String STATUS_MANDATE_SETUP      = 'Mandate Setup';
    public static final String STATUS_DISBURSED          = 'Disbursed';
    public static final String STATUS_REJECTED           = 'Rejected';
    public static final String STATUS_WITHDRAWN          = 'Withdrawn';

    // Valid forward transitions — enforces the state machine
    private static final Map<String, Set<String>> VALID_TRANSITIONS = new Map<String, Set<String>>{
        STATUS_DRAFT             => new Set<String>{ STATUS_SUBMITTED, STATUS_WITHDRAWN },
        STATUS_SUBMITTED         => new Set<String>{ STATUS_KYC_IN_PROGRESS, STATUS_REJECTED, STATUS_WITHDRAWN },
        STATUS_KYC_IN_PROGRESS   => new Set<String>{ STATUS_KYC_VERIFIED, STATUS_REJECTED },
        STATUS_KYC_VERIFIED      => new Set<String>{ STATUS_DOC_COLLECTION, STATUS_REJECTED },
        STATUS_DOC_COLLECTION    => new Set<String>{ STATUS_CREDIT_ASSESSMENT, STATUS_REJECTED },
        STATUS_CREDIT_ASSESSMENT => new Set<String>{ STATUS_PROPERTY_EVAL, STATUS_SANCTIONED, STATUS_REJECTED },
        STATUS_PROPERTY_EVAL     => new Set<String>{ STATUS_SANCTIONED, STATUS_REJECTED },
        STATUS_SANCTIONED        => new Set<String>{ STATUS_MANDATE_SETUP, STATUS_REJECTED },
        STATUS_MANDATE_SETUP     => new Set<String>{ STATUS_DISBURSED, STATUS_REJECTED },
        STATUS_DISBURSED         => new Set<String>(),   // terminal — no further transitions
        STATUS_REJECTED          => new Set<String>(),   // terminal
        STATUS_WITHDRAWN         => new Set<String>()    // terminal
    };

    // ───────────────────────────────────────────────────────────────────────────
    // Public — Before-Insert processing
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Called from LoanApplicationTriggerHandler.beforeInsert().
     *              Defaults status to Draft and calculates EMI if loan details are present.
     */
    public static void handleBeforeInsert(List<Loan_Application__c> newApps) {
        for (Loan_Application__c app : newApps) {
            if (String.isBlank(app.Status__c)) {
                app.Status__c = STATUS_DRAFT;
            }
            if (app.Application_Date__c == null) {
                app.Application_Date__c = Date.today();
            }
            calculateEMI(app);
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Public — Before-Update processing
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Validates status transitions and recalculates EMI on field changes.
     */
    public static void handleBeforeUpdate(
        List<Loan_Application__c>               newApps,
        Map<Id, Loan_Application__c>            oldMap
    ) {
        for (Loan_Application__c app : newApps) {
            Loan_Application__c oldApp = oldMap.get(app.Id);

            // State machine validation
            if (app.Status__c != oldApp.Status__c) {
                validateTransition(app, oldApp.Status__c, app.Status__c);

                // Stamp sanction date when first sanctioned
                if (app.Status__c == STATUS_SANCTIONED && app.Sanction_Date__c == null) {
                    app.Sanction_Date__c = Date.today();
                    // Copy sanctioned amount from loan amount if not overridden
                    if (app.Sanctioned_Amount__c == null) {
                        app.Sanctioned_Amount__c = app.Loan_Amount__c;
                    }
                }
            }

            // Recalculate EMI if key financial fields changed
            if (app.Loan_Amount__c != oldApp.Loan_Amount__c
                || app.Interest_Rate__c != oldApp.Interest_Rate__c
                || app.Tenure_Months__c != oldApp.Tenure_Months__c) {
                calculateEMI(app);
            }
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Public — After-Insert processing
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Creates a KYC_Request__c child record for new applications.
     */
    public static void handleAfterInsert(List<Loan_Application__c> newApps) {
        List<KYC_Request__c> kycRequests = new List<KYC_Request__c>();

        for (Loan_Application__c app : newApps) {
            kycRequests.add(new KYC_Request__c(
                Name              = 'KYC-' + app.Name,
                Loan_Application__c = app.Id,
                KYC_Status__c     = 'Pending'
            ));
        }

        if (!kycRequests.isEmpty()) {
            try {
                insert kycRequests;
                ApplicationLogger.log(LEVEL_INFO, MODULE, 'handleAfterInsert',
                    'Created ' + kycRequests.size() + ' KYC requests.');
            } catch (Exception e) {
                ApplicationLogger.logException(e, MODULE, 'handleAfterInsert');
            } finally {
                ApplicationLogger.flush();
            }
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Calculates monthly EMI using the reducing-balance formula:
     *              EMI = P * r * (1 + r)^n / ((1 + r)^n - 1)
     *              where P = principal, r = monthly rate, n = tenure months.
     */
    @TestVisible
    private static void calculateEMI(Loan_Application__c app) {
        if (app.Loan_Amount__c == null
            || app.Interest_Rate__c == null
            || app.Tenure_Months__c == null
            || app.Tenure_Months__c == 0) {
            return;
        }

        Decimal principal    = app.Loan_Amount__c;
        Decimal annualRate   = app.Interest_Rate__c;
        Integer tenure       = Integer.valueOf(app.Tenure_Months__c);
        Decimal monthlyRate  = (annualRate / 100) / 12;

        if (monthlyRate == 0) {
            // Zero-interest product
            app.EMI_Amount__c = (principal / tenure).setScale(2, RoundingMode.HALF_UP);
            return;
        }

        Decimal factor = monthlyRate * Math.pow((1 + monthlyRate).doubleValue(), tenure);
        Decimal divisor = Math.pow((1 + monthlyRate).doubleValue(), tenure) - 1;
        app.EMI_Amount__c = ((principal * factor) / divisor).setScale(2, RoundingMode.HALF_UP);
    }

    private static void validateTransition(Loan_Application__c app, String fromStatus, String toStatus) {
        Set<String> allowed = VALID_TRANSITIONS.get(fromStatus);
        if (allowed == null || !allowed.contains(toStatus)) {
            app.addError(
                'Invalid status transition from "' + fromStatus + '" to "' + toStatus + '". '
                + 'Allowed next statuses: ' + (allowed != null ? String.join(new List<String>(allowed), ', ') : 'None')
            );
        }
    }

    private static final String LEVEL_INFO = ApplicationLogger.LEVEL_INFO;
}
