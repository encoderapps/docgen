import { LightningElement, wire, track } from 'lwc';
import getTemplates from '@salesforce/apex/TemplateLwcController.getTemplates';
import getAllObjects from '@salesforce/apex/TemplateLwcController.getAllObjects';
import runBatch from '@salesforce/apex/TemplateLwcController.runBatch';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class TemplateBatchRunner extends LightningElement {

    @track templateOptions = [];
    @track objectOptions = [];

    selectedTemplate;
    selectedObject;
    isLoading = false;

    // Fetch Templates
    @wire(getTemplates)
    wiredTemplates({ data, error }) {
        if (data) {
            this.templateOptions = data.map(item => ({
                label: item.Name,
                value: item.Id
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load templates', 'error');
        }
    }

    // Fetch Objects
    @wire(getAllObjects)
    wiredObjects({ data, error }) {
        if (data) {
            this.objectOptions = data.map(obj => ({
                label: obj,
                value: obj
            }));
        } else if (error) {
            this.showToast('Error', 'Failed to load objects', 'error');
        }
    }

    handleTemplateChange(event) {
        this.selectedTemplate = event.detail.value;
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
    }

    // Run Batch
    handleRun() {

        if (!this.selectedTemplate || !this.selectedObject) {
            this.showToast('Error', 'Please select both fields', 'error');
            return;
        }

        this.isLoading = true;

        runBatch({
            templateId: this.selectedTemplate,
            objectName: this.selectedObject
        })
        .then(jobId => {
            this.showToast(
                'Success',
                'Batch started. Job Id: ' + jobId,
                'success'
            );
        })
        .catch(error => {
            this.showToast(
                'Error',
                error?.body?.message || 'Something went wrong',
                'error'
            );
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}
