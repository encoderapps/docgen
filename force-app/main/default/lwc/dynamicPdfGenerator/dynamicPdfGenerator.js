import { LightningElement, api, track } from 'lwc';

import getTemplates from '@salesforce/apex/DynamicPdfController.getTemplateRecords';
import getMappedHtml from '@salesforce/apex/DynamicPdfController.getMappedHtml';
import fetchDynamicRecord from '@salesforce/apex/DynamicPdfController.fetchDynamicRecord';
import updateDynamicRecord from '@salesforce/apex/DynamicPdfController.updateDynamicRecord';
import generateDocument from '@salesforce/apex/DynamicPdfController.generateDocument';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DynamicPdfGenerator extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track templateOptions = [];
    @track selectedTemplateId;

    @track isNextClicked = false;
    @track finalHtml = '';
    @track fieldRefs = [];

    @track isEditMode = false;

    connectedCallback() {
        this.loadTemplates();
    }

    async loadTemplates() {
        const data = await getTemplates();

        this.templateOptions = data.map(t => ({
            label: t.Name,
            value: t.Id
        }));
    }

    handleTemplateChange(event) {
        this.selectedTemplateId = event.detail.value;
    }

    async handleNext() {
        if (!this.selectedTemplateId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Warning',
                    message: 'Please select a template first',
                    variant: 'warning'
                })
            );
            return;
        }

        try {
            this.isNextClicked = true;

            const templateData = await getMappedHtml({
                recordId: this.recordId,
                templateId: this.selectedTemplateId
            });

            const templateHtml = templateData.structure;

            this.fieldRefs = this.extractFieldReferences(templateHtml);

            const dataMap = await fetchDynamicRecord({
                objectApiName: this.objectApiName,
                recordId: this.recordId,
                fieldPaths: this.fieldRefs
            });

            this.finalHtml = this.replaceTemplate(templateHtml, dataMap);

            setTimeout(() => {
                this.renderHtml();
            }, 0);

        } catch (error) {
            console.error('Error in handleNext:', error);

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error?.body?.message || 'No data found for selected template',
                    variant: 'error'
                })
            );

            this.isNextClicked = false;
            this.finalHtml = '';
            this.fieldRefs = [];
        }
    }

    extractFieldReferences(template) {
        const regex = /\{\!\s*([a-zA-Z0-9_.]+)\s*\}/g;
        let fields = new Set();
        let match;

        while ((match = regex.exec(template)) !== null) {
            fields.add(match[1]);
        }

        return Array.from(fields);
    }

    replaceTemplate(template, dataMap) {
        const regex = /\{\!\s*([a-zA-Z0-9_.]+)\s*\}/g;

        return template.replace(regex, (match, ref) => {
            let key = ref.includes('.') ? ref : `${this.objectApiName}.${ref}`;
            const value = dataMap[key] || '';

            return `
                <span class="editable-wrapper">
                    <input 
                        type="text"
                        class="editable-field"
                        value="${value}"
                        data-field="${key}"
                        disabled
                    />
                    <span class="edit-icon">&#9998;</span>
                </span>
            `;
        });
    }

    renderHtml() {
        const container = this.template.querySelector('.output-container');

        if (container && this.finalHtml) {
            container.innerHTML = this.finalHtml;

            container.onclick = (event) => {
                let el = event.target;

                while (el && el !== container) {
                    if (el.classList?.contains('edit-icon')) {
                        this.isEditMode = true;
                        this.enableAllFields();
                        return;
                    }
                    el = el.parentNode;
                }
            };
        }
    }

    enableAllFields() {
        this.template.querySelectorAll('.editable-field')
            .forEach(i => i.removeAttribute('disabled'));
    }

    handleSave() {
        let fieldMap = {};
        const inputs = this.template.querySelectorAll('.editable-field');

        inputs.forEach(i => {
            fieldMap[i.dataset.field] = i.value;
        });

        updateDynamicRecord({
            objectApiName: this.objectApiName,
            recordId: this.recordId,
            fieldValues: fieldMap
        })
        .then(() => {
            this.isEditMode = false;

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Changes saved!',
                variant: 'success'
            }));
        });
    }

    handleGenerateDocument() {
        const container = this.template.querySelector('.output-container');
        if (container) {
            this.finalHtml = container.innerHTML;
        }

        generateDocument({
            recordId: this.recordId,
            objectApiName: this.objectApiName,
            htmlContent: this.finalHtml
        })
        .then((fileUrl) => {
            console.log('Generated PDF URL:', fileUrl);

            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Document generated successfully!',
                variant: 'success'
            }));
        })
        .catch((error) => {
            console.error('Error:', error);

            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: error?.body?.message || 'Failed to generate document',
                variant: 'error'
            }));
        });
    }
}