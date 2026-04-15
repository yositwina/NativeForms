import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getHomeState from '@salesforce/apex/NativeFormsDemoDataController.getHomeState';
import installDemoData from '@salesforce/apex/NativeFormsDemoDataController.installDemoData';
import getConnectionStatus from '@salesforce/apex/NativeFormsSetupController.getConnectionStatus';
import getSubmissionLogStatus from '@salesforce/apex/NativeFormsSubmissionLogsController.getSubmissionLogStatus';

const PLAN_FEATURES = {
    free: [
        { key: 'builder', label: 'Core Form Builder', detail: 'Create and manage basic forms for your org.', enabled: true },
        { key: 'themes', label: 'Themes', detail: 'Apply and manage form themes.', enabled: true },
        { key: 'prefill', label: 'Prefill', detail: 'Use basic prefill and lookup actions.', enabled: true },
        { key: 'submit', label: 'Submit Actions', detail: 'Use standard submit actions.', enabled: true },
        { key: 'detailedLogs', label: 'Detailed Submission Logs', detail: 'Private field-level logs for each submit.', enabled: false },
        { key: 'proFeatures', label: 'Advanced Pro Features', detail: 'Repeat groups, formula fields, advanced submit, and load file.', enabled: false }
    ],
    starter: [
        { key: 'builder', label: 'Core Form Builder', detail: 'Create and manage production forms for your org.', enabled: true },
        { key: 'themes', label: 'Themes', detail: 'Apply and manage form themes.', enabled: true },
        { key: 'prefill', label: 'Prefill', detail: 'Use standard prefill and lookup actions.', enabled: true },
        { key: 'submit', label: 'Submit Actions', detail: 'Use standard submit actions.', enabled: true },
        { key: 'detailedLogs', label: 'Detailed Submission Logs', detail: 'Private field-level logs for each submit.', enabled: true },
        { key: 'proFeatures', label: 'Advanced Pro Features', detail: 'Repeat groups, formula fields, advanced submit, and load file.', enabled: false }
    ],
    trial: [
        { key: 'builder', label: 'Core Form Builder', detail: 'Create and manage forms during evaluation.', enabled: true },
        { key: 'themes', label: 'Themes', detail: 'Apply and manage form themes.', enabled: true },
        { key: 'prefill', label: 'Prefill', detail: 'Use prefill and lookup actions.', enabled: true },
        { key: 'submit', label: 'Submit Actions', detail: 'Use full submit flows during evaluation.', enabled: true },
        { key: 'detailedLogs', label: 'Detailed Submission Logs', detail: 'Private field-level logs for each submit.', enabled: true },
        { key: 'proFeatures', label: 'Advanced Pro Features', detail: 'Repeat groups, formula fields, advanced submit, and load file.', enabled: true }
    ],
    pro: [
        { key: 'builder', label: 'Core Form Builder', detail: 'Create and manage unlimited production forms.', enabled: true },
        { key: 'themes', label: 'Themes', detail: 'Apply and manage form themes.', enabled: true },
        { key: 'prefill', label: 'Prefill', detail: 'Use full prefill and lookup actions.', enabled: true },
        { key: 'submit', label: 'Submit Actions', detail: 'Use full submit actions and modes.', enabled: true },
        { key: 'detailedLogs', label: 'Detailed Submission Logs', detail: 'Private field-level logs for each submit.', enabled: true },
        { key: 'proFeatures', label: 'Advanced Pro Features', detail: 'Repeat groups, formula fields, advanced submit, and load file.', enabled: true }
    ]
};

export default class NativeFormsHome extends NavigationMixin(LightningElement) {
    demoDataInstalled = false;
    demoDataVersionValue = 'Not installed yet';
    installedThemeCount = 0;
    installedContactCount = 0;
    installedCaseCount = 0;
    installedFormCount = 0;
    targetThemeCount = 4;
    targetContactCount = 2;
    targetCaseCount = 4;
    targetFormCount = 2;

    connectionStatus = null;
    submissionLogStatus = null;

    isLoading = true;
    isInstalling = false;
    errorMessage = '';
    successMessage = '';

    connectedCallback() {
        this.loadState();
    }

    async loadState() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const [homeState, connectionStatus, submissionLogStatus] = await Promise.all([
                getHomeState(),
                getConnectionStatus({ orgId: null }).catch(() => null),
                getSubmissionLogStatus().catch(() => null)
            ]);

            this.demoDataInstalled = !!homeState?.demoDataInstalled;
            this.demoDataVersionValue = homeState?.demoDataVersion || 'Not installed yet';
            this.installedThemeCount = homeState?.installedThemeCount || 0;
            this.installedContactCount = homeState?.installedContactCount || 0;
            this.installedCaseCount = homeState?.installedCaseCount || 0;
            this.installedFormCount = homeState?.installedFormCount || 0;
            this.targetThemeCount = homeState?.targetThemeCount || 4;
            this.targetContactCount = homeState?.targetContactCount || 2;
            this.targetCaseCount = homeState?.targetCaseCount || 4;
            this.targetFormCount = homeState?.targetFormCount || 2;
            this.connectionStatus = connectionStatus;
            this.submissionLogStatus = submissionLogStatus;
        } catch (error) {
            this.errorMessage = this.formatError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleInstall() {
        this.isInstalling = true;
        this.errorMessage = '';
        this.successMessage = '';
        try {
            const result = await installDemoData();
            this.successMessage = result?.message || 'Demo data installed successfully.';
            await this.loadState();
        } catch (error) {
            this.errorMessage = this.formatError(error);
        } finally {
            this.isInstalling = false;
        }
    }

    handleOpenConnect() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'NativeForms_Connect'
            }
        });
    }

    formatError(error) {
        return error?.body?.message || error?.message || 'Unknown error';
    }

    get installDisabled() {
        return this.isLoading || this.isInstalling;
    }

    get installedLabel() {
        return this.demoDataInstalled ? 'Installed' : 'Not installed';
    }

    get connectionSetupLabel() {
        return this.prettyLabel(this.connectionStatus?.setupState || 'not_started');
    }

    get connectionLabel() {
        return this.connectionStatus?.connected ? 'Connected' : 'Not fully connected';
    }

    get tenantAuthLabel() {
        return this.connectionStatus?.tenantAuthVerified ? 'Verified' : this.prettyLabel(this.connectionStatus?.tenantAuthStatus || 'not_verified');
    }

    get credentialsLabel() {
        return this.connectionStatus?.hasClientCredentials ? 'Configured' : 'Missing';
    }

    get showConnectAction() {
        if (!this.connectionStatus) {
            return true;
        }

        return !this.connectionStatus.connected
            || !this.connectionStatus.tenantAuthVerified
            || !this.connectionStatus.hasClientCredentials;
    }

    get connectionBadgeClass() {
        return this.showConnectAction ? 'status-pill status-pill--warning' : 'status-pill status-pill--success';
    }

    get connectionBadgeLabel() {
        return this.showConnectAction ? 'Connect Incomplete' : 'Connection Ready';
    }

    get planCode() {
        return String(this.submissionLogStatus?.planCode || 'free').toLowerCase();
    }

    get planLabel() {
        return this.prettyLabel(this.planCode);
    }

    get planBadgeClass() {
        return 'status-pill status-pill--neutral';
    }

    get detailedLogsLabel() {
        return this.submissionLogStatus?.detailedLogsIncludedByPlan ? 'Included' : 'Not included';
    }

    get retentionLabel() {
        return this.submissionLogStatus?.retentionDays ? `${this.submissionLogStatus.retentionDays} days` : 'Not available';
    }

    get encryptionLabel() {
        return this.prettyLabel(this.submissionLogStatus?.encryptionStatus || 'not_ready');
    }

    get featureAccessList() {
        const baseFeatures = PLAN_FEATURES[this.planCode] || PLAN_FEATURES.free;
        const detailedLogsIncluded = this.submissionLogStatus?.detailedLogsIncludedByPlan === true;

        return baseFeatures.map((feature) => {
            const enabled = feature.key === 'detailedLogs'
                ? detailedLogsIncluded
                : feature.enabled;

            return {
                ...feature,
                enabled,
                badgeLabel: enabled ? 'Included' : 'Not included',
                badgeClass: enabled ? 'feature-badge feature-badge--success' : 'feature-badge feature-badge--muted'
            };
        });
    }

    prettyLabel(value) {
        return String(value || '')
            .replace(/([a-z])([A-Z])/g, '$1 $2')
            .replace(/[_-]+/g, ' ')
            .replace(/\s+/g, ' ')
            .trim()
            .replace(/\b\w/g, (character) => character.toUpperCase());
    }
}
