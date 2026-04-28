import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getSetupContext from '@salesforce/apex/NativeFormsSetupController.getSetupContext';
import getConnectionStatus from '@salesforce/apex/NativeFormsSetupController.getConnectionStatus';
import registerOrg from '@salesforce/apex/NativeFormsSetupController.registerOrg';
import getAccessManagementView from '@salesforce/apex/NativeFormsHomeController.getAccessManagementView';
import updatePermissionSetAccess from '@salesforce/apex/NativeFormsHomeController.updatePermissionSetAccess';
import installDemoData from '@salesforce/apex/NativeFormsDemoDataController.installDemoData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const CONNECT_STATE_KEY = 'nativeforms:connectState';
const TENANT_SECRET_VISIBLE_MS = 5 * 60 * 1000;
const CONNECTION_POLL_MS = 5000;

export default class NativeFormsConnect extends NavigationMixin(LightningElement) {
    orgId = '';
    adminEmail = '';
    companyName = '';
    loginBaseUrl = '';
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
    hasBlockingSetupAccessIssue = false;
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
    accessView;
    isUpdatingAccess = false;
    isInstallingDemo = false;
    homeTabApiName = 'NativeForms_Home';
    selectedUserGrantId = '';
    selectedAdminGrantId = '';

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
            await this.loadConnectionStatus(false);
            await this.loadAccessSummary();
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

        this.hasBlockingSetupAccessIssue = isPrincipalAccessIssue;

        if (isPrincipalAccessIssue) {
            return 'TwinaForms could not connect yet because the required permission-set access is not fully enabled.';
        }

        return rawMessage;
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
        return this.tenantAuthVerified && !this.hasBlockingSetupAccessIssue;
    }

    get showTenantSetupStage() {
        return this.hasBlockingSetupAccessIssue || !this.tenantAuthVerified;
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
        return this.tenantSetupComplete && !this.isConnected && !this.hasBlockingSetupAccessIssue;
    }

    get showOauthCompleteBanner() {
        return this.tenantSetupComplete && this.isConnected;
    }

    get showDemoInstallStage() {
        return this.tenantSetupComplete && this.isConnected;
    }

    get showConnectAction() {
        return this.showOauthStage && !this.isAwaitingOauthReturn;
    }

    get showRefreshAction() {
        return this.showOauthStage && this.isAwaitingOauthReturn;
    }

    get actionDisabled() {
        return this.isBusy || this.isInitializing || this.isInstallingDemo;
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

    get access() {
        return this.accessView?.access || {};
    }

    get usage() {
        return this.accessView?.usage || {};
    }

    get accessUsers() {
        return this.access.users || [];
    }

    get adminAppOpen() {
        return this.access.adminAppOpen === true;
    }

    get adminAppStatusLabel() {
        return this.adminAppOpen ? 'Open for support/debug' : 'Closed by default';
    }

    get adminAppStatusClass() {
        return this.adminAppOpen ? 'status-pill status-pill--success' : 'status-pill status-pill--warning';
    }

    get showAccessSection() {
        return this.tenantSetupComplete && this.isConnected && this.accessUsers.length > 0;
    }

    get userAssignments() {
        return this.accessUsers.filter((item) => item.hasTwinaFormsUser);
    }

    get adminAssignments() {
        return this.accessUsers.filter((item) => item.hasTwinaFormsAdmin);
    }

    get hasUserAssignments() {
        return this.userAssignments.length > 0;
    }

    get hasAdminAssignments() {
        return this.adminAssignments.length > 0;
    }

    get availableUserGrantOptions() {
        return this.accessUsers
            .filter((item) => !item.hasTwinaFormsUser)
            .map((item) => ({
                label: item.displayLabel,
                value: item.userId
            }));
    }

    get availableAdminGrantOptions() {
        return this.accessUsers
            .filter((item) => !item.hasTwinaFormsAdmin)
            .map((item) => ({
                label: item.displayLabel,
                value: item.userId
            }));
    }

    get userGrantDisabled() {
        return this.isInitializing || this.isUpdatingAccess || !this.selectedUserGrantId;
    }

    get adminGrantDisabled() {
        return this.isInitializing || this.isUpdatingAccess || !this.selectedAdminGrantId || !this.adminAppOpen;
    }

    get adminGrantComboboxDisabled() {
        return this.isUpdatingAccess || !this.adminAppOpen;
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

    handleUserGrantSelection(event) {
        this.selectedUserGrantId = event.detail.value;
    }

    handleAdminGrantSelection(event) {
        this.selectedAdminGrantId = event.detail.value;
    }

    async handleGrantUserAccess() {
        await this.changeAccess(this.selectedUserGrantId, 'user', true, 'TwinaForms User granted.');
        this.selectedUserGrantId = '';
    }

    async handleGrantAdminAccess() {
        await this.changeAccess(this.selectedAdminGrantId, 'admin', true, 'TwinaForms Admin granted.');
        this.selectedAdminGrantId = '';
    }

    async handleToggleAccess(event) {
        const userId = event.currentTarget.dataset.userId;
        const accessType = event.currentTarget.dataset.accessType;
        const enabled = event.currentTarget.dataset.enabled === 'true';
        const successToastMessage = enabled
            ? `${accessType === 'admin' ? 'TwinaForms Admin' : 'TwinaForms User'} granted.`
            : `${accessType === 'admin' ? 'TwinaForms Admin' : 'TwinaForms User'} removed.`;
        await this.changeAccess(userId, accessType, enabled, successToastMessage);
    }

    buildRegistrationPayload() {
        return {
            orgId: this.orgId,
            adminEmail: this.adminEmail,
            companyName: this.companyName,
            loginBaseUrl: this.loginBaseUrl,
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

    async handleGenerateSecret() {
        this.errorMessage = '';
        this.successMessage = '';
        this.tenantTestMessage = '';
        this.tenantTestMessageVariant = '';
        this.hasBlockingSetupAccessIssue = false;
        this.isBusy = true;

        try {
            const data = await registerOrg({
                requestJson: JSON.stringify(this.buildRegistrationPayload())
            });

            if (!data?.success) {
                throw new Error(data?.errorMessage || 'TwinaForms registration failed.');
            }

            this.tenantSecret = data.tenantSecret || '';
            this.tenantSecretIssuedAt = this.tenantSecret ? Date.now() : null;
            this.connectUrl = data.connectUrl || '';
            this.setupState = 'registered_pending_connection';
            this.successMessage = 'Tenant secret generated. Add it to Named Credentials, then click Test Tenant Secret.';
            this.dispatchEvent(new ShowToastEvent({
                title: 'Tenant secret generated',
                message: 'Add it to Named Credentials, then click Test Tenant Secret.',
                variant: 'success'
            }));
            this.scheduleTenantSecretExpiry();
            this.persistConnectState();
        } catch (error) {
            this.errorMessage = this.normalizeRegistrationError(error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Could not generate tenant secret',
                message: this.errorMessage,
                variant: 'error',
                mode: 'sticky'
            }));
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
            await this.loadConnectionStatus(true);

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
        this.hasBlockingSetupAccessIssue = false;
        this.isBusy = true;
        const oauthWindow = window.open('', '_blank');

        try {
            if (!this.connectUrl) {
                throw new Error('TwinaForms could not generate a Salesforce connection URL.');
            }

            this.isAwaitingOauthReturn = true;
            this.successMessage = 'Finish authentication in the Salesforce window, then return here.';
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
            await this.loadConnectionStatus(false);
            await this.loadAccessSummary();
        } finally {
            this.isBusy = false;
        }
    }

    async loadAccessSummary() {
        const result = await getAccessManagementView();
        this.accessView = result || {};
        this.homeTabApiName = result?.homeTabApiName || this.homeTabApiName;
    }

    async handleInstallDemoRecords() {
        this.isInstallingDemo = true;
        this.errorMessage = '';
        this.successMessage = '';

        try {
            const result = await installDemoData();
            this.dispatchEvent(new ShowToastEvent({
                title: 'Demo records installed',
                message: result?.message || 'Demo records are ready.',
                variant: 'success'
            }));
            this.navigateToHome();
        } catch (error) {
            this.errorMessage = this.formatError(error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Could not install demo records',
                message: this.errorMessage,
                variant: 'error',
                mode: 'sticky'
            }));
        } finally {
            this.isInstallingDemo = false;
        }
    }

    handleSkipDemoRecords() {
        this.navigateToHome();
    }

    navigateToHome() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: this.homeTabApiName || 'NativeForms_Home'
            }
        });
    }

    async changeAccess(userId, accessType, enabled, successToastMessage) {
        if (!userId || this.isUpdatingAccess) {
            return;
        }

        this.isUpdatingAccess = true;
        this.errorMessage = '';
        this.successMessage = '';
        try {
            const result = await updatePermissionSetAccess({ userId, accessType, enabled });
            this.accessView = result || {};
            this.homeTabApiName = result?.homeTabApiName || this.homeTabApiName;
            this.dispatchEvent(new ShowToastEvent({
                title: 'User access updated',
                message: successToastMessage,
                variant: 'success'
            }));
        } catch (error) {
            this.errorMessage = this.formatError(error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Could not update user access',
                message: this.errorMessage,
                variant: 'error',
                mode: 'sticky'
            }));
        } finally {
            this.isUpdatingAccess = false;
        }
    }

    async loadConnectionStatus(verifyTenantAuth = false) {
        try {
            const status = await getConnectionStatus({
                orgId: this.orgId,
                verifyTenantAuthNow: verifyTenantAuth
            });
            if (status?.success !== true) {
                this.tenantAuthVerified = false;
                this.tenantAuthStatus = 'not_verified';
                this.tenantAuthErrorMessage = '';
                this.isAwaitingOauthReturn = false;
                this.successMessage = '';
                this.errorMessage = this.normalizeRegistrationError(
                    new Error(status?.errorMessage || 'Unable to verify TwinaForms connection status.')
                );
                return;
            }

            this.hasBlockingSetupAccessIssue = false;
            this.errorMessage = '';
            this.setupState = status.setupState || 'not_registered';
            this.connectUrl = status.connectUrl || '';
            this.hasClientCredentials = status.hasClientCredentials === true;
            const tenantAuthWasAlreadyVerified = this.tenantAuthVerified === true && status.tenantAuthStatus === 'not_checked';
            const orgIsAlreadyConnected = status.setupState === 'connected' || status.connected === true;
            this.tenantAuthVerified = tenantAuthWasAlreadyVerified || status.tenantAuthVerified === true || orgIsAlreadyConnected;
            this.tenantAuthStatus = this.tenantAuthVerified
                ? 'verified'
                : (status.tenantAuthStatus || 'not_checked');
            this.tenantAuthErrorMessage = status.tenantAuthErrorMessage || '';

            if (this.tenantAuthVerified) {
                this.clearTenantSecretDisplayState();
            }

            if (this.isConnected) {
                this.isAwaitingOauthReturn = false;
                this.stopConnectionPolling();
                this.successMessage = 'TwinaForms is fully connected.';
                try {
                    await this.loadAccessSummary();
                } catch (accessError) {
                    this.errorMessage = this.formatError(accessError);
                }
            } else if (this.isAwaitingOauthReturn && !this.isPendingConnection) {
                this.isAwaitingOauthReturn = false;
                this.stopConnectionPolling();
            } else if (this.tenantSetupComplete && !this.hasClientCredentials) {
                this.isAwaitingOauthReturn = false;
            }

            this.persistConnectState();
        } catch (error) {
            this.tenantAuthVerified = false;
            this.tenantAuthStatus = 'not_verified';
            this.tenantAuthErrorMessage = '';
            this.isAwaitingOauthReturn = false;
            this.successMessage = '';
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
