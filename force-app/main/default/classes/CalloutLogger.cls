/**
 * @description Shared utility for logging API callout requests and responses
 *              to Application_Log__c. Used by all integration callout classes.
 * @author      LendSphere 360
 * @version     1.0
 */
public with sharing class CalloutLogger {

    // ─── Inner DTO ─────────────────────────────────────────────────────────────

    /**
     * @description Encapsulates all data needed to log a single callout event.
     */
    public class CalloutLog {
        public String  module;
        public String  className;
        public String  methodName;
        public String  endpoint;
        public String  requestBody;
        public String  responseBody;
        public Integer httpStatusCode;
        public String  relatedRecordId;
        public String  logLevel;
        public String  message;
    }

    // ─── Public Methods ─────────────────────────────────────────────────────────

    /**
     * @description Logs a successful API callout.
     * @param log  Populated CalloutLog DTO
     */
    public static void logSuccess(CalloutLog log) {
        log.logLevel = 'INFO';
        if (String.isBlank(log.message)) {
            log.message = 'Callout succeeded. HTTP ' + log.httpStatusCode;
        }
        insertLog(log);
    }

    /**
     * @description Logs a failed or error API callout.
     * @param log  Populated CalloutLog DTO
     */
    public static void logError(CalloutLog log) {
        log.logLevel = 'ERROR';
        if (String.isBlank(log.message)) {
            log.message = 'Callout failed. HTTP ' + log.httpStatusCode;
        }
        insertLog(log);
    }

    /**
     * @description Logs a callout from an HttpRequest/HttpResponse pair.
     * @param req             HttpRequest that was sent
     * @param res             HttpResponse received
     * @param module          Module name (e.g. 'CreditBureau')
     * @param className       Calling class name
     * @param methodName      Calling method name
     * @param relatedRecordId SObject record ID being processed
     */
    public static void log(
        HttpRequest  req,
        HttpResponse res,
        String       module,
        String       className,
        String       methodName,
        String       relatedRecordId
    ) {
        CalloutLog entry = new CalloutLog();
        entry.module          = module;
        entry.className       = className;
        entry.methodName      = methodName;
        entry.endpoint        = req != null ? req.getEndpoint() : null;
        entry.requestBody     = req != null ? req.getBody()     : null;
        entry.responseBody    = res != null ? res.getBody()     : null;
        entry.httpStatusCode  = res != null ? res.getStatusCode() : 0;
        entry.relatedRecordId = relatedRecordId;

        if (res != null && res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            logSuccess(entry);
        } else {
            logError(entry);
        }
    }

    /**
     * @description Logs an exception encountered during a callout.
     * @param ex              Exception caught
     * @param module          Module name
     * @param className       Calling class name
     * @param methodName      Calling method name
     * @param relatedRecordId SObject record ID being processed
     */
    public static void logException(
        Exception ex,
        String    module,
        String    className,
        String    methodName,
        String    relatedRecordId
    ) {
        CalloutLog entry = new CalloutLog();
        entry.module          = module;
        entry.className       = className;
        entry.methodName      = methodName;
        entry.logLevel        = 'ERROR';
        entry.message         = ex.getMessage();
        entry.responseBody    = ex.getStackTraceString();
        entry.relatedRecordId = relatedRecordId;
        insertLog(entry);
    }

    // ─── Private Helpers ────────────────────────────────────────────────────────

    @SuppressWarnings('PMD.ApexCRUDViolation')
    private static void insertLog(CalloutLog log) {
        try {
            Application_Log__c record = new Application_Log__c(
                Module__c          = truncate(log.module,        80),
                Class_Name__c      = truncate(log.className,     80),
                Method_Name__c     = truncate(log.methodName,    80),
                Log_Level__c       = truncate(log.logLevel,      20),
                Message__c         = truncate(log.message,     255),
                Endpoint__c        = truncate(log.endpoint,    255),
                Request_Body__c    = truncate(log.requestBody,131072),
                Response_Body__c   = truncate(log.responseBody,131072),
                HTTP_Status_Code__c= log.httpStatusCode != null
                                        ? Decimal.valueOf(log.httpStatusCode)
                                        : null,
                Related_Record_Id__c = log.relatedRecordId,
                Log_Timestamp__c     = Datetime.now()
            );
            insert record; // NOPMD
        } catch (Exception ex) {
            // Silently absorb — logging must never break main flow
            System.debug(LoggingLevel.ERROR,
                'CalloutLogger.insertLog failed: ' + ex.getMessage());
        }
    }

    private static String truncate(String value, Integer maxLen) {
        if (value == null) { return null; }
        return value.length() > maxLen ? value.substring(0, maxLen) : value;
    }
}
