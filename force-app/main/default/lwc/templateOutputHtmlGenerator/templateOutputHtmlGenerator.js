import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import generateHtmlFromTemplate from '@salesforce/apex/TemplateProcessor.generateHtmlFromTemplate';

export default class TemplateOutputHtmlGenerator extends NavigationMixin(LightningElement) {

    @track isOpen = true;

    generateHTML() {

        const fields = this.template.querySelectorAll('lightning-input-field');

        let accountId;
        let templateId;
        let mappingId;

        fields.forEach(field => {
            if (field.fieldName === 'Account__c') accountId = field.value;
            if (field.fieldName === 'Template_Id__c') templateId = field.value;
            if (field.fieldName === 'Field_Mapping__c') mappingId = field.value;
        });

        if (!accountId || !templateId || !mappingId) {
            return;
        }

        createAndGenerate({
            accountId,
            templateId,
            mappingId
        })
        .then((recordId) => {

            // ✅ store returned Id
            this.recordId = recordId;

            // ✅ navigate to created record
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.recordId,
                    objectApiName: 'Template_Mapping_Output__c',
                    actionName: 'view'
                }
            });

        })
        .catch(error => {
            console.error('ERROR:', JSON.stringify(error));
        });
    }

    closeModal() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Your_Junction_Object__c',
                actionName: 'list'
            }
        });
    }
}