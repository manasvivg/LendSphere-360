/**
 * @description Trigger for KYC_Request__c.
 * @author      LendSphere 360
 */
trigger KYCRequestTrigger on KYC_Request__c (
    before insert, before update,
    after update
) {
    new KYCRequestTriggerHandler().run();
}
