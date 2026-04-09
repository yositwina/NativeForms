import { LightningElement } from 'lwc';
import getFeatureSettings from '@salesforce/apex/NativeFormsAdminController.getFeatureSettings';
import saveFeatureSettings from '@salesforce/apex/NativeFormsAdminController.saveFeatureSettings';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class NativeFormsAdminFeatures extends LightningElement {
    isLoading = true;
    errorMessage = '';
    enableProConditionLogic = false;

    connectedCallback() {
        this.loadSettings();
    }

    async loadSettings() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const settings = await getFeatureSettings();
            this.enableProConditionLogic = !!settings?.enableProConditionLogic;
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleToggle(event) {
        this.enableProConditionLogic = event.target.checked;
    }

    async handleSave() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const settings = await saveFeatureSettings({
                inputValue: {
                    enableProConditionLogic: this.enableProConditionLogic
                }
            });
            this.enableProConditionLogic = !!settings?.enableProConditionLogic;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Settings saved',
                message: 'NativeForms feature flags were updated.',
                variant: 'success'
            }));
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    normalizeError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'Something went wrong while loading feature settings.';
    }
}
