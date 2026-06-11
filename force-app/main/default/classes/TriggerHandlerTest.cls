/**
 * @description Test class for TriggerHandler base class.
 * @author      LendSphere 360
 */
@isTest
private class TriggerHandlerTest {

    @isTest
    static void testBypass_preventsHandlerExecution() {
        TriggerHandler.bypass('LoanApplicationTriggerHandler');
        System.assert(TriggerHandler.isBypassed('LoanApplicationTriggerHandler'),
            'Handler should be bypassed');
    }

    @isTest
    static void testClearBypass_removesHandler() {
        TriggerHandler.bypass('LoanApplicationTriggerHandler');
        TriggerHandler.clearBypass('LoanApplicationTriggerHandler');
        System.assert(!TriggerHandler.isBypassed('LoanApplicationTriggerHandler'),
            'Handler should not be bypassed after clearBypass');
    }

    @isTest
    static void testClearAllBypasses() {
        TriggerHandler.bypass('LoanApplicationTriggerHandler');
        TriggerHandler.bypass('KYCRequestTriggerHandler');
        TriggerHandler.clearAllBypasses();
        System.assert(!TriggerHandler.isBypassed('LoanApplicationTriggerHandler'));
        System.assert(!TriggerHandler.isBypassed('KYCRequestTriggerHandler'));
    }

    @isTest
    static void testIsBypassed_notBypassed() {
        System.assert(!TriggerHandler.isBypassed('SomeOtherHandler'),
            'Non-bypassed handler should return false');
    }

    @isTest
    static void testMultipleBypasses_independent() {
        TriggerHandler.bypass('HandlerA');
        TriggerHandler.bypass('HandlerB');
        System.assert(TriggerHandler.isBypassed('HandlerA'));
        System.assert(TriggerHandler.isBypassed('HandlerB'));

        TriggerHandler.clearBypass('HandlerA');
        System.assert(!TriggerHandler.isBypassed('HandlerA'), 'HandlerA should be cleared');
        System.assert(TriggerHandler.isBypassed('HandlerB'), 'HandlerB should still be bypassed');
    }
}
