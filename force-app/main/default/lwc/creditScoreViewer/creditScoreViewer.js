import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import submitAnalystDecision from '@salesforce/apex/CreditService.submitAnalystDecision';

// Credit score gauge constants
const GAUGE_RADIUS     = 80;
const GAUGE_CX         = 100;
const GAUGE_CY         = 100;
const MIN_ANGLE        = -180; // degrees
const MAX_ANGLE        = 0;
const MIN_SCORE        = 300;
const MAX_SCORE        = 900;

const GRADE_CONFIG = {
    A: { color: '#22c55e', description: 'Excellent Credit — High approval likelihood' },
    B: { color: '#84cc16', description: 'Good Credit — Favorable terms expected'       },
    C: { color: '#f59e0b', description: 'Fair Credit — Standard terms, review needed'  },
    D: { color: '#f97316', description: 'Poor Credit — Higher risk, possible conditions'},
    E: { color: '#ef4444', description: 'Very Poor — Likely rejection or high risk'     }
};

export default class CreditScoreViewer extends LightningElement {

    @api recordId; // Credit_Assessment__c Id
    @api loanApplicationId;

    @track assessment = {};
    @track creditScore = 0;
    @track riskGrade = '';
    @track analystDecision = '';
    @track analystRemarks = '';
    @track isSubmitting = false;

    get gradeColor() {
        return (GRADE_CONFIG[this.riskGrade] || GRADE_CONFIG['E']).color;
    }

    get gradeDescription() {
        return (GRADE_CONFIG[this.riskGrade] || GRADE_CONFIG['E']).description;
    }

    get gradeBadgeStyle() {
        const color = this.gradeColor;
        return `background: ${color}20; border: 2px solid ${color}; color: ${color}`;
    }

    get scoreArcPath() {
        const score       = Math.max(MIN_SCORE, Math.min(MAX_SCORE, this.creditScore));
        const percentage  = (score - MIN_SCORE) / (MAX_SCORE - MIN_SCORE);
        const angleRange  = 180; // degrees (from -180 to 0 = half circle)
        const endAngleDeg = -180 + percentage * angleRange;
        const endAngleRad = (endAngleDeg * Math.PI) / 180;

        const startX = GAUGE_CX - GAUGE_RADIUS; // 20
        const startY = GAUGE_CY;                // 100
        const endX   = GAUGE_CX + GAUGE_RADIUS * Math.cos(endAngleRad);
        const endY   = GAUGE_CY + GAUGE_RADIUS * Math.sin(endAngleRad);
        const largeArcFlag = percentage > 0.5 ? 1 : 0;

        return `M ${startX} ${startY} A ${GAUGE_RADIUS} ${GAUGE_RADIUS} 0 ${largeArcFlag} 1 ${endX.toFixed(2)} ${endY.toFixed(2)}`;
    }

    get assessmentDate() {
        if (!this.assessment.Score_Pull_Date__c) return '';
        return new Date(this.assessment.Score_Pull_Date__c).toLocaleDateString('en-IN');
    }

    get totalOutstandingFormatted() {
        return this.formatCurrency(this.assessment.Total_Outstanding__c);
    }

    get overdueFlag() {
        return this.assessment.Overdue_Accounts__c > 0 ? 'warn' : 'ok';
    }

    get overdueLabel() {
        return this.assessment.Overdue_Accounts__c > 0 ? 'Attention' : 'Clean';
    }

    get hasAnalystDecision() {
        return !!this.assessment.Analyst_Decision__c;
    }

    get decisionOptions() {
        return [
            { label: 'Approve',       value: 'Approved'  },
            { label: 'Recommend',     value: 'Recommend' },
            { label: 'Reject',        value: 'Rejected'  },
            { label: 'Hold for Info', value: 'On Hold'   }
        ];
    }

    @wire(getRecord, { recordId: '$recordId', fields: [
        'Credit_Assessment__c.Credit_Score__c',
        'Credit_Assessment__c.Risk_Grade__c',
        'Credit_Assessment__c.Bureau_Reference__c',
        'Credit_Assessment__c.Score_Pull_Date__c',
        'Credit_Assessment__c.Total_Active_Accounts__c',
        'Credit_Assessment__c.Overdue_Accounts__c',
        'Credit_Assessment__c.Total_Outstanding__c',
        'Credit_Assessment__c.Analyst_Decision__c',
        'Credit_Assessment__c.Analyst_Remarks__c'
    ]})
    wiredRecord({ data, error }) {
        if (data) {
            this.assessment    = data.fields;
            this.creditScore   = getFieldValue(data, 'Credit_Assessment__c.Credit_Score__c') || 0;
            this.riskGrade     = getFieldValue(data, 'Credit_Assessment__c.Risk_Grade__c') || 'E';
        }
    }

    handleDecisionChange(event) {
        this.analystDecision = event.detail.value;
    }

    handleRemarksChange(event) {
        this.analystRemarks = event.detail.value;
    }

    async submitDecision() {
        if (!this.analystDecision) {
            this.showToast('Validation', 'Please select a decision.', 'warning');
            return;
        }
        this.isSubmitting = true;
        try {
            await submitAnalystDecision({
                assessmentId : this.recordId,
                decision     : this.analystDecision,
                remarks      : this.analystRemarks
            });
            this.showToast('Success', 'Decision submitted successfully.', 'success');
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to submit decision.', 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    formatCurrency(value) {
        if (value == null) return '0';
        return new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 }).format(value);
    }
}
