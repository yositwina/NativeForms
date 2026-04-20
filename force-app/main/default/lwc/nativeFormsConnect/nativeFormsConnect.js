import { LightningElement } from 'lwc';
import getSetupContext from '@salesforce/apex/NativeFormsSetupController.getSetupContext';
import getConnectionStatus from '@salesforce/apex/NativeFormsSetupController.getConnectionStatus';
import registerOrg from '@salesforce/apex/NativeFormsSetupController.registerOrg';
import saveClientCredentials from '@salesforce/apex/NativeFormsSetupController.saveClientCredentials';
import step1Image from '@salesforce/resourceUrl/nativeFormsConnectStep1';
import step2Image from '@salesforce/resourceUrl/nativeFormsConnectStep2';
import step3Image from '@salesforce/resourceUrl/nativeFormsConnectStep3';

const CONNECT_STATE_KEY = 'nativeforms:connectState';
const TENANT_SECRET_VISIBLE_MS = 5 * 60 * 1000;
const CONNECTION_POLL_MS = 5000;
const STEP1_PLACEHOLDER_CLIENT_ID = 'nativeforms-step1-placeholder-client-id';
const STEP1_PLACEHOLDER_CLIENT_SECRET = 'nativeforms-step1-placeholder-client-secret';

export default class NativeFormsConnect extends LightningElement {
    connectVersion = 'v2.2';
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
    country = '';
    state = '';
    city = '';

    tenantSecret = '';
    connectUrl = '';
    setupState = 'not_registered';
    errorMessage = '';
    successMessage = '';
    isBusy = false;
    isInitializing = true;
    showPrincipalAccessHelp = false;
    tenantAuthVerified = false;
    tenantAuthStatus = 'not_checked';
    tenantAuthErrorMessage = '';
    tenantSecretIssuedAt = null;
    tenantSecretTimeoutId;
    connectionPollId;
    isAwaitingOauthReturn = false;
    hasClientCredentials = false;
    tenantTestMessage = '';
    tenantTestMessageVariant = '';
    expandedImageSections = {
        step1: false,
        step2: false,
        step3: false
    };

    connectedCallback() {
        const today = new Date();
        const thirtyDaysLater = new Date(today);
        thirtyDaysLater.setDate(thirtyDaysLater.getDate() + 30);

        this.subscriptionStartDate = this.toIsoDate(today);
        this.subscriptionEndDate = this.toIsoDate(thirtyDaysLater);
        this.loadSetupContext();
    }

    disconnectedCallback() {
        this.clearTenantSecretTimer();
        this.stopConnectionPolling();
    }

    async loadSetupContext() {
        try {
            const context = await getSetupContext();
            this.orgId = context.orgId || '';
            this.companyName = context.orgName || 'TwinaForms Tenant';
            this.adminEmail = context.adminEmail || '';
            this.loginBaseUrl = context.loginBaseUrl || '';
            this.country = context.country || '';
            this.state = context.state || '';
            this.city = context.city || '';
            this.restoreConnectState(this.orgId);
            await this.loadConnectionStatus();
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
        if (error.name && error.name !== 'Error') {
            parts.push(`name=${error.name}`);
        }

        return parts.join('\n\n') || JSON.stringify(error);
    }

    normalizeRegistrationError(error) {
        const rawMessage = this.formatError(error);
        const normalized = rawMessage.toLowerCase();
        const isPrincipalAccessIssue =
            normalized.includes('we couldn\'t access the credential') ||
            normalized.includes('external credential') ||
            normalized.includes('nativeforms_bootstrap') ||
            normalized.includes('nativeformsbootstrap') ||
            normalized.includes('nativeformslambd') ||
            normalized.includes('principal access') ||
            normalized.includes('setup access is not complete') ||
            normalized.includes('permission-set access') ||
            normalized.includes('permission set access');

        this.showPrincipalAccessHelp = isPrincipalAccessIssue;

        if (isPrincipalAccessIssue) {
            return 'TwinaForms could not connect yet because the required permission-set access is not fully enabled.';
        }

        return rawMessage;
    }

    get step1ImageUrl() {
        return step1Image;
    }

    get step2ImageUrl() {
        return step2Image;
    }

    get step3ImageUrl() {
        return step3Image;
    }

    get hasTenantSecret() {
        return !!this.tenantSecret && !this.isTenantSecretExpired;
    }

    get isTenantSecretExpired() {
        if (!this.tenantSecret || !this.tenantSecretIssuedAt) {
            return false;
        }

        return Date.now() - this.tenantSecretIssuedAt >= TENANT_SECRET_VISIBLE_MS;
    }

    get isPendingConnection() {
        return this.setupState === 'registered_pending_connection';
    }

    get isConnected() {
        return this.setupState === 'connected';
    }

    get tenantSetupComplete() {
        return this.tenantAuthVerified;
    }

    get showTenantSetupStage() {
        return !this.tenantSetupComplete;
    }

    get showTenantSetupCompleteBanner() {
        return this.tenantSetupComplete;
    }

    get showTenantSetupInstructions() {
        return this.showTenantSetupStage;
    }

    get showTenantSetupActions() {
        return !this.isAwaitingOauthReturn && !this.tenantSetupComplete;
    }

    get showGenerateSecretAction() {
        return this.showTenantSetupActions;
    }

    get showTestTenantAction() {
        return this.isPendingConnection || this.hasTenantSecret;
    }

    get showTenantSecretExpiredMessage() {
        return !this.hasTenantSecret && !!this.tenantSecretIssuedAt && !this.tenantSetupComplete;
    }

    get showOauthStage() {
        return this.tenantSetupComplete && !this.isConnected;
    }

    get showOauthCompleteBanner() {
        return this.isConnected;
    }

    get showOauthCredentialsForm() {
        return this.showOauthStage && !this.isAwaitingOauthReturn;
    }

    get showConnectAction() {
        return this.showOauthStage && !this.isAwaitingOauthReturn;
    }

    get showRefreshAction() {
        return this.showOauthStage && this.isAwaitingOauthReturn;
    }

    get actionDisabled() {
        return this.isBusy || this.isInitializing;
    }

    get connectionStatusLabel() {
        if (this.isInitializing) {
            return 'Checking connection status...';
        }

        if (this.isConnected) {
            return 'Connected';
        }

        if (this.isPendingConnection) {
            return this.tenantSetupComplete ? 'Waiting for Salesforce OAuth connection' : 'Waiting for tenant secret setup';
        }

        return 'Not registered';
    }

    get salesforceConnectionLabel() {
        if (this.isInitializing) {
            return 'Checking...';
        }

        if (this.isConnected) {
            return 'Connected';
        }

        if (this.isAwaitingOauthReturn) {
            return 'Waiting for OAuth callback';
        }

        if (this.isPendingConnection) {
            return 'Not connected yet';
        }

        return 'Not registered';
    }

    get tenantSecretAuthLabel() {
        if (this.isInitializing) {
            return 'Checking...';
        }

        if (this.tenantAuthVerified) {
            return 'Verified';
        }

        if (this.tenantAuthStatus === 'not_verified') {
            return 'Not verified';
        }

        return 'Not checked';
    }

    get showConnectionStatusSection() {
        return false;
    }

    get showTenantTestMessage() {
        return !!this.tenantTestMessage;
    }

    get tenantTestMessageClass() {
        return this.tenantTestMessageVariant === 'error'
            ? 'tenant-test-message tenant-test-message--error'
            : 'tenant-test-message tenant-test-message--success';
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        if (!field) {
            return;
        }
        this[field] = event.target.value;
    }

    handleToggleImage(event) {
        const section = event.target.dataset.section;
        if (!section) {
            return;
        }

        this.expandedImageSections = {
            ...this.expandedImageSections,
            [section]: !this.expandedImageSections[section]
        };
    }

    get showStep1Image() {
        return this.expandedImageSections.step1;
    }

    get showStep2Image() {
        return this.expandedImageSections.step2;
    }

    get showStep3Image() {
        return this.expandedImageSections.step3;
    }

    get step1ImageButtonLabel() {
        return this.showStep1Image ? 'Hide example image' : 'Show example image';
    }

    get step2ImageButtonLabel() {
        return this.showStep2Image ? 'Hide example image' : 'Show example image';
    }

    get step3ImageButtonLabel() {
        return this.showStep3Image ? 'Hide example image' : 'Show example image';
    }

    buildRegistrationPayload() {
        return {
            orgId: this.orgId,
            adminEmail: this.adminEmail,
            companyName: this.companyName,
            loginBaseUrl: this.loginBaseUrl,
            salesforceClientId: this.salesforceClientId || STEP1_PLACEHOLDER_CLIENT_ID,
            salesforceClientSecret: this.salesforceClientSecret || STEP1_PLACEHOLDER_CLIENT_SECRET,
            subscriptionState: this.subscriptionState,
            subscriptionStartDate: this.subscriptionStartDate || null,
            subscriptionEndDate: this.subscriptionEndDate || null,
            isActive: this.isActive,
            status: 'active',
            country: this.country || null,
            state: this.state || null,
            city: this.city || null
        };
    }

    buildClientCredentialsPayload() {
        return {
            orgId: this.orgId,
            adminEmail: this.adminEmail,
            companyName: this.companyName,
            loginBaseUrl: this.loginBaseUrl,
            salesforceClientId: this.salesforceClientId,
            salesforceClientSecret: this.salesforceClientSecret
        };
    }

    async handleGenerateSecret() {
        this.errorMessage = '';
        this.successMessage = '';
        this.tenantTestMessage = '';
        this.tenantTestMessageVariant = '';
        this.showPrincipalAccessHelp = false;
        this.isBusy = true;

        try {
            const data = await registerOrg({ requestBody: this.buildRegistrationPayload() });

            if (!data?.success) {
                throw new Error(data?.errorMessage || 'TwinaForms registration failed.');
            }

            this.tenantSecret = data.tenantSecret || '';
            this.tenantSecretIssuedAt = this.tenantSecret ? Date.now() : null;
            this.connectUrl = data.connectUrl || '';
            this.setupState = 'registered_pending_connection';
            this.successMessage = 'Tenant secret generated. Add it to Named Credentials, then click Test Tenant Secret.';
            this.scheduleTenantSecretExpiry();
            this.persistConnectState();
        } catch (error) {
            this.errorMessage = this.normalizeRegistrationError(error);
        } finally {
            this.isBusy = false;
        }
    }

    async handleTestTenantSetup() {
        this.isBusy = true;
        this.errorMessage = '';
        this.successMessage = '';
        this.tenantTestMessage = '';
        this.tenantTestMessageVariant = '';

        try {
            await this.loadConnectionStatus();

            if (this.tenantSetupComplete) {
                this.tenantTestMessage = 'Tenant secret verified. You can continue to Step 2.';
                this.tenantTestMessageVariant = 'success';
            } else {
                this.tenantTestMessage = this.getFriendlyTenantTestError();
                this.tenantTestMessageVariant = 'error';
            }
        } finally {
            this.isBusy = false;
        }
    }

    async handleConnect() {
        this.errorMessage = '';
        this.successMessage = '';
        this.showPrincipalAccessHelp = false;
        this.isBusy = true;
        const oauthWindow = window.open('', '_blank');

        try {
            const data = await saveClientCredentials({ requestBody: this.buildClientCredentialsPayload() });

            if (!data?.success) {
                throw new Error(data?.errorMessage || 'TwinaForms could not save the Salesforce client credentials.');
            }

            this.connectUrl = data.connectUrl || '';
            this.hasClientCredentials = true;

            if (!this.connectUrl) {
                throw new Error('TwinaForms could not generate a Salesforce connection URL.');
            }

            this.isAwaitingOauthReturn = true;
            this.successMessage = 'Salesforce client credentials saved. Finish authentication in the Salesforce window, then return here.';
            this.persistConnectState();
            this.startConnectionPolling();
            if (oauthWindow) {
                oauthWindow.location = this.connectUrl;
            } else {
                window.open(this.connectUrl, '_blank');
            }
        } catch (error) {
            if (oauthWindow && !oauthWindow.closed) {
                oauthWindow.close();
            }
            this.errorMessage = this.normalizeRegistrationError(error);
        } finally {
            this.isBusy = false;
        }
    }

    async handleRefreshStatus() {
        this.isBusy = true;
        this.errorMessage = '';

        try {
            await this.loadConnectionStatus();
        } finally {
            this.isBusy = false;
        }
    }

    async loadConnectionStatus() {
        try {
            const status = await getConnectionStatus({ orgId: this.orgId });
            if (status?.success !== true) {
                this.errorMessage = this.normalizeRegistrationError(
                    new Error(status?.errorMessage || 'Unable to verify TwinaForms connection status.')
                );
                return;
            }

            this.errorMessage = '';
            this.setupState = status.setupState || 'not_registered';
            this.connectUrl = status.connectUrl || '';
            this.hasClientCredentials = status.hasClientCredentials === true;
            this.tenantAuthVerified = status.tenantAuthVerified === true;
            this.tenantAuthStatus = status.tenantAuthStatus || 'not_checked';
            this.tenantAuthErrorMessage = status.tenantAuthErrorMessage || '';

            if (this.tenantAuthVerified) {
                this.clearTenantSecretDisplayState();
            }

            if (this.isConnected) {
                this.isAwaitingOauthReturn = false;
                this.stopConnectionPolling();
                this.successMessage = 'TwinaForms is fully connected.';
            } else if (this.isAwaitingOauthReturn && !this.isPendingConnection) {
                this.isAwaitingOauthReturn = false;
                this.stopConnectionPolling();
            } else if (this.tenantSetupComplete && !this.hasClientCredentials) {
                this.isAwaitingOauthReturn = false;
            }

            this.persistConnectState();
        } catch (error) {
            this.errorMessage = this.normalizeRegistrationError(
                new Error(`Unable to verify TwinaForms connection status.\n\n${this.formatError(error)}`)
            );
        }
    }

    getFriendlyTenantTestError() {
        const raw = (this.tenantAuthErrorMessage || '').toLowerCase();

        if (raw.includes('invalid tenant secret') || raw.includes('401 unauthorized')) {
            return 'The tenant secret is incorrect. Please update the secret in Named Credentials and test again.';
        }

        if (raw.includes('unauthorized') || raw.includes('not verified')) {
            return 'TwinaForms could not verify the tenant secret yet. Please check the secret value and try again.';
        }

        return 'Tenant secret is not verified yet. Please finish the Named Credential step and try Test again.';
    }

    startConnectionPolling() {
        this.stopConnectionPolling();
        this.connectionPollId = window.setInterval(() => {
            this.loadConnectionStatus();
        }, CONNECTION_POLL_MS);
    }

    stopConnectionPolling() {
        if (this.connectionPollId) {
            window.clearInterval(this.connectionPollId);
            this.connectionPollId = null;
        }
    }

    clearTenantSecretTimer() {
        if (this.tenantSecretTimeoutId) {
            window.clearTimeout(this.tenantSecretTimeoutId);
            this.tenantSecretTimeoutId = null;
        }
    }

    clearTenantSecretFromUi() {
        this.clearTenantSecretTimer();
        this.tenantSecret = '';
        this.persistConnectState();
    }

    clearTenantSecretDisplayState() {
        this.clearTenantSecretTimer();
        this.tenantSecret = '';
        this.tenantSecretIssuedAt = null;
    }

    scheduleTenantSecretExpiry() {
        this.clearTenantSecretTimer();

        if (!this.tenantSecret || !this.tenantSecretIssuedAt) {
            return;
        }

        const remainingMs = TENANT_SECRET_VISIBLE_MS - (Date.now() - this.tenantSecretIssuedAt);
        if (remainingMs <= 0) {
            this.clearTenantSecretFromUi();
            return;
        }

        this.tenantSecretTimeoutId = window.setTimeout(() => {
            this.clearTenantSecretFromUi();
        }, remainingMs);
    }

    persistConnectState() {
        try {
            window.sessionStorage.setItem(CONNECT_STATE_KEY, JSON.stringify({
                orgId: this.orgId,
                tenantSecret: this.tenantSecret,
                tenantSecretIssuedAt: this.tenantSecretIssuedAt,
                connectUrl: this.connectUrl,
                successMessage: this.successMessage,
                setupState: this.setupState,
                isAwaitingOauthReturn: this.isAwaitingOauthReturn,
                tenantAuthVerified: this.tenantAuthVerified,
                tenantAuthStatus: this.tenantAuthStatus,
                tenantAuthErrorMessage: this.tenantAuthErrorMessage,
                hasClientCredentials: this.hasClientCredentials
            }));
        } catch (error) {
            // Ignore browser storage failures.
        }
    }

    restoreConnectState(orgId) {
        try {
            const rawValue = window.sessionStorage.getItem(CONNECT_STATE_KEY);
            if (!rawValue) {
                return;
            }

            const stored = JSON.parse(rawValue);
            if (stored?.orgId && orgId && stored.orgId !== orgId) {
                return;
            }

            this.tenantSecret = stored?.tenantSecret || '';
            this.tenantSecretIssuedAt = typeof stored?.tenantSecretIssuedAt === 'number'
                ? stored.tenantSecretIssuedAt
                : null;
            this.connectUrl = stored?.connectUrl || '';
            this.successMessage = stored?.successMessage || '';
            this.setupState = stored?.setupState || 'not_registered';
            this.isAwaitingOauthReturn = stored?.isAwaitingOauthReturn === true;
            this.tenantAuthVerified = stored?.tenantAuthVerified === true;
            this.tenantAuthStatus = stored?.tenantAuthStatus || 'not_checked';
            this.tenantAuthErrorMessage = stored?.tenantAuthErrorMessage || '';
            this.hasClientCredentials = stored?.hasClientCredentials === true;
            this.scheduleTenantSecretExpiry();
            if (this.isAwaitingOauthReturn) {
                this.startConnectionPolling();
            }
        } catch (error) {
            // Ignore browser storage failures.
        }
    }
}
