/**
 * @description Trigger for Credit_Assessment__c.
 * @author      LendSphere 360
 */
trigger CreditAssessmentTrigger on Credit_Assessment__c (
    before insert, before update,
    after update
) {
    new CreditAssessmentTriggerHandler().run();
}
