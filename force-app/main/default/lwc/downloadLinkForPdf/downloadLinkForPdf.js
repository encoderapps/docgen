import { LightningElement, wire } from 'lwc';
import { subscribe, MessageContext } from 'lightning/messageService';
import PDF_CHANNEL from '@salesforce/messageChannel/pdfMessageChannel__c';

export default class DownloadLinkForPdf extends LightningElement {

    fileUrl;
    subscription = null;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this.subscribeChannel();
    }

    subscribeChannel() {
        if (!this.subscription) {
            this.subscription = subscribe(
                this.messageContext,
                PDF_CHANNEL,
                (message) => this.handleMessage(message)
            );
        }
    }

    handleMessage(message) {
        this.fileUrl = message.fileUrl;
    }

    get isDisabled() {
        return !this.fileUrl;
    }

    handleDownload() {
        if (this.fileUrl) {
            window.open(this.fileUrl, '_blank');
        }
    }
}