import { LightningElement, track } from 'lwc';
import getWorkspace from '@salesforce/apex/NativeFormsBuilderController.getWorkspace';
import addElement from '@salesforce/apex/NativeFormsBuilderController.addElement';
import updateElement from '@salesforce/apex/NativeFormsBuilderController.updateElement';
import moveElement from '@salesforce/apex/NativeFormsBuilderController.moveElement';
import deleteElement from '@salesforce/apex/NativeFormsBuilderController.deleteElement';
import publishVersion from '@salesforce/apex/NativeFormsBuilderController.publishVersion';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const PALETTE = [
    {
        label: 'Input Fields',
        items: [
            { type: 'text', label: 'Text', hint: 'Single-line text input' },
            { type: 'input', label: 'Generic Input', hint: 'Flexible single input field' },
            { type: 'textarea', label: 'Textarea', hint: 'Long answer field' },
            { type: 'select', label: 'Picklist', hint: 'Dropdown choice field' },
            { type: 'checkbox', label: 'Checkbox', hint: 'Single yes/no field' },
            { type: 'radio', label: 'Radio Group', hint: 'Choice buttons' },
            { type: 'hidden', label: 'Hidden', hint: 'Runtime hidden field' }
        ]
    }
];

export default class NativeFormsBuilder extends LightningElement {
    isLoading = true;
    errorMessage = '';
    workspaceLoaded = false;
    selectedVersionId;
    selectedVersionStatus = '';
    selectedFormName = '';
    selectedFormKey = '';
    paletteSearch = '';
    selectedElementId;
    prefillAliasOptions = [];
    prefillAliasDetails = [];
    prefillFieldSearch = '';
    submitActionOptions = [];
    submitActionDetails = [];
    submitFieldSearch = '';
    publishResult = null;
    choiceOptionsText = '';

    @track elements = [];
    @track versionOptions = [];
    @track draftElement = {};
    fieldKeyTouched = false;

    connectedCallback() {
        this.loadWorkspace();
    }

    get paletteSections() {
        const search = this.paletteSearch.trim().toLowerCase();
        return PALETTE.map((section) => {
            const items = section.items.filter((item) => {
                if (!search) {
                    return true;
                }
                return item.label.toLowerCase().includes(search) || item.hint.toLowerCase().includes(search);
            });
            return {
                ...section,
                items
            };
        }).filter((section) => section.items.length);
    }

    get selectedElement() {
        return this.elements.find((item) => item.id === this.selectedElementId);
    }

    get elementTypeOptions() {
        return PALETTE.flatMap((section) => section.items).map((item) => ({
            label: item.label,
            value: item.type
        }));
    }

    get prefillFieldOptions() {
        const aliasValue = this.draftElement?.prefillAlias;
        if (!aliasValue) {
            return [{ label: 'Select Salesforce field', value: '' }];
        }
        const match = this.prefillAliasDetails.find((item) => item.alias === aliasValue);
        const fields = match?.fieldOptions || [];
        const search = (this.prefillFieldSearch || '').trim().toLowerCase();
        const filtered = !search
            ? fields
            : fields.filter((item) =>
                (item.label || '').toLowerCase().includes(search) ||
                (item.value || '').toLowerCase().includes(search)
            );
        return [{ label: 'Select Salesforce field', value: '' }].concat(filtered);
    }

    get publishResultClass() {
        return this.publishResult?.success ? 'panel-success' : 'panel-error';
    }

    get publishResultTitle() {
        return this.publishResult?.success ? 'Publish completed' : 'Publish failed';
    }

    get showsPlaceholder() {
        return ['text', 'input', 'textarea'].includes(this.draftElement?.elementType);
    }

    get isChoiceField() {
        return ['select', 'radio'].includes(this.draftElement?.elementType);
    }

    get isCheckboxField() {
        return this.draftElement?.elementType === 'checkbox';
    }

    get isHiddenField() {
        return this.draftElement?.elementType === 'hidden';
    }

    get choiceOptionsHelpText() {
        return 'Use one option per line. Format: Label|value';
    }

    get submitFieldOptions() {
        const actionKey = this.draftElement?.submitActionKey;
        if (!actionKey) {
            return [{ label: 'Select Salesforce field', value: '' }];
        }
        const match = this.submitActionDetails.find((item) => item.actionKey === actionKey);
        const fields = match?.fieldOptions || [];
        const search = (this.submitFieldSearch || '').trim().toLowerCase();
        const filtered = !search
            ? fields
            : fields.filter((item) =>
                (item.label || '').toLowerCase().includes(search) ||
                (item.value || '').toLowerCase().includes(search)
            );
        return [{ label: 'Select Salesforce field', value: '' }].concat(filtered);
    }

    async loadWorkspace(versionId = this.selectedVersionId) {
        this.isLoading = true;
        this.errorMessage = '';

        try {
            const workspace = await getWorkspace({ versionId });
            this.selectedVersionId = workspace.selectedVersionId;
            this.selectedVersionStatus = workspace.selectedVersionStatus;
            this.selectedFormName = workspace.selectedFormName;
            this.selectedFormKey = workspace.selectedFormKey;
            this.prefillAliasDetails = workspace.prefillAliases || [];
            this.submitActionDetails = workspace.submitActions || [];
            this.prefillAliasOptions = [{ label: 'Select alias', value: '' }].concat(
                this.prefillAliasDetails.map((alias) => ({ label: alias.alias, value: alias.alias }))
            );
            this.submitActionOptions = [{ label: 'Select action', value: '' }].concat(
                this.submitActionDetails.map((action) => ({
                    label: `${action.actionKey} (${action.objectApiName} - ${action.commandType})`,
                    value: action.actionKey
                }))
            );
            this.versionOptions = (workspace.versions || []).map((option) => ({
                label: `${option.label} (${option.status})`,
                value: option.value
            }));
            this.elements = workspace.elements || [];
            this.workspaceLoaded = !!workspace.selectedVersionId;

            const existingSelected = this.elements.find((item) => item.id === this.selectedElementId);
            if (existingSelected) {
                this.setDraftElement(existingSelected);
            } else if (this.elements.length) {
                this.selectedElementId = this.elements[0].id;
                this.setDraftElement(this.elements[0]);
            } else {
                this.selectedElementId = null;
                this.draftElement = {};
                this.fieldKeyTouched = false;
            }
            this.syncSelectedState();
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    decorateElement(item) {
        const config = this.parseConfig(item.configJson);
        const selected = item.id === this.selectedElementId;
        return {
            ...item,
            fieldKeyDisplay: item.fieldKey || 'No field key',
            hasFieldKey: !!item.fieldKey,
            prefillEnabled: !!config.prefillEnabled,
            prefillAlias: config.prefillAlias || '',
            prefillFieldPath: config.prefillFieldPath || '',
            submitEnabled: !!config.submitEnabled || !!config.submitActionKey || !!config.submitFieldPath,
            submitActionKey: config.submitActionKey || '',
            submitFieldPath: config.submitFieldPath || '',
            saveOnSubmit: !!config.submitEnabled || !!config.submitActionKey || !!config.submitFieldPath,
            optionsText: this.optionsToText(config.options),
            cardClass: `canvas-item${selected ? ' canvas-item--selected' : ''}`
        };
    }

    handleVersionChange(event) {
        this.selectedVersionId = event.detail.value;
        this.selectedElementId = null;
        this.draftElement = {};
        this.publishResult = null;
        this.loadWorkspace(this.selectedVersionId);
    }

    handlePaletteSearch(event) {
        this.paletteSearch = event.target.value || '';
    }

    async handleAddElement(event) {
        const type = event.currentTarget.dataset.type;
        if (!this.selectedVersionId) {
            return;
        }

        this.isLoading = true;
        try {
            const newElement = await addElement({ versionId: this.selectedVersionId, elementType: type });
            this.selectedElementId = newElement.id;
            await this.loadWorkspace(this.selectedVersionId);
            this.showToast('Element added', `${newElement.label} was added to the canvas.`, 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    handleSelectElement(event) {
        const elementId = event.currentTarget.dataset.id;
        const match = this.elements.find((item) => item.id === elementId);
        if (!match) {
            return;
        }
        this.selectedElementId = match.id;
        this.setDraftElement(match);
        this.syncSelectedState();
    }

    handleDraftChange(event) {
        const { name, type } = event.target;
        const value = type === 'checkbox' ? event.target.checked : event.target.value;
        if (name === 'fieldKey') {
            this.fieldKeyTouched = true;
        }
        if (name === 'choiceOptionsText') {
            this.choiceOptionsText = value;
            this.draftElement = {
                ...this.draftElement,
                choiceOptionsText: value
            };
            return;
        }
        if (name === 'prefillAlias') {
            this.prefillFieldSearch = '';
            this.draftElement = {
                ...this.draftElement,
                prefillAlias: value,
                prefillFieldPath: ''
            };
            return;
        }
        if (name === 'submitActionKey') {
            this.submitFieldSearch = '';
            this.draftElement = {
                ...this.draftElement,
                submitActionKey: value,
                submitFieldPath: '',
                submitEnabled: !!value
            };
            return;
        }
        this.draftElement = {
            ...this.draftElement,
            [name]: value
        };
        if (name === 'label' && !this.fieldKeyTouched && this.supportsFieldKey(this.draftElement.elementType)) {
            this.draftElement = {
                ...this.draftElement,
                fieldKey: this.slugifyFieldKey(value)
            };
        }
    }

    handlePrefillFieldSearch(event) {
        this.prefillFieldSearch = event.target.value || '';
    }

    handleSubmitFieldSearch(event) {
        this.submitFieldSearch = event.target.value || '';
    }

    async handleSaveElement() {
        this.isLoading = true;
        try {
            const configJson = this.buildConfigJson();
            await updateElement({
                inputValue: {
                    id: this.draftElement.id,
                    label: this.draftElement.label,
                    fieldKey: this.draftElement.fieldKey,
                    configJson,
                    elementType: this.draftElement.elementType
                }
            });
            await this.loadWorkspace(this.selectedVersionId);
            const refreshed = this.elements.find((item) => item.id === this.selectedElementId);
            this.setDraftElement(refreshed);
            this.syncSelectedState();
            this.showToast('Element saved', 'The selected field was updated.', 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleDeleteElement() {
        if (!this.draftElement.id) {
            return;
        }

        this.isLoading = true;
        try {
            await deleteElement({ elementId: this.draftElement.id });
            this.selectedElementId = null;
            this.draftElement = {};
            await this.loadWorkspace(this.selectedVersionId);
            this.showToast('Element deleted', 'The element was removed from the canvas.', 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleMoveElement(event) {
        event.stopPropagation();
        const elementId = event.currentTarget.dataset.id;
        const direction = event.currentTarget.dataset.direction;

        this.isLoading = true;
        try {
            await moveElement({ elementId, direction });
            this.selectedElementId = elementId;
            await this.loadWorkspace(this.selectedVersionId);
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handlePublishVersion() {
        if (!this.selectedVersionId) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        try {
            const result = await publishVersion({ versionId: this.selectedVersionId });
            this.publishResult = result;
            await this.loadWorkspace(this.selectedVersionId);
            this.showToast(
                result.success ? 'Published' : 'Publish failed',
                result.message || (result.success ? 'The form was published.' : 'Publishing failed.'),
                result.success ? 'success' : 'error'
            );
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            this.publishResult = {
                success: false,
                message: this.errorMessage
            };
        } finally {
            this.isLoading = false;
        }
    }

    syncSelectedState() {
        this.elements = this.elements.map((item) => this.decorateElement(item));
    }

    setDraftElement(element) {
        if (!element) {
            this.draftElement = {};
            this.fieldKeyTouched = false;
            return;
        }

        const config = this.parseConfig(element.configJson);
        this.draftElement = {
            ...element,
            placeholder: config.placeholder || '',
            required: !!config.required,
            defaultValue: config.defaultValue || '',
            checked: !!config.checked,
            hiddenValue: config.value == null ? '' : String(config.value),
            prefillEnabled: !!config.prefillEnabled,
            prefillAlias: config.prefillAlias || '',
            prefillFieldPath: config.prefillFieldPath || '',
            prefillReadOnly: !!config.prefillReadOnly,
            submitEnabled: !!config.submitEnabled || !!config.submitActionKey || !!config.submitFieldPath,
            submitActionKey: config.submitActionKey || '',
            submitFieldPath: config.submitFieldPath || '',
            saveOnSubmit: !!config.submitEnabled || !!config.submitActionKey || !!config.submitFieldPath,
            choiceOptionsText: this.optionsToText(config.options),
            configJson: element.configJson || '{}'
        };
        this.choiceOptionsText = this.draftElement.choiceOptionsText || '';
        this.fieldKeyTouched = false;
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
        const existing = this.parseConfig(this.draftElement.configJson);
        const merged = { ...existing };

        if (this.showsPlaceholder) {
            merged.placeholder = this.draftElement.placeholder || '';
        } else {
            delete merged.placeholder;
        }

        if (this.isChoiceField) {
            merged.options = this.parseChoiceOptions(this.choiceOptionsText);
            merged.defaultValue = this.draftElement.defaultValue || '';
        } else {
            delete merged.options;
            delete merged.defaultValue;
        }

        if (this.isCheckboxField) {
            merged.checked = !!this.draftElement.checked;
        } else {
            delete merged.checked;
        }

        if (this.isHiddenField) {
            merged.value = this.draftElement.hiddenValue || '';
        } else {
            delete merged.value;
        }

        merged.required = !!this.draftElement.required;
        merged.prefillEnabled = !!this.draftElement.prefillEnabled;
        merged.prefillAlias = this.draftElement.prefillAlias || '';
        merged.prefillFieldPath = this.draftElement.prefillFieldPath || '';
        merged.prefillReadOnly = !!this.draftElement.prefillReadOnly;
        merged.submitEnabled = !!this.draftElement.submitEnabled;
        merged.submitActionKey = this.draftElement.submitActionKey || '';
        merged.submitFieldPath = this.draftElement.submitFieldPath || '';
        merged.saveOnSubmit = !!this.draftElement.submitEnabled;
        return JSON.stringify(merged, null, 2);
    }

    optionsToText(options) {
        if (!Array.isArray(options) || !options.length) {
            return '';
        }
        return options
            .map((item) => `${item?.label ?? ''}|${item?.value ?? ''}`)
            .join('\n');
    }

    parseChoiceOptions(rawText) {
        return String(rawText || '')
            .split(/\r?\n/)
            .map((line) => line.trim())
            .filter((line) => !!line)
            .map((line) => {
                const pipeIndex = line.indexOf('|');
                if (pipeIndex < 0) {
                    return {
                        label: line,
                        value: this.slugifyOptionValue(line)
                    };
                }
                const label = line.slice(0, pipeIndex).trim();
                const value = line.slice(pipeIndex + 1).trim();
                return {
                    label: label || value,
                    value: value || this.slugifyOptionValue(label)
                };
            });
    }

    slugifyOptionValue(label) {
        const raw = String(label || '')
            .trim()
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '_')
            .replace(/^_+|_+$/g, '');
        return raw || 'option';
    }

    supportsFieldKey(elementType) {
        return !['heading', 'section', 'columns', 'image'].includes(elementType);
    }

    slugifyFieldKey(label) {
        const raw = String(label || '')
            .trim()
            .replace(/[^a-zA-Z0-9]+(.)/g, (_, chr) => (chr ? chr.toUpperCase() : ''))
            .replace(/[^a-zA-Z0-9]/g, '');
        if (!raw) {
            return '';
        }
        return raw.charAt(0).toLowerCase() + raw.slice(1);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    normalizeError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.body?.output?.errors?.length) {
            return error.body.output.errors.map((entry) => entry.message).join(', ');
        }
        if (error?.message) {
            return error.message;
        }
        return 'Something went wrong while loading the builder.';
    }
}
