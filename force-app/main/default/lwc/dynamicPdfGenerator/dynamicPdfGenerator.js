import { LightningElement, api, track } from 'lwc';
import getTemplateByName from '@salesforce/apex/DynamicPdfController.getTemplateByName';
import fetchDynamicRecord from '@salesforce/apex/DynamicPdfController.fetchDynamicRecord';
import updateDynamicRecord from '@salesforce/apex/DynamicPdfController.updateDynamicRecord';
import generateDocument from '@salesforce/apex/DynamicPdfController.generateDocument';

import { publish, MessageContext } from 'lightning/messageService';
import PDF_CHANNEL from '@salesforce/messageChannel/pdfMessageChannel__c';
import { wire } from 'lwc';

import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class dynamicPdfGenerator extends LightningElement {

    @api recordId;
    @api objectApiName;

    @track isEditMode = false;

    pendingEnable = false;
    isListenerAttached = false;

    @track finalHtml = '';
    @track isLoading = true;
    @track errorMessage = '';

    @track fileUrl;

    templateHtml = '';
    fieldRefs = [];

    @wire(MessageContext)
      messageContext;

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
        <div>
            ${template.replace(regex, (match, ref) => {

                let key = ref;

                if (!ref.includes('.')) {
                    key = `${this.objectApiName}.${ref}`;
                }

                if (ref.split('.').length === 2 && ref.split('.')[0] !== this.objectApiName) {
                    key = ref;
                }

                const value = this.escapeHTML(dataMap[key] || '');

                return (
                    '<span style="display:inline-flex; align-items:center; gap:6px;">' +

                        '<input ' +
                            'type="text" ' +
                            'class="editable-field" ' +
                            'value="' + value + '" ' +
                            'data-field="' + key + '" ' +
                            'style="width:250px;padding:6px;border:1px solid #ccc;border-radius:4px;margin-left:8px;" ' +
                            'disabled />' +

                        '<span class="edit-icon" title="Edit" style="cursor:pointer;">' +
                            '<svg style="width:14px;height:14px;fill:#0176d3;" aria-hidden="true">' +
                                '<use xlink:href="/_slds/icons/utility-sprite/svg/symbols.svg#edit"></use>' +
                            '</svg>' +
                        '</span>' +

                    '</span>'
                );
            })}
        </div>
    `;
}

 renderedCallback() {
    if (this.finalHtml) {
        const container = this.template.querySelector('.output-container');

        if (container && container.innerHTML !== this.finalHtml) {
            container.innerHTML = this.finalHtml;

            container.onclick = (event) => {
                if (event.target.closest('.edit-icon')) {
                    this.isEditMode = true;
                    this.pendingEnable = true;
                }
            };
        }

        if (this.pendingEnable) {
            this.enableAllFields();
            this.pendingEnable = false;
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

            this.isEditMode = false; 
        
             setTimeout(() => {
                 this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'Your changes are saved and will be reflected in the database.Click "Generate Documennt" to generate a PDF',
                            variant: 'success'
                       })
                    );
        },        300);
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

    escapeHTML(value) {
    if (!value) return '';

    return value
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

  handleGenerateDocument() {

    generateDocument({
        recordId: this.recordId,
        objectApiName: this.objectApiName,
        htmlContent: this.finalHtml
    })
    .then((result) => {

        this.fileUrl = result;

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Document generated successfully! You can find the document in the "Related list" section',
                variant: 'success'
            })
        );
        

        publish(this.messageContext, PDF_CHANNEL, {
            fileUrl: this.fileUrl
        });

          this.dispatchEvent(new CloseActionScreenEvent());

    })
    .catch(error => {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: error?.body?.message || 'Failed',
                variant: 'error'
            })
        );
    });
}
}