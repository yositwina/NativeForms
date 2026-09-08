import { LightningElement, track } from 'lwc';
import getWorkspace from '@salesforce/apex/NativeFormsDesignerController.getWorkspace';
import updateFormSettings from '@salesforce/apex/NativeFormsDesignerController.updateFormSettings';
import updateUserVerificationSessionMode from '@salesforce/apex/NativeFormsDesignerController.updateUserVerificationSessionMode';
import updateUserVerificationSenderEmail from '@salesforce/apex/NativeFormsDesignerController.updateUserVerificationSenderEmail';
import updateVersionPostSubmitRedirectSettings from '@salesforce/apex/NativeFormsDesignerController.updateVersionPostSubmitRedirectSettings';
import updateVersionSubmissionPdfSettings from '@salesforce/apex/NativeFormsDesignerController.updateVersionSubmissionPdfSettings';
import updateVersionCustomJs from '@salesforce/apex/NativeFormsDesignerController.updateVersionCustomJs';
import createProject from '@salesforce/apex/NativeFormsDesignerController.createProject';
import createFormWithDraftVersion from '@salesforce/apex/NativeFormsDesignerController.createFormWithDraftVersion';
import createFormFromPageLayout from '@salesforce/apex/NativeFormsDesignerController.createFormFromPageLayout';
import cloneFormWithDraftVersion from '@salesforce/apex/NativeFormsDesignerController.cloneFormWithDraftVersion';
import cloneField from '@salesforce/apex/NativeFormsDesignerController.cloneField';
import restoreDraftFromPublished from '@salesforce/apex/NativeFormsDesignerController.restoreDraftFromPublished';
import deleteDesignerForm from '@salesforce/apex/NativeFormsDesignerController.deleteForm';
import restoreVersionElementsSnapshot from '@salesforce/apex/NativeFormsDesignerController.restoreVersionElementsSnapshot';
import exportPortableForm from '@salesforce/apex/NativeFormsFormPortabilityController.exportForm';
import inspectPortableFormImport from '@salesforce/apex/NativeFormsFormPortabilityController.inspectImport';
import importPortableForm from '@salesforce/apex/NativeFormsFormPortabilityController.importForm';
import getConnectedImportView from '@salesforce/apex/NativeFormsConnectedOrgController.getConnectedImportView';
import getSnapshotPackage from '@salesforce/apex/NativeFormsConnectedOrgController.getSnapshotPackage';
import getObjectOptions from '@salesforce/apex/NativeFormsDesignerController.getObjectOptions';
import getPageLayoutImportOptions from '@salesforce/apex/NativeFormsDesignerController.getPageLayoutImportOptions';
import getRelatedListImportOptions from '@salesforce/apex/NativeFormsDesignerController.getRelatedListImportOptions';
import getRelatedListFieldOptions from '@salesforce/apex/NativeFormsDesignerController.getRelatedListFieldOptions';
import getRelatedParentMatchOptions from '@salesforce/apex/NativeFormsDesignerController.getRelatedParentMatchOptions';
import previewPageLayoutImport from '@salesforce/apex/NativeFormsDesignerController.previewPageLayoutImport';
import getPicklistFieldOptions from '@salesforce/apex/NativeFormsDesignerController.getPicklistFieldOptions';
import getPicklistValueOptions from '@salesforce/apex/NativeFormsDesignerController.getPicklistValueOptions';
import getLookupFieldOptions from '@salesforce/apex/NativeFormsDesignerController.getLookupFieldOptions';
import uploadImageFile from '@salesforce/apex/NativeFormsDesignerController.uploadImageFile';
import addElement from '@salesforce/apex/NativeFormsDesignerController.addElement';
import deleteDesignerElement from '@salesforce/apex/NativeFormsDesignerController.deleteElement';
import moveElement from '@salesforce/apex/NativeFormsDesignerController.moveElement';
import insertElementAfter from '@salesforce/apex/NativeFormsDesignerController.insertElementAfter';
import updateSectionColumns from '@salesforce/apex/NativeFormsDesignerController.updateSectionColumns';
import updateElement from '@salesforce/apex/NativeFormsBuilderController.updateElement';
import publishVersion from '@salesforce/apex/NativeFormsBuilderController.publishVersion';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import { previewFormulaValue, setFormulaLanguage, validateFormulaConfig } from './formulaEngine';

const DESIGNER_PROJECT_KEY = 'nativeforms:selectedProjectId';
const DESIGNER_FORM_KEY = 'nativeforms:selectedFormId';
const DESIGNER_VERSION_KEY = 'nativeforms:selectedVersionId';
const DESIGNER_FORM_SORT_KEY = 'nativeforms:formSortMode';
const SALESFORCE_ID_PATTERN = /^[a-zA-Z0-9]{15}(?:[a-zA-Z0-9]{3})?$/;

function sanitizeSalesforceId(value) {
    const normalized = String(value || '').trim();
    return SALESFORCE_ID_PATTERN.test(normalized) ? normalized : null;
}

const MAX_UNDO_STEPS = 5;
const SUBMIT_BUTTON_ELEMENT_ID = '__submitButton__';
const USER_VERIFICATION_ELEMENT_ID = '__userVerification__';
const MAX_EMBEDDED_IMAGE_BYTES = 69 * 1024;
const MAX_EMBEDDED_IMAGE_LABEL = '69 KB';

export default class NativeFormsDesigner extends LightningElement {
    isLoading = true;
    isCloningField = false;
    pendingVisualSavePromises = [];
    isSavingFormSettings = false;
    errorMessage = '';
    selectedProjectId;
    selectedFormId;
    selectedVersionId;
    selectedThemeId;
    selectedElementId;
    selectedFormName = '';
    selectedFormKey = '';
    selectedFormDescription = '';
    selectedProjectName = '';
    draftFormName = '';
    draftLanguageCode = 'en';
    selectedFormCaptchaEnabled = false;
    captchaKeysConfigured = false;
    selectedVersionName = '';
    selectedVersionStatus = '';
    selectedVersionLanguageCode = 'en';
    selectedVersionSubmitSuccessMessage = 'Your form was submitted successfully.';
    selectedVersionSubmitLabel = 'Submit';
    selectedVersionRtlEnabled = false;
    selectedVersionPostSubmitAutoLinkEnabled = false;
    selectedVersionPostSubmitUrlMode = 'template';
    selectedVersionPostSubmitUrlTemplate = '';
    selectedVersionPostSubmitUrlFormula = '';
    selectedVersionPostSubmitButtonLabel = 'Continue';
    selectedVersionPostSubmitDelaySeconds = 0;
    selectedVersionUserVerificationEnabled = false;
    selectedVersionUserVerificationMatchField = 'Email';
    selectedVersionUserVerificationIntroText = '';
    selectedVersionUserVerificationSentMessage = '';
    selectedVersionUserVerificationInvalidMessage = '';
    selectedVersionUserVerificationVerifiedMessage = '';
    selectedVersionUserVerificationSendButtonLabel = 'Enter';
    selectedVersionUserVerificationVerifyButtonLabel = 'Verify';
    selectedVersionUserVerificationResendButtonLabel = 'Resend Verification Number';
    selectedVersionUserVerificationExpiryMinutes = 10;
    selectedVersionUserVerificationMaxAttempts = 5;
    selectedVersionUserVerificationAllowResend = true;
    selectedVersionUserVerificationSessionMode = 'short';
    selectedVersionUserVerificationSenderEmail = '';
    selectedVersionSubmitConditionalEnabled = false;
    selectedVersionSubmitConditionalFieldKey = '';
    selectedVersionSubmitConditionalOperator = 'equals';
    selectedVersionSubmitConditionalValue = '';
    selectedVersionSubmitConditionalConditions = [];
    selectedVersionSubmitConditionalExpression = '';
    selectedVersionSubmissionPdfEnabled = false;
    selectedVersionSubmissionPdfAttachToRecord = true;
    selectedVersionSubmissionPdfTargetSubmitActionKey = '';
    selectedVersionSubmissionPdfTitle = 'Submitted Response';
    selectedVersionSubmissionPdfIncludeEmptyFields = true;
    selectedVersionCustomJs = '';
    draftSubmitSuccessMessage = 'Your form was submitted successfully.';
    draftSubmitLabel = 'Submit';
    draftRtlEnabled = false;
    draftPostSubmitAutoLinkEnabled = false;
    draftPostSubmitUrlMode = 'template';
    draftPostSubmitUrlTemplate = '';
    draftPostSubmitUrlFormula = '';
    draftPostSubmitUrlFormulaPreviewValue = '';
    draftPostSubmitUrlFormulaError = '';
    draftPostSubmitButtonLabel = 'Continue';
    draftPostSubmitDelaySeconds = 0;
    draftUserVerificationEnabled = false;
    draftUserVerificationMatchField = 'Email';
    draftUserVerificationIntroText = '';
    draftUserVerificationSentMessage = '';
    draftUserVerificationInvalidMessage = '';
    draftUserVerificationVerifiedMessage = '';
    draftUserVerificationSendButtonLabel = 'Enter';
    draftUserVerificationVerifyButtonLabel = 'Verify';
    draftUserVerificationResendButtonLabel = 'Resend Verification Number';
    draftUserVerificationExpiryMinutes = 10;
    draftUserVerificationMaxAttempts = 5;
    draftUserVerificationAllowResend = true;
    draftUserVerificationSessionMode = 'short';
    draftUserVerificationSenderEmail = '';
    draftSubmitConditionalEnabled = false;
    draftSubmitConditionalFieldKey = '';
    draftSubmitConditionalOperator = 'equals';
    draftSubmitConditionalValue = '';
    draftSubmitConditionalConditions = [];
    draftSubmitConditionalExpression = '';
    draftSubmissionPdfEnabled = false;
    draftSubmissionPdfAttachToRecord = true;
    draftSubmissionPdfTargetSubmitActionKey = '';
    draftSubmissionPdfTitle = 'Submitted Response';
    draftSubmissionPdfIncludeEmptyFields = true;
    draftCustomJs = '';
    selectedPublishedUrl = '';
    selectedTheme = null;
    draggedElementId = null;
    dragTargetIndex = null;
    dragSectionTarget = null;
    autoSaveTimeoutId = null;
    publishResult = null;
    publishResultContextVersionId = '';
    undoStack = [];
    pendingElementEditUndoSnapshot = null;
    isUndoing = false;
    showNewFormModal = false;
    showCreateProjectModal = false;
    showLayoutImportModal = false;
    showLayoutImportResultModal = false;
    showImportFormModal = false;
    showCloneFormModal = false;
    showDisplayTextModal = false;
    showCustomJsModal = false;
    showPostSubmitFormulaModal = false;
    showFieldFormulaModal = false;
    showButtonParameterFormulaModal = false;
    showDeleteFormModal = false;
    newFormDescription = '';
    newFormProjectId = '';
    newFormProjectName = '';
    isCreatingForm = false;
    newProjectName = '';
    isCreatingProject = false;
    layoutImportDescription = '';
    layoutImportProjectId = '';
    layoutImportProjectName = '';
    layoutImportObjectApiName = '';
    layoutImportLayoutKey = '';
    layoutImportMode = 'secureUpdateOrCreate';
    layoutImportLanguageCode = '';
    isImportingLayout = false;
    layoutImportPreview = null;
    layoutImportResult = null;
    isLoadingLayoutMetadata = false;
    cloneFormDescription = '';
    cloneFormProjectId = '';
    cloneFormProjectName = '';
    isCloningForm = false;
    isRestoringPublished = false;
    isExportingForm = false;
    isInspectingFormImport = false;
    isImportingForm = false;
    importPackageJson = '';
    importFileName = '';
    importPreview = null;
    importProjectId = '__default__';
    importDecision = '';
    importThemeConflictChoice = '';
    importRawJsonText = '';
    importStatusMessage = '';
    connectedImportView = null;
    connectedSnapshots = [];
    connectedImportError = '';
    isLoadingConnectedImportSources = false;
    isLoadingConnectedSnapshot = false;
    deleteFormConfirmText = '';
    isDeletingForm = false;

    @track projectOptions = [];
    @track formOptions = [];
    rawFormOptions = [];
    formSortMode = 'nameAsc';
    @track versionOptions = [];
    @track themeOptions = [];
    @track elements = [];
    @track canvasElements = [];
    @track salesforceObjectOptions = [];
    @track picklistFieldOptions = [];
    @track lookupSearchFieldOptions = [];
    @track lookupDisplayFieldOptions = [];
    @track layoutImportLayoutOptions = [];
    // Page Layout to Form - related records as a table
    layoutImportIncludeRelated = false;
    layoutImportRelatedValue = '';
    layoutImportParentShape = '';
    layoutImportContactLookupField = '';
    layoutImportParentContactField = '';
    layoutImportBusinessKeyField = '';
    layoutImportBusinessKeyParam = '';
    isLoadingRelatedMetadata = false;
    @track layoutImportRelatedListOptions = [];
    @track layoutImportRelatedFieldOptions = [];
    @track layoutImportRelatedFieldValues = [];
    @track layoutImportContactLookupOptions = [];
    @track layoutImportParentContactOptions = [];
    @track layoutImportBusinessKeyOptions = [];
    @track prefillAliasDetails = [];
    @track submitActionDetails = [];
    @track editorSurveyOptions = [];
    @track publishedButtonTargets = [];
    @track editorButtonQueryParameters = [];
    enableProConditionLogic = false;
    enableProRepeatGroups = false;
    enableProLoadFile = false;
    enableProElectronicSignature = false;
    enableProSubmissionPdf = false;
    enableProSurveyFields = false;
    enableProLocationFields = false;
    enableProFormulaFields = false;
    enableProPostSubmitAutoLink = false;
    enableProUserVerification = false;
    enableProAdvancedSubmitModes = false;
    enableProPageLayoutClone = false;
    enableProCustomJs = false;
    enableProButtonElements = false;
    enableProMergedDocument = false;
    currentFormCount = 0;
    maxForms = null;
    formLimitReached = false;
    formLimitMessage = '';
    upgradeUrl = 'https://twinaforms.com/upgrade?source=salesforce-designer';
    selectedPostSubmitFormToken = '';
    selectedPostSubmitFormulaFieldToken = '';
    selectedFormulaFieldToken = '';
    selectedButtonParameterFormulaFieldToken = '';
    postSubmitUrlSelectionStart = 0;
    postSubmitUrlSelectionEnd = 0;
    postSubmitTokenInteraction = false;
    postSubmitSettingsBlurTimeout;

    inputFieldType = 'text';
    displayElementType = 'section';
    editorLabel = '';
    editorElementType = '';
    editorLabelPosition = 'above';
    editorDefaultValue = '';
    editorPlaceholder = '';
    editorDisplayText = '';
    editorImageUrl = '';
    editorImageAlt = '';
    editorImageFit = 'original';
    editorImageWidthPercent = '100';
    editorShowTitle = true;
    editorBoxed = true;
    editorColumns = '2';
    editorColumnLayout = 'equal';
    editorRepeatSourceAlias = '';
    editorRepeatSubmitActionKey = '';
    editorAllowAddRows = true;
    editorAllowDeleteRows = true;
    editorShowLabelsOnEachRow = true;
    editorRowSignatureEnabled = false;
    editorRowSignatureRequired = true;
    editorRowSignatureLabel = 'Signature';
    editorRowSignatureHelpText = '';
    editorRowSignatureAttachToRowRecord = false;
    editorPicklistObject = '';
    editorPicklistField = '';
    editorLookupTargetObject = '';
    editorLookupSearchFieldsText = 'Name';
    editorLookupDisplayFieldsText = 'Name';
    editorLookupSearchFields = ['Name'];
    editorLookupDisplayFields = ['Name'];
    @track editorLookupSetFields = [];
    editorLookupMinSearchLength = '2';
    editorLookupResultLimit = '10';
    editorLocationMode = 'countryRegionCity';
    editorLocationLayout = 'stacked';
    editorLocationRequiredCountry = true;
    editorLocationRequiredRegion = false;
    editorLocationRequiredCity = false;
    editorLocationDefaultCountryCode = '';
    editorLocationAllowedCountriesText = '';
    editorLocationMinSearchLength = '2';
    editorLocationResultLimit = '10';
    editorLocationCountryPrefillFieldPath = '';
    editorLocationRegionPrefillFieldPath = '';
    editorLocationCityPrefillFieldPath = '';
    editorLocationCountrySubmitFieldPath = '';
    editorLocationRegionSubmitFieldPath = '';
    editorLocationCitySubmitFieldPath = '';
    editorLabelBold = false;
    editorLabelItalic = false;
    editorLabelUnderline = false;
    editorRequired = false;
    editorFieldBehavior = 'editable';
    editorConditionalEnabled = false;
    editorConditionalFieldKey = '';
    editorConditionalOperator = 'equals';
    editorConditionalValue = '';
    editorConditionalConditions = [];
    editorConditionalExpression = '';
    editorMinValue = '';
    editorMaxValue = '';
    editorTextareaMaxLength = '254';
    editorDateDisplayFormat = 'us';
    editorDateGmtOffset = '+00:00';
    editorTimeFormat = '24h';
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
    editorAllowMultipleFiles = false;
    editorAllowedExtensionsText = '';
    editorMaxFileSizeMb = '10';
    editorTargetSubmitActionKey = '';
    editorHelpText = '';
    editorClearButtonLabel = 'Clear';
    editorButtonDestinationType = 'form';
    editorButtonTargetFormId = '';
    editorButtonExternalUrlMode = 'template';
    editorButtonExternalUrlTemplate = '';
    editorButtonExternalUrlFormula = '';
    editorButtonSubmitBeforeNavigation = false;
    editorUseFormula = false;
    editorFormulaExpression = '';
    editorFormulaPreviewValue = '';
    editorFormulaError = '';
    modalDisplayText = '';
    modalMergeAlias = '';
    modalMergeFieldPath = '';
    displayTextRichTextFormats = [
        'font',
        'size',
        'bold',
        'italic',
        'underline',
        'strike',
        'color',
        'background',
        'list',
        'indent',
        'align',
        'link',
        'clean'
    ];
    modalCustomJs = '';
    modalFormulaExpression = '';
    modalFormulaPreviewValue = '';
    modalFormulaError = '';
    modalPostSubmitUrlFormula = '';
    modalPostSubmitUrlFormulaPreviewValue = '';
    modalPostSubmitUrlFormulaError = '';
    modalButtonParameterFormula = '';
    modalButtonParameterFormulaPreviewValue = '';
    modalButtonParameterFormulaError = '';
    modalButtonParameterIndex = null;

    inputFieldOptions = [
        { label: 'Text', value: 'text', iconName: 'utility:text' },
        { label: 'Number', value: 'number', iconName: 'utility:number_input' },
        { label: 'Date', value: 'date', iconName: 'utility:event' },
        { label: 'Time', value: 'time', iconName: 'utility:clock' },
        { label: 'Email', value: 'email', iconName: 'utility:email' },
        { label: 'Phone', value: 'tel', iconName: 'utility:call' },
        { label: 'Picklist', value: 'select', iconName: 'utility:picklist_type' },
        { label: 'Multi Checkbox', value: 'multiCheckbox', iconName: 'utility:check' },
        { label: 'Lookup', value: 'lookup', iconName: 'utility:search' },
        { label: 'Radio groups', value: 'radio', iconName: 'utility:radio_button' },
        { label: 'Checkbox', value: 'checkbox', iconName: 'utility:check' },
        { label: 'Text Area', value: 'textarea', iconName: 'utility:note' },
        { label: 'URL', value: 'url', iconName: 'utility:link' },
        { label: 'File Upload', value: 'fileUpload', iconName: 'utility:upload' },
        { label: 'Signature', value: 'signature', iconName: 'utility:edit_form' }
    ];

    specialElementOptions = [
        { label: 'Button', value: 'button', iconName: 'utility:link' },
        { label: 'Country / State / City', value: 'location', iconName: 'utility:location' },
        { label: 'Merged Document', value: 'mergedDocument', iconName: 'utility:description' },
        { label: 'Blank Space', value: 'spacer', iconName: 'utility:rows' }
    ];

    spacerSizeOptions = [
        { label: 'Field only', value: 'field' },
        { label: 'Field with label space', value: 'fieldWithLabel' }
    ];

    surveyFieldOptions = [
        { key: 'stars', label: '1-5 Star Rating', value: 'radio', preset: 'stars', iconName: 'utility:favorite' },
        { key: 'nps', label: 'NPS 0-10', value: 'radio', preset: 'nps', iconName: 'utility:gauge' },
        { key: 'likert', label: 'Likert Scale', value: 'radio', preset: 'likert', iconName: 'utility:slider' },
        { key: 'ranking', label: 'Ranking', value: 'ranking', preset: 'ranking', iconName: 'utility:sort' },
        { key: 'satisfaction', label: 'Satisfaction Scale', value: 'radio', preset: 'satisfaction', iconName: 'utility:smiley_and_people' }
    ];

    displayElementOptions = [
        { label: 'Section', value: 'section', iconName: 'utility:section' },
        { label: 'Group', value: 'group', iconName: 'utility:layout' },
        { label: 'Records List', value: 'repeatGroup', iconName: 'utility:table' },
        { label: 'Display Text', value: 'heading', iconName: 'utility:text' },
        { label: 'Image', value: 'image', iconName: 'utility:image' }
    ];

    editorElementTypeOptions = [
        ...this.inputFieldOptions,
        ...this.specialElementOptions,
        { label: 'Ranking', value: 'ranking' },
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

    buttonDestinationTypeOptions = [
        { label: 'Another TwinaForms Form', value: 'form' },
        { label: 'External URL', value: 'external' }
    ];

    buttonExternalUrlModeOptions = [
        { label: 'URL Template', value: 'template' },
        { label: 'Formula URL', value: 'formula' }
    ];

    buttonParameterModeOptions = [
        { label: 'Field', value: 'template' },
        { label: 'Formula', value: 'formula' }
    ];

    languageOptions = [
        { label: 'English', value: 'en' },
        { label: 'Hebrew', value: 'he' },
        { label: 'Spanish', value: 'es' },
        { label: 'German', value: 'de' },
        { label: 'French', value: 'fr' }
    ];

    locationModeOptions = [
        { label: 'Country only', value: 'country' },
        { label: 'Country + State/Region', value: 'countryRegion' },
        { label: 'Country + City', value: 'countryCity' },
        { label: 'Country + State/Region + City', value: 'countryRegionCity' }
    ];

    locationLayoutOptions = [
        { label: 'Stacked', value: 'stacked' },
        { label: 'Inline', value: 'inline' }
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

    timeFormatOptions = [
        { label: '24-hour (19:00)', value: '24h' },
        { label: '12-hour (8:00 PM)', value: '12h' }
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
        { label: '4', value: '4' },
        { label: '5', value: '5' },
        { label: '6', value: '6' },
        { label: '7', value: '7' },
        { label: '8', value: '8' },
        { label: '9', value: '9' },
        { label: '10', value: '10' }
    ];

    repeatLabelModeOptions = [
        { label: 'Each row labels', value: 'eachRow' },
        { label: 'Table header only on desktop', value: 'tableHeader' }
    ];

    connectedCallback() {
        this.selectedProjectId = this.loadStoredProjectId();
        this.selectedFormId = this.loadStoredFormId();
        this.selectedVersionId = this.loadStoredVersionId();
        this.formSortMode = this.loadStoredFormSortMode();
        this.loadSalesforceObjectOptions();
        this.loadWorkspace(this.selectedProjectId, this.selectedFormId, this.selectedVersionId);
    }

    get selectedElement() {
        if (this.selectedElementId === USER_VERIFICATION_ELEMENT_ID) {
            return this.buildUserVerificationCanvasElement();
        }
        if (this.selectedElementId === SUBMIT_BUTTON_ELEMENT_ID) {
            return this.buildSubmitButtonCanvasElement();
        }
        return this.elements.find((item) => item.id === this.selectedElementId);
    }

    get selectedElementFieldKey() {
        if (this.selectedElementIsSubmitButton || this.selectedElementIsUserVerification) {
            return '';
        }
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
        if (this.selectedElementIsUserVerification) {
            return 'User Verification';
        }
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
        const backgroundStart = this.safeValue(theme.backgroundColor, '#f3f7fb');
        const backgroundEnd = this.safeValue(theme.backgroundGradientColor, backgroundStart);
        return [
            `--nf-theme-page-bg:${backgroundStart}`,
            `--nf-theme-page-bg-gradient:${backgroundEnd}`,
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

    get designerFormSurfaceClass() {
        return `designer-form-surface${this.draftRtlEnabled ? ' designer-form-surface--rtl' : ''}`;
    }

    get designerFormDirection() {
        return this.draftRtlEnabled ? 'rtl' : 'ltr';
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

    get showPublishResult() {
        return !!this.publishResult
            && (!this.publishResultContextVersionId || this.publishResultContextVersionId === this.selectedVersionId);
    }

    get showPublishFormButton() {
        return !this.errorMessage
            && !this.showFormLimitWarning
            && !(this.publishResult && this.publishResult.success !== true);
    }

    get defaultPostSubmitRedirectUrl() {
        return 'https://forms.twinaforms.com/formX/?param1=';
    }

    get newFormCreateDisabled() {
        const projectSelection = String(this.newFormProjectId || '').trim();
        const requiresNewProjectName = projectSelection === '__new__';
        return this.isCreatingForm
            || this.formLimitReached
            || !String(this.newFormDescription || '').trim()
            || (!projectSelection && !requiresNewProjectName)
            || (requiresNewProjectName && !String(this.newFormProjectName || '').trim());
    }

    get cloneFormDisabled() {
        return !this.selectedFormId || !this.selectedVersionId || this.isCloningForm;
    }

    get exportFormDisabled() {
        return !this.selectedFormId || !this.selectedVersionId || this.isExportingForm;
    }

    get importFormActionDisabled() {
        return this.isImportingForm;
    }

    get importFormConfirmDisabled() {
        return this.isInspectingFormImport
            || this.isImportingForm
            || !this.importPackageJson
            || !this.importPreview
            || this.importBlockingErrors.length > 0
            || (this.importRequiresThemeConflictChoice && !this.importThemeConflictChoice)
            || (!!this.importPreview?.importDecisionRequired && !this.importDecision)
            || (this.importWillCreateForm && this.formLimitReached);
    }

    get importHasPreview() {
        return !!this.importPreview;
    }

    get importWillCreateForm() {
        return this.importCreatesForm || this.importDecision === 'createNew';
    }

    get importDecisionRequired() {
        return !!this.importPreview?.importDecisionRequired;
    }

    get importDecisionOptions() {
        return this.importPreview?.importDecisionOptions || [
            { label: 'Update existing form', value: 'updateExisting' },
            { label: 'Import as a new form', value: 'createNew' }
        ];
    }

    get showImportProjectPicker() {
        return this.importHasPreview && this.importWillCreateForm;
    }

    get importModalInstruction() {
        if (this.isInspectingFormImport) {
            return 'Checking import file...';
        }
        if (this.importHasPreview) {
            return 'Review the import result before creating the draft.';
        }
        return this.importStatusMessage || 'Choose a JSON export file or import a published form from a connected org.';
    }
    get showImportSourcePicker() {
        return this.showImportFormModal && !this.importHasPreview;
    }

    get connectedOtherOrgs() {
        const currentOrgId = this.normalizeConnectedOrgId(this.connectedImportView?.orgId);
        return (this.connectedImportView?.orgs || []).filter((org) => {
            const orgId = this.normalizeConnectedOrgId(org?.orgId || org?.connectedOrgId || org?.sourceOrgId || org?.targetOrgId);
            return orgId && orgId !== currentOrgId;
        });
    }

    get hasConnectedOtherOrgs() {
        return this.connectedOtherOrgs.length > 0;
    }

    get hasConnectedSnapshots() {
        return Array.isArray(this.connectedSnapshots) && this.connectedSnapshots.length > 0;
    }

    get connectedOrgFormsHeading() {
        const names = this.connectedOtherOrgs
            .map((org) => org?.orgName || org?.name || org?.orgId)
            .filter((name) => !!name);
        if (names.length === 1) {
            return `Connected Org Forms: ${names[0]}`;
        }
        if (names.length > 1) {
            return `Connected Org Forms: ${names.join(', ')}`;
        }
        return 'Connected Org Forms';
    }

    get connectedImportStatusMessage() {
        if (this.isLoadingConnectedImportSources) {
            return 'Loading connected org forms...';
        }
        if (this.connectedImportError) {
            return this.connectedImportError;
        }
        if (this.connectedImportView?.success === true && !this.hasConnectedOtherOrgs) {
            return 'No connected orgs yet. Connect another org from TwinaForms Setup, then return here to import its published forms.';
        }
        if (this.connectedImportView?.success === true && !this.hasConnectedSnapshots) {
            return 'Connected orgs exist, but no published forms are available yet. Publish a form in a connected org, then refresh this import list.';
        }
        return '';
    }

    get connectedSnapshotActionDisabled() {
        return this.isLoadingConnectedSnapshot || this.isInspectingFormImport || this.isImportingForm;
    }
    normalizeConnectedOrgId(value) {
        return String(value || '').trim().substring(0, 15);
    }

    get importCreatesForm() {
        return this.importPreview?.targetAction === 'createForm';
    }

    get importTargetFormLabel() {
        const formKey = this.importPreview?.globalFormKey || 'form';
        const formName = this.importPreview?.targetFormName || '';
        return formName ? `${formKey} - ${formName}` : formKey;
    }

    get importTargetsCurrentForm() {
        return !!this.importPreview?.targetFormId && this.importPreview.targetFormId === this.selectedFormId;
    }

    get importTargetsDifferentExistingForm() {
        return !!this.importPreview?.targetFormId && !this.importTargetsCurrentForm;
    }

    get importTargetMessageClass() {
        if (this.importWillCreateForm) {
            return 'designer-portable-import-result__target designer-portable-import-result__target--neutral';
        }
        if (this.importTargetsCurrentForm) {
            return 'designer-portable-import-result__target designer-portable-import-result__target--success';
        }
        return 'designer-portable-import-result__target designer-portable-import-result__target--danger';
    }

    get importTargetNoticeClass() {
        if (this.importTargetsDifferentExistingForm) {
            return 'designer-portable-import-result__notice designer-portable-import-result__notice--danger';
        }
        if (this.importTargetsCurrentForm) {
            return 'designer-portable-import-result__notice designer-portable-import-result__notice--success';
        }
        return 'designer-portable-import-result__notice designer-portable-import-result__notice--neutral';
    }

    get importPrimaryMessage() {
        if (!this.importPreview) {
            return '';
        }
        if (this.importWillCreateForm) {
            if (this.importDecision === 'createNew' && this.importPreview?.targetFormId) {
                return 'This import will create a separate new form with a new local public key.';
            }
            return `This import will create a new form: "${this.importTargetFormLabel}".`;
        }
        if (this.importTargetsCurrentForm) {
            return `This import will create a new Draft version for the current form: "${this.importTargetFormLabel}".`;
        }
        return `This import will create a new Draft version for a different existing form: "${this.importTargetFormLabel}".`;
    }

    get importPreviewSummary() {
        if (!this.importPreview) {
            return '';
        }
        if (this.importWillCreateForm) {
            if (this.importDecision === 'createNew' && this.importPreview?.targetFormId) {
                return 'The existing form will not be changed. TwinaForms will allocate a new public key for the imported form.';
            }
            return 'No existing form uses this form number, so TwinaForms will create a new form.';
        }
        if (this.importTargetsCurrentForm) {
            return 'You are currently viewing this form. The import will add a new Draft version to it.';
        }
        const currentKey = this.selectedFormKey || this.selectedFormName || 'the currently open form';
        return `You are viewing ${currentKey}, but this file imports into ${this.importPreview.globalFormKey}. The currently open form will not be changed.`;
    }

    get importBlockingErrors() {
        return this.importPreview?.blockingErrors || [];
    }

    get importWarnings() {
        return this.importPreview?.warnings || [];
    }

    get importAssetPreview() {
        return this.importPreview?.assetPreview || null;
    }

    get importAssetMessages() {
        return this.importAssetPreview?.messages || [];
    }

    get importAssetItems() {
        return this.importAssetPreview?.items || [];
    }

    get hasSingleImportAssetItem() {
        return this.importAssetItems.length === 1;
    }

    get hasMultipleImportAssetItems() {
        return this.importAssetItems.length > 1;
    }

    get importSingleAssetName() {
        return this.importAssetItems[0] || '';
    }

    get importAssetSummaryText() {
        const count = Number(this.importAssetPreview?.assetCount || this.importAssetItems.length || 0);
        if (count === 1) {
            return '1 image/logo file will be imported:';
        }
        return `${count} image/logo files will be imported:`;
    }

    get importAssetWarnings() {
        return this.importAssetPreview?.warnings || [];
    }

    get hasImportAssetPreview() {
        return !!this.importAssetPreview;
    }

    get hasImportAssetMessages() {
        return this.importAssetMessages.length > 0;
    }

    get hasImportAssetItems() {
        return this.importAssetItems.length > 0;
    }

    get hasImportAssetWarnings() {
        return this.importAssetWarnings.length > 0;
    }

    get importFeaturePreview() {
        return this.importPreview?.featurePreview || null;
    }

    get importFeatureMessages() {
        return this.importFeaturePreview?.messages || [];
    }

    get importFeatureLabels() {
        return this.importFeaturePreview?.featureLabels || [];
    }

    get importFeatureWarnings() {
        return this.importFeaturePreview?.warnings || [];
    }

    get hasImportFeaturePreview() {
        return !!this.importFeaturePreview;
    }

    get hasImportFeatureMessages() {
        return this.importFeatureMessages.length > 0;
    }

    get hasImportFeatureLabels() {
        return this.importFeatureLabels.length > 0;
    }

    get hasImportFeatureWarnings() {
        return this.importFeatureWarnings.length > 0;
    }
    get importThemePreview() {
        return this.importPreview?.themePreview || null;
    }

    get importThemeMessages() {
        return this.importThemePreview?.messages || [];
    }

    get importThemeWarnings() {
        return this.importThemePreview?.warnings || [];
    }

    get hasImportThemePreview() {
        return !!this.importThemePreview;
    }

    get hasImportThemeMessages() {
        return this.importThemeMessages.length > 0;
    }

    get hasImportThemeWarnings() {
        return this.importThemeWarnings.length > 0;
    }

    get importRequiresThemeConflictChoice() {
        return this.importThemePreview?.requiresAdminChoice === true;
    }

    get importThemeConflictOptions() {
        return [
            { label: 'Create imported copy', value: 'createCopy' },
            { label: 'Reuse existing theme', value: 'reuseExisting' }
        ];
    }

    get importMissingObjects() {
        return this.importPreview?.missingObjects || [];
    }

    get importMissingFields() {
        return this.importPreview?.missingFields || [];
    }

    get hasImportBlockingErrors() {
        return this.importBlockingErrors.length > 0;
    }

    get hasImportWarnings() {
        return this.importWarnings.length > 0;
    }

    get hasImportMissingObjects() {
        return this.importMissingObjects.length > 0;
    }

    get hasImportMissingFields() {
        return this.importMissingFields.length > 0;
    }

    get importProjectOptions() {
        return [{ label: 'Default General project', value: '__default__' }].concat(this.projectOptions || []);
    }

    get inspectImportTextDisabled() {
        return this.isInspectingFormImport || this.isImportingForm || !String(this.importRawJsonText || '').trim();
    }
    get newFormActionDisabled() {
        return this.formLimitReached || this.isCreatingForm;
    }

    get cloneFormCreateDisabled() {
        const projectSelection = String(this.cloneFormProjectId || '').trim();
        const requiresNewProjectName = projectSelection === '__new__';
        return this.isCloningForm
            || this.formLimitReached
            || !this.selectedFormId
            || !this.selectedVersionId
            || !String(this.cloneFormDescription || '').trim()
            || (!projectSelection && !requiresNewProjectName)
            || (requiresNewProjectName && !String(this.cloneFormProjectName || '').trim());
    }

    get createProjectDisabled() {
        return this.isCreatingProject || !String(this.newProjectName || '').trim();
    }

    get selectedVersionOption() {
        return (this.versionOptions || []).find((option) => option.value === this.selectedVersionId) || null;
    }

    get selectedVersionIsPublished() {
        return this.selectedVersionOption?.isPublished === true;
    }

    get showRestorePublishedAction() {
        return this.selectedVersionIsPublished;
    }

    get restorePublishedDisabled() {
        return !this.selectedFormId || !this.selectedVersionId || !this.selectedVersionIsPublished || this.isRestoringPublished;
    }

    get layoutImportDisabled() {
        return !this.enableProPageLayoutClone || this.isImportingLayout;
    }

    get layoutImportCreateDisabled() {
        const projectSelection = String(this.layoutImportProjectId || '').trim();
        const requiresNewProjectName = projectSelection === '__new__';
        return this.isImportingLayout
            || this.isLoadingLayoutMetadata
            || this.formLimitReached
            || !this.enableProPageLayoutClone
            || !String(this.layoutImportDescription || '').trim()
            || !String(this.layoutImportLanguageCode || '').trim()
            || !String(this.layoutImportObjectApiName || '').trim()
            || !String(this.layoutImportLayoutKey || '').trim()
            || !this.layoutImportPreview
            || (!projectSelection && !requiresNewProjectName)
            || (requiresNewProjectName && !String(this.layoutImportProjectName || '').trim());
    }

    get layoutImportLayoutSourceDisabled() {
        return this.formLimitReached
            || this.isLoadingLayoutMetadata
            || !String(this.layoutImportLanguageCode || '').trim()
            || !String(this.layoutImportObjectApiName || '').trim()
            || !this.layoutImportLayoutOptions?.length;
    }

    get showLayoutImportProjectNameInput() {
        return this.layoutImportProjectId === '__new__';
    }

    get layoutImportProjectOptions() {
        return this.newFormProjectOptions;
    }

    get layoutImportModeOptions() {
        return [
            { label: 'Secure edit or create if missing', value: 'secureUpdateOrCreate' },
            { label: 'Secure edit existing record only', value: 'secureUpdate' },
            { label: 'Create new record only', value: 'create' }
        ];
    }

    get layoutImportPreviewSummary() {
        if (!this.layoutImportPreview) {
            return '';
        }
        const supported = this.layoutImportPreview.supportedFieldCount || 0;
        const skipped = this.layoutImportPreview.skippedFieldCount || 0;
        const createOnly = this.layoutImportPreview.createOnlyFieldCount || 0;
        const createOnlyText = createOnly ? ` ${createOnly} fields are create-only.` : '';
        return `${supported} fields will be imported. ${skipped} fields will be skipped.${createOnlyText}`;
    }

    get layoutImportWarnings() {
        return this.layoutImportPreview?.warnings || [];
    }

    get layoutImportResultTitle() {
        const objectLabel = this.layoutImportResult?.objectLabel || this.layoutImportResult?.objectApiName || 'Salesforce Object';
        return `Form Created From ${objectLabel} Layout`;
    }

    get layoutImportResultSummary() {
        const summary = this.layoutImportResult?.summary || {};
        const imported = summary.importedFieldCount || 0;
        const skipped = summary.skippedFieldCount || 0;
        const createOnly = summary.createOnlyFieldCount || 0;
        return `${imported} fields imported. ${createOnly} create-only. ${skipped} skipped.`;
    }

    get layoutImportResultIncludedNotes() {
        return this.layoutImportResult?.includedNotes || [];
    }

    get layoutImportResultSkippedFields() {
        return this.layoutImportResult?.skippedFields || [];
    }

    get layoutImportResultWarnings() {
        return this.layoutImportResult?.warnings || [];
    }

    get hasLayoutImportResultIncludedNotes() {
        return this.layoutImportResultIncludedNotes.length > 0;
    }

    get hasLayoutImportResultSkippedFields() {
        return this.layoutImportResultSkippedFields.length > 0;
    }

    get hasLayoutImportResultWarnings() {
        return this.layoutImportResultWarnings.length > 0;
    }

    get showFormLimitWarning() {
        return this.formLimitReached && !!this.formLimitMessage;
    }

    get formLimitUsageLabel() {
        return this.maxForms == null
            ? `${this.currentFormCount || 0} forms`
            : `${this.currentFormCount || 0} / ${this.maxForms} forms`;
    }

    get showNewProjectNameInput() {
        return this.newFormProjectId === '__new__';
    }

    get showCloneProjectNameInput() {
        return this.cloneFormProjectId === '__new__';
    }

    get newFormProjectOptions() {
        return (this.projectOptions || []).concat([
            { label: '+ Create New Project', value: '__new__' }
        ]);
    }

    get cloneFormProjectOptions() {
        return this.newFormProjectOptions;
    }

    get isSelectedVersionReadOnly() {
        return this.selectedVersionStatus === 'Published';
    }

    get publishDisabled() {
        return !this.selectedVersionId || this.isSelectedVersionReadOnly;
    }

    get undoDisabled() {
        return this.isUndoing
            || this.isSelectedVersionReadOnly
            || !this.selectedVersionId
            || !(this.undoStack || []).length;
    }

    get undoLabel() {
        const count = (this.undoStack || []).length;
        return count > 1 ? `Undo (${count})` : 'Undo';
    }

    get hasCanvasElements() {
        return this.canvasElements.length > 0;
    }

    get hasFormOptions() {
        return (this.formOptions || []).length > 0;
    }
    get formSortIconName() {
        return this.formSortMode === 'nameDesc' || this.formSortMode === 'numberDesc'
            ? 'utility:sort_descending'
            : 'utility:sort_ascending';
    }

    get formSortButtonAlternativeText() {
        const labels = {
            nameAsc: 'Sort forms by name A-Z',
            nameDesc: 'Sort forms by name Z-A',
            numberAsc: 'Sort forms by form number low-high',
            numberDesc: 'Sort forms by form number high-low'
        };
        return labels[this.formSortMode] || labels.nameAsc;
    }

    get formSortNameAscChecked() {
        return this.formSortMode === 'nameAsc';
    }

    get formSortNameDescChecked() {
        return this.formSortMode === 'nameDesc';
    }

    get formSortNumberAscChecked() {
        return this.formSortMode === 'numberAsc';
    }

    get formSortNumberDescChecked() {
        return this.formSortMode === 'numberDesc';
    }

    get hasVersionOptions() {
        return (this.versionOptions || []).length > 0;
    }

    get disableFormSelector() {
        return !this.hasFormOptions;
    }

    get disableVersionSelector() {
        return !this.hasVersionOptions;
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

    get selectedElementIsSubmitButton() {
        return this.selectedElement?.elementType === 'submitButton';
    }

    get selectedElementIsButton() {
        return this.editorElementType === 'button';
    }

    get selectedElementIsSpacer() {
        return this.editorElementType === 'spacer';
    }

    get selectedElementIsUserVerification() {
        return this.selectedElement?.elementType === 'userVerification';
    }

    get selectedElementIsGroup() {
        return this.selectedElement?.elementType === 'group';
    }

    get selectedElementIsRepeatGroup() {
        return this.selectedElement?.elementType === 'repeatGroup';
    }

    get editorRepeatLabelMode() {
        return this.editorShowLabelsOnEachRow ? 'eachRow' : 'tableHeader';
    }

    get selectedElementIsContainer() {
        return this.selectedElementIsSection || this.selectedElementIsGroup || this.selectedElementIsRepeatGroup;
    }

    get selectedElementCanClone() {
        return ['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'location', 'radio', 'ranking', 'fileUpload', 'signature'].includes(this.selectedElement?.elementType);
    }

    get cloneFieldDisabled() {
        return !this.selectedElementCanClone || this.isSelectedVersionReadOnly || this.isCloningField || this.isLoading || this.isUndoing;
    }

    async handleCloneField() {
        if (this.cloneFieldDisabled) return;
        // Capture current property drafts before selection or pending saves can change the panel.
        this.applyEditorDraft(false);
        const source = this.selectedElement;
        const inputJson = JSON.stringify({ id: source.id, label: source.label, fieldKey: source.fieldKey, elementType: source.elementType, configJson: source.configJson });
        const projectId = this.selectedProjectId;
        const formId = this.selectedFormId;
        const versionId = this.selectedVersionId;
        this.isCloningField = true;
        this.errorMessage = '';
        let undoStep;
        try {
            await Promise.all(this.pendingVisualSavePromises);
            undoStep = this.captureUndoStep('Clone field');
            const created = await cloneField({ inputJson });
            await this.loadWorkspace(projectId, formId, versionId, true);
            this.selectedElementId = created.id;
            this.syncSelectedState();
        } catch (error) {
            this.removeUndoStep(undoStep);
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isCloningField = false;
        }
    }

    get showColumnLayoutPicker() {
        return this.selectedElementIsContainer && Number(this.editorColumns || 1) > 1;
    }

    get columnLayoutOptions() {
        const columns = Number(this.editorColumns || 1);
        let definitions = [{ value: 'equal', label: 'Equal', thumbnailClass: 'column-layout-thumb column-layout-thumb--equal' }];
        if (columns === 2) {
            definitions = [
                definitions[0],
                { value: 'narrowFirst', label: 'Narrow first', thumbnailClass: 'column-layout-thumb column-layout-thumb--narrow-first' },
                { value: 'wideFirst', label: 'Wide first', thumbnailClass: 'column-layout-thumb column-layout-thumb--wide-first' }
            ];
        } else if (columns === 3) {
            definitions = [
                definitions[0],
                { value: 'wideFirst', label: 'Wide first', thumbnailClass: 'column-layout-thumb column-layout-thumb--wide-first' },
                { value: 'wideMiddle', label: 'Wide middle', thumbnailClass: 'column-layout-thumb column-layout-thumb--wide-middle' },
                { value: 'wideLast', label: 'Wide last', thumbnailClass: 'column-layout-thumb column-layout-thumb--wide-last' }
            ];
        }
        return definitions.map((option) => ({
            ...option,
            selected: option.value === this.editorColumnLayout,
            className: `column-layout-option${option.value === this.editorColumnLayout ? ' column-layout-option--selected' : ''}`
        }));
    }

    get availableDisplayElementOptions() {
        return this.displayElementOptions.filter((option) => {
            if (option.value === 'repeatGroup') {
                return this.enableProRepeatGroups;
            }
            if (option.value === 'button') {
                return this.enableProButtonElements;
            }
            if (option.value === 'location') {
                return this.enableProLocationFields;
            }
            return true;
        });
    }

    get buttonDestinationIsForm() {
        return this.editorButtonDestinationType === 'form';
    }

    get buttonDestinationIsExternal() {
        return !this.buttonDestinationIsForm;
    }

    get buttonExternalUrlUsesFormula() {
        return this.editorButtonExternalUrlMode === 'formula';
    }

    get availableInputFieldOptions() {
        return this.inputFieldOptions.filter((option) => {
            if (option.value === 'fileUpload') {
                return this.enableProLoadFile;
            }
            if (option.value === 'signature') {
                return this.enableProElectronicSignature;
            }
            if (option.value === 'button') {
                return this.enableProButtonElements;
            }
            return true;
        });
    }

    get availableSurveyFieldOptions() {
        return this.enableProSurveyFields ? this.surveyFieldOptions : [];
    }

    get showSurveyFieldOptions() {
        return this.availableSurveyFieldOptions.length > 0;
    }

    get availableEditorElementTypeOptions() {
        const allowedInputTypes = new Set([
            ...this.availableInputFieldOptions.map((option) => option.value),
            ...this.availableSpecialElementOptions.map((option) => option.value),
            ...this.availableSurveyFieldOptions.map((option) => option.value)
        ]);
        return this.editorElementTypeOptions.filter((option) => {
            if (this.inputFieldOptions.some((inputOption) => inputOption.value === option.value)
                || this.specialElementOptions.some((specialOption) => specialOption.value === option.value)) {
                return allowedInputTypes.has(option.value);
            }
            if (option.value === 'ranking') {
                return this.enableProSurveyFields;
            }
            if (option.value === 'button') {
                return this.enableProButtonElements || this.selectedElementIsButton;
            }
            if (option.value === 'location') {
                return this.enableProLocationFields || this.selectedElementIsLocation;
            }
            if (option.value === 'mergedDocument') {
                return this.enableProMergedDocument || this.selectedElementIsMergedDocument;
            }
            return option.value !== 'repeatGroup' || this.enableProRepeatGroups;
        });
    }

    get selectedElementSupportsLabelPosition() {
        return ['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'location', 'radio', 'ranking', 'fileUpload', 'signature'].includes(this.editorElementType);
    }

    get selectedElementSupportsDefaultValue() {
        return ['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'radio'].includes(this.editorElementType)
            && !this.editorUseFormula;
    }

    get selectedElementSupportsPlaceholder() {
        return ['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'lookup'].includes(this.editorElementType);
    }

    get selectedElementSupportsBoldLabel() {
        return ['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'location', 'radio', 'ranking', 'fileUpload', 'signature'].includes(this.editorElementType);
    }

    get selectedElementSupportsRequired() {
        return ['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'location', 'radio', 'ranking', 'fileUpload', 'signature'].includes(this.editorElementType);
    }

    get selectedElementSupportsFieldBehavior() {
        return ['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'location', 'radio', 'ranking', 'section', 'group'].includes(this.editorElementType);
    }

    get selectedElementSupportsDisplayFieldBehavior() {
        return this.editorElementType === 'section' || this.editorElementType === 'group';
    }

    get selectedElementSupportsBehaviorFieldBehavior() {
        return this.selectedElementSupportsFieldBehavior && !this.selectedElementSupportsDisplayFieldBehavior;
    }

    get selectedElementIsDisplayText() {
        return this.editorElementType === 'heading';
    }

    get selectedElementIsMergedDocument() {
        return this.editorElementType === 'mergedDocument';
    }

    get selectedElementIsRichTextDisplay() {
        return this.selectedElementIsDisplayText || this.selectedElementIsMergedDocument;
    }

    get selectedElementIsImage() {
        return this.editorElementType === 'image';
    }

    get selectedElementIsFileUpload() {
        return this.editorElementType === 'fileUpload';
    }

    get selectedElementIsSignature() {
        return this.editorElementType === 'signature';
    }

    get selectedElementIsPicklist() {
        return this.editorElementType === 'select';
    }

    get selectedElementIsTextarea() {
        return this.editorElementType === 'textarea';
    }

    get selectedElementIsMultiCheckbox() {
        return this.editorElementType === 'multiCheckbox';
    }

    get selectedElementIsLookup() {
        return this.editorElementType === 'lookup';
    }

    get selectedElementIsLocation() {
        return this.editorElementType === 'location';
    }

    get selectedElementIsCheckbox() {
        return this.editorElementType === 'checkbox';
    }

    get selectedElementIsRadio() {
        return this.editorElementType === 'radio';
    }

    get selectedElementIsRanking() {
        return this.editorElementType === 'ranking';
    }

    get selectedElementPresentation() {
        return this.parseConfig(this.selectedElement?.configJson).presentation || '';
    }

    get selectedElementIsSurveyRadio() {
        return this.selectedElementIsRadio && ['stars', 'nps', 'likert', 'satisfaction'].includes(this.selectedElementPresentation);
    }

    get selectedElementSupportsSurveyChoices() {
        return this.selectedElementIsRanking || this.selectedElementIsSurveyRadio;
    }

    get surveyChoicesTitle() {
        return this.selectedElementIsRanking ? 'Ranking Choices' : 'Survey Choices';
    }

    get surveyChoicesHelpText() {
        return this.selectedElementIsRanking
            ? 'Edit the choices respondents will rank. Respondents move choices up or down, and TwinaForms saves the ordered values.'
            : 'Edit the labels and saved values for this survey field.';
    }

    get canDeleteSurveyChoice() {
        return (this.editorSurveyOptions || []).length > 1;
    }

    get cannotDeleteSurveyChoice() {
        return !this.canDeleteSurveyChoice;
    }

    get selectedElementUsesSalesforcePicklistSource() {
        return this.selectedElementIsPicklist || this.selectedElementIsMultiCheckbox || (this.selectedElementIsRadio && !this.selectedElementIsSurveyRadio);
    }

    get checkboxDefaultValueOptions() {
        return [
            { label: 'False', value: 'false' },
            { label: 'True', value: 'true' }
        ];
    }

    get selectedElementUsesDefaultValueHelp() {
        return this.editorElementType === 'checkbox' || this.editorElementType === 'radio' || this.editorElementType === 'multiCheckbox';
    }

    get defaultValueHelpText() {
        if (this.editorElementType === 'checkbox') {
            return 'Use true or false to control whether the checkbox starts checked.';
        }
        if (this.editorElementType === 'radio') {
            return 'Use the exact Salesforce picklist value to preselect a radio choice.';
        }
        if (this.editorElementType === 'multiCheckbox') {
            return 'Use Salesforce values separated by semicolons, for example A;B;C.';
        }
        return '';
    }

    get selectedElementSupportsConditional() {
        return this.editorElementType !== 'repeatGroup';
    }

    get submitButtonUsesConditionalValue() {
        const first = this.draftSubmitConditionalConditions?.[0];
        return this.conditionUsesValue(first?.operator || this.draftSubmitConditionalOperator);
    }

    get selectedElementSupportsSalesforceMapping() {
        return ['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'location', 'radio', 'ranking'].includes(this.editorElementType);
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

    get selectedSignatureInsideRepeatGroup() {
        return this.selectedElementIsSignature && this.selectedElementIsInsideRepeatGroup;
    }

    get submissionPdfRequiredByRecordsListSignature() {
        const recordsListIds = new Set(
            (this.elements || [])
                .filter((item) => item.elementType === 'repeatGroup')
                .map((item) => item.elementId)
        );
        return (this.elements || []).some((item) =>
            item.elementType === 'signature' && recordsListIds.has(item.parentElementId)
        );
    }

    get selectedButtonInsideRepeatGroup() {
        return this.selectedElementIsButton && this.selectedElementIsInsideRepeatGroup;
    }

    get selectedRepeatGroupHint() {
        const parent = this.selectedRepeatGroupParent;
        if (!parent) {
            return '';
        }
        const parentConfig = this.parseConfig(parent.configJson);
        const sourceText = parentConfig.repeatSourceAlias
            ? `Source: ${parentConfig.repeatSourceAlias}.`
            : 'No source alias is set.';
        const saveText = parentConfig.repeatSubmitActionKey
            ? `Save: ${this.repeatSubmitAliasLabel(parentConfig.repeatSubmitActionKey)}.`
            : 'No submit alias is set.';
        return `This field belongs to Records List "${parent.label}". ${sourceText} ${saveText}`;
    }

    get selectedRepeatGroupSourceWarning() {
        if (!this.selectedElementIsRepeatGroup || this.editorRepeatSourceAlias || this.editorRepeatSubmitActionKey) {
            return '';
        }
        return this.repeatGroupHasRowFields(this.selectedElement)
            ? 'This Records List has row fields, but no Prefill Alias or Submit Alias.'
            : '';
    }

    get selectedElementSupportsRangeValidation() {
        return ['number', 'date'].includes(this.editorElementType);
    }

    get selectedElementIsNumber() {
        return this.editorElementType === 'number';
    }

    get selectedElementSupportsFormula() {
        return this.enableProFormulaFields
            && ['text', 'number'].includes(this.editorElementType);
    }

    get showFormulaSettings() {
        return this.selectedElementSupportsFormula;
    }

    get formulaPreviewText() {
        if (this.selectedElementIsNumber) {
            return this.editorFormulaPreviewValue === null || this.editorFormulaPreviewValue === undefined
                ? ''
                : String(this.editorFormulaPreviewValue);
        }
        return this.editorFormulaPreviewValue || '';
    }

    get formulaStatusText() {
        return (this.editorFormulaExpression || '').trim()
            ? 'Formula configured.'
            : 'No formula configured.';
    }

    get formulaButtonLabel() {
        return (this.editorFormulaExpression || '').trim()
            ? 'Edit Formula'
            : 'Add Formula';
    }

    get modalFormulaPreviewText() {
        if (this.selectedElementIsNumber) {
            return this.modalFormulaPreviewValue === null || this.modalFormulaPreviewValue === undefined
                ? ''
                : String(this.modalFormulaPreviewValue);
        }
        return this.modalFormulaPreviewValue || '';
    }

    get formulaHelpTooltip() {
        return [
            'Supported functions:',
            'Text: CONCAT(...), LEFT(...), RIGHT(...), MID(text, start, length),',
            '  LEN(...), TRIM(...), UPPER(...), LOWER(...),',
            '  SUBSTITUTE(text, old, new), CONTAINS(text, find), BEGINS(text, find),',
            '  TEXT(...), URLENCODE(...)',
            'Logic: IF(...), AND(...), OR(...), NOT(...), COALESCE(...), ISBLANK(...)',
            'Number: VALUE(...), ROUND(...), ABS(...), MIN(...), MAX(...),',
            '  MOD(value, divisor), CEILING(...), FLOOR(...), POWER(base, exp), SQRT(...)',
            'Date: TODAY(), NOW(), YEAR(...), MONTH(...), DAY(...),',
            '  WEEKDAY(date) 1=Sunday..7=Saturday, DAYNAME(date) in the form language,',
            '  DATE(year, month, day), ADDMONTHS(date, months), DATEVALUE(...)',
            '',
            'Use field references like {text1} or {number1}.',
            'Inside Records Lists, use same-row references like {row.quantity}.',
            'Only Text and Number fields can be formula targets in V1.'
        ].join('\n');
    }

    get formulaHelpUrl() {
        return 'https://twinaforms.com/help/formulas';
    }

    get customJsHelpUrl() {
        return 'https://twinaforms.com/help/custom-javascript';
    }

    get customJsHelpText() {
        return [
            'Run supported TwinaForms custom JavaScript in the published form runtime.',
            'Use TwinaForms.getValue(...), TwinaForms.setValue(...), and TwinaForms.on(...).',
            'This is a Pro feature and only runs on published forms for versions with saved code.'
        ].join('\n');
    }

    get customJsStatusText() {
        return this.draftCustomJs && this.draftCustomJs.trim()
            ? 'Configured on this form version.'
            : 'No custom JavaScript is configured on this form version.';
    }

    get customJsButtonLabel() {
        return this.draftCustomJs && this.draftCustomJs.trim()
            ? 'Edit Custom JavaScript'
            : 'Add Custom JavaScript';
    }

    get customJsFallbackClass() {
        return 'slds-textarea designer-custom-js-textarea';
    }

    get deleteFormConfirmationValue() {
        return this.selectedFormName || this.selectedFormKey || '';
    }

    get deleteFormConfirmationHelpText() {
        const expectedValue = this.deleteFormConfirmationValue;
        return expectedValue
            ? `Type "${expectedValue}" to confirm.`
            : 'Type the form name or form key to confirm.';
    }

    get deleteFormDisabled() {
        return this.isDeletingForm
            || !this.selectedFormId
            || !String(this.deleteFormConfirmText || '').trim();
    }

    get deleteFormWarningText() {
        return 'This permanently deletes the form from Designer, including versions, fields, Prefill actions, and Submit actions. Published links will stop working. Existing submission logs are kept according to your plan retention settings. This cannot be undone.';
    }

    get formulaFieldTokenOptions() {
        const selectedRepeatGroup = this.selectedElementIsInsideRepeatGroup
            ? this.findRepeatGroupAncestor(this.selectedElement)
            : null;
        const eligibleTypes = ['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'radio', 'ranking', 'hidden'];
        const options = [];
        (this.elements || []).forEach((item) => {
            if (!item?.fieldKey || item.id === this.selectedElementId || !eligibleTypes.includes(item.elementType)) {
                return;
            }
            const config = this.parseConfig(item.configJson);
            if (config.isFormula === true) {
                return;
            }
            const itemRepeatGroup = item.parentElementId ? this.findRepeatGroupAncestor(item) : null;
            if (itemRepeatGroup) {
                if (!selectedRepeatGroup || itemRepeatGroup.elementId !== selectedRepeatGroup.elementId) {
                    return;
                }
                options.push({
                    label: `Row: ${item.label} (${item.fieldKey})`,
                    value: `{row.${item.fieldKey}}`
                });
                return;
            }
            options.push({
                label: `${item.label} (${item.fieldKey})`,
                value: `{${item.fieldKey}}`
            });
        });
        return [{ label: 'Insert field', value: '' }].concat(options);
    }

    get lookupSearchFieldOptionsForEditor() {
        return [{ label: 'Select record field', value: '' }].concat(
            this.mergeSelectedOptions(this.lookupSearchFieldOptions, this.editorLookupSearchFields)
        );
    }

    get editorLookupSearchField() {
        return this.ensureEditorRows(this.editorLookupSearchFields, 'Name')[0] || 'Name';
    }

    get lookupSourceFieldOptionsForEditor() {
        return [{ label: 'Select record field', value: '' }].concat(
            this.mergeSelectedOptions(
                this.lookupDisplayFieldOptions,
                (this.editorLookupSetFields || []).map((mapping) => mapping.sourceField)
            )
        );
    }

    get lookupSetTargetFieldOptions() {
        const eligibleTypes = ['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'radio', 'ranking', 'hidden'];
        const selected = this.selectedElement;
        const selectedRepeatGroup = this.selectedElementIsInsideRepeatGroup
            ? this.findRepeatGroupAncestor(selected)
            : null;
        const selectedTargetValues = (this.editorLookupSetFields || []).map((mapping) => mapping.targetFieldKey);
        const options = (this.elements || [])
            .filter((item) => {
                if (!item?.fieldKey || item.id === this.selectedElementId || !eligibleTypes.includes(item.elementType)) {
                    return false;
                }
                const config = this.parseConfig(item.configJson);
                if (config.isFormula === true) {
                    return false;
                }
                const itemRepeatGroup = item.parentElementId ? this.findRepeatGroupAncestor(item) : null;
                if (selectedRepeatGroup) {
                    return !itemRepeatGroup || itemRepeatGroup.elementId === selectedRepeatGroup.elementId;
                }
                return !itemRepeatGroup;
            })
            .map((item) => ({
                label: `${item.parentElementId && this.findRepeatGroupAncestor(item) ? 'Row: ' : ''}${item.label || item.fieldKey} (${item.fieldKey})`,
                value: item.fieldKey
            }));
        return [{ label: 'Select form field', value: '' }].concat(
            this.mergeSelectedOptions(options, selectedTargetValues)
        );
    }

    get lookupSetFieldRows() {
        return (this.editorLookupSetFields || []).map((mapping, index) => ({
            ...mapping,
            key: `lookup-set-field-${index}`
        }));
    }

    get lookupCopyFieldsTitle() {
        const objectLabel = (this.salesforceObjectOptions || []).find((option) => option.value === this.editorLookupTargetObject)?.label;
        return objectLabel ? `Copy fields from selected ${objectLabel}` : 'Copy fields from selected record';
    }

    get lookupSearchFieldsHelpText() {
        return 'The Salesforce field users search by. Matching results show this field, and the form stores the selected record Id.';
    }

    get lookupCopyFieldsHelpText() {
        return 'When the user selects a lookup record, copy values from that record into other form fields. Inside a Records List, values are copied only into the same row.';
    }

    get formulaExpressionShellClass() {
        const hasError = this.showFieldFormulaModal ? this.modalFormulaError : this.editorFormulaError;
        return hasError
            ? 'formula-editor-shell formula-editor-shell--error'
            : 'formula-editor-shell';
    }

    get internalNameHelpText() {
        return 'Used in formulas, URL parameters, mappings, and advanced setup.';
    }

    get validationRulesHelpText() {
        return 'Applies built-in input checks before the form is submitted.';
    }

    get showConditionallyHelpText() {
        return 'Shows this field only when the conditions below are true.';
    }

    get conditionLogicHelpText() {
        return 'Use expressions like 1 AND 2, or 1 AND (2 OR 3).';
    }

    get dateTimezoneHelpText() {
        return 'Use this only if you need the date to be interpreted with a specific GMT offset.';
    }

    get timeFormatHelpText() {
        return 'Choose how users enter the time. TwinaForms stores and submits the value as HH:mm.';
    }

    get repeatSourceAliasHelpText() {
        return 'Loads Records List rows from a prefill result.';
    }

    get repeatSubmitAliasHelpText() {
        return 'Marks which Records List submit action saves these rows.';
    }

    get locationDefaultCountryHelpText() {
        return 'Preselects or prioritizes one country for autocomplete when the form loads. Enter a two-letter ISO code such as US, IL, or CA. Submitted Salesforce mappings still use country names.';
    }

    get locationAllowedCountriesHelpText() {
        return 'Limits autocomplete to these countries. Enter comma-separated two-letter ISO codes such as US, CA, IL. Leave empty to allow all countries. Submitted Salesforce mappings still use country names.';
    }

    get locationMinSearchLengthHelpText() {
        return 'How many characters the visitor must type before autocomplete starts. Two characters is recommended.';
    }

    get locationResultLimitHelpText() {
        return 'Maximum number of autocomplete results shown to the visitor. Ten is recommended; the maximum is 25.';
    }

    get salesforceIntegrationHelpText() {
        return 'Connect this field to Prefill and Submit actions.';
    }

    get enablePrefillHelpText() {
        return 'Loads a value into this field from a Prefill action.';
    }

    get prefillAliasHelpText() {
        return 'Choose which prefill result this field should read from.';
    }

    get enableSubmitHelpText() {
        return 'Sends this field?s value to a Submit action.';
    }

    get submitActionHelpText() {
        return 'Choose which saved-record action should receive this field?s value.';
    }

    get postSubmitRedirectHelpText() {
        return 'Sends the user to another form or URL after a successful submit.';
    }

    get postSubmitUrlHelpText() {
        return 'Set the destination URL after submit. Replace formX with the target form key. Example: https://forms.twinaforms.com/formX/?param1={{field.text1}}&param2={{field.text12}}';
    }

    get postSubmitFormulaHelpText() {
        return 'Use the same formula syntax as Formula Fields. The result must be blank or an absolute http:// or https:// URL.';
    }

    get buttonParameterFormulaHelpText() {
        return 'Use a formula to calculate the query parameter value. Reference fields such as {email}; Records List Buttons may also reference {row.contactId}.';
    }

    get postSubmitUrlModeIsFormula() {
        return this.draftPostSubmitUrlMode === 'formula';
    }

    get postSubmitUrlModeIsTemplate() {
        return !this.postSubmitUrlModeIsFormula;
    }

    get postSubmitFormulaPreviewText() {
        return this.draftPostSubmitUrlFormulaPreviewValue || '';
    }

    get postSubmitFormulaExpressionShellClass() {
        return this.modalPostSubmitUrlFormulaError
            ? 'formula-editor-shell formula-editor-shell--error'
            : 'formula-editor-shell';
    }

    get postSubmitFormulaStatusText() {
        return (this.draftPostSubmitUrlFormula || '').trim()
            ? 'Formula configured.'
            : 'No redirect formula configured.';
    }

    get postSubmitFormulaButtonLabel() {
        return (this.draftPostSubmitUrlFormula || '').trim()
            ? 'Edit Formula'
            : 'Add Formula';
    }

    get postSubmitModalFormulaPreviewText() {
        return this.modalPostSubmitUrlFormulaPreviewValue || '';
    }

    get insertFormFieldHelpText() {
        return 'Insert a token from this form into the redirect URL.';
    }

    get insertTokenButtonHelpText() {
        return 'Inserts the selected token at the current cursor position.';
    }

    get userVerificationEmailTemplateHelpText() {
        return 'Default Salesforce email template: TwinaForms User Verification Default. You can edit or replace it later in Salesforce.';
    }

    get userVerificationSenderEmailHelpText() {
        return 'Salesforce can only send from verified Org-Wide Email Addresses or authorized email domains. If this email is not authorized, Salesforce may reject the verification email.';
    }

    get userVerificationSenderEmailMessage() {
        return (this.draftUserVerificationSenderEmail || '').trim()
            ? ''
            : 'User Verification requires a sender email before publishing.';
    }

    get userVerificationExpiryHelpText() {
        return 'How many minutes the verification code stays valid.';
    }

    get userVerificationMaxAttemptsHelpText() {
        return 'Maximum number of code attempts allowed before the user must request a new one.';
    }

    get userVerificationAllowResendHelpText() {
        return 'Lets the user request another verification code if needed.';
    }

    get userVerificationSameTabSessionHelpText() {
        return 'Keeps the verified session after refresh in this browser tab until local midnight, capped at 12 hours.';
    }

    get draftUserVerificationKeepSessionUntilMidnight() {
        return this.draftUserVerificationSessionMode === 'sameTabUntilMidnight';
    }

    get projectNameHelpText() {
        return 'Creates a new project and places the new form inside it.';
    }

    labelPreviewClasses(item) {
        const classes = ['preview-field__label'];
        if (this.labelBold(item)) {
            classes.push('preview-field__label--bold');
        }
        if (this.labelItalic(item)) {
            classes.push('preview-field__label--italic');
        }
        if (this.labelUnderline(item)) {
            classes.push('preview-field__label--underline');
        }
        return classes.join(' ');
    }

    get selectedElementIsDate() {
        return this.editorElementType === 'date';
    }

    get selectedElementIsTime() {
        return this.editorElementType === 'time';
    }

    get selectedDateFormatHelpText() {
        return this.editorDateDisplayFormat === 'eu'
            ? 'Users will enter dates as DD/MM/YYYY.'
            : 'Users will enter dates as MM/DD/YYYY.';
    }

    get selectedTimeFormatHelpText() {
        return this.editorTimeFormat === '12h'
            ? 'Users enter time like 8:00 PM. TwinaForms submits it as HH:mm.'
            : 'Users enter time from 00:00 to 23:59.';
    }

    timePlaceholderForFormat(format) {
        return format === '12h' ? '8:00 PM' : '19:00';
    }

    parseTimeValue(value, format = '24h') {
        const raw = String(value || '').trim();
        if (!raw) {
            return null;
        }
        let match;
        if (format === '12h') {
            match = raw.match(/^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$/);
            if (!match) {
                return null;
            }
            let hours = Number(match[1]);
            const minutes = Number(match[2]);
            if (!Number.isInteger(hours) || !Number.isInteger(minutes) || hours < 1 || hours > 12 || minutes < 0 || minutes > 59) {
                return null;
            }
            const meridiem = match[3].toUpperCase();
            if (meridiem === 'AM' && hours === 12) {
                hours = 0;
            } else if (meridiem === 'PM' && hours < 12) {
                hours += 12;
            }
            return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
        }
        match = raw.match(/^(\d{1,2}):(\d{2})$/);
        if (!match) {
            return null;
        }
        const hours = Number(match[1]);
        const minutes = Number(match[2]);
        if (!Number.isInteger(hours) || !Number.isInteger(minutes) || hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
            return null;
        }
        return `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
    }

    formatTimeValue(value, format = '24h') {
        const normalized = this.parseTimeValue(value, '24h') || this.parseTimeValue(value, '12h');
        if (!normalized) {
            return value || '';
        }
        if (format !== '12h') {
            return normalized;
        }
        const [hourText, minuteText] = normalized.split(':');
        const hour24 = Number(hourText);
        const meridiem = hour24 >= 12 ? 'PM' : 'AM';
        const hour12 = hour24 % 12 || 12;
        return `${hour12}:${minuteText} ${meridiem}`;
    }

    get selectedElementSupportsTextValidation() {
        return ['text', 'textarea', 'email', 'tel', 'url'].includes(this.editorElementType);
    }

    get selectedElementUsesConditionalValue() {
        const first = this.editorConditionalConditions?.[0];
        return this.conditionUsesValue(first?.operator || this.editorConditionalOperator);
    }

    get showElementConditionExpression() {
        return this.enableProConditionLogic && (this.editorConditionalConditions || []).length > 1;
    }

    get showSubmitConditionExpression() {
        return this.enableProConditionLogic && (this.draftSubmitConditionalConditions || []).length > 1;
    }

    get canAddElementCondition() {
        return this.enableProConditionLogic || (this.editorConditionalConditions || []).length === 0;
    }

    get canAddSubmitCondition() {
        return this.enableProConditionLogic || (this.draftSubmitConditionalConditions || []).length === 0;
    }

    get editorConditionalRows() {
        return this.buildConditionRows(this.editorConditionalConditions || [], 'element');
    }

    get submitConditionalRows() {
        return this.buildConditionRows(this.draftSubmitConditionalConditions || [], 'submit');
    }

    get showPostSubmitAutoLinkSettings() {
        return this.enableProPostSubmitAutoLink;
    }

    get showSpecialElementOptions() {
        return this.enableProUserVerification || this.availableSpecialElementOptions.length > 0;
    }

    get showUserVerificationSpecialElement() {
        return this.enableProUserVerification;
    }

    get availableSpecialElementOptions() {
        return this.specialElementOptions.filter((option) => {
            if (option.value === 'location') {
                return this.enableProLocationFields;
            }
            if (option.value === 'mergedDocument') {
                return this.enableProMergedDocument;
            }
            return true;
        });
    }

    get userVerificationPaletteActionLabel() {
        return this.draftUserVerificationEnabled ? 'Added' : 'Add';
    }

    get userVerificationPaletteActionDisabled() {
        return this.isSelectedVersionReadOnly || this.draftUserVerificationEnabled;
    }

    userVerificationLanguageDefaults(languageCode = this.draftLanguageCode || this.selectedVersionLanguageCode || 'en') {
        switch ((languageCode || 'en').toLowerCase()) {
        case 'he':
            return {
                introText: '\u05d4\u05d6\u05d9\u05e0\u05d5 \u05d0\u05ea \u05d4\u05d0\u05d9\u05de\u05d9\u05d9\u05dc \u05d5\u05dc\u05d7\u05e6\u05d5 \u05e2\u05dc Enter. \u05e0\u05e9\u05dc\u05d7 \u05d0\u05dc\u05d9\u05db\u05dd \u05e7\u05d5\u05d3 \u05d1\u05df 6 \u05e1\u05e4\u05e8\u05d5\u05ea \u05dc\u05e4\u05e0\u05d9 \u05e9\u05ea\u05d5\u05db\u05dc\u05d5 \u05dc\u05d4\u05de\u05e9\u05d9\u05da.',
                sentMessage: '\u05d0\u05dd \u05de\u05e6\u05d0\u05e0\u05d5 \u05d0\u05d9\u05e9 \u05e7\u05e9\u05e8 \u05ea\u05d5\u05d0\u05dd, \u05e9\u05dc\u05d7\u05e0\u05d5 \u05e7\u05d5\u05d3 \u05d1\u05df 6 \u05e1\u05e4\u05e8\u05d5\u05ea \u05dc\u05d0\u05d9\u05de\u05d9\u05d9\u05dc \u05d4\u05d6\u05d4.',
                invalidMessage: '\u05d4\u05e7\u05d5\u05d3 \u05e9\u05d2\u05d5\u05d9 \u05d0\u05d5 \u05e9\u05e4\u05d2 \u05ea\u05d5\u05e7\u05e4\u05d5. \u05e0\u05e1\u05d5 \u05e9\u05d5\u05d1 \u05d0\u05d5 \u05d1\u05e7\u05e9\u05d5 \u05e7\u05d5\u05d3 \u05d7\u05d3\u05e9.',
                verifiedMessage: '\u05d4\u05e7\u05d5\u05d3 \u05d0\u05d5\u05de\u05ea. \u05d0\u05e4\u05e9\u05e8 \u05dc\u05d4\u05de\u05e9\u05d9\u05da \u05e2\u05dd \u05d4\u05d8\u05d5\u05e4\u05e1.',
                sendButtonLabel: '\u05e9\u05dc\u05d7',
                verifyButtonLabel: '\u05d0\u05de\u05ea',
                resendButtonLabel: '\u05e9\u05dc\u05d7 \u05e9\u05d5\u05d1 \u05e7\u05d5\u05d3'
            };
        case 'es':
            return {
                introText: 'Introduce tu correo y pulsa Entrar. Te enviaremos un c?digo de 6 d?gitos antes de continuar.',
                sentMessage: 'Si encontramos un contacto coincidente, enviamos un c?digo de 6 d?gitos a ese correo.',
                invalidMessage: 'El c?digo no es v?lido o ya expir?. Int?ntalo otra vez o solicita uno nuevo.',
                verifiedMessage: 'C?digo verificado. Ya puedes continuar con el formulario.',
                sendButtonLabel: 'Enviar',
                verifyButtonLabel: 'Verificar',
                resendButtonLabel: 'Reenviar c?digo'
            };
        case 'de':
            return {
                introText: 'Geben Sie Ihre E-Mail-Adresse ein und klicken Sie auf Eingabe. Wir senden Ihnen einen 6-stelligen Code, bevor Sie fortfahren k?nnen.',
                sentMessage: 'Wenn wir einen passenden Kontakt gefunden haben, senden wir einen 6-stelligen Code an diese E-Mail-Adresse.',
                invalidMessage: 'Der Code ist ung?ltig oder abgelaufen. Versuchen Sie es erneut oder fordern Sie einen neuen Code an.',
                verifiedMessage: 'Code best?tigt. Sie k?nnen jetzt mit dem Formular fortfahren.',
                sendButtonLabel: 'Senden',
                verifyButtonLabel: 'Best?tigen',
                resendButtonLabel: 'Code erneut senden'
            };
        case 'fr':
            return {
                introText: 'Saisissez votre adresse e-mail et cliquez sur Entr?e. Nous vous enverrons un code ? 6 chiffres avant de continuer.',
                sentMessage: 'Si nous trouvons un contact correspondant, nous envoyons un code ? 6 chiffres ? cette adresse e-mail.',
                invalidMessage: 'Le code est invalide ou a expir?. R?essayez ou demandez un nouveau code.',
                verifiedMessage: 'Code v?rifi?. Vous pouvez maintenant continuer le formulaire.',
                sendButtonLabel: 'Envoyer',
                verifyButtonLabel: 'V?rifier',
                resendButtonLabel: 'Renvoyer le code'
            };
        default:
            return {
                introText: 'Enter your email and click Enter. We will send you a 6-digit code before you can continue.',
                sentMessage: 'If we found a matching contact, we sent a 6-digit code to that email.',
                invalidMessage: 'The code is invalid or expired. Try again or request a new code.',
                verifiedMessage: 'Code verified. You can continue with the form now.',
                sendButtonLabel: 'Enter',
                verifyButtonLabel: 'Verify',
                resendButtonLabel: 'Resend Verification Number'
            };
        }
    }

    isDefaultUserVerificationValue(value, key) {
        const trimmedValue = String(value || '').trim();
        if (!trimmedValue) {
            return true;
        }
        return ['en', 'he', 'es', 'de', 'fr'].some((languageCode) => {
            const defaults = this.userVerificationLanguageDefaults(languageCode);
            return String(defaults[key] || '').trim() === trimmedValue;
        });
    }

    normalizeUserVerificationValue(value, key, languageCode = this.draftLanguageCode || this.selectedVersionLanguageCode || 'en') {
        const defaults = this.userVerificationLanguageDefaults(languageCode);
        const trimmedValue = String(value || '').trim();
        if (!trimmedValue || this.isDefaultUserVerificationValue(trimmedValue, key)) {
            return defaults[key] || '';
        }
        return trimmedValue;
    }

    fileUploadLanguageDefaults(languageCode = this.draftLanguageCode || this.selectedVersionLanguageCode || 'en') {
        switch ((languageCode || 'en').toLowerCase()) {
        case 'he':
            return {
                browseSingle: '\u05d1\u05d7\u05e8 \u05e7\u05d5\u05d1\u05e5',
                browseMultiple: '\u05d1\u05d7\u05e8 \u05e7\u05d1\u05e6\u05d9\u05dd',
                allowedTypes: '\u05e1\u05d5\u05d2\u05d9\u05dd \u05de\u05d5\u05ea\u05e8\u05d9\u05dd: {types}',
                maxSize: '\u05d2\u05d5\u05d3\u05dc \u05de\u05e7\u05e1\u05d9\u05de\u05dc\u05d9: {size} MB',
                multipleAllowed: '\u05de\u05d5\u05ea\u05e8 \u05dc\u05d4\u05e2\u05dc\u05d5\u05ea \u05db\u05de\u05d4 \u05e7\u05d1\u05e6\u05d9\u05dd'
            };
        case 'es':
            return {
                browseSingle: 'Buscar archivo',
                browseMultiple: 'Buscar archivos',
                allowedTypes: 'Permitidos: {types}',
                maxSize: 'Tama?o m?ximo: {size} MB',
                multipleAllowed: 'Se permiten varios archivos'
            };
        case 'de':
            return {
                browseSingle: 'Datei ausw?hlen',
                browseMultiple: 'Dateien ausw?hlen',
                allowedTypes: 'Erlaubt: {types}',
                maxSize: 'Maximale Gr??e: {size} MB',
                multipleAllowed: 'Mehrere Dateien erlaubt'
            };
        case 'fr':
            return {
                browseSingle: 'Choisir un fichier',
                browseMultiple: 'Choisir des fichiers',
                allowedTypes: 'Autoris?s : {types}',
                maxSize: 'Taille maximale : {size} MB',
                multipleAllowed: 'Plusieurs fichiers autoris?s'
            };
        default:
            return {
                browseSingle: 'Browse file',
                browseMultiple: 'Browse files',
                allowedTypes: 'Allowed: {types}',
                maxSize: 'Max size: {size} MB',
                multipleAllowed: 'Multiple files allowed'
            };
        }
    }

    interpolateText(template, replacements = {}) {
        let output = String(template || '');
        Object.keys(replacements).forEach((key) => {
            output = output.replace(new RegExp(`\\{${key}\\}`, 'g'), String(replacements[key]));
        });
        return output;
    }

    isLegacySeedDefaultValue(item, value) {
        const trimmedValue = String(value || '').trim();
        if (!trimmedValue) {
            return false;
        }
        const seedDefaults = {
            text: 'Enter text',
            textarea: 'Enter longer text',
            number: 'Enter number',
            email: 'name@example.com',
            tel: 'Phone number',
            url: 'https://example.com'
        };
        return seedDefaults[item?.elementType] === trimmedValue;
    }

    fieldPlaceholderDefaults(languageCode) {
        switch (languageCode) {
        case 'he':
            return {
                text: '\u05d4\u05d6\u05df \u05d8\u05e7\u05e1\u05d8',
                textarea: '\u05d4\u05d6\u05df \u05d8\u05e7\u05e1\u05d8 \u05d0\u05e8\u05d5\u05da',
                number: '\u05d4\u05d6\u05df \u05de\u05e1\u05e4\u05e8',
                email: 'name@example.com',
                tel: '\u05de\u05e1\u05e4\u05e8 \u05d8\u05dc\u05e4\u05d5\u05df',
                url: 'https://example.com'
            };
        case 'es':
            return {
                text: 'Introducir texto',
                textarea: 'Introducir texto largo',
                number: 'Introducir n?mero',
                email: 'name@example.com',
                tel: 'N?mero de tel?fono',
                url: 'https://example.com'
            };
        case 'de':
            return {
                text: 'Text eingeben',
                textarea: 'L?ngeren Text eingeben',
                number: 'Nummer eingeben',
                email: 'name@example.com',
                tel: 'Telefonnummer',
                url: 'https://example.com'
            };
        case 'fr':
            return {
                text: 'Saisir du texte',
                textarea: 'Saisir un texte plus long',
                number: 'Saisir un nombre',
                email: 'name@example.com',
                tel: 'Num?ro de t?l?phone',
                url: 'https://example.com'
            };
        default:
            return {
                text: 'Enter text',
                textarea: 'Enter longer text',
                number: 'Enter number',
                email: 'name@example.com',
                tel: 'Phone number',
                url: 'https://example.com'
            };
        }
    }

    localizedFieldPlaceholder(item) {
        const languageCode = this.selectedVersionLanguageCode || this.draftLanguageCode || 'en';
        const placeholders = this.fieldPlaceholderDefaults(languageCode);
        return placeholders[item?.elementType] || '';
    }

    formUiLanguageDefaults(languageCode) {
        switch ((languageCode || 'en').toLowerCase()) {
        case 'he':
            return {
                submitLabel: '\u05e9\u05dc\u05d7',
                submitSuccessMessage: '\u05d4\u05d8\u05d5\u05e4\u05e1 \u05e0\u05e9\u05dc\u05d7 \u05d1\u05d4\u05e6\u05dc\u05d7\u05d4.',
                postSubmitButtonLabel: '\u05d4\u05de\u05e9\u05da'
            };
        case 'es':
            return {
                submitLabel: 'Enviar',
                submitSuccessMessage: 'Tu formulario se envi? correctamente.',
                postSubmitButtonLabel: 'Continuar'
            };
        case 'de':
            return {
                submitLabel: 'Senden',
                submitSuccessMessage: 'Ihr Formular wurde erfolgreich gesendet.',
                postSubmitButtonLabel: 'Weiter'
            };
        case 'fr':
            return {
                submitLabel: 'Envoyer',
                submitSuccessMessage: 'Votre formulaire a ?t? envoy? avec succ?s.',
                postSubmitButtonLabel: 'Continuer'
            };
        default:
            return {
                submitLabel: 'Submit',
                submitSuccessMessage: 'Your form was submitted successfully.',
                postSubmitButtonLabel: 'Continue'
            };
        }
    }

    get userVerificationPreviewData() {
        return {
            introText: this.normalizeUserVerificationValue(this.draftUserVerificationIntroText, 'introText', this.draftLanguageCode),
            sentMessage: this.normalizeUserVerificationValue(this.draftUserVerificationSentMessage, 'sentMessage', this.draftLanguageCode),
            verifiedMessage: this.normalizeUserVerificationValue(this.draftUserVerificationVerifiedMessage, 'verifiedMessage', this.draftLanguageCode),
            sendButtonLabel: this.normalizeUserVerificationValue(this.draftUserVerificationSendButtonLabel, 'sendButtonLabel', this.draftLanguageCode),
            verifyButtonLabel: this.normalizeUserVerificationValue(this.draftUserVerificationVerifyButtonLabel, 'verifyButtonLabel', this.draftLanguageCode),
            resendButtonLabel: this.normalizeUserVerificationValue(this.draftUserVerificationResendButtonLabel, 'resendButtonLabel', this.draftLanguageCode),
            allowResend: this.draftUserVerificationAllowResend
        };
    }

    get showCanvasUserVerificationPreview() {
        return this.draftUserVerificationEnabled;
    }

    get userVerificationPreviewClass() {
        return `designer-user-verification-preview${this.selectedElementIsUserVerification ? ' designer-user-verification-preview--selected' : ''}`;
    }

    get postSubmitFormFieldTokenOptions() {
        return [{ label: 'Insert form field', value: '' }].concat(
            this.elements
                .filter((item) =>
                    item.fieldKey &&
                    ['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'radio', 'ranking'].includes(item.elementType)
                )
                .map((item) => ({
                    label: `${item.label} (${item.fieldKey})`,
                    value: `{{field.${item.fieldKey}}}`
                }))
        );
    }

    get postSubmitFormulaFieldTokenOptions() {
        return [{ label: 'Insert field', value: '' }].concat(
            (this.elements || [])
                .filter((item) => {
                    if (!item?.fieldKey) {
                        return false;
                    }
                    if (!['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'radio', 'ranking', 'hidden'].includes(item.elementType)) {
                        return false;
                    }
                    return !(item.parentElementId && this.isElementInsideRepeatGroup(item));
                })
                .map((item) => ({
                    label: `${item.label} (${item.fieldKey})`,
                    value: `{${item.fieldKey}}`
                }))
        );
    }

    get buttonParameterFieldOptions() {
        const options = [{ label: 'Select a field', value: '' }];
        (this.elements || [])
            .filter((item) =>
                item.fieldKey
                && ['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'radio', 'ranking', 'hidden'].includes(item.elementType)
            )
            .forEach((item) => {
                const isRowField = item.parentElementId && this.isElementInsideRepeatGroup(item);
                if (isRowField && !this.selectedButtonInsideRepeatGroup) {
                    return;
                }
                if (!isRowField) {
                    options.push({
                        label: `${item.label} (${item.fieldKey})`,
                        value: `{{field.${item.fieldKey}}}`
                    });
                } else {
                    options.push({
                        label: `${item.label} (${item.fieldKey}) - Current Row`,
                        value: `{{row.${item.fieldKey}}}`
                    });
                }
            });
        return options;
    }

    get buttonParameterFormulaFieldTokenOptions() {
        const options = [{ label: 'Insert field', value: '' }];
        (this.elements || [])
            .filter((item) =>
                item.fieldKey
                && ['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'radio', 'ranking', 'hidden'].includes(item.elementType)
            )
            .forEach((item) => {
                const isRowField = item.parentElementId && this.isElementInsideRepeatGroup(item);
                if (isRowField && !this.selectedButtonInsideRepeatGroup) {
                    return;
                }
                options.push({
                    label: isRowField
                        ? `${item.label} (${item.fieldKey}) - Current Row`
                        : `${item.label} (${item.fieldKey})`,
                    value: isRowField ? `{row.${item.fieldKey}}` : `{${item.fieldKey}}`
                });
            });
        return options;
    }

    get buttonParameterFormulaExpressionShellClass() {
        return this.modalButtonParameterFormulaError
            ? 'formula-editor-shell formula-editor-shell--error'
            : 'formula-editor-shell';
    }

    get buttonParameterModalFormulaPreviewText() {
        return this.modalButtonParameterFormulaPreviewValue || '';
    }

    get fieldBehaviorRadioOptions() {
        return this.fieldBehaviorOptions.map((option) => ({
            ...option,
            isLockedOption: option.value === 'readonlyWhenPrefilled',
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
                ['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'radio', 'ranking'].includes(item.elementType)
            )
            .map((item) => ({
                label: `${item.label} (${item.fieldKey})`,
                value: item.fieldKey
            }));
    }

    conditionUsesValue(operator) {
        return !['isTrue', 'isFalse', 'isBlank', 'isNotBlank'].includes(operator);
    }

    createVisibilityCondition() {
        return {
            id: `cond-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
            fieldKey: '',
            operator: 'equals',
            value: ''
        };
    }

    normalizeVisibilityConditions(rawConditions, fallbackFieldKey = '', fallbackOperator = 'equals', fallbackValue = '') {
        const normalized = Array.isArray(rawConditions)
            ? rawConditions
                .map((item, index) => ({
                    id: item?.id || `cond-${Date.now()}-${index}`,
                    fieldKey: item?.fieldKey || '',
                    operator: item?.operator || 'equals',
                    value: item?.value || ''
                }))
                .filter((item) => item.fieldKey && item.operator)
            : [];
        if (normalized.length) {
            return normalized;
        }
        if (fallbackFieldKey) {
            return [{
                id: `cond-${Date.now()}-0`,
                fieldKey: fallbackFieldKey,
                operator: fallbackOperator || 'equals',
                value: fallbackValue || ''
            }];
        }
        return [];
    }

    sanitizeVisibilityConditions(conditions) {
        return (conditions || [])
            .filter((item) => item?.fieldKey && item?.operator)
            .map((item) => ({
                fieldKey: item.fieldKey,
                operator: item.operator,
                value: item.value || ''
            }));
    }

    defaultVisibilityExpression(count) {
        if (!count || count < 1) {
            return '';
        }
        return Array.from({ length: count }, (_, index) => String(index + 1)).join(' AND ');
    }

    normalizeVisibilityExpression(expression, count) {
        if (!count || count < 1) {
            return '';
        }
        return (expression || '').trim() || this.defaultVisibilityExpression(count);
    }

    buildConditionRows(conditions, scope) {
        return (conditions || []).map((condition, index) => ({
            ...condition,
            scope,
            index,
            rowKey: condition.id || `${scope}-${index}`,
            displayIndex: index + 1,
            usesValue: this.conditionUsesValue(condition.operator)
        }));
    }

    validateVisibilityExpression(conditions, expression) {
        const clauses = this.sanitizeVisibilityConditions(conditions);
        if (!this.enableProConditionLogic || clauses.length <= 1) {
            return '';
        }
        const raw = (expression || '').trim();
        if (!raw) {
            return 'Enter condition logic such as 1 AND (2 OR 3).';
        }
        const normalized = raw.replace(/\(/g, ' ( ').replace(/\)/g, ' ) ').replace(/\s+/g, ' ').trim();
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
            const number = Number(token);
            if (number < 1 || number > maxNumber) {
                return `Condition logic can only reference rows 1 to ${maxNumber}.`;
            }
            expectOperand = false;
        }
        if (expectOperand || depth !== 0) {
            return 'Condition logic has invalid syntax.';
        }
        return '';
    }

    syncEditorConditionalLegacyFields() {
        const first = (this.editorConditionalConditions || [])[0] || {};
        this.editorConditionalFieldKey = first.fieldKey || '';
        this.editorConditionalOperator = first.operator || 'equals';
        this.editorConditionalValue = first.value || '';
        this.editorConditionalExpression = this.normalizeVisibilityExpression(
            this.editorConditionalExpression,
            (this.editorConditionalConditions || []).length
        );
    }

    syncSubmitConditionalLegacyFields() {
        const first = (this.draftSubmitConditionalConditions || [])[0] || {};
        this.draftSubmitConditionalFieldKey = first.fieldKey || '';
        this.draftSubmitConditionalOperator = first.operator || 'equals';
        this.draftSubmitConditionalValue = first.value || '';
        this.draftSubmitConditionalExpression = this.normalizeVisibilityExpression(
            this.draftSubmitConditionalExpression,
            (this.draftSubmitConditionalConditions || []).length
        );
    }

    ensureDraftElementConditionRow() {
        if (this.editorConditionalEnabled && !(this.editorConditionalConditions || []).length) {
            this.editorConditionalConditions = [this.createVisibilityCondition()];
        }
    }

    ensureDraftSubmitConditionRow() {
        if (this.draftSubmitConditionalEnabled && !(this.draftSubmitConditionalConditions || []).length) {
            this.draftSubmitConditionalConditions = [this.createVisibilityCondition()];
        }
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

    get modalMergeFieldOptions() {
        if (!this.modalMergeAlias) {
            return [{ label: 'Select Salesforce field', value: '' }];
        }
        const match = this.prefillAliasDetails.find((item) => item.alias === this.modalMergeAlias);
        return [{ label: 'Select Salesforce field', value: '' }].concat(match?.fieldOptions || []);
    }

    get canInsertMergedDocumentToken() {
        return !!this.modalMergeAlias && !!this.modalMergeFieldPath;
    }

    get cannotInsertMergedDocumentToken() {
        return !this.canInsertMergedDocumentToken;
    }

    get displayTextModalTitle() {
        return this.selectedElementIsMergedDocument ? 'Edit Merged Document' : 'Edit Display Text';
    }

    get displayTextModalLabel() {
        return this.selectedElementIsMergedDocument ? 'Merged Document' : 'Display Text';
    }

    get submitActionOptions() {
        return [{ label: 'Select action', value: '' }].concat(
            (this.submitActionDetails || []).map((action) => ({
                label: `${action.storeResultAs || action.actionKey} (${action.actionKey})`,
                value: action.actionKey
            }))
        );
    }

    get repeatSubmitActionOptions() {
        const selectedKey = this.selectedElement?.fieldKey;
        const selectedId = this.selectedElement?.elementId;
        return [{ label: 'Select submit alias', value: '' }].concat(
            (this.submitActionDetails || [])
                .filter((action) => action.commandType === 'upsertMany')
                .filter((action) => !action.repeatGroupKey || action.repeatGroupKey === selectedKey || action.repeatGroupKey === selectedId)
                .map((action) => ({
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

    inferPicklistSourceFromSubmitMapping(config) {
        if (!config?.submitActionKey || !config?.submitFieldPath) {
            return { objectApiName: '', fieldApiName: '' };
        }
        const submitAction = (this.submitActionDetails || []).find((item) => item.actionKey === config.submitActionKey);
        return {
            objectApiName: submitAction?.objectApiName || '',
            fieldApiName: config.submitFieldPath || ''
        };
    }

    get fileUploadTargetActionOptions() {
        return [{ label: 'Select action', value: '' }].concat(
            (this.submitActionDetails || [])
                .filter((action) => ['create', 'update', 'findAndUpdate', 'updateById'].includes(action.commandType))
                .map((action) => ({
                    label: `${action.storeResultAs || action.actionKey} (${action.actionKey})`,
                    value: action.actionKey
                }))
        );
    }

    get submissionPdfTargetActionOptions() {
        return this.fileUploadTargetActionOptions;
    }

    async loadWorkspace(projectId = this.selectedProjectId, formId = this.selectedFormId, versionId = this.selectedVersionId, silent = false) {
        if (!silent) {
            this.isLoading = true;
        }
        this.errorMessage = '';

        try {
            const workspace = await getWorkspace({ projectId, formId, versionId });
            this.selectedProjectId = workspace.selectedProjectId || '';
            this.selectedFormId = workspace.selectedFormId;
            this.selectedVersionId = workspace.selectedVersionId;
            this.selectedThemeId = workspace.selectedThemeId || '';
            this.selectedTheme = workspace.selectedTheme || null;
            this.selectedProjectName = workspace.selectedProjectName || '';
            this.selectedFormName = workspace.selectedFormName;
            this.selectedFormKey = workspace.selectedFormKey;
            this.selectedFormDescription = workspace.selectedFormDescription;
            this.draftFormName = this.selectedFormName || '';
            this.selectedFormCaptchaEnabled = !!workspace.selectedFormCaptchaEnabled;
            this.captchaKeysConfigured = !!workspace.captchaKeysConfigured;
            this.selectedVersionName = workspace.selectedVersionName;
            this.selectedVersionStatus = workspace.selectedVersionStatus;
            this.selectedVersionLanguageCode = workspace.selectedVersionLanguageCode || 'en';
            // Keeps the formula preview's DAYNAME() output in the same language the published form will use.
            setFormulaLanguage(this.selectedVersionLanguageCode);
            this.selectedVersionSubmitSuccessMessage = workspace.selectedVersionSubmitSuccessMessage || 'Your form was submitted successfully.';
            this.selectedVersionSubmitLabel = workspace.selectedVersionSubmitLabel || 'Submit';
            this.selectedVersionRtlEnabled = !!workspace.selectedVersionRtlEnabled;
            this.selectedVersionPostSubmitAutoLinkEnabled = !!workspace.selectedVersionPostSubmitAutoLinkEnabled;
            this.selectedVersionPostSubmitUrlMode = workspace.selectedVersionPostSubmitUrlMode === 'formula' ? 'formula' : 'template';
            this.selectedVersionPostSubmitUrlTemplate = workspace.selectedVersionPostSubmitUrlTemplate || '';
            this.selectedVersionPostSubmitUrlFormula = workspace.selectedVersionPostSubmitUrlFormula || '';
            this.selectedVersionPostSubmitButtonLabel = workspace.selectedVersionPostSubmitButtonLabel || 'Continue';
            this.selectedVersionPostSubmitDelaySeconds = Number.isFinite(Number(workspace.selectedVersionPostSubmitDelaySeconds))
                ? Math.max(0, Number(workspace.selectedVersionPostSubmitDelaySeconds))
                : 0;
            this.selectedVersionUserVerificationEnabled = !!workspace.selectedVersionUserVerificationEnabled;
            this.selectedVersionUserVerificationMatchField = workspace.selectedVersionUserVerificationMatchField || 'Email';
            this.selectedVersionUserVerificationIntroText = this.normalizeUserVerificationValue(workspace.selectedVersionUserVerificationIntroText, 'introText', this.selectedVersionLanguageCode);
            this.selectedVersionUserVerificationSentMessage = this.normalizeUserVerificationValue(workspace.selectedVersionUserVerificationSentMessage, 'sentMessage', this.selectedVersionLanguageCode);
            this.selectedVersionUserVerificationInvalidMessage = this.normalizeUserVerificationValue(workspace.selectedVersionUserVerificationInvalidMessage, 'invalidMessage', this.selectedVersionLanguageCode);
            this.selectedVersionUserVerificationVerifiedMessage = this.normalizeUserVerificationValue(workspace.selectedVersionUserVerificationVerifiedMessage, 'verifiedMessage', this.selectedVersionLanguageCode);
            this.selectedVersionUserVerificationSendButtonLabel = this.normalizeUserVerificationValue(workspace.selectedVersionUserVerificationSendButtonLabel, 'sendButtonLabel', this.selectedVersionLanguageCode);
            this.selectedVersionUserVerificationVerifyButtonLabel = this.normalizeUserVerificationValue(workspace.selectedVersionUserVerificationVerifyButtonLabel, 'verifyButtonLabel', this.selectedVersionLanguageCode);
            this.selectedVersionUserVerificationResendButtonLabel = this.normalizeUserVerificationValue(workspace.selectedVersionUserVerificationResendButtonLabel, 'resendButtonLabel', this.selectedVersionLanguageCode);
            this.selectedVersionUserVerificationExpiryMinutes = Number.isFinite(Number(workspace.selectedVersionUserVerificationExpiryMinutes))
                ? Math.max(1, Number(workspace.selectedVersionUserVerificationExpiryMinutes))
                : 10;
            this.selectedVersionUserVerificationMaxAttempts = Number.isFinite(Number(workspace.selectedVersionUserVerificationMaxAttempts))
                ? Math.max(1, Number(workspace.selectedVersionUserVerificationMaxAttempts))
                : 5;
            this.selectedVersionUserVerificationAllowResend = workspace.selectedVersionUserVerificationAllowResend !== false;
            this.selectedVersionUserVerificationSessionMode = workspace.selectedVersionUserVerificationSessionMode === 'sameTabUntilMidnight'
                ? 'sameTabUntilMidnight'
                : 'short';
            this.selectedVersionUserVerificationSenderEmail = (workspace.selectedVersionUserVerificationSenderEmail || workspace.defaultUserVerificationSenderEmail || '').trim().toLowerCase();
            this.selectedVersionSubmitConditionalEnabled = !!workspace.selectedVersionSubmitConditionalEnabled;
            this.selectedVersionSubmitConditionalFieldKey = workspace.selectedVersionSubmitConditionalFieldKey || '';
            this.selectedVersionSubmitConditionalOperator = workspace.selectedVersionSubmitConditionalOperator || 'equals';
            this.selectedVersionSubmitConditionalValue = workspace.selectedVersionSubmitConditionalValue || '';
            this.selectedVersionSubmitConditionalConditions = this.normalizeVisibilityConditions(
                this.parseConfig(workspace.selectedVersionSubmitConditionalConditionsJson || '[]'),
                this.selectedVersionSubmitConditionalFieldKey,
                this.selectedVersionSubmitConditionalOperator,
                this.selectedVersionSubmitConditionalValue
            );
            this.selectedVersionSubmitConditionalExpression = this.normalizeVisibilityExpression(
                workspace.selectedVersionSubmitConditionalExpression || '',
                this.selectedVersionSubmitConditionalConditions.length
            );
            this.selectedVersionSubmissionPdfEnabled = !!workspace.selectedVersionSubmissionPdfEnabled;
            this.selectedVersionSubmissionPdfAttachToRecord = workspace.selectedVersionSubmissionPdfAttachToRecord !== false;
            this.selectedVersionSubmissionPdfTargetSubmitActionKey = workspace.selectedVersionSubmissionPdfTargetSubmitActionKey || '';
            this.selectedVersionSubmissionPdfTitle = workspace.selectedVersionSubmissionPdfTitle || 'Submitted Response';
            this.selectedVersionSubmissionPdfIncludeEmptyFields = workspace.selectedVersionSubmissionPdfIncludeEmptyFields !== false;
            this.selectedVersionCustomJs = workspace.selectedVersionCustomJs || '';
            this.draftSubmitSuccessMessage = this.selectedVersionSubmitSuccessMessage;
            this.draftLanguageCode = this.selectedVersionLanguageCode;
            this.draftSubmitLabel = this.selectedVersionSubmitLabel;
            this.draftRtlEnabled = this.selectedVersionRtlEnabled;
            this.draftPostSubmitAutoLinkEnabled = this.selectedVersionPostSubmitAutoLinkEnabled;
            this.draftPostSubmitUrlMode = this.selectedVersionPostSubmitUrlMode;
            this.draftPostSubmitUrlTemplate = this.selectedVersionPostSubmitUrlTemplate || this.defaultPostSubmitRedirectUrl;
            this.draftPostSubmitUrlFormula = this.selectedVersionPostSubmitUrlFormula;
            this.draftPostSubmitButtonLabel = this.selectedVersionPostSubmitButtonLabel;
            this.draftPostSubmitDelaySeconds = this.selectedVersionPostSubmitDelaySeconds;
            this.draftUserVerificationEnabled = this.selectedVersionUserVerificationEnabled;
            this.draftUserVerificationMatchField = this.selectedVersionUserVerificationMatchField || 'Email';
            this.draftUserVerificationIntroText = this.selectedVersionUserVerificationIntroText;
            this.draftUserVerificationSentMessage = this.selectedVersionUserVerificationSentMessage;
            this.draftUserVerificationInvalidMessage = this.selectedVersionUserVerificationInvalidMessage;
            this.draftUserVerificationVerifiedMessage = this.selectedVersionUserVerificationVerifiedMessage;
            this.draftUserVerificationSendButtonLabel = this.selectedVersionUserVerificationSendButtonLabel;
            this.draftUserVerificationVerifyButtonLabel = this.selectedVersionUserVerificationVerifyButtonLabel;
            this.draftUserVerificationResendButtonLabel = this.selectedVersionUserVerificationResendButtonLabel;
            this.draftUserVerificationExpiryMinutes = this.selectedVersionUserVerificationExpiryMinutes;
            this.draftUserVerificationMaxAttempts = this.selectedVersionUserVerificationMaxAttempts;
            this.draftUserVerificationAllowResend = this.selectedVersionUserVerificationAllowResend;
            this.draftUserVerificationSessionMode = this.selectedVersionUserVerificationSessionMode;
            this.draftUserVerificationSenderEmail = this.selectedVersionUserVerificationSenderEmail;
            this.draftSubmitConditionalEnabled = this.selectedVersionSubmitConditionalEnabled;
            this.draftSubmitConditionalFieldKey = this.selectedVersionSubmitConditionalFieldKey;
            this.draftSubmitConditionalOperator = this.selectedVersionSubmitConditionalOperator;
            this.draftSubmitConditionalValue = this.selectedVersionSubmitConditionalValue;
            this.draftSubmitConditionalConditions = [...this.selectedVersionSubmitConditionalConditions];
            this.draftSubmitConditionalExpression = this.selectedVersionSubmitConditionalExpression;
            this.draftSubmissionPdfEnabled = this.selectedVersionSubmissionPdfEnabled;
            this.draftSubmissionPdfAttachToRecord = this.selectedVersionSubmissionPdfAttachToRecord;
            this.draftSubmissionPdfTargetSubmitActionKey = this.selectedVersionSubmissionPdfTargetSubmitActionKey;
            this.draftSubmissionPdfTitle = this.selectedVersionSubmissionPdfTitle;
            this.draftSubmissionPdfIncludeEmptyFields = this.selectedVersionSubmissionPdfIncludeEmptyFields;
            this.draftCustomJs = this.selectedVersionCustomJs;
            this.ensureDraftSubmitConditionRow();
            this.selectedPublishedUrl = workspace.selectedPublishedUrl || '';
            this.prefillAliasDetails = workspace.prefillAliases || [];
            this.submitActionDetails = workspace.submitActions || [];
            this.enableProConditionLogic = !!workspace.enableProConditionLogic;
            this.enableProRepeatGroups = !!workspace.enableProRepeatGroups;
            this.enableProLoadFile = !!workspace.enableProLoadFile;
            this.enableProElectronicSignature = !!workspace.enableProElectronicSignature;
            this.enableProSubmissionPdf = !!workspace.enableProSubmissionPdf;
            this.enableProSurveyFields = !!workspace.enableProSurveyFields;
            this.enableProLocationFields = !!workspace.enableProLocationFields;
            this.enableProFormulaFields = !!workspace.enableProFormulaFields;
            this.enableProPostSubmitAutoLink = !!workspace.enableProPostSubmitAutoLink;
            this.enableProUserVerification = !!workspace.enableProUserVerification;
            this.enableProAdvancedSubmitModes = !!workspace.enableProAdvancedSubmitModes;
            this.enableProPageLayoutClone = !!workspace.enableProPageLayoutClone;
            this.enableProCustomJs = !!workspace.enableProCustomJs;
            this.enableProButtonElements = !!workspace.enableProButtonElements;
            this.enableProMergedDocument = !!workspace.enableProMergedDocument;
            this.currentFormCount = workspace.currentFormCount || 0;
            this.maxForms = workspace.maxForms === null || workspace.maxForms === undefined ? null : Number(workspace.maxForms);
            this.formLimitReached = workspace.formLimitReached === true;
            this.formLimitMessage = workspace.formLimitMessage || '';
            this.upgradeUrl = workspace.upgradeUrl || 'https://twinaforms.com/upgrade?source=salesforce-designer';
            if (this.selectedProjectId) {
                this.storeSelectedProject(this.selectedProjectId);
            } else {
                this.clearStoredProject();
            }
            if (this.selectedFormId) {
                this.storeSelectedForm(this.selectedFormId);
            } else {
                this.clearStoredForm();
            }
            if (this.selectedVersionId) {
                this.storeSelectedVersion(this.selectedVersionId);
            } else {
                this.clearStoredVersion();
            }
            this.projectOptions = (workspace.projects || []).map((option) => ({
                label: option.label,
                value: option.value
            }));
            this.rawFormOptions = (workspace.forms || []).map((option) => ({
                label: option.label,
                value: option.value
            }));
            this.applyFormSort();
            this.publishedButtonTargets = (workspace.publishedButtonTargets || []).map((option) => ({
                label: option.label,
                value: option.value
            }));
            this.versionOptions = (workspace.versions || []).map((option) => ({
                label: option.isPublished ? `${option.label} (Published)` : `${option.label} (${option.status})`,
                value: option.value,
                isPublished: option.isPublished === true
            }));
            this.themeOptions = [{ label: 'Select Theme', value: '' }].concat(
                (workspace.themes || []).map((option) => ({
                    label: option.label,
                    value: option.value
                }))
            );
            this.elements = (workspace.elements || []).map((item) => this.decorateBaseElement(item));
            this.canvasElements = this.buildCanvasElements(this.elements);
            this.updatePostSubmitFormulaPreview();
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
            const options = await getPicklistFieldOptions({
                objectApiName,
                fieldType: this.selectedElementIsMultiCheckbox ? 'MultiPicklist' : 'Picklist'
            });
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

    async loadLookupFieldOptions(objectApiName) {
        if (!objectApiName) {
            this.lookupSearchFieldOptions = [];
            this.lookupDisplayFieldOptions = [];
            return;
        }
        try {
            const [searchOptions, displayOptions] = await Promise.all([
                getLookupFieldOptions({ objectApiName, usage: 'search' }),
                getLookupFieldOptions({ objectApiName, usage: 'display' })
            ]);
            this.lookupSearchFieldOptions = (searchOptions || []).map((option) => ({
                label: option.label,
                value: option.value
            }));
            this.lookupDisplayFieldOptions = (displayOptions || []).map((option) => ({
                label: option.label,
                value: option.value
            }));
            this.editorLookupSearchFields = this.ensureSelectedLookupFields(
                this.editorLookupSearchFields,
                this.lookupSearchFieldOptions,
                ['Name']
            ).slice(0, 1);
            this.editorLookupDisplayFields = [...this.editorLookupSearchFields];
            this.editorLookupSetFields = this.normalizeLookupSetFields(this.editorLookupSetFields);
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
        const rendered = topLevel.map((item) => this.decorateCanvasElement(item, byParent));
        rendered.push(this.buildSubmitButtonCanvasElement());
        return rendered;
    }

    buildSubmitButtonCanvasElement() {
        const conditionalEnabled = !!this.draftSubmitConditionalEnabled;
        const conditionalConditions = this.sanitizeVisibilityConditions(this.draftSubmitConditionalConditions);
        const conditionalExpression = this.normalizeVisibilityExpression(
            this.draftSubmitConditionalExpression,
            conditionalConditions.length
        );
        const firstCondition = conditionalConditions[0] || {};
        const conditionalSummary = conditionalEnabled && conditionalConditions.length
            ? this.buildConditionalSummaryFromConditions(conditionalConditions, conditionalExpression)
            : '';
        const selected = this.selectedElementId === SUBMIT_BUTTON_ELEMENT_ID;
        return {
            id: SUBMIT_BUTTON_ELEMENT_ID,
            elementId: SUBMIT_BUTTON_ELEMENT_ID,
            label: this.draftSubmitLabel || 'Submit',
            elementType: 'submitButton',
            fieldKey: '',
            configJson: JSON.stringify({
                submitLabel: this.draftSubmitLabel || 'Submit',
                conditionalEnabled,
                conditionalFieldKey: firstCondition.fieldKey || '',
                conditionalOperator: firstCondition.operator || 'equals',
                conditionalValue: firstCondition.value || '',
                conditionalConditions,
                conditionalExpression
            }),
            isSubmitButton: true,
            cardClass: `designer-node designer-node--field designer-node--submit-button${selected ? ' designer-node--selected' : ''}`,
            previewButtonLabel: this.draftSubmitLabel || 'Submit',
            showConditionalBadge: !!conditionalSummary,
            conditionalSummary,
            showHiddenBadge: conditionalEnabled && !conditionalConditions.length,
            fieldPreviewClass: 'preview-field preview-field--submit-button'
        };
    }

    buildUserVerificationCanvasElement() {
        const selected = this.selectedElementId === USER_VERIFICATION_ELEMENT_ID;
        return {
            id: USER_VERIFICATION_ELEMENT_ID,
            elementId: USER_VERIFICATION_ELEMENT_ID,
            label: 'User Verification',
            elementType: 'userVerification',
            fieldKey: '',
            configJson: JSON.stringify({ systemElement: true }),
            isSystemElement: true,
            cardClass: `designer-user-verification-preview${selected ? ' designer-user-verification-preview--selected' : ''}`
        };
    }

    decorateRenderableElement(item, isChild) {
        const effectiveType = item.elementType === 'hidden' ? 'text' : item.elementType;
        const config = this.parseConfig(item.configJson);
        const presentation = config.presentation || '';
        const isSurveyRadio = effectiveType === 'radio' && ['stars', 'nps', 'likert', 'satisfaction'].includes(presentation);
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
            isTime: effectiveType === 'time',
            isEmail: effectiveType === 'email',
            isPhone: effectiveType === 'tel',
            isUrl: effectiveType === 'url',
            isSelect: effectiveType === 'select',
            isMultiCheckbox: effectiveType === 'multiCheckbox',
            isLocation: effectiveType === 'location',
            isRadio: effectiveType === 'radio',
            isSurveyRadio,
            isRanking: effectiveType === 'ranking',
            isFileUpload: effectiveType === 'fileUpload',
            isSignature: effectiveType === 'signature',
            isHidden: item.elementType === 'hidden',
            isFormula: this.isFormulaField(item),
            isHeading: effectiveType === 'heading' || effectiveType === 'mergedDocument',
            isMergedDocument: effectiveType === 'mergedDocument',
            isImage: effectiveType === 'image',
            isButton: effectiveType === 'button',
            isSpacer: effectiveType === 'spacer',
            spacerSize: config.spacerSize === 'fieldWithLabel' ? 'fieldWithLabel' : 'field',
            labelPosition: this.labelPosition(item),
            fieldBehavior: this.fieldBehavior(item),
            previewText: this.previewText(item),
            previewHtml: this.previewHtml(item),
            previewValue: this.previewValue(item),
            previewPlaceholder: this.previewPlaceholder(item),
            previewChecked: this.previewChecked(item),
            previewOptions: this.previewOptions(item),
            previewLocationParts: this.previewLocationParts(item),
            previewLocationInputsClass: this.previewLocationInputsClass(item),
            previewRankingOptions: this.previewRankingOptions(item),
            previewImageUrl: this.previewImageUrl(item),
            previewImageAlt: this.previewImageAlt(item),
            previewImageFit: this.previewImageFit(item),
            previewImageWidthPercent: this.previewImageWidthPercent(item),
            previewInputType: this.previewInputType(item),
            previewFileAccept: this.previewFileAccept(item),
            previewFileAllowMultiple: this.previewFileAllowMultiple(item),
            previewUploadActionLabel: this.previewUploadActionLabel(item),
            validationPattern: this.validationPattern(item),
            conditionalSummary: this.conditionalSummary(item),
            showTitle: this.sectionShowTitle(item),
            showSectionBox: this.sectionBoxed(item),
            repeatSourceAlias: this.repeatSourceAlias(item),
            repeatSubmitAlias: this.repeatSubmitAlias(item),
            allowAddRows: this.repeatAllowAddRows(item),
            allowDeleteRows: this.repeatAllowDeleteRows(item)
        };
        const selected = normalized.id === this.selectedElementId;
        const hidesSubtree = (normalized.isSectionLike || normalized.isRepeatGroup) && normalized.fieldBehavior === 'hidden';
        return {
            ...normalized,
            isTopLevelDraggable: !isChild,
            isChildDraggable: isChild,
            showHiddenBadge: normalized.isHidden || normalized.fieldBehavior === 'hidden',
            showExpandedPicklist: (normalized.isSelect || normalized.isMultiCheckbox) && selected,
            showLabel: !normalized.isSpacer && normalized.labelPosition !== 'hidden',
            showConditionalBadge: !!normalized.conditionalSummary,
            displayLabel: this.previewLabel(item),
            labelClass: this.labelPreviewClasses(item),
            cardStyle: this.elementCardStyle(normalized),
            cardClass: `designer-node ${!(normalized.isSectionLike || normalized.isRepeatGroup) ? 'designer-node--field ' : ''}${isChild ? 'designer-node--child ' : ''}designer-node--${normalized.elementType}${(normalized.isSectionLike || normalized.isRepeatGroup) && !normalized.showSectionBox ? ' designer-node--section-unboxed' : ''}${hidesSubtree ? ' designer-node--hidden-subtree' : ''}${selected ? ' designer-node--selected' : ''}`,
            fieldPreviewClass: `preview-field preview-field--${normalized.labelPosition || 'above'}`,
            previewRadioGroupClass: `preview-radio-group${isSurveyRadio ? ` preview-radio-group--${presentation}` : ''}`,
            previewInputDirection: this.previewInputDirection(item),
            previewTextClass: `preview-heading${selected ? ' preview-heading--selected' : ''}`,
            imageFrameClass: `preview-image__frame preview-image__frame--${normalized.previewImageFit || 'original'}`,
            imageClass: `preview-image__img preview-image__img--${normalized.previewImageFit || 'original'}`,
            imageStyle: `width:${normalized.previewImageWidthPercent || 100}%;`,
            previewSpacerClass: `preview-spacer${normalized.spacerSize === 'fieldWithLabel' ? ' preview-spacer--field-with-label' : ''}`,
            previewButtonLabel: item.label || 'Continue'
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
        const sectionColumnStyle = this.sectionColumnStyle(base.configJson);
        const sectionSlots = Array.from({ length: slotCount }, (_, index) => {
            const columnValue = index + 1;
            const targetKey = `${base.id}:${columnValue}`;
            const childItems = sectionChildren
                .filter((child) => Number(child.sectionColumn || 1) === columnValue)
                .map((child) => this.decorateRenderableElement(child, true))
                .map((child, childIndex) => ({
                    ...child,
                    sectionIndex: childIndex
                }));

            return {
                key: `slot-${base.id}-${columnValue}`,
                label: String(columnValue),
                emptyLabel: String(columnValue),
                columnValue,
                sectionId: base.id,
                childCount: childItems.length,
                dropClass: `preview-column-slot${!base.showSectionBox ? ' preview-column-slot--unboxed' : ''}${this.dragSectionTarget === targetKey ? ' preview-column-slot--active' : ''}`,
                childItems,
                hasChildren: childItems.length > 0
            };
        });

        const showRepeatSourceWarning = base.isRepeatGroup && !base.repeatSourceAlias && !base.repeatSubmitAlias && sectionChildren.length > 0;
        return {
            ...base,
            sectionColumnClass,
            sectionColumnStyle,
            sectionSlots,
            showRepeatSourceWarning,
            repeatSourceWarningText: showRepeatSourceWarning ? 'This Records List has row fields, but no Prefill Alias or Submit Alias.' : ''
        };
    }

    sectionColumns(configJson) {
        const config = this.parseConfig(configJson);
        const value = Number(config.columns);
        return Number.isFinite(value) && value >= 1 && value <= 10 ? value : 2;
    }

    normalizeColumnLayout(layout, columns) {
        const count = Number(columns || 1);
        if (layout === 'narrowFirst' && count === 2) return layout;
        if (layout === 'wideFirst' && (count === 2 || count === 3)) return layout;
        if (layout === 'wideMiddle' && count === 3) return layout;
        if (layout === 'wideLast' && count === 3) return layout;
        return 'equal';
    }

    columnTemplate(columns, layout) {
        const count = Math.min(Math.max(Number(columns || 1), 1), 10);
        const normalized = this.normalizeColumnLayout(layout, count);
        if (count === 1) return '1fr';
        if (count === 2 && normalized === 'narrowFirst') return 'minmax(0,1fr) minmax(0,2fr)';
        if (count === 2 && normalized === 'wideFirst') return 'minmax(0,2fr) minmax(0,1fr)';
        if (count === 3 && normalized === 'wideFirst') return 'minmax(0,2fr) minmax(0,1fr) minmax(0,1fr)';
        if (count === 3 && normalized === 'wideMiddle') return 'minmax(0,1fr) minmax(0,2fr) minmax(0,1fr)';
        if (count === 3 && normalized === 'wideLast') return 'minmax(0,1fr) minmax(0,1fr) minmax(0,2fr)';
        return `repeat(${count},minmax(0,1fr))`;
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

    repeatSubmitAlias(item) {
        const config = this.parseConfig(item.configJson);
        return this.repeatSubmitAliasLabel(config.repeatSubmitActionKey || config.repeatSubmitAlias || '');
    }

    repeatSubmitAliasLabel(actionKey) {
        if (!actionKey) {
            return '';
        }
        const match = (this.submitActionDetails || []).find((action) => action.actionKey === actionKey);
        return match?.storeResultAs || actionKey;
    }

    repeatGroupHasRowFields(item) {
        if (!item?.elementId) {
            return false;
        }
        return this.elements.some((candidate) => candidate.parentElementId === item.elementId);
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

    previewLabel(item) {
        const label = item?.label || '';
        if (!this.supportsRequiredMarker(item)) {
            return label;
        }
        return `${label} *`;
    }

    supportsRequiredMarker(item) {
        const effectiveType = item?.elementType === 'hidden' ? 'text' : item?.elementType;
        if (!['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'radio', 'ranking', 'fileUpload', 'signature'].includes(effectiveType)) {
            return false;
        }
        const config = this.parseConfig(item?.configJson);
        return config.required === true;
    }

    previewHtml(item) {
        const config = this.parseConfig(item.configJson);
        return config.html || config.text || (item?.elementType === 'mergedDocument' ? '<p>Merged document text</p>' : '<p>Display text</p>');
    }

    previewValue(item) {
        const config = this.parseConfig(item.configJson);
        if (config.isFormula === true) {
            const preview = previewFormulaValue({
                expression: config.formulaExpression || '',
                fieldKey: item.fieldKey,
                targetType: item.elementType,
                elements: this.elements,
                insideRepeatGroup: !!item.parentElementId && this.elements.some((candidate) => candidate.elementId === item.parentElementId && candidate.elementType === 'repeatGroup'),
                sourceValues: this.formulaSourceValues()
            });
            return preview.value === null || preview.value === undefined ? '' : String(preview.value);
        }
        if (this.isLegacySeedDefaultValue(item, config.defaultValue)) {
            return '';
        }
        if (item.elementType === 'time') {
            return this.formatTimeValue(config.defaultValue || '', config.timeFormat === '12h' ? '12h' : '24h');
        }
        return config.defaultValue || '';
    }

    previewPlaceholder(item) {
        const config = this.parseConfig(item.configJson);
        if (config.isFormula === true) {
            return '';
        }
        if (item.elementType === 'date') {
            return config.placeholder || (config.dateDisplayFormat === 'eu' ? 'dd/mm/yyyy' : 'mm/dd/yyyy');
        }
        if (item.elementType === 'time') {
            return config.placeholder || this.timePlaceholderForFormat(config.timeFormat === '12h' ? '12h' : '24h');
        }
        if (config.placeholder) {
            return config.placeholder;
        }
        if (this.isLegacySeedDefaultValue(item, config.defaultValue)) {
            return this.localizedFieldPlaceholder(item);
        }
        return '';
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
        const multiValues = item.elementType === 'multiCheckbox'
            ? new Set(String(defaultValue || '').split(';').map((value) => value.trim()).filter(Boolean))
            : null;
        const presentation = config.presentation || '';
        const optionKeyPrefix = item.id || item.elementId || item.fieldKey || item.elementType || 'option';
        return Array.isArray(config.options)
            ? config.options.map((option, index) => {
                const value = option?.value;
                let label = option?.label || '';
                if (presentation === 'stars') {
                    const starCount = Number(value);
                    label = Number.isFinite(starCount) && starCount > 0 ? '\u2605'.repeat(starCount) : label;
                }
                return {
                    ...option,
                    key: `${optionKeyPrefix}-${index}-${String(value || label || 'blank')}`,
                    label,
                    checked: multiValues ? multiValues.has(String(value)) : value === defaultValue
                };
            })
            : [];
    }

    previewRankingOptions(item) {
        const config = this.parseConfig(item.configJson);
        return Array.isArray(config.options)
            ? config.options.map((option, index) => ({
                key: `${option?.value || index}`,
                rank: index + 1,
                label: option?.label || option?.value || `Choice ${index + 1}`,
                isFirst: index === 0,
                isLast: index === config.options.length - 1
            }))
            : [];
    }

    normalizeSurveyOptions(options) {
        const normalized = Array.isArray(options)
            ? options
                .map((option, index) => ({
                    rowKey: `${index}-${option?.value || option?.label || 'choice'}`,
                    index,
                    displayIndex: index + 1,
                    isFirst: index === 0,
                    isLast: index === options.length - 1,
                    label: option?.label || '',
                    value: option?.value || ''
                }))
                .filter((option) => option.label || option.value)
            : [];

        return normalized.length
            ? this.decorateSurveyOptions(normalized)
            : this.decorateSurveyOptions([{ rowKey: '0-choice', index: 0, displayIndex: 1, label: 'Choice 1', value: 'choice1' }]);
    }

    decorateSurveyOptions(options) {
        const count = (options || []).length;
        return (options || []).map((option, index) => ({
            ...option,
            index,
            displayIndex: index + 1,
            isFirst: index === 0,
            isLast: index === count - 1
        }));
    }

    surveyOptionsForSave() {
        return (this.editorSurveyOptions || [])
            .map((option, index) => {
                const label = (option.label || '').trim() || `Choice ${index + 1}`;
                const value = (option.value || '').trim() || this.valueFromLabel(label, index);
                return { label, value };
            })
            .filter((option) => option.label || option.value);
    }

    valueFromLabel(label, index) {
        const normalized = String(label || '')
            .trim()
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '_')
            .replace(/^_+|_+$/g, '');
        return normalized || `choice${index + 1}`;
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
        if (effectiveType === 'time') {
            return 'text';
        }
        return ['text', 'number', 'date', 'email', 'tel', 'url'].includes(effectiveType) ? effectiveType : 'text';
    }

    previewFileAccept(item) {
        const config = this.parseConfig(item.configJson);
        return this.allowedExtensionsToAccept(config.allowedExtensions);
    }

    previewFileAllowMultiple(item) {
        const config = this.parseConfig(item.configJson);
        return config.allowMultiple === true;
    }

    previewUploadActionLabel(item) {
        const config = this.parseConfig(item.configJson);
        const defaults = this.fileUploadLanguageDefaults(this.draftLanguageCode);
        return config.allowMultiple === true ? defaults.browseMultiple : defaults.browseSingle;
    }

    previewInputDirection(item) {
        return ['number', 'date', 'time', 'email', 'tel', 'url'].includes(item?.elementType) ? 'ltr' : null;
    }

    isFormulaField(item) {
        const config = this.parseConfig(item?.configJson);
        return config.isFormula === true;
    }

    formulaSourceValues() {
        const values = {};
        const selectedRepeatGroup = this.selectedElementIsInsideRepeatGroup
            ? this.findRepeatGroupAncestor(this.selectedElement)
            : null;
        (this.elements || []).forEach((item) => {
            if (!item?.fieldKey) {
                return;
            }
            const config = this.parseConfig(item.configJson);
            if (config.isFormula === true) {
                return;
            }
            if (item.elementType === 'checkbox') {
                values[item.fieldKey] = this.previewChecked(item);
                if (selectedRepeatGroup && item.parentElementId === selectedRepeatGroup.elementId) {
                    values[`row.${item.fieldKey}`] = values[item.fieldKey];
                }
                return;
            }
            if (item.elementType === 'select' || item.elementType === 'radio') {
                values[item.fieldKey] = config.defaultValue || '';
                if (selectedRepeatGroup && item.parentElementId === selectedRepeatGroup.elementId) {
                    values[`row.${item.fieldKey}`] = values[item.fieldKey];
                }
                return;
            }
            if (item.elementType === 'hidden') {
                values[item.fieldKey] = config.value || '';
                if (selectedRepeatGroup && item.parentElementId === selectedRepeatGroup.elementId) {
                    values[`row.${item.fieldKey}`] = values[item.fieldKey];
                }
                return;
            }
            values[item.fieldKey] = this.previewValue(item);
            if (selectedRepeatGroup && item.parentElementId === selectedRepeatGroup.elementId) {
                values[`row.${item.fieldKey}`] = values[item.fieldKey];
            }
        });
        return values;
    }

    updateFormulaPreview() {
        if (!this.selectedElement || !this.selectedElementSupportsFormula || !this.editorUseFormula) {
            this.editorFormulaPreviewValue = '';
            this.editorFormulaError = '';
            return;
        }
        const preview = previewFormulaValue({
            expression: this.editorFormulaExpression,
            fieldKey: this.selectedElementFieldKey,
            targetType: this.editorElementType,
            elements: this.elements,
            insideRepeatGroup: this.selectedElementIsInsideRepeatGroup,
            sourceValues: this.formulaSourceValues()
        });
        this.editorFormulaPreviewValue = preview.value;
        this.editorFormulaError = preview.valid ? '' : preview.message;
    }

    updatePostSubmitFormulaPreview() {
        if (!this.draftPostSubmitAutoLinkEnabled || !this.postSubmitUrlModeIsFormula) {
            this.draftPostSubmitUrlFormulaPreviewValue = '';
            this.draftPostSubmitUrlFormulaError = '';
            return;
        }
        const preview = previewFormulaValue({
            expression: this.draftPostSubmitUrlFormula,
            fieldKey: '',
            targetType: 'text',
            elements: this.elements,
            sourceValues: this.formulaSourceValues(),
            allowFormulaReferences: true
        });
        this.draftPostSubmitUrlFormulaPreviewValue = preview.value || '';
        if (!preview.valid) {
            this.draftPostSubmitUrlFormulaError = preview.message;
            return;
        }
        const previewUrl = String(preview.value || '').trim();
        this.draftPostSubmitUrlFormulaError = previewUrl && !this.isAbsoluteHttpUrl(previewUrl)
            ? 'Formula preview must be a valid http:// or https:// URL, or blank.'
            : '';
    }

    isAbsoluteHttpUrl(value) {
        try {
            const parsed = new URL(String(value || '').trim());
            return parsed.protocol === 'http:' || parsed.protocol === 'https:';
        } catch (error) {
            return false;
        }
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
            return parts.join(' | ');
        }
        if (item.elementType === 'fileUpload') {
            const defaults = this.fileUploadLanguageDefaults(this.draftLanguageCode);
            const parts = [];
            const extensions = this.normalizeAllowedExtensions(config.allowedExtensions);
            if (extensions.length) {
                parts.push(this.interpolateText(defaults.allowedTypes, { types: extensions.join(', ') }));
            }
            const maxFileSizeMb = Number(config.maxFileSizeMb);
            if (Number.isFinite(maxFileSizeMb) && maxFileSizeMb > 0) {
                parts.push(this.interpolateText(defaults.maxSize, { size: maxFileSizeMb }));
            }
            if (config.allowMultiple === true) {
                parts.push(defaults.multipleAllowed);
            }
            return parts.join(' ? ');
        }
        const parts = [];
        if (config.minValue !== null && config.minValue !== undefined && String(config.minValue) !== '') {
            parts.push(`Min ${config.minValue}`);
        }
        if (config.maxValue !== null && config.maxValue !== undefined && String(config.maxValue) !== '') {
            parts.push(`Max ${config.maxValue}`);
        }
        return parts.join(' ? ');
    }

    conditionalSummary(item) {
        const config = this.parseConfig(item.configJson);
        const conditions = this.normalizeVisibilityConditions(
            config.conditionalConditions,
            config.conditionalFieldKey,
            config.conditionalOperator,
            config.conditionalValue
        );
        if (!config.conditionalEnabled || !conditions.length) {
            return '';
        }
        return this.buildConditionalSummaryFromConditions(
            conditions,
            this.normalizeVisibilityExpression(config.conditionalExpression, conditions.length)
        );
    }

    buildConditionalSummary(fieldKey, operator, compareValue) {
        let summary = `Show when ${fieldKey} ${operator || 'equals'}`;
        if (!['isTrue', 'isFalse', 'isBlank', 'isNotBlank'].includes(operator) && compareValue) {
            summary += ` ${compareValue}`;
        }
        return summary;
    }

    buildConditionalSummaryFromConditions(conditions, expression) {
        const sanitized = this.sanitizeVisibilityConditions(conditions);
        if (!sanitized.length) {
            return '';
        }
        if (sanitized.length === 1) {
            const first = sanitized[0];
            return this.buildConditionalSummary(first.fieldKey, first.operator, first.value);
        }
        return `Show when ${this.normalizeVisibilityExpression(expression, sanitized.length)}`;
    }

    labelBold(item) {
        const config = this.parseConfig(item.configJson);
        return config.labelBold === true;
    }

    labelItalic(item) {
        const config = this.parseConfig(item.configJson);
        return config.labelItalic === true;
    }

    labelUnderline(item) {
        const config = this.parseConfig(item.configJson);
        return config.labelUnderline === true;
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

    sectionColumnStyle(configJson) {
        const config = this.parseConfig(configJson);
        return `--preview-grid-template:${this.columnTemplate(this.sectionColumns(configJson), config.columnLayout)};`;
    }

    clearPublishResult() {
        this.publishResult = null;
        this.publishResultContextVersionId = '';
    }

    handleFormChange(event) {
        this.selectedFormId = event.detail.value;
        this.storeSelectedForm(this.selectedFormId);
        this.selectedVersionId = null;
        this.clearStoredVersion();
        this.selectedElementId = null;
        this.clearPublishResult();
        this.clearUndoStack();
        this.loadWorkspace(this.selectedProjectId, this.selectedFormId, null);
    }

    handleFormSortChange(event) {
        const nextMode = event.detail.value;
        if (!['nameAsc', 'nameDesc', 'numberAsc', 'numberDesc'].includes(nextMode)) {
            return;
        }
        this.formSortMode = nextMode;
        this.storeFormSortMode(nextMode);
        this.applyFormSort();
    }

    applyFormSort() {
        const options = [...(this.rawFormOptions || [])];
        const byName = (left, right) => String(left.label || '').localeCompare(String(right.label || ''), undefined, {
            numeric: true,
            sensitivity: 'base'
        });
        const byNumberAsc = (left, right) => this.compareFormNumber(left, right, 1, byName);
        const byNumberDesc = (left, right) => this.compareFormNumber(left, right, -1, byName);

        if (this.formSortMode === 'nameDesc') {
            options.sort((left, right) => byName(right, left));
        } else if (this.formSortMode === 'numberAsc') {
            options.sort(byNumberAsc);
        } else if (this.formSortMode === 'numberDesc') {
            options.sort(byNumberDesc);
        } else {
            options.sort(byName);
        }
        this.formOptions = options;
    }

    compareFormNumber(left, right, direction, byName) {
        const leftNumber = this.extractFormNumber(left.label);
        const rightNumber = this.extractFormNumber(right.label);
        if (leftNumber === null && rightNumber === null) {
            return byName(left, right);
        }
        if (leftNumber === null) {
            return 1;
        }
        if (rightNumber === null) {
            return -1;
        }
        return direction * (leftNumber - rightNumber) || byName(left, right);
    }

    extractFormNumber(label) {
        const match = String(label || '').match(/\(form(\d+)\)/i);
        return match ? Number(match[1]) : null;
    }
    handleProjectChange(event) {
        this.selectedProjectId = event.detail.value;
        this.storeSelectedProject(this.selectedProjectId);
        this.selectedFormId = null;
        this.selectedVersionId = null;
        this.selectedElementId = null;
        this.clearPublishResult();
        this.clearUndoStack();
        this.clearStoredForm();
        this.clearStoredVersion();
        this.loadWorkspace(this.selectedProjectId, null, null);
    }

    handleVersionChange(event) {
        this.selectedVersionId = event.detail.value;
        this.storeSelectedVersion(this.selectedVersionId);
        this.selectedElementId = null;
        this.clearPublishResult();
        this.clearUndoStack();
        this.loadWorkspace(this.selectedProjectId, this.selectedFormId, this.selectedVersionId);
    }

    handleFormActionMenuSelect(event) {
        const action = event.detail.value;
        if (action === 'newForm') {
            this.handleOpenNewFormModal();
        } else if (action === 'createProject') {
            this.handleOpenCreateProjectModal();
        } else if (action === 'createFromLayout') {
            this.handleOpenLayoutImportModal();
        } else if (action === 'cloneForm') {
            this.handleOpenCloneFormModal();
        } else if (action === 'exportForm') {
            this.handleExportForm();
        } else if (action === 'importForm') {
            this.handleOpenImportFormPicker();
        } else if (action === 'restoreFromPublished') {
            this.handleRestoreFromPublished();
        }
    }

    async handleExportForm() {
        if (this.exportFormDisabled) {
            return;
        }
        this.isExportingForm = true;
        this.errorMessage = '';
        try {
            const packageJson = await exportPortableForm({
                formId: this.selectedFormId,
                versionId: this.selectedVersionId
            });
            const fileName = this.exportFormFileName();
            this.downloadTextFile(fileName, packageJson, 'application/json');
            this.showToast(
                'Form exported',
                'Import this file in another org to create the same form number or add a new draft version.',
                'success'
            );
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isExportingForm = false;
        }
    }

    handleOpenImportFormPicker() {
        this.showImportFormModal = true;
        if (this.importFormActionDisabled) {
            return;
        }
        this.errorMessage = '';
        this.importPackageJson = '';
        this.importFileName = '';
        this.importPreview = null;
        this.importProjectId = this.selectedProjectId || '__default__';
        this.importRawJsonText = '';
        this.importStatusMessage = 'Choose a JSON export file or import a published form from a connected org.';
        this.connectedImportView = null;
        this.connectedSnapshots = [];
        this.connectedImportError = '';
        this.showImportFormModal = true;
        this.loadConnectedImportSources();
    }

    handleChooseImportFile() {
        if (this.importFormActionDisabled) {
            return;
        }
        const input = this.template.querySelector('[data-id="portable-form-import-hidden"]');
        if (input) {
            input.value = null;
            input.click();
        }
    }

    async loadConnectedImportSources() {
        if (this.isLoadingConnectedImportSources) {
            return;
        }
        this.isLoadingConnectedImportSources = true;
        this.connectedImportError = '';
        try {
            const view = await getConnectedImportView();
            this.connectedImportView = view || null;
            if (view?.success !== true) {
                this.connectedImportError = view?.errorMessage || 'Connected org forms are not available right now.';
                this.connectedSnapshots = [];
                return;
            }
            this.connectedSnapshots = (view.snapshots || []).map((snapshot) => this.normalizeConnectedSnapshot(snapshot));
        } catch (error) {
            this.connectedImportError = this.normalizeError(error);
            this.connectedSnapshots = [];
        } finally {
            this.isLoadingConnectedImportSources = false;
        }
    }

    normalizeConnectedSnapshot(snapshot) {
        const sourceOrgName = snapshot?.sourceOrgName || snapshot?.sourceOrgId || 'Connected org';
        const formKey = snapshot?.globalFormKey || 'form';
        const formName = snapshot?.formName && snapshot.formName !== formKey ? snapshot.formName : '';
        const version = snapshot?.publishedVersionNumber ? `v${snapshot.publishedVersionNumber}` : 'Published';
        return {
            ...snapshot,
            key: `${snapshot?.sourceOrgId || sourceOrgName}:${formKey}`,
            formKeyLabel: formKey,
            formNameLabel: formName,
            versionLabel: version,
            sourceLabel: sourceOrgName,
            themeNameLabel: snapshot?.themeName || 'Default theme',
            publishedDateLabel: this.formatConnectedSnapshotDate(snapshot?.publishedAt)
        };
    }

    formatConnectedSnapshotDate(value) {
        const raw = String(value || '').trim();
        if (!raw) {
            return '';
        }
        const match = raw.match(/^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})/);
        return match ? `${match[1]} ${match[2]}` : raw;
    }

    async handleConnectedSnapshotSelected(event) {
        if (this.connectedSnapshotActionDisabled) {
            return;
        }
        const sourceOrgId = event.currentTarget?.dataset?.sourceOrgId;
        const globalFormKey = event.currentTarget?.dataset?.formKey;
        if (!sourceOrgId || !globalFormKey) {
            return;
        }

        this.isLoadingConnectedSnapshot = true;
        this.errorMessage = '';
        try {
            const result = await getSnapshotPackage({ sourceOrgId, globalFormKey });
            if (result?.success !== true || !result.portableJson) {
                throw new Error(result?.errorMessage || 'Connected form snapshot is not available.');
            }
            const snapshot = result.snapshot || {};
            const sourceName = snapshot.sourceOrgName || sourceOrgId;
            const formName = snapshot.formName || globalFormKey;
            await this.inspectImportPackageJson(result.portableJson, `Connected org: ${sourceName} / ${globalFormKey} - ${formName}`);
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            this.importStatusMessage = this.errorMessage;
            this.showToast('Connected import not ready', this.errorMessage, 'error');
        } finally {
            this.isLoadingConnectedSnapshot = false;
        }
    }
    async handleImportFormFileSelected(event) {
        const files = event.detail?.files || event.target?.files || [];
        const file = files && files.length ? files[0] : null;
        if (!file) {
            this.importStatusMessage = 'No file was selected.';
            return;
        }

        this.importFileName = file.name || 'TwinaForms export';
        this.importStatusMessage = `Reading ${this.importFileName}...`;
        try {
            const packageJson = await this.readTextFile(file);
            this.importRawJsonText = packageJson;
            await this.inspectImportPackageJson(packageJson, this.importFileName);
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            this.importStatusMessage = this.errorMessage;
            this.showToast('Import file not ready', this.errorMessage, 'error');
        }
    }

    handleImportJsonTextChange(event) {
        this.importRawJsonText = event.detail?.value ?? event.target?.value ?? '';
        this.importPackageJson = '';
        this.importPreview = null;
        this.importStatusMessage = this.importRawJsonText.trim() ? 'JSON text is ready to preview.' : '';
    }

    async handleInspectImportText() {
        if (this.inspectImportTextDisabled) {
            return;
        }
        await this.inspectImportPackageJson(this.importRawJsonText, this.importFileName || 'Pasted JSON');
    }

    async inspectImportPackageJson(packageJson, fileName) {
        this.isInspectingFormImport = true;
        this.errorMessage = '';
        this.importPackageJson = '';
        this.importPreview = null;
        this.importThemeConflictChoice = '';
        this.importDecision = '';
        this.importFileName = fileName || 'TwinaForms export';
        this.importProjectId = this.selectedProjectId || '__default__';
        this.importRawJsonText = '';
        this.importStatusMessage = '';
        this.showImportFormModal = true;
        try {
            JSON.parse(packageJson);
            this.importStatusMessage = 'Checking import package...';
            const previewJson = await inspectPortableFormImport({ packageJson });
            this.importPackageJson = packageJson;
            this.importPreview = JSON.parse(previewJson);
            this.importThemeConflictChoice = this.importRequiresThemeConflictChoice ? 'createCopy' : '';
            this.importStatusMessage = 'Import preview is ready.';
            this.showToast('Import preview ready', 'Review the import details, then click Import.', 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            this.importStatusMessage = this.errorMessage;
            this.showToast('Import file not ready', this.errorMessage, 'error');
        } finally {
            this.isInspectingFormImport = false;
        }
    }

    handleImportProjectChange(event) {
        this.importProjectId = event.detail.value || '__default__';
    }

    handleImportThemeConflictChange(event) {
        this.importThemeConflictChoice = event.detail.value || '';
    }

    handleImportDecisionChange(event) {
        this.importDecision = event.detail.value || '';
    }

    handleCloseImportFormModal() {
        if (this.isImportingForm) {
            return;
        }
        this.showImportFormModal = false;
        this.importPackageJson = '';
        this.importFileName = '';
        this.importPreview = null;
        this.importProjectId = '__default__';
        this.importThemeConflictChoice = '';
        this.importDecision = '';
    }

    async handleImportForm() {
        if (this.importFormConfirmDisabled) {
            return;
        }

        this.isImportingForm = true;
        this.errorMessage = '';
        try {
            const options = {
                projectId: this.importWillCreateForm && this.importProjectId !== '__default__' ? this.importProjectId : null,
                themeConflictChoice: this.importThemeConflictChoice || null,
                importMode: this.importDecision || null
            };
            const resultJson = await importPortableForm({
                packageJson: this.importPackageJson,
                optionsJson: JSON.stringify(options)
            });
            const result = JSON.parse(resultJson);
            const projectId = result.projectId || this.selectedProjectId || null;
            this.selectedProjectId = projectId;
            this.selectedFormId = result.formId;
            this.selectedVersionId = result.versionId;
            this.selectedElementId = null;
            this.clearPublishResult();
            this.clearUndoStack();
            if (projectId) {
                this.storeSelectedProject(projectId);
            }
            this.storeSelectedForm(result.formId);
            this.storeSelectedVersion(result.versionId);
            this.showImportFormModal = false;
            this.importPackageJson = '';
            this.importFileName = '';
            this.importPreview = null;
        this.importProjectId = '__default__';
            this.importThemeConflictChoice = '';
            this.importDecision = '';
            await this.loadWorkspace(projectId, result.formId, result.versionId);
            const actionLabel = result.targetAction === 'createForm' ? 'Form imported' : 'Draft version imported';
            this.showToast(actionLabel, `${result.globalFormKey || 'Form'} is ready in Draft mode.`, 'success');

        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            this.showToast('Import failed', this.errorMessage, 'error');
        } finally {
            this.isImportingForm = false;
        }
    }


    handleOpenNewFormModal() {
        if (this.newFormActionDisabled) {
            return;
        }
        this.newFormDescription = '';
        this.newFormProjectId = this.selectedProjectId || '';
        this.newFormProjectName = '';
        this.showNewFormModal = true;
    }

    handleOpenCreateProjectModal() {
        this.newProjectName = '';
        this.showCreateProjectModal = true;
    }

    async handleOpenLayoutImportModal() {
        if (!this.enableProPageLayoutClone) {
            this.showToast('Pro feature', 'Page Layout Clone is available on Pro plans only.', 'warning');
            return;
        }
        this.errorMessage = '';
        this.layoutImportDescription = '';
        this.layoutImportProjectId = this.selectedProjectId || '';
        this.layoutImportProjectName = '';
        this.layoutImportObjectApiName = '';
        this.layoutImportLayoutKey = '';
        this.layoutImportMode = 'secureUpdateOrCreate';
        this.layoutImportLanguageCode = '';
        this.layoutImportPreview = null;
        this.isLoadingLayoutMetadata = false;
        this.layoutImportLayoutOptions = [];
        if (!this.salesforceObjectOptions?.length) {
            try {
                this.salesforceObjectOptions = await getObjectOptions();
            } catch (error) {
                this.errorMessage = this.normalizeError(error);
            }
        }
        this.showLayoutImportModal = true;
    }

    handleOpenCloneFormModal() {
        if (this.cloneFormDisabled) {
            return;
        }
        const sourceName = this.selectedFormDescription || this.selectedFormName || 'Form';
        this.cloneFormDescription = `${sourceName} Copy`;
        this.cloneFormProjectId = this.selectedProjectId || '';
        this.cloneFormProjectName = '';
        this.showCloneFormModal = true;
    }

    handleOpenDisplayTextModal() {
        this.modalDisplayText = this.editorDisplayText || (this.selectedElementIsMergedDocument ? '<p>Merged document text</p>' : '<p>Display text</p>');
        this.modalMergeAlias = '';
        this.modalMergeFieldPath = '';
        this.showDisplayTextModal = true;
    }

    handleOpenCustomJsModal() {
        if (!this.enableProCustomJs) {
            this.showToast('Upgrade required', 'Custom JavaScript is available on Pro plans only.', 'warning');
            return;
        }
        this.modalCustomJs = this.selectedVersionCustomJs || this.draftCustomJs || '';
        this.showCustomJsModal = true;
    }

    handlePostSubmitFormulaButtonMouseDown(event) {
        event.preventDefault();
        event.stopPropagation();
    }

    handleFormulaButtonMouseDown(event) {
        event.preventDefault();
        event.stopPropagation();
    }

    defaultPostSubmitFormulaExample() {
        const fields = (this.elements || []).filter((item) =>
            item?.fieldKey
            && ['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'radio', 'ranking', 'hidden'].includes(item.elementType)
            && !(item.parentElementId && this.isElementInsideRepeatGroup(item))
        );
        const byKeyOrLabel = (pattern) => fields.find((item) =>
            pattern.test(String(item.fieldKey || '')) || pattern.test(String(item.label || ''))
        );
        const countryField = byKeyOrLabel(/country/i) || fields.find((item) => ['select', 'radio', 'text'].includes(item.elementType)) || fields[0];
        const emailField = fields.find((item) => item.elementType === 'email') || byKeyOrLabel(/email/i) || fields.find((item) => item !== countryField) || countryField;
        const countryRef = countryField?.fieldKey ? `{${countryField.fieldKey}}` : '{Country}';
        const emailRef = emailField?.fieldKey ? `{${emailField.fieldKey}}` : '{Email}';
        return [
            'IF(',
            `  ${countryRef} == "US",`,
            `  CONCAT("https://example.com/us-thank-you?email=", URLENCODE(${emailRef})),`,
            `  CONCAT("https://example.com/global-thank-you?email=", URLENCODE(${emailRef}))`,
            ')'
        ].join('\n');
    }

    handleOpenPostSubmitFormulaModal(event) {
        event?.preventDefault();
        event?.stopPropagation();
        this.modalPostSubmitUrlFormula = (this.draftPostSubmitUrlFormula || '').trim()
            ? this.draftPostSubmitUrlFormula
            : this.defaultPostSubmitFormulaExample();
        this.modalPostSubmitUrlFormulaError = '';
        this.modalPostSubmitUrlFormulaPreviewValue = '';
        this.selectedPostSubmitFormulaFieldToken = '';
        this.showPostSubmitFormulaModal = true;
    }

    handleOpenFieldFormulaModal(event) {
        event?.preventDefault();
        event?.stopPropagation();
        if (!this.selectedElementSupportsFormula) {
            return;
        }
        this.modalFormulaExpression = this.editorFormulaExpression || '';
        this.modalFormulaError = '';
        this.modalFormulaPreviewValue = '';
        this.selectedFormulaFieldToken = '';
        this.showFieldFormulaModal = true;
    }

    handleOpenButtonParameterFormulaModal(event) {
        event?.preventDefault();
        event?.stopPropagation();
        const index = Number(event.currentTarget.dataset.index);
        const parameter = (this.editorButtonQueryParameters || [])[index];
        if (!parameter) {
            return;
        }
        this.modalButtonParameterIndex = index;
        this.modalButtonParameterFormula = parameter.valueFormula || '';
        this.modalButtonParameterFormulaError = '';
        this.modalButtonParameterFormulaPreviewValue = '';
        this.selectedButtonParameterFormulaFieldToken = '';
        this.showButtonParameterFormulaModal = true;
    }

    handleCloseDisplayTextModal() {
        this.showDisplayTextModal = false;
        this.modalDisplayText = '';
        this.modalMergeAlias = '';
        this.modalMergeFieldPath = '';
    }

    handleCloseCustomJsModal() {
        this.showCustomJsModal = false;
        this.modalCustomJs = '';
    }

    handleClosePostSubmitFormulaModal() {
        this.showPostSubmitFormulaModal = false;
        this.modalPostSubmitUrlFormula = '';
        this.modalPostSubmitUrlFormulaError = '';
        this.modalPostSubmitUrlFormulaPreviewValue = '';
        this.selectedPostSubmitFormulaFieldToken = '';
    }

    handleCloseFieldFormulaModal() {
        this.showFieldFormulaModal = false;
        this.modalFormulaExpression = '';
        this.modalFormulaPreviewValue = '';
        this.modalFormulaError = '';
        this.selectedFormulaFieldToken = '';
    }

    handleCloseButtonParameterFormulaModal() {
        this.showButtonParameterFormulaModal = false;
        this.modalButtonParameterIndex = null;
        this.modalButtonParameterFormula = '';
        this.modalButtonParameterFormulaPreviewValue = '';
        this.modalButtonParameterFormulaError = '';
        this.selectedButtonParameterFormulaFieldToken = '';
    }

    handleOpenDeleteFormModal() {
        this.deleteFormConfirmText = '';
        this.showDeleteFormModal = true;
    }

    handleCloseDeleteFormModal() {
        if (this.isDeletingForm) {
            return;
        }
        this.showDeleteFormModal = false;
        this.deleteFormConfirmText = '';
    }

    handleDeleteFormConfirmTextChange(event) {
        this.deleteFormConfirmText = event.detail.value || '';
    }

    handleCloseNewFormModal() {
        if (this.isCreatingForm) {
            return;
        }
        this.showNewFormModal = false;
        this.newFormDescription = '';
        this.newFormProjectId = '';
        this.newFormProjectName = '';
    }

    handleCloseCreateProjectModal() {
        if (this.isCreatingProject) {
            return;
        }
        this.showCreateProjectModal = false;
        this.newProjectName = '';
    }

    handleCloseLayoutImportModal() {
        if (this.isImportingLayout) {
            return;
        }
        this.showLayoutImportModal = false;
        this.layoutImportDescription = '';
        this.layoutImportProjectId = '';
        this.layoutImportProjectName = '';
        this.layoutImportObjectApiName = '';
        this.layoutImportLayoutKey = '';
        this.layoutImportLanguageCode = '';
        this.layoutImportPreview = null;
        this.isLoadingLayoutMetadata = false;
        this.layoutImportLayoutOptions = [];
    }

    handleAcceptLayoutImportResult() {
        this.showLayoutImportResultModal = false;
        this.layoutImportResult = null;
    }

    parseLayoutImportDiagnostics(rawDiagnostics, result) {
        if (rawDiagnostics) {
            try {
                const parsed = JSON.parse(rawDiagnostics);
                if (parsed && typeof parsed === 'object') {
                    return parsed;
                }
            } catch (error) {
                // Diagnostics are helpful but not required for the created form.
            }
        }
        return {
            objectApiName: this.layoutImportObjectApiName,
            objectLabel: this.layoutImportObjectApiName,
            layoutLabel: this.layoutImportLayoutKey,
            mode: this.layoutImportMode,
            summary: {
                importedFieldCount: result?.importedFieldCount || 0,
                createOnlyFieldCount: 0,
                skippedFieldCount: result?.skippedFieldCount || 0
            },
            includedNotes: [],
            skippedFields: [],
            warnings: result?.warnings || []
        };
    }

    shouldShowLayoutImportDiagnostics(diagnostics) {
        return (diagnostics?.skippedFields || []).length > 0
            || (diagnostics?.includedNotes || []).length > 0;
    }

    handleCloseCloneFormModal() {
        if (this.isCloningForm) {
            return;
        }
        this.showCloneFormModal = false;
        this.cloneFormDescription = '';
        this.cloneFormProjectId = '';
        this.cloneFormProjectName = '';
    }

    handleNewFormDescriptionChange(event) {
        this.newFormDescription = event.detail.value || '';
    }

    handleNewFormProjectChange(event) {
        this.newFormProjectId = event.detail.value || '';
        if (this.newFormProjectId !== '__new__') {
            this.newFormProjectName = '';
        }
    }

    handleNewProjectNameChange(event) {
        this.newFormProjectName = event.detail.value || '';
    }

    handleCreateProjectNameChange(event) {
        this.newProjectName = event.detail.value || '';
    }

    handleLayoutImportDescriptionChange(event) {
        this.layoutImportDescription = event.detail.value || '';
    }

    handleLayoutImportProjectChange(event) {
        this.layoutImportProjectId = event.detail.value || '';
        if (this.layoutImportProjectId !== '__new__') {
            this.layoutImportProjectName = '';
        }
    }

    handleLayoutImportProjectNameChange(event) {
        this.layoutImportProjectName = event.detail.value || '';
    }

    async handleLayoutImportLanguageChange(event) {
        this.layoutImportLanguageCode = event.detail.value || '';
        this.layoutImportLayoutKey = '';
        this.layoutImportPreview = null;
        this.layoutImportLayoutOptions = [];
        if (!this.layoutImportObjectApiName || !this.layoutImportLanguageCode) {
            return;
        }
        await this.loadLayoutImportOptionsAndPreview();
    }

    async handleLayoutImportObjectChange(event) {
        this.layoutImportObjectApiName = event.detail.value || '';
        this.layoutImportLayoutKey = '';
        this.layoutImportPreview = null;
        this.layoutImportLayoutOptions = [];
        if (!this.layoutImportObjectApiName || !this.layoutImportLanguageCode) {
            return;
        }
        await this.loadLayoutImportOptionsAndPreview();
    }

    async loadLayoutImportOptionsAndPreview() {
        this.isLoadingLayoutMetadata = true;
        try {
            this.layoutImportLayoutOptions = await getPageLayoutImportOptions({
                objectApiName: this.layoutImportObjectApiName,
                languageCode: this.layoutImportLanguageCode
            });
            this.layoutImportLayoutKey = this.layoutImportLayoutOptions?.[0]?.value || '';
            await this.refreshLayoutImportPreview({ keepLoading: true });
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoadingLayoutMetadata = false;
        }
    }

    async handleLayoutImportLayoutChange(event) {
        this.layoutImportLayoutKey = event.detail.value || '';
        await this.refreshLayoutImportPreview();
    }

    async handleLayoutImportModeChange(event) {
        this.layoutImportMode = event.detail.value || 'secureUpdateOrCreate';
        if (this.layoutImportMode === 'create') {
            // Related records need a verified contact to reach the parent record.
            this.layoutImportIncludeRelated = false;
            this.resetRelatedSelections();
        }
        await this.refreshLayoutImportPreview();
    }

    async refreshLayoutImportPreview(options = {}) {
        if (!this.layoutImportObjectApiName || !this.layoutImportLayoutKey) {
            this.layoutImportPreview = null;
            return;
        }
        const ownsLoading = !options.keepLoading;
        if (ownsLoading) {
            this.isLoadingLayoutMetadata = true;
        }
        try {
            this.layoutImportPreview = await previewPageLayoutImport({
                objectApiName: this.layoutImportObjectApiName,
                layoutKey: this.layoutImportLayoutKey,
                mode: this.layoutImportMode,
                languageCode: this.layoutImportLanguageCode
            });
        } catch (error) {
            this.layoutImportPreview = null;
            this.errorMessage = this.normalizeError(error);
        } finally {
            if (ownsLoading) {
                this.isLoadingLayoutMetadata = false;
            }
        }
    }

    handleCloneFormDescriptionChange(event) {
        this.cloneFormDescription = event.detail.value || '';
    }

    handleCloneFormProjectChange(event) {
        this.cloneFormProjectId = event.detail.value || '';
        if (this.cloneFormProjectId !== '__new__') {
            this.cloneFormProjectName = '';
        }
    }

    handleCloneProjectNameChange(event) {
        this.cloneFormProjectName = event.detail.value || '';
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
                projectId: this.newFormProjectId === '__new__' ? null : (this.newFormProjectId || null),
                newProjectName: this.newFormProjectId === '__new__' ? this.newFormProjectName : '',
                themeId: this.selectedThemeId || null
            });
            this.selectedProjectId = result.projectId;
            this.selectedFormId = result.formId;
            this.selectedVersionId = result.versionId;
            this.selectedElementId = null;
            this.clearPublishResult();
            this.clearUndoStack();
            this.storeSelectedProject(result.projectId);
            this.storeSelectedForm(result.formId);
            this.storeSelectedVersion(result.versionId);
            this.showNewFormModal = false;
            this.newFormDescription = '';
            this.newFormProjectId = '';
            this.newFormProjectName = '';
            await this.loadWorkspace(result.projectId, result.formId, result.versionId);
            this.showToast('Form created', `${result.formName} is ready in Draft mode.`, 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isCreatingForm = false;
        }
    }

    async handleCreateProject() {
        if (this.createProjectDisabled) {
            return;
        }
        this.isCreatingProject = true;
        this.errorMessage = '';
        try {
            const result = await createProject({ projectName: this.newProjectName });
            this.selectedProjectId = result.value;
            this.selectedProjectName = result.label;
            this.selectedFormId = null;
            this.selectedVersionId = null;
            this.selectedElementId = null;
            this.storeSelectedProject(result.value);
            this.clearStoredForm();
            this.clearStoredVersion();
            this.clearUndoStack();
            this.showCreateProjectModal = false;
            this.newProjectName = '';
            await this.loadWorkspace(result.value, null, null);
            this.showToast('Project created', `${result.label} is ready for forms.`, 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isCreatingProject = false;
        }
    }

    async handleCreateFromLayout() {
        if (this.layoutImportCreateDisabled) {
            return;
        }

        this.isImportingLayout = true;
        this.errorMessage = '';
        try {
            const result = await createFormFromPageLayout({
                description: this.layoutImportDescription,
                projectId: this.layoutImportProjectId === '__new__' ? null : (this.layoutImportProjectId || null),
                newProjectName: this.layoutImportProjectId === '__new__' ? this.layoutImportProjectName : '',
                themeId: this.selectedThemeId || null,
                objectApiName: this.layoutImportObjectApiName,
                layoutKey: this.layoutImportLayoutKey,
                mode: this.layoutImportMode,
                languageCode: this.layoutImportLanguageCode,
                relatedListJson: this.buildRelatedListJson()
            });
            this.selectedProjectId = result.projectId;
            this.selectedFormId = result.formId;
            this.selectedVersionId = result.versionId;
            this.selectedElementId = null;
            this.clearPublishResult();
            this.clearUndoStack();
            this.storeSelectedProject(result.projectId);
            this.storeSelectedForm(result.formId);
            this.storeSelectedVersion(result.versionId);
            this.layoutImportResult = this.parseLayoutImportDiagnostics(result.importDiagnosticsJson, result);
            this.showLayoutImportModal = false;
            this.showLayoutImportResultModal = this.shouldShowLayoutImportDiagnostics(this.layoutImportResult);
            this.layoutImportDescription = '';
            this.layoutImportProjectId = '';
            this.layoutImportProjectName = '';
            this.layoutImportObjectApiName = '';
            this.layoutImportLanguageCode = '';
            this.layoutImportPreview = null;
            await this.loadWorkspace(result.projectId, result.formId, result.versionId);
            const importedCount = result.importedFieldCount || 0;
            this.showToast('Form created', `${result.formName} imported ${importedCount} Salesforce fields.`, 'success');

        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isImportingLayout = false;
        }
    }

    async handleCloneForm() {
        if (this.cloneFormCreateDisabled) {
            return;
        }

        this.isCloningForm = true;
        this.errorMessage = '';
        try {
            const result = await cloneFormWithDraftVersion({
                sourceFormId: this.selectedFormId,
                sourceVersionId: this.selectedVersionId,
                description: this.cloneFormDescription,
                projectId: this.cloneFormProjectId === '__new__' ? null : (this.cloneFormProjectId || null),
                newProjectName: this.cloneFormProjectId === '__new__' ? this.cloneFormProjectName : ''
            });
            this.selectedProjectId = result.projectId;
            this.selectedFormId = result.formId;
            this.selectedVersionId = result.versionId;
            this.selectedElementId = null;
            this.clearPublishResult();
            this.clearUndoStack();
            this.storeSelectedProject(result.projectId);
            this.storeSelectedForm(result.formId);
            this.storeSelectedVersion(result.versionId);
            this.showCloneFormModal = false;
            this.cloneFormDescription = '';
            this.cloneFormProjectId = '';
            this.cloneFormProjectName = '';
            await this.loadWorkspace(result.projectId, result.formId, result.versionId);
            this.showToast('Form cloned', `${result.formName} is ready in Draft mode.`, 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isCloningForm = false;
        }
    }

    async handleRestoreFromPublished() {
        if (this.restorePublishedDisabled) {
            return;
        }

        this.isRestoringPublished = true;
        this.errorMessage = '';
        try {
            const result = await restoreDraftFromPublished({
                formId: this.selectedFormId,
                sourceVersionId: this.selectedVersionId
            });
            this.selectedProjectId = result.projectId;
            this.selectedFormId = result.formId;
            this.selectedVersionId = result.versionId;
            this.selectedElementId = null;
            this.clearPublishResult();
            this.clearUndoStack();
            this.storeSelectedProject(result.projectId);
            this.storeSelectedForm(result.formId);
            this.storeSelectedVersion(result.versionId);
            await this.loadWorkspace(result.projectId, result.formId, result.versionId);
            this.showToast('Draft restored', 'A new draft version was created from the published form.', 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isRestoringPublished = false;
        }
    }

    async handleDeleteForm() {
        if (this.deleteFormDisabled) {
            return;
        }

        const projectId = this.selectedProjectId;
        const formName = this.selectedFormName || 'The form';
        this.isDeletingForm = true;
        this.errorMessage = '';
        try {
            await deleteDesignerForm({
                formId: this.selectedFormId,
                confirmationText: this.deleteFormConfirmText
            });
            this.showDeleteFormModal = false;
            this.deleteFormConfirmText = '';
            this.selectedFormId = null;
            this.selectedVersionId = null;
            this.selectedElementId = null;
            this.clearPublishResult();
            this.clearUndoStack();
            this.clearStoredForm();
            this.clearStoredVersion();
            await this.loadWorkspace(projectId, null, null);
            this.showToast('Form deleted', `${formName} was deleted and published links were disabled.`, 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isDeletingForm = false;
        }
    }

    async saveFormSettings(nextValues, successMessage, options = {}) {
        if (!this.selectedFormId) {
            return;
        }
        const effectiveLanguageCode = (nextValues && nextValues.languageCode) || this.draftLanguageCode || 'en';
        const formUiDefaults = this.formUiLanguageDefaults(effectiveLanguageCode);
        const mergedValues = {
            formName: this.draftFormName,
            projectId: this.selectedProjectId || '',
            themeId: this.selectedThemeId || '',
            enableCaptcha: this.selectedFormCaptchaEnabled,
            languageCode: this.draftLanguageCode || 'en',
            submitSuccessMessage: this.draftSubmitSuccessMessage,
            rtlEnabled: this.draftRtlEnabled,
            postSubmitAutoLinkEnabled: this.draftPostSubmitAutoLinkEnabled,
            postSubmitUrlMode: this.draftPostSubmitUrlMode,
            postSubmitUrlTemplate: this.draftPostSubmitUrlTemplate,
            postSubmitUrlFormula: this.draftPostSubmitUrlFormula,
            postSubmitButtonLabel: this.draftPostSubmitButtonLabel,
            postSubmitDelaySeconds: 0,
            userVerificationEnabled: this.draftUserVerificationEnabled,
            userVerificationMatchField: this.draftUserVerificationMatchField || 'Email',
            userVerificationIntroText: this.draftUserVerificationIntroText,
            userVerificationSentMessage: this.draftUserVerificationSentMessage,
            userVerificationInvalidMessage: this.draftUserVerificationInvalidMessage,
            userVerificationVerifiedMessage: this.draftUserVerificationVerifiedMessage,
            userVerificationSendButtonLabel: this.draftUserVerificationSendButtonLabel,
            userVerificationVerifyButtonLabel: this.draftUserVerificationVerifyButtonLabel,
            userVerificationResendButtonLabel: this.draftUserVerificationResendButtonLabel,
            userVerificationExpiryMinutes: this.draftUserVerificationExpiryMinutes,
            userVerificationMaxAttempts: this.draftUserVerificationMaxAttempts,
            userVerificationAllowResend: this.draftUserVerificationAllowResend,
            userVerificationSessionMode: this.draftUserVerificationSessionMode,
            userVerificationSenderEmail: this.draftUserVerificationSenderEmail,
            submitLabel: this.draftSubmitLabel,
            submitConditionalEnabled: this.draftSubmitConditionalEnabled,
            submitConditionalFieldKey: this.draftSubmitConditionalFieldKey,
            submitConditionalOperator: this.draftSubmitConditionalOperator,
            submitConditionalValue: this.draftSubmitConditionalValue,
            submitConditionalConditionsJson: JSON.stringify(this.sanitizeVisibilityConditions(this.draftSubmitConditionalConditions)),
            submitConditionalExpression: this.normalizeVisibilityExpression(
                this.draftSubmitConditionalExpression,
                this.sanitizeVisibilityConditions(this.draftSubmitConditionalConditions).length
            ),
            ...(nextValues || {})
        };
        this.isSavingFormSettings = true;
        this.errorMessage = '';
        let saved = false;
        try {
            await updateFormSettings({
                formId: this.selectedFormId,
                versionId: this.selectedVersionId,
                formName: (mergedValues.formName || '').trim(),
                projectId: mergedValues.projectId === '' ? null : mergedValues.projectId,
                themeId: mergedValues.themeId === '' ? null : mergedValues.themeId,
                enableCaptcha: !!mergedValues.enableCaptcha,
                languageCode: mergedValues.languageCode || 'en',
                submitSuccessMessage: mergedValues.submitSuccessMessage || '',
                rtlEnabled: !!mergedValues.rtlEnabled,
                postSubmitAutoLinkEnabled: !!mergedValues.postSubmitAutoLinkEnabled,
                postSubmitUrlTemplate: mergedValues.postSubmitUrlTemplate || '',
                postSubmitButtonLabel: mergedValues.postSubmitButtonLabel || '',
                postSubmitDelaySeconds: 0,
                userVerificationEnabled: !!mergedValues.userVerificationEnabled,
                userVerificationMatchField: mergedValues.userVerificationMatchField || 'Email',
                userVerificationIntroText: mergedValues.userVerificationIntroText || '',
                userVerificationSentMessage: mergedValues.userVerificationSentMessage || '',
                userVerificationInvalidMessage: mergedValues.userVerificationInvalidMessage || '',
                userVerificationVerifiedMessage: mergedValues.userVerificationVerifiedMessage || '',
                userVerificationSendButtonLabel: mergedValues.userVerificationSendButtonLabel || '',
                userVerificationVerifyButtonLabel: mergedValues.userVerificationVerifyButtonLabel || '',
                userVerificationResendButtonLabel: mergedValues.userVerificationResendButtonLabel || '',
                userVerificationExpiryMinutes: Number(mergedValues.userVerificationExpiryMinutes) || 10,
                userVerificationMaxAttempts: Number(mergedValues.userVerificationMaxAttempts) || 5,
                userVerificationAllowResend: mergedValues.userVerificationAllowResend !== false,
                submitLabel: mergedValues.submitLabel || '',
                submitConditionalEnabled: !!mergedValues.submitConditionalEnabled,
                submitConditionalFieldKey: mergedValues.submitConditionalFieldKey || '',
                submitConditionalOperator: mergedValues.submitConditionalOperator || 'equals',
                submitConditionalValue: mergedValues.submitConditionalValue || '',
                submitConditionalConditionsJson: mergedValues.submitConditionalConditionsJson || '[]',
                submitConditionalExpression: mergedValues.submitConditionalExpression || ''
            });
            saved = true;
            this.selectedFormName = (mergedValues.formName || '').trim();
            this.selectedFormDescription = this.selectedFormName;
            this.draftFormName = this.selectedFormName;
            this.selectedProjectId = mergedValues.projectId || '';
            this.selectedThemeId = mergedValues.themeId || '';
            this.selectedFormCaptchaEnabled = !!mergedValues.enableCaptcha;
            this.selectedVersionLanguageCode = mergedValues.languageCode || 'en';
            setFormulaLanguage(this.selectedVersionLanguageCode);
            this.selectedVersionSubmitSuccessMessage = mergedValues.submitSuccessMessage || formUiDefaults.submitSuccessMessage;
            this.selectedVersionSubmitLabel = mergedValues.submitLabel || formUiDefaults.submitLabel;
            this.selectedVersionRtlEnabled = !!mergedValues.rtlEnabled;
            this.selectedVersionPostSubmitAutoLinkEnabled = !!mergedValues.postSubmitAutoLinkEnabled;
            this.selectedVersionPostSubmitUrlMode = mergedValues.postSubmitUrlMode === 'formula' ? 'formula' : 'template';
            this.selectedVersionPostSubmitUrlTemplate = (mergedValues.postSubmitUrlTemplate || '').trim();
            this.selectedVersionPostSubmitUrlFormula = (mergedValues.postSubmitUrlFormula || '').trim();
            this.selectedVersionPostSubmitButtonLabel = mergedValues.postSubmitButtonLabel || formUiDefaults.postSubmitButtonLabel;
            this.selectedVersionPostSubmitDelaySeconds = 0;
            this.selectedVersionUserVerificationEnabled = !!mergedValues.userVerificationEnabled;
            this.selectedVersionUserVerificationMatchField = mergedValues.userVerificationMatchField || 'Email';
            this.selectedVersionUserVerificationIntroText = this.normalizeUserVerificationValue(mergedValues.userVerificationIntroText, 'introText', this.selectedVersionLanguageCode);
            this.selectedVersionUserVerificationSentMessage = this.normalizeUserVerificationValue(mergedValues.userVerificationSentMessage, 'sentMessage', this.selectedVersionLanguageCode);
            this.selectedVersionUserVerificationInvalidMessage = this.normalizeUserVerificationValue(mergedValues.userVerificationInvalidMessage, 'invalidMessage', this.selectedVersionLanguageCode);
            this.selectedVersionUserVerificationVerifiedMessage = this.normalizeUserVerificationValue(mergedValues.userVerificationVerifiedMessage, 'verifiedMessage', this.selectedVersionLanguageCode);
            this.selectedVersionUserVerificationSendButtonLabel = this.normalizeUserVerificationValue(mergedValues.userVerificationSendButtonLabel, 'sendButtonLabel', this.selectedVersionLanguageCode);
            this.selectedVersionUserVerificationVerifyButtonLabel = this.normalizeUserVerificationValue(mergedValues.userVerificationVerifyButtonLabel, 'verifyButtonLabel', this.selectedVersionLanguageCode);
            this.selectedVersionUserVerificationResendButtonLabel = this.normalizeUserVerificationValue(mergedValues.userVerificationResendButtonLabel, 'resendButtonLabel', this.selectedVersionLanguageCode);
            this.selectedVersionUserVerificationExpiryMinutes = Math.max(1, Number(mergedValues.userVerificationExpiryMinutes) || 10);
            this.selectedVersionUserVerificationMaxAttempts = Math.max(1, Number(mergedValues.userVerificationMaxAttempts) || 5);
            this.selectedVersionUserVerificationAllowResend = mergedValues.userVerificationAllowResend !== false;
            this.selectedVersionUserVerificationSessionMode = mergedValues.userVerificationSessionMode === 'sameTabUntilMidnight'
                ? 'sameTabUntilMidnight'
                : 'short';
            this.selectedVersionUserVerificationSenderEmail = (mergedValues.userVerificationSenderEmail || '').trim().toLowerCase();
            this.selectedVersionSubmitConditionalEnabled = !!mergedValues.submitConditionalEnabled;
            this.selectedVersionSubmitConditionalFieldKey = mergedValues.submitConditionalFieldKey || '';
            this.selectedVersionSubmitConditionalOperator = mergedValues.submitConditionalOperator || 'equals';
            this.selectedVersionSubmitConditionalValue = mergedValues.submitConditionalValue || '';
            this.selectedVersionSubmitConditionalConditions = this.normalizeVisibilityConditions(
                this.parseConfig(mergedValues.submitConditionalConditionsJson || '[]'),
                this.selectedVersionSubmitConditionalFieldKey,
                this.selectedVersionSubmitConditionalOperator,
                this.selectedVersionSubmitConditionalValue
            );
            this.selectedVersionSubmitConditionalExpression = this.normalizeVisibilityExpression(
                mergedValues.submitConditionalExpression || '',
                this.selectedVersionSubmitConditionalConditions.length
            );
            this.draftSubmitSuccessMessage = this.selectedVersionSubmitSuccessMessage;
            this.draftLanguageCode = this.selectedVersionLanguageCode;
            this.draftSubmitLabel = this.selectedVersionSubmitLabel;
            this.draftRtlEnabled = this.selectedVersionRtlEnabled;
            this.draftPostSubmitAutoLinkEnabled = this.selectedVersionPostSubmitAutoLinkEnabled;
            this.draftPostSubmitUrlMode = this.selectedVersionPostSubmitUrlMode;
            this.draftPostSubmitUrlTemplate = this.selectedVersionPostSubmitUrlTemplate || this.defaultPostSubmitRedirectUrl;
            this.draftPostSubmitUrlFormula = this.selectedVersionPostSubmitUrlFormula;
            this.updatePostSubmitFormulaPreview();
            this.draftPostSubmitButtonLabel = this.selectedVersionPostSubmitButtonLabel;
            this.draftPostSubmitDelaySeconds = this.selectedVersionPostSubmitDelaySeconds;
            this.draftUserVerificationEnabled = this.selectedVersionUserVerificationEnabled;
            this.draftUserVerificationMatchField = this.selectedVersionUserVerificationMatchField;
            this.draftUserVerificationIntroText = this.selectedVersionUserVerificationIntroText;
            this.draftUserVerificationSentMessage = this.selectedVersionUserVerificationSentMessage;
            this.draftUserVerificationInvalidMessage = this.selectedVersionUserVerificationInvalidMessage;
            this.draftUserVerificationVerifiedMessage = this.selectedVersionUserVerificationVerifiedMessage;
            this.draftUserVerificationSendButtonLabel = this.selectedVersionUserVerificationSendButtonLabel;
            this.draftUserVerificationVerifyButtonLabel = this.selectedVersionUserVerificationVerifyButtonLabel;
            this.draftUserVerificationResendButtonLabel = this.selectedVersionUserVerificationResendButtonLabel;
            this.draftUserVerificationExpiryMinutes = this.selectedVersionUserVerificationExpiryMinutes;
            this.draftUserVerificationMaxAttempts = this.selectedVersionUserVerificationMaxAttempts;
            this.draftUserVerificationAllowResend = this.selectedVersionUserVerificationAllowResend;
            this.draftUserVerificationSessionMode = this.selectedVersionUserVerificationSessionMode;
            this.draftUserVerificationSenderEmail = this.selectedVersionUserVerificationSenderEmail;
            this.draftSubmitConditionalEnabled = this.selectedVersionSubmitConditionalEnabled;
            this.draftSubmitConditionalFieldKey = this.selectedVersionSubmitConditionalFieldKey;
            this.draftSubmitConditionalOperator = this.selectedVersionSubmitConditionalOperator;
            this.draftSubmitConditionalValue = this.selectedVersionSubmitConditionalValue;
            this.draftSubmitConditionalConditions = [...this.selectedVersionSubmitConditionalConditions];
            this.draftSubmitConditionalExpression = this.selectedVersionSubmitConditionalExpression;
            if (!options.skipReload) {
                await this.loadWorkspace(this.selectedProjectId, this.selectedFormId, this.selectedVersionId, true);
            }
            if (successMessage) {
                this.showToast('Form settings saved', successMessage, 'success');
            }
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isSavingFormSettings = false;
        }
        return saved;
    }

    async savePostSubmitRedirectSettings() {
        if (!this.selectedFormId || !this.selectedVersionId) {
            return false;
        }
        this.isSavingFormSettings = true;
        this.errorMessage = '';
        try {
            await updateVersionPostSubmitRedirectSettings({
                formId: this.selectedFormId,
                versionId: this.selectedVersionId,
                enabled: !!this.draftPostSubmitAutoLinkEnabled,
                urlMode: this.postSubmitUrlModeIsFormula ? 'formula' : 'template',
                urlTemplate: this.draftPostSubmitUrlTemplate || '',
                urlFormula: this.draftPostSubmitUrlFormula || '',
                buttonLabel: this.draftPostSubmitButtonLabel || '',
                delaySeconds: 0
            });
            this.selectedVersionPostSubmitAutoLinkEnabled = !!this.draftPostSubmitAutoLinkEnabled;
            this.selectedVersionPostSubmitUrlMode = this.postSubmitUrlModeIsFormula ? 'formula' : 'template';
            this.selectedVersionPostSubmitUrlTemplate = (this.draftPostSubmitUrlTemplate || '').trim();
            this.selectedVersionPostSubmitUrlFormula = (this.draftPostSubmitUrlFormula || '').trim();
            this.selectedVersionPostSubmitButtonLabel = this.draftPostSubmitButtonLabel || this.formUiLanguageDefaults(this.draftLanguageCode).postSubmitButtonLabel;
            this.selectedVersionPostSubmitDelaySeconds = 0;
            return true;
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            return false;
        } finally {
            this.isSavingFormSettings = false;
        }
    }

    async handleThemeChange(event) {
        await this.saveFormSettings(
            {
                themeId: event.detail.value || '',
                formName: this.draftFormName,
                enableCaptcha: this.selectedFormCaptchaEnabled,
                submitSuccessMessage: this.draftSubmitSuccessMessage,
                rtlEnabled: this.draftRtlEnabled,
                submitLabel: this.draftSubmitLabel,
                submitConditionalEnabled: this.draftSubmitConditionalEnabled,
                submitConditionalFieldKey: this.draftSubmitConditionalFieldKey,
                submitConditionalOperator: this.draftSubmitConditionalOperator,
                submitConditionalValue: this.draftSubmitConditionalValue
            },
            'Form theme updated.'
        );
    }

    async handleFormProjectChange(event) {
        await this.saveFormSettings(
            {
                projectId: event.detail.value || '',
                formName: this.draftFormName
            },
            'Form project updated.'
        );
    }

    async handleFormCaptchaChange(event) {
        await this.saveFormSettings(
            {
                themeId: this.selectedThemeId || '',
                formName: this.draftFormName,
                enableCaptcha: event.target.checked,
                submitSuccessMessage: this.draftSubmitSuccessMessage,
                rtlEnabled: this.draftRtlEnabled,
                submitLabel: this.draftSubmitLabel,
                submitConditionalEnabled: this.draftSubmitConditionalEnabled,
                submitConditionalFieldKey: this.draftSubmitConditionalFieldKey,
                submitConditionalOperator: this.draftSubmitConditionalOperator,
                submitConditionalValue: this.draftSubmitConditionalValue
            },
            event.target.checked ? 'CAPTCHA enabled for this form.' : 'CAPTCHA disabled for this form.',
            { skipReload: true }
        );
    }

    async handleFormRtlChange(event) {
        this.draftRtlEnabled = event.target.checked;
        await this.saveFormSettings(
            {
                themeId: this.selectedThemeId || '',
                formName: this.draftFormName,
                enableCaptcha: this.selectedFormCaptchaEnabled,
                submitSuccessMessage: this.draftSubmitSuccessMessage,
                rtlEnabled: this.draftRtlEnabled,
                submitLabel: this.draftSubmitLabel,
                submitConditionalEnabled: this.draftSubmitConditionalEnabled,
                submitConditionalFieldKey: this.draftSubmitConditionalFieldKey,
                submitConditionalOperator: this.draftSubmitConditionalOperator,
                submitConditionalValue: this.draftSubmitConditionalValue
            },
            this.draftRtlEnabled ? 'RTL enabled for this form.' : 'RTL disabled for this form.'
        );
    }

    async handleLanguageCodeChange(event) {
        this.draftLanguageCode = event.detail.value || 'en';
        setFormulaLanguage(this.draftLanguageCode);
        if (this.draftLanguageCode === this.selectedVersionLanguageCode) {
            return;
        }
        await this.saveFormSettings({}, 'Form language updated.', { skipReload: true });
    }

    async handleAddUserVerification() {
        if (!this.enableProUserVerification || this.draftUserVerificationEnabled || this.isSelectedVersionReadOnly) {
            return;
        }
        this.draftUserVerificationEnabled = true;
        const saved = await this.saveFormSettings({}, null, { skipReload: true });
        if (!saved) {
            this.draftUserVerificationEnabled = this.selectedVersionUserVerificationEnabled;
            return;
        }
        if (!(await this.saveUserVerificationSenderEmail())) {
            return;
        }
        this.selectedElementId = USER_VERIFICATION_ELEMENT_ID;
        this.syncSelectedState();
        this.showToast('User Verification added', 'Visitors will verify their email before accessing the published form.', 'success');
    }

    async handleRemoveUserVerification() {
        if (!this.draftUserVerificationEnabled || this.isSelectedVersionReadOnly) {
            return;
        }
        const confirmed = await LightningConfirm.open({
            label: 'Remove User Verification?',
            message: 'Removing User Verification allows visitors to access and submit this form without email verification.',
            theme: 'warning'
        });
        if (!confirmed) {
            return;
        }
        this.draftUserVerificationEnabled = false;
        const saved = await this.saveFormSettings({}, null, { skipReload: true });
        if (!saved) {
            this.draftUserVerificationEnabled = this.selectedVersionUserVerificationEnabled;
            return;
        }
        this.selectedElementId = null;
        this.syncSelectedState();
        this.showToast('User Verification removed', 'Visitors will no longer be asked to verify their email for this form.', 'success');
    }

    handleUserVerificationSenderEmailInput(event) {
        this.draftUserVerificationSenderEmail = (event.target.value || '').trim().toLowerCase();
    }

    async handleUserVerificationSenderEmailBlur(event) {
        this.draftUserVerificationSenderEmail = (event.target.value || '').trim().toLowerCase();
        if ((this.draftUserVerificationSenderEmail || '') === (this.selectedVersionUserVerificationSenderEmail || '')) {
            return;
        }
        await this.saveUserVerificationSenderEmail();
    }
    async saveUserVerificationSenderEmail() {
        this.isSavingFormSettings = true;
        this.errorMessage = '';
        try {
            await updateUserVerificationSenderEmail({
                formId: this.selectedFormId,
                versionId: this.selectedVersionId,
                userVerificationSenderEmail: this.draftUserVerificationSenderEmail || ''
            });
            this.selectedVersionUserVerificationSenderEmail = (this.draftUserVerificationSenderEmail || '').trim().toLowerCase();
            this.draftUserVerificationSenderEmail = this.selectedVersionUserVerificationSenderEmail;
            return true;
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            this.draftUserVerificationSenderEmail = this.selectedVersionUserVerificationSenderEmail;
            return false;
        } finally {
            this.isSavingFormSettings = false;
        }
    }
    handleUserVerificationIntroTextInput(event) {
        this.draftUserVerificationIntroText = event.target.value || '';
    }

    async handleUserVerificationIntroTextBlur(event) {
        this.draftUserVerificationIntroText = event.target.value || '';
        if ((this.draftUserVerificationIntroText || '').trim() === (this.selectedVersionUserVerificationIntroText || '').trim()) {
            return;
        }
        await this.saveFormSettings({}, null, { skipReload: true });
    }

    handleUserVerificationSentMessageInput(event) {
        this.draftUserVerificationSentMessage = event.target.value || '';
    }

    async handleUserVerificationSentMessageBlur(event) {
        this.draftUserVerificationSentMessage = event.target.value || '';
        if ((this.draftUserVerificationSentMessage || '').trim() === (this.selectedVersionUserVerificationSentMessage || '').trim()) {
            return;
        }
        await this.saveFormSettings({}, null, { skipReload: true });
    }

    handleUserVerificationInvalidMessageInput(event) {
        this.draftUserVerificationInvalidMessage = event.target.value || '';
    }

    async handleUserVerificationInvalidMessageBlur(event) {
        this.draftUserVerificationInvalidMessage = event.target.value || '';
        if ((this.draftUserVerificationInvalidMessage || '').trim() === (this.selectedVersionUserVerificationInvalidMessage || '').trim()) {
            return;
        }
        await this.saveFormSettings({}, null, { skipReload: true });
    }

    handleUserVerificationVerifiedMessageInput(event) {
        this.draftUserVerificationVerifiedMessage = event.target.value || '';
    }

    async handleUserVerificationVerifiedMessageBlur(event) {
        this.draftUserVerificationVerifiedMessage = event.target.value || '';
        if ((this.draftUserVerificationVerifiedMessage || '').trim() === (this.selectedVersionUserVerificationVerifiedMessage || '').trim()) {
            return;
        }
        await this.saveFormSettings({}, null, { skipReload: true });
    }

    handleUserVerificationSendButtonLabelInput(event) {
        this.draftUserVerificationSendButtonLabel = event.target.value || '';
    }

    async handleUserVerificationSendButtonLabelBlur(event) {
        this.draftUserVerificationSendButtonLabel = event.target.value || '';
        if ((this.draftUserVerificationSendButtonLabel || '').trim() === (this.selectedVersionUserVerificationSendButtonLabel || '').trim()) {
            return;
        }
        await this.saveFormSettings({}, null, { skipReload: true });
    }

    handleUserVerificationVerifyButtonLabelInput(event) {
        this.draftUserVerificationVerifyButtonLabel = event.target.value || '';
    }

    async handleUserVerificationVerifyButtonLabelBlur(event) {
        this.draftUserVerificationVerifyButtonLabel = event.target.value || '';
        if ((this.draftUserVerificationVerifyButtonLabel || '').trim() === (this.selectedVersionUserVerificationVerifyButtonLabel || '').trim()) {
            return;
        }
        await this.saveFormSettings({}, null, { skipReload: true });
    }

    handleUserVerificationResendButtonLabelInput(event) {
        this.draftUserVerificationResendButtonLabel = event.target.value || '';
    }

    async handleUserVerificationResendButtonLabelBlur(event) {
        this.draftUserVerificationResendButtonLabel = event.target.value || '';
        if ((this.draftUserVerificationResendButtonLabel || '').trim() === (this.selectedVersionUserVerificationResendButtonLabel || '').trim()) {
            return;
        }
        await this.saveFormSettings({}, null, { skipReload: true });
    }

    async handleUserVerificationExpiryMinutesBlur(event) {
        this.draftUserVerificationExpiryMinutes = Math.max(1, Number(event.target.value) || 10);
        if (this.draftUserVerificationExpiryMinutes === this.selectedVersionUserVerificationExpiryMinutes) {
            return;
        }
        await this.saveFormSettings({}, null, { skipReload: true });
    }

    async handleUserVerificationMaxAttemptsBlur(event) {
        this.draftUserVerificationMaxAttempts = Math.max(1, Number(event.target.value) || 5);
        if (this.draftUserVerificationMaxAttempts === this.selectedVersionUserVerificationMaxAttempts) {
            return;
        }
        await this.saveFormSettings({}, null, { skipReload: true });
    }

    async handleUserVerificationAllowResendChange(event) {
        this.draftUserVerificationAllowResend = !!event.target.checked;
        if (this.draftUserVerificationAllowResend === this.selectedVersionUserVerificationAllowResend) {
            return;
        }
        await this.saveFormSettings({}, null, { skipReload: true });
    }

    async handleUserVerificationSessionModeChange(event) {
        const nextMode = event.target.checked ? 'sameTabUntilMidnight' : 'short';
        this.draftUserVerificationSessionMode = nextMode;
        if (nextMode === this.selectedVersionUserVerificationSessionMode) {
            return;
        }
        this.isSavingFormSettings = true;
        this.errorMessage = '';
        try {
            await updateUserVerificationSessionMode({
                formId: this.selectedFormId,
                versionId: this.selectedVersionId,
                userVerificationSessionMode: nextMode
            });
            this.selectedVersionUserVerificationSessionMode = nextMode;
            this.draftUserVerificationSessionMode = nextMode;
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            this.draftUserVerificationSessionMode = this.selectedVersionUserVerificationSessionMode;
            this.draftUserVerificationSenderEmail = this.selectedVersionUserVerificationSenderEmail;
        } finally {
            this.isSavingFormSettings = false;
        }
    }

    handleSubmitSuccessMessageInput(event) {
        this.draftSubmitSuccessMessage = event.target.value || '';
    }

    handleFormNameInput(event) {
        this.draftFormName = event.target.value || '';
    }

    async handleFormNameBlur(event) {
        const nextName = (event.target.value || '').trim();
        if (!nextName) {
            this.draftFormName = this.selectedFormName || '';
            return;
        }
        this.draftFormName = nextName;
        if (nextName === (this.selectedFormName || '').trim()) {
            return;
        }
        await this.saveFormSettings(
            {
                formName: nextName,
                themeId: this.selectedThemeId || '',
                enableCaptcha: this.selectedFormCaptchaEnabled,
                submitSuccessMessage: this.draftSubmitSuccessMessage,
                rtlEnabled: this.draftRtlEnabled,
                submitLabel: this.draftSubmitLabel,
                submitConditionalEnabled: this.draftSubmitConditionalEnabled,
                submitConditionalFieldKey: this.draftSubmitConditionalFieldKey,
                submitConditionalOperator: this.draftSubmitConditionalOperator,
                submitConditionalValue: this.draftSubmitConditionalValue
            },
            null
        );
    }

    async handleSubmitSuccessMessageBlur(event) {
        const nextMessage = event.target.value || '';
        this.draftSubmitSuccessMessage = nextMessage;
        if ((nextMessage || '').trim() === (this.selectedVersionSubmitSuccessMessage || '').trim()) {
            return;
        }
        await this.saveFormSettings(
            {
                themeId: this.selectedThemeId || '',
                formName: this.draftFormName,
                enableCaptcha: this.selectedFormCaptchaEnabled,
                submitSuccessMessage: nextMessage,
                rtlEnabled: this.draftRtlEnabled,
                submitLabel: this.draftSubmitLabel,
                submitConditionalEnabled: this.draftSubmitConditionalEnabled,
                submitConditionalFieldKey: this.draftSubmitConditionalFieldKey,
                submitConditionalOperator: this.draftSubmitConditionalOperator,
                submitConditionalValue: this.draftSubmitConditionalValue
            },
            null
        );
    }

    handlePostSubmitAutoLinkChange(event) {
        this.draftPostSubmitAutoLinkEnabled = event.target.checked;
        if (this.draftPostSubmitAutoLinkEnabled && this.postSubmitUrlModeIsTemplate && !(this.draftPostSubmitUrlTemplate || '').trim()) {
            this.draftPostSubmitUrlTemplate = this.defaultPostSubmitRedirectUrl;
        }
    }

    async handlePostSubmitAutoLinkCommit() {
        if (this.draftPostSubmitAutoLinkEnabled === this.selectedVersionPostSubmitAutoLinkEnabled) {
            return;
        }
        await this.savePostSubmitRedirectSettings();
    }

    async handlePostSubmitUrlModeFormulaChange(event) {
        this.draftPostSubmitUrlMode = event.target.checked ? 'formula' : 'template';
        if (this.draftPostSubmitAutoLinkEnabled && this.postSubmitUrlModeIsTemplate && !(this.draftPostSubmitUrlTemplate || '').trim()) {
            this.draftPostSubmitUrlTemplate = this.defaultPostSubmitRedirectUrl;
        }
        this.updatePostSubmitFormulaPreview();
        if (this.postSubmitUrlModeIsTemplate && (this.selectedVersionPostSubmitUrlMode || 'template') !== 'template') {
            await this.savePostSubmitRedirectSettings();
        }
    }

    handlePostSubmitUrlTemplateInput(event) {
        this.draftPostSubmitUrlTemplate = event.target.value || '';
        this.capturePostSubmitUrlSelection(event);
    }

    capturePostSubmitUrlSelection(event) {
        const target = event.target;
        this.postSubmitUrlSelectionStart = target?.selectionStart ?? this.draftPostSubmitUrlTemplate.length;
        this.postSubmitUrlSelectionEnd = target?.selectionEnd ?? this.postSubmitUrlSelectionStart;
    }

    handlePostSubmitUrlTemplateBlur(event) {
        this.draftPostSubmitUrlTemplate = event.target.value || '';
    }

    async handlePostSubmitUrlTemplateChange(event) {
        this.draftPostSubmitUrlTemplate = event.target.value || '';
        if (this.postSubmitTokenInteraction) {
            return;
        }
        if ((this.draftPostSubmitUrlTemplate || '').trim() === (this.selectedVersionPostSubmitUrlTemplate || '').trim()) {
            return;
        }
        await this.savePostSubmitRedirectSettings();
    }

    markPostSubmitTokenInteraction() {
        this.postSubmitTokenInteraction = true;
    }

    clearPostSubmitTokenInteraction() {
        window.setTimeout(() => {
            this.postSubmitTokenInteraction = false;
        }, 0);
    }

    handlePostSubmitFormTokenChange(event) {
        this.selectedPostSubmitFormToken = event.detail.value || '';
    }

    insertTokenIntoPostSubmitUrl(token) {
        if (!token) {
            return;
        }
        const textarea = this.template.querySelector('[data-id="post-submit-url-template"]');
        const sourceValue = textarea ? (textarea.value || '') : (this.draftPostSubmitUrlTemplate || '');
        const start = textarea?.selectionStart ?? this.postSubmitUrlSelectionStart ?? sourceValue.length;
        const end = textarea?.selectionEnd ?? this.postSubmitUrlSelectionEnd ?? start;
        const nextValue = `${sourceValue.slice(0, start)}${token}${sourceValue.slice(end)}`;
        const nextCursor = start + token.length;
        this.draftPostSubmitUrlTemplate = nextValue;
        this.postSubmitUrlSelectionStart = nextCursor;
        this.postSubmitUrlSelectionEnd = nextCursor;
        if (textarea) {
            textarea.value = nextValue;
            requestAnimationFrame(() => {
                textarea.focus();
                textarea.setSelectionRange(nextCursor, nextCursor);
            });
        }
    }

    handleInsertPostSubmitFormToken() {
        if (!this.selectedPostSubmitFormToken) {
            this.clearPostSubmitTokenInteraction();
            return;
        }
        this.insertTokenIntoPostSubmitUrl(this.selectedPostSubmitFormToken);
        this.selectedPostSubmitFormToken = '';
        this.clearPostSubmitTokenInteraction();
    }

    handlePostSubmitUrlFormulaInput(event) {
        this.modalPostSubmitUrlFormula = event.detail?.value ?? event.target.value ?? '';
        this.modalPostSubmitUrlFormulaError = '';
        this.modalPostSubmitUrlFormulaPreviewValue = '';
    }

    handlePostSubmitFormulaFieldTokenChange(event) {
        this.selectedPostSubmitFormulaFieldToken = event.detail.value || '';
    }

    insertTokenIntoPostSubmitFormula(token) {
        if (!token) {
            return;
        }
        const textarea = this.template.querySelector('[data-id="post-submit-url-formula"]');
        const sourceValue = textarea ? (textarea.value || '') : (this.modalPostSubmitUrlFormula || '');
        const start = textarea?.selectionStart ?? sourceValue.length;
        const end = textarea?.selectionEnd ?? start;
        const nextValue = `${sourceValue.slice(0, start)}${token}${sourceValue.slice(end)}`;
        const nextCursor = start + token.length;
        this.modalPostSubmitUrlFormula = nextValue;
        this.modalPostSubmitUrlFormulaError = '';
        this.modalPostSubmitUrlFormulaPreviewValue = '';
        if (textarea) {
            textarea.value = nextValue;
            requestAnimationFrame(() => {
                textarea.focus();
                textarea.setSelectionRange(nextCursor, nextCursor);
            });
        }
    }

    handleInsertPostSubmitFormulaFieldToken() {
        if (!this.selectedPostSubmitFormulaFieldToken) {
            return;
        }
        this.insertTokenIntoPostSubmitFormula(this.selectedPostSubmitFormulaFieldToken);
        this.selectedPostSubmitFormulaFieldToken = '';
    }

    validatePostSubmitFormulaExpression(expression) {
        const validation = validateFormulaConfig({
            expression: expression || '',
            fieldKey: '',
            targetType: 'text',
            elements: this.elements,
            allowFormulaReferences: true
        });
        if (!validation.valid) {
            return {
                valid: false,
                message: validation.message,
                previewValue: ''
            };
        }
        const preview = previewFormulaValue({
            expression: expression || '',
            fieldKey: '',
            targetType: 'text',
            elements: this.elements,
            sourceValues: this.formulaSourceValues(),
            allowFormulaReferences: true
        });
        if (!preview.valid) {
            return {
                valid: false,
                message: preview.message,
                previewValue: ''
            };
        }
        const previewUrl = String(preview.value || '').trim();
        if (previewUrl && !this.isAbsoluteHttpUrl(previewUrl)) {
            return {
                valid: false,
                message: 'Formula preview must be a valid http:// or https:// URL, or blank.',
                previewValue: previewUrl
            };
        }
        return {
            valid: true,
            message: '',
            previewValue: previewUrl
        };
    }

    async handleSavePostSubmitFormulaModal() {
        const textarea = this.template.querySelector('[data-id="post-submit-url-formula"]');
        const latestFormula = textarea ? (textarea.value || '') : (this.modalPostSubmitUrlFormula || '');
        this.modalPostSubmitUrlFormula = latestFormula;
        const validation = this.validatePostSubmitFormulaExpression(latestFormula);
        this.modalPostSubmitUrlFormulaPreviewValue = validation.previewValue || '';
        if (!validation.valid) {
            this.modalPostSubmitUrlFormulaError = validation.message;
            return;
        }
        this.modalPostSubmitUrlFormulaError = '';
        this.draftPostSubmitUrlFormula = latestFormula;
        const saved = await this.savePostSubmitRedirectSettings();
        if (saved) {
            this.handleClosePostSubmitFormulaModal();
            this.showToast('Redirect formula saved', 'Redirect formula updated.', 'success');
        }
    }

    async handleSubmissionPdfEnabledChange(event) {
        if (!event.target.checked && this.submissionPdfRequiredByRecordsListSignature) {
            this.draftSubmissionPdfEnabled = true;
            this.showToast('Submission PDF required', 'Remove the Signature inside the Records List before turning off Submission PDF.', 'warning');
            return;
        }
        this.draftSubmissionPdfEnabled = event.target.checked;
        if (this.draftSubmissionPdfEnabled && !(this.draftSubmissionPdfTitle || '').trim()) {
            this.draftSubmissionPdfTitle = 'Submitted Response';
        }
        await this.handleSubmissionPdfSettingsCommit();
    }

    async handleSubmissionPdfAttachToRecordChange(event) {
        this.draftSubmissionPdfAttachToRecord = event.target.checked;
        await this.handleSubmissionPdfSettingsCommit();
    }

    async handleSubmissionPdfTargetActionChange(event) {
        this.draftSubmissionPdfTargetSubmitActionKey = event.detail.value || '';
        await this.handleSubmissionPdfSettingsCommit();
    }

    handleSubmissionPdfTitleInput(event) {
        this.draftSubmissionPdfTitle = event.target.value || '';
    }

    async handleSubmissionPdfIncludeEmptyFieldsChange(event) {
        this.draftSubmissionPdfIncludeEmptyFields = event.target.checked;
        await this.handleSubmissionPdfSettingsCommit();
    }

    async handleSubmissionPdfSettingsCommit() {
        if (!this.selectedFormId || !this.selectedVersionId) {
            return;
        }
        this.isSavingFormSettings = true;
        this.errorMessage = '';
        try {
            await updateVersionSubmissionPdfSettings({
                formId: this.selectedFormId,
                versionId: this.selectedVersionId,
                enabled: !!this.draftSubmissionPdfEnabled,
                attachToRecord: this.draftSubmissionPdfAttachToRecord !== false,
                targetSubmitActionKey: this.draftSubmissionPdfTargetSubmitActionKey || '',
                title: this.draftSubmissionPdfTitle || '',
                includeEmptyFields: this.draftSubmissionPdfIncludeEmptyFields !== false
            });
            this.selectedVersionSubmissionPdfEnabled = !!this.draftSubmissionPdfEnabled;
            this.selectedVersionSubmissionPdfAttachToRecord = this.draftSubmissionPdfAttachToRecord !== false;
            this.selectedVersionSubmissionPdfTargetSubmitActionKey = this.draftSubmissionPdfTargetSubmitActionKey || '';
            this.selectedVersionSubmissionPdfTitle = (this.draftSubmissionPdfTitle || '').trim() || 'Submitted Response';
            this.selectedVersionSubmissionPdfIncludeEmptyFields = this.draftSubmissionPdfIncludeEmptyFields !== false;
            this.draftSubmissionPdfTitle = this.selectedVersionSubmissionPdfTitle;
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isSavingFormSettings = false;
        }
    }

    handleSubmitButtonLabelInput(event) {
        this.draftSubmitLabel = event.target.value || '';
        this.syncSelectedState();
    }

    async persistSubmitButtonSettings() {
        this.syncSubmitConditionalLegacyFields();
        await this.saveFormSettings({
            formName: this.draftFormName,
            themeId: this.selectedThemeId || '',
            enableCaptcha: this.selectedFormCaptchaEnabled,
            submitSuccessMessage: this.draftSubmitSuccessMessage,
            rtlEnabled: this.draftRtlEnabled,
            submitLabel: this.draftSubmitLabel,
            submitConditionalEnabled: this.draftSubmitConditionalEnabled,
            submitConditionalFieldKey: this.draftSubmitConditionalFieldKey,
            submitConditionalOperator: this.draftSubmitConditionalOperator,
            submitConditionalValue: this.draftSubmitConditionalValue,
            submitConditionalConditionsJson: JSON.stringify(this.sanitizeVisibilityConditions(this.draftSubmitConditionalConditions)),
            submitConditionalExpression: this.normalizeVisibilityExpression(
                this.draftSubmitConditionalExpression,
                this.sanitizeVisibilityConditions(this.draftSubmitConditionalConditions).length
            )
        }, null);
    }

    async handleSubmitButtonLabelBlur(event) {
        const nextLabel = (event.target.value || '').trim() || 'Submit';
        this.draftSubmitLabel = nextLabel;
        if (nextLabel === (this.selectedVersionSubmitLabel || 'Submit')) {
            this.syncSelectedState();
            return;
        }
        await this.persistSubmitButtonSettings();
    }

    handleSubmitButtonConditionalEnabledChange(event) {
        this.draftSubmitConditionalEnabled = event.target.checked;
        if (this.draftSubmitConditionalEnabled && !(this.draftSubmitConditionalConditions || []).length) {
            this.draftSubmitConditionalConditions = [this.createVisibilityCondition()];
        }
        if (!this.draftSubmitConditionalEnabled) {
            this.draftSubmitConditionalExpression = '';
        }
        this.syncSubmitConditionalLegacyFields();
        this.syncSelectedState();
    }

    async handleSubmitButtonConditionalEnabledCommit() {
        if (this.draftSubmitConditionalEnabled === this.selectedVersionSubmitConditionalEnabled) {
            return;
        }
        await this.persistSubmitButtonSettings();
    }

    handleSubmitConditionRowChange(event) {
        const index = Number(event.target.dataset.index);
        const field = event.target.dataset.field;
        const value = event.detail?.value ?? event.target.value ?? '';
        const next = [...(this.draftSubmitConditionalConditions || [])];
        if (!next[index]) {
            return;
        }
        next[index] = {
            ...next[index],
            [field]: value
        };
        if (field === 'operator' && !this.conditionUsesValue(value)) {
            next[index].value = '';
        }
        this.draftSubmitConditionalConditions = next;
        this.syncSubmitConditionalLegacyFields();
        this.syncSelectedState();
    }

    handleSubmitConditionControlBlur(event) {
        if (event.relatedTarget?.dataset?.conditionAction) {
            return;
        }
        this.handleSubmitConditionRowCommit();
    }

    handleSubmitConditionValueBlur(event) {
        this.handleSubmitConditionRowChange(event);
        if (event.relatedTarget?.dataset?.conditionAction) {
            return;
        }
        this.handleSubmitConditionRowCommit();
    }

    async handleSubmitConditionRowCommit() {
        await this.persistSubmitButtonSettings();
    }

    async handleAddSubmitCondition() {
        if (!this.canAddSubmitCondition) {
            return;
        }
        this.draftSubmitConditionalConditions = [...(this.draftSubmitConditionalConditions || []), this.createVisibilityCondition()];
        this.draftSubmitConditionalExpression = this.defaultVisibilityExpression(this.draftSubmitConditionalConditions.length);
        this.syncSubmitConditionalLegacyFields();
        this.syncSelectedState();
    }

    async handleDeleteSubmitCondition(event) {
        const index = Number(event.currentTarget.dataset.index);
        this.draftSubmitConditionalConditions = (this.draftSubmitConditionalConditions || []).filter((_, rowIndex) => rowIndex !== index);
        this.draftSubmitConditionalExpression = this.normalizeVisibilityExpression(
            '',
            this.draftSubmitConditionalConditions.length
        );
        this.syncSubmitConditionalLegacyFields();
        this.syncSelectedState();
        await this.persistSubmitButtonSettings();
    }

    handleSubmitConditionalExpressionInput(event) {
        this.draftSubmitConditionalExpression = event.target.value || '';
    }

    async handleSubmitConditionalExpressionBlur(event) {
        this.draftSubmitConditionalExpression = event.target.value || '';
        await this.persistSubmitButtonSettings();
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
        const elementPreset = event.currentTarget?.dataset?.preset || '';
        if (!elementType) {
            return;
        }
        if (elementType === 'repeatGroup' && !this.enableProRepeatGroups) {
            this.showToast('Pro feature', 'Enable Pro Repeat Groups in TwinaForms Admin Features first.', 'warning');
            return;
        }
        if (elementType === 'fileUpload' && !this.enableProLoadFile) {
            this.showToast('Pro feature', 'Enable Pro File Uploads in your AWS plan entitlements first.', 'warning');
            return;
        }
        if (elementType === 'signature' && !this.enableProElectronicSignature) {
            this.showToast('Pro feature', 'Enable Pro Electronic Signature in your AWS plan entitlements first.', 'warning');
            return;
        }
        if (elementType === 'button' && !this.enableProButtonElements) {
            this.showToast('Pro feature', 'Enable Portal Buttons in TwinaForms Admin Features first.', 'warning');
            return;
        }
        if ((elementType === 'ranking' || elementPreset) && !this.enableProSurveyFields) {
            this.showToast('Pro feature', 'Enable Pro Survey Fields in your AWS plan entitlements first.', 'warning');
            return;
        }
        if (elementType === 'location' && !this.enableProLocationFields) {
            this.showToast('Pro feature', 'Enable Pro Country / State / City in your AWS plan entitlements first.', 'warning');
            return;
        }
        if (elementType === 'mergedDocument' && !this.enableProMergedDocument) {
            this.showToast('Pro feature', 'Enable Pro Merged Document in your AWS plan entitlements first.', 'warning');
            return;
        }
        await this.addElementType(elementType, elementPreset);
    }

    async addElementType(elementType, elementPreset = '') {
        if (!this.selectedVersionId || this.isSelectedVersionReadOnly) {
            return;
        }
        const undoStep = this.captureUndoStep('Add element');
        try {
            const created = await addElement({ versionId: this.selectedVersionId, elementType, elementPreset });
            const selectedElement = this.selectedElement;
            if (selectedElement) {
                await insertElementAfter({
                    elementId: created.id,
                    anchorElementId: selectedElement.id
                });
            }
            await this.loadWorkspace(this.selectedProjectId, this.selectedFormId, this.selectedVersionId, true);
            this.selectedElementId = created.id;
            this.syncSelectedState();
        } catch (error) {
            this.removeUndoStep(undoStep);
            this.errorMessage = this.normalizeError(error);
        }
    }

    handleSelectElement(event) {
        event.stopPropagation();
        this.selectedElementId = event.currentTarget.dataset.id;
        this.syncSelectedState();
    }

    handleUserVerificationPreviewKeydown(event) {
        if (event.key !== 'Enter' && event.key !== ' ') {
            return;
        }
        event.preventDefault();
        event.stopPropagation();
        this.selectedElementId = USER_VERIFICATION_ELEMENT_ID;
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

        const formulaValidation = this.validateAllFormulasForPublish();
        if (!formulaValidation.valid) {
            this.errorMessage = formulaValidation.message;
            this.publishResultContextVersionId = this.selectedVersionId || '';
            this.publishResult = {
                success: false,
                message: formulaValidation.message
            };
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';
        try {
            await this.savePendingDesignerChangesBeforePublish();
            const result = await publishVersion({ versionId: this.selectedVersionId });
            this.publishResult = result;
            const nextVersionId = result.newDraftVersionId || this.selectedVersionId;
            this.publishResultContextVersionId = nextVersionId || '';
            this.storeSelectedVersion(nextVersionId);
            this.clearUndoStack();
            await this.loadWorkspace(this.selectedProjectId, this.selectedFormId, nextVersionId);
            this.showToast(
                result.success ? 'Published' : 'Publish failed',
                result.message || (result.success ? 'The form was published.' : 'Publishing failed.'),
                result.success ? 'success' : 'error'
            );
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            this.publishResultContextVersionId = this.selectedVersionId || '';
            this.publishResult = {
                success: false,
                message: this.errorMessage
            };
        } finally {
            this.isLoading = false;
        }
    }

    async savePendingDesignerChangesBeforePublish() {
        if (this.selectedElementId && !this.isSelectedVersionReadOnly) {
            await this.persistVisualSettings(false);
        }
        if (this.hasPendingSubmissionPdfSettings()) {
            await this.handleSubmissionPdfSettingsCommit();
        }
    }

    hasPendingSubmissionPdfSettings() {
        return this.draftSubmissionPdfEnabled !== this.selectedVersionSubmissionPdfEnabled
            || this.draftSubmissionPdfAttachToRecord !== this.selectedVersionSubmissionPdfAttachToRecord
            || (this.draftSubmissionPdfTargetSubmitActionKey || '') !== (this.selectedVersionSubmissionPdfTargetSubmitActionKey || '')
            || ((this.draftSubmissionPdfTitle || '').trim() || 'Submitted Response') !== (this.selectedVersionSubmissionPdfTitle || 'Submitted Response')
            || this.draftSubmissionPdfIncludeEmptyFields !== this.selectedVersionSubmissionPdfIncludeEmptyFields;
    }

    handleEditorLabelCommit(event) {
        this.editorLabel = event.target.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleButtonDestinationTypeChange(event) {
        this.editorButtonDestinationType = event.detail.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleButtonTargetFormChange(event) {
        this.editorButtonTargetFormId = event.detail.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleButtonExternalUrlModeChange(event) {
        this.editorButtonExternalUrlMode = event.detail.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleButtonExternalUrlTemplateCommit(event) {
        this.editorButtonExternalUrlTemplate = event.target.value || '';
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleButtonExternalUrlFormulaCommit(event) {
        this.editorButtonExternalUrlFormula = event.target.value || '';
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleButtonSubmitBeforeNavigationChange(event) {
        this.editorButtonSubmitBeforeNavigation = event.target.checked && !this.selectedElementIsInsideRepeatGroup;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleAddButtonQueryParameter() {
        this.editorButtonQueryParameters = [...(this.editorButtonQueryParameters || []), {
            key: `button-param-${Date.now()}`,
            name: '',
            valueMode: 'template',
            usesFormula: false,
            valueTemplate: '',
            valueFormula: ''
        }];
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleRemoveButtonQueryParameter(event) {
        const index = Number(event.currentTarget.dataset.index);
        this.editorButtonQueryParameters = this.editorButtonQueryParameters.filter((item, itemIndex) => itemIndex !== index);
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleButtonQueryParameterModeChange(event) {
        const index = Number(event.currentTarget.dataset.index);
        const usesFormula = event.detail.value === 'formula';
        this.editorButtonQueryParameters = this.editorButtonQueryParameters.map((item, itemIndex) => (
            itemIndex === index ? { ...item, valueMode: event.detail.value, usesFormula } : item
        ));
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
        if (usesFormula) {
            this.handleOpenButtonParameterFormulaModal(event);
        }
    }

    handleButtonQueryParameterNameCommit(event) {
        this.commitButtonQueryParameterValue(Number(event.currentTarget.dataset.index), 'name', event.target.value || '');
    }

    handleButtonQueryParameterTemplateChange(event) {
        this.commitButtonQueryParameterValue(Number(event.currentTarget.dataset.index), 'valueTemplate', event.detail.value || '');
    }

    handleButtonParameterFormulaInput(event) {
        this.modalButtonParameterFormula = event.target.value || '';
        this.modalButtonParameterFormulaPreviewValue = '';
        this.modalButtonParameterFormulaError = '';
    }

    handleButtonParameterFormulaFieldTokenChange(event) {
        this.selectedButtonParameterFormulaFieldToken = event.detail.value || '';
    }

    insertTokenIntoButtonParameterFormula(token) {
        if (!token) {
            return;
        }
        const textarea = this.template.querySelector('[data-id="button-parameter-formula"]');
        const sourceValue = textarea ? (textarea.value || '') : (this.modalButtonParameterFormula || '');
        const start = textarea && Number.isInteger(textarea.selectionStart) ? textarea.selectionStart : sourceValue.length;
        const end = textarea && Number.isInteger(textarea.selectionEnd) ? textarea.selectionEnd : start;
        const nextValue = `${sourceValue.slice(0, start)}${token}${sourceValue.slice(end)}`;
        const nextCursor = start + token.length;
        this.modalButtonParameterFormula = nextValue;
        this.modalButtonParameterFormulaPreviewValue = '';
        this.modalButtonParameterFormulaError = '';
        if (textarea) {
            textarea.value = nextValue;
            requestAnimationFrame(() => {
                textarea.focus();
                textarea.setSelectionRange(nextCursor, nextCursor);
            });
        }
    }

    handleInsertButtonParameterFormulaFieldToken() {
        if (!this.selectedButtonParameterFormulaFieldToken) {
            return;
        }
        this.insertTokenIntoButtonParameterFormula(this.selectedButtonParameterFormulaFieldToken);
        this.selectedButtonParameterFormulaFieldToken = '';
    }

    validateButtonParameterFormulaExpression(expression) {
        const normalizedExpression = String(expression || '').replace(/\{row\.([a-zA-Z0-9_]+)\}/g, '{$1}');
        const validation = validateFormulaConfig({
            expression: normalizedExpression,
            fieldKey: '',
            targetType: 'text',
            elements: this.elements,
            allowFormulaReferences: true
        });
        if (!validation.valid) {
            return { valid: false, message: validation.message, previewValue: '' };
        }
        const preview = previewFormulaValue({
            expression: normalizedExpression,
            fieldKey: '',
            targetType: 'text',
            elements: this.elements,
            sourceValues: this.formulaSourceValues(),
            allowFormulaReferences: true
        });
        return {
            valid: preview.valid,
            message: preview.valid ? '' : preview.message,
            previewValue: preview.value || ''
        };
    }

    handleSaveButtonParameterFormulaModal() {
        const textarea = this.template.querySelector('[data-id="button-parameter-formula"]');
        const expression = textarea ? (textarea.value || '') : (this.modalButtonParameterFormula || '');
        const validation = this.validateButtonParameterFormulaExpression(expression);
        this.modalButtonParameterFormula = expression;
        this.modalButtonParameterFormulaPreviewValue = validation.previewValue || '';
        this.modalButtonParameterFormulaError = validation.valid ? '' : validation.message;
        if (!validation.valid) {
            return;
        }
        this.commitButtonQueryParameterValue(this.modalButtonParameterIndex, 'valueFormula', expression);
        this.handleCloseButtonParameterFormulaModal();
        this.showToast('Formula saved', 'Button query parameter formula updated.', 'success');
    }

    commitButtonQueryParameterValue(index, propertyName, value) {
        this.editorButtonQueryParameters = this.editorButtonQueryParameters.map((item, itemIndex) => (
            itemIndex === index ? { ...item, [propertyName]: value } : item
        ));
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorTypeChange(event) {
        this.editorElementType = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorLabelPositionChange(event) {
        this.editorLabelPosition = event.target.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorLabelPositionCommit() {
        this.flushEditorDraftSave();
    }

    handleEditorSpacerSizeChange(event) {
        this.editorSpacerSize = event.detail?.value || event.target?.value || 'field';
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorDefaultValueCommit(event) {
        this.editorDefaultValue = this.selectedElementIsTime
            ? this.formatTimeValue(event.target.value, this.editorTimeFormat)
            : event.target.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorCheckboxDefaultValueChange(event) {
        this.editorDefaultValue = event.detail.value || 'false';
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorPlaceholderCommit(event) {
        this.editorPlaceholder = event.target.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorDisplayTextChange(event) {
        this.editorDisplayText = event.detail.value;
        this.applyEditorDraft();
    }

    handleModalDisplayTextChange(event) {
        this.modalDisplayText = event.detail.value;
    }

    handleModalMergeAliasChange(event) {
        this.modalMergeAlias = event.detail.value;
        this.modalMergeFieldPath = '';
    }

    handleModalMergeFieldPathChange(event) {
        this.modalMergeFieldPath = event.detail.value;
    }

    handleInsertMergedDocumentToken() {
        if (!this.canInsertMergedDocumentToken) {
            return;
        }
        const token = `{{${this.modalMergeAlias}.${this.modalMergeFieldPath}}}`;
        const spacer = this.modalDisplayText && !/\s$/.test(this.modalDisplayText) ? ' ' : '';
        this.modalDisplayText = `${this.modalDisplayText || ''}${spacer}${token}`;
    }

    handleModalCustomJsChange(event) {
        this.modalCustomJs = event.detail?.value ?? event.target.value ?? '';
    }

    handleSaveDisplayTextModal() {
        this.editorDisplayText = this.modalDisplayText || (this.selectedElementIsMergedDocument ? '<p>Merged document text</p>' : '<p>Display text</p>');
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
        this.handleCloseDisplayTextModal();
    }

    async handleSaveCustomJsModal() {
        if (!this.selectedFormId || !this.selectedVersionId) {
            return;
        }
        const customJsInput = this.template.querySelector('.designer-custom-js-textarea');
        const latestCustomJs = customJsInput ? (customJsInput.value || '') : (this.modalCustomJs || '');
        this.modalCustomJs = latestCustomJs;
        this.isLoading = true;
        this.errorMessage = '';
        try {
            await updateVersionCustomJs({
                formId: this.selectedFormId,
                versionId: this.selectedVersionId,
                customJs: latestCustomJs
            });
            this.selectedVersionCustomJs = latestCustomJs;
            this.draftCustomJs = this.selectedVersionCustomJs;
            this.handleCloseCustomJsModal();
            this.showToast('Custom JavaScript saved', 'Custom JavaScript updated.', 'success');
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    renderedCallback() {
        if (this.showCustomJsModal) {
            const customJsInput = this.template.querySelector('.designer-custom-js-textarea');
            if (customJsInput && customJsInput.value !== this.modalCustomJs) {
                customJsInput.value = this.modalCustomJs || '';
            }
        }
        if (this.showPostSubmitFormulaModal) {
            const formulaInput = this.template.querySelector('[data-id="post-submit-url-formula"]');
            if (formulaInput && formulaInput.value !== this.modalPostSubmitUrlFormula) {
                formulaInput.value = this.modalPostSubmitUrlFormula || '';
            }
        }
        if (this.showFieldFormulaModal) {
            const formulaInput = this.template.querySelector('[data-id="formula-expression"]');
            if (formulaInput && formulaInput.value !== this.modalFormulaExpression) {
                formulaInput.value = this.modalFormulaExpression || '';
            }
        }
        if (this.showButtonParameterFormulaModal) {
            const formulaInput = this.template.querySelector('[data-id="button-parameter-formula"]');
            if (formulaInput && formulaInput.value !== this.modalButtonParameterFormula) {
                formulaInput.value = this.modalButtonParameterFormula || '';
            }
        }
    }

    handleEditorImageUrlCommit(event) {
        this.editorImageUrl = event.target.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorImageAltCommit(event) {
        this.editorImageAlt = event.target.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
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
        if (!this.validateEmbeddedImageFile(file, 'Image')) {
            event.target.value = null;
            return;
        }

        const undoStep = this.captureUndoStep('Edit image');
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
            await this.loadWorkspace(this.selectedProjectId, this.selectedFormId, this.selectedVersionId, true);
        } catch (error) {
            this.removeUndoStep(undoStep);
            this.errorMessage = this.normalizeError(error);
        }
    }

    async handleEditorPicklistObjectChange(event) {
        this.editorPicklistObject = event.detail.value;
        this.editorPicklistField = '';
        this.picklistFieldOptions = [];
        if (!this.pendingElementEditUndoSnapshot) {
            this.pendingElementEditUndoSnapshot = this.captureUndoStep('Edit element');
        }
        this.elements = this.elements.map((item) => {
            if (item.id !== this.selectedElementId) {
                return item;
            }
            const config = this.parseConfig(item.configJson);
            config.sourceObjectApiName = this.editorPicklistObject || '';
            config.sourcePicklistFieldApiName = '';
            delete config.options;
            return this.decorateBaseElement({
                ...item,
                configJson: JSON.stringify(config)
            });
        });
        this.applyEditorDraft();
        await this.loadPicklistFieldOptions(this.editorPicklistObject, null);
    }

    async handleEditorPicklistFieldChange(event) {
        this.editorPicklistField = event.detail.value;
        await this.loadPicklistValuesIntoEditor(this.editorPicklistObject, this.editorPicklistField);
        this.applyEditorDraft();
    }

    async handleEditorLookupTargetObjectChange(event) {
        this.editorLookupTargetObject = event.detail.value;
        this.editorLookupSearchFields = ['Name'];
        this.editorLookupDisplayFields = ['Name'];
        this.editorLookupSearchFieldsText = 'Name';
        this.editorLookupDisplayFieldsText = 'Name';
        this.editorLookupSetFields = [];
        this.applyEditorDraft();
        await this.loadLookupFieldOptions(this.editorLookupTargetObject);
        this.applyEditorDraft();
    }

    handleEditorLookupSearchFieldChange(event) {
        this.editorLookupSearchFields = this.normalizeLookupFieldList([event.detail.value], ['Name']).slice(0, 1);
        this.editorLookupDisplayFields = [...this.editorLookupSearchFields];
        this.editorLookupSearchFieldsText = this.editorLookupSearchFields.join(', ');
        this.editorLookupDisplayFieldsText = this.editorLookupDisplayFields.join(', ');
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleAddLookupSetField() {
        this.editorLookupSetFields = (this.editorLookupSetFields || []).concat({
            sourceField: '',
            targetFieldKey: ''
        });
    }

    handleLookupSetFieldChange(event) {
        const index = Number.parseInt(event.target.dataset.index, 10);
        const fieldName = event.target.dataset.fieldName;
        if (!Number.isFinite(index) || !fieldName) {
            return;
        }
        const value = event.detail.value;
        const draftRows = Array.isArray(this.editorLookupSetFields) ? [...this.editorLookupSetFields] : [];
        while (draftRows.length <= index) {
            draftRows.push({ sourceField: '', targetFieldKey: '' });
        }
        let changedRow = null;
        this.editorLookupSetFields = draftRows.map((mapping, mappingIndex) => {
            if (mappingIndex !== index) {
                return mapping;
            }
            changedRow = {
                sourceField: String(mapping?.sourceField || '').trim(),
                targetFieldKey: String(mapping?.targetFieldKey || '').trim(),
                ...mapping,
                [fieldName]: value
            };
            return changedRow;
        });
        if (changedRow?.sourceField && changedRow?.targetFieldKey) {
            this.applyEditorDraft(false);
            this.flushEditorDraftSave();
        }
    }

    handleDeleteLookupSetField(event) {
        const index = Number.parseInt(event.currentTarget.dataset.index, 10);
        if (!Number.isFinite(index)) {
            return;
        }
        this.editorLookupSetFields = (Array.isArray(this.editorLookupSetFields) ? this.editorLookupSetFields : [])
            .filter((mapping, mappingIndex) => mappingIndex !== index);
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorLookupMinSearchLengthCommit(event) {
        this.editorLookupMinSearchLength = event.target.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorLookupResultLimitCommit(event) {
        this.editorLookupResultLimit = event.target.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorLocationModeChange(event) {
        this.editorLocationMode = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorLocationLayoutChange(event) {
        this.editorLocationLayout = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorLocationRequiredCountryChange(event) {
        this.editorLocationRequiredCountry = event.target.checked;
        this.applyEditorDraft();
    }

    handleEditorLocationRequiredRegionChange(event) {
        this.editorLocationRequiredRegion = event.target.checked;
        this.applyEditorDraft();
    }

    handleEditorLocationRequiredCityChange(event) {
        this.editorLocationRequiredCity = event.target.checked;
        this.applyEditorDraft();
    }

    handleEditorLocationDefaultCountryCommit(event) {
        this.editorLocationDefaultCountryCode = String(event.target.value || '').trim().toUpperCase();
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorLocationAllowedCountriesCommit(event) {
        this.editorLocationAllowedCountriesText = event.target.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorLocationMinSearchLengthCommit(event) {
        this.editorLocationMinSearchLength = event.target.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorLocationResultLimitCommit(event) {
        this.editorLocationResultLimit = event.target.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorSurveyOptionChange(event) {
        const index = Number(event.currentTarget?.dataset?.index);
        const field = event.currentTarget?.dataset?.field;
        if (!Number.isInteger(index) || !field) {
            return;
        }
        const nextOptions = (this.editorSurveyOptions || []).map((option, optionIndex) => {
            if (optionIndex !== index) {
                return option;
            }
            return {
                ...option,
                [field]: event.detail?.value || ''
            };
        });
        this.editorSurveyOptions = this.decorateSurveyOptions(nextOptions);
        this.applyEditorDraft(false);
    }

    handleAddEditorSurveyOption() {
        const nextIndex = (this.editorSurveyOptions || []).length;
        this.editorSurveyOptions = [
            ...(this.editorSurveyOptions || []),
            {
                rowKey: `${Date.now()}-${nextIndex}`,
                label: `Choice ${nextIndex + 1}`,
                value: `choice${nextIndex + 1}`
            }
        ];
        this.editorSurveyOptions = this.decorateSurveyOptions(this.editorSurveyOptions);
        this.applyEditorDraft();
    }

    handleDeleteEditorSurveyOption(event) {
        const index = Number(event.currentTarget?.dataset?.index);
        if (!Number.isInteger(index) || (this.editorSurveyOptions || []).length <= 1) {
            return;
        }
        this.editorSurveyOptions = this.decorateSurveyOptions(
            this.editorSurveyOptions.filter((_, optionIndex) => optionIndex !== index)
        );
        this.applyEditorDraft();
    }

    handleMoveEditorSurveyOption(event) {
        const index = Number(event.currentTarget?.dataset?.index);
        const direction = event.currentTarget?.dataset?.direction;
        const options = [...(this.editorSurveyOptions || [])];
        const targetIndex = direction === 'up' ? index - 1 : index + 1;
        if (!Number.isInteger(index) || targetIndex < 0 || targetIndex >= options.length) {
            return;
        }
        const [item] = options.splice(index, 1);
        options.splice(targetIndex, 0, item);
        this.editorSurveyOptions = this.decorateSurveyOptions(options);
        this.applyEditorDraft();
    }

    handleEditorLabelBoldChange(event) {
        this.editorLabelBold = event.target.checked;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorLabelItalicChange(event) {
        this.editorLabelItalic = event.target.checked;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorLabelUnderlineChange(event) {
        this.editorLabelUnderline = event.target.checked;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorLabelBoldCommit() {
        this.flushEditorDraftSave();
    }

    handleEditorRequiredChange(event) {
        this.editorRequired = event.target.checked;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorRequiredCommit() {
        this.flushEditorDraftSave();
    }

    handleEditorFieldBehaviorChange(event) {
        this.editorFieldBehavior = event.detail?.value || event.target?.value || 'editable';
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorFieldBehaviorCommit() {
        this.flushEditorDraftSave();
    }

    handleEditorConditionalEnabledChange(event) {
        this.editorConditionalEnabled = event.target.checked;
        if (this.editorConditionalEnabled && !(this.editorConditionalConditions || []).length) {
            this.editorConditionalConditions = [this.createVisibilityCondition()];
        }
        if (!this.editorConditionalEnabled) {
            this.editorConditionalExpression = '';
        }
        this.syncEditorConditionalLegacyFields();
        this.applyEditorDraft(false, true);
        this.flushEditorDraftSave();
    }

    handleEditorConditionalEnabledCommit() {
        this.flushEditorDraftSave();
    }

    handleEditorConditionRowChange(event) {
        const index = Number(event.target.dataset.index);
        const field = event.target.dataset.field;
        const value = event.detail?.value ?? event.target.value ?? '';
        const next = [...(this.editorConditionalConditions || [])];
        if (!next[index]) {
            return;
        }
        next[index] = {
            ...next[index],
            [field]: value
        };
        if (field === 'operator' && !this.conditionUsesValue(value)) {
            next[index].value = '';
        }
        this.editorConditionalConditions = next;
        this.syncEditorConditionalLegacyFields();
        this.applyEditorDraft(false, true);
    }

    handleEditorConditionControlBlur(event) {
        if (event.relatedTarget?.dataset?.conditionAction) {
            return;
        }
        this.handleEditorConditionRowCommit();
    }

    handleEditorConditionValueBlur(event) {
        this.handleEditorConditionRowChange(event);
        if (event.relatedTarget?.dataset?.conditionAction) {
            return;
        }
        this.handleEditorConditionRowCommit();
    }

    handleEditorConditionRowCommit() {
        this.flushEditorDraftSave();
    }

    handleAddEditorCondition() {
        if (!this.canAddElementCondition) {
            return;
        }
        this.editorConditionalConditions = [...(this.editorConditionalConditions || []), this.createVisibilityCondition()];
        this.editorConditionalExpression = this.defaultVisibilityExpression(this.editorConditionalConditions.length);
        this.syncEditorConditionalLegacyFields();
        this.applyEditorDraft(false, true);
    }

    handleDeleteEditorCondition(event) {
        const index = Number(event.currentTarget.dataset.index);
        this.editorConditionalConditions = (this.editorConditionalConditions || []).filter((_, rowIndex) => rowIndex !== index);
        this.editorConditionalExpression = this.normalizeVisibilityExpression('', this.editorConditionalConditions.length);
        this.syncEditorConditionalLegacyFields();
        this.applyEditorDraft(false, true);
        this.flushEditorDraftSave();
    }

    handleEditorConditionalExpressionInput(event) {
        this.editorConditionalExpression = event.target.value || '';
    }

    handleEditorConditionalExpressionBlur(event) {
        this.editorConditionalExpression = event.target.value || '';
        this.applyEditorDraft(false, true);
        this.flushEditorDraftSave();
    }

    handleEditorMinValueCommit(event) {
        this.editorMinValue = event.target.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorMaxValueCommit(event) {
        this.editorMaxValue = event.target.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorTextareaMaxLengthCommit(event) {
        this.editorTextareaMaxLength = event.target.value;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorDateDisplayFormatChange(event) {
        this.editorDateDisplayFormat = event.detail.value || 'us';
        this.applyEditorDraft();
    }

    handleEditorTimeFormatChange(event) {
        const nextFormat = event.detail.value === '12h' ? '12h' : '24h';
        const normalized = this.parseTimeValue(this.editorDefaultValue, this.editorTimeFormat) || this.parseTimeValue(this.editorDefaultValue, nextFormat);
        this.editorTimeFormat = nextFormat;
        if (!this.editorPlaceholder || ['HH:mm', '19:00', '8:00 PM'].includes(this.editorPlaceholder)) {
            this.editorPlaceholder = this.timePlaceholderForFormat(nextFormat);
        }
        if (normalized) {
            this.editorDefaultValue = this.formatTimeValue(normalized, nextFormat);
        }
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
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
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorPrefillEnabledCommit() {
        this.flushEditorDraftSave();
    }

    async handleEditorPrefillAliasChange(event) {
        this.editorPrefillAlias = event.detail.value;
        if (!this.editorPrefillAlias) {
            this.editorPrefillFieldPath = '';
            this.editorLocationCountryPrefillFieldPath = '';
            this.editorLocationRegionPrefillFieldPath = '';
            this.editorLocationCityPrefillFieldPath = '';
        }
        this.applyEditorDraft();
        await this.ensureParentRepeatGroupAlias(this.editorPrefillAlias);
    }

    handleEditorPrefillFieldChange(event) {
        this.editorPrefillFieldPath = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorLocationCountryPrefillFieldChange(event) {
        this.editorLocationCountryPrefillFieldPath = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorLocationRegionPrefillFieldChange(event) {
        this.editorLocationRegionPrefillFieldPath = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorLocationCityPrefillFieldChange(event) {
        this.editorLocationCityPrefillFieldPath = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorSubmitEnabledChange(event) {
        this.editorSubmitEnabled = event.target.checked;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorSubmitEnabledCommit() {
        this.flushEditorDraftSave();
    }

    async handleEditorSubmitActionChange(event) {
        this.editorSubmitActionKey = event.detail.value;
        if (!this.editorSubmitActionKey) {
            this.editorSubmitFieldPath = '';
            this.editorLocationCountrySubmitFieldPath = '';
            this.editorLocationRegionSubmitFieldPath = '';
            this.editorLocationCitySubmitFieldPath = '';
        }
        this.applyEditorDraft();
        await this.ensureParentRepeatGroupSubmitAction(this.editorSubmitActionKey);
    }

    handleEditorSubmitFieldChange(event) {
        this.editorSubmitFieldPath = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorLocationCountrySubmitFieldChange(event) {
        this.editorLocationCountrySubmitFieldPath = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorLocationRegionSubmitFieldChange(event) {
        this.editorLocationRegionSubmitFieldPath = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorLocationCitySubmitFieldChange(event) {
        this.editorLocationCitySubmitFieldPath = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorAllowMultipleFilesChange(event) {
        this.editorAllowMultipleFiles = event.target.checked;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorAllowedExtensionsCommit(event) {
        this.editorAllowedExtensionsText = event.target.value;
        this.applyEditorDraft();
    }

    handleEditorMaxFileSizeCommit(event) {
        this.editorMaxFileSizeMb = event.target.value;
        this.applyEditorDraft();
    }

    handleEditorTargetSubmitActionChange(event) {
        this.editorTargetSubmitActionKey = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorHelpTextCommit(event) {
        this.editorHelpText = event.target.value || '';
        this.applyEditorDraft();
    }

    handleEditorClearButtonLabelCommit(event) {
        this.editorClearButtonLabel = event.target.value || '';
        this.applyEditorDraft();
    }

    handleEditorShowTitleChange(event) {
        this.editorShowTitle = event.target.checked;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorShowTitleCommit() {
        this.flushEditorDraftSave();
    }

    handleEditorBoxedChange(event) {
        this.editorBoxed = event.target.checked;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorBoxedCommit() {
        this.flushEditorDraftSave();
    }

    handleEditorColumnsChange(event) {
        this.editorColumns = event.detail.value;
        this.editorColumnLayout = this.normalizeColumnLayout(this.editorColumnLayout, Number(this.editorColumns || 1));
        this.applyEditorDraft();
    }

    handleColumnLayoutChange(event) {
        this.editorColumnLayout = this.normalizeColumnLayout(event.currentTarget.dataset.layout, Number(this.editorColumns || 1));
        this.applyEditorDraft();
    }

    handleEditorRepeatSourceAliasChange(event) {
        this.editorRepeatSourceAlias = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorRepeatSubmitActionChange(event) {
        this.editorRepeatSubmitActionKey = event.detail.value;
        this.applyEditorDraft();
    }

    handleEditorAllowAddRowsChange(event) {
        this.editorAllowAddRows = event.target.checked;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorAllowAddRowsCommit() {
        this.flushEditorDraftSave();
    }

    handleEditorAllowDeleteRowsChange(event) {
        this.editorAllowDeleteRows = event.target.checked;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorAllowDeleteRowsCommit() {
        this.flushEditorDraftSave();
    }

    handleEditorRepeatLabelModeChange(event) {
        this.editorShowLabelsOnEachRow = event.detail.value !== 'tableHeader';
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorRowSignatureAttachToRowRecordChange(event) {
        this.editorRowSignatureAttachToRowRecord = event.target.checked;
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
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
        event.stopPropagation();
        const target = this.sectionDropTargetFromEvent(event);
        this.dragTargetIndex = null;
        this.dragSectionTarget = target ? `${target.sectionId}:${target.columnNumber}` : null;
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

    sectionDropTargetFromEvent(event) {
        const sectionId = event.currentTarget.dataset.sectionId;
        const columnNumber = Number(event.currentTarget.dataset.column);
        let targetIndex = Number(event.currentTarget.dataset.index);
        if (!sectionId || !Number.isFinite(columnNumber)) {
            return null;
        }
        if (!Number.isFinite(targetIndex)) {
            targetIndex = 0;
        }
        if (event.currentTarget.dataset.itemDrop === 'true') {
            const bounds = event.currentTarget.getBoundingClientRect();
            const dropAfter = event.clientY > bounds.top + (bounds.height / 2);
            if (dropAfter) {
                targetIndex += 1;
            }
        }
        return {
            sectionId,
            columnNumber,
            targetIndex
        };
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

        const undoStep = this.captureUndoStep('Move element');
        try {
            this.selectedElementId = elementId;
            this.optimisticMoveToTopLevel(elementId, targetIndex);
            await moveElement({
                versionId: this.selectedVersionId,
                elementId,
                targetParentId: null,
                columnNumber: null,
                targetIndex
            });
        } catch (error) {
            this.removeUndoStep(undoStep);
            await this.loadWorkspace(this.selectedProjectId, this.selectedFormId, this.selectedVersionId);
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.draggedElementId = null;
            this.dragTargetIndex = null;
            this.dragSectionTarget = null;
        }
    }

    async handleDropIntoSection(event) {
        event.preventDefault();
        event.stopPropagation();
        if (this.isSelectedVersionReadOnly) {
            return;
        }
        event.stopPropagation();
        const target = this.sectionDropTargetFromEvent(event);
        const sectionId = target?.sectionId;
        const columnNumber = target?.columnNumber;
        const targetIndex = target?.targetIndex;
        const elementId = this.draggedElementId || event.dataTransfer.getData('text/plain');
        this.dragSectionTarget = null;
        if (!elementId || !sectionId || !Number.isFinite(columnNumber) || !Number.isFinite(targetIndex) || !this.selectedVersionId) {
            this.draggedElementId = null;
            return;
        }

        const undoStep = this.captureUndoStep('Move element');
        const movedElement = (this.elements || []).find((item) => item.id === elementId);
        const targetParent = (this.elements || []).find((item) => item.id === sectionId);
        const enablesSubmissionPdf = movedElement?.elementType === 'signature'
            && targetParent?.elementType === 'repeatGroup'
            && !this.draftSubmissionPdfEnabled;
        try {
            this.selectedElementId = elementId;
            this.optimisticPlaceInSection(elementId, sectionId, columnNumber, targetIndex);
            await moveElement({
                versionId: this.selectedVersionId,
                elementId,
                targetParentId: sectionId,
                columnNumber,
                targetIndex
            });
            if (enablesSubmissionPdf) {
                this.draftSubmissionPdfEnabled = true;
                this.selectedVersionSubmissionPdfEnabled = true;
                this.showToast(
                    'Submission PDF enabled',
                    'A Records List Signature requires a Submission PDF, so PDF generation was enabled automatically.',
                    'success'
                );
            }
        } catch (error) {
            this.removeUndoStep(undoStep);
            await this.loadWorkspace(this.selectedProjectId, this.selectedFormId, this.selectedVersionId);
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.draggedElementId = null;
            this.dragSectionTarget = null;
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
        const undoStep = this.captureUndoStep('Change section columns');
        try {
            this.selectedElementId = elementId;
            this.optimisticSetSectionColumns(elementId, columns);
            await updateSectionColumns({ elementId, columns });
            await this.loadWorkspace(this.selectedProjectId, this.selectedFormId, this.selectedVersionId, true);
        } catch (error) {
            this.removeUndoStep(undoStep);
            await this.loadWorkspace(this.selectedProjectId, this.selectedFormId, this.selectedVersionId);
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleDeleteSelected() {
        if (!this.selectedElementId || this.isSelectedVersionReadOnly || this.selectedElementIsSubmitButton || this.selectedElementIsUserVerification) {
            return;
        }

        this.isLoading = true;
        const undoStep = this.captureUndoStep('Delete element');
        try {
            const deletedId = this.selectedElementId;
            this.removeDeletedElementLocally(deletedId);
            await deleteDesignerElement({ elementId: deletedId });
            this.selectedElementId = this.elements.find((item) => item.id !== deletedId)?.id || null;
            await this.loadWorkspace(this.selectedProjectId, this.selectedFormId, this.selectedVersionId);
            this.showToast('Element deleted', 'The selected canvas item was removed.', 'success');
        } catch (error) {
            this.removeUndoStep(undoStep);
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
            this.editorDefaultValue = '';
            this.editorPlaceholder = '';
            this.editorDisplayText = '';
            this.editorImageUrl = '';
            this.editorImageAlt = '';
            this.editorImageFit = 'original';
            this.editorImageWidthPercent = '100';
            this.editorSpacerSize = 'field';
            this.editorShowTitle = true;
            this.editorBoxed = true;
            this.editorColumns = '2';
            this.editorColumnLayout = 'equal';
            this.editorRepeatSourceAlias = '';
            this.editorRepeatSubmitActionKey = '';
            this.editorAllowAddRows = true;
            this.editorAllowDeleteRows = true;
            this.editorShowLabelsOnEachRow = true;
            this.editorRowSignatureEnabled = false;
            this.editorRowSignatureRequired = true;
            this.editorRowSignatureLabel = 'Signature';
            this.editorRowSignatureHelpText = '';
            this.editorRowSignatureAttachToRowRecord = false;
            this.editorPicklistObject = '';
            this.editorPicklistField = '';
            this.editorLookupTargetObject = '';
            this.editorLookupSearchFieldsText = 'Name';
            this.editorLookupDisplayFieldsText = 'Name';
            this.editorLookupMinSearchLength = '2';
            this.editorLookupResultLimit = '10';
            this.editorLabelBold = false;
            this.editorLabelItalic = false;
            this.editorLabelUnderline = false;
            this.editorRequired = false;
            this.editorFieldBehavior = 'editable';
            this.editorConditionalEnabled = false;
            this.editorConditionalConditions = [];
            this.editorConditionalExpression = '';
            this.editorConditionalFieldKey = '';
            this.editorConditionalOperator = 'equals';
            this.editorConditionalValue = '';
            this.editorMinValue = '';
            this.editorMaxValue = '';
            this.editorTextareaMaxLength = '254';
            this.editorDateDisplayFormat = 'us';
            this.editorDateGmtOffset = '+00:00';
            this.editorTimeFormat = '24h';
            this.editorPastYears = '';
            this.editorPastMonths = '';
            this.editorFutureYears = '';
            this.editorFutureMonths = '';
            this.editorTextRule = 'none';
            this.editorPrefillEnabled = false;
            this.editorPrefillAlias = '';
            this.editorPrefillFieldPath = '';
            this.editorLocationCountryPrefillFieldPath = '';
            this.editorLocationRegionPrefillFieldPath = '';
            this.editorLocationCityPrefillFieldPath = '';
            this.editorSubmitEnabled = false;
            this.editorSubmitActionKey = '';
            this.editorSubmitFieldPath = '';
            this.editorLocationCountrySubmitFieldPath = '';
            this.editorLocationRegionSubmitFieldPath = '';
            this.editorLocationCitySubmitFieldPath = '';
            this.editorAllowMultipleFiles = false;
            this.editorAllowedExtensionsText = '';
            this.editorMaxFileSizeMb = '10';
            this.editorTargetSubmitActionKey = '';
            this.editorUseFormula = false;
            this.editorFormulaExpression = '';
            this.editorFormulaPreviewValue = '';
            this.editorFormulaError = '';
            this.editorButtonDestinationType = 'form';
            this.editorButtonTargetFormId = '';
            this.editorButtonExternalUrlMode = 'template';
            this.editorButtonExternalUrlTemplate = '';
            this.editorButtonExternalUrlFormula = '';
            this.editorButtonQueryParameters = [];
            this.editorButtonSubmitBeforeNavigation = false;
            this.selectedFormulaFieldToken = '';
            this.picklistFieldOptions = [];
            this.editorSurveyOptions = [];
            return;
        }

        if (this.selectedElementIsSubmitButton) {
            this.editorLabel = '';
            this.editorElementType = '';
            this.picklistFieldOptions = [];
            this.editorSurveyOptions = [];
            return;
        }

        if (this.selectedElementIsUserVerification) {
            this.editorLabel = '';
            this.editorElementType = '';
            this.picklistFieldOptions = [];
            this.editorSurveyOptions = [];
            return;
        }

        const config = this.parseConfig(selected.configJson);
        this.editorLabel = selected.label || '';
        this.editorElementType = selected.elementType === 'hidden' ? 'text' : (selected.elementType || 'text');
        this.editorLabelPosition = config.labelPosition === 'inline' ? 'above' : (config.labelPosition || 'above');
        const loadedTimeFormat = config.timeFormat === '12h' ? '12h' : '24h';
        this.editorTimeFormat = loadedTimeFormat;
        this.editorDefaultValue = selected.elementType === 'time'
            ? this.formatTimeValue(config.defaultValue || '', loadedTimeFormat)
            : (config.defaultValue || '');
        this.editorPlaceholder = config.placeholder || '';
        this.editorDisplayText = config.html || config.text || '';
        this.editorImageUrl = config.imageUrl || '';
        this.editorImageAlt = config.altText || '';
        this.editorImageFit = config.imageFit || 'original';
        this.editorImageWidthPercent = config.imageWidthPercent == null ? '100' : String(config.imageWidthPercent);
        this.editorSpacerSize = config.spacerSize === 'fieldWithLabel' ? 'fieldWithLabel' : 'field';
        this.editorShowTitle = config.showTitle !== false;
        this.editorBoxed = config.boxed !== false;
        this.editorColumns = String(config.columns || (selected.elementType === 'group' ? 1 : 2));
        this.editorColumnLayout = this.normalizeColumnLayout(config.columnLayout, Number(this.editorColumns || 1));
        this.editorRepeatSourceAlias = config.repeatSourceAlias || '';
        this.editorRepeatSubmitActionKey = config.repeatSubmitActionKey || config.repeatSubmitAlias || '';
        this.editorAllowAddRows = config.allowAddRows !== false;
        this.editorAllowDeleteRows = config.allowDeleteRows !== false;
        this.editorShowLabelsOnEachRow = config.showLabelsOnEachRow !== false;
        this.editorRowSignatureAttachToRowRecord = config.attachToRowRecord === true;
        const inferredPicklistSource = this.inferPicklistSourceFromSubmitMapping(config);
        this.editorPicklistObject = config.sourceObjectApiName || inferredPicklistSource.objectApiName || '';
        this.editorPicklistField = config.sourcePicklistFieldApiName || inferredPicklistSource.fieldApiName || '';
        this.editorLookupTargetObject = config.lookupTargetObject || '';
        this.editorLookupSearchFieldsText = this.joinLookupFields(config.lookupSearchFields, 'Name');
        this.editorLookupSearchFields = this.normalizeLookupFieldList(config.lookupSearchFields || this.editorLookupSearchFieldsText, ['Name']).slice(0, 1);
        this.editorLookupDisplayFields = [...this.editorLookupSearchFields];
        this.editorLookupDisplayFieldsText = this.editorLookupDisplayFields.join(', ');
        this.editorLookupSetFields = this.normalizeLookupSetFields(config.lookupSetFields || config.lookupFieldMappings);
        this.editorLookupMinSearchLength = config.lookupMinSearchLength == null ? '2' : String(config.lookupMinSearchLength);
        this.editorLookupResultLimit = config.lookupLimit == null ? '10' : String(config.lookupLimit);
        this.editorLocationMode = this.normalizeLocationMode(config.locationMode);
        this.editorLocationLayout = this.normalizeLocationLayout(config.locationLayout);
        this.editorLocationRequiredCountry = config.locationRequiredCountry !== false;
        this.editorLocationRequiredRegion = config.locationRequiredRegion === true;
        this.editorLocationRequiredCity = config.locationRequiredCity === true;
        this.editorLocationDefaultCountryCode = config.locationDefaultCountryCode || '';
        this.editorLocationAllowedCountriesText = this.joinLocationCountryCodes(config.locationAllowedCountries);
        this.editorLocationMinSearchLength = config.locationMinSearchLength == null ? '2' : String(config.locationMinSearchLength);
        this.editorLocationResultLimit = config.locationLimit == null ? '10' : String(config.locationLimit);
        this.editorLabelBold = config.labelBold === true;
        this.editorLabelItalic = config.labelItalic === true;
        this.editorLabelUnderline = config.labelUnderline === true;
        this.editorRequired = config.required === true;
        this.editorFieldBehavior = config.fieldBehavior || (selected.elementType === 'hidden' ? 'hidden' : 'editable');
        this.editorConditionalEnabled = config.conditionalEnabled === true;
        this.editorConditionalConditions = this.normalizeVisibilityConditions(
            config.conditionalConditions,
            config.conditionalFieldKey,
            config.conditionalOperator,
            config.conditionalValue
        );
        this.editorConditionalExpression = this.normalizeVisibilityExpression(
            config.conditionalExpression,
            this.editorConditionalConditions.length
        );
        this.ensureDraftElementConditionRow();
        this.syncEditorConditionalLegacyFields();
        this.editorMinValue = config.minValue === null || config.minValue === undefined ? '' : String(config.minValue);
        this.editorMaxValue = config.maxValue === null || config.maxValue === undefined ? '' : String(config.maxValue);
        this.editorTextareaMaxLength = this.selectedElementIsTextarea && config.maxLengthDisabled !== true && (config.maxLength === null || config.maxLength === undefined)
            ? '254'
            : (config.maxLength === null || config.maxLength === undefined ? '' : String(config.maxLength));
        this.editorDateDisplayFormat = config.dateDisplayFormat || 'us';
        this.editorDateGmtOffset = config.dateGmtOffset || '+00:00';
        this.editorPastYears = config.pastYears === null || config.pastYears === undefined ? '' : String(config.pastYears);
        this.editorPastMonths = config.pastMonths === null || config.pastMonths === undefined ? '' : String(config.pastMonths);
        this.editorFutureYears = config.futureYears === null || config.futureYears === undefined ? '' : String(config.futureYears);
        this.editorFutureMonths = config.futureMonths === null || config.futureMonths === undefined ? '' : String(config.futureMonths);
        this.editorTextRule = config.textRule || 'none';
        this.editorPrefillEnabled = !!config.prefillEnabled
            || !!config.prefillAlias
            || !!config.prefillFieldPath
            || !!config.locationPrefillCountryFieldPath
            || !!config.locationPrefillRegionFieldPath
            || !!config.locationPrefillCityFieldPath;
        this.editorPrefillAlias = config.prefillAlias || '';
        this.editorPrefillFieldPath = config.prefillFieldPath || '';
        this.editorLocationCountryPrefillFieldPath = config.locationPrefillCountryFieldPath || '';
        this.editorLocationRegionPrefillFieldPath = config.locationPrefillRegionFieldPath || '';
        this.editorLocationCityPrefillFieldPath = config.locationPrefillCityFieldPath || '';
        this.editorLocationCountrySubmitFieldPath = config.locationSubmitCountryFieldPath || '';
        this.editorLocationRegionSubmitFieldPath = config.locationSubmitRegionFieldPath || '';
        this.editorLocationCitySubmitFieldPath = config.locationSubmitCityFieldPath || '';
        this.editorSubmitEnabled = !!config.submitEnabled
            || !!config.submitActionKey
            || !!config.submitFieldPath
            || !!config.locationSubmitCountryFieldPath
            || !!config.locationSubmitRegionFieldPath
            || !!config.locationSubmitCityFieldPath;
        this.editorSubmitActionKey = config.submitActionKey || '';
        this.editorSubmitFieldPath = config.submitFieldPath || '';
        this.editorAllowMultipleFiles = config.allowMultiple === true;
        this.editorAllowedExtensionsText = this.allowedExtensionsText(config.allowedExtensions);
        this.editorMaxFileSizeMb = config.maxFileSizeMb == null ? '10' : String(config.maxFileSizeMb);
        this.editorTargetSubmitActionKey = config.targetSubmitActionKey || '';
        this.editorHelpText = config.helpText || '';
        this.editorClearButtonLabel = config.clearButtonLabel || 'Clear';
        this.editorButtonDestinationType = config.destinationType === 'external' ? 'external' : 'form';
        this.editorButtonTargetFormId = config.targetFormId || '';
        this.editorButtonExternalUrlMode = config.externalUrlMode === 'formula' ? 'formula' : 'template';
        this.editorButtonExternalUrlTemplate = config.externalUrlTemplate || '';
        this.editorButtonExternalUrlFormula = config.externalUrlFormula || '';
        this.editorButtonQueryParameters = Array.isArray(config.queryParameters)
            ? config.queryParameters.map((item, index) => ({
                key: `button-param-${index}`,
                name: item.name || '',
                valueMode: item.valueMode === 'formula' ? 'formula' : 'template',
                usesFormula: item.valueMode === 'formula',
                valueTemplate: item.valueTemplate || '',
                valueFormula: item.valueFormula || ''
            }))
            : [];
        this.editorButtonSubmitBeforeNavigation = this.selectedElementIsInsideRepeatGroup
            ? false
            : config.submitBeforeNavigation === true;
        this.editorSurveyOptions = this.normalizeSurveyOptions(config.options);
        this.editorUseFormula = config.isFormula === true;
        this.editorFormulaExpression = config.formulaExpression || '';
        this.selectedFormulaFieldToken = '';
        this.updateFormulaPreview();
        if (this.selectedElementUsesSalesforcePicklistSource && this.editorPicklistObject) {
            this.loadPicklistFieldOptions(this.editorPicklistObject, this.editorPicklistField);
        } else {
            this.picklistFieldOptions = [];
        }
        if (this.selectedElementIsLookup && this.editorLookupTargetObject) {
            this.loadLookupFieldOptions(this.editorLookupTargetObject);
        } else {
            this.lookupSearchFieldOptions = [];
            this.lookupDisplayFieldOptions = [];
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

        if (this.selectedElementIsSpacer) {
            nextConfig.spacerSize = this.editorSpacerSize === 'fieldWithLabel' ? 'fieldWithLabel' : 'field';
            delete nextConfig.labelPosition;
        } else {
            delete nextConfig.spacerSize;
        }

        if (this.selectedElementSupportsDefaultValue) {
            nextConfig.defaultValue = this.selectedElementIsTime
                ? (this.parseTimeValue(this.editorDefaultValue, this.editorTimeFormat) || this.editorDefaultValue || '')
                : (this.editorDefaultValue || '');
            delete nextConfig.placeholder;
            if (this.editorElementType === 'checkbox') {
                nextConfig.checked = ['true', '1', 'yes', 'checked'].includes(String(this.editorDefaultValue || '').toLowerCase());
            }
        } else {
            delete nextConfig.defaultValue;
        }

        if (this.selectedElementSupportsPlaceholder) {
            nextConfig.placeholder = this.selectedElementIsTime
                ? (this.editorPlaceholder || this.timePlaceholderForFormat(this.editorTimeFormat))
                : (this.editorPlaceholder || '');
        } else {
            delete nextConfig.placeholder;
        }

        if (this.selectedElementIsRichTextDisplay) {
            const defaultRichText = this.selectedElementIsMergedDocument ? '<p>Merged document text</p>' : '<p>Display text</p>';
            nextConfig.html = this.editorDisplayText || defaultRichText;
            nextConfig.text = this.editorDisplayText || defaultRichText;
        }

        if (this.selectedElementIsImage) {
            nextConfig.imageUrl = this.editorImageUrl || '';
            nextConfig.altText = this.editorImageAlt || 'Image preview';
            nextConfig.imageFit = this.editorImageFit || 'original';
            nextConfig.imageWidthPercent = this.editorImageWidthPercent || '100';
        }

        if (this.selectedElementIsFileUpload) {
            nextConfig.allowMultiple = this.editorAllowMultipleFiles === true;
            nextConfig.allowedExtensions = this.parseAllowedExtensionsText(this.editorAllowedExtensionsText);
            nextConfig.maxFileSizeMb = this.parsePositiveInteger(this.editorMaxFileSizeMb, 10);
            nextConfig.targetSubmitActionKey = this.editorTargetSubmitActionKey || '';
        } else if (this.selectedElementIsSignature) {
            nextConfig.helpText = this.editorHelpText || '';
            nextConfig.clearButtonLabel = this.editorClearButtonLabel || 'Clear';
            if (this.selectedElementIsInsideRepeatGroup) {
                nextConfig.targetSubmitActionKey = '';
                nextConfig.attachToRowRecord = this.editorRowSignatureAttachToRowRecord === true;
            } else {
                nextConfig.targetSubmitActionKey = this.editorTargetSubmitActionKey || '';
                delete nextConfig.attachToRowRecord;
            }
            delete nextConfig.allowMultiple;
            delete nextConfig.allowedExtensions;
            delete nextConfig.maxFileSizeMb;
        } else {
            delete nextConfig.allowMultiple;
            delete nextConfig.allowedExtensions;
            delete nextConfig.maxFileSizeMb;
            delete nextConfig.targetSubmitActionKey;
            delete nextConfig.helpText;
            delete nextConfig.clearButtonLabel;
        }

        if (this.selectedElementUsesSalesforcePicklistSource) {
            nextConfig.sourceObjectApiName = this.editorPicklistObject || '';
            nextConfig.sourcePicklistFieldApiName = this.editorPicklistField || '';
            if (Array.isArray(baseConfig.options) && baseConfig.options.length) {
                nextConfig.options = baseConfig.options
                    .map((option) => ({
                        label: option?.label || '',
                        value: option?.value || ''
                    }))
                    .filter((option) => option.label || option.value);
            } else if (Array.isArray(nextConfig.options)) {
                nextConfig.options = nextConfig.options
                    .map((option) => ({
                        label: option?.label || '',
                        value: option?.value || ''
                    }))
                    .filter((option) => option.label || option.value);
            } else {
                delete nextConfig.options;
            }
        } else {
            delete nextConfig.sourceObjectApiName;
            delete nextConfig.sourcePicklistFieldApiName;
        }

        if (this.selectedElementIsLookup) {
            nextConfig.lookupTargetObject = this.editorLookupTargetObject || '';
            nextConfig.lookupSearchFields = this.normalizeLookupFieldList(this.editorLookupSearchFields, ['Name']).slice(0, 1);
            nextConfig.lookupDisplayFields = [...nextConfig.lookupSearchFields];
            nextConfig.lookupSetFields = this.normalizeLookupSetFields(this.editorLookupSetFields)
                .filter((mapping) => mapping.sourceField && mapping.targetFieldKey);
            nextConfig.lookupMinSearchLength = this.parsePositiveInteger(this.editorLookupMinSearchLength, 2);
            nextConfig.lookupLimit = Math.min(this.parsePositiveInteger(this.editorLookupResultLimit, 10), 25);
        } else {
            delete nextConfig.lookupTargetObject;
            delete nextConfig.lookupSearchFields;
            delete nextConfig.lookupDisplayFields;
            delete nextConfig.lookupSetFields;
            delete nextConfig.lookupFieldMappings;
            delete nextConfig.lookupMinSearchLength;
            delete nextConfig.lookupLimit;
        }

        if (this.selectedElementIsLocation) {
            nextConfig.locationMode = this.normalizeLocationMode(this.editorLocationMode);
            nextConfig.locationLayout = this.normalizeLocationLayout(this.editorLocationLayout);
            nextConfig.locationRequiredCountry = this.editorLocationRequiredCountry === true;
            nextConfig.locationRequiredRegion = this.editorLocationRequiredRegion === true;
            nextConfig.locationRequiredCity = this.editorLocationRequiredCity === true;
            nextConfig.locationDefaultCountryCode = String(this.editorLocationDefaultCountryCode || '').trim().toUpperCase();
            nextConfig.locationAllowedCountries = this.parseLocationCountryCodes(this.editorLocationAllowedCountriesText);
            nextConfig.locationMinSearchLength = this.parsePositiveInteger(this.editorLocationMinSearchLength, 2);
            nextConfig.locationLimit = Math.min(this.parsePositiveInteger(this.editorLocationResultLimit, 10), 25);
            nextConfig.locationOutputMode = 'structured';
        } else {
            delete nextConfig.locationMode;
            delete nextConfig.locationLayout;
            delete nextConfig.locationRequiredCountry;
            delete nextConfig.locationRequiredRegion;
            delete nextConfig.locationRequiredCity;
            delete nextConfig.locationDefaultCountryCode;
            delete nextConfig.locationAllowedCountries;
            delete nextConfig.locationMinSearchLength;
            delete nextConfig.locationLimit;
            delete nextConfig.locationOutputMode;
        }

        if (this.selectedElementSupportsSurveyChoices) {
            nextConfig.options = this.surveyOptionsForSave();
        }

        if (this.selectedElementSupportsBoldLabel) {
            nextConfig.labelBold = this.editorLabelBold;
            nextConfig.labelItalic = this.editorLabelItalic;
            nextConfig.labelUnderline = this.editorLabelUnderline;
        } else {
            delete nextConfig.labelBold;
            delete nextConfig.labelItalic;
            delete nextConfig.labelUnderline;
        }

        if (this.selectedElementSupportsRequired) {
            nextConfig.required = this.editorRequired === true;
        } else {
            delete nextConfig.required;
        }

        if (this.selectedElementSupportsFieldBehavior) {
            nextConfig.fieldBehavior = this.editorFieldBehavior || 'editable';
        } else {
            delete nextConfig.fieldBehavior;
        }

        if (this.selectedElementSupportsFormula) {
            nextConfig.isFormula = this.editorUseFormula === true;
            nextConfig.formulaExpression = this.editorUseFormula ? (this.editorFormulaExpression || '') : '';
            if (this.editorUseFormula) {
                nextConfig.defaultValue = '';
                delete nextConfig.prefillEnabled;
                delete nextConfig.prefillAlias;
                delete nextConfig.prefillFieldPath;
                delete nextConfig.locationPrefillCountryFieldPath;
                delete nextConfig.locationPrefillRegionFieldPath;
                delete nextConfig.locationPrefillCityFieldPath;
            }
        } else {
            delete nextConfig.isFormula;
            delete nextConfig.formulaExpression;
        }

        if (this.selectedElementSupportsConditional) {
            this.syncEditorConditionalLegacyFields();
            const conditionalConditions = this.sanitizeVisibilityConditions(this.editorConditionalConditions);
            nextConfig.conditionalEnabled = this.editorConditionalEnabled;
            nextConfig.conditionalFieldKey = this.editorConditionalFieldKey || '';
            nextConfig.conditionalOperator = this.editorConditionalOperator || 'equals';
            nextConfig.conditionalValue = this.editorConditionalValue || '';
            nextConfig.conditionalConditions = conditionalConditions;
            nextConfig.conditionalExpression = this.normalizeVisibilityExpression(
                this.editorConditionalExpression,
                conditionalConditions.length
            );
        } else {
            delete nextConfig.conditionalEnabled;
            delete nextConfig.conditionalFieldKey;
            delete nextConfig.conditionalOperator;
            delete nextConfig.conditionalValue;
            delete nextConfig.conditionalConditions;
            delete nextConfig.conditionalExpression;
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

        if (this.selectedElementIsTextarea) {
            const maxLength = this.parsePositiveInteger(this.editorTextareaMaxLength, null);
            if (maxLength) {
                nextConfig.maxLength = maxLength;
                delete nextConfig.maxLengthDisabled;
            } else {
                delete nextConfig.maxLength;
                nextConfig.maxLengthDisabled = true;
            }
        } else {
            delete nextConfig.maxLength;
            delete nextConfig.maxLengthDisabled;
        }

        if (this.selectedElementIsTime) {
            nextConfig.timeFormat = this.editorTimeFormat === '12h' ? '12h' : '24h';
        } else {
            delete nextConfig.timeFormat;
        }

        if (this.selectedElementSupportsTextValidation) {
            nextConfig.textRule = this.editorTextRule || 'none';
        } else {
            delete nextConfig.textRule;
        }

        if (this.selectedElementSupportsSalesforceMapping) {
            if (!this.editorUseFormula) {
                nextConfig.prefillEnabled = this.editorPrefillEnabled;
                nextConfig.prefillAlias = this.editorPrefillAlias || '';
                if (this.selectedElementIsLocation) {
                    nextConfig.prefillFieldPath = '';
                    nextConfig.locationPrefillCountryFieldPath = this.editorLocationCountryPrefillFieldPath || '';
                    nextConfig.locationPrefillRegionFieldPath = this.editorLocationRegionPrefillFieldPath || '';
                    nextConfig.locationPrefillCityFieldPath = this.editorLocationCityPrefillFieldPath || '';
                } else {
                    nextConfig.prefillFieldPath = this.editorPrefillFieldPath || '';
                    delete nextConfig.locationPrefillCountryFieldPath;
                    delete nextConfig.locationPrefillRegionFieldPath;
                    delete nextConfig.locationPrefillCityFieldPath;
                }
            } else {
                delete nextConfig.prefillEnabled;
                delete nextConfig.prefillAlias;
                delete nextConfig.prefillFieldPath;
                delete nextConfig.locationPrefillCountryFieldPath;
                delete nextConfig.locationPrefillRegionFieldPath;
                delete nextConfig.locationPrefillCityFieldPath;
            }
            nextConfig.submitEnabled = this.editorSubmitEnabled;
            nextConfig.submitActionKey = this.editorSubmitActionKey || '';
            if (this.selectedElementIsLocation) {
                nextConfig.submitFieldPath = '';
                nextConfig.locationSubmitCountryFieldPath = this.editorLocationCountrySubmitFieldPath || '';
                nextConfig.locationSubmitRegionFieldPath = this.editorLocationRegionSubmitFieldPath || '';
                nextConfig.locationSubmitCityFieldPath = this.editorLocationCitySubmitFieldPath || '';
            } else {
                nextConfig.submitFieldPath = this.editorSubmitFieldPath || '';
                delete nextConfig.locationSubmitCountryFieldPath;
                delete nextConfig.locationSubmitRegionFieldPath;
                delete nextConfig.locationSubmitCityFieldPath;
            }
        } else {
            delete nextConfig.prefillEnabled;
            delete nextConfig.prefillAlias;
            delete nextConfig.prefillFieldPath;
            delete nextConfig.locationPrefillCountryFieldPath;
            delete nextConfig.locationPrefillRegionFieldPath;
            delete nextConfig.locationPrefillCityFieldPath;
            delete nextConfig.submitEnabled;
            delete nextConfig.submitActionKey;
            delete nextConfig.submitFieldPath;
            delete nextConfig.locationSubmitCountryFieldPath;
            delete nextConfig.locationSubmitRegionFieldPath;
            delete nextConfig.locationSubmitCityFieldPath;
        }

        if (this.selectedElementIsSection) {
            nextConfig.text = this.editorDisplayText || 'Section description';
            nextConfig.showTitle = this.editorShowTitle;
            nextConfig.boxed = this.editorBoxed;
            nextConfig.columns = Number(this.editorColumns || 2);
            nextConfig.columnLayout = this.normalizeColumnLayout(this.editorColumnLayout, nextConfig.columns);
        }

        if (this.selectedElementIsGroup) {
            nextConfig.columns = Number(this.editorColumns || 1);
            nextConfig.columnLayout = this.normalizeColumnLayout(this.editorColumnLayout, nextConfig.columns);
            nextConfig.boxed = false;
            delete nextConfig.text;
            delete nextConfig.showTitle;
            delete nextConfig.repeatSourceAlias;
            delete nextConfig.repeatSubmitActionKey;
            delete nextConfig.repeatSubmitAlias;
            delete nextConfig.allowAddRows;
            delete nextConfig.allowDeleteRows;
            delete nextConfig.showLabelsOnEachRow;
        }

        if (this.selectedElementIsRepeatGroup) {
            nextConfig.showTitle = this.editorShowTitle;
            nextConfig.boxed = this.editorBoxed;
            nextConfig.columns = Number(this.editorColumns || 2);
            nextConfig.columnLayout = this.normalizeColumnLayout(this.editorColumnLayout, nextConfig.columns);
            nextConfig.repeatSourceAlias = this.editorRepeatSourceAlias || '';
            nextConfig.repeatSubmitActionKey = this.editorRepeatSubmitActionKey || '';
            delete nextConfig.repeatSubmitAlias;
            nextConfig.allowAddRows = this.editorAllowAddRows;
            nextConfig.allowDeleteRows = this.editorAllowDeleteRows;
            nextConfig.showLabelsOnEachRow = this.editorShowLabelsOnEachRow;
            delete nextConfig.rowSignatureEnabled;
            delete nextConfig.rowSignatureRequired;
            delete nextConfig.rowSignatureLabel;
            delete nextConfig.rowSignatureHelpText;
            delete nextConfig.rowSignatureAttachToRowRecord;
            delete nextConfig.text;
        }

        if (this.selectedElementIsButton) {
            nextConfig.destinationType = this.editorButtonDestinationType === 'form' ? 'form' : 'external';
            nextConfig.targetFormId = this.editorButtonTargetFormId || '';
            nextConfig.externalUrlMode = this.editorButtonExternalUrlMode === 'formula' ? 'formula' : 'template';
            nextConfig.externalUrlTemplate = this.editorButtonExternalUrlTemplate || '';
            nextConfig.externalUrlFormula = this.editorButtonExternalUrlFormula || '';
            nextConfig.queryParameters = (this.editorButtonQueryParameters || []).map((item) => ({
                name: item.name || '',
                valueMode: item.valueMode === 'formula' ? 'formula' : 'template',
                valueTemplate: item.valueTemplate || '',
                valueFormula: item.valueFormula || ''
            }));
            nextConfig.submitBeforeNavigation = !this.selectedElementIsInsideRepeatGroup && this.editorButtonSubmitBeforeNavigation;
            delete nextConfig.required;
            delete nextConfig.defaultValue;
            delete nextConfig.placeholder;
            delete nextConfig.fieldBehavior;
        }

        return nextConfig;
    }

    validateCurrentFormula() {
        if (!this.selectedElement || !this.selectedElementSupportsFormula || !this.editorUseFormula) {
            return { valid: true, message: '' };
        }
        return this.validateFieldFormulaExpression(this.editorFormulaExpression);
    }

    validateFieldFormulaExpression(expression) {
        if (!this.selectedElement || !this.selectedElementSupportsFormula) {
            return { valid: true, message: '', previewValue: '' };
        }
        const preview = previewFormulaValue({
            expression,
            fieldKey: this.selectedElementFieldKey,
            targetType: this.editorElementType,
            elements: this.elements,
            insideRepeatGroup: this.selectedElementIsInsideRepeatGroup,
            sourceValues: this.formulaSourceValues()
        });
        return {
            valid: preview.valid,
            message: preview.valid ? '' : preview.message,
            references: preview.references || [],
            previewValue: preview.value
        };
    }

    handleSaveFieldFormulaModal() {
        const textarea = this.template.querySelector('[data-id="formula-expression"]');
        const expression = textarea ? (textarea.value || '') : (this.modalFormulaExpression || '');
        const validation = this.validateFieldFormulaExpression(expression);
        this.modalFormulaExpression = expression;
        this.modalFormulaPreviewValue = validation.previewValue;
        this.modalFormulaError = validation.valid ? '' : validation.message;
        if (!validation.valid) {
            return;
        }
        this.editorUseFormula = true;
        this.editorFormulaExpression = expression;
        this.editorFormulaPreviewValue = validation.previewValue;
        this.editorFormulaError = '';
        this.editorDefaultValue = '';
        this.editorPrefillEnabled = false;
        this.editorPrefillAlias = '';
        this.editorPrefillFieldPath = '';
        this.editorLocationCountryPrefillFieldPath = '';
        this.editorLocationRegionPrefillFieldPath = '';
        this.editorLocationCityPrefillFieldPath = '';
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
        this.handleCloseFieldFormulaModal();
        this.showToast('Formula saved', 'The field formula was saved.', 'success');
    }

    handleEditorUseFormulaChange(event) {
        this.editorUseFormula = event.target.checked;
        if (this.editorUseFormula) {
            this.editorDefaultValue = '';
            this.editorPrefillEnabled = false;
            this.editorPrefillAlias = '';
            this.editorPrefillFieldPath = '';
            this.editorLocationCountryPrefillFieldPath = '';
            this.editorLocationRegionPrefillFieldPath = '';
            this.editorLocationCityPrefillFieldPath = '';
        }
        this.errorMessage = '';
        this.updateFormulaPreview();
        this.applyEditorDraft(false);
        this.flushEditorDraftSave();
    }

    handleEditorFormulaExpressionInput(event) {
        if (this.showFieldFormulaModal) {
            this.modalFormulaExpression = event.target.value || '';
            this.modalFormulaPreviewValue = '';
            this.modalFormulaError = '';
            return;
        }
        this.editorFormulaExpression = event.target.value || '';
    }

    handleEditorFormulaExpressionBlur(event) {
        if (this.showFieldFormulaModal) {
            return;
        }
        this.editorFormulaExpression = event.target.value || '';
        this.updateFormulaPreview();
        this.errorMessage = '';
        this.applyEditorDraft(true);
    }

    handleFormulaFieldTokenChange(event) {
        this.selectedFormulaFieldToken = event.detail.value || '';
    }

    insertTokenIntoFormulaExpression(token) {
        if (!token) {
            return;
        }
        const textarea = this.template.querySelector('[data-id="formula-expression"]');
        const sourceValue = textarea
            ? (textarea.value || '')
            : (this.showFieldFormulaModal ? (this.modalFormulaExpression || '') : (this.editorFormulaExpression || ''));
        const start = textarea && Number.isInteger(textarea.selectionStart) ? textarea.selectionStart : sourceValue.length;
        const end = textarea && Number.isInteger(textarea.selectionEnd) ? textarea.selectionEnd : start;
        const nextValue = `${sourceValue.slice(0, start)}${token}${sourceValue.slice(end)}`;
        if (this.showFieldFormulaModal) {
            this.modalFormulaExpression = nextValue;
            this.modalFormulaPreviewValue = '';
            this.modalFormulaError = '';
        } else {
            this.editorFormulaExpression = nextValue;
        }
        if (textarea) {
            textarea.value = nextValue;
            requestAnimationFrame(() => {
                if (typeof textarea.focus === 'function') {
                    textarea.focus();
                }
                if (typeof textarea.setSelectionRange === 'function') {
                    const nextPosition = start + token.length;
                    textarea.setSelectionRange(nextPosition, nextPosition);
                }
            });
        }
    }

    handleInsertFormulaFieldToken() {
        if (!this.selectedFormulaFieldToken) {
            return;
        }
        this.insertTokenIntoFormulaExpression(this.selectedFormulaFieldToken);
        this.selectedFormulaFieldToken = '';
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

    validateEmbeddedImageFile(file, label = 'Image') {
        if (!file) {
            return false;
        }
        if (file.size > MAX_EMBEDDED_IMAGE_BYTES) {
            this.errorMessage = `${label} is too large. Please upload an optimized image under ${MAX_EMBEDDED_IMAGE_LABEL}.`;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Image too large',
                message: `Please upload an optimized image under ${MAX_EMBEDDED_IMAGE_LABEL}.`,
                variant: 'error'
            }));
            return false;
        }
        return true;
    }

    elementUndoSnapshot() {
        return JSON.stringify((this.elements || []).map((item, index) => ({
            elementId: item.elementId,
            label: item.label,
            elementType: item.elementType,
            fieldKey: item.fieldKey,
            elementIndex: item.elementIndex,
            configJson: item.configJson,
            parentElementId: item.parentElementId,
            orderValue: item.orderValue == null ? ((index + 1) * 10) : item.orderValue
        })));
    }

    captureUndoStep(label = 'Undo') {
        if (!this.selectedVersionId || this.isSelectedVersionReadOnly || this.isUndoing) {
            return null;
        }
        const step = {
            versionId: this.selectedVersionId,
            selectedElementId: this.selectedElement?.elementId || this.selectedElementId,
            label,
            snapshotJson: this.elementUndoSnapshot()
        };
        this.undoStack = [step].concat(this.undoStack || []).slice(0, MAX_UNDO_STEPS);
        return step;
    }

    removeUndoStep(step) {
        if (!step) {
            return;
        }
        this.undoStack = (this.undoStack || []).filter((item) => item !== step);
        if (this.pendingElementEditUndoSnapshot === step) {
            this.pendingElementEditUndoSnapshot = null;
        }
    }

    clearUndoStack() {
        this.undoStack = [];
        this.pendingElementEditUndoSnapshot = null;
    }

    async handleUndo() {
        if (this.undoDisabled) {
            return;
        }
        const [step, ...remainingSteps] = this.undoStack || [];
        this.undoStack = remainingSteps;
        this.pendingElementEditUndoSnapshot = null;
        window.clearTimeout(this.autoSaveTimeoutId);
        this.isUndoing = true;
        this.errorMessage = '';
        try {
            await restoreVersionElementsSnapshot({
                versionId: step.versionId,
                snapshotJson: step.snapshotJson
            });
            this.selectedVersionId = step.versionId;
            this.selectedElementId = null;
            await this.loadWorkspace(this.selectedProjectId, this.selectedFormId, step.versionId, true);
            const restoredElement = (this.elements || []).find((item) => item.elementId === step.selectedElementId || item.id === step.selectedElementId);
            this.selectedElementId = restoredElement?.id || null;
            this.syncSelectedState();
            this.showToast('Undo complete', 'The previous canvas state was restored.', 'success');
        } catch (error) {
            this.undoStack = [step].concat(this.undoStack || []).slice(0, MAX_UNDO_STEPS);
            this.errorMessage = this.normalizeError(error);
            await this.loadWorkspace(this.selectedProjectId, this.selectedFormId, this.selectedVersionId, true);
        } finally {
            this.isUndoing = false;
        }
    }

    applyEditorDraft(shouldAutoSave = true, preserveConditionalDraft = false) {
        if (!this.selectedElementId || this.selectedElementIsUserVerification || this.selectedElementIsSubmitButton || this.isSelectedVersionReadOnly) {
            return;
        }
        if (!this.pendingElementEditUndoSnapshot) {
            this.pendingElementEditUndoSnapshot = this.captureUndoStep('Edit element');
        }

        const preservedConditionalState = preserveConditionalDraft
            ? {
                enabled: this.editorConditionalEnabled,
                conditions: (this.editorConditionalConditions || []).map((item) => ({ ...item })),
                expression: this.editorConditionalExpression || ''
            }
            : null;

        const nextConfig = this.buildEditorConfig();
        this.elements = this.elements.map((item) => {
            if (item.id !== this.selectedElementId) {
                return item;
            }

            const nextFieldKey = ['text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'location', 'radio', 'ranking', 'repeatGroup', 'fileUpload', 'signature'].includes(this.editorElementType)
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
        if (preservedConditionalState && this.selectedElementSupportsConditional && !this.selectedElementIsSubmitButton) {
            this.editorConditionalEnabled = preservedConditionalState.enabled;
            this.editorConditionalConditions = preservedConditionalState.conditions;
            this.editorConditionalExpression = preservedConditionalState.expression;
            this.syncEditorConditionalLegacyFields();
        }
        if (shouldAutoSave) {
            this.scheduleAutoSave();
        }
    }

    generatedFieldKey(elementType) {
        const prefix = `${elementType || 'field'}Field`;
        return `${prefix}${Math.floor(Math.random() * 10000)}`;
    }

    async handleSaveVisualSettings() {
        await this.persistVisualSettings(true);
    }

    scheduleAutoSave() {
        if (!this.selectedElementId || this.selectedElementIsUserVerification || this.selectedElementIsSubmitButton || this.isSelectedVersionReadOnly) {
            return;
        }
        window.clearTimeout(this.autoSaveTimeoutId);
        this.persistVisualSettings(false);
    }

    flushEditorDraftSave() {
        if (!this.selectedElementId || this.selectedElementIsUserVerification || this.selectedElementIsSubmitButton || this.isSelectedVersionReadOnly) {
            return;
        }
        window.clearTimeout(this.autoSaveTimeoutId);
        this.persistVisualSettings(false);
    }

    async persistVisualSettings(showToast) {
        if (!this.selectedElement || this.selectedElementIsUserVerification || this.selectedElementIsSubmitButton || this.isCloningField) {
            return;
        }
        let savePromise;
        try {
            const selected = this.selectedElement;
            savePromise = updateElement({
                inputJson: JSON.stringify({
                    id: selected.id,
                    label: selected.label,
                    fieldKey: selected.fieldKey,
                    configJson: selected.configJson,
                    elementType: selected.elementType
                })
            });
            this.pendingVisualSavePromises = [...this.pendingVisualSavePromises, savePromise];
            await savePromise;
            if (showToast) {
                this.showToast('Saved', 'Visual settings updated.', 'success');
            }
            this.pendingElementEditUndoSnapshot = null;
        } catch (error) {
            this.removeUndoStep(this.pendingElementEditUndoSnapshot);
            const saveDebugMessage = this.describeElementSaveError(error, this.selectedElement);
            // Temporary debugging for the checkbox default-value save path.
            // eslint-disable-next-line no-console
            console.error('NativeFormsDesigner.persistVisualSettings failed', {
                elementId: this.selectedElement?.id,
                elementType: this.selectedElement?.elementType,
                fieldKey: this.selectedElement?.fieldKey,
                configJson: this.selectedElement?.configJson,
                error
            });
            await this.loadWorkspace(this.selectedProjectId, this.selectedFormId, this.selectedVersionId, true);
            this.errorMessage = saveDebugMessage;
        } finally {
            this.pendingVisualSavePromises = this.pendingVisualSavePromises.filter((pending) => pending !== savePromise);
        }
    }

    validateAllFormulasForPublish() {
        if (this.draftPostSubmitAutoLinkEnabled && this.postSubmitUrlModeIsFormula) {
            const validation = validateFormulaConfig({
                expression: this.draftPostSubmitUrlFormula || '',
                fieldKey: '',
                targetType: 'text',
                elements: this.elements,
                allowFormulaReferences: true
            });
            if (!validation.valid) {
                return {
                    valid: false,
                    message: `Redirect formula: ${validation.message}`
                };
            }
            const preview = previewFormulaValue({
                expression: this.draftPostSubmitUrlFormula || '',
                fieldKey: '',
                targetType: 'text',
                elements: this.elements,
                sourceValues: this.formulaSourceValues(),
                allowFormulaReferences: true
            });
            const previewUrl = String(preview.value || '').trim();
            if (preview.valid && previewUrl && !this.isAbsoluteHttpUrl(previewUrl)) {
                return {
                    valid: false,
                    message: 'Redirect formula preview must be a valid http:// or https:// URL, or blank.'
                };
            }
        }
        for (let index = 0; index < (this.elements || []).length; index += 1) {
            const item = this.elements[index];
            const config = this.parseConfig(item?.configJson);
            if (item?.elementType === 'button') {
                const buttonValidation = this.validateButtonNavigationForPublish(item, config);
                if (!buttonValidation.valid) {
                    return buttonValidation;
                }
            }
            if (config.isFormula !== true) {
                continue;
            }
            const validation = validateFormulaConfig({
                expression: config.formulaExpression || '',
                fieldKey: item.fieldKey,
                targetType: item.elementType,
                elements: this.elements,
                insideRepeatGroup: item.parentElementId ? this.isElementInsideRepeatGroup(item) : false
            });
            if (!validation.valid) {
                const label = item.label || item.fieldKey || 'Formula field';
                return {
                    valid: false,
                    message: `${label}: ${validation.message}`
                };
            }
        }
        return { valid: true, message: '' };
    }

    validateButtonNavigationForPublish(item, config) {
        const label = item.label || 'Button';
        const expressionValues = [];
        const templateValues = [];
        if (config.destinationType !== 'form') {
            if (config.externalUrlMode === 'formula') {
                expressionValues.push({ label: 'destination formula', value: config.externalUrlFormula || '', requireUrl: true });
            } else {
                templateValues.push({ label: 'destination URL template', value: config.externalUrlTemplate || '' });
            }
        }
        (config.queryParameters || []).forEach((parameter, index) => {
            if (parameter.valueMode === 'formula') {
                expressionValues.push({ label: `query parameter ${index + 1} formula`, value: parameter.valueFormula || '', requireUrl: false });
            } else {
                templateValues.push({ label: `query parameter ${index + 1} template`, value: parameter.valueTemplate || '' });
            }
        });
        for (let index = 0; index < templateValues.length; index += 1) {
            const rowValidation = this.validateButtonRowReferences(item, templateValues[index].value, label, templateValues[index].label, true);
            if (!rowValidation.valid) {
                return rowValidation;
            }
        }
        for (let index = 0; index < expressionValues.length; index += 1) {
            const entry = expressionValues[index];
            const rowValidation = this.validateButtonRowReferences(item, entry.value, label, entry.label, false);
            if (!rowValidation.valid) {
                return rowValidation;
            }
            const normalizedExpression = String(entry.value || '').replace(/\{row\.([a-zA-Z0-9_]+)\}/g, '{$1}');
            const validation = validateFormulaConfig({
                expression: normalizedExpression,
                fieldKey: '',
                targetType: 'text',
                elements: this.elements,
                allowFormulaReferences: true
            });
            if (!validation.valid) {
                return { valid: false, message: `${label} ${entry.label}: ${validation.message}` };
            }
            if (entry.requireUrl) {
                const preview = previewFormulaValue({
                    expression: normalizedExpression,
                    fieldKey: '',
                    targetType: 'text',
                    elements: this.elements,
                    sourceValues: this.formulaSourceValues(),
                    allowFormulaReferences: true
                });
                const previewUrl = String(preview.value || '').trim();
                if (preview.valid && previewUrl && !this.isAbsoluteHttpUrl(previewUrl)) {
                    return { valid: false, message: `${label} destination formula preview must be a valid http:// or https:// URL, or blank.` };
                }
            }
        }
        return { valid: true, message: '' };
    }

    validateButtonRowReferences(item, source, label, contextLabel, templateMode) {
        const insideRepeatGroup = this.isElementInsideRepeatGroup(item);
        const rowPattern = templateMode ? /\{\{\s*row\.([a-zA-Z0-9_]+)\s*\}\}/g : /\{row\.([a-zA-Z0-9_]+)\}/g;
        const rowReferences = Array.from(String(source || '').matchAll(rowPattern), (match) => match[1]);
        if (rowReferences.length && !insideRepeatGroup) {
            return { valid: false, message: `${label} ${contextLabel}: row references can only be used inside a Records List.` };
        }
        if (!rowReferences.length) {
            return { valid: true, message: '' };
        }
        const repeatGroup = this.findRepeatGroupAncestor(item);
        const rowFieldKeys = new Set(
            (this.elements || [])
                .filter((candidate) => candidate.parentElementId === repeatGroup?.elementId && candidate.fieldKey)
                .map((candidate) => candidate.fieldKey)
        );
        const unknownKey = rowReferences.find((fieldKey) => !rowFieldKeys.has(fieldKey));
        return unknownKey
            ? { valid: false, message: `${label} ${contextLabel}: unknown row field reference: ${unknownKey}.` }
            : { valid: true, message: '' };
    }

    isElementInsideRepeatGroup(item) {
        return !!this.findRepeatGroupAncestor(item);
    }

    findRepeatGroupAncestor(item) {
        let parentElementId = item?.parentElementId;
        while (parentElementId) {
            const parent = this.elements.find((candidate) => candidate.elementId === parentElementId);
            if (!parent) {
                return null;
            }
            if (parent.elementType === 'repeatGroup') {
                return parent;
            }
            parentElementId = parent.parentElementId;
        }
        return null;
    }

    findParentElement(item) {
        if (!item?.parentElementId) {
            return null;
        }
        return this.elements.find((candidate) => candidate.elementId === item.parentElementId) || null;
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
                inputJson: JSON.stringify({
                    id: updatedParent.id,
                    label: updatedParent.label,
                    fieldKey: updatedParent.fieldKey,
                    configJson: updatedParent.configJson,
                    elementType: updatedParent.elementType
                })
            });
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            await this.loadWorkspace(this.selectedProjectId, this.selectedFormId, this.selectedVersionId, true);
        }
    }

    async ensureParentRepeatGroupSubmitAction(actionKey) {
        if (!actionKey || this.isSelectedVersionReadOnly) {
            return;
        }
        const parent = this.selectedRepeatGroupParent;
        if (!parent) {
            return;
        }
        const action = (this.submitActionDetails || []).find((candidate) => candidate.actionKey === actionKey);
        if (action?.commandType !== 'upsertMany') {
            return;
        }
        if (action.repeatGroupKey && action.repeatGroupKey !== parent.fieldKey && action.repeatGroupKey !== parent.elementId) {
            return;
        }

        const parentConfig = this.parseConfig(parent.configJson);
        if (parentConfig.repeatSubmitActionKey) {
            return;
        }

        parentConfig.repeatSubmitActionKey = actionKey;
        const updatedParent = this.decorateBaseElement({
            ...parent,
            configJson: JSON.stringify(parentConfig)
        });

        this.elements = this.elements.map((item) => (item.id === parent.id ? updatedParent : item));
        this.syncSelectedState();

        try {
            await updateElement({
                inputJson: JSON.stringify({
                    id: updatedParent.id,
                    label: updatedParent.label,
                    fieldKey: updatedParent.fieldKey,
                    configJson: updatedParent.configJson,
                    elementType: updatedParent.elementType
                })
            });
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            await this.loadWorkspace(this.selectedProjectId, this.selectedFormId, this.selectedVersionId, true);
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
                sectionColumn: null,
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

    optimisticPlaceInSection(elementId, sectionId, columnNumber, targetIndex) {
        const section = this.elements.find((item) => item.id === sectionId);
        if (!section) {
            return;
        }

        const dragged = this.elements.find((item) => item.id === elementId);
        if (!dragged) {
            return;
        }

        const updatedDragged = (() => {
            const config = this.parseConfig(dragged.configJson);
            config.sectionColumn = columnNumber;
            return this.decorateBaseElement({
                ...dragged,
                parentElementId: section.elementId,
                sectionColumn: columnNumber,
                configJson: JSON.stringify(config)
            });
        })();

        const siblings = this.elements
            .filter((item) => item.parentElementId === section.elementId && item.id !== elementId)
            .sort((a, b) => (a.orderValue || 0) - (b.orderValue || 0));
        const byColumn = new Map();
        siblings.forEach((item) => {
            const column = Number(item.sectionColumn || 1);
            if (!byColumn.has(column)) {
                byColumn.set(column, []);
            }
            byColumn.get(column).push(item);
        });
        if (!byColumn.has(columnNumber)) {
            byColumn.set(columnNumber, []);
        }
        const targetColumnItems = byColumn.get(columnNumber);
        const originalSameGroup = dragged.parentElementId === section.elementId
            && Number(dragged.sectionColumn || 1) === columnNumber;
        let normalizedTargetIndex = Number.isFinite(targetIndex) ? targetIndex : targetColumnItems.length;
        if (originalSameGroup) {
            const currentIndex = this.elements
                .filter((item) => item.parentElementId === section.elementId && Number(item.sectionColumn || 1) === columnNumber)
                .sort((a, b) => (a.orderValue || 0) - (b.orderValue || 0))
                .findIndex((item) => item.id === elementId);
            if (currentIndex >= 0 && normalizedTargetIndex > currentIndex) {
                normalizedTargetIndex -= 1;
            }
        }
        if (normalizedTargetIndex < 0) {
            normalizedTargetIndex = 0;
        }
        if (normalizedTargetIndex > targetColumnItems.length) {
            normalizedTargetIndex = targetColumnItems.length;
        }
        targetColumnItems.splice(normalizedTargetIndex, 0, updatedDragged);

        const reorderedChildren = [];
        for (let column = 1; column <= 10; column += 1) {
            if (byColumn.has(column)) {
                reorderedChildren.push(...byColumn.get(column));
            }
        }
        const orderById = new Map();
        reorderedChildren.forEach((item, index) => {
            orderById.set(item.id, (index + 1) * 10);
        });

        this.elements = this.elements.map((item) => {
            if (item.id === elementId) {
                return this.decorateBaseElement({
                    ...updatedDragged,
                    orderValue: orderById.get(elementId) || updatedDragged.orderValue || 10
                });
            }
            if (orderById.has(item.id)) {
                return this.decorateBaseElement({
                    ...item,
                    orderValue: orderById.get(item.id)
                });
            }
            return item;
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

    normalizeAllowedExtensions(rawValue) {
        if (!Array.isArray(rawValue)) {
            return [];
        }
        const seen = new Set();
        return rawValue
            .map((value) => String(value || '').trim().toLowerCase().replace(/^\./, ''))
            .filter((value) => value)
            .filter((value) => {
                if (seen.has(value)) {
                    return false;
                }
                seen.add(value);
                return true;
            });
    }

    allowedExtensionsText(rawValue) {
        return this.normalizeAllowedExtensions(rawValue).join(', ');
    }

    parseAllowedExtensionsText(rawText) {
        const seen = new Set();
        return String(rawText || '')
            .split(',')
            .map((value) => value.trim().toLowerCase().replace(/^\./, ''))
            .filter((value) => value)
            .filter((value) => {
                if (seen.has(value)) {
                    return false;
                }
                seen.add(value);
                return true;
            });
    }

    allowedExtensionsToAccept(rawValue) {
        const extensions = this.normalizeAllowedExtensions(rawValue);
        return extensions.map((value) => `.${value}`).join(',');
    }

    parsePositiveInteger(rawValue, fallbackValue) {
        const parsed = Number.parseInt(rawValue, 10);
        return Number.isFinite(parsed) && parsed > 0 ? parsed : fallbackValue;
    }

    mergeSelectedOptions(options, selectedValues) {
        const merged = [...(options || [])];
        const existing = new Set(merged.map((option) => String(option.value || '').toLowerCase()));
        (Array.isArray(selectedValues) ? selectedValues : [selectedValues])
            .map((value) => String(value || '').trim())
            .filter((value) => value)
            .forEach((value) => {
                const key = value.toLowerCase();
                if (!existing.has(key)) {
                    existing.add(key);
                    merged.push({
                        label: value,
                        value
                    });
                }
            });
        return merged;
    }

    normalizeLookupFieldList(rawValue, fallbackFields = ['Name']) {
        const values = Array.isArray(rawValue)
            ? rawValue
            : String(rawValue || '').split(',');
        const seen = new Set();
        const normalized = values
            .map((value) => String(value || '').trim())
            .filter((value) => /^[A-Za-z][A-Za-z0-9_]*(?:__c)?$/.test(value))
            .filter((value) => {
                const key = value.toLowerCase();
                if (seen.has(key)) {
                    return false;
                }
                seen.add(key);
                return true;
            });
        return normalized.length ? normalized : [...fallbackFields];
    }

    ensureEditorRows(values, fallbackValue) {
        const rows = Array.isArray(values) ? values.map((value) => String(value || '').trim()) : [];
        return rows.length ? rows : [fallbackValue || ''];
    }

    ensureSelectedLookupFields(selectedValues, optionList, fallbackFields = ['Name']) {
        const allowed = new Set((optionList || []).map((option) => String(option.value || '').toLowerCase()));
        const values = this.normalizeLookupFieldList(selectedValues, fallbackFields)
            .filter((value) => !allowed.size || allowed.has(String(value).toLowerCase()));
        if (values.length) {
            return values;
        }
        const fallback = this.normalizeLookupFieldList(fallbackFields, []);
        return fallback.find((value) => allowed.has(String(value).toLowerCase()))
            ? fallback.filter((value) => allowed.has(String(value).toLowerCase()))
            : (optionList?.[0]?.value ? [optionList[0].value] : fallback);
    }

    normalizeLookupSetFields(rawValue) {
        if (!Array.isArray(rawValue)) {
            return [];
        }
        const seenTargets = new Set();
        return rawValue
            .map((mapping) => ({
                sourceField: String(mapping?.sourceField || mapping?.source || '').trim(),
                targetFieldKey: String(mapping?.targetFieldKey || mapping?.target || '').trim()
            }))
            .filter((mapping) => {
                if (!mapping.sourceField && !mapping.targetFieldKey) {
                    return false;
                }
                if (mapping.sourceField && !/^[A-Za-z][A-Za-z0-9_]*(?:__c)?$/.test(mapping.sourceField)) {
                    return false;
                }
                if (mapping.targetFieldKey && !/^[A-Za-z][A-Za-z0-9_]*$/.test(mapping.targetFieldKey)) {
                    return false;
                }
                if (!mapping.targetFieldKey) {
                    return true;
                }
                const targetKey = mapping.targetFieldKey.toLowerCase();
                if (seenTargets.has(targetKey)) {
                    return false;
                }
                seenTargets.add(targetKey);
                return true;
            });
    }

    parseLookupFieldsText(rawValue, fallbackFields = ['Name']) {
        return this.normalizeLookupFieldList(rawValue, fallbackFields);
    }

    joinLookupFields(rawValue, fallbackValue = 'Name') {
        if (Array.isArray(rawValue)) {
            const values = rawValue.map((value) => String(value || '').trim()).filter((value) => value);
            return values.length ? values.join(', ') : fallbackValue;
        }
        const value = String(rawValue || '').trim();
        return value || fallbackValue;
    }

    normalizeLocationMode(value) {
        const mode = String(value || '').trim();
        return ['country', 'countryRegion', 'countryCity', 'countryRegionCity'].includes(mode)
            ? mode
            : 'countryRegionCity';
    }

    normalizeLocationLayout(value) {
        return String(value || '').trim() === 'inline' ? 'inline' : 'stacked';
    }

    previewLocationParts(item) {
        const config = this.parseConfig(item?.configJson);
        const mode = this.normalizeLocationMode(config.locationMode);
        return [
            { key: 'country', label: 'Country', show: true },
            { key: 'region', label: 'State/Region', show: mode === 'countryRegion' || mode === 'countryRegionCity' },
            { key: 'city', label: 'City', show: mode === 'countryCity' || mode === 'countryRegionCity' }
        ].filter((part) => part.show);
    }

    previewLocationInputsClass(item) {
        const config = this.parseConfig(item?.configJson);
        return `preview-location-inputs preview-location-inputs--${this.normalizeLocationLayout(config.locationLayout)}`;
    }

    parseLocationCountryCodes(rawValue) {
        const seen = new Set();
        return String(rawValue || '')
            .split(',')
            .map((value) => value.trim().toUpperCase())
            .filter((value) => /^[A-Z]{2}$/.test(value))
            .filter((value) => {
                if (seen.has(value)) {
                    return false;
                }
                seen.add(value);
                return true;
            });
    }

    joinLocationCountryCodes(rawValue) {
        if (!Array.isArray(rawValue)) {
            return '';
        }
        return rawValue
            .map((value) => String(value || '').trim().toUpperCase())
            .filter((value) => /^[A-Z]{2}$/.test(value))
            .join(', ');
    }

    exportFormFileName() {
        const today = new Date().toISOString().slice(0, 10);
        const formKey = this.safeFileNamePart(this.selectedFormKey || this.selectedFormName || this.selectedFormId || 'form');
        return 'TwinaForms_' + formKey + '_' + today + '.json';
    }

    safeFileNamePart(value) {
        return String(value || 'form')
            .trim()
            .replace(/[^a-zA-Z0-9._-]+/g, '-')
            .replace(/^-+|-+$/g, '') || 'form';
    }

    readTextFile(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(String(reader.result || ''));
            reader.onerror = () => reject(reader.error || new Error('Unable to read import file.'));
            reader.readAsText(file);
        });
    }

    downloadTextFile(fileName, text, mimeType) {
        const blob = new Blob([text || ''], { type: mimeType || 'text/plain' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = fileName;
        link.style.display = 'none';
        try {
            document.body.appendChild(link);
            link.click();
        } finally {
            link.remove();
            URL.revokeObjectURL(url);
        }
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
        const parsed = Number(value);
        if (Number.isFinite(parsed)) {
            return `${Math.min(100, Math.max(50, parsed))}%`;
        }
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
        const fallbackDetails = this.stringifyDebugValue(error?.body || error);
        if (fallbackDetails && fallbackDetails !== '{}') {
            return fallbackDetails.length > 500 ? fallbackDetails.substring(0, 500) : fallbackDetails;
        }
        return 'Something went wrong while loading the designer.';
    }

    describeElementSaveError(error, selectedElement) {
        const parts = ['Element save failed'];
        if (selectedElement?.elementType) {
            parts.push(`type=${selectedElement.elementType}`);
        }
        if (selectedElement?.fieldKey) {
            parts.push(`field=${selectedElement.fieldKey}`);
        }
        const normalized = this.normalizeError(error);
        if (normalized) {
            parts.push(`message=${normalized}`);
        }
        const rawBody = this.stringifyDebugValue(error?.body);
        if (rawBody) {
            parts.push(`body=${rawBody}`);
        }
        return parts.join(' | ');
    }

    stringifyDebugValue(value) {
        if (value == null) {
            return '';
        }
        if (typeof value === 'string') {
            return value;
        }
        try {
            return JSON.stringify(value);
        } catch (jsonError) {
            return String(value);
        }
    }

    storeSelectedVersion(versionId) {
        try {
            const safeVersionId = sanitizeSalesforceId(versionId);
            if (safeVersionId) {
                window.localStorage.setItem(DESIGNER_VERSION_KEY, safeVersionId);
            }
        } catch (e) {
            // ignore browser storage failures
        }
    }

    loadStoredVersionId() {
        try {
            return sanitizeSalesforceId(window.localStorage.getItem(DESIGNER_VERSION_KEY));
        } catch (e) {
            return null;
        }
    }

    clearStoredVersion() {
        try {
            window.localStorage.removeItem(DESIGNER_VERSION_KEY);
        } catch (e) {
            // ignore browser storage failures
        }
    }

    storeSelectedForm(formId) {
        try {
            const safeFormId = sanitizeSalesforceId(formId);
            if (safeFormId) {
                window.localStorage.setItem(DESIGNER_FORM_KEY, safeFormId);
            }
        } catch (e) {
            // ignore browser storage failures
        }
    }

    loadStoredFormId() {
        try {
            return sanitizeSalesforceId(window.localStorage.getItem(DESIGNER_FORM_KEY));
        } catch (e) {
            return null;
        }
    }

    clearStoredForm() {
        try {
            window.localStorage.removeItem(DESIGNER_FORM_KEY);
        } catch (e) {
            // ignore browser storage failures
        }
    }

    loadStoredFormSortMode() {
        try {
            const storedValue = window.localStorage?.getItem(DESIGNER_FORM_SORT_KEY);
            return ['nameAsc', 'nameDesc', 'numberAsc', 'numberDesc'].includes(storedValue) ? storedValue : 'nameAsc';
        } catch (error) {
            return 'nameAsc';
        }
    }

    storeFormSortMode(sortMode) {
        try {
            window.localStorage?.setItem(DESIGNER_FORM_SORT_KEY, sortMode);
        } catch (error) {
            // Ignore browser storage failures.
        }
    }
    storeSelectedProject(projectId) {
        try {
            const safeProjectId = sanitizeSalesforceId(projectId);
            if (safeProjectId) {
                window.localStorage.setItem(DESIGNER_PROJECT_KEY, safeProjectId);
            }
        } catch (e) {
            // ignore browser storage failures
        }
    }

    loadStoredProjectId() {
        try {
            return sanitizeSalesforceId(window.localStorage.getItem(DESIGNER_PROJECT_KEY));
        } catch (e) {
            return null;
        }
    }

    clearStoredProject() {
        try {
            window.localStorage.removeItem(DESIGNER_PROJECT_KEY);
        } catch (e) {
            // ignore browser storage failures
        }
    }

    // --- Page Layout to Form: related records as a table -------------------

    get layoutImportRelatedAvailable() {
        return this.layoutImportMode !== 'create' && !!this.layoutImportObjectApiName;
    }

    get layoutImportRelatedFieldsDisabled() {
        return !this.layoutImportRelatedValue;
    }

    get layoutImportShowContactLookup() {
        return this.layoutImportIncludeRelated && this.layoutImportParentShape === 'B';
    }

    get layoutImportShowParentContact() {
        return this.layoutImportIncludeRelated && this.layoutImportParentShape === 'C';
    }

    get layoutImportShowBusinessKey() {
        return this.layoutImportShowParentContact && !!this.layoutImportBusinessKeyField;
    }

    get layoutImportRelatedFieldHelp() {
        const chosen = this.layoutImportRelatedFieldValues.length;
        return `Choose up to 6 fields to show as columns. ${chosen} selected. Only field types that work inside a Records List are listed.`;
    }

    get layoutImportRelatedNotice() {
        if (!this.layoutImportIncludeRelated) {
            return '';
        }
        if (this.layoutImportParentShape === 'none') {
            return 'This object cannot be reached from a verified contact, so related records are not available for it.';
        }
        return 'The table loads up to 20 existing rows, newest first. Visitors can edit rows and add new ones, but not delete them. User Verification is switched on so the signed-in contact can be identified.';
    }

    async handleLayoutImportIncludeRelatedChange(event) {
        this.layoutImportIncludeRelated = event.target.checked === true;
        this.resetRelatedSelections();
        if (!this.layoutImportIncludeRelated || !this.layoutImportObjectApiName) {
            return;
        }
        this.isLoadingRelatedMetadata = true;
        try {
            const [relatedLists, parentMatch] = await Promise.all([
                getRelatedListImportOptions({ objectApiName: this.layoutImportObjectApiName }),
                getRelatedParentMatchOptions({ objectApiName: this.layoutImportObjectApiName })
            ]);
            this.layoutImportRelatedListOptions = (relatedLists || []).map((item) => ({
                label: item.label,
                value: item.value,
                childObjectApiName: item.childObjectApiName,
                parentLookupField: item.parentLookupField,
                childObjectLabelPlural: item.childObjectLabelPlural
            }));
            this.layoutImportParentShape = parentMatch ? parentMatch.shape : 'none';
            this.layoutImportContactLookupOptions = this.toFieldOptions(parentMatch && parentMatch.contactLookupFields);
            this.layoutImportParentContactOptions = this.toFieldOptions(parentMatch && parentMatch.parentContactFields);
            this.layoutImportBusinessKeyOptions = [{ label: 'No business key', value: '' }].concat(
                this.toFieldOptions(parentMatch && parentMatch.businessKeyFields)
            );
            // Auto-pick when there is only one sensible answer, so most imports ask nothing extra.
            if (this.layoutImportContactLookupOptions.length === 1) {
                this.layoutImportContactLookupField = this.layoutImportContactLookupOptions[0].value;
            }
            if (this.layoutImportParentContactOptions.length === 1) {
                this.layoutImportParentContactField = this.layoutImportParentContactOptions[0].value;
            }
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
            this.layoutImportIncludeRelated = false;
        } finally {
            this.isLoadingRelatedMetadata = false;
        }
    }

    toFieldOptions(rawFields) {
        return (rawFields || []).map((item) => ({ label: item.label, value: item.apiName }));
    }

    resetRelatedSelections() {
        this.layoutImportRelatedValue = '';
        this.layoutImportRelatedFieldOptions = [];
        this.layoutImportRelatedFieldValues = [];
        this.layoutImportContactLookupField = '';
        this.layoutImportParentContactField = '';
        this.layoutImportBusinessKeyField = '';
        this.layoutImportBusinessKeyParam = '';
    }

    async handleLayoutImportRelatedListChange(event) {
        this.layoutImportRelatedValue = event.detail.value || '';
        this.layoutImportRelatedFieldValues = [];
        this.layoutImportRelatedFieldOptions = [];
        const selected = this.selectedRelatedListOption;
        if (!selected) {
            return;
        }
        this.isLoadingRelatedMetadata = true;
        try {
            const fields = await getRelatedListFieldOptions({
                childObjectApiName: selected.childObjectApiName,
                parentLookupField: selected.parentLookupField
            });
            this.layoutImportRelatedFieldOptions = (fields || []).map((item) => ({
                label: item.label,
                value: item.apiName
            }));
        } catch (error) {
            this.errorMessage = this.normalizeError(error);
        } finally {
            this.isLoadingRelatedMetadata = false;
        }
    }

    get selectedRelatedListOption() {
        return this.layoutImportRelatedListOptions.find(
            (item) => item.value === this.layoutImportRelatedValue
        );
    }

    handleLayoutImportRelatedFieldsChange(event) {
        const chosen = event.detail.value || [];
        if (chosen.length > 6) {
            this.errorMessage = 'A related records table supports up to 6 fields.';
            return;
        }
        this.errorMessage = '';
        this.layoutImportRelatedFieldValues = chosen;
    }

    handleLayoutImportContactLookupChange(event) {
        this.layoutImportContactLookupField = event.detail.value || '';
    }

    handleLayoutImportParentContactChange(event) {
        this.layoutImportParentContactField = event.detail.value || '';
    }

    handleLayoutImportBusinessKeyChange(event) {
        this.layoutImportBusinessKeyField = event.detail.value || '';
        if (!this.layoutImportBusinessKeyField) {
            this.layoutImportBusinessKeyParam = '';
        }
    }

    handleLayoutImportBusinessKeyParamChange(event) {
        this.layoutImportBusinessKeyParam = (event.target.value || '').trim();
    }

    /** Serialises the picker into the shape parseRelatedListSpec expects, or null when unused. */
    buildRelatedListJson() {
        if (!this.layoutImportIncludeRelated || !this.layoutImportRelatedValue) {
            return null;
        }
        const selected = this.selectedRelatedListOption;
        if (!selected || !this.layoutImportRelatedFieldValues.length) {
            return null;
        }
        let parentMatchMode = 'contact';
        if (this.layoutImportParentShape === 'B') {
            parentMatchMode = 'contactLookup';
        } else if (this.layoutImportParentShape === 'C') {
            parentMatchMode = 'parentLookup';
        }
        return JSON.stringify({
            childObjectApiName: selected.childObjectApiName,
            parentLookupField: selected.parentLookupField,
            listLabel: selected.childObjectLabelPlural,
            fieldApiNames: this.layoutImportRelatedFieldValues,
            parentMatchMode,
            contactLookupField: this.layoutImportContactLookupField,
            parentContactField: this.layoutImportParentContactField,
            businessKeyField: this.layoutImportBusinessKeyField,
            businessKeyParam: this.layoutImportBusinessKeyParam
        });
    }
}
