import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCollectionDashboardData from '@salesforce/apex/CollectionsService.getCollectionDashboardData';
import updateCollectionCase from '@salesforce/apex/CollectionsService.updateCollectionCase';
import runCollectionsBatch from '@salesforce/apex/CollectionsBatch.executeNow';

const CASE_COLUMNS = [
    { label: 'Case #',          fieldName: 'Name',             type: 'text'     },
    { label: 'Loan Application',fieldName: 'loanAppName',      type: 'text'     },
    { label: 'DPD',             fieldName: 'DPD__c',           type: 'number'   },
    { label: 'Bucket',          fieldName: 'Bucket__c',        type: 'text'     },
    { label: 'Overdue (₹)',     fieldName: 'Overdue_Amount__c',type: 'currency', typeAttributes: { currencyCode: 'INR' } },
    { label: 'Status',          fieldName: 'Collection_Status__c', type: 'text' },
    { label: 'PTP Date',        fieldName: 'Promise_To_Pay_Date__c', type: 'date' },
    {
        type    : 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Update Case',    name: 'update'  },
                { label: 'Create Task',    name: 'task'    },
                { label: 'Mark Resolved',  name: 'resolve' }
            ]
        }
    }
];

export default class CollectionsDashboard extends LightningElement {

    @track collectionCases    = [];
    @track filteredCases      = [];
    @track selectedBucket     = '';
    @track selectedStatus     = '';
    @track showActionModal    = false;
    @track selectedCase       = {};
    @track promiseToPay       = '';
    @track contactRemarks     = '';
    @track selectedAction     = '';
    @track isBatchRunning     = false;
    @track isLoading          = true;

    // Summary KPI data
    @track totalOverdue         = 0;
    @track totalOverdueCount    = 0;
    @track bucket1Amount = 0;  @track bucket1Count = 0;
    @track bucket2Amount = 0;  @track bucket2Count = 0;
    @track bucket3Amount = 0;  @track bucket3Count = 0;
    @track npaAmount     = 0;  @track npaCount     = 0;

    caseColumns = CASE_COLUMNS;
    rowOffset   = 0;

    get todayDate() { return new Date().toLocaleDateString('en-IN'); }

    // Formatted KPIs
    get totalOverdueFormatted()   { return this.fmt(this.totalOverdue);  }
    get bucket1AmountFormatted()  { return this.fmt(this.bucket1Amount); }
    get bucket2AmountFormatted()  { return this.fmt(this.bucket2Amount); }
    get bucket3AmountFormatted()  { return this.fmt(this.bucket3Amount); }
    get npaAmountFormatted()      { return this.fmt(this.npaAmount);     }

    // Bar chart styles (relative to largest bucket)
    get maxCount() { return Math.max(this.bucket1Count, this.bucket2Count, this.bucket3Count, this.npaCount, 1); }
    get bucket1BarStyle() { return `width: ${(this.bucket1Count / this.maxCount) * 100}%`; }
    get bucket2BarStyle() { return `width: ${(this.bucket2Count / this.maxCount) * 100}%`; }
    get bucket3BarStyle() { return `width: ${(this.bucket3Count / this.maxCount) * 100}%`; }
    get npaBarStyle()     { return `width: ${(this.npaCount     / this.maxCount) * 100}%`; }

    get bucketFilterOptions() {
        return [
            { label: 'All Buckets',    value: ''    },
            { label: '1–30 DPD',       value: '1-30' },
            { label: '31–60 DPD',      value: '31-60'},
            { label: '61–90 DPD',      value: '61-90'},
            { label: 'NPA (90+ DPD)',  value: 'NPA' }
        ];
    }

    get statusFilterOptions() {
        return [
            { label: 'All Statuses',   value: ''           },
            { label: 'Open',           value: 'Open'       },
            { label: 'In Progress',    value: 'In Progress'},
            { label: 'PTP Given',      value: 'PTP Given'  },
            { label: 'Resolved',       value: 'Resolved'   }
        ];
    }

    get actionOptions() {
        return [
            { label: 'Verbal PTP',   value: 'PTP Given'   },
            { label: 'Escalate',     value: 'Escalated'   },
            { label: 'No Contact',   value: 'No Contact'  },
            { label: 'Field Visit',  value: 'Field Visit' }
        ];
    }

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        this.isLoading = true;
        try {
            const data = await getCollectionDashboardData();
            this.collectionCases    = (data.cases || []).map(c => ({
                ...c,
                loanAppName: c.Loan_Application__r?.Name
            }));
            this.filteredCases      = [...this.collectionCases];

            const summary = data.summary || {};
            this.totalOverdue      = summary.totalOverdue     || 0;
            this.totalOverdueCount = summary.totalCount       || 0;
            this.bucket1Amount     = summary.bucket1Amount    || 0;
            this.bucket1Count      = summary.bucket1Count     || 0;
            this.bucket2Amount     = summary.bucket2Amount    || 0;
            this.bucket2Count      = summary.bucket2Count     || 0;
            this.bucket3Amount     = summary.bucket3Amount    || 0;
            this.bucket3Count      = summary.bucket3Count     || 0;
            this.npaAmount         = summary.npaAmount        || 0;
            this.npaCount          = summary.npaCount         || 0;
        } catch (error) {
            this.showToast('Error', 'Failed to load dashboard data.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    refreshData() { this.loadData(); }

    handleBucketFilter(event) {
        this.selectedBucket = event.detail.value;
        this.applyFilters();
    }

    handleStatusFilter(event) {
        this.selectedStatus = event.detail.value;
        this.applyFilters();
    }

    applyFilters() {
        this.filteredCases = this.collectionCases.filter(c => {
            const bucketMatch = !this.selectedBucket || c.Bucket__c === this.selectedBucket;
            const statusMatch = !this.selectedStatus || c.Collection_Status__c === this.selectedStatus;
            return bucketMatch && statusMatch;
        });
    }

    handleRowAction(event) {
        const { action, row } = event.detail;
        this.selectedCase = row;
        if (action.name === 'update') {
            this.showActionModal = true;
        } else if (action.name === 'resolve') {
            this.resolveCase(row.Id);
        }
    }

    closeModal() { this.showActionModal = false; }
    stopPropagation(event) { event.stopPropagation(); }

    handlePTPChange(event)     { this.promiseToPay    = event.detail.value; }
    handleRemarksChange(event) { this.contactRemarks  = event.detail.value; }
    handleActionSelect(event)  { this.selectedAction  = event.detail.value; }

    async saveAction() {
        try {
            await updateCollectionCase({
                caseId           : this.selectedCase.Id,
                status           : this.selectedAction || 'In Progress',
                promiseToPay     : this.promiseToPay,
                contactRemarks   : this.contactRemarks
            });
            this.showToast('Success', 'Case updated successfully.', 'success');
            this.closeModal();
            this.loadData();
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Update failed.', 'error');
        }
    }

    async resolveCase(caseId) {
        try {
            await updateCollectionCase({ caseId, status: 'Resolved', promiseToPay: null, contactRemarks: 'Marked resolved' });
            this.showToast('Success', 'Case marked as resolved.', 'success');
            this.loadData();
        } catch (error) {
            this.showToast('Error', 'Failed to resolve case.', 'error');
        }
    }

    async runBatch() {
        this.isBatchRunning = true;
        try {
            await runCollectionsBatch();
            this.showToast('Success', 'Collections batch has been queued.', 'success');
            setTimeout(() => { this.loadData(); }, 3000);
        } catch (error) {
            this.showToast('Error', 'Failed to start batch.', 'error');
        } finally {
            this.isBatchRunning = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    fmt(value) {
        return '₹' + new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 }).format(value || 0);
    }
}
