import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getLoanProducts from '@salesforce/apex/LoanApplicationService.getActiveLoanProducts';
import createLoanApplication from '@salesforce/apex/LoanApplicationService.createLoanApplicationFromPortal';

const STEPS = [
    { id: 1, number: '1', label: 'Product', cssClass: 'step active' },
    { id: 2, number: '2', label: 'Applicant', cssClass: 'step' },
    { id: 3, number: '3', label: 'Co-Applicant', cssClass: 'step' },
    { id: 4, number: '4', label: 'Documents', cssClass: 'step' },
    { id: 5, number: '5', label: 'Review', cssClass: 'step' }
];

const PRODUCT_ICONS = {
    'Home Loan': '🏠',
    'Personal Loan': '💳',
    'Vehicle Loan': '🚗',
    'Loan Against Property': '🏢',
    'Business Loan': '💼'
};

export default class LoanApplicationWizard extends NavigationMixin(LightningElement) {

    @track currentStep = 1;
    @track steps = STEPS.map(s => ({ ...s }));
    @track loanProducts = [];
    @track selectedProduct = null;
    @track loanAmount = 500000;
    @track tenureMonths = 120;
    @track estimatedEMI = null;

    // Applicant fields
    @track applicantName = '';
    @track dateOfBirth = '';
    @track panNumber = '';
    @track aadhaarNumber = '';
    @track email = '';
    @track mobile = '';
    @track annualIncome = 0;
    @track employmentType = '';

    // Co-Applicant
    @track hasCoApplicant = false;
    @track coApplicantName = '';
    @track coApplicantPAN = '';
    @track relationship = '';
    @track coApplicantIncome = 0;

    // State
    @track consentGiven = false;
    @track isSubmitted = false;
    @track applicationNumber = '';
    @track applicationId = '';
    @track isSubmitting = false;

    @wire(getLoanProducts)
    wiredProducts({ data, error }) {
        if (data) {
            this.loanProducts = data.map(p => ({
                ...p,
                icon: PRODUCT_ICONS[p.Product_Type__c] || '💰',
                cardClass: 'product-card',
                minAmountFormatted: this.formatCurrency(p.Min_Amount__c),
                maxAmountFormatted: this.formatCurrency(p.Max_Amount__c)
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load loan products.', 'error');
        }
    }

    get employmentOptions() {
        return [
            { label: 'Salaried', value: 'Salaried' },
            { label: 'Self Employed - Professional', value: 'Self Employed - Professional' },
            { label: 'Self Employed - Business', value: 'Self Employed - Business' },
            { label: 'Government Employee', value: 'Government Employee' }
        ];
    }

    get relationshipOptions() {
        return [
            { label: 'Spouse', value: 'Spouse' },
            { label: 'Parent', value: 'Parent' },
            { label: 'Sibling', value: 'Sibling' },
            { label: 'Child', value: 'Child' }
        ];
    }

    get requiredDocuments() {
        const docs = [
            { type: 'PAN_CARD', label: 'PAN Card', icon: '🪪', hint: 'Front side of PAN card', accept: '.pdf,.jpg,.png', uploaded: false },
            { type: 'AADHAAR', label: 'Aadhaar Card', icon: '🪪', hint: 'Both sides of Aadhaar', accept: '.pdf,.jpg,.png', uploaded: false },
            { type: 'INCOME_PROOF', label: 'Income Proof', icon: '📄', hint: 'Last 3 months salary slips or ITR', accept: '.pdf', uploaded: false },
            { type: 'BANK_STATEMENT', label: 'Bank Statement', icon: '🏦', hint: 'Last 6 months bank statement', accept: '.pdf', uploaded: false }
        ];
        if (this.selectedProduct && this.selectedProduct.Requires_Collateral__c) {
            docs.push({ type: 'PROPERTY_DOC', label: 'Property Documents', icon: '🏠', hint: 'Title deed, NOC, etc.', accept: '.pdf', uploaded: false });
        }
        return docs;
    }

    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    get isStep5() { return this.currentStep === 5; }

    get nextButtonLabel() {
        return this.currentStep === 5 ? 'Submit Application' : 'Next →';
    }

    get isNextDisabled() {
        if (this.currentStep === 1) return !this.selectedProduct || !this.loanAmount;
        if (this.currentStep === 5) return !this.consentGiven || this.isSubmitting;
        return false;
    }

    get loanAmountFormatted() { return this.formatCurrency(this.loanAmount); }
    get maskedPAN() {
        if (!this.panNumber || this.panNumber.length < 4) return this.panNumber;
        return '••••••' + this.panNumber.slice(-4);
    }

    selectProduct(event) {
        const productId = event.currentTarget.dataset.id;
        this.selectedProduct = this.loanProducts.find(p => p.Id === productId);
        this.loanProducts = this.loanProducts.map(p => ({
            ...p,
            cardClass: p.Id === productId ? 'product-card selected' : 'product-card'
        }));
        this.loanAmount = this.selectedProduct.Min_Amount__c;
        this.tenureMonths = this.selectedProduct.Min_Tenure_Months__c;
        this.calculateEMI();
    }

    handleLoanAmountChange(event) {
        this.loanAmount = parseFloat(event.detail.value) || 0;
        this.calculateEMI();
    }

    handleTenureChange(event) {
        this.tenureMonths = parseInt(event.detail.value) || 12;
        this.calculateEMI();
    }

    calculateEMI() {
        if (!this.selectedProduct || !this.loanAmount || !this.tenureMonths) return;
        const principal = this.loanAmount;
        const monthlyRate = this.selectedProduct.Base_Interest_Rate__c / 100 / 12;
        const n = this.tenureMonths;
        const emi = (principal * monthlyRate * Math.pow(1 + monthlyRate, n)) /
                    (Math.pow(1 + monthlyRate, n) - 1);
        this.estimatedEMI = this.formatCurrency(Math.round(emi));
    }

    handleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        this[field] = event.detail.value;
    }

    toggleCoApplicant(event) {
        this.hasCoApplicant = event.detail.checked;
    }

    toggleConsent(event) {
        this.consentGiven = event.detail.checked;
    }

    handleUploadFinished(event) {
        const docType = event.target.name;
        this.showToast('Success', docType + ' uploaded successfully.', 'success');
    }

    handleBack() {
        if (this.currentStep > 1) {
            this.currentStep -= 1;
            this.updateStepStyles();
        }
    }

    handleNext() {
        if (this.currentStep < 5) {
            this.currentStep += 1;
            this.updateStepStyles();
        } else {
            this.submitApplication();
        }
    }

    goToStep(event) {
        const targetStep = parseInt(event.currentTarget.dataset.step);
        if (targetStep < this.currentStep) {
            this.currentStep = targetStep;
            this.updateStepStyles();
        }
    }

    updateStepStyles() {
        this.steps = this.steps.map(s => ({
            ...s,
            cssClass: s.id < this.currentStep ? 'step completed'
                     : s.id === this.currentStep ? 'step active'
                     : 'step'
        }));
    }

    async submitApplication() {
        this.isSubmitting = true;
        try {
            const params = {
                productId       : this.selectedProduct.Id,
                loanAmount      : this.loanAmount,
                tenureMonths    : this.tenureMonths,
                applicantName   : this.applicantName,
                panNumber       : this.panNumber,
                aadhaarNumber   : this.aadhaarNumber,
                email           : this.email,
                mobile          : this.mobile,
                annualIncome    : this.annualIncome,
                employmentType  : this.employmentType,
                coApplicantName : this.hasCoApplicant ? this.coApplicantName : null,
                coApplicantPAN  : this.hasCoApplicant ? this.coApplicantPAN  : null
            };
            const result = await createLoanApplication({ params });
            this.applicationId     = result.Id;
            this.applicationNumber = result.Name;
            this.isSubmitted       = true;
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Submission failed.', 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    viewApplication() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: this.applicationId, actionName: 'view' }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    formatCurrency(value) {
        if (!value) return '0';
        return new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 }).format(value);
    }
}
