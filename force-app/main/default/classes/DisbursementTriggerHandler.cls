/**
 * @description Trigger handler for Disbursement__c.
 * @author      LendSphere 360
 */
public with sharing class DisbursementTriggerHandler extends TriggerHandler {

    private List<Disbursement__c>       newList;
    private Map<Id, Disbursement__c>    oldMap;

    public DisbursementTriggerHandler() {
        this.newList = (List<Disbursement__c>) Trigger.new;
        this.oldMap  = (Map<Id, Disbursement__c>) Trigger.oldMap;
    }

    protected override void beforeInsert() {
        DisbursementService.handleBeforeInsert(newList);
    }

    protected override void afterUpdate() {
        DisbursementService.handleAfterUpdate(newList, oldMap);
    }
}
