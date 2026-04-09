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
    formFieldOptions = [];
    objectSearch = '';
    fieldOptions = [];
    enableProConditionLogic = false;
    enableProPrefillAliasReferences = false;
    prefillAliasDetails = [];
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
        return (this.draftAction?.conditions || []).map((row, index) => ({
            ...row,
            displayIndex: index + 1,
            isValueSourceField: row.valueSource === 'field',
            isValueSourceAlias: row.valueSource === 'alias',
            selectedAliasName: row.valueSource === 'alias' ? this.aliasNameFromValue(row.valueText) : '',
            selectedAliasField: row.valueSource === 'alias' ? this.aliasFieldFromValue(row.valueText) : '',
            aliasOptions: this.prefillAliasOptions,
            aliasFieldOptions: this.getPrefillAliasFieldOptions(row.valueSource === 'alias' ? this.aliasNameFromValue(row.valueText) : ''),
            valueLabel: this.getConditionValueLabel(row.valueSource || 'param'),
            valuePlaceholder: this.getConditionValuePlaceholder(row.valueSource || 'param')
        }));
    }

    get prefillAliasOptions() {
        return [{ label: 'Select alias', value: '' }].concat(
            (this.prefillAliasDetails || []).map((item) => ({
                label: item.alias,
                value: item.alias
            }))
        );
    }

    get valueSourceOptions() {
        const options = [
            { label: 'URL Parameter', value: 'param' },
            { label: 'Form Field', value: 'field' },
            { label: 'Literal Value', value: 'literal' }
        ];
        if (this.enableProPrefillAliasReferences) {
            options.splice(2, 0, { label: 'Prefill Alias Field', value: 'alias' });
        }
        return options;
    }

    get showConditionExpression() {
        return this.enableProConditionLogic && this.conditionRows.length > 1;
    }

    get canAddCondition() {
        return this.enableProConditionLogic || this.conditionRows.length === 0;
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

    get mappingGroups() {
        const actions = this.actions || [];
        const mappings = this.mappings || [];
        return actions.map((action) => {
            const fields = mappings.filter((item) => item.aliasValue === action.storeResultAs);
            return {
                key: action.id,
                title: action.storeResultAs,
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
            this.formFieldOptions = workspace.formFieldOptions || [];
            this.mappings = workspace.mappings || [];
            this.enableProConditionLogic = !!workspace.enableProConditionLogic;
            this.enableProPrefillAliasReferences = !!workspace.enableProPrefillAliasReferences;
            this.prefillAliasDetails = workspace.prefillAliasDetails || [];
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
            whereClause: config.where || '',
            orderBy: config.orderBy || '',
            limitValue: config.limit == null ? (action.commandType === 'findMany' ? 25 : null) : config.limit,
            onNotFound: config.onNotFound || 'ignore',
            conditionLogic: config.conditionLogic || '',
            conditions: this.normalizeConditions(config.conditions, config.where),
            conditionExpression: config.conditionExpression || config.conditionLogic || this.defaultConditionExpression((config.conditions || []).length)
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
        config.conditions = this.sanitizeConditions();
        config.conditionLogic = this.enableProConditionLogic
            ? (this.draftAction.conditionExpression || this.defaultConditionExpression(config.conditions.length))
            : this.defaultConditionExpression(config.conditions.length);
        config.conditionExpression = config.conditionLogic;
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
        const nextDraft = {
            ...this.draftAction,
            [name]: value
        };
        if (name === 'commandType') {
            if (value === 'findMany' && (nextDraft.limitValue === null || nextDraft.limitValue === undefined || nextDraft.limitValue === '')) {
                nextDraft.limitValue = 25;
            }
            if (value !== 'findMany') {
                nextDraft.limitValue = null;
                nextDraft.orderBy = '';
            }
        }
        this.draftAction = nextDraft;
        if (name === 'objectApiName') {
            this.loadFieldOptions(value);
        }
    }

    handleConditionChange(event) {
        const rowIndex = Number(event.target.dataset.index);
        const { name, value } = event.target;
        const conditions = [...(this.draftAction.conditions || [])];
        if (name === 'aliasName' || name === 'aliasField') {
            const currentAlias = this.aliasNameFromValue(conditions[rowIndex]?.valueText || '');
            const currentField = this.aliasFieldFromValue(conditions[rowIndex]?.valueText || '');
            const nextAlias = name === 'aliasName' ? value : currentAlias;
            const nextField = name === 'aliasField' ? value : currentField;
            conditions[rowIndex] = {
                ...conditions[rowIndex],
                valueText: this.composeAliasValue(nextAlias, nextField)
            };
            this.draftAction = {
                ...this.draftAction,
                conditions
            };
            return;
        }
        conditions[rowIndex] = {
            ...conditions[rowIndex],
            [name]: name === 'valueText'
                ? this.normalizeConditionValueInput(conditions[rowIndex]?.valueSource, value)
                : value
        };
        if (name === 'operator' && (value === 'isBlank' || value === 'isNotBlank')) {
            conditions[rowIndex].valueText = '';
        }
        if (name === 'valueSource') {
            conditions[rowIndex].valueText = this.normalizeConditionValueInput(value, conditions[rowIndex].valueText || '');
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
        try {
            if (!this.draftAction.objectApiName) {
                this.errorMessage = 'Choose a Salesforce Object before saving the prefill action.';
                this.isLoading = false;
                return;
            }
            if (this.draftAction.commandType === 'findMany') {
                const limitValue = Number(this.draftAction.limitValue);
                if (!Number.isFinite(limitValue) || limitValue < 1) {
                    this.errorMessage = 'Enter a valid Limit greater than 0 for a findMany prefill action.';
                    this.isLoading = false;
                    return;
                }
            }
            const conditionValidationMessage = this.validateConditionExpression();
            if (conditionValidationMessage) {
                this.errorMessage = conditionValidationMessage;
                this.isLoading = false;
                return;
            }
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
                valueSource: item.valueSource || (item.paramName ? 'param' : 'literal'),
                valueText: this.normalizeConditionValueInput(
                    item.valueSource || (item.paramName ? 'param' : 'literal'),
                    item.valueText != null ? item.valueText : (item.paramName || '')
                )
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
                valueSource: paramName ? 'param' : 'literal',
                valueText: this.normalizeConditionValueInput(paramName ? 'param' : 'literal', paramName)
            };
        });
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
        const rawValue = this.normalizeConditionValueInput(item?.valueSource || 'param', item?.valueText || '');
        if (!rawValue) {
            return '';
        }
        if ((item?.valueSource || 'param') === 'param') {
            return `{params.${rawValue}}`;
        }
        if (item?.valueSource === 'field') {
            return `{input.${rawValue}}`;
        }
        if (item?.valueSource === 'alias') {
            return `{${rawValue}}`;
        }
        if (/^-?\d+(\.\d+)?$/.test(rawValue)) {
            return rawValue;
        }
        return `'${rawValue.replace(/'/g, "\\'")}'`;
    }

    getConditionValueLabel(valueSource) {
        if (valueSource === 'field') {
            return 'Form Field';
        }
        if (valueSource === 'alias') {
            return 'Alias.Field';
        }
        if (valueSource === 'literal') {
            return 'Literal Value';
        }
        return 'Parameter Name';
    }

    getConditionValuePlaceholder(valueSource) {
        if (valueSource === 'field') {
            return 'Choose a form field';
        }
        if (valueSource === 'alias') {
            return 'Choose an alias and field';
        }
        if (valueSource === 'literal') {
            return 'Example: Web';
        }
        return 'Example: email';
    }

    normalizeConditionValueInput(valueSource, rawValue) {
        const value = rawValue == null ? '' : String(rawValue).trim();
        if (!value) {
            return '';
        }
        if (valueSource === 'param') {
            const wrappedMatch = value.match(/^\{params\.([^}]+)\}$/i);
            return wrappedMatch ? wrappedMatch[1] : value.replace(/^params\./i, '');
        }
        if (valueSource === 'field') {
            const wrappedMatch = value.match(/^\{input\.([^}]+)\}$/i);
            return wrappedMatch ? wrappedMatch[1] : value.replace(/^input\./i, '');
        }
        if (valueSource === 'alias') {
            const wrappedMatch = value.match(/^\{([^}]+)\}$/);
            return wrappedMatch ? wrappedMatch[1] : value;
        }
        return value;
    }

    aliasNameFromValue(rawValue) {
        const value = this.normalizeConditionValueInput('alias', rawValue || '');
        if (!value || !value.includes('.')) {
            return '';
        }
        return value.split('.')[0];
    }

    aliasFieldFromValue(rawValue) {
        const value = this.normalizeConditionValueInput('alias', rawValue || '');
        if (!value || !value.includes('.')) {
            return '';
        }
        return value.split('.').slice(1).join('.');
    }

    composeAliasValue(aliasName, fieldName) {
        if (!aliasName || !fieldName) {
            return '';
        }
        return `${aliasName}.${fieldName}`;
    }

    getPrefillAliasFieldOptions(aliasName) {
        if (!aliasName) {
            return [{ label: 'Select field', value: '' }];
        }
        const match = (this.prefillAliasDetails || []).find((item) => item.alias === aliasName);
        return [{ label: 'Select field', value: '' }].concat(match?.fieldOptions || []);
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
