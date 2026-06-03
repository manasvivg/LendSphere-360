/**
 * @description Trigger for Property_Detail__c.
 * @author      LendSphere 360
 */
trigger PropertyDetailTrigger on Property_Detail__c (
    before insert, before update,
    after update
) {
    new PropertyDetailTriggerHandler().run();
}
