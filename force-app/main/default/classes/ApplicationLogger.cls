/**
 * @description       Platform-wide logging utility. Wraps Application_Log__c inserts
 *                    so that no class is ever tightly coupled to the log object schema.
 *                    Supports synchronous (in-transaction) and fire-and-forget patterns.
 *
 *                    Usage:
 *                      ApplicationLogger.log('INFO', 'LoanService', 'createApplication', 'Application created for ' + appId);
 *                      ApplicationLogger.logException(e, 'KYCService', 'verifyPAN');
 *                      ApplicationLogger.flush();   // call at end of transaction to write buffer
 *
 * @author            LendSphere 360
 * @created           2024
 */
public without sharing class ApplicationLogger {

    // ───────────────────────────────────────────────────────────────────────────
    // Constants
    // ───────────────────────────────────────────────────────────────────────────

    public static final String LEVEL_INFO  = 'INFO';
    public static final String LEVEL_WARN  = 'WARN';
    public static final String LEVEL_ERROR = 'ERROR';
    public static final String LEVEL_DEBUG = 'DEBUG';

    // ───────────────────────────────────────────────────────────────────────────
    // In-transaction buffer — reduces DML statements via bulkification
    // ───────────────────────────────────────────────────────────────────────────

    @TestVisible
    private static List<Application_Log__c> logBuffer = new List<Application_Log__c>();

    // ───────────────────────────────────────────────────────────────────────────
    // Public API
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Log a simple informational message.
     */
    public static void log(String level, String module, String methodName, String message) {
        log(level, module, methodName, message, null, null);
    }

    /**
     * @description Log a message with a related record ID for traceability.
     */
    public static void log(String level, String module, String methodName, String message, String relatedRecordId) {
        log(level, module, methodName, message, relatedRecordId, null);
    }

    /**
     * @description Full-signature log — all fields.
     */
    public static void log(
        String level,
        String module,
        String methodName,
        String message,
        String relatedRecordId,
        String className
    ) {
        Application_Log__c logRecord = new Application_Log__c(
            Log_Level__c        = level,
            Module__c           = module,
            Method_Name__c      = methodName,
            Message__c          = truncate(message, 131072),
            Related_Record_Id__c = relatedRecordId,
            Class_Name__c       = className,
            Log_Timestamp__c    = System.now()
        );
        logBuffer.add(logRecord);
    }

    /**
     * @description Log a caught exception with full stack trace.
     */
    public static void logException(Exception e, String module, String methodName) {
        logException(e, module, methodName, null, null);
    }

    public static void logException(Exception e, String module, String methodName, String relatedRecordId) {
        logException(e, module, methodName, relatedRecordId, null);
    }

    public static void logException(
        Exception e,
        String    module,
        String    methodName,
        String    relatedRecordId,
        String    className
    ) {
        Application_Log__c logRecord = new Application_Log__c(
            Log_Level__c         = LEVEL_ERROR,
            Module__c            = module,
            Method_Name__c       = methodName,
            Message__c           = truncate(e.getMessage(), 131072),
            Stack_Trace__c       = truncate(e.getStackTraceString(), 131072),
            Related_Record_Id__c = relatedRecordId,
            Class_Name__c        = className != null ? className : e.getTypeName(),
            Log_Timestamp__c     = System.now()
        );
        logBuffer.add(logRecord);
    }

    /**
     * @description Log an inbound or outbound API call.
     */
    public static void logApiCall(
        String  module,
        String  methodName,
        String  endpoint,
        String  requestBody,
        String  responseBody,
        Integer httpStatusCode,
        String  relatedRecordId
    ) {
        Application_Log__c logRecord = new Application_Log__c(
            Log_Level__c         = (httpStatusCode != null && httpStatusCode >= 400) ? LEVEL_ERROR : LEVEL_INFO,
            Module__c            = module,
            Method_Name__c       = methodName,
            Endpoint__c          = truncate(endpoint, 255),
            Request_Body__c      = truncate(requestBody, 131072),
            Response_Body__c     = truncate(responseBody, 131072),
            HTTP_Status_Code__c  = httpStatusCode,
            Related_Record_Id__c = relatedRecordId,
            Log_Timestamp__c     = System.now()
        );
        logBuffer.add(logRecord);
    }

    /**
     * @description Write the buffer to the database.
     *              Call once at the end of the transaction (e.g., at the end of a service method or trigger handler).
     *              Uses Database.insert with allOrNone=false so a failed log does not roll back business DML.
     */
    public static void flush() {
        if (logBuffer.isEmpty()) return;
        Database.insert(logBuffer, false);
        logBuffer.clear();
    }

    /**
     * @description Synchronous write — bypasses buffer, writes immediately.
     *              Use sparingly (e.g., in catch blocks where flush may never be reached).
     */
    public static void flushImmediate() {
        flush();
    }

    /**
     * @description Returns current buffer size — useful in tests.
     */
    @TestVisible
    public static Integer getBufferSize() {
        return logBuffer.size();
    }

    /**
     * @description Clear the buffer without writing — use in tests.
     */
    @TestVisible
    public static void clearBuffer() {
        logBuffer.clear();
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ───────────────────────────────────────────────────────────────────────────

    private static String truncate(String value, Integer maxLength) {
        if (value == null) return null;
        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }
}
