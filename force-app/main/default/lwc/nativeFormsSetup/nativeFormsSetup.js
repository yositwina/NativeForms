import { LightningElement } from 'lwc';
import getSetupContext from '@salesforce/apex/NativeFormsSetupController.getSetupContext';
import registerOrg from '@salesforce/apex/NativeFormsSetupController.registerOrg';

export default class NativeFormsSetup extends LightningElement {
    orgId = '';
    adminEmail = '';
    companyName = '';
    loginBaseUrl = '';
    salesforceClientId = '';
    salesforceClientSecret = '';
    subscriptionState = 'trial';
    subscriptionStartDate = '';
    subscriptionEndDate = '';
    isActive = true;

    tenantSecret = '';
    connectUrl = '';
    rawResponse = '';
    errorMessage = '';
    successMessage = '';
    isBusy = false;
    isInitializing = true;

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
        if (error.message) {
            parts.push(error.message);
        }
        if (error.name && error.name !== 'Error') {
            parts.push(`name=${error.name}`);
        }
        if (error.stack) {
            parts.push(error.stack);
        }

        return parts.join('\n\n') || JSON.stringify(error);
    }

    get connectDisabled() {
        return this.isBusy || !this.connectUrl;
    }

    get actionLabel() {
        return this.connectUrl ? 'Reconnect TwinaForms' : 'Connect TwinaForms';
    }

    get actionDisabled() {
        return this.isBusy || this.isInitializing;
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }
        this[field] = event.target.value;
    }

    handleActiveToggle(event) {
        this.isActive = event.target.checked;
    }

    buildRegistrationPayload() {
        return {
            orgId: this.orgId,
            adminEmail: this.adminEmail,
            companyName: this.companyName,
            loginBaseUrl: this.loginBaseUrl,
            salesforceClientId: this.salesforceClientId,
            salesforceClientSecret: this.salesforceClientSecret,
            subscriptionState: this.subscriptionState,
            subscriptionStartDate: this.subscriptionStartDate || null,
            subscriptionEndDate: this.subscriptionEndDate || null,
            isActive: this.isActive,
            status: this.isActive ? 'active' : 'disabled'
        };
    }

    async registerOrg() {
        this.errorMessage = '';
        this.successMessage = '';
        this.isBusy = true;

        try {
            const payload = this.buildRegistrationPayload();
            const data = await registerOrg({ requestBody: payload });
            this.rawResponse = data?.rawResponse || '';

            if (!data?.success) {
                throw new Error(data?.errorMessage || 'TwinaForms registration failed.');
            }

            this.tenantSecret = data.tenantSecret || '';
            this.connectUrl = data.connectUrl || '';
            this.successMessage = 'Org registration succeeded.';
        } catch (error) {
            this.errorMessage = this.formatError(error);
        } finally {
            this.isBusy = false;
        }
    }

    async handleConnect() {
        this.errorMessage = '';
        this.successMessage = '';

        if (!this.connectUrl) {
            await this.registerOrg();
        }

        if (!this.connectUrl) {
            this.errorMessage = this.errorMessage || 'TwinaForms could not generate a Salesforce connection URL.';
            return;
        }
        window.open(this.connectUrl, '_blank');
    }
}
