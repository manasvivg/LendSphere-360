/**
 * @description Scheduled Apex class that sends EMI payment reminders to customers
 *              3 days before their EMI due date. Runs daily at 8:00 AM.
 *
 *              Schedule via Anonymous Apex:
 *              System.schedule('EMI Reminder Scheduler', '0 0 8 * * ?', new ReminderScheduler());
 *
 * @author      LendSphere 360
 * @version     1.0
 */
public with sharing class ReminderScheduler implements Schedulable {

    private static final String MODULE     = 'ReminderScheduler';
    private static final String CLASS_NAME = 'ReminderScheduler';

    // ─── Schedulable Interface ───────────────────────────────────────────────────
    public void execute(SchedulableContext sc) {
        Date reminderDate = Date.today().addDays(3);

        // Find all EMI schedules due in 3 days that are still Scheduled
        List<EMI_Schedule__c> upcomingEMIs = [
            SELECT Id, Loan_Application__c,
                   Loan_Application__r.Applicant__c,
                   Loan_Application__r.Applicant__r.Name,
                   Loan_Application__r.Applicant__r.PersonEmail,
                   EMI_Amount__c, Due_Date__c, EMI_Number__c, Outstanding_Balance__c
            FROM   EMI_Schedule__c
            WHERE  Due_Date__c = :reminderDate
            AND    Status__c   = 'Scheduled'
        ];

        if (upcomingEMIs.isEmpty()) {
            ApplicationLogger.log(ApplicationLogger.LEVEL_INFO, MODULE, 'execute',
                'No EMIs due on ' + reminderDate + '. No reminders sent.', null);
            return;
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (EMI_Schedule__c emi : upcomingEMIs) {
            String recipientEmail = emi.Loan_Application__r.Applicant__r.PersonEmail;
            String recipientName  = emi.Loan_Application__r.Applicant__r.Name;

            if (String.isBlank(recipientEmail)) { continue; }

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ recipientEmail });
            mail.setSubject('EMI Payment Reminder — Due on ' + emi.Due_Date__c.format());
            mail.setPlainTextBody(buildEmailBody(emi, recipientName));
            mail.setSaveAsActivity(false);
            emails.add(mail);
        }

        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
                ApplicationLogger.log(ApplicationLogger.LEVEL_INFO, MODULE, 'execute',
                    'EMI reminders sent for ' + emails.size() + ' customers.', null);
            } catch (Exception ex) {
                ApplicationLogger.log(ApplicationLogger.LEVEL_ERROR, MODULE, 'execute',
                    'Email send failed: ' + ex.getMessage(), null);
            }
        }
    }

    // ─── Private Helpers ────────────────────────────────────────────────────────

    private static String buildEmailBody(EMI_Schedule__c emi, String name) {
        return 'Dear ' + name + ',\n\n'
            + 'This is a friendly reminder that your EMI payment is due in 3 days.\n\n'
            + 'EMI Details:\n'
            + '  EMI Number     : ' + emi.EMI_Number__c + '\n'
            + '  Due Date       : ' + emi.Due_Date__c.format() + '\n'
            + '  EMI Amount     : INR ' + emi.EMI_Amount__c.setScale(2) + '\n'
            + '  Outstanding    : INR ' + emi.Outstanding_Balance__c.setScale(2) + '\n\n'
            + 'Please ensure sufficient balance in your registered bank account or UPI.\n\n'
            + 'For any queries, log in to the LendSphere Customer Portal or contact support.\n\n'
            + 'Regards,\n'
            + 'LendSphere 360 — Loan Servicing Team\n';
    }
}
