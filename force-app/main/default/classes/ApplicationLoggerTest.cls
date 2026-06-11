/**
 * @description Test class for ApplicationLogger.
 * @author      LendSphere 360
 */
@isTest
private class ApplicationLoggerTest {

    @isTest
    static void testLog_basic() {
        ApplicationLogger.log('INFO', 'TestModule', 'testMethod', 'Test message');
        System.assertEquals(1, ApplicationLogger.getBufferSize(), 'Buffer should have 1 entry');

        ApplicationLogger.flush();
        System.assertEquals(0, ApplicationLogger.getBufferSize(), 'Buffer should be empty after flush');

        List<Application_Log__c> logs = [SELECT Log_Level__c, Module__c FROM Application_Log__c];
        System.assertEquals(1, logs.size(), 'One log record should be inserted');
        System.assertEquals('INFO', logs[0].Log_Level__c);
        System.assertEquals('TestModule', logs[0].Module__c);
    }

    @isTest
    static void testLog_withRelatedRecordId() {
        ApplicationLogger.log('WARN', 'TestModule', 'testMethod', 'Warn message', 'fakeId123');
        ApplicationLogger.flush();
        List<Application_Log__c> logs = [SELECT Related_Record_Id__c FROM Application_Log__c];
        System.assertEquals('fakeId123', logs[0].Related_Record_Id__c);
    }

    @isTest
    static void testLogException() {
        try {
            Integer x = Integer.valueOf('not-a-number');
        } catch (Exception e) {
            ApplicationLogger.logException(e, 'TestModule', 'testMethod');
        }
        System.assertEquals(1, ApplicationLogger.getBufferSize());
        ApplicationLogger.flush();
        List<Application_Log__c> logs = [SELECT Log_Level__c, Stack_Trace__c FROM Application_Log__c];
        System.assertEquals('ERROR', logs[0].Log_Level__c);
        System.assertNotEquals(null, logs[0].Stack_Trace__c);
    }

    @isTest
    static void testClearBuffer() {
        ApplicationLogger.log('DEBUG', 'TestModule', 'testMethod', 'Debug message');
        System.assertEquals(1, ApplicationLogger.getBufferSize());
        ApplicationLogger.clearBuffer();
        System.assertEquals(0, ApplicationLogger.getBufferSize(), 'Buffer should be cleared');
    }

    @isTest
    static void testFlush_emptyBuffer() {
        // Should not throw
        ApplicationLogger.flush();
        System.assert(true, 'Flush on empty buffer should not throw');
    }

    @isTest
    static void testMultipleLogsBuffered() {
        for (Integer i = 0; i < 5; i++) {
            ApplicationLogger.log('INFO', 'Module' + i, 'method', 'Message ' + i);
        }
        System.assertEquals(5, ApplicationLogger.getBufferSize(), 'Buffer should hold 5 entries');
        ApplicationLogger.flush();
        System.assertEquals(5, [SELECT COUNT() FROM Application_Log__c], '5 records should be inserted');
    }
}
