import { LightningElement, track } from 'lwc';
import getWorkspace from '@salesforce/apex/NativeFormsSubmitActionsController.getWorkspace';
import getFieldOptions from '@salesforce/apex/NativeFormsSubmitActionsController.getFieldOptions';
import addSubmitAction from '@salesforce/apex/NativeFormsSubmitActionsController.addSubmitAction';
import saveSubmitAction from '@salesforce/apex/NativeFormsSubmitActionsController.saveSubmitAction';
import deleteSubmitAction from '@salesforce/apex/NativeFormsSubmitActionsController.deleteSubmitAction';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const DESIGNER_VERSION_KEY = 'nativeforms:selectedVersionId';
const PAGE_VERSION = 'Submit v0.9';

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
    formFieldOptions = [];
    objectSearch = '';
    fieldOptions = [];
    enableProConditionLogic = false;
    enableProRepeatGroups = false;
    enableProPrefillAliasReferences = false;
    enableProAdvancedSubmitModes = false;
    repeatGroupOptions = [];
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

    get pageVersion() {
        return PAGE_VERSION;
    }

    notFoundOptions = [
        { label: 'Show error', value: 'error' },
        { label: 'Create new record', value: 'create' }
    ];

    get commandTypeOptions() {
        const options = [
            { label: 'Create record', value: 'create' }
        ];
        if (this.enableProAdvancedSubmitModes || this.draftAction?.commandType === 'updateById') {
            options.push({ label: 'Update by record Id', value: 'updateById' });
            options.push({ label: 'Find and update existing record', value: 'findAndUpdate' });
        }
        if (this.enableProRepeatGroups) {
            options.push({ label: 'Upsert repeat group', value: 'upsertMany' });
        }
        return options;
    }

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

    get isUpsertMany() {
        return this.draftAction?.commandType === 'upsertMany';
    }

    get showNotFoundChoice() {
        return this.isUpdateById || this.isFindAndUpdate;
    }

    get showRepeatGroupConfig() {
        return this.isUpsertMany;
    }

    get isRepeatRelationshipValueField() {
        return this.draftAction?.relationshipValueSource === 'field';
    }

    get isRepeatRelationshipValueAlias() {
        return this.draftAction?.relationshipValueSource === 'alias';
    }

    get selectedRelationshipAliasName() {
        return this.draftAction?.relationshipAliasName || this.aliasNameFromValue(this.draftAction?.relationshipValueText || '');
    }

    get selectedRelationshipAliasField() {
        return this.draftAction?.relationshipAliasField || this.aliasFieldFromValue(this.draftAction?.relationshipValueText || '');
    }

    get relationshipAliasFieldOptions() {
        return this.getPrefillAliasFieldOptions(this.selectedRelationshipAliasName, this.availableAliasDetails);
    }

    get conditionRows() {
        return (this.draftAction?.conditions || []).map((row, index) => ({
            ...row,
            displayIndex: index + 1,
            isValueSourceField: row.valueSource === 'field',
            isValueSourceAlias: row.valueSource === 'alias',
            selectedAliasName: row.valueSource === 'alias'
                ? (row.aliasName || this.aliasNameFromValue(row.valueText))
                : '',
            selectedAliasField: row.valueSource === 'alias'
                ? (row.aliasField || this.aliasFieldFromValue(row.valueText))
                : '',
            aliasOptions: this.getAliasOptionsForRow(row),
            aliasFieldOptions: this.getPrefillAliasFieldOptions(
                row.valueSource === 'alias'
                    ? (row.aliasName || this.aliasNameFromValue(row.valueText))
                    : '',
                this.getAvailableAliasDetailsForValue(row.valueText, row.aliasName)
            ),
            valueLabel: this.getConditionValueLabel(row.valueSource || 'param'),
            valuePlaceholder: this.getConditionValuePlaceholder(row.valueSource || 'param')
        }));
    }

    get prefillAliasOptions() {
        return this.buildAliasOptions(this.availableAliasDetails);
    }

    get availableAliasDetails() {
        return this.getAvailableAliasDetails();
    }

    buildAliasOptions(aliasDetails) {
        return [{ label: 'Select alias', value: '' }].concat(
            (aliasDetails || []).map((item) => ({
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
            options.splice(2, 0, { label: 'Result Alias Field', value: 'alias' });
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
            return 'Build conditions with Salesforce fields on the left, then choose a URL parameter, form field, result alias field, or literal value on the right.';
        }
        if (this.draftAction?.commandType === 'upsertMany') {
            return 'Use this Pro mode to save rows from one Repeat Group. Existing rows with an Id update, and rows without an Id create new records.';
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
            this.formFieldOptions = workspace.formFieldOptions || [];
            this.repeatGroupOptions = workspace.repeatGroupOptions || [];
            this.mappings = workspace.mappings || [];
            this.enableProConditionLogic = !!workspace.enableProConditionLogic;
            this.enableProRepeatGroups = !!workspace.enableProRepeatGroups;
            this.enableProPrefillAliasReferences = !!workspace.enableProPrefillAliasReferences;
            this.enableProAdvancedSubmitModes = !!workspace.enableProAdvancedSubmitModes;
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
            this.showToast('No Designer selection', 'Open TwinaForms Designer and choose a version first.', 'warning');
            return;
        }

        this.selectedActionId = null;
        this.draftAction = {};
        await this.loadWorkspace(storedVersionId);
        this.showToast('Refreshed', 'Loaded the version currently selected in TwinaForms Designer.', 'success');
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
            conditionLogic: config.conditionLogic || '',
            conditions: this.normalizeConditions(config.conditions, config.where),
            conditionExpression: config.conditionExpression || config.conditionLogic || this.defaultConditionExpression((config.conditions || []).length),
            repeatGroupKey: config.repeatGroupKey || '',
            relationshipField: this.matchOptionValue(this.fieldOptions, config.relationshipField || ''),
            relationshipValueSource: config.relationshipValueSource || 'alias',
            relationshipValueText: this.normalizeRelationshipValue(config.relationshipValueSource || 'alias', config.relationshipValueText || ''),
            relationshipAliasName: this.aliasNameFromValue(config.relationshipValueText || ''),
            relationshipAliasField: this.aliasFieldFromValue(config.relationshipValueText || ''),
            allowDelete: config.allowDelete === true
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
            config.conditions = this.sanitizeConditions();
            config.conditionLogic = this.enableProConditionLogic
                ? (this.draftAction.conditionExpression || this.defaultConditionExpression(config.conditions.length))
                : this.defaultConditionExpression(config.conditions.length);
            config.conditionExpression = config.conditionLogic;
        }
        if (this.draftAction.commandType === 'upsertMany') {
            config.repeatGroupKey = this.draftAction.repeatGroupKey || '';
            config.relationshipField = this.draftAction.relationshipField || '';
            config.relationshipValueSource = this.draftAction.relationshipValueSource || 'alias';
            const relationshipValueText = config.relationshipValueSource === 'alias'
                ? this.composeAliasValue(
                    this.draftAction.relationshipAliasName || this.aliasNameFromValue(this.draftAction.relationshipValueText || ''),
                    this.draftAction.relationshipAliasField || this.aliasFieldFromValue(this.draftAction.relationshipValueText || '')
                )
                : (this.draftAction.relationshipValueText || '');
            config.relationshipValueText = this.normalizeConditionValueInput(
                config.relationshipValueSource,
                relationshipValueText
            );
            config.allowDelete = this.draftAction.allowDelete === true;
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

    handleRepeatRelationshipChange(event) {
        const { name, value, checked, type } = event.target;
        if (name === 'relationshipAliasName' || name === 'relationshipAliasField') {
            const currentAlias = this.draftAction.relationshipAliasName || this.aliasNameFromValue(this.draftAction.relationshipValueText || '');
            const currentField = this.draftAction.relationshipAliasField || this.aliasFieldFromValue(this.draftAction.relationshipValueText || '');
            const nextAlias = name === 'relationshipAliasName' ? value : currentAlias;
            const nextField = name === 'relationshipAliasField' ? value : currentField;
            this.draftAction = {
                ...this.draftAction,
                relationshipAliasName: nextAlias,
                relationshipAliasField: nextField,
                relationshipValueText: this.composeAliasValue(nextAlias, nextField)
            };
            return;
        }
        this.draftAction = {
            ...this.draftAction,
            [name]: type === 'checkbox' ? checked : (
                name === 'relationshipValueText'
                    ? this.normalizeConditionValueInput(this.draftAction.relationshipValueSource || 'alias', value)
                    : value
            )
        };
    }

    handleRepeatRelationshipSourceChange(event) {
        const value = event.target.value;
        this.draftAction = {
            ...this.draftAction,
            relationshipValueSource: value,
            relationshipValueText: this.normalizeConditionValueInput(value, this.draftAction.relationshipValueText || ''),
            relationshipAliasName: value === 'alias'
                ? (this.draftAction.relationshipAliasName || this.aliasNameFromValue(this.draftAction.relationshipValueText || ''))
                : '',
            relationshipAliasField: value === 'alias'
                ? (this.draftAction.relationshipAliasField || this.aliasFieldFromValue(this.draftAction.relationshipValueText || ''))
                : ''
        };
    }

    handleConditionChange(event) {
        const rowIndex = Number(event.target.dataset.index);
        const { name, value } = event.target;
        const conditions = [...(this.draftAction.conditions || [])];
        if (name === 'aliasName' || name === 'aliasField') {
            const currentAlias = conditions[rowIndex]?.aliasName || this.aliasNameFromValue(conditions[rowIndex]?.valueText || '');
            const currentField = conditions[rowIndex]?.aliasField || this.aliasFieldFromValue(conditions[rowIndex]?.valueText || '');
            const nextAlias = name === 'aliasName' ? value : currentAlias;
            const nextField = name === 'aliasField' ? value : currentField;
            conditions[rowIndex] = {
                ...conditions[rowIndex],
                aliasName: nextAlias,
                aliasField: nextField,
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
            if (value !== 'alias') {
                conditions[rowIndex].aliasName = '';
                conditions[rowIndex].aliasField = '';
            } else {
                conditions[rowIndex].aliasName = conditions[rowIndex].aliasName || this.aliasNameFromValue(conditions[rowIndex].valueText || '');
                conditions[rowIndex].aliasField = conditions[rowIndex].aliasField || this.aliasFieldFromValue(conditions[rowIndex].valueText || '');
            }
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
            if (this.draftAction?.relationshipField || this.draftAction?.relationshipValueText) {
                this.draftAction = {
                    ...this.draftAction,
                    relationshipField: this.matchOptionValue(this.fieldOptions, this.draftAction.relationshipField || ''),
                    relationshipValueText: this.normalizeRelationshipValue(
                        this.draftAction.relationshipValueSource || 'alias',
                        this.draftAction.relationshipValueText || ''
                    )
                };
            }
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
                ),
                aliasName: (item.valueSource || (item.paramName ? 'param' : 'literal')) === 'alias'
                    ? this.aliasNameFromValue(item.valueText != null ? item.valueText : (item.paramName || ''))
                    : '',
                aliasField: (item.valueSource || (item.paramName ? 'param' : 'literal')) === 'alias'
                    ? this.aliasFieldFromValue(item.valueText != null ? item.valueText : (item.paramName || ''))
                    : ''
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
                valueText: this.normalizeConditionValueInput(match ? 'param' : 'literal', match ? match[3] : ''),
                aliasName: '',
                aliasField: ''
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
            valueText: '',
            aliasName: '',
            aliasField: ''
        };
    }

    sanitizeConditions() {
        return (this.draftAction.conditions || [])
            .filter((item) => item.fieldApiName && item.operator)
            .map((item) => ({
                fieldApiName: item.fieldApiName,
                operator: item.operator,
                valueSource: item.valueSource || 'param',
                valueText: (item.valueSource || 'param') === 'alias'
                    ? this.composeAliasValue(
                        item.aliasName || this.aliasNameFromValue(item.valueText || ''),
                        item.aliasField || this.aliasFieldFromValue(item.valueText || '')
                    )
                    : (item.valueText || '')
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
            return 'Result Alias Field';
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
            return 'Choose a result alias and field';
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

    normalizeRelationshipValue(valueSource, rawValue) {
        const normalized = this.normalizeConditionValueInput(valueSource, rawValue);
        if (valueSource === 'field') {
            return this.matchOptionValue(this.formFieldOptions, normalized);
        }
        return normalized;
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

    getAvailableAliasDetails() {
        const currentOrder = this.draftAction?.orderValue;
        const currentActionId = this.draftAction?.id;
        return (this.prefillAliasDetails || []).filter((item) => {
            if (item.actionScope !== 'Submit') {
                return true;
            }
            if (!currentActionId || currentOrder == null || item.orderValue == null) {
                return false;
            }
            if (item.actionId === currentActionId) {
                return false;
            }
            return item.orderValue < currentOrder;
        });
    }

    getAvailableAliasDetailsForValue(rawValue, explicitAliasName = '') {
        const aliasName = explicitAliasName || this.aliasNameFromValue(rawValue || '');
        const availableAliasDetails = this.getAvailableAliasDetails();
        const selectedAliasDetail = (this.prefillAliasDetails || []).find((item) => item.alias === aliasName);
        if (selectedAliasDetail && !availableAliasDetails.some((item) => item.alias === aliasName)) {
            return availableAliasDetails.concat([selectedAliasDetail]);
        }
        return availableAliasDetails;
    }

    getAliasOptionsForRow(row) {
        return this.buildAliasOptions(this.getAvailableAliasDetailsForValue(row?.valueText || '', row?.aliasName || ''));
    }

    getPrefillAliasFieldOptions(aliasName, aliasDetails = this.availableAliasDetails) {
        if (!aliasName) {
            return [{ label: 'Select field', value: '' }];
        }
        const match = (aliasDetails || []).find((item) => item.alias === aliasName);
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
            return window.localStorage.getItem(DESIGNER_VERSION_KEY)
                || window.sessionStorage.getItem(DESIGNER_VERSION_KEY);
        } catch (e) {
            return null;
        }
    }

    matchObjectOptionValue(rawValue) {
        if (!rawValue) {
            return rawValue;
        }
        return this.matchOptionValue(this.objectOptions, rawValue);
    }

    matchOptionValue(options, rawValue) {
        if (!rawValue) {
            return rawValue;
        }
        const exact = (options || []).find((item) => item.value === rawValue);
        if (exact) {
            return exact.value;
        }
        const loose = (options || []).find((item) => (item.value || '').toLowerCase() === String(rawValue).toLowerCase());
        return loose ? loose.value : rawValue;
    }
}
