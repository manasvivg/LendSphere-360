import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getExistingDocuments from '@salesforce/apex/LoanApplicationService.getDocumentsByApplication';

const MAX_FILE_SIZE_MB = 10;
const ACCEPTED_TYPES   = ['application/pdf', 'image/jpeg', 'image/jpg', 'image/png'];
const TYPE_ICONS       = { 'application/pdf': '📄', 'image/jpeg': '🖼️', 'image/png': '🖼️' };

export default class DocumentUpload extends LightningElement {

    @api recordId;
    @api title = 'Upload Documents';
    @api subtitle = 'Upload KYC and supporting documents for your loan application.';

    @track selectedFiles = [];
    @track existingDocuments = [];
    @track isDragOver = false;
    @track isUploading = false;
    @track showToast = false;
    @track toastMessage = '';
    @track toastVariant = 'success';

    @wire(getExistingDocuments, { loanApplicationId: '$recordId' })
    wiredDocs({ data, error }) {
        if (data) { this.existingDocuments = data; }
    }

    get hasFiles()        { return this.selectedFiles.length > 0; }
    get hasExistingDocs() { return this.existingDocuments.length > 0; }
    get toastIcon()       { return this.toastVariant === 'success' ? '✅' : '❌'; }

    handleDragOver(event) {
        event.preventDefault();
        this.isDragOver = true;
    }

    handleDragLeave() {
        this.isDragOver = false;
    }

    handleDrop(event) {
        event.preventDefault();
        this.isDragOver = false;
        this.processFiles(Array.from(event.dataTransfer.files));
    }

    triggerFileInput() {
        this.template.querySelector('[data-id="fileInput"]').click();
    }

    handleFileSelect(event) {
        this.processFiles(Array.from(event.target.files));
    }

    processFiles(files) {
        const newFiles = [];
        for (const file of files) {
            if (!ACCEPTED_TYPES.includes(file.type)) {
                this.displayToast(`${file.name}: Unsupported file type.`, 'error');
                continue;
            }
            if (file.size > MAX_FILE_SIZE_MB * 1024 * 1024) {
                this.displayToast(`${file.name}: Exceeds ${MAX_FILE_SIZE_MB}MB limit.`, 'error');
                continue;
            }
            if (this.selectedFiles.find(f => f.name === file.name)) { continue; }

            newFiles.push({
                name        : file.name,
                size        : file.size,
                sizeLabel   : this.formatSize(file.size),
                type        : file.type,
                typeIcon    : TYPE_ICONS[file.type] || '📁',
                file        : file,
                progress    : 0,
                progressStyle: 'width: 0%',
                uploading   : false,
                uploaded    : false,
                error       : false,
                errorMessage: ''
            });
        }
        this.selectedFiles = [...this.selectedFiles, ...newFiles];
    }

    removeFile(event) {
        const fileName = event.currentTarget.dataset.name;
        this.selectedFiles = this.selectedFiles.filter(f => f.name !== fileName);
    }

    clearAll() {
        this.selectedFiles = [];
    }

    async uploadAll() {
        this.isUploading = true;
        for (let i = 0; i < this.selectedFiles.length; i++) {
            const fileEntry = this.selectedFiles[i];
            if (fileEntry.uploaded) { continue; }
            await this.uploadSingleFile(fileEntry, i);
        }
        this.isUploading = false;
        this.displayToast('All files uploaded successfully.', 'success');
    }

    async uploadSingleFile(fileEntry, index) {
        this.updateFile(index, { uploading: true, progress: 10, progressStyle: 'width: 10%' });

        try {
            const base64 = await this.readAsBase64(fileEntry.file);
            this.updateFile(index, { progress: 50, progressStyle: 'width: 50%' });

            // Upload via Content Version (standard Salesforce file upload)
            // In real impl: call an Apex controller to create ContentVersion
            // Simulating progress here for demonstration
            await this.delay(500);
            this.updateFile(index, { progress: 100, progressStyle: 'width: 100%', uploading: false, uploaded: true });
        } catch (error) {
            this.updateFile(index, { uploading: false, error: true, errorMessage: error.message });
        }
    }

    updateFile(index, updates) {
        const files = [...this.selectedFiles];
        files[index] = { ...files[index], ...updates };
        this.selectedFiles = files;
    }

    readAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload  = () => resolve(reader.result.split(',')[1]);
            reader.onerror = () => reject(new Error('File read failed'));
            reader.readAsDataURL(file);
        });
    }

    delay(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }

    displayToast(message, variant) {
        this.toastMessage = message;
        this.toastVariant = variant;
        this.showToast    = true;
        setTimeout(() => { this.showToast = false; }, 4000);
    }

    formatSize(bytes) {
        if (bytes < 1024) return bytes + ' B';
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
        return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
    }
}
