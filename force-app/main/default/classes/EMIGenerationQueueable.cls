/**
 * @description       Queueable Apex that generates the EMI amortisation schedule
 *                    for one or more completed disbursements.
 *                    Enqueued by DisbursementService.handleAfterUpdate() after
 *                    a disbursement reaches 'Completed' status — runs outside the
 *                    trigger transaction to avoid heap/CPU governor issues.
 *
 * @author            LendSphere 360
 * @created           2024
 */
public class EMIGenerationQueueable implements Queueable {

    private List<Id> disbursementIds;

    public EMIGenerationQueueable(List<Id> disbursementIds) {
        this.disbursementIds = disbursementIds;
    }

    public void execute(QueueableContext ctx) {
        try {
            EMIService.generateSchedules(disbursementIds);
        } catch (Exception e) {
            ApplicationLogger.logException(e, 'EMIGenerationQueueable', 'execute');
            ApplicationLogger.flush();
        }
    }
}
