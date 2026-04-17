import { LightningElement, track } from 'lwc';
import getWorkspace from '@salesforce/apex/NativeFormsDesignerController.getWorkspace';
import updateFormSettings from '@salesforce/apex/NativeFormsDesignerController.updateFormSettings';
import createFormWithDraftVersion from '@salesforce/apex/NativeFormsDesignerController.createFormWithDraftVersion';
import getObjectOptions from '@salesforce/apex/NativeFormsDesignerController.getObjectOptions';
import getPicklistFieldOptions from '@salesforce/apex/NativeFormsDesignerController.getPicklistFieldOptions';
import getPicklistValueOptions from '@salesforce/apex/NativeFormsDesignerController.getPicklistValueOptions';
import uploadImageFile from '@salesforce/apex/NativeFormsDesignerController.uploadImageFile';
import addElement from '@salesforce/apex/NativeFormsDesignerController.addElement';
import deleteDesignerElement from '@salesforce/apex/NativeFormsDesignerController.deleteElement';
import reorderElement from '@salesforce/apex/NativeFormsDesignerController.reorderElement';
import placeElementInSection from '@salesforce/apex/NativeFormsDesignerController.placeElementInSection';
import insertElementAfter from '@salesforce/apex/NativeFormsDesignerController.insertElementAfter';
import updateSectionColumns from '@salesforce/apex/NativeFormsDesignerController.updateSectionColumns';
import updateElement from '@salesforce/apex/NativeFormsBuilderController.updateElement';
import publishVersion from '@salesforce/apex/NativeFormsBuilderController.publishVersion';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const DESIGNER_VERSION_KEY = 'nativeforms:selectedVersionId';

export default class NativeFormsDesigner extends LightningElement {
    designerVersion = 'v9.4';
    isLoading = true;
    errorMessage = '';
    selectedFormId;
    selectedVersionId;
    selectedThemeId;
    selectedElementId;
    selectedFormName = '';
    selectedFormKey = '';
    selectedFormDescription = '';
    selectedFormCaptchaEnabled = false;
    captchaKeysConfigured = false;
    selectedVersionName = '';
    selectedVersionStatus = '';
    selectedPublishedUrl = '';
    selectedTheme = null;
    draggedElementId = null;
    dragTargetIndex = null;
    dragSectionTarget = null;
    autoSaveTimeoutId = null;
    publishResult = null;
    showNewFormModal = false;
    newFormDescription = '';
    isCreatingForm = false;

    @track formOptions = [];
    @track versionOptions = [];
    @track themeOptions = [];
    @track elements = [];
    @track canvasElements = [];
    @track salesforceObjectOptions = [];
    @track picklistFieldOptions = [];
    @track prefillAliasDetails = [];
    @track submitActionDetails = [];
    enableProRepeatGroups = false;

    inputFieldType = 'text';
    displayElementType = 'section';
    editorLabel = '';
    editorElementType = '';
    editorLabelPosition = 'above';
    editorPlaceholder = '';
    editorDisplayText = '';
    editorImageUrl = '';
    editorImageAlt = '';
    editorImageFit = 'original';
    editorImageWidthPercent = '100';
    editorShowTitle = true;
    editorBoxed = true;
    editorColumns = '2';
    editorRepeatSourceAlias = '';
    editorAllowAddRows = true;
    editorAllowDeleteRows = true;
    editorShowLabelsOnEachRow = true;
    editorPicklistObject = '';
    editorPicklistField = '';
    editorRadioOptionsText = '';
    editorLabelBold = false;
    editorFieldBehavior = 'editable';
    editorConditionalEnabled = false;
    editorConditionalFieldKey = '';
    editorConditionalOperator = 'equals';
    editorConditionalValue = '';
    editorMinValue = '';
    editorMaxValue = '';
    editorDateDisplayFormat = 'us';
    editorDateGmtOffset = '+00:00';
    editorPastYears = '';
    editorPastMonths = '';
    editorFutureYears = '';
    editorFutureMonths = '';
    editorTextRule = 'none';
    editorPrefillEnabled = false;
    editorPrefillAlias = '';
    editorPrefillFieldPath = '';
    editorSubmitEnabled = false;
    editorSubmitActionKey = '';
    editorSubmitFieldPath = '';

    inputFieldOptions = [
        { label: 'Text', value: 'text' },
        { label: 'Number', value: 'number' },
        { label: 'Date', value: 'date' },
        { label: 'Email', value: 'email' },
        { label: 'Phone', value: 'tel' },
        { label: 'Picklist', value: 'select' },
        { label: 'Radio groups', value: 'radio' },
        { label: 'Checkbox', value: 'checkbox' },
        { label: 'Text Area', value: 'textarea' },
        { label: 'URL', value: 'url' }
    ];

    displayElementOptions = [
        { label: 'Section', value: 'section' },
        { label: 'Group', value: 'group' },
        { label: 'Repeat Group', value: 'repeatGroup' },
        { label: 'Display Text', value: 'heading' },
        { label: 'Image', value: 'image' }
    ];

    editorElementTypeOptions = [
        ...this.inputFieldOptions,
        ...this.displayElementOptions
    ];

    labelPositionOptions = [
        { label: 'Above', value: 'above' },
        { label: 'Left', value: 'left' },
        { label: 'Right', value: 'right' },
        { label: 'None', value: 'hidden' }
    ];

    imageFitOptions = [
        { label: 'Original Size', value: 'original' },
        { label: 'Left', value: 'left' },
        { label: 'Center', value: 'center' },
        { label: 'Right', value: 'right' },
        { label: 'Stretch', value: 'stretch' }
    ];

    fieldBehaviorOptions = [
        { label: 'Editable', value: 'editable' },
        { label: 'Locked', value: 'readonlyWhenPrefilled' },
        { label: 'Hidden', value: 'hidden' }
    ];

    conditionalOperatorOptions = [
        { label: 'Equals', value: 'equals' },
        { label: 'Not Equals', value: 'notEquals' },
        { label: 'Is True', value: 'isTrue' },
        { label: 'Is False', value: 'isFalse' },
        { label: 'Is Blank', value: 'isBlank' },
        { label: 'Is Not Blank', value: 'isNotBlank' }
    ];

    textRuleOptions = [
        { label: 'None', value: 'none' },
        { label: 'Alphanumeric Only', value: 'alphanumeric' },
        { label: 'Letters Only', value: 'letters' },
        { label: 'Numbers Only', value: 'numbers' }
    ];

    dateDisplayFormatOptions = [
        { label: 'US (MM/DD/YYYY)', value: 'us' },
        { label: 'EU (DD/MM/YYYY)', value: 'eu' }
    ];

    dateGmtOffsetOptions = [
        { label: 'UTC -12:00', value: '-12:00' },
        { label: 'UTC -11:00', value: '-11:00' },
        { label: 'UTC -10:00', value: '-10:00' },
        { label: 'UTC -09:00', value: '-09:00' },
        { label: 'UTC -08:00', value: '-08:00' },
        { label: 'UTC -07:00', value: '-07:00' },
        { label: 'UTC -06:00', value: '-06:00' },
        { label: 'UTC -05:00', value: '-05:00' },
        { label: 'UTC -04:00', value: '-04:00' },
        { label: 'UTC -03:00', value: '-03:00' },
        { label: 'UTC -02:00', value: '-02:00' },
        { label: 'UTC -01:00', value: '-01:00' },
        { label: 'UTC +00:00', value: '+00:00' },
        { label: 'UTC +01:00', value: '+01:00' },
        { label: 'UTC +02:00', value: '+02:00' },
        { label: 'UTC +03:00', value: '+03:00' },
        { label: 'UTC +04:00', value: '+04:00' },
        { label: 'UTC +05:00', value: '+05:00' },
        { label: 'UTC +05:30', value: '+05:30' },
        { label: 'UTC +06:00', value: '+06:00' },
        { label: 'UTC +07:00', value: '+07:00' },
        { label: 'UTC +08:00', value: '+08:00' },
        { label: 'UTC +09:00', value: '+09:00' },
        { label: 'UTC +10:00', value: '+10:00' },
        { label: 'UTC +11:00', value: '+11:00' },
        { label: 'UTC +12:00', value: '+12:00' },
        { label: 'UTC +13:00', value: '+13:00' },
        { label: 'UTC +14:00', value: '+14:00' }
    ];

    sectionColumnOptions = [
        { label: '1', value: '1' },
        { label: '2', value: '2' },
        { label: '3', value: '3' },
        { label: '4', value: '4' }
    ];

    connectedCallback() {
        this.selectedVersionId = this.loadStoredVersionId();
        this.loadSalesforceObjectOptions();
        this.loadWorkspace(this.selectedFormId, this.selectedVersionId);
    }

    get selectedElement() {
        return this.elements.find((item) => item.id === this.selectedElementId);
    }

    get selectedElementFieldKey() {
        return this.selectedElement?.fieldKey || '';
    }

    get selectedElementIndex() {
        return this.selectedElement?.elementIndex ?? '';
    }

    get canvasTitle() {
        return this.selectedFormDescription || this.selectedFormName;
    }

    get formSettingsButtonClass() {
        return `designer-form-settings-button${this.selectedElement ? '' : ' designer-form-settings-button--active'}`;
    }

    get showFormSettingsPanel() {
        return !this.selectedElement;
    }

    get rightPaneTitle() {
        return this.showFormSettingsPanel ? 'Form Settings' : 'Element Properties';
    }

    get canvasSummaryLine() {
        const parts = [];
        if (this.selectedFormKey) {
            parts.push(this.selectedFormKey);
        }
        if (this.selectedVersionName) {
            parts.push(`Version ${this.selectedVersionName}`);
        }
        return parts.join(' - ');
    }

    get designerCanvasThemeStyle() {
        const theme = this.selectedTheme || {};
        const titleFont = this.safeFont(theme.titleFont, 'Roboto Slab');
        const mainFont = this.safeFont(theme.mainFont, 'Inter');
        const sectionFont = this.safeFont(theme.sectionTitleFont, titleFont);
        const buttonFont = this.safeFont(theme.buttonFont, mainFont);
        const formWidth = this.themeFormMaxWidth(theme.formWidth);
        return [
            `--nf-theme-page-bg:${this.safeValue(theme.backgroundColor, '#f3f7fb')}`,
            `--nf-theme-form-bg:${this.safeValue(theme.formBackgroundColor, '#ffffff')}`,
            `--nf-theme-form-border:${this.safeValue(theme.formBorderColor, '#dbe5ef')}`,
            `--nf-theme-form-max-width:${formWidth}`,
            `--nf-theme-title-font:${titleFont}`,
            `--nf-theme-title-size:${this.safeNumber(theme.titleFontSizePx, 17.6)}px`,
            `--nf-theme-title-color:${this.safeValue(theme.titleTextColor, '#17324d')}`,
            `--nf-theme-section-font:${sectionFont}`,
            `--nf-theme-section-size:${this.safeNumber(theme.sectionTitleFontSizePx, 16)}px`,
            `--nf-theme-section-color:${this.safeValue(theme.sectionTitleTextColor, '#17324d')}`,
            `--nf-theme-main-font:${mainFont}`,
            `--nf-theme-main-size:${this.safeNumber(theme.mainTextSizePx, 14.4)}px`,
            `--nf-theme-main-color:${this.safeValue(theme.mainTextColor, '#17324d')}`,
            `--nf-theme-hint-color:${this.safeValue(theme.hintTextColor, '#5f6f89')}`,
            `--nf-theme-input-bg:${this.safeValue(theme.inputBackgroundColor, '#ffffff')}`,
            `--nf-theme-input-border:${this.safeValue(theme.inputBorderColor, '#c9d3df')}`,
            `--nf-theme-input-radius:${this.safeNumber(theme.inputBorderRadiusPx, 14)}px`,
            `--nf-theme-button-font:${buttonFont}`,
            `--nf-theme-button-size:${this.safeNumber(theme.buttonFontSizePx, 14)}px`,
            `--nf-theme-button-text:${this.safeValue(theme.buttonTextColor, '#ffffff')}`,
            `--nf-theme-button-bg:${this.safeValue(theme.buttonBackgroundColor, '#0f6cbd')}`
        ].join(';');
    }

    get themeLogoUrl() {
        return this.selectedTheme?.logoUrl || '';
    }

    get showThemeLogo() {
        return Boolean(this.themeLogoUrl);
    }

    get themeLogoWrapClass() {
        const position = (this.selectedTheme?.logoPosition || 'left').toLowerCase();
        return `designer-logo-wrap designer-logo-wrap--${position}`;
    }

    get themeLogoStyle() {
        const size = this.safeNumber(this.selectedTheme?.logoSizePx, 120);
        return `max-height:${size}px;`;
    }

    get publishResultClass() {
        return this.publishResult?.success ? 'panel-success' : 'panel-error';
    }

    get publishResultTitle() {
        return this.publishResult?.success ? 'Publish completed' : 'Publish failed';
    }

    get publishResultInlineClass() {
        return this.publishResult?.success ? 'designer-topbar__result designer-topbar__result--success' : 'designer-topbar__result designer-topbar__result--error';
    }

    get publishResultInlineMessage() {
        if (!this.publishResult) {
            return '';
        }
        return this.publishResult.success
            ? 'Published successfully.'
            : (this.publishResult.message || 'Publish failed.');
    }

    get publishResultLinkLabel() {
        return this.publishResult?.success ? 'Open published form' : 'Open form';
    }

    get newFormCreateDisabled() {
        return this.isCreatingForm || !String(this.newFormDescription || '').trim();
    }

    get isSelectedVersionReadOnly() {
        return this.selectedVersionStatus === 'Published';
    }

    get readOnlyMessage() {
        return 'This published version is read-only. Publish creates a new draft copy for continued editing.';
    }

    get hasSelectedPublishedUrl() {
        return !!this.selectedPublishedUrl;
    }

    get selectedElementIsSection() {
        return this.selectedElement?.elementType === 'section';
    }

    get selectedElementIsGroup() {
        return this.selectedElement?.elementType === 'group';
    }

    get selectedElementIsRepeatGroup() {
        return this.selectedElement?.elementType === 'repeatGroup';
    }

    get selectedElementIsContainer() {
        return this.selectedElementIsSection || this.selectedElementIsGroup || this.selectedElementIsRepeatGroup;
    }

    get availableDisplayElementOptions() {
        return this.enableProRepeatGroups
            ? this.displayElementOptions
            : this.displayElementOptions.filter((option) => option.value !== 'repeatGroup');
    }

    get selectedElementSupportsLabelPosition() {
        return ['text', 'textarea', 'number', 'date', 'email', 'tel', 'url', 'checkbox', 'select', 'radio'].includes(this.editorElementType);
    }

    get selectedElementSupportsDefaultValue() {
        return ['text', 'textarea', 'number', 'date', 'email', 'tel', 'url', 'checkbox', 'select', 'radio'].includes(this.editorElementType);
    }

    get selectedElementSupportsBoldLabel() {
        return ['text', 'textarea', 'number', 'date', 'email', 'tel', 'url', 'checkbox', 'select', 'radio'].includes(this.editorElementType);
    }

    get selectedElementSupportsFieldBehavior() {
        return ['text', 'textarea', 'number', 'date', 'email', 'tel', 'url', 'checkbox', 'select', 'radio', 'group'].includes(this.editorElementType);
    }

    get selectedElementSupportsDisplayFieldBehavior() {
        return this.editorElementType === 'group';
    }

    get selectedElementSupportsBehaviorFieldBehavior() {
        return this.selectedElementSupportsFieldBehavior && !this.selectedElementSupportsDisplayFieldBehavior;
    }

    get selectedElementIsDisplayText() {
        return this.editorElementType === 'heading';
    }

    get selectedElementIsImage() {
        return this.editorElementType === 'image';
    }

    get selectedElementIsPicklist() {
        return this.editorElementType === 'select';
    }

    get selectedElementIsRadio() {
        return this.editorElementType === 'radio';
    }

    get selectedElementSupportsConditional() {
        return !['section', 'repeatGroup'].includes(this.editorElementType);
    }

    get selectedElementSupportsSalesforceMapping() {
        return ['text', 'textarea', 'number', 'date', 'email', 'tel', 'url', 'checkbox', 'select', 'radio'].includes(this.editorElementType);
    }

    get selectedRepeatGroupParent() {
        const selected = this.selectedElement;
        if (!selected?.parentElementId) {
            return null;
        }
        return this.elements.find((item) => item.elementId === selected.parentElementId && item.elementType === 'repeatGroup') || null;
    }

    get selectedElementIsInsideRepeatGroup() {
        return !!this.selectedRepeatGroupParent;
    }

    get selectedRepeatGroupHint() {
        const parent = this.selectedRepeatGroupParent;
        if (!parent) {
            return '';
        }
        const parentConfig = this.parseConfig(parent.configJson);
        const aliasText = parentConfig.repeatSourceAlias
            ? `Current repeat source: ${parentConfig.repeatSourceAlias}.`
            : 'No repeat source is set on the parent group yet.';
        return `This field belongs to repeat group "${parent.label}". ${aliasText}`;
    }

    get selectedElementSupportsRangeValidation() {
        return ['number', 'date'].includes(this.editorElementType);
    }

    get selectedElementIsNumber() {
        return this.editorElementType === 'number';
    }

    get selectedElementIsDate() {
        return this.editorElementType === 'date';
    }

    get selectedDateFormatHelpText() {
        return this.editorDateDisplayFormat === 'eu'
            ? 'Users will enter dates as DD/MM/YYYY. TwinaForms will normalize the submitted value before Salesforce submit.'
            : 'Users will enter dates as MM/DD/YYYY. TwinaForms will normalize the submitted value before Salesforce submit.';
    }

    get selectedElementSupportsTextValidation() {
        return ['text', 'textarea', 'email', 'tel', 'url'].includes(this.editorElementType);
    }

    get selectedElementUsesConditionalValue() {
        return !['isTrue', 'isFalse', 'isBlank', 'isNotBlank'].includes(this.editorConditionalOperator);
    }

    get fieldBehaviorRadioOptions() {
        return this.fieldBehaviorOptions.map((option) => ({
            ...option,
            checked: option.value === this.editorFieldBehavior
        }));
    }

    get labelPositionRadioOptions() {
        return this.labelPositionOptions.map((option) => ({
            ...option,
            checked: option.value === this.editorLabelPosition
        }));
    }

    get conditionalFieldOptions() {
        return this.elements
            .filter((item) =>
                item.id !== this.selectedElementId &&
                item.fieldKey &&
                ['text', 'textarea', 'number', 'date', 'email', 'tel', 'url', 'checkbox', 'select', 'radio'].includes(item.elementType)
            )
            .map((item) => ({
                label: `${item.label} (${item.fieldKey})`,
                value: item.fieldKey
            }));
    }

    get prefillAliasOptions() {
        return [{ label: 'Select alias', value: '' }].concat(
            (this.prefillAliasDetails || []).map((alias) => ({
                label: `${alias.alias} (${alias.actionKey || alias.objectApiName})`,
                value: alias.alias
            }))
        );
    }

    get prefillFieldOptions() {
        const aliasValue = this.editorPrefillAlias;
        if (!aliasValue) {
            return [{ label: 'Select Salesforce field', value: '' }];
        }
        const match = this.prefillAliasDetails.find((item) => item.alias === aliasValue);
        return [{ label: 'Select Salesforce field', value: '' }].concat(match?.fieldOptions || []);
    }

    get submitActionOptions() {
        return [{ label: 'Select action', value: '' }].concat(
            (this.submitActionDetails || []).map((action) => ({
                label: `${action.storeResultAs || action.actionKey} (${action.actionKey})`,
                value: action.actionKey
            }))
        );
    }

    get submitFieldOptions() {
        const actionKey = this.editorSubmitActionKey;
        if (!actionKey) {
            return [{ label: 'Select Salesforce field', value: '' }];
        }
        const match = this.submitActionDetails.find((item) => item.actionKey === actionKey);
        return [{ label: 'Select Salesforce field', value: '' }].concat(match?.fieldOptions || []);
    }

    async loadWorkspace(formId = this.selectedFormId, versionId = this.selectedVersionId, silent = false) {
        if (!silent) {
            this.isLoading = true;
        }
        this.errorMessage = '';

        try {
            const workspace = await getWorkspace({ formId, versionId });
            this.selectedFormId = workspace.selectedFormId;
            this.selectedVersionId = workspace.selectedVersionId;
            this.selectedThemeId = workspace.selectedThemeId || '';
            this.selectedTheme = workspace.selectedTheme || null;
            this.selectedFormName = workspace.selectedFormName;
            this.selectedFormKey = workspace.selectedFormKey;
            this.selectedFormDescription = workspace.selectedFormDescription;
            this.selectedFormCaptchaEnabled = !!workspace.selectedFormCaptchaEnabled;
            this.captchaKeysConfigured = !!workspace.captchaKeysConfigured;
            this.selectedVersionName = workspace.selectedVersionName;
            this.selectedVersionStatus = workspace.selectedVersionStatus;
            this.selectedPublishedUrl = workspace.selectedPublishedUrl || '';
            this.prefillAliasDetails = workspace.prefillAliases || [];
            this.submitActionDetails = workspace.submitActions || [];
            this.enableProRepeatGroups = !!workspace.enableProRepeatGroups;
            if (this.selectedVersionId) {
                this.storeSelectedVersion(this.selectedVersionId);
            } else {
                this.clearStoredVersion();
            }
            this.formOptions = (workspace.forms || []).map((option) => ({
                label: option.label,
                value: option.value
            }));
            this.versionOptions = (workspace.versions || []).map((option) => ({
                label: option.isPublished ? `${option.label} (Published)` : `${option.label} (${option.status})`,
                value: option.value
            }));
            this.themeOptions = [{ label: 'Select Theme', value: '' }].concat(
                (workspace.themes || []).map((option) => ({
                    label: option.label,
                    value: option.value
                }))
            );
            this.elements = (workspace.elements || []).map((item) => this.decorateBaseElement(item));
            this.canvasElements = this.buildCanvasElements(this.elements);
            if (!this.elements.some((item) => item.id === this.selectedElementId)) {
                this.selectedElementId = null;
                this.syncSelectedState();
            } else {
                this.syncEditorState();
            }
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            if (!silent) {
                this.isLoading = false;
            }
        }
    }

    async loadSalesforceObjectOptions() {
        try {
            const options = await getObjectOptions();
            this.salesforceObjectOptions = (options || []).map((option) => ({
                label: option.label,
                value: option.value
            }));
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        }
    }

    async loadPicklistFieldOptions(objectApiName, preferredFieldName) {
        if (!objectApiName) {
            this.picklistFieldOptions = [];
            return;
        }
        try {
            const options = await getPicklistFieldOptions({ objectApiName });
            this.picklistFieldOptions = (options || []).map((option) => ({
                label: option.label,
                value: option.value
            }));
            if (preferredFieldName && this.picklistFieldOptions.some((option) => option.value === preferredFieldName)) {
                this.editorPicklistField = preferredFieldName;
            }
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        }
    }

    async loadPicklistValuesIntoEditor(objectApiName, fieldApiName) {
        if (!objectApiName || !fieldApiName) {
            return;
        }
        try {
            const options = await getPicklistValueOptions({ objectApiName, fieldApiName });
            this.elements = this.elements.map((item) => {
                if (item.id !== this.selectedElementId) {
                    return item;
                }
                const config = this.parseConfig(item.configJson);
                config.sourceObjectApiName = objectApiName;
                config.sourcePicklistFieldApiName = fieldApiName;
                config.options = (options || []).map((option) => ({
                    label: option.label,
                    value: option.value
                }));
                return this.decorateBaseElement({
                    ...item,
                    configJson: JSON.stringify(config)
                });
            });
            this.syncSelectedState();
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        }
    }

    decorateBaseElement(item) {
        return this.decorateRenderableElement(item, false);
    }

    get canvasRows() {
        const rows = [];
        for (let index = 0; index <= this.canvasElements.length; index += 1) {
            rows.push({
                dropKey: `drop-${index}`,
                index,
                dropClass: `designer-dropzone${this.dragTargetIndex === index ? ' designer-dropzone--active' : ''}`,
                item: index < this.canvasElements.length ? this.canvasElements[index] : null,
                hasItem: index < this.canvasElements.length
            });
        }
        return rows;
    }

    buildCanvasElements(elements) {
        const containerElementIds = new Set();
        elements.forEach((item) => {
            if (item.elementId && ['section', 'group', 'repeatGroup'].includes(item.elementType)) {
                containerElementIds.add(item.elementId);
            }
        });

        const byParent = new Map();
        const topLevel = [];

        elements.forEach((item) => {
            const hasValidParent = item.parentElementId && item.parentElementId !== item.elementId && containerElementIds.has(item.parentElementId);
            if (hasValidParent) {
                const siblings = byParent.get(item.parentElementId) || [];
                siblings.push(item);
                byParent.set(item.parentElementId, siblings);
            } else if (!item.parentElementId) {
                topLevel.push(item);
            }
        });

        const sortByOrder = (a, b) => (a.orderValue || 0) - (b.orderValue || 0);
        topLevel.sort(sortByOrder);
        byParent.forEach((items) => items.sort(sortByOrder));

        return topLevel.map((item) => this.decorateCanvasElement(item, byParent));
    }

    decorateRenderableElement(item, isChild) {
        const effectiveType = item.elementType === 'hidden' ? 'text' : item.elementType;
        const normalized = {
            ...item,
            effectiveElementType: effectiveType,
            sectionColumns: this.sectionColumns(item.configJson),
            isSection: item.elementType === 'section',
            isGroup: item.elementType === 'group',
            isSectionLike: item.elementType === 'section' || item.elementType === 'group',
            isRepeatGroup: item.elementType === 'repeatGroup',
            isCheckbox: effectiveType === 'checkbox',
            isTextInput: effectiveType === 'text',
            isTextarea: effectiveType === 'textarea',
            isNumber: effectiveType === 'number',
            isDate: effectiveType === 'date',
            isEmail: effectiveType === 'email',
            isPhone: effectiveType === 'tel',
            isUrl: effectiveType === 'url',
            isSelect: effectiveType === 'select',
            isRadio: effectiveType === 'radio',
            isHidden: item.elementType === 'hidden',
            isHeading: effectiveType === 'heading',
            isImage: effectiveType === 'image',
            labelPosition: this.labelPosition(item),
            fieldBehavior: this.fieldBehavior(item),
            previewText: this.previewText(item),
            previewHtml: this.previewHtml(item),
            previewPlaceholder: this.previewPlaceholder(item),
            previewChecked: this.previewChecked(item),
            previewOptions: this.previewOptions(item),
            previewImageUrl: this.previewImageUrl(item),
            previewImageAlt: this.previewImageAlt(item),
            previewImageFit: this.previewImageFit(item),
            previewImageWidthPercent: this.previewImageWidthPercent(item),
            previewInputType: this.previewInputType(item),
            validationPattern: this.validationPattern(item),
            conditionalSummary: this.conditionalSummary(item),
            showTitle: this.sectionShowTitle(item),
            showSectionBox: this.sectionBoxed(item),
            repeatSourceAlias: this.repeatSourceAlias(item),
            allowAddRows: this.repeatAllowAddRows(item),
            allowDeleteRows: this.repeatAllowDeleteRows(item)
        };
        const selected = normalized.id === this.selectedElementId;
        return {
            ...normalized,
            isTopLevelDraggable: !isChild,
            isChildDraggable: isChild,
            showHiddenBadge: normalized.isHidden || normalized.fieldBehavior === 'hidden',
            showExpandedPicklist: normalized.isSelect && selected,
            showLabel: normalized.labelPosition !== 'hidden',
            showConditionalBadge: !!normalized.conditionalSummary,
            labelClass: `preview-field__label${this.labelBold(item) ? ' preview-field__label--bold' : ''}`,
            cardStyle: this.elementCardStyle(normalized),
            cardClass: `designer-node ${!(normalized.isSectionLike || normalized.isRepeatGroup) ? 'designer-node--field ' : ''}${isChild ? 'designer-node--child ' : ''}designer-node--${normalized.elementType}${(normalized.isSectionLike || normalized.isRepeatGroup) && !normalized.showSectionBox ? ' designer-node--section-unboxed' : ''}${selected ? ' designer-node--selected' : ''}`,
            fieldPreviewClass: `preview-field preview-field--${normalized.labelPosition || 'above'}`,
            previewTextClass: `preview-heading${selected ? ' preview-heading--selected' : ''}`,
            imageFrameClass: `preview-image__frame preview-image__frame--${normalized.previewImageFit || 'original'}`,
            imageClass: `preview-image__img preview-image__img--${normalized.previewImageFit || 'original'}`,
            imageStyle: `width:${normalized.previewImageWidthPercent || 100}%;`
        };
    }

    decorateCanvasElement(item, byParent) {
        const base = this.decorateRenderableElement(item, false);

        if (!base.isSectionLike && !base.isRepeatGroup) {
            return base;
        }

        const sectionChildren = byParent.get(base.elementId) || [];
        const slotCount = base.sectionColumns;
        const sectionColumnClass = this.sectionColumnClass(base.configJson);
        const sectionSlots = Array.from({ length: slotCount }, (_, index) => {
            const columnValue = index + 1;
            const targetKey = `${base.id}:${columnValue}`;
            const childItems = sectionChildren
                .filter((child) => Number(child.sectionColumn || 1) === columnValue)
                .map((child) => this.decorateRenderableElement(child, true));

            return {
                key: `slot-${base.id}-${columnValue}`,
                label: String(columnValue),
                emptyLabel: String(columnValue),
                columnValue,
                sectionId: base.id,
                dropClass: `preview-column-slot${!base.showSectionBox ? ' preview-column-slot--unboxed' : ''}${this.dragSectionTarget === targetKey ? ' preview-column-slot--active' : ''}`,
                childItems,
                hasChildren: childItems.length > 0
            };
        });

        return {
            ...base,
            sectionColumnClass,
            sectionSlots
        };
    }

    sectionColumns(configJson) {
        const config = this.parseConfig(configJson);
        const value = Number(config.columns);
        return Number.isFinite(value) && value >= 1 && value <= 4 ? value : 2;
    }

    sectionShowTitle(item) {
        const config = this.parseConfig(item.configJson);
        return config.showTitle !== false;
    }

    sectionBoxed(item) {
        const config = this.parseConfig(item.configJson);
        return config.boxed !== false;
    }

    repeatSourceAlias(item) {
        const config = this.parseConfig(item.configJson);
        return config.repeatSourceAlias || '';
    }

    repeatAllowAddRows(item) {
        const config = this.parseConfig(item.configJson);
        return config.allowAddRows !== false;
    }

    repeatAllowDeleteRows(item) {
        const config = this.parseConfig(item.configJson);
        return config.allowDeleteRows !== false;
    }

    labelPosition(item) {
        const config = this.parseConfig(item.configJson);
        if (config.labelPosition) {
            if (config.labelPosition === 'inline') {
                return 'above';
            }
            return config.labelPosition;
        }
        return 'above';
    }

    fieldBehavior(item) {
        const config = this.parseConfig(item.configJson);
        return config.fieldBehavior || (item.elementType === 'hidden' ? 'hidden' : 'editable');
    }

    previewText(item) {
        const config = this.parseConfig(item.configJson);
        return config.text || item.label;
    }

    previewHtml(item) {
        const config = this.parseConfig(item.configJson);
        return config.html || config.text || '<p>Display text</p>';
    }

    previewPlaceholder(item) {
        const config = this.parseConfig(item.configJson);
        if (item.elementType === 'date') {
            return config.dateDisplayFormat === 'eu' ? 'dd/mm/yyyy' : 'mm/dd/yyyy';
        }
        return config.defaultValue || config.placeholder || '';
    }

    previewChecked(item) {
        const config = this.parseConfig(item.configJson);
        if (config.checked === true || config.checked === 'true') {
            return true;
        }
        const defaultValue = String(config.defaultValue || '').toLowerCase();
        return ['true', '1', 'yes', 'checked'].includes(defaultValue);
    }

    previewOptions(item) {
        const config = this.parseConfig(item.configJson);
        const defaultValue = config.defaultValue;
        return Array.isArray(config.options)
            ? config.options.map((option) => ({
                ...option,
                checked: option?.value === defaultValue
            }))
            : [];
    }

    previewImageUrl(item) {
        const config = this.parseConfig(item.configJson);
        return config.imageUrl || '';
    }

    previewImageAlt(item) {
        const config = this.parseConfig(item.configJson);
        return config.altText || item.label || 'Image preview';
    }

    previewImageFit(item) {
        const config = this.parseConfig(item.configJson);
        return config.imageFit || 'original';
    }

    previewImageWidthPercent(item) {
        const config = this.parseConfig(item.configJson);
        const value = Number(config.imageWidthPercent);
        return Number.isFinite(value) && value > 0 ? Math.min(value, 100) : 100;
    }

    previewInputType(item) {
        const effectiveType = item.elementType === 'hidden' ? 'text' : item.elementType;
        if (effectiveType === 'date') {
            return 'text';
        }
        return ['text', 'number', 'date', 'email', 'tel', 'url'].includes(effectiveType) ? effectiveType : 'text';
    }

    validationPattern(item) {
        const config = this.parseConfig(item.configJson);
        if (config.textRule === 'alphanumeric') {
            return 'A-Za-z0-9 only';
        }
        if (config.textRule === 'letters') {
            return 'Letters only';
        }
        if (config.textRule === 'numbers') {
            return 'Numbers only';
        }
        if (item.elementType === 'date') {
            const parts = [];
            if (config.minValue !== null && config.minValue !== undefined && String(config.minValue) !== '') {
                parts.push(`From ${config.minValue}`);
            }
            if (config.maxValue !== null && config.maxValue !== undefined && String(config.maxValue) !== '') {
                parts.push(`To ${config.maxValue}`);
            }
            return parts.join(' • ');
        }
        const parts = [];
        if (config.minValue !== null && config.minValue !== undefined && String(config.minValue) !== '') {
            parts.push(`Min ${config.minValue}`);
        }
        if (config.maxValue !== null && config.maxValue !== undefined && String(config.maxValue) !== '') {
            parts.push(`Max ${config.maxValue}`);
        }
        return parts.join(' • ');
    }

    conditionalSummary(item) {
        const config = this.parseConfig(item.configJson);
        if (!config.conditionalEnabled || !config.conditionalFieldKey) {
            return '';
        }
        let summary = `Show when ${config.conditionalFieldKey} ${config.conditionalOperator || 'equals'}`;
        if (!['isTrue', 'isFalse', 'isBlank', 'isNotBlank'].includes(config.conditionalOperator) && config.conditionalValue) {
            summary += ` ${config.conditionalValue}`;
        }
        return summary;
    }

    labelBold(item) {
        const config = this.parseConfig(item.configJson);
        return config.labelBold === true;
    }

    elementCardStyle(item) {
        if (item.elementType === 'section' && !this.sectionBoxed(item)) {
            return 'border: 0; background: transparent; box-shadow: none; padding-left: 0; padding-right: 0;';
        }
        return '';
    }

    sectionColumnClass(configJson) {
        return `preview-section__grid preview-section__grid--${this.sectionColumns(configJson)}`;
    }

    handleFormChange(event) {
        this.selectedFormId = event.detail.value;
        this.selectedVersionId = null;
        this.selectedElementId = null;
        this.loadWorkspace(this.selectedFormId, null);
    }

    handleVersionChange(event) {
        this.selectedVersionId = event.detail.value;
        this.storeSelectedVersion(this.selectedVersionId);
        this.selectedElementId = null;
        this.publishResult = null;
        this.loadWorkspace(this.selectedFormId, this.selectedVersionId);
    }

    handleOpenNewFormModal() {
        this.newFormDescription = '';
        this.showNewFormModal = true;
    }

    handleCloseNewFormModal() {
        if (this.isCreatingForm) {
            return;
        }
        this.showNewFormModal = false;
        this.newFormDescription = '';
    }

    handleNewFormDescriptionChange(event) {
        this.newFormDescription = event.detail.value || '';
    }

    async handleCreateNewForm() {
        if (this.newFormCreateDisabled) {
            return;
        }

        this.isCreatingForm = true;
        this.errorMessage = '';
        try {
            const result = await createFormWithDraftVersion({
                description: this.newFormDescription,
                themeId: this.selectedThemeId || null
            });
            this.selectedFormId = result.formId;
            this.selectedVersionId = result.versionId;
            this.selectedElementId = null;
            this.publishResult = null;
            this.storeSelectedVersion(result.versionId);
            this.showNewFormModal = false;
            this.newFormDescription = '';
            await this.loadWorkspace(result.formId, result.versionId);
            this.showToast('Form created', `${result.formName} is ready in Draft mode.`, 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isCreatingForm = false;
        }
    }

    async saveFormSettings(nextValues, successMessage) {
        if (!this.selectedFormId) {
            return;
        }
        this.isLoading = true;
        this.errorMessage = '';
        try {
            await updateFormSettings({
                formId: this.selectedFormId,
                themeId: nextValues.themeId === '' ? null : nextValues.themeId,
                enableCaptcha: !!nextValues.enableCaptcha
            });
            this.selectedThemeId = nextValues.themeId || '';
            this.selectedFormCaptchaEnabled = !!nextValues.enableCaptcha;
            await this.loadWorkspace(this.selectedFormId, this.selectedVersionId, true);
            this.showToast('Form settings saved', successMessage, 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleThemeChange(event) {
        await this.saveFormSettings(
            {
                themeId: event.detail.value || '',
                enableCaptcha: this.selectedFormCaptchaEnabled
            },
            'Form theme updated.'
        );
    }

    async handleFormCaptchaChange(event) {
        await this.saveFormSettings(
            {
                themeId: this.selectedThemeId || '',
                enableCaptcha: event.target.checked
            },
            event.target.checked ? 'CAPTCHA enabled for this form.' : 'CAPTCHA disabled for this form.'
        );
    }

    handleInputTypeChange(event) {
        this.inputFieldType = event.detail.value;
    }

    handleDisplayTypeChange(event) {
        this.displayElementType = event.detail.value;
    }

    async handleAddInput() {
        await this.addElementType(this.inputFieldType);
    }

    async handleAddDisplay() {
        await this.addElementType(this.displayElementType);
    }

    async handleQuickAddField(event) {
        const elementType = event.currentTarget?.dataset?.type;
        if (!elementType) {
            return;
        }
        if (elementType === 'repeatGroup' && !this.enableProRepeatGroups) {
            this.showToast('Pro feature', 'Enable Pro Repeat Groups in TwinaForms Admin Features first.', 'warning');
            return;
        }
        await this.addElementType(elementType);
    }

    async addElementType(elementType) {
        if (!this.selectedVersionId || this.isSelectedVersionReadOnly) {
            return;
        }
        try {
            const created = await addElement({ versionId: this.selectedVersionId, elementType });
            const selectedElement = this.selectedElement;
            if (selectedElement) {
                await insertElementAfter({
                    elementId: created.id,
                    anchorElementId: selectedElement.id
                });
            }
            await this.loadWorkspace(this.selectedFormId, this.selectedVersionId, true);
            this.selectedElementId = created.id;
            this.syncSelectedState();
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        }
    }

    handleSelectElement(event) {
        event.stopPropagation();
        this.selectedElementId = event.currentTarget.dataset.id;
        this.syncSelectedState();
    }

    handleCanvasClick() {
        this.selectedElementId = null;
        this.syncSelectedState();
    }

    handleOpenFormSettings(event) {
        event.stopPropagation();
        this.selectedElementId = null;
        this.syncSelectedState();
    }

    async handlePublishVersion() {
        if (!this.selectedVersionId || this.isSelectedVersionReadOnly) {
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        try {
            const result = await publishVersion({ versionId: this.selectedVersionId });
            this.publishResult = result;
            const nextVersionId = result.newDraftVersionId || this.selectedVersionId;
            this.storeSelectedVersion(nextVersionId);
            await this.loadWorkspace(this.selectedFormId, nextVersionId);
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

    handleEditorLabelChange(event) {
        this.editorLabel = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorTypeChange(event) {
        this.editorElementType = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorLabelPositionChange(event) {
        this.editorLabelPosition = event.target.value;
        this.applyEditorDraft();
    }

    handleEditorPlaceholderChange(event) {
        this.editorPlaceholder = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorDisplayTextChange(event) {
        this.editorDisplayText = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorImageUrlChange(event) {
        this.editorImageUrl = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorImageAltChange(event) {
        this.editorImageAlt = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorImageFitChange(event) {
        this.editorImageFit = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorImageWidthPercentChange(event) {
        this.editorImageWidthPercent = event.detail.value;
        this.applyEditorDraft();
    }

    async handleImageFileChange(event) {
        const [file] = event.target.files || [];
        if (!file || !this.selectedElementId || !this.selectedVersionId || this.isSelectedVersionReadOnly) {
            return;
        }

        try {
            const base64Data = await this.readFileAsBase64(file);
            const uploaded = await uploadImageFile({
                elementId: this.selectedElementId,
                versionId: this.selectedVersionId,
                fileName: file.name,
                contentType: file.type,
                base64Data
            });

            this.elements = this.elements.map((item) =>
                item.id === this.selectedElementId ? this.decorateBaseElement(uploaded.element) : item
            );
            this.syncSelectedState();
            await this.loadWorkspace(this.selectedFormId, this.selectedVersionId, true);
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        }
    }

    async handleEditorPicklistObjectChange(event) {
        this.editorPicklistObject = event.detail.value;
        this.editorPicklistField = '';
        this.picklistFieldOptions = [];
        this.applyEditorDraft();
        await this.loadPicklistFieldOptions(this.editorPicklistObject, null);
    }

    async handleEditorPicklistFieldChange(event) {
        this.editorPicklistField = event.detail.value;
        this.applyEditorDraft();
        await this.loadPicklistValuesIntoEditor(this.editorPicklistObject, this.editorPicklistField);
    }

    handleEditorRadioOptionsChange(event) {
        this.editorRadioOptionsText = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorLabelBoldChange(event) {
        this.editorLabelBold = event.target.checked;
        this.applyEditorDraft();
    }

    handleEditorFieldBehaviorChange(event) {
        this.editorFieldBehavior = event.detail?.value || event.target?.value || 'editable';
        this.applyEditorDraft();
    }

    handleEditorConditionalEnabledChange(event) {
        this.editorConditionalEnabled = event.target.checked;
        this.applyEditorDraft();
    }

    handleEditorConditionalFieldChange(event) {
        this.editorConditionalFieldKey = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorConditionalOperatorChange(event) {
        this.editorConditionalOperator = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorConditionalValueChange(event) {
        this.editorConditionalValue = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorMinValueChange(event) {
        this.editorMinValue = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorMaxValueChange(event) {
        this.editorMaxValue = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorDateDisplayFormatChange(event) {
        this.editorDateDisplayFormat = event.detail.value || 'us';
        this.applyEditorDraft();
    }

    handleEditorDateGmtOffsetChange(event) {
        this.editorDateGmtOffset = event.detail.value || '+00:00';
        this.applyEditorDraft();
    }

    handleEditorPastYearsChange(event) {
        this.editorPastYears = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorPastMonthsChange(event) {
        this.editorPastMonths = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorFutureYearsChange(event) {
        this.editorFutureYears = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorFutureMonthsChange(event) {
        this.editorFutureMonths = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorTextRuleChange(event) {
        this.editorTextRule = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorPrefillEnabledChange(event) {
        this.editorPrefillEnabled = event.target.checked;
        this.applyEditorDraft();
    }

    async handleEditorPrefillAliasChange(event) {
        this.editorPrefillAlias = event.detail.value;
        if (!this.editorPrefillAlias) {
            this.editorPrefillFieldPath = '';
        }
        this.applyEditorDraft();
        await this.ensureParentRepeatGroupAlias(this.editorPrefillAlias);
    }

    handleEditorPrefillFieldChange(event) {
        this.editorPrefillFieldPath = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorSubmitEnabledChange(event) {
        this.editorSubmitEnabled = event.target.checked;
        this.applyEditorDraft();
    }

    handleEditorSubmitActionChange(event) {
        this.editorSubmitActionKey = event.detail.value;
        if (!this.editorSubmitActionKey) {
            this.editorSubmitFieldPath = '';
        }
        this.applyEditorDraft();
    }

    handleEditorSubmitFieldChange(event) {
        this.editorSubmitFieldPath = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorShowTitleChange(event) {
        this.editorShowTitle = event.target.checked;
        this.applyEditorDraft();
    }

    handleEditorBoxedChange(event) {
        this.editorBoxed = event.target.checked;
        this.applyEditorDraft();
    }

    handleEditorColumnsChange(event) {
        this.editorColumns = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorRepeatSourceAliasChange(event) {
        this.editorRepeatSourceAlias = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorAllowAddRowsChange(event) {
        this.editorAllowAddRows = event.target.checked;
        this.applyEditorDraft();
    }

    handleEditorAllowDeleteRowsChange(event) {
        this.editorAllowDeleteRows = event.target.checked;
        this.applyEditorDraft();
    }

    handleEditorShowLabelsOnEachRowChange(event) {
        this.editorShowLabelsOnEachRow = event.target.checked;
        this.applyEditorDraft();
    }

    handleDragStart(event) {
        event.stopPropagation();
        this.draggedElementId = event.currentTarget.dataset.id;
        event.dataTransfer.effectAllowed = 'move';
        event.dataTransfer.setData('text/plain', this.draggedElementId);
    }

    handleDragEnd(event) {
        event.stopPropagation();
        this.draggedElementId = null;
        this.dragTargetIndex = null;
        this.dragSectionTarget = null;
    }

    handleDragOver(event) {
        event.preventDefault();
        const index = Number(event.currentTarget.dataset.index);
        this.dragTargetIndex = Number.isFinite(index) ? index : null;
        this.dragSectionTarget = null;
        event.dataTransfer.dropEffect = 'move';
    }

    handleSectionDragOver(event) {
        event.preventDefault();
        const sectionId = event.currentTarget.dataset.sectionId;
        const column = event.currentTarget.dataset.column;
        this.dragTargetIndex = null;
        this.dragSectionTarget = `${sectionId}:${column}`;
        event.dataTransfer.dropEffect = 'move';
    }

    handleDragLeave(event) {
        const related = event.relatedTarget;
        if (!related || !event.currentTarget.contains(related)) {
            this.dragTargetIndex = null;
        }
    }

    handleSectionDragLeave(event) {
        const related = event.relatedTarget;
        if (!related || !event.currentTarget.contains(related)) {
            this.dragSectionTarget = null;
        }
    }

    async handleDrop(event) {
        event.preventDefault();
        event.stopPropagation();
        if (this.isSelectedVersionReadOnly) {
            return;
        }
        const targetIndex = Number(event.currentTarget.dataset.index);
        const elementId = this.draggedElementId || event.dataTransfer.getData('text/plain');
        this.dragTargetIndex = null;
        if (!elementId || !Number.isFinite(targetIndex) || !this.selectedVersionId) {
            this.draggedElementId = null;
            return;
        }

        this.isLoading = true;
        try {
            this.selectedElementId = elementId;
            this.optimisticMoveToTopLevel(elementId, targetIndex);
            await reorderElement({
                versionId: this.selectedVersionId,
                elementId,
                targetIndex
            });
            await this.loadWorkspace(this.selectedFormId, this.selectedVersionId, true);
        } catch (error) {
            await this.loadWorkspace(this.selectedFormId, this.selectedVersionId);
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.draggedElementId = null;
            this.dragTargetIndex = null;
            this.dragSectionTarget = null;
            this.isLoading = false;
        }
    }

    async handleDropIntoSection(event) {
        event.preventDefault();
        event.stopPropagation();
        if (this.isSelectedVersionReadOnly) {
            return;
        }
        const sectionId = event.currentTarget.dataset.sectionId;
        const columnNumber = Number(event.currentTarget.dataset.column);
        const elementId = this.draggedElementId || event.dataTransfer.getData('text/plain');
        this.dragSectionTarget = null;
        if (!elementId || !sectionId || !Number.isFinite(columnNumber)) {
            this.draggedElementId = null;
            return;
        }

        this.isLoading = true;
        try {
            this.selectedElementId = elementId;
            this.optimisticPlaceInSection(elementId, sectionId, columnNumber);
            await placeElementInSection({ elementId, sectionId, columnNumber });
            await this.loadWorkspace(this.selectedFormId, this.selectedVersionId, true);
        } catch (error) {
            await this.loadWorkspace(this.selectedFormId, this.selectedVersionId);
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.draggedElementId = null;
            this.dragSectionTarget = null;
            this.isLoading = false;
        }
    }

    async handleSectionColumns(event) {
        event.stopPropagation();
        if (this.isSelectedVersionReadOnly) {
            return;
        }
        const elementId = event.currentTarget.dataset.id;
        const columns = Number(event.currentTarget.dataset.columns);
        this.isLoading = true;
        try {
            this.selectedElementId = elementId;
            this.optimisticSetSectionColumns(elementId, columns);
            await updateSectionColumns({ elementId, columns });
            await this.loadWorkspace(this.selectedFormId, this.selectedVersionId, true);
        } catch (error) {
            await this.loadWorkspace(this.selectedFormId, this.selectedVersionId);
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleDeleteSelected() {
        if (!this.selectedElementId || this.isSelectedVersionReadOnly) {
            return;
        }

        this.isLoading = true;
        try {
            const deletedId = this.selectedElementId;
            this.removeDeletedElementLocally(deletedId);
            await deleteDesignerElement({ elementId: deletedId });
            this.selectedElementId = this.elements.find((item) => item.id !== deletedId)?.id || null;
            await this.loadWorkspace(this.selectedFormId, this.selectedVersionId);
            this.showToast('Element deleted', 'The selected canvas item was removed.', 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    syncSelectedState() {
        this.canvasElements = this.buildCanvasElements(this.elements);
        this.syncEditorState();
    }

    syncEditorState() {
        const selected = this.selectedElement;
        if (!selected) {
            this.editorLabel = '';
            this.editorElementType = '';
            this.editorLabelPosition = 'above';
            this.editorPlaceholder = '';
            this.editorDisplayText = '';
            this.editorImageUrl = '';
            this.editorImageAlt = '';
            this.editorImageFit = 'original';
            this.editorImageWidthPercent = '100';
            this.editorShowTitle = true;
            this.editorBoxed = true;
            this.editorColumns = '2';
            this.editorRepeatSourceAlias = '';
            this.editorAllowAddRows = true;
            this.editorAllowDeleteRows = true;
            this.editorShowLabelsOnEachRow = true;
            this.editorPicklistObject = '';
            this.editorPicklistField = '';
            this.editorRadioOptionsText = '';
            this.editorLabelBold = false;
            this.editorFieldBehavior = 'editable';
            this.editorConditionalEnabled = false;
            this.editorConditionalFieldKey = '';
            this.editorConditionalOperator = 'equals';
            this.editorConditionalValue = '';
            this.editorMinValue = '';
            this.editorMaxValue = '';
            this.editorDateDisplayFormat = 'us';
            this.editorDateGmtOffset = '+00:00';
            this.editorPastYears = '';
            this.editorPastMonths = '';
            this.editorFutureYears = '';
            this.editorFutureMonths = '';
            this.editorTextRule = 'none';
            this.editorPrefillEnabled = false;
            this.editorPrefillAlias = '';
            this.editorPrefillFieldPath = '';
            this.editorSubmitEnabled = false;
            this.editorSubmitActionKey = '';
            this.editorSubmitFieldPath = '';
            this.picklistFieldOptions = [];
            return;
        }

        const config = this.parseConfig(selected.configJson);
        this.editorLabel = selected.label || '';
        this.editorElementType = selected.elementType === 'hidden' ? 'text' : (selected.elementType || 'text');
        this.editorLabelPosition = config.labelPosition === 'inline' ? 'above' : (config.labelPosition || 'above');
        this.editorPlaceholder = config.defaultValue || config.placeholder || '';
        this.editorDisplayText = config.html || config.text || '';
        this.editorImageUrl = config.imageUrl || '';
        this.editorImageAlt = config.altText || '';
        this.editorImageFit = config.imageFit || 'original';
        this.editorImageWidthPercent = config.imageWidthPercent == null ? '100' : String(config.imageWidthPercent);
        this.editorShowTitle = config.showTitle !== false;
        this.editorBoxed = config.boxed !== false;
        this.editorColumns = String(config.columns || (selected.elementType === 'group' ? 1 : 2));
        this.editorRepeatSourceAlias = config.repeatSourceAlias || '';
        this.editorAllowAddRows = config.allowAddRows !== false;
        this.editorAllowDeleteRows = config.allowDeleteRows !== false;
        this.editorShowLabelsOnEachRow = config.showLabelsOnEachRow !== false;
        this.editorPicklistObject = config.sourceObjectApiName || '';
        this.editorPicklistField = config.sourcePicklistFieldApiName || '';
        this.editorRadioOptionsText = this.radioOptionsText(config.options);
        this.editorLabelBold = config.labelBold === true;
        this.editorFieldBehavior = config.fieldBehavior || (selected.elementType === 'hidden' ? 'hidden' : 'editable');
        this.editorConditionalEnabled = config.conditionalEnabled === true;
        this.editorConditionalFieldKey = config.conditionalFieldKey || '';
        this.editorConditionalOperator = config.conditionalOperator || 'equals';
        this.editorConditionalValue = config.conditionalValue || '';
        this.editorMinValue = config.minValue === null || config.minValue === undefined ? '' : String(config.minValue);
        this.editorMaxValue = config.maxValue === null || config.maxValue === undefined ? '' : String(config.maxValue);
        this.editorDateDisplayFormat = config.dateDisplayFormat || 'us';
        this.editorDateGmtOffset = config.dateGmtOffset || '+00:00';
        this.editorPastYears = config.pastYears === null || config.pastYears === undefined ? '' : String(config.pastYears);
        this.editorPastMonths = config.pastMonths === null || config.pastMonths === undefined ? '' : String(config.pastMonths);
        this.editorFutureYears = config.futureYears === null || config.futureYears === undefined ? '' : String(config.futureYears);
        this.editorFutureMonths = config.futureMonths === null || config.futureMonths === undefined ? '' : String(config.futureMonths);
        this.editorTextRule = config.textRule || 'none';
        this.editorPrefillEnabled = !!config.prefillEnabled || !!config.prefillAlias || !!config.prefillFieldPath;
        this.editorPrefillAlias = config.prefillAlias || '';
        this.editorPrefillFieldPath = config.prefillFieldPath || '';
        this.editorSubmitEnabled = !!config.submitEnabled || !!config.submitActionKey || !!config.submitFieldPath;
        this.editorSubmitActionKey = config.submitActionKey || '';
        this.editorSubmitFieldPath = config.submitFieldPath || '';
        if (this.selectedElementIsPicklist && this.editorPicklistObject) {
            this.loadPicklistFieldOptions(this.editorPicklistObject, this.editorPicklistField);
        } else {
            this.picklistFieldOptions = [];
        }
    }

    buildEditorConfig() {
        const selected = this.selectedElement;
        const baseConfig = this.parseConfig(selected?.configJson);
        const nextConfig = { ...baseConfig };

        if (this.selectedElementSupportsLabelPosition) {
            nextConfig.labelPosition = this.editorLabelPosition;
        } else {
            delete nextConfig.labelPosition;
        }

        if (this.selectedElementSupportsDefaultValue) {
            nextConfig.defaultValue = this.editorPlaceholder || '';
            delete nextConfig.placeholder;
            if (this.editorElementType === 'checkbox') {
                nextConfig.checked = ['true', '1', 'yes', 'checked'].includes(String(this.editorPlaceholder || '').toLowerCase());
            }
        } else {
            delete nextConfig.defaultValue;
            delete nextConfig.placeholder;
        }

        if (this.selectedElementIsDisplayText) {
            nextConfig.html = this.editorDisplayText || '<p>Display text</p>';
            nextConfig.text = this.editorDisplayText || '<p>Display text</p>';
        }

        if (this.selectedElementIsImage) {
            nextConfig.imageUrl = this.editorImageUrl || '';
            nextConfig.altText = this.editorImageAlt || 'Image preview';
            nextConfig.imageFit = this.editorImageFit || 'original';
            nextConfig.imageWidthPercent = this.editorImageWidthPercent || '100';
        }

        if (this.selectedElementIsPicklist) {
            nextConfig.sourceObjectApiName = this.editorPicklistObject || '';
            nextConfig.sourcePicklistFieldApiName = this.editorPicklistField || '';
        } else {
            delete nextConfig.sourceObjectApiName;
            delete nextConfig.sourcePicklistFieldApiName;
        }

        if (this.selectedElementIsRadio) {
            nextConfig.options = this.parseRadioOptionsText(this.editorRadioOptionsText);
        }

        if (this.selectedElementSupportsBoldLabel) {
            nextConfig.labelBold = this.editorLabelBold;
        } else {
            delete nextConfig.labelBold;
        }

        if (this.selectedElementSupportsFieldBehavior) {
            nextConfig.fieldBehavior = this.editorFieldBehavior || 'editable';
        } else {
            delete nextConfig.fieldBehavior;
        }

        if (this.selectedElementSupportsConditional) {
            nextConfig.conditionalEnabled = this.editorConditionalEnabled;
            nextConfig.conditionalFieldKey = this.editorConditionalFieldKey || '';
            nextConfig.conditionalOperator = this.editorConditionalOperator || 'equals';
            nextConfig.conditionalValue = this.editorConditionalValue || '';
        } else {
            delete nextConfig.conditionalEnabled;
            delete nextConfig.conditionalFieldKey;
            delete nextConfig.conditionalOperator;
            delete nextConfig.conditionalValue;
        }

        if (this.selectedElementIsNumber || this.selectedElementIsDate) {
            nextConfig.minValue = this.editorMinValue;
            nextConfig.maxValue = this.editorMaxValue;
            if (this.selectedElementIsDate) {
                nextConfig.dateDisplayFormat = this.editorDateDisplayFormat || 'us';
                nextConfig.dateGmtOffset = this.editorDateGmtOffset || '+00:00';
            } else {
                delete nextConfig.dateDisplayFormat;
                delete nextConfig.dateGmtOffset;
            }
            delete nextConfig.pastYears;
            delete nextConfig.pastMonths;
            delete nextConfig.futureYears;
            delete nextConfig.futureMonths;
        } else {
            delete nextConfig.minValue;
            delete nextConfig.maxValue;
            delete nextConfig.dateDisplayFormat;
            delete nextConfig.dateGmtOffset;
            delete nextConfig.pastYears;
            delete nextConfig.pastMonths;
            delete nextConfig.futureYears;
            delete nextConfig.futureMonths;
        }

        if (this.selectedElementSupportsTextValidation) {
            nextConfig.textRule = this.editorTextRule || 'none';
        } else {
            delete nextConfig.textRule;
        }

        if (this.selectedElementSupportsSalesforceMapping) {
            nextConfig.prefillEnabled = this.editorPrefillEnabled;
            nextConfig.prefillAlias = this.editorPrefillAlias || '';
            nextConfig.prefillFieldPath = this.editorPrefillFieldPath || '';
            nextConfig.submitEnabled = this.editorSubmitEnabled;
            nextConfig.submitActionKey = this.editorSubmitActionKey || '';
            nextConfig.submitFieldPath = this.editorSubmitFieldPath || '';
        } else {
            delete nextConfig.prefillEnabled;
            delete nextConfig.prefillAlias;
            delete nextConfig.prefillFieldPath;
            delete nextConfig.submitEnabled;
            delete nextConfig.submitActionKey;
            delete nextConfig.submitFieldPath;
        }

        if (this.selectedElementIsSection) {
            nextConfig.text = this.editorDisplayText || 'Section description';
            nextConfig.showTitle = this.editorShowTitle;
            nextConfig.boxed = this.editorBoxed;
            nextConfig.columns = Number(this.editorColumns || 2);
        }

        if (this.selectedElementIsGroup) {
            nextConfig.columns = Number(this.editorColumns || 1);
            nextConfig.boxed = false;
            delete nextConfig.text;
            delete nextConfig.showTitle;
            delete nextConfig.repeatSourceAlias;
            delete nextConfig.allowAddRows;
            delete nextConfig.allowDeleteRows;
            delete nextConfig.showLabelsOnEachRow;
        }

        if (this.selectedElementIsRepeatGroup) {
            nextConfig.showTitle = this.editorShowTitle;
            nextConfig.boxed = this.editorBoxed;
            nextConfig.columns = Number(this.editorColumns || 2);
            nextConfig.repeatSourceAlias = this.editorRepeatSourceAlias || '';
            nextConfig.allowAddRows = this.editorAllowAddRows;
            nextConfig.allowDeleteRows = this.editorAllowDeleteRows;
            nextConfig.showLabelsOnEachRow = this.editorShowLabelsOnEachRow;
            delete nextConfig.text;
        }

        return nextConfig;
    }

    readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const result = String(reader.result || '');
                const commaIndex = result.indexOf(',');
                resolve(commaIndex >= 0 ? result.substring(commaIndex + 1) : result);
            };
            reader.onerror = () => reject(new Error('Could not read the selected image file.'));
            reader.readAsDataURL(file);
        });
    }

    applyEditorDraft() {
        if (!this.selectedElementId || this.isSelectedVersionReadOnly) {
            return;
        }

        const nextConfig = this.buildEditorConfig();
        this.elements = this.elements.map((item) => {
            if (item.id !== this.selectedElementId) {
                return item;
            }

            const nextFieldKey = ['text', 'textarea', 'number', 'date', 'email', 'tel', 'url', 'checkbox', 'select', 'radio', 'repeatGroup'].includes(this.editorElementType)
                ? (item.fieldKey || this.generatedFieldKey(this.editorElementType))
                : null;

            return this.decorateBaseElement({
                ...item,
                label: this.editorLabel || item.label,
                elementType: this.editorElementType,
                fieldKey: nextFieldKey,
                configJson: JSON.stringify(nextConfig)
            });
        });
        this.syncSelectedState();
        this.scheduleAutoSave();
    }

    generatedFieldKey(elementType) {
        const prefix = `${elementType || 'field'}Field`;
        return `${prefix}${Math.floor(Math.random() * 10000)}`;
    }

    async handleSaveVisualSettings() {
        await this.persistVisualSettings(true);
    }

    scheduleAutoSave() {
        if (!this.selectedElementId || this.isSelectedVersionReadOnly) {
            return;
        }
        window.clearTimeout(this.autoSaveTimeoutId);
        this.autoSaveTimeoutId = window.setTimeout(() => {
            this.persistVisualSettings(false);
        }, 500);
    }

    async persistVisualSettings(showToast) {
        if (!this.selectedElement) {
            return;
        }
        try {
            const selected = this.selectedElement;
            await updateElement({
                inputValue: {
                    id: selected.id,
                    label: selected.label,
                    fieldKey: selected.fieldKey,
                    configJson: selected.configJson,
                    elementType: selected.elementType
                }
            });
            await this.loadWorkspace(this.selectedFormId, this.selectedVersionId, true);
            if (showToast) {
                this.showToast('Saved', 'Visual settings updated.', 'success');
            }
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        }
    }

    async ensureParentRepeatGroupAlias(aliasValue) {
        if (!aliasValue || this.isSelectedVersionReadOnly) {
            return;
        }
        const parent = this.selectedRepeatGroupParent;
        if (!parent) {
            return;
        }

        const parentConfig = this.parseConfig(parent.configJson);
        if (parentConfig.repeatSourceAlias) {
            return;
        }

        parentConfig.repeatSourceAlias = aliasValue;
        const updatedParent = this.decorateBaseElement({
            ...parent,
            configJson: JSON.stringify(parentConfig)
        });

        this.elements = this.elements.map((item) => (item.id === parent.id ? updatedParent : item));
        this.syncSelectedState();

        try {
            await updateElement({
                inputValue: {
                    id: updatedParent.id,
                    label: updatedParent.label,
                    fieldKey: updatedParent.fieldKey,
                    configJson: updatedParent.configJson,
                    elementType: updatedParent.elementType
                }
            });
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            await this.loadWorkspace(this.selectedFormId, this.selectedVersionId, true);
        }
    }

    optimisticSetSectionColumns(elementId, columns) {
        this.elements = this.elements.map((item) => {
            if (item.id !== elementId) {
                return item;
            }
            const config = this.parseConfig(item.configJson);
            config.columns = columns;
            return this.decorateBaseElement({
                ...item,
                configJson: JSON.stringify(config)
            });
        });
        this.syncSelectedState();
    }

    optimisticMoveToTopLevel(elementId, targetIndex) {
        const working = this.elements.map((item) => {
            if (item.id !== elementId) {
                return item;
            }
            const config = this.parseConfig(item.configJson);
            delete config.sectionColumn;
            return this.decorateBaseElement({
                ...item,
                parentElementId: null,
                configJson: JSON.stringify(config)
            });
        });

        const topLevel = working
            .filter((item) => !item.parentElementId)
            .sort((a, b) => (a.orderValue || 0) - (b.orderValue || 0));
        const children = working.filter((item) => item.parentElementId);
        const currentIndex = topLevel.findIndex((item) => item.id === elementId);
        if (currentIndex < 0) {
            return;
        }

        const [dragged] = topLevel.splice(currentIndex, 1);
        let nextIndex = targetIndex;
        if (nextIndex > currentIndex) {
            nextIndex -= 1;
        }
        if (nextIndex < 0) {
            nextIndex = 0;
        }
        if (nextIndex > topLevel.length) {
            nextIndex = topLevel.length;
        }
        topLevel.splice(nextIndex, 0, dragged);
        topLevel.forEach((item, index) => {
            item.orderValue = (index + 1) * 10;
        });

        this.elements = [...topLevel, ...children];
        this.syncSelectedState();
    }

    optimisticPlaceInSection(elementId, sectionId, columnNumber) {
        const section = this.elements.find((item) => item.id === sectionId);
        if (!section) {
            return;
        }

        const existingChildren = this.elements.filter((item) => item.parentElementId === section.elementId);
        const nextOrder = existingChildren.length
            ? Math.max(...existingChildren.map((item) => item.orderValue || 0)) + 10
            : 10;

        this.elements = this.elements.map((item) => {
            if (item.id !== elementId) {
                return item;
            }
            const config = this.parseConfig(item.configJson);
            config.sectionColumn = columnNumber;
            return this.decorateBaseElement({
                ...item,
                parentElementId: section.elementId,
                orderValue: nextOrder,
                configJson: JSON.stringify(config)
            });
        });
        this.syncSelectedState();
    }

    removeDeletedElementLocally(elementId) {
        const target = this.elements.find((item) => item.id === elementId);
        if (!target) {
            return;
        }

        if ((target.elementType === 'section' || target.elementType === 'group' || target.elementType === 'repeatGroup') && target.elementId) {
            this.elements = this.elements.filter((item) => item.id !== elementId && item.parentElementId !== target.elementId);
        } else {
            this.elements = this.elements.filter((item) => item.id !== elementId);
        }
        this.syncSelectedState();
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

    radioOptionsText(options) {
        if (!Array.isArray(options)) {
            return '';
        }
        return options.map((option) => option.label || '').filter((label) => label).join('\n');
    }

    parseRadioOptionsText(rawText) {
        const labels = String(rawText || '')
            .split('\n')
            .map((line) => line.trim())
            .filter((line) => line);

        if (!labels.length) {
            return [
                { label: 'Option 1', value: 'option1' },
                { label: 'Option 2', value: 'option2' }
            ];
        }

        return labels.map((label, index) => ({
            label,
            value: `option${index + 1}`
        }));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    safeValue(value, fallbackValue) {
        return value || fallbackValue;
    }

    safeNumber(value, fallbackValue) {
        const parsed = Number(value);
        return Number.isFinite(parsed) && parsed > 0 ? parsed : fallbackValue;
    }

    safeFont(value, fallbackValue) {
        return value ? `"${value}", Arial, sans-serif` : fallbackValue;
    }

    themeFormMaxWidth(value) {
        if (value === 'narrow') {
            return '42rem';
        }
        if (value === 'standard') {
            return '56rem';
        }
        if (value === 'full') {
            return '100%';
        }
        return '72rem';
    }

    normalizeError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (Array.isArray(error?.body?.pageErrors) && error.body.pageErrors.length) {
            return error.body.pageErrors[0].message;
        }
        if (Array.isArray(error?.body?.fieldErrors)) {
            const firstFieldError = error.body.fieldErrors.find((entry) => Array.isArray(entry) && entry.length && entry[0]?.message);
            if (firstFieldError) {
                return firstFieldError[0].message;
            }
        }
        if (Array.isArray(error?.body?.output?.errors) && error.body.output.errors.length) {
            return error.body.output.errors[0].message;
        }
        const fieldErrorGroups = error?.body?.output?.fieldErrors;
        if (fieldErrorGroups && typeof fieldErrorGroups === 'object') {
            const firstFieldName = Object.keys(fieldErrorGroups).find((key) => Array.isArray(fieldErrorGroups[key]) && fieldErrorGroups[key].length);
            if (firstFieldName) {
                return fieldErrorGroups[firstFieldName][0].message;
            }
        }
        if (error?.message) {
            return error.message;
        }
        return 'Something went wrong while loading the designer.';
    }

    storeSelectedVersion(versionId) {
        try {
            if (versionId) {
                window.sessionStorage.setItem(DESIGNER_VERSION_KEY, versionId);
            }
        } catch (e) {
            // ignore browser storage failures
        }
    }

    loadStoredVersionId() {
        try {
            return window.sessionStorage.getItem(DESIGNER_VERSION_KEY);
        } catch (e) {
            return null;
        }
    }

    clearStoredVersion() {
        try {
            window.sessionStorage.removeItem(DESIGNER_VERSION_KEY);
        } catch (e) {
            // ignore browser storage failures
        }
    }
}
