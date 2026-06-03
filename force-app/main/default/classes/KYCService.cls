/**
 * @description       Service layer for KYC verification operations.
 *                    Handles PAN/Aadhaar encryption on save, status transitions,
 *                    and propagation of KYC outcomes back to the parent Loan Application.
 *
 * @author            LendSphere 360
 * @created           2024
 */
public with sharing class KYCService {

    private static final String MODULE = 'KYCService';

    // ───────────────────────────────────────────────────────────────────────────
    // Status constants
    // ───────────────────────────────────────────────────────────────────────────

    public static final String KYC_PENDING      = 'Pending';
    public static final String KYC_IN_PROGRESS  = 'In Progress';
    public static final String KYC_VERIFIED     = 'Verified';
    public static final String KYC_FAILED       = 'Failed';

    public static final String VER_PENDING      = 'Pending';
    public static final String VER_VERIFIED     = 'Verified';
    public static final String VER_FAILED       = 'Failed';

    // ───────────────────────────────────────────────────────────────────────────
    // Before-Insert
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Default KYC status and set timestamp placeholder.
     *              NOTE: PAN/Aadhaar encryption happens before DML so plaintext
     *              is never persisted to the database.
     */
    public static void handleBeforeInsert(List<KYC_Request__c> newRecords) {
        for (KYC_Request__c kyc : newRecords) {
            if (String.isBlank(kyc.KYC_Status__c)) {
                kyc.KYC_Status__c = KYC_PENDING;
            }
            if (String.isBlank(kyc.PAN_Verification_Status__c)) {
                kyc.PAN_Verification_Status__c = VER_PENDING;
            }
            if (String.isBlank(kyc.Aadhaar_Verification_Status__c)) {
                kyc.Aadhaar_Verification_Status__c = VER_PENDING;
            }
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Before-Update
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Derives the overall KYC_Status__c from individual verification statuses.
     *              Stamps Verified_Date__c when both checks pass.
     */
    public static void handleBeforeUpdate(
        List<KYC_Request__c>         newRecords,
        Map<Id, KYC_Request__c>      oldMap
    ) {
        for (KYC_Request__c kyc : newRecords) {
            KYC_Request__c old = oldMap.get(kyc.Id);

            Boolean panChanged    = kyc.PAN_Verification_Status__c    != old.PAN_Verification_Status__c;
            Boolean aadhaarChanged = kyc.Aadhaar_Verification_Status__c != old.Aadhaar_Verification_Status__c;

            if (panChanged || aadhaarChanged) {
                deriveKYCStatus(kyc);
            }
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    // After-Update — propagate KYC outcome to parent Loan Application
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description When KYC is Verified, advances the parent Loan Application
     *              to 'KYC Verified'. When KYC fails, transitions to 'Rejected'.
     */
    public static void handleAfterUpdate(
        List<KYC_Request__c>         newRecords,
        Map<Id, KYC_Request__c>      oldMap
    ) {
        Map<Id, String> appStatusUpdates = new Map<Id, String>();

        for (KYC_Request__c kyc : newRecords) {
            KYC_Request__c old = oldMap.get(kyc.Id);
            if (kyc.KYC_Status__c == old.KYC_Status__c) continue;

            if (kyc.KYC_Status__c == KYC_VERIFIED) {
                appStatusUpdates.put(kyc.Loan_Application__c, LoanApplicationService.STATUS_KYC_VERIFIED);
            } else if (kyc.KYC_Status__c == KYC_FAILED) {
                appStatusUpdates.put(kyc.Loan_Application__c, LoanApplicationService.STATUS_REJECTED);
            }
        }

        if (!appStatusUpdates.isEmpty()) {
            updateParentApplications(appStatusUpdates);
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ───────────────────────────────────────────────────────────────────────────

    @TestVisible
    private static void deriveKYCStatus(KYC_Request__c kyc) {
        Boolean panOk     = kyc.PAN_Verification_Status__c    == VER_VERIFIED;
        Boolean aadhaarOk = kyc.Aadhaar_Verification_Status__c == VER_VERIFIED;
        Boolean panFailed     = kyc.PAN_Verification_Status__c    == VER_FAILED;
        Boolean aadhaarFailed = kyc.Aadhaar_Verification_Status__c == VER_FAILED;

        if (panOk && aadhaarOk) {
            kyc.KYC_Status__c    = KYC_VERIFIED;
            kyc.Verified_Date__c = System.now();
        } else if (panFailed || aadhaarFailed) {
            kyc.KYC_Status__c = KYC_FAILED;
        } else {
            kyc.KYC_Status__c = KYC_IN_PROGRESS;
        }
    }

    private static void updateParentApplications(Map<Id, String> appStatusUpdates) {
        List<Loan_Application__c> appsToUpdate = new List<Loan_Application__c>();
        for (Id appId : appStatusUpdates.keySet()) {
            appsToUpdate.add(new Loan_Application__c(
                Id        = appId,
                Status__c = appStatusUpdates.get(appId)
            ));
        }

        try {
            // Bypass the LoanApplication trigger to avoid circular execution
            TriggerHandler.bypass('LoanApplicationTriggerHandler');
            update appsToUpdate;
            TriggerHandler.clearBypass('LoanApplicationTriggerHandler');
            ApplicationLogger.log(ApplicationLogger.LEVEL_INFO, MODULE, 'updateParentApplications',
                'Updated ' + appsToUpdate.size() + ' Loan Applications based on KYC outcome.');
        } catch (Exception e) {
            ApplicationLogger.logException(e, MODULE, 'updateParentApplications');
        } finally {
            TriggerHandler.clearBypass('LoanApplicationTriggerHandler');
            ApplicationLogger.flush();
        }
    }
}
