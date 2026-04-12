import { LightningElement } from 'lwc';
import getFeatureSettings from '@salesforce/apex/NativeFormsAdminController.getFeatureSettings';
import saveFeatureSettings from '@salesforce/apex/NativeFormsAdminController.saveFeatureSettings';
import getConnectionStatus from '@salesforce/apex/NativeFormsSetupController.getConnectionStatus';
import disconnectOrg from '@salesforce/apex/NativeFormsSetupController.disconnectOrg';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class NativeFormsAdminFeatures extends LightningElement {
    adminFeaturesVersion = 'v0.6';
    isLoading = true;
    isDisconnecting = false;
    errorMessage = '';
    enableProConditionLogic = false;
    enableProRepeatGroups = false;
    enableProPrefillAliasReferences = false;
    enableProAdvancedSubmitModes = false;
    enableProFormulaFields = false;
    enableProPostSubmitAutoLink = false;
    enableProSfSecretCodeAuth = false;
    enableProLoadFile = false;
    captchaSiteKey = '';
    captchaSecretKey = '';
    setupState = 'not_registered';
    connectUrl = '';
    tenantAuthVerified = false;
    tenantAuthStatus = 'not_checked';
    tenantAuthErrorMessage = '';

    connectedCallback() {
        this.loadPage();
    }

    async loadPage() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            await Promise.all([
                this.loadSettings(),
                this.loadConnectionStatus()
            ]);
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async loadSettings() {
        const settings = await getFeatureSettings();
        this.enableProConditionLogic = !!settings?.enableProConditionLogic;
        this.enableProRepeatGroups = !!settings?.enableProRepeatGroups;
        this.enableProPrefillAliasReferences = !!settings?.enableProPrefillAliasReferences;
        this.enableProAdvancedSubmitModes = !!settings?.enableProAdvancedSubmitModes;
        this.enableProFormulaFields = !!settings?.enableProFormulaFields;
        this.enableProPostSubmitAutoLink = !!settings?.enableProPostSubmitAutoLink;
        this.enableProSfSecretCodeAuth = !!settings?.enableProSfSecretCodeAuth;
        this.enableProLoadFile = !!settings?.enableProLoadFile;
        this.captchaSiteKey = settings?.captchaSiteKey || '';
        this.captchaSecretKey = settings?.captchaSecretKey || '';
    }

    async loadConnectionStatus() {
        const status = await getConnectionStatus({ orgId: null });
        if (status?.success !== true) {
            throw new Error(status?.errorMessage || 'Unable to load NativeForms connection status.');
        }

        this.setupState = status.setupState || 'not_registered';
        this.connectUrl = status.connectUrl || '';
        this.tenantAuthVerified = status.tenantAuthVerified === true;
        this.tenantAuthStatus = status.tenantAuthStatus || 'not_checked';
        this.tenantAuthErrorMessage = status.tenantAuthErrorMessage || '';
    }

    get salesforceConnectionLabel() {
        if (this.setupState === 'connected') {
            return 'Connected';
        }

        if (this.setupState === 'registered_pending_connection') {
            return 'Disconnected';
        }

        return 'Not registered';
    }

    get tenantSecretAuthLabel() {
        if (this.tenantAuthVerified) {
            return 'Verified';
        }

        if (this.tenantAuthStatus === 'not_verified') {
            return 'Not verified';
        }

        return 'Not checked';
    }

    get disconnectDisabled() {
        return this.isLoading || this.isDisconnecting || this.setupState !== 'connected';
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
        if (fieldName === 'enableProFormulaFields') {
            this.enableProFormulaFields = event.target.checked;
            return;
        }
        if (fieldName === 'enableProPostSubmitAutoLink') {
            this.enableProPostSubmitAutoLink = event.target.checked;
            return;
        }
        if (fieldName === 'enableProSfSecretCodeAuth') {
            this.enableProSfSecretCodeAuth = event.target.checked;
            return;
        }
        if (fieldName === 'enableProLoadFile') {
            this.enableProLoadFile = event.target.checked;
            return;
        }
        if (fieldName === 'captchaSiteKey') {
            this.captchaSiteKey = event.target.value || '';
            return;
        }
        if (fieldName === 'captchaSecretKey') {
            this.captchaSecretKey = event.target.value || '';
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
                    enableProAdvancedSubmitModes: this.enableProAdvancedSubmitModes,
                    enableProFormulaFields: this.enableProFormulaFields,
                    enableProPostSubmitAutoLink: this.enableProPostSubmitAutoLink,
                    enableProSfSecretCodeAuth: this.enableProSfSecretCodeAuth,
                    enableProLoadFile: this.enableProLoadFile,
                    captchaSiteKey: this.captchaSiteKey,
                    captchaSecretKey: this.captchaSecretKey
                }
            });
            this.enableProConditionLogic = !!settings?.enableProConditionLogic;
            this.enableProRepeatGroups = !!settings?.enableProRepeatGroups;
            this.enableProPrefillAliasReferences = !!settings?.enableProPrefillAliasReferences;
            this.enableProAdvancedSubmitModes = !!settings?.enableProAdvancedSubmitModes;
            this.enableProFormulaFields = !!settings?.enableProFormulaFields;
            this.enableProPostSubmitAutoLink = !!settings?.enableProPostSubmitAutoLink;
            this.enableProSfSecretCodeAuth = !!settings?.enableProSfSecretCodeAuth;
            this.enableProLoadFile = !!settings?.enableProLoadFile;
            this.captchaSiteKey = settings?.captchaSiteKey || '';
            this.captchaSecretKey = settings?.captchaSecretKey || '';
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

    async handleRefreshConnection() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            await this.loadConnectionStatus();
            this.dispatchEvent(new ShowToastEvent({
                title: 'Connection refreshed',
                message: 'NativeForms connection status was refreshed.',
                variant: 'success'
            }));
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleDisconnect() {
        const confirmed = window.confirm(
            'Disconnect NativeForms for testing? This keeps the tenant registered but clears the Salesforce OAuth connection.'
        );
        if (!confirmed) {
            return;
        }

        this.isDisconnecting = true;
        this.errorMessage = '';
        try {
            const result = await disconnectOrg({ orgId: null });
            if (result?.success !== true) {
                throw new Error(result?.errorMessage || 'Unable to disconnect NativeForms.');
            }

            await this.loadConnectionStatus();
            this.dispatchEvent(new ShowToastEvent({
                title: 'Connection cleared',
                message: 'NativeForms Salesforce connection was disconnected for this org.',
                variant: 'success'
            }));
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isDisconnecting = false;
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
