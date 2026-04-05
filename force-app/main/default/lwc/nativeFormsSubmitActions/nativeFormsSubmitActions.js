import { LightningElement, track } from 'lwc';
import getWorkspace from '@salesforce/apex/NativeFormsSubmitActionsController.getWorkspace';
import addSubmitAction from '@salesforce/apex/NativeFormsSubmitActionsController.addSubmitAction';
import saveSubmitAction from '@salesforce/apex/NativeFormsSubmitActionsController.saveSubmitAction';
import deleteSubmitAction from '@salesforce/apex/NativeFormsSubmitActionsController.deleteSubmitAction';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class NativeFormsSubmitActions extends LightningElement {
    isLoading = true;
    errorMessage = '';
    workspaceLoaded = false;
    selectedVersionId;
    selectedVersionName = '';
    selectedVersionStatus = '';
    selectedFormName = '';
    selectedActionId;
    objectOptions = [];
    objectSearch = '';

    @track actions = [];
    @track versionOptions = [];
    @track draftAction = {};

    commandTypeOptions = [
        { label: 'create', value: 'create' },
        { label: 'updateById', value: 'updateById' },
        { label: 'findAndUpdate', value: 'findAndUpdate' }
    ];

    connectedCallback() {
        this.loadWorkspace();
    }

    get selectedAction() {
        return this.actions.find((item) => item.id === this.selectedActionId);
    }

    get isUpdateById() {
        return this.draftAction?.commandType === 'updateById';
    }

    get isFindAndUpdate() {
        return this.draftAction?.commandType === 'findAndUpdate';
    }

    get filteredObjectOptions() {
        const search = (this.objectSearch || '').trim().toLowerCase();
        if (!search) {
            return this.objectOptions;
        }
        return this.objectOptions.filter((item) =>
            (item.label || '').toLowerCase().includes(search) ||
            (item.value || '').toLowerCase().includes(search)
        );
    }

    async loadWorkspace(versionId = this.selectedVersionId) {
        this.isLoading = true;
        this.errorMessage = '';

        try {
            const workspace = await getWorkspace({ versionId });
            this.selectedVersionId = workspace.selectedVersionId;
            this.selectedVersionName = workspace.selectedVersionName;
            this.selectedVersionStatus = workspace.selectedVersionStatus;
            this.selectedFormName = workspace.selectedFormName;
            this.objectOptions = workspace.objectOptions || [];
            this.versionOptions = (workspace.versions || []).map((option) => ({
                label: `${option.label} (${option.status})`,
                value: option.value
            }));
            this.actions = (workspace.actions || []).map((item) => this.decorateAction(item));
            this.workspaceLoaded = !!workspace.selectedVersionId;

            const existingSelected = this.actions.find((item) => item.id === this.selectedActionId);
            if (existingSelected) {
                this.setDraftAction(existingSelected);
            } else if (this.actions.length) {
                this.selectedActionId = this.actions[0].id;
                this.setDraftAction(this.actions[0]);
            } else {
                this.selectedActionId = null;
                this.draftAction = {};
            }
            this.syncSelection();
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    decorateAction(item) {
        return {
            ...item,
            cardClass: `action-card${item.id === this.selectedActionId ? ' action-card--selected' : ''}`
        };
    }

    setDraftAction(action) {
        if (!action) {
            this.draftAction = {};
            return;
        }

        const config = this.parseConfig(action.configJson);
        this.draftAction = {
            ...action,
            targetBy: config.targetBy || (action.commandType === 'create' ? 'create' : ''),
            recordIdSource: config.recordIdSource || '',
            whereClause: config.where || ''
        };
    }

    parseConfig(rawJson) {
        if (!rawJson) {
            return {};
        }
        try {
            return JSON.parse(rawJson);
        } catch (e) {
            return {};
        }
    }

    buildConfigJson() {
        const config = {};
        if (this.draftAction.commandType === 'create') {
            config.targetBy = 'create';
        }
        if (this.draftAction.commandType === 'updateById') {
            config.targetBy = 'id';
            if (this.draftAction.recordIdSource) {
                config.recordIdSource = this.draftAction.recordIdSource;
            }
        }
        if (this.draftAction.commandType === 'findAndUpdate') {
            config.targetBy = 'where';
            if (this.draftAction.whereClause) {
                config.where = this.draftAction.whereClause;
            }
        }
        return JSON.stringify(config, null, 2);
    }

    handleVersionChange(event) {
        this.selectedVersionId = event.detail.value;
        this.selectedActionId = null;
        this.draftAction = {};
        this.loadWorkspace(this.selectedVersionId);
    }

    async handleAddAction() {
        if (!this.selectedVersionId) {
            return;
        }

        this.isLoading = true;
        try {
            const newAction = await addSubmitAction({ versionId: this.selectedVersionId });
            this.selectedActionId = newAction.id;
            await this.loadWorkspace(this.selectedVersionId);
            this.showToast('Submit action added', `${newAction.objectApiName} action is ready to configure.`, 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleSelectAction(event) {
        const actionId = event.currentTarget.dataset.id;
        const match = this.actions.find((item) => item.id === actionId);
        if (!match) {
            return;
        }
        this.selectedActionId = match.id;
        this.setDraftAction(match);
        this.syncSelection();
    }

    handleDraftChange(event) {
        const { name, value } = event.target;
        this.draftAction = {
            ...this.draftAction,
            [name]: value
        };
    }

    handleObjectSearch(event) {
        this.objectSearch = event.target.value || '';
    }

    async handleSaveAction() {
        this.isLoading = true;
        try {
            const configJson = this.buildConfigJson();
            await saveSubmitAction({
                inputValue: {
                    id: this.draftAction.id,
                    versionId: this.selectedVersionId,
                    actionKey: this.draftAction.actionKey,
                    commandType: this.draftAction.commandType,
                    objectApiName: this.draftAction.objectApiName,
                    storeResultAs: this.draftAction.storeResultAs,
                    configJson
                }
            });
            await this.loadWorkspace(this.selectedVersionId);
            this.showToast('Submit action saved', 'The submit action was updated.', 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleDeleteAction() {
        if (!this.draftAction.id) {
            return;
        }

        this.isLoading = true;
        try {
            await deleteSubmitAction({ actionId: this.draftAction.id });
            this.selectedActionId = null;
            this.draftAction = {};
            await this.loadWorkspace(this.selectedVersionId);
            this.showToast('Submit action deleted', 'The action was removed.', 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    syncSelection() {
        this.actions = this.actions.map((item) => this.decorateAction(item));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    normalizeError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'Something went wrong while loading submit actions.';
    }
}
