/**
 * @description       Abstract base class for the Trigger Framework.
 *                    Implements the Kevin O'Hara dispatcher pattern — one trigger
 *                    per object, one handler class per trigger.
 *                    Supports bypass, loop-count protection, and test-context override.
 * @author            LendSphere 360
 * @created           2024
 */
public abstract class TriggerHandler {

    // ───────────────────────────────────────────────────────────────────────────
    // Static state (shared across all handler instances in the transaction)
    // ───────────────────────────────────────────────────────────────────────────

    @TestVisible private static Map<String, LoopCount> loopCountMap;
    @TestVisible private static Set<String>            bypassedHandlers;

    static {
        loopCountMap     = new Map<String, LoopCount>();
        bypassedHandlers = new Set<String>();
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Instance state
    // ───────────────────────────────────────────────────────────────────────────

    @TestVisible private TriggerContext context;
    @TestVisible private Boolean        isTriggerExecuting;

    // ───────────────────────────────────────────────────────────────────────────
    // Constructor
    // ───────────────────────────────────────────────────────────────────────────

    public TriggerHandler() {
        setTriggerContext();
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Public — main entry point
    // ───────────────────────────────────────────────────────────────────────────

    /**
     * @description Call from the trigger body: new MyHandler().run();
     */
    public void run() {
        if (!validateRun()) return;
        addToLoopCount();

        switch on this.context {
            when BEFORE_INSERT   { beforeInsert();   }
            when BEFORE_UPDATE   { beforeUpdate();   }
            when BEFORE_DELETE   { beforeDelete();   }
            when AFTER_INSERT    { afterInsert();    }
            when AFTER_UPDATE    { afterUpdate();    }
            when AFTER_DELETE    { afterDelete();    }
            when AFTER_UNDELETE  { afterUndelete();  }
        }
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Public — loop count control
    // ───────────────────────────────────────────────────────────────────────────

    public void setMaxLoopCount(Integer max) {
        String handlerName = getHandlerName();
        if (!loopCountMap.containsKey(handlerName)) {
            loopCountMap.put(handlerName, new LoopCount(max));
        } else {
            loopCountMap.get(handlerName).setMax(max);
        }
    }

    public void clearMaxLoopCount() {
        setMaxLoopCount(-1);
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Public Static — bypass control (use in tests or integration callouts)
    // ───────────────────────────────────────────────────────────────────────────

    public static void bypass(String handlerName) {
        bypassedHandlers.add(handlerName);
    }

    public static void clearBypass(String handlerName) {
        bypassedHandlers.remove(handlerName);
    }

    public static Boolean isBypassed(String handlerName) {
        return bypassedHandlers.contains(handlerName);
    }

    public static void clearAllBypasses() {
        bypassedHandlers.clear();
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Protected Virtual — override in subclass (only what you need)
    // ───────────────────────────────────────────────────────────────────────────

    @TestVisible protected virtual void beforeInsert()  {}
    @TestVisible protected virtual void beforeUpdate()  {}
    @TestVisible protected virtual void beforeDelete()  {}
    @TestVisible protected virtual void afterInsert()   {}
    @TestVisible protected virtual void afterUpdate()   {}
    @TestVisible protected virtual void afterDelete()   {}
    @TestVisible protected virtual void afterUndelete() {}

    // ───────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ───────────────────────────────────────────────────────────────────────────

    @TestVisible
    private void setTriggerContext() {
        setTriggerContext(null, false);
    }

    @TestVisible
    private void setTriggerContext(String ctx, Boolean testMode) {
        if (!Trigger.isExecuting && !testMode) {
            this.isTriggerExecuting = false;
            return;
        }
        this.isTriggerExecuting = true;

        if      ((Trigger.isExecuting && Trigger.isBefore && Trigger.isInsert)   || ctx == 'before insert')   { this.context = TriggerContext.BEFORE_INSERT;  }
        else if ((Trigger.isExecuting && Trigger.isBefore && Trigger.isUpdate)   || ctx == 'before update')   { this.context = TriggerContext.BEFORE_UPDATE;  }
        else if ((Trigger.isExecuting && Trigger.isBefore && Trigger.isDelete)   || ctx == 'before delete')   { this.context = TriggerContext.BEFORE_DELETE;  }
        else if ((Trigger.isExecuting && Trigger.isAfter  && Trigger.isInsert)   || ctx == 'after insert')    { this.context = TriggerContext.AFTER_INSERT;   }
        else if ((Trigger.isExecuting && Trigger.isAfter  && Trigger.isUpdate)   || ctx == 'after update')    { this.context = TriggerContext.AFTER_UPDATE;   }
        else if ((Trigger.isExecuting && Trigger.isAfter  && Trigger.isDelete)   || ctx == 'after delete')    { this.context = TriggerContext.AFTER_DELETE;   }
        else if ((Trigger.isExecuting && Trigger.isAfter  && Trigger.isUndelete) || ctx == 'after undelete')  { this.context = TriggerContext.AFTER_UNDELETE; }
    }

    private void addToLoopCount() {
        String handlerName = getHandlerName();
        if (loopCountMap.containsKey(handlerName)) {
            Boolean exceeded = loopCountMap.get(handlerName).increment();
            if (exceeded) {
                Integer max = loopCountMap.get(handlerName).getMax();
                throw new TriggerHandlerException(
                    'Maximum loop count of ' + max + ' reached in ' + handlerName
                );
            }
        }
    }

    private Boolean validateRun() {
        if (!this.isTriggerExecuting || this.context == null) {
            throw new TriggerHandlerException('TriggerHandler called outside of Trigger execution context.');
        }
        return !bypassedHandlers.contains(getHandlerName());
    }

    @TestVisible
    private String getHandlerName() {
        return String.valueOf(this).substringBefore(':');
    }

    // ───────────────────────────────────────────────────────────────────────────
    // Inner Classes
    // ───────────────────────────────────────────────────────────────────────────

    @TestVisible
    public enum TriggerContext {
        BEFORE_INSERT, BEFORE_UPDATE, BEFORE_DELETE,
        AFTER_INSERT,  AFTER_UPDATE,  AFTER_DELETE,
        AFTER_UNDELETE
    }

    @TestVisible
    private class LoopCount {
        private Integer max;
        private Integer count;

        public LoopCount()            { this.max = 5; this.count = 0; }
        public LoopCount(Integer max) { this.max = max; this.count = 0; }

        public Boolean increment() { this.count++; return exceeded(); }
        public Boolean exceeded()  { return this.max >= 0 && this.count > this.max; }
        public Integer getMax()    { return this.max; }
        public Integer getCount()  { return this.count; }
        public void setMax(Integer max) { this.max = max; }
    }

    public class TriggerHandlerException extends Exception {}
}
