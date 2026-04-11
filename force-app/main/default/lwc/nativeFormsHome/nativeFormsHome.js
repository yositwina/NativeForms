import { LightningElement } from 'lwc';
import getHomeState from '@salesforce/apex/NativeFormsDemoDataController.getHomeState';
import installDemoData from '@salesforce/apex/NativeFormsDemoDataController.installDemoData';

export default class NativeFormsHome extends LightningElement {
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
            const state = await getHomeState();
            this.demoDataInstalled = !!state?.demoDataInstalled;
            this.demoDataVersionValue = state?.demoDataVersion || 'Not installed yet';
            this.installedThemeCount = state?.installedThemeCount || 0;
            this.installedContactCount = state?.installedContactCount || 0;
            this.installedCaseCount = state?.installedCaseCount || 0;
            this.installedFormCount = state?.installedFormCount || 0;
            this.targetThemeCount = state?.targetThemeCount || 4;
            this.targetContactCount = state?.targetContactCount || 2;
            this.targetCaseCount = state?.targetCaseCount || 4;
            this.targetFormCount = state?.targetFormCount || 2;
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

    formatError(error) {
        return error?.body?.message || error?.message || 'Unknown error';
    }

    get installDisabled() {
        return this.isLoading || this.isInstalling;
    }

    get installedLabel() {
        return this.demoDataInstalled ? 'Installed' : 'Not installed';
    }
}
