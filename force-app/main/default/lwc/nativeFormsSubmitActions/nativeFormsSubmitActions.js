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
    enableProConditionLogic = false;
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
    valueSourceOptions = [
        { label: 'URL Parameter', value: 'param' },
        { label: 'Literal Value', value: 'literal' }
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
        return (this.draftAction?.conditions || []).map((row, index) => ({
            ...row,
            displayIndex: index + 1
        }));
    }

    get showConditionExpression() {
        return this.enableProConditionLogic && this.conditionRows.length > 1;
    }

    get canAddCondition() {
        return this.enableProConditionLogic || this.conditionRows.length === 0;
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

    get mappingGroups() {
        const actions = this.actions || [];
        const mappings = this.mappings || [];
        return actions.map((action) => {
            const fields = mappings.filter((item) => item.actionKey === action.actionKey);
            return {
                key: action.id,
                title: action.storeResultAs || action.actionKey,
                objectApiName: action.objectApiName,
                isSelected: action.id === this.selectedActionId,
                groupClass: `mapping-group${action.id === this.selectedActionId ? ' mapping-group--selected' : ''}`,
                fields: fields.map((item) => ({
                    key: item.elementId,
                    label: item.elementLabel,
                    fieldPath: item.fieldPath
                })),
                hasFields: fields.length > 0
            };
        });
    }

    get hasMappingGroups() {
        return this.mappingGroups.length > 0;
    }

    get modeHelpText() {
        if (this.draftAction?.commandType === 'updateById') {
            return 'Use a hidden field, prefilled id, or prior result alias expression such as {foundContact.Id}.';
        }
        if (this.draftAction?.commandType === 'findAndUpdate') {
            return 'Build conditions with Salesforce fields on the left, then choose either a URL parameter or a literal value on the right.';
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
            this.enableProConditionLogic = !!workspace.enableProConditionLogic;
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
            objectApiName: this.matchObjectOptionValue(action.objectApiName),
            targetBy: config.targetBy || (action.commandType === 'create' ? 'create' : ''),
            recordIdSource: config.recordIdSource || '',
            whereClause: config.where || '',
            onNotFound: config.onNotFound || (action.commandType === 'findAndUpdate' ? 'create' : 'error'),
            conditionLogic: config.conditionLogic || 'AND',
            conditions: this.normalizeConditions(config.conditions, config.where),
            conditionExpression: config.conditionExpression || this.defaultConditionExpression((config.conditions || []).length)
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
            config.conditionExpression = this.enableProConditionLogic
                ? (this.draftAction.conditionExpression || this.defaultConditionExpression(config.conditions.length))
                : null;
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
            conditions[rowIndex].valueText = '';
        }
        if (name === 'valueSource') {
            conditions[rowIndex].valueText = conditions[rowIndex].valueText || '';
        }
        this.draftAction = {
            ...this.draftAction,
            conditions
        };
    }

    handleConditionExpressionChange(event) {
        this.draftAction = {
            ...this.draftAction,
            conditionExpression: event.target.value || ''
        };
    }

    handleAddCondition() {
        const conditions = [...(this.draftAction.conditions || [])];
        conditions.push(this.createEmptyCondition());
        this.draftAction = {
            ...this.draftAction,
            conditions,
            conditionExpression: this.defaultConditionExpression(conditions.length)
        };
    }

    handleDeleteCondition(event) {
        const rowIndex = Number(event.target.dataset.index);
        const conditions = [...(this.draftAction.conditions || [])];
        conditions.splice(rowIndex, 1);
        this.draftAction = {
            ...this.draftAction,
            conditions,
            conditionExpression: this.defaultConditionExpression(conditions.length)
        };
    }

    handleObjectSearch(event) {
        this.objectSearch = event.target.value || '';
    }

    async handleSaveAction() {
        this.isLoading = true;
        this.errorMessage = '';
        try {
            const conditionValidationMessage = this.validateConditionExpression();
            if (conditionValidationMessage) {
                this.errorMessage = conditionValidationMessage;
                this.isLoading = false;
                return;
            }
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
                valueSource: item.valueSource || (item.paramName ? 'param' : 'literal'),
                valueText: item.valueText != null ? item.valueText : (item.paramName || '')
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
                valueSource: match ? 'param' : 'literal',
                valueText: match ? match[3] : ''
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
            valueSource: 'param',
            valueText: ''
        };
    }

    sanitizeConditions() {
        return (this.draftAction.conditions || [])
            .filter((item) => item.fieldApiName && item.operator)
            .map((item) => ({
                fieldApiName: item.fieldApiName,
                operator: item.operator,
                valueSource: item.valueSource || 'param',
                valueText: item.valueText || ''
            }));
    }

    buildWhereClause() {
        const sanitized = this.sanitizeConditions();
        const clauses = sanitized
            .map((item) => this.buildConditionClause(item))
            .filter((item) => !!item);
        if (!clauses.length) {
            return '';
        }
        if (!this.enableProConditionLogic || clauses.length === 1) {
            return clauses.join(' AND ');
        }
        const expression = (this.draftAction.conditionExpression || this.defaultConditionExpression(clauses.length)).trim();
        return this.expandConditionExpression(expression, clauses);
    }

    buildConditionClause(item) {
        const fieldName = item.fieldApiName;
        const expression = this.buildConditionValueExpression(item);
        switch (item.operator) {
            case 'eq':
                return expression ? `${fieldName} = ${expression}` : '';
            case 'neq':
                return expression ? `${fieldName} != ${expression}` : '';
            case 'contains':
                return expression ? `${fieldName} CONTAINS ${expression}` : '';
            case 'startsWith':
                return expression ? `${fieldName} STARTS_WITH ${expression}` : '';
            case 'gt':
                return expression ? `${fieldName} > ${expression}` : '';
            case 'lt':
                return expression ? `${fieldName} < ${expression}` : '';
            case 'isBlank':
                return `${fieldName} IS_BLANK`;
            case 'isNotBlank':
                return `${fieldName} IS_NOT_BLANK`;
            default:
                return '';
        }
    }

    buildConditionValueExpression(item) {
        const rawValue = item?.valueText || '';
        if (!rawValue) {
            return '';
        }
        if ((item?.valueSource || 'param') === 'param') {
            return `{params.${rawValue}}`;
        }
        if (/^-?\d+(\.\d+)?$/.test(rawValue)) {
            return rawValue;
        }
        return `'${rawValue.replace(/'/g, "\\'")}'`;
    }

    defaultConditionExpression(count) {
        if (!count || count < 1) {
            return '';
        }
        return Array.from({ length: count }, (_, index) => String(index + 1)).join(' AND ');
    }

    validateConditionExpression() {
        const clauses = this.sanitizeConditions();
        if (!this.enableProConditionLogic || clauses.length <= 1) {
            return '';
        }
        const expression = (this.draftAction.conditionExpression || '').trim();
        if (!expression) {
            return 'Enter condition logic such as 1 AND (2 OR 3).';
        }
        const normalized = expression.replace(/\(/g, ' ( ').replace(/\)/g, ' ) ').replace(/\s+/g, ' ').trim();
        const tokens = normalized.split(' ');
        let depth = 0;
        let expectOperand = true;
        const maxNumber = clauses.length;
        for (const token of tokens) {
            if (!token) {
                continue;
            }
            if (token === '(') {
                if (!expectOperand) return 'Condition logic has invalid syntax.';
                depth += 1;
                continue;
            }
            if (token === ')') {
                if (expectOperand || depth < 1) return 'Condition logic has invalid syntax.';
                depth -= 1;
                continue;
            }
            if (token === 'AND' || token === 'OR') {
                if (expectOperand) return 'Condition logic has invalid syntax.';
                expectOperand = true;
                continue;
            }
            if (!/^\d+$/.test(token)) {
                return 'Condition logic can contain only numbers, AND, OR, and parentheses.';
            }
            const numericValue = Number(token);
            if (numericValue < 1 || numericValue > maxNumber) {
                return `Condition logic can only reference rows 1 to ${maxNumber}.`;
            }
            if (!expectOperand) {
                return 'Condition logic has invalid syntax.';
            }
            expectOperand = false;
        }
        if (depth !== 0 || expectOperand) {
            return 'Condition logic has invalid syntax.';
        }
        return '';
    }

    expandConditionExpression(expression, clauses) {
        const normalized = expression.replace(/\(/g, ' ( ').replace(/\)/g, ' ) ').replace(/\s+/g, ' ').trim();
        return normalized
            .split(' ')
            .map((token) => {
                if (/^\d+$/.test(token)) {
                    return `(${clauses[Number(token) - 1]})`;
                }
                return token;
            })
            .join(' ');
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

    matchObjectOptionValue(rawValue) {
        if (!rawValue) {
            return rawValue;
        }
        const exact = (this.objectOptions || []).find((item) => item.value === rawValue);
        if (exact) {
            return exact.value;
        }
        const loose = (this.objectOptions || []).find((item) => (item.value || '').toLowerCase() === String(rawValue).toLowerCase());
        return loose ? loose.value : rawValue;
    }
}
