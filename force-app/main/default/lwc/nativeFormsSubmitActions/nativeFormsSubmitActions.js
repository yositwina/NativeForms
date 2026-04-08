import { LightningElement, track } from 'lwc';
import getWorkspace from '@salesforce/apex/NativeFormsSubmitActionsController.getWorkspace';
import getFieldOptions from '@salesforce/apex/NativeFormsSubmitActionsController.getFieldOptions';
import addSubmitAction from '@salesforce/apex/NativeFormsSubmitActionsController.addSubmitAction';
import saveSubmitAction from '@salesforce/apex/NativeFormsSubmitActionsController.saveSubmitAction';
import deleteSubmitAction from '@salesforce/apex/NativeFormsSubmitActionsController.deleteSubmitAction';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const DESIGNER_VERSION_KEY = 'nativeforms:selectedVersionId';

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
    fieldOptions = [];
    conditionLogicOptions = [
        { label: 'AND', value: 'AND' },
        { label: 'OR', value: 'OR' }
    ];
    operatorOptions = [
        { label: 'Equals', value: 'eq' },
        { label: 'Not equals', value: 'neq' },
        { label: 'Contains', value: 'contains' },
        { label: 'Starts with', value: 'startsWith' },
        { label: 'Greater than', value: 'gt' },
        { label: 'Less than', value: 'lt' },
        { label: 'Is blank', value: 'isBlank' },
        { label: 'Is not blank', value: 'isNotBlank' }
    ];

    @track actions = [];
    @track versionOptions = [];
    @track draftAction = {};
    @track mappings = [];
    boundHandlePageActivation;

    commandTypeOptions = [
        { label: 'Create record', value: 'create' },
        { label: 'Update by record Id', value: 'updateById' },
        { label: 'Find and update existing record', value: 'findAndUpdate' }
    ];

    notFoundOptions = [
        { label: 'Show error', value: 'error' },
        { label: 'Create new record', value: 'create' }
    ];

    connectedCallback() {
        this.boundHandlePageActivation = this.handlePageActivation.bind(this);
        window.addEventListener('focus', this.boundHandlePageActivation);
        document.addEventListener('visibilitychange', this.boundHandlePageActivation);
        this.selectedVersionId = this.loadStoredVersionId();
        this.loadWorkspace(this.selectedVersionId);
    }

    disconnectedCallback() {
        if (this.boundHandlePageActivation) {
            window.removeEventListener('focus', this.boundHandlePageActivation);
            document.removeEventListener('visibilitychange', this.boundHandlePageActivation);
        }
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

    get showNotFoundChoice() {
        return this.isUpdateById || this.isFindAndUpdate;
    }

    get conditionRows() {
        return this.draftAction?.conditions || [];
    }

    get filteredMappings() {
        const actionKey = this.draftAction?.actionKey;
        if (!actionKey) {
            return [];
        }
        return (this.mappings || []).filter((item) => item.actionKey === actionKey);
    }

    get hasFilteredMappings() {
        return this.filteredMappings.length > 0;
    }

    get modeHelpText() {
        if (this.draftAction?.commandType === 'updateById') {
            return 'Use a hidden field, prefilled id, or prior result alias expression such as {foundContact.Id}.';
        }
        if (this.draftAction?.commandType === 'findAndUpdate') {
            return 'Use simple equality conditions joined by AND, for example: Email = \'{input.email}\'';
        }
        return 'Create adds a new record using the fields mapped from the Builder.';
    }

    get filteredObjectOptions() {
        const search = (this.objectSearch || '').trim().toLowerCase();
        const filtered = !search
            ? this.objectOptions
            : this.objectOptions.filter((item) =>
            (item.label || '').toLowerCase().includes(search) ||
            (item.value || '').toLowerCase().includes(search)
        );

        const selectedValue = this.draftAction?.objectApiName;
        if (selectedValue && !filtered.some((item) => item.value === selectedValue)) {
            const selectedOption = this.objectOptions.find((item) => item.value === selectedValue);
            if (selectedOption) {
                return [selectedOption].concat(filtered);
            }
        }
        return filtered;
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
            this.mappings = workspace.mappings || [];
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

    async handlePageActivation() {
        if (document.visibilityState && document.visibilityState !== 'visible') {
            return;
        }
        const storedVersionId = this.loadStoredVersionId();
        if (storedVersionId && storedVersionId !== this.selectedVersionId) {
            this.selectedActionId = null;
            this.draftAction = {};
            await this.loadWorkspace(storedVersionId);
        }
    }

    async handleRefreshFromDesigner() {
        const storedVersionId = this.loadStoredVersionId();
        if (!storedVersionId) {
            this.showToast('No Designer selection', 'Open NativeForms Designer and choose a version first.', 'warning');
            return;
        }

        this.selectedActionId = null;
        this.draftAction = {};
        await this.loadWorkspace(storedVersionId);
        this.showToast('Refreshed', 'Loaded the version currently selected in NativeForms Designer.', 'success');
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
            whereClause: config.where || '',
            onNotFound: config.onNotFound || (action.commandType === 'findAndUpdate' ? 'create' : 'error'),
            conditionLogic: config.conditionLogic || 'AND',
            conditions: this.normalizeConditions(config.conditions, config.where)
        };
        this.loadFieldOptions(action.objectApiName);
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
            config.onNotFound = this.draftAction.onNotFound || 'error';
        }
        if (this.draftAction.commandType === 'findAndUpdate') {
            config.targetBy = 'where';
            const whereClause = this.buildWhereClause();
            if (whereClause) {
                config.where = whereClause;
            }
            config.onNotFound = this.draftAction.onNotFound || 'create';
            config.conditionLogic = this.draftAction.conditionLogic || 'AND';
            config.conditions = this.sanitizeConditions();
        }
        return JSON.stringify(config, null, 2);
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
        if (name === 'objectApiName') {
            this.loadFieldOptions(value);
        }
    }

    handleConditionChange(event) {
        const rowIndex = Number(event.target.dataset.index);
        const { name, value } = event.target;
        const conditions = [...(this.draftAction.conditions || [])];
        conditions[rowIndex] = {
            ...conditions[rowIndex],
            [name]: value
        };
        if (name === 'operator' && (value === 'isBlank' || value === 'isNotBlank')) {
            conditions[rowIndex].paramName = '';
        }
        this.draftAction = {
            ...this.draftAction,
            conditions
        };
    }

    handleAddCondition() {
        const conditions = [...(this.draftAction.conditions || [])];
        conditions.push(this.createEmptyCondition());
        this.draftAction = {
            ...this.draftAction,
            conditions
        };
    }

    handleDeleteCondition(event) {
        const rowIndex = Number(event.target.dataset.index);
        const conditions = [...(this.draftAction.conditions || [])];
        conditions.splice(rowIndex, 1);
        this.draftAction = {
            ...this.draftAction,
            conditions
        };
    }

    handleObjectSearch(event) {
        this.objectSearch = event.target.value || '';
    }

    async handleSaveAction() {
        this.isLoading = true;
        this.errorMessage = '';
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

    async loadFieldOptions(objectApiName) {
        if (!objectApiName) {
            this.fieldOptions = [];
            return;
        }
        try {
            this.fieldOptions = await getFieldOptions({ objectApiName });
        } catch (error) {
            this.fieldOptions = [];
        }
    }

    normalizeConditions(savedConditions, fallbackWhereClause) {
        if (Array.isArray(savedConditions) && savedConditions.length) {
            return savedConditions.map((item, index) => ({
                id: item.id || `cond-${index}-${Date.now()}`,
                fieldApiName: item.fieldApiName || '',
                operator: item.operator || 'eq',
                paramName: item.paramName || ''
            }));
        }
        if (!fallbackWhereClause) {
            return [this.createEmptyCondition()];
        }
        const parts = fallbackWhereClause.split(/\s+AND\s+/i);
        return parts.map((item, index) => {
            const match = item.match(/^(.+?)\s*(=|!=|>|<)\s*\{params\.([^}]+)\}$/i);
            return {
                id: `cond-${index}-${Date.now()}`,
                fieldApiName: match ? match[1].trim() : '',
                operator: match ? this.operatorFromToken(match[2]) : 'eq',
                paramName: match ? match[3] : ''
            };
        });
    }

    operatorFromToken(token) {
        if (token === '!=') {
            return 'neq';
        }
        if (token === '>') {
            return 'gt';
        }
        if (token === '<') {
            return 'lt';
        }
        return 'eq';
    }

    createEmptyCondition() {
        return {
            id: `cond-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
            fieldApiName: '',
            operator: 'eq',
            paramName: ''
        };
    }

    sanitizeConditions() {
        return (this.draftAction.conditions || [])
            .filter((item) => item.fieldApiName && item.operator)
            .map((item) => ({
                fieldApiName: item.fieldApiName,
                operator: item.operator,
                paramName: item.paramName || ''
            }));
    }

    buildWhereClause() {
        const clauses = this.sanitizeConditions()
            .map((item) => this.buildConditionClause(item))
            .filter((item) => !!item);
        if (!clauses.length) {
            return '';
        }
        const joiner = ` ${this.draftAction.conditionLogic || 'AND'} `;
        return clauses.join(joiner);
    }

    buildConditionClause(item) {
        const fieldName = item.fieldApiName;
        const paramRef = item.paramName ? `{params.${item.paramName}}` : '';
        switch (item.operator) {
            case 'eq':
                return paramRef ? `${fieldName} = ${paramRef}` : '';
            case 'neq':
                return paramRef ? `${fieldName} != ${paramRef}` : '';
            case 'contains':
                return paramRef ? `${fieldName} CONTAINS ${paramRef}` : '';
            case 'startsWith':
                return paramRef ? `${fieldName} STARTS_WITH ${paramRef}` : '';
            case 'gt':
                return paramRef ? `${fieldName} > ${paramRef}` : '';
            case 'lt':
                return paramRef ? `${fieldName} < ${paramRef}` : '';
            case 'isBlank':
                return `${fieldName} IS_BLANK`;
            case 'isNotBlank':
                return `${fieldName} IS_NOT_BLANK`;
            default:
                return '';
        }
    }

    normalizeError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (Array.isArray(error?.body) && error.body.length && error.body[0]?.message) {
            return error.body[0].message;
        }
        if (error?.body?.output?.errors?.length) {
            return error.body.output.errors.map((entry) => entry.message).join(', ');
        }
        if (error?.message) {
            return error.message;
        }
        if (typeof error === 'string') {
            return error;
        }
        try {
            return JSON.stringify(error);
        } catch (e) {
            // fall through
        }
        return 'Something went wrong while loading submit actions.';
    }

    loadStoredVersionId() {
        try {
            return window.sessionStorage.getItem(DESIGNER_VERSION_KEY);
        } catch (e) {
            return null;
        }
    }
}
