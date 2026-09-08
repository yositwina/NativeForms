import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getHomeView from '@salesforce/apex/NativeFormsHomeController.getHomeView';
import installDemoData from '@salesforce/apex/NativeFormsDemoDataController.installDemoData';

const TEMP_UPGRADE_URL = 'https://twinaforms.com/upgrade/';
const HOME_REFRESH_EVENT = 'nativeforms:home-refresh-requested';
const HOME_REFRESH_SESSION_KEY = 'nativeforms:home-refresh-pending';

export default class NativeFormsHome extends NavigationMixin(LightningElement) {
    homeView;
    isLoading = true;
    isInstalling = false;
    errorMessage = '';
    successMessage = '';
    boundHomeRefreshHandler;
    refreshFlagConsumed = false;

    connectedCallback() {
        this.boundHomeRefreshHandler = () => {
            this.loadHome();
        };
        window.addEventListener(HOME_REFRESH_EVENT, this.boundHomeRefreshHandler);
        this.loadHome();
        this.consumePendingRefreshFlag();
    }

    disconnectedCallback() {
        if (this.boundHomeRefreshHandler) {
            window.removeEventListener(HOME_REFRESH_EVENT, this.boundHomeRefreshHandler);
            this.boundHomeRefreshHandler = null;
        }
    }

    async loadHome() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const result = await getHomeView();
            this.homeView = result || {};
            this.errorMessage = result?.errorMessage || '';
        } catch (error) {
            this.errorMessage = this.formatError(error);
            this.homeView = null;
        } finally {
            this.isLoading = false;
        }
    }

    renderedCallback() {
        this.consumePendingRefreshFlag();
    }

    consumePendingRefreshFlag() {
        if (this.refreshFlagConsumed) {
            return;
        }
        try {
            const pendingRefresh = window.sessionStorage?.getItem(HOME_REFRESH_SESSION_KEY);
            if (pendingRefresh !== 'true') {
                return;
            }
            this.refreshFlagConsumed = true;
            window.sessionStorage.removeItem(HOME_REFRESH_SESSION_KEY);
            this.loadHome();
        } catch (error) {
            // Home still loads normally if session storage is unavailable.
        }
    }

    async handleInstall() {
        this.isInstalling = true;
        this.errorMessage = '';
        this.successMessage = '';
        try {
            const result = await installDemoData();
            this.successMessage = result?.message || 'Demo data installed successfully.';
            await this.loadHome();
        } catch (error) {
            this.errorMessage = this.formatError(error);
        } finally {
            this.isInstalling = false;
        }
    }

    handlePrimaryAction() {
        if (this.showConnectAction) {
            this.handleOpenConnect();
            return;
        }

        this.handleOpenUpgrade();
    }

    handleOpenConnect() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: this.connectTabApiName
            }
        });
    }

    handleOpenUpgrade() {
        this.navigateToUrl(TEMP_UPGRADE_URL);
    }

    handleOpenComparePlans() {
        this.navigateToUrl(TEMP_UPGRADE_URL);
    }

    navigateToUrl(url) {
        if (!url) {
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url
            }
        });
    }

    formatError(error) {
        return error?.body?.message || error?.message || 'Unknown error';
    }

    get connection() {
        return this.homeView?.connection || {};
    }

    get connectTabApiName() {
        return this.homeView?.connectTabApiName || 'NativeForms_Connect';
    }

    get plan() {
        return this.homeView?.plan || {};
    }

    get usage() {
        return this.homeView?.usage || {};
    }

    get demo() {
        return this.homeView?.demo || {};
    }

    get upgradeFeatures() {
        return this.homeView?.upgradeFeatures || [];
    }

    get installDisabled() {
        return this.isLoading || this.isInstalling;
    }

    get showConnectAction() {
        return this.connection.needsConnectAction === true || this.connection.ready !== true;
    }

    get showPlanUpgradeAction() {
        return this.plan.showUpgradeAction === true;
    }

    get showUpgradeSection() {
        return this.upgradeFeatures.length > 0;
    }

    get showPrimaryAction() {
        return this.showConnectAction || this.showPlanUpgradeAction;
    }

    get primaryActionLabel() {
        return this.showConnectAction ? 'Open Connect Page' : 'Upgrade Plan';
    }

    get heroHeading() {
        return this.showConnectAction
            ? 'Finish setup before using TwinaForms live.'
            : 'Your TwinaForms workspace is ready.';
    }

    get heroCopy() {
        return this.showConnectAction
            ? 'Check setup, plan, and workspace limits from one compact view.'
            : 'Review your plan, demo status, and current limits in one compact view.';
    }

    get connectionBadgeClass() {
        return this.showConnectAction
            ? 'status-pill status-pill--warning'
            : 'status-pill status-pill--success';
    }

    get connectionBadgeLabel() {
        return this.showConnectAction ? 'Setup Incomplete' : 'Connection Ready';
    }

    get planBadgeClass() {
        return 'status-pill status-pill--neutral';
    }

    get planLabel() {
        return this.plan.label || 'Plan';
    }

    get connectionCardTitle() {
        return this.showConnectAction ? 'Setup needs attention' : 'Ready to use';
    }

    get planMaxFormsLabel() {
        return this.plan.maxForms == null ? 'Unlimited' : String(this.plan.maxForms);
    }

}
