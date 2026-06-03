/**
 * @description Trigger handler for KYC_Request__c.
 * @author      LendSphere 360
 */
public with sharing class KYCRequestTriggerHandler extends TriggerHandler {

    private List<KYC_Request__c>        newList;
    private Map<Id, KYC_Request__c>     oldMap;

    public KYCRequestTriggerHandler() {
        this.newList = (List<KYC_Request__c>) Trigger.new;
        this.oldMap  = (Map<Id, KYC_Request__c>) Trigger.oldMap;
    }

    protected override void beforeInsert() {
        KYCService.handleBeforeInsert(newList);
    }

    protected override void beforeUpdate() {
        KYCService.handleBeforeUpdate(newList, oldMap);
    }

    protected override void afterUpdate() {
        KYCService.handleAfterUpdate(newList, oldMap);
    }
}
