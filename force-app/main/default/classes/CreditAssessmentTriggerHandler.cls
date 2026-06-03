/**
 * @description Trigger handler for Credit_Assessment__c.
 * @author      LendSphere 360
 */
public with sharing class CreditAssessmentTriggerHandler extends TriggerHandler {

    private List<Credit_Assessment__c>      newList;
    private Map<Id, Credit_Assessment__c>   oldMap;

    public CreditAssessmentTriggerHandler() {
        this.newList = (List<Credit_Assessment__c>) Trigger.new;
        this.oldMap  = (Map<Id, Credit_Assessment__c>) Trigger.oldMap;
    }

    protected override void beforeInsert() {
        CreditService.handleBeforeInsert(newList);
    }

    protected override void beforeUpdate() {
        CreditService.handleBeforeUpdate(newList, oldMap);
    }

    protected override void afterUpdate() {
        CreditService.handleAfterUpdate(newList, oldMap);
    }
}
