import { LightningElement } from 'lwc';
import getFeatureSettings from '@salesforce/apex/NativeFormsAdminController.getFeatureSettings';
import saveFeatureSettings from '@salesforce/apex/NativeFormsAdminController.saveFeatureSettings';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class NativeFormsAdminFeatures extends LightningElement {
    isLoading = true;
    errorMessage = '';
    enableProConditionLogic = false;
    enableProRepeatGroups = false;
    enableProPrefillAliasReferences = false;
    enableProAdvancedSubmitModes = false;

    connectedCallback() {
        this.loadSettings();
    }

    async loadSettings() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const settings = await getFeatureSettings();
            this.enableProConditionLogic = !!settings?.enableProConditionLogic;
            this.enableProRepeatGroups = !!settings?.enableProRepeatGroups;
            this.enableProPrefillAliasReferences = !!settings?.enableProPrefillAliasReferences;
            this.enableProAdvancedSubmitModes = !!settings?.enableProAdvancedSubmitModes;
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleToggle(event) {
        const fieldName = event.target.name;
        if (fieldName === 'enableProRepeatGroups') {
            this.enableProRepeatGroups = event.target.checked;
            return;
        }
        if (fieldName === 'enableProPrefillAliasReferences') {
            this.enableProPrefillAliasReferences = event.target.checked;
            return;
        }
        if (fieldName === 'enableProAdvancedSubmitModes') {
            this.enableProAdvancedSubmitModes = event.target.checked;
            return;
        }
        this.enableProConditionLogic = event.target.checked;
    }

    async handleSave() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const settings = await saveFeatureSettings({
                inputValue: {
                    enableProConditionLogic: this.enableProConditionLogic,
                    enableProRepeatGroups: this.enableProRepeatGroups,
                    enableProPrefillAliasReferences: this.enableProPrefillAliasReferences,
                    enableProAdvancedSubmitModes: this.enableProAdvancedSubmitModes
                }
            });
            this.enableProConditionLogic = !!settings?.enableProConditionLogic;
            this.enableProRepeatGroups = !!settings?.enableProRepeatGroups;
            this.enableProPrefillAliasReferences = !!settings?.enableProPrefillAliasReferences;
            this.enableProAdvancedSubmitModes = !!settings?.enableProAdvancedSubmitModes;
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
