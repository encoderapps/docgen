import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateFromJunction from '@salesforce/apex/TemplateGeneratorService.generateFromJunction';

export default class TemplateOutputGenerator extends LightningElement {
    @api recordId;
    isLoading = false;

    handleClick() {
        this.isLoading = true;

        generateFromJunction({ junctionId: this.recordId })
            .then(result => {
                if (result.success) {
                    this.dispatchEvent(new ShowToastEvent({
                        title   : 'Success',
                        message : 'Output HTML generated successfully!',
                        variant : 'success'
                    }));
                } else {
                    this.dispatchEvent(new ShowToastEvent({
                        title   : 'Error',
                        message : result.errorMessage,
                        variant : 'error'
                    }));
                }
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({
                    title   : 'Error',
                    message : error.body.message,
                    variant : 'error'
                }));
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
}