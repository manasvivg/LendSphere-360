import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class EmiCalculator extends NavigationMixin(LightningElement) {

    @api defaultAmount    = 1000000;
    @api defaultRate      = 10.5;
    @api defaultTenure    = 120;
    @api showApplyButton  = false;

    @track loanAmount   = this.defaultAmount;
    @track interestRate = this.defaultRate;
    @track tenureMonths = this.defaultTenure;

    // ─── Computed properties ─────────────────────────────────────────────────────

    get monthlyEMI() {
        const emi = this.computeEMI(this.loanAmount, this.interestRate, this.tenureMonths);
        return this.formatCurrency(Math.round(emi));
    }

    get totalPayable() {
        const emi   = this.computeEMI(this.loanAmount, this.interestRate, this.tenureMonths);
        return Math.round(emi * this.tenureMonths);
    }

    get totalInterest() {
        return Math.max(0, this.totalPayable - this.loanAmount);
    }

    get principalFormatted()    { return this.formatCurrency(this.loanAmount);   }
    get totalInterestFormatted(){ return this.formatCurrency(this.totalInterest); }
    get totalPayableFormatted() { return this.formatCurrency(this.totalPayable);  }

    get interestPercent() {
        if (!this.totalPayable) return 0;
        return Math.round((this.totalInterest / this.totalPayable) * 100);
    }

    get donutStyle() {
        // CSS conic-gradient for the donut chart
        const principalPct = 100 - this.interestPercent;
        return `background: conic-gradient(
            #3b82f6 0% ${principalPct}%,
            #f97316 ${principalPct}% 100%
        )`;
    }

    // ─── Slider event handlers ───────────────────────────────────────────────────

    handleAmountSlider(event) {
        this.loanAmount = parseInt(event.target.value) || 0;
    }

    handleAmountInput(event) {
        this.loanAmount = parseInt(event.target.value) || 0;
    }

    handleRateSlider(event) {
        this.interestRate = parseFloat(event.target.value) || 0;
    }

    handleRateInput(event) {
        this.interestRate = parseFloat(event.target.value) || 0;
    }

    handleTenureSlider(event) {
        this.tenureMonths = parseInt(event.target.value) || 1;
    }

    handleTenureInput(event) {
        this.tenureMonths = parseInt(event.target.value) || 1;
    }

    // ─── Actions ─────────────────────────────────────────────────────────────────

    applyNow() {
        this.dispatchEvent(new CustomEvent('applynow', {
            detail: {
                loanAmount  : this.loanAmount,
                interestRate: this.interestRate,
                tenureMonths: this.tenureMonths,
                estimatedEMI: this.computeEMI(this.loanAmount, this.interestRate, this.tenureMonths)
            }
        }));
        this[NavigationMixin.Navigate]({
            type: 'standard__component',
            attributes: { componentName: 'c__loanApplicationWizard' }
        });
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────────

    computeEMI(principal, annualRate, months) {
        if (!principal || !annualRate || !months) return 0;
        const r = annualRate / 100 / 12;
        const n = months;
        if (r === 0) return principal / n;
        return (principal * r * Math.pow(1 + r, n)) / (Math.pow(1 + r, n) - 1);
    }

    formatCurrency(value) {
        if (value == null) return '0';
        return new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 }).format(value);
    }
}
