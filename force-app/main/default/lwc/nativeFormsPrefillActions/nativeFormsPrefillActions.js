import { LightningElement, track } from 'lwc';
import getWorkspace from '@salesforce/apex/NativeFormsPrefillActionsController.getWorkspace';
import getFieldOptions from '@salesforce/apex/NativeFormsPrefillActionsController.getFieldOptions';
import addPrefillAction from '@salesforce/apex/NativeFormsPrefillActionsController.addPrefillAction';
import savePrefillAction from '@salesforce/apex/NativeFormsPrefillActionsController.savePrefillAction';
import deletePrefillAction from '@salesforce/apex/NativeFormsPrefillActionsController.deletePrefillAction';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const DESIGNER_VERSION_KEY = 'nativeforms:selectedVersionId';

export default class NativeFormsPrefillActions extends LightningElement {
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
        { label: 'findOne', value: 'findOne' },
        { label: 'findMany', value: 'findMany' }
    ];

    notFoundOptions = [
        { label: 'ignore', value: 'ignore' },
        { label: 'error', value: 'error' }
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

    get isFindMany() {
        return this.draftAction?.commandType === 'findMany';
    }

    get conditionRows() {
        return this.draftAction?.conditions || [];
    }

    get filteredMappings() {
        const aliasValue = this.draftAction?.storeResultAs;
        if (!aliasValue) {
            return [];
        }
        return (this.mappings || []).filter((item) => item.aliasValue === aliasValue);
    }

    get hasFilteredMappings() {
        return this.filteredMappings.length > 0;
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
            whereClause: config.where || '',
            orderBy: config.orderBy || '',
            limitValue: config.limit == null ? null : config.limit,
            onNotFound: config.onNotFound || 'ignore',
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
        const whereClause = this.buildWhereClause();
        if (whereClause) {
            config.where = whereClause;
        }
        if (this.draftAction.commandType === 'findMany' && this.draftAction.orderBy) {
            config.orderBy = this.draftAction.orderBy;
        }
        if (this.draftAction.commandType === 'findMany' && this.draftAction.limitValue !== null && this.draftAction.limitValue !== undefined && this.draftAction.limitValue !== '') {
            config.limit = Number(this.draftAction.limitValue);
        }
        config.conditionLogic = this.draftAction.conditionLogic || 'AND';
        config.conditions = this.sanitizeConditions();
        config.onNotFound = this.draftAction.onNotFound || 'ignore';
        return JSON.stringify(config, null, 2);
    }

    async handleAddAction() {
        if (!this.selectedVersionId) {
            return;
        }

        this.isLoading = true;
        try {
            const newAction = await addPrefillAction({ versionId: this.selectedVersionId });
            this.selectedActionId = newAction.id;
            await this.loadWorkspace(this.selectedVersionId);
            this.showToast('Prefill action added', `${newAction.actionKey} is ready to configure.`, 'success');
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
        try {
            const configJson = this.buildConfigJson();
            await savePrefillAction({
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
            this.showToast('Prefill action saved', 'The query definition was updated.', 'success');
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
            await deletePrefillAction({ actionId: this.draftAction.id });
            this.selectedActionId = null;
            this.draftAction = {};
            await this.loadWorkspace(this.selectedVersionId);
            this.showToast('Prefill action deleted', 'The action was removed.', 'success');
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
            const split = item.split('=');
            const fieldApiName = split.length > 1 ? split[0].trim() : '';
            let paramName = '';
            if (split.length > 1) {
                const right = split[1].trim();
                const match = right.match(/\{params\.([^}]+)\}/i);
                paramName = match ? match[1] : '';
            }
            return {
                id: `cond-${index}-${Date.now()}`,
                fieldApiName,
                operator: 'eq',
                paramName
            };
        });
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
        if (error?.message) {
            return error.message;
        }
        return 'Something went wrong while loading prefill actions.';
    }

    loadStoredVersionId() {
        try {
            return window.sessionStorage.getItem(DESIGNER_VERSION_KEY);
        } catch (e) {
            return null;
        }
    }
}
