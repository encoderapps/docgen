import { LightningElement, api, track } from 'lwc';
import getTemplateByName from '@salesforce/apex/DynamicPdfController.getTemplateByName';
import fetchDynamicRecord from '@salesforce/apex/DynamicPdfController.fetchDynamicRecord';
import updateDynamicRecord from '@salesforce/apex/DynamicPdfController.updateDynamicRecord';

import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DynamicPdfGenerator extends LightningElement {

    @api recordId;
    @api objectApiName;

    @track finalHtml = '';
    @track isLoading = true;
    @track errorMessage = '';

    templateHtml = '';
    fieldRefs = [];

    connectedCallback() {
        this.initialize();
    }

   async initialize() {
    try {
        const template = await getTemplateByName({ 
            templateName: 'Sample Account' 
        });

        this.templateHtml = template || '';

        if (!this.templateHtml) {
            this.errorMessage = 'Template not found';
            return;
        }

        this.fieldRefs = this.extractFieldReferences(this.templateHtml);

        const dataMap = await fetchDynamicRecord({
            objectApiName: this.objectApiName,
            recordId: this.recordId,
            fieldPaths: this.fieldRefs
        });

        this.finalHtml = this.replaceTemplate(this.templateHtml, dataMap);

    } catch (error) {
        this.errorMessage = error?.body?.message || error.message;
    } finally {
        this.isLoading = false;
    }
}

    extractFieldReferences(template) {
        const regex = /\{\!\s*([a-zA-Z0-9_]+(?:\.[a-zA-Z0-9_]+){0,2})\s*\}/g;
        const fields = new Set();
        let match;

        while ((match = regex.exec(template)) !== null) {
            let ref = match[1];

            if (!ref.includes('.')) {
                ref = `${this.objectApiName}.${ref}`;
            }

            if (ref.split('.').length === 2) {
                const obj = ref.split('.')[0];
                if (obj !== this.objectApiName) {
                    ref = `${this.objectApiName}.${ref}`;
                }
            }

            fields.add(ref);
        }

        return Array.from(fields);
    }

    replaceTemplate(template, dataMap) {
        const regex = /\{\!\s*([a-zA-Z0-9_.]+)\s*\}/g;

        return `
            <div class="slds-box slds-theme_default slds-p-around_medium">
                ${template.replace(regex, (match, ref) => {

                    let key = ref;

                    if (!ref.includes('.')) {
                        key = `${this.objectApiName}.${ref}`;
                    }

                    if (ref.split('.').length === 2 && ref.split('.')[0] !== this.objectApiName) {
                        key = ref;
                    }

                    const value = this.escapeHTML(dataMap[key] || '');

                    
                    return `
                        <div class="field-row">
                            
                           <div class="field-label"></div>

                            <div class="field-input-wrapper">
                                <input  
                                    type="text"
                                    class="slds-input editable-field"
                                    value="${value}"
                                    data-field="${key}"
                                    disabled
                                />

                                <span class="edit-icon" title="Edit">
                                    <svg class="slds-icon slds-icon_x-small" aria-hidden="true">
                                        <use xlink:href="/_slds/icons/utility-sprite/svg/symbols.svg#edit"></use>
                                    </svg>
                                </span>
                            </div>

                        </div>
                    `;
                })}
            </div>
        `;
    }

    renderedCallback() {
        if (this.finalHtml) {
            const container = this.template.querySelector('.output-container');

            if (container && container.innerHTML !== this.finalHtml) {
                container.innerHTML = this.finalHtml;

                const icons = container.querySelectorAll('.edit-icon');

                icons.forEach(icon => {
                    icon.addEventListener('click', () => {
                        this.enableAllFields();
                    });
                });
            }
        }
    }

    enableAllFields() {
        const inputs = this.template.querySelectorAll('.editable-field');
        inputs.forEach(input => input.removeAttribute('disabled'));
    }

    handleSave() {
        const inputs = this.template.querySelectorAll('.editable-field');
        let fieldMap = {};

        inputs.forEach(input => {
            fieldMap[input.dataset.field] = input.value;
        });

        updateDynamicRecord({
            objectApiName: this.objectApiName,
            recordId: this.recordId,
            fieldValues: fieldMap
        })
        .then(() => {

            inputs.forEach(input => input.setAttribute('disabled', true));

            setTimeout(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Your PDF is generated!! Any changes will be reflected in the database.',
                        variant: 'success',
                        mode: 'sticky'
                    })
                );

                this.dispatchEvent(new CloseActionScreenEvent());

            }, 300);
        })
        .catch(error => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error?.body?.message || 'Something went wrong',
                    variant: 'error'
                })
            );
        });
    }

    escapeHTML(str) {
        return String(str)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
    }
}