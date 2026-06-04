import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';

const STAGE_CONFIG = [
    { id: 'submitted',    title: 'Application Submitted',    icon: '📝', statusMatch: ['Submitted', 'Under Review', 'KYC Pending', 'KYC Completed', 'Credit Assessment', 'Property Evaluation', 'Sanctioned', 'Mandate Setup', 'Disbursed', 'Rejected'] },
    { id: 'kyc',          title: 'KYC Verification',         icon: '🪪', statusMatch: ['KYC Completed', 'Credit Assessment', 'Property Evaluation', 'Sanctioned', 'Mandate Setup', 'Disbursed'] },
    { id: 'credit',       title: 'Credit Assessment',        icon: '📊', statusMatch: ['Credit Assessment', 'Property Evaluation', 'Sanctioned', 'Mandate Setup', 'Disbursed'] },
    { id: 'property',     title: 'Property Evaluation',      icon: '🏠', statusMatch: ['Property Evaluation', 'Sanctioned', 'Mandate Setup', 'Disbursed'] },
    { id: 'sanctioned',   title: 'Loan Sanctioned',          icon: '✅', statusMatch: ['Sanctioned', 'Mandate Setup', 'Disbursed'] },
    { id: 'mandate',      title: 'Mandate Setup',            icon: '📱', statusMatch: ['Mandate Setup', 'Disbursed'] },
    { id: 'disbursed',    title: 'Loan Disbursed',           icon: '🏦', statusMatch: ['Disbursed'] }
];

const STATUS_MESSAGES = {
    'Submitted'         : { icon: '⏳', title: 'Application Under Review', message: 'Your application has been submitted and is being reviewed by our operations team.'  },
    'KYC Pending'       : { icon: '📋', title: 'KYC Verification Required', message: 'Please complete your KYC verification to proceed.'                                 },
    'KYC Completed'     : { icon: '✅', title: 'KYC Verified', message: 'Your KYC is complete. Credit assessment is in progress.'                                        },
    'Credit Assessment' : { icon: '🔍', title: 'Credit Review Ongoing', message: 'Our credit analyst is reviewing your credit profile.'                                  },
    'Property Evaluation': { icon: '🏠', title: 'Property Evaluation', message: 'Our valuation team is assessing the property details.'                                 },
    'Sanctioned'        : { icon: '🎉', title: 'Loan Approved!', message: 'Congratulations! Your loan is sanctioned. Please set up your repayment mandate.'             },
    'Mandate Setup'     : { icon: '📱', title: 'Setup Repayment Mandate', message: 'Please complete your UPI or eNACH mandate setup to receive disbursement.'            },
    'Disbursed'         : { icon: '🏦', title: 'Loan Disbursed!', message: 'Your loan amount has been credited to your account. EMI schedule is now active.'            },
    'Rejected'          : { icon: '❌', title: 'Application Rejected', message: 'We are unable to proceed with your application at this time.'                           }
};

export default class LoanTracker extends NavigationMixin(LightningElement) {

    @api recordId;

    @track applicationNumber = '';
    @track currentStatus = '';
    @track rejectionReason = '';
    @track stages = [];

    @wire(getRecord, { recordId: '$recordId', fields: [
        'Loan_Application__c.Name',
        'Loan_Application__c.Status__c',
        'Loan_Application__c.Rejection_Reason__c',
        'Loan_Application__c.Application_Date__c',
        'Loan_Application__c.Sanction_Date__c'
    ]})
    wiredRecord({ data, error }) {
        if (data) {
            this.applicationNumber = getFieldValue(data, 'Loan_Application__c.Name');
            this.currentStatus     = getFieldValue(data, 'Loan_Application__c.Status__c') || 'Submitted';
            this.rejectionReason   = getFieldValue(data, 'Loan_Application__c.Rejection_Reason__c');
            this.buildTimeline(data.fields);
        }
    }

    buildTimeline(fields) {
        const currentStatus = this.currentStatus;
        const isRejected    = currentStatus === 'Rejected';

        this.stages = STAGE_CONFIG.map((stage, idx) => {
            const isCompleted = stage.statusMatch.includes(currentStatus);
            const isCurrent   = this.isStageCurrent(stage.id, currentStatus);

            return {
                ...stage,
                id              : stage.id,
                isFirst         : idx === 0,
                prevCompleted   : idx > 0 && STAGE_CONFIG[idx - 1].statusMatch.includes(currentStatus),
                status          : isCompleted ? 'completed' : isCurrent ? 'active' : 'pending',
                statusLabel     : isCompleted ? 'Done ✓' : isCurrent ? 'In Progress' : 'Pending',
                description     : this.getStageDescription(stage.id),
                containerClass  : `timeline-stage ${isCompleted ? 'completed' : isCurrent ? 'active' : 'pending'}`,
                rejectionReason : (isRejected && isCurrent) ? this.rejectionReason : null
            };
        });
    }

    isStageCurrent(stageId, status) {
        const stageStatusMap = {
            'submitted'  : ['Submitted', 'Under Review', 'KYC Pending'],
            'kyc'        : ['KYC Pending', 'KYC Completed'],
            'credit'     : ['Credit Assessment'],
            'property'   : ['Property Evaluation'],
            'sanctioned' : ['Sanctioned', 'Rejected'],
            'mandate'    : ['Mandate Setup'],
            'disbursed'  : ['Disbursed']
        };
        return (stageStatusMap[stageId] || []).includes(status);
    }

    getStageDescription(stageId) {
        const descriptions = {
            'submitted'  : 'Application details captured and sent for initial review.',
            'kyc'        : 'PAN and Aadhaar verification via integrated KYC API.',
            'credit'     : 'Credit bureau score fetched and risk evaluated.',
            'property'   : 'Physical site visit and title clearance (for secured loans).',
            'sanctioned' : 'Branch Manager sanction approval completed.',
            'mandate'    : 'UPI AutoPay or eNACH mandate registration.',
            'disbursed'  : 'Loan amount credited to your registered bank account.'
        };
        return descriptions[stageId] || '';
    }

    get currentStatusIcon() {
        return (STATUS_MESSAGES[this.currentStatus] || {}).icon || '⏳';
    }

    get currentStatusTitle() {
        return (STATUS_MESSAGES[this.currentStatus] || {}).title || 'Processing';
    }

    get currentStatusMessage() {
        return (STATUS_MESSAGES[this.currentStatus] || {}).message || '';
    }

    get hasNextAction() {
        return ['KYC Pending', 'Sanctioned', 'Mandate Setup'].includes(this.currentStatus);
    }

    get nextActionLabel() {
        const labels = {
            'KYC Pending'  : 'Complete KYC',
            'Sanctioned'   : 'View Sanction Letter',
            'Mandate Setup': 'Setup Mandate'
        };
        return labels[this.currentStatus] || 'Continue';
    }

    get nextActionText() {
        const texts = {
            'KYC Pending'  : 'Complete your PAN and Aadhaar verification to proceed.',
            'Sanctioned'   : 'Download your sanction letter and set up your repayment mandate.',
            'Mandate Setup': 'Link your UPI ID or bank account for automatic EMI deduction.'
        };
        return texts[this.currentStatus] || '';
    }

    handleNextAction() {
        // Navigate to relevant section based on current status
        this.dispatchEvent(new CustomEvent('nextaction', {
            detail: { status: this.currentStatus, applicationId: this.recordId }
        }));
    }
}
