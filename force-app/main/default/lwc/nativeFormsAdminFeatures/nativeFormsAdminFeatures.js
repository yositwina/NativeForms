import { LightningElement } from 'lwc';
import getFeatureSettings from '@salesforce/apex/NativeFormsAdminController.getFeatureSettings';
import getSubmissionLogStatus from '@salesforce/apex/NativeFormsSubmissionLogsController.getSubmissionLogStatus';
import saveSubmissionLogKeyPair from '@salesforce/apex/NativeFormsSubmissionLogsController.saveSubmissionLogKeyPair';
import syncSubmissionLogConfig from '@salesforce/apex/NativeFormsSubmissionLogsController.syncSubmissionLogConfig';
import getConnectionStatus from '@salesforce/apex/NativeFormsSetupController.getConnectionStatus';
import disconnectOrg from '@salesforce/apex/NativeFormsSetupController.disconnectOrg';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class NativeFormsAdminFeatures extends LightningElement {
    isLoading = true;
    isDisconnecting = false;
    isPreparingSubmissionLogs = false;
    isSyncingSubmissionLogs = false;
    errorMessage = '';
    captchaSiteKey = '';
    captchaSecretKey = '';
    submissionLogPlanCode = '';
    submissionLogRetentionDays = null;
    submissionLogsIncludedByPlan = false;
    submissionLogEffectiveMode = 'metadata_only';
    submissionLogEncryptionStatus = 'missing_public_key';
    submissionLogKeyVersion = 'v2';
    submissionLogHasPublicKey = false;
    submissionLogHasPrivateKey = false;
    submissionLogPublicKeySyncedAt = '';
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
                this.loadConnectionStatus(),
                this.loadSubmissionLogStatus()
            ]);
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async loadSettings() {
        const settings = await getFeatureSettings();
        this.captchaSiteKey = settings?.captchaSiteKey || '';
        this.captchaSecretKey = settings?.captchaSecretKey || '';
    }

    async loadConnectionStatus() {
        const status = await getConnectionStatus({
            orgId: null,
            verifyTenantAuthNow: false
        });
        if (status?.success !== true) {
            throw new Error(status?.errorMessage || 'Unable to load TwinaForms connection status.');
        }

        this.setupState = status.setupState || 'not_registered';
        this.connectUrl = status.connectUrl || '';
        this.tenantAuthVerified = status.tenantAuthVerified === true;
        this.tenantAuthStatus = status.tenantAuthStatus || 'not_checked';
        this.tenantAuthErrorMessage = status.tenantAuthErrorMessage || '';
    }

    async loadSubmissionLogStatus() {
        const status = await getSubmissionLogStatus();
        this.submissionLogPlanCode = status?.planCode || '';
        this.submissionLogRetentionDays = status?.retentionDays ?? null;
        this.submissionLogsIncludedByPlan = status?.detailedLogsIncludedByPlan === true;
        this.submissionLogEffectiveMode = status?.effectiveDetailMode || 'metadata_only';
        this.submissionLogEncryptionStatus = status?.encryptionStatus || 'missing_public_key';
        this.submissionLogKeyVersion = status?.keyVersion || 'v2';
        this.submissionLogHasPublicKey = status?.hasPublicKey === true;
        this.submissionLogHasPrivateKey = status?.hasPrivateKey === true;
        this.submissionLogPublicKeySyncedAt = status?.publicKeySyncedAt || '';
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

    get prepareSubmissionLogsDisabled() {
        return this.isLoading || this.isPreparingSubmissionLogs;
    }

    get syncSubmissionLogsDisabled() {
        return this.isLoading || this.isSyncingSubmissionLogs || !this.submissionLogsIncludedByPlan;
    }

    get submissionLogsIncludedLabel() {
        return this.submissionLogsIncludedByPlan ? 'Included by current plan' : 'Not included by current plan';
    }

    get submissionLogRetentionLabel() {
        return this.submissionLogRetentionDays ? `${this.submissionLogRetentionDays} days` : 'Not available';
    }

    get submissionLogPlanLabel() {
        return this.submissionLogPlanCode ? this.toTitleCase(this.submissionLogPlanCode) : 'Unknown';
    }

    get submissionLogEncryptionLabel() {
        switch (this.submissionLogEncryptionStatus) {
            case 'ready':
                return 'Ready';
            case 'not_included_by_plan':
                return 'Not included by plan';
            case 'missing_public_key':
            default:
                return 'Setup needed';
        }
    }

    get submissionLogSyncLabel() {
        return this.submissionLogPublicKeySyncedAt
            ? this.formatDateTime(this.submissionLogPublicKeySyncedAt)
            : 'Not synced yet';
    }

    get submissionLogStatusCopy() {
        if (!this.submissionLogsIncludedByPlan) {
            return 'This plan keeps submission logs in metadata-only mode. Upgrade the customer plan if you want field-level private log detail.';
        }

        if (this.submissionLogEncryptionStatus === 'ready') {
            return 'Detailed submission logs are available for this org. New submissions will store encrypted private detail and the Submission Logs tab can decrypt it for org users.';
        }

        return 'This org is entitled to detailed submission logs, but the hidden keypair has not been prepared and synced yet. Use the repair actions below to finish setup.';
    }

    async handlePrepareSubmissionLogs() {
        this.isPreparingSubmissionLogs = true;
        this.errorMessage = '';
        try {
            const status = await this.ensureSubmissionLogKeyPair();
            this.dispatchEvent(new ShowToastEvent({
                title: 'Submission logs prepared',
                message: status?.generated === false
                    ? 'Submission-log encryption was already ready for this org.'
                    : 'A hidden org keypair was created for encrypted submission-log detail.',
                variant: 'success'
            }));
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isPreparingSubmissionLogs = false;
        }
    }

    async handleSyncSubmissionLogs() {
        this.isSyncingSubmissionLogs = true;
        this.errorMessage = '';
        try {
            if (!this.submissionLogHasPublicKey || !this.submissionLogHasPrivateKey) {
                await this.ensureSubmissionLogKeyPair();
            }

            const result = await syncSubmissionLogConfig();
            if (result?.success !== true) {
                throw new Error(result?.errorMessage || 'Unable to sync TwinaForms submission-log settings to AWS.');
            }

            await this.loadSubmissionLogStatus();
            this.dispatchEvent(new ShowToastEvent({
                title: 'Submission logs synced',
                message: `AWS accepted submission-log setup for plan ${this.submissionLogPlanLabel} (${this.submissionLogRetentionLabel}).`,
                variant: 'success'
            }));
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isSyncingSubmissionLogs = false;
        }
    }

    async handleRefreshConnection() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            await this.loadConnectionStatus();
            this.dispatchEvent(new ShowToastEvent({
                title: 'Connection refreshed',
                message: 'TwinaForms connection status was refreshed.',
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
            'Disconnect TwinaForms for testing? This keeps the tenant registered but clears the Salesforce OAuth connection.'
        );
        if (!confirmed) {
            return;
        }

        this.isDisconnecting = true;
        this.errorMessage = '';
        try {
            const result = await disconnectOrg({ orgId: null });
            if (result?.success !== true) {
                throw new Error(result?.errorMessage || 'Unable to disconnect TwinaForms.');
            }

            await this.loadConnectionStatus();
            this.dispatchEvent(new ShowToastEvent({
                title: 'Connection cleared',
                message: 'TwinaForms Salesforce connection was disconnected for this org.',
                variant: 'success'
            }));
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isDisconnecting = false;
        }
    }

    applySubmissionLogStatus(status) {
        this.submissionLogPlanCode = status?.planCode || this.submissionLogPlanCode;
        this.submissionLogRetentionDays = status?.retentionDays ?? this.submissionLogRetentionDays;
        this.submissionLogsIncludedByPlan = status?.detailedLogsIncludedByPlan === true;
        this.submissionLogEffectiveMode = status?.effectiveDetailMode || this.submissionLogEffectiveMode;
        this.submissionLogEncryptionStatus = status?.encryptionStatus || this.submissionLogEncryptionStatus;
        this.submissionLogKeyVersion = status?.keyVersion || this.submissionLogKeyVersion;
        this.submissionLogHasPublicKey = status?.hasPublicKey === true;
        this.submissionLogHasPrivateKey = status?.hasPrivateKey === true;
        this.submissionLogPublicKeySyncedAt = status?.publicKeySyncedAt || this.submissionLogPublicKeySyncedAt;
    }

    async ensureSubmissionLogKeyPair() {
        if (this.submissionLogHasPublicKey && this.submissionLogHasPrivateKey) {
            return {
                generated: false,
                hasPublicKey: true,
                hasPrivateKey: true,
                keyVersion: this.submissionLogKeyVersion
            };
        }

        const generated = await this.generateSubmissionLogKeyPair();
        const status = await saveSubmissionLogKeyPair({
            publicKeyB64: generated.publicKeyB64,
            privateKeyPkcs8B64: generated.privateKeyB64,
            keyVersion: generated.keyVersion
        });
        this.applySubmissionLogStatus(status);
        return {
            ...status,
            generated: true
        };
    }

    async generateSubmissionLogKeyPair() {
        const subtle = window?.crypto?.subtle;
        if (!subtle) {
            throw new Error('This browser does not support Web Crypto key generation for submission logs.');
        }

        const keyPair = await subtle.generateKey(
            {
                name: 'RSA-OAEP',
                modulusLength: 2048,
                publicExponent: new Uint8Array([1, 0, 1]),
                hash: 'SHA-256'
            },
            true,
            ['encrypt', 'decrypt']
        );

        const publicKeyBuffer = await subtle.exportKey('spki', keyPair.publicKey);
        const privateKeyBuffer = await subtle.exportKey('pkcs8', keyPair.privateKey);

        return {
            publicKeyB64: this.arrayBufferToBase64(publicKeyBuffer),
            privateKeyB64: this.arrayBufferToBase64(privateKeyBuffer),
            keyVersion: 'v2'
        };
    }

    arrayBufferToBase64(buffer) {
        const bytes = new Uint8Array(buffer);
        let binary = '';
        bytes.forEach((byte) => {
            binary += String.fromCharCode(byte);
        });
        return btoa(binary);
    }

    formatDateTime(value) {
        if (!value) {
            return 'Unknown';
        }

        const parsed = new Date(value);
        if (Number.isNaN(parsed.getTime())) {
            return value;
        }

        return new Intl.DateTimeFormat('en-GB', {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }).format(parsed);
    }

    toTitleCase(value) {
        return String(value || '')
            .replace(/([a-z])([A-Z])/g, '$1 $2')
            .replace(/[_-]+/g, ' ')
            .replace(/\s+/g, ' ')
            .trim()
            .replace(/\b\w/g, (character) => character.toUpperCase());
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
