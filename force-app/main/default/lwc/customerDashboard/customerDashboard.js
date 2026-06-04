import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import getCustomerDashboardData from '@salesforce/apex/LoanApplicationService.getCustomerDashboardData';
import userId from '@salesforce/user/Id';

const EMI_COLUMNS = [
    { label: 'EMI #',         fieldName: 'EMI_Number__c',   type: 'number',   initialWidth: 80  },
    { label: 'Due Date',      fieldName: 'Due_Date__c',      type: 'date'                        },
    { label: 'EMI Amount',    fieldName: 'EMI_Amount__c',    type: 'currency', typeAttributes: { currencyCode: 'INR' } },
    { label: 'Status',        fieldName: 'Status__c',        type: 'text'                        },
    { label: 'Outstanding',   fieldName: 'Outstanding_Balance__c', type: 'currency', typeAttributes: { currencyCode: 'INR' } }
];

export default class CustomerDashboard extends NavigationMixin(LightningElement) {

    @track customerName = '';
    @track activeLoans = [];
    @track upcomingEMIs = [];
    @track pendingApplications = [];
    @track totalPortfolio = 0;
    @track totalOutstanding = 0;
    @track nextEMIAmount = '';
    @track nextEMIDate = '';
    @track isLoading = true;

    emiColumns = EMI_COLUMNS;
    rowOffset = 0;

    connectedCallback() {
        this.loadDashboardData();
    }

    async loadDashboardData() {
        this.isLoading = true;
        try {
            const data = await getCustomerDashboardData({ userId });
            this.customerName          = data.customerName;
            this.activeLoans           = (data.activeLoans || []).map(l => ({
                ...l,
                sanctionedFormatted: this.formatCurrency(l.Sanctioned_Amount__c),
                progressPercent    : this.calcProgress(l),
                progressStyle      : `width: ${this.calcProgress(l)}%`
            }));
            this.upcomingEMIs          = data.upcomingEMIs || [];
            this.pendingApplications   = data.pendingApplications || [];
            this.totalPortfolio        = data.totalPortfolio || 0;
            this.totalOutstanding      = data.totalOutstanding || 0;

            if (data.nextEMI) {
                this.nextEMIDate   = new Date(data.nextEMI.Due_Date__c).toLocaleDateString('en-IN');
                this.nextEMIAmount = this.formatCurrency(data.nextEMI.EMI_Amount__c);
            }
        } catch (error) {
            this.showToast('Error', 'Failed to load dashboard data.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    get totalPortfolioFormatted() { return this.formatCurrency(this.totalPortfolio); }
    get totalOutstandingFormatted() { return this.formatCurrency(this.totalOutstanding); }
    get activeLoansCount() { return this.activeLoans.length; }
    get hasActiveLoans() { return this.activeLoans.length > 0; }
    get hasUpcomingEMIs() { return this.upcomingEMIs.length > 0; }
    get hasPendingApplications() { return this.pendingApplications.length > 0; }

    refreshLoans() {
        this.loadDashboardData();
    }

    viewLoanDetail(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName: 'view' }
        });
    }

    trackApplication(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, actionName: 'view' }
        });
    }

    applyForLoan() {
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: { componentName: 'c__loanApplicationWizard' }
        });
    }

    raiseCase() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Case', actionName: 'new' }
        });
    }

    viewAllEMIs() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'EMI_Schedule__c', actionName: 'list' }
        });
    }

    calcProgress(loan) {
        // Approximate: paid months / total months
        const totalMonths = loan.Tenure_Months__c || 1;
        const paidEMIs    = loan.paidEMICount || 0;
        return Math.min(Math.round((paidEMIs / totalMonths) * 100), 100);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    formatCurrency(value) {
        if (value == null) return '0';
        return new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 }).format(value);
    }
}
