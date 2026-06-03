/**
 * @description Trigger for Disbursement__c.
 * @author      LendSphere 360
 */
trigger DisbursementTrigger on Disbursement__c (
    before insert,
    after update
) {
    new DisbursementTriggerHandler().run();
}
