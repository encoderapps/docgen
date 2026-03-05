import { LightningElement, api, wire, track } from 'lwc';
import processHTMLData from '@salesforce/apex/APIHandlerController.processHTMLData';
import getRelatedFiles from '@salesforce/apex/APIHandlerController.getRelatedFiles';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ApiFileDownloader extends LightningElement {
    @api recordId;
    @track fileLogs;
    wiredLogsResult;

    @wire(getRelatedFiles, { parentId: '$recordId' })
    wiredLogs(result) {
        this.wiredLogsResult = result;
        if (result.data) {
            this.fileLogs = result.data;
        }
    }

    handleProcessClick() {
        processHTMLData({ parentId: this.recordId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'File processed and saved!',
                    variant: 'success'
                }));
                return refreshApex(this.wiredLogsResult);
            })
            .catch(error => {
                console.error(error);
            });
    }
}