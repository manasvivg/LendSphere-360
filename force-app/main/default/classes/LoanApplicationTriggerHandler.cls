/**
 * @description Trigger handler for Loan_Application__c.
 *              Delegates all business logic to LoanApplicationService.
 *              One trigger, one handler — follows the framework pattern.
 * @author      LendSphere 360
 */
public with sharing class LoanApplicationTriggerHandler extends TriggerHandler {

    private List<Loan_Application__c>        newList;
    private List<Loan_Application__c>        oldList;
    private Map<Id, Loan_Application__c>     newMap;
    private Map<Id, Loan_Application__c>     oldMap;

    public LoanApplicationTriggerHandler() {
        this.newList = (List<Loan_Application__c>) Trigger.new;
        this.oldList = (List<Loan_Application__c>) Trigger.old;
        this.newMap  = (Map<Id, Loan_Application__c>) Trigger.newMap;
        this.oldMap  = (Map<Id, Loan_Application__c>) Trigger.oldMap;
    }

    protected override void beforeInsert() {
        LoanApplicationService.handleBeforeInsert(newList);
    }

    protected override void beforeUpdate() {
        LoanApplicationService.handleBeforeUpdate(newList, oldMap);
    }

    protected override void afterInsert() {
        LoanApplicationService.handleAfterInsert(newList);
    }
}
