/**
 * @description Trigger for Loan_Application__c.
 *              Single trigger — all logic delegated to LoanApplicationTriggerHandler.
 * @author      LendSphere 360
 */
trigger LoanApplicationTrigger on Loan_Application__c (
    before insert, before update,
    after insert, after update
) {
    new LoanApplicationTriggerHandler().run();
}
