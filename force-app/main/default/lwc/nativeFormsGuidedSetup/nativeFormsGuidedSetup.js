import { LightningElement } from 'lwc';
import getSetupContext from '@salesforce/apex/NativeFormsSetupController.getSetupContext';
import registerOrg from '@salesforce/apex/NativeFormsSetupController.registerOrg';

export default class NativeFormsGuidedSetup extends LightningElement {
    orgId = '';
    adminEmail = '';
    companyName = '';
    loginBaseUrl = '';

    tenantSecret = '';
    connectUrl = '';
    errorMessage = '';
    successMessage = '';
    isBusy = false;
    isInitializing = true;
    subscriptionStartDate = '';
    subscriptionEndDate = '';

    connectedCallback() {
        const today = new Date();
        const nextYear = new Date(today);
        nextYear.setFullYear(nextYear.getFullYear() + 1);

        this.subscriptionStartDate = this.toIsoDate(today);
        this.subscriptionEndDate = this.toIsoDate(nextYear);
        this.loadSetupContext();
    }

    async loadSetupContext() {
        try {
            const context = await getSetupContext();
            this.orgId = context.orgId || '';
            this.companyName = context.orgName || 'TwinaForms Tenant';
            this.adminEmail = context.adminEmail || '';
            this.loginBaseUrl = context.loginBaseUrl || '';
        } catch (error) {
            this.errorMessage = `Unable to load org setup details.\n\n${this.formatError(error)}`;
        } finally {
            this.isInitializing = false;
        }
    }

    toIsoDate(dateValue) {
        return dateValue.toISOString().slice(0, 10);
    }

    formatError(error) {
        if (!error) {
            return 'Unknown error';
        }

        const parts = [];
        if (error.body?.message) {
            parts.push(error.body.message);
        }
        if (error.message) {
            parts.push(error.message);
        }

        return parts.join('\n\n') || JSON.stringify(error);
    }

    get actionDisabled() {
        return this.isBusy || this.isInitializing;
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        if (field) {
            this[field] = event.target.value;
        }
    }

    buildRegistrationPayload() {
        return {
            orgId: this.orgId,
            adminEmail: this.adminEmail,
            companyName: this.companyName,
            loginBaseUrl: this.loginBaseUrl,
            subscriptionState: 'active',
            subscriptionStartDate: this.subscriptionStartDate,
            subscriptionEndDate: this.subscriptionEndDate,
            isActive: true,
            status: 'active'
        };
    }

    async handleConnect() {
        this.errorMessage = '';
        this.successMessage = '';
        this.isBusy = true;

        try {
            const result = await registerOrg({
                requestJson: JSON.stringify(this.buildRegistrationPayload())
            });

            if (!result?.success) {
                throw new Error(result?.errorMessage || 'TwinaForms registration failed.');
            }

            this.tenantSecret = result.tenantSecret || '';
            this.connectUrl = result.connectUrl || '';
            this.successMessage = 'TwinaForms generated your tenant code and opened Salesforce authorization in a new tab.';

            if (!this.connectUrl) {
                throw new Error('TwinaForms could not generate a Salesforce connection URL.');
            }

            window.open(this.connectUrl, '_blank');
        } catch (error) {
            this.errorMessage = this.formatError(error);
        } finally {
            this.isBusy = false;
        }
    }
}
