import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import savePropertyDetail from '@salesforce/apex/PropertyValuationService.savePropertyDetail';

const MAX_LTV_HOME    = 80;
const MAX_LTV_VEHICLE = 85;
const MAX_LTV_LAP     = 75;

export default class PropertyValuationForm extends LightningElement {

    @api recordId;       // Loan_Application__c Id
    @api propertyDetailId; // Property_Detail__c Id (if editing)
    @api loanAmount = 0;

    @track propertyType = '';
    @track collateralCategory = '';
    @track propertyAddress = '';
    @track city = '';
    @track state = '';
    @track pincode = '';
    @track ownershipType = '';
    @track constructionStatus = '';
    @track propertyAreaSqFt = null;
    @track plotAreaSqFt = null;
    @track yearOfConstruction = null;
    @track marketValue = null;
    @track forcedSaleValue = null;
    @track valuationDate = '';
    @track valuationReportRef = '';
    @track titleStatus = '';
    @track titleVerifiedBy = '';
    @track valuationRemarks = '';
    @track legalRemarks = '';
    @track isSaving = false;

    get propertyTypeOptions() {
        return [
            { label: 'Residential Apartment', value: 'Residential Apartment' },
            { label: 'Independent House / Villa', value: 'Independent House' },
            { label: 'Commercial Property', value: 'Commercial Property'      },
            { label: 'Plot / Land', value: 'Plot'                             },
            { label: 'Industrial Property', value: 'Industrial Property'      }
        ];
    }

    get collateralOptions() {
        return [
            { label: 'Primary Collateral', value: 'Primary'   },
            { label: 'Additional Collateral', value: 'Additional' }
        ];
    }

    get ownershipOptions() {
        return [
            { label: 'Freehold', value: 'Freehold'   },
            { label: 'Leasehold', value: 'Leasehold' },
            { label: 'Co-Ownership', value: 'Co-Ownership' }
        ];
    }

    get constructionOptions() {
        return [
            { label: 'Ready to Move', value: 'Ready'        },
            { label: 'Under Construction', value: 'Under Construction' },
            { label: 'Completed', value: 'Completed'        }
        ];
    }

    get titleStatusOptions() {
        return [
            { label: 'Clear', value: 'Clear'           },
            { label: 'Encumbered', value: 'Encumbered' },
            { label: 'Disputed', value: 'Disputed'     },
            { label: 'Pending Verification', value: 'Pending' }
        ];
    }

    get maxLTV() {
        if (this.propertyType === 'Commercial Property') return MAX_LTV_LAP;
        if (this.propertyType === 'Plot') return MAX_LTV_LAP;
        return MAX_LTV_HOME;
    }

    get ltvRatio() {
        if (!this.marketValue || !this.loanAmount) return 0;
        return ((this.loanAmount / this.marketValue) * 100).toFixed(2);
    }

    get showLTV() {
        return this.marketValue && this.loanAmount;
    }

    get ltvFlag() {
        return parseFloat(this.ltvRatio) > this.maxLTV ? 'breach' : 'ok';
    }

    get ltvStatus() {
        return parseFloat(this.ltvRatio) > this.maxLTV
            ? '⚠️ Exceeds Maximum LTV'
            : '✅ Within Limit';
    }

    get ltvBarStyle() {
        const percent = Math.min(100, (parseFloat(this.ltvRatio) / this.maxLTV) * 100);
        const color   = parseFloat(this.ltvRatio) > this.maxLTV ? '#ef4444' : '#22c55e';
        return `width: ${percent}%; background: ${color}`;
    }

    get loanAmountFormatted() { return this.formatCurrency(this.loanAmount); }
    get marketValueFormatted() { return this.formatCurrency(this.marketValue); }

    get isSubmitDisabled() {
        return this.isSaving || !this.marketValue || !this.titleStatus;
    }

    handleChange(event) {
        const field = event.currentTarget.dataset.field;
        this[field] = event.detail.value;
    }

    handleValuationChange(event) {
        const field = event.currentTarget.dataset.field;
        this[field] = parseFloat(event.detail.value) || null;
    }

    async saveDraft() {
        await this.save('Draft');
    }

    async submitValuation() {
        await this.save('Completed');
    }

    async save(valuationStatus) {
        this.isSaving = true;
        try {
            const params = {
                loanApplicationId    : this.recordId,
                propertyDetailId     : this.propertyDetailId,
                propertyType         : this.propertyType,
                collateralCategory   : this.collateralCategory,
                propertyAddress      : this.propertyAddress,
                city                 : this.city,
                state                : this.state,
                pincode              : this.pincode,
                ownershipType        : this.ownershipType,
                constructionStatus   : this.constructionStatus,
                propertyAreaSqFt     : this.propertyAreaSqFt,
                plotAreaSqFt         : this.plotAreaSqFt,
                yearOfConstruction   : this.yearOfConstruction,
                marketValue          : this.marketValue,
                forcedSaleValue      : this.forcedSaleValue,
                ltvRatio             : parseFloat(this.ltvRatio),
                valuationDate        : this.valuationDate,
                valuationReportRef   : this.valuationReportRef,
                titleStatus          : this.titleStatus,
                titleVerifiedBy      : this.titleVerifiedBy,
                valuationRemarks     : this.valuationRemarks,
                legalRemarks         : this.legalRemarks,
                valuationStatus      : valuationStatus
            };
            await savePropertyDetail({ params });
            this.showToast('Success',
                valuationStatus === 'Completed'
                    ? 'Valuation submitted successfully.'
                    : 'Draft saved.',
                'success');
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Save failed.', 'error');
        } finally {
            this.isSaving = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    formatCurrency(value) {
        if (!value) return '0';
        return new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 }).format(value);
    }
}
