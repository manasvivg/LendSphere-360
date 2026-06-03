/**
 * @description Trigger handler for Property_Detail__c.
 * @author      LendSphere 360
 */
public with sharing class PropertyDetailTriggerHandler extends TriggerHandler {

    private List<Property_Detail__c>        newList;
    private Map<Id, Property_Detail__c>     oldMap;

    public PropertyDetailTriggerHandler() {
        this.newList = (List<Property_Detail__c>) Trigger.new;
        this.oldMap  = (Map<Id, Property_Detail__c>) Trigger.oldMap;
    }

    protected override void beforeInsert() {
        PropertyValuationService.handleBeforeInsert(newList);
    }

    protected override void beforeUpdate() {
        PropertyValuationService.handleBeforeUpdate(newList, oldMap);
    }

    protected override void afterUpdate() {
        PropertyValuationService.handleAfterUpdate(newList, oldMap);
    }
}
