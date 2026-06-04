public with sharing class NativeFormsDesignerController {
    private static final Integer MAX_INTEGER_VALUE = 2147483647;
    private static final Integer MAX_PAGE_LAYOUT_IMPORT_FIELDS = 50;
    private static final Integer ELEMENT_LABEL_MAX_LENGTH = 255;
    private static final Integer ELEMENT_CONFIG_JSON_MAX_LENGTH = 131072;
    private static final Integer MAX_EMBEDDED_IMAGE_BYTES = 70656;
    @TestVisible private static Map<String, Object> pageLayoutImportMetadataMock;

    public class SelectOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
    }

    private static void sortOptionsByLabel(List<SelectOption> options) {
        if (options == null || options.size() < 2) {
            return;
        }
        Map<String, List<SelectOption>> bucket = new Map<String, List<SelectOption>>();
        List<String> keys = new List<String>();
        for (SelectOption o : options) {
            String key = (o.label == null ? '' : o.label.toLowerCase());
            if (!bucket.containsKey(key)) {
                bucket.put(key, new List<SelectOption>());
                keys.add(key);
            }
            bucket.get(key).add(o);
        }
        keys.sort();
        options.clear();
        for (String k : keys) {
            options.addAll(bucket.get(k));
        }
    }

    public class UploadedImageResult {
        @AuraEnabled public Id contentDocumentId { get; set; }
        @AuraEnabled public Id contentVersionId { get; set; }
        @AuraEnabled public String fileName { get; set; }
        @AuraEnabled public String previewUrl { get; set; }
        @AuraEnabled public String altText { get; set; }
        @AuraEnabled public ElementRecord element { get; set; }
    }

    public class VersionOption {
        @AuraEnabled public Id value { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Boolean isPublished { get; set; }
    }

    public class PrefillAliasDetail {
        @AuraEnabled public String alias { get; set; }
        @AuraEnabled public String actionKey { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public List<SelectOption> fieldOptions { get; set; }
    }

    public class SubmitActionDetail {
        @AuraEnabled public Integer displayNumber { get; set; }
        @AuraEnabled public String actionKey { get; set; }
        @AuraEnabled public String storeResultAs { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String commandType { get; set; }
        @AuraEnabled public List<SelectOption> fieldOptions { get; set; }
    }

    public class ThemeRecord {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String logoUrl { get; set; }
        @AuraEnabled public Decimal logoSizePx { get; set; }
        @AuraEnabled public String logoPosition { get; set; }
        @AuraEnabled public String formWidth { get; set; }
        @AuraEnabled public String backgroundColor { get; set; }
        @AuraEnabled public String formBackgroundColor { get; set; }
        @AuraEnabled public String formBorderColor { get; set; }
        @AuraEnabled public String titleFont { get; set; }
        @AuraEnabled public Decimal titleFontSizePx { get; set; }
        @AuraEnabled public String titleTextColor { get; set; }
        @AuraEnabled public String sectionTitleFont { get; set; }
        @AuraEnabled public Decimal sectionTitleFontSizePx { get; set; }
        @AuraEnabled public String sectionTitleTextColor { get; set; }
        @AuraEnabled public String mainFont { get; set; }
        @AuraEnabled public Decimal mainTextSizePx { get; set; }
        @AuraEnabled public String mainTextColor { get; set; }
        @AuraEnabled public String hintTextColor { get; set; }
        @AuraEnabled public Decimal inputBorderRadiusPx { get; set; }
        @AuraEnabled public String inputBackgroundColor { get; set; }
        @AuraEnabled public String inputBorderColor { get; set; }
        @AuraEnabled public String buttonFont { get; set; }
        @AuraEnabled public Decimal buttonFontSizePx { get; set; }
        @AuraEnabled public String buttonTextColor { get; set; }
        @AuraEnabled public String buttonBackgroundColor { get; set; }
    }

    public class ElementRecord {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String elementId { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String elementType { get; set; }
        @AuraEnabled public String fieldKey { get; set; }
        @AuraEnabled public Integer elementIndex { get; set; }
        @AuraEnabled public String configJson { get; set; }
        @AuraEnabled public String parentElementId { get; set; }
        @AuraEnabled public Integer sectionColumn { get; set; }
        @AuraEnabled public Integer orderValue { get; set; }
    }

    public class ElementSnapshotRecord {
        @AuraEnabled public String elementId { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String elementType { get; set; }
        @AuraEnabled public String fieldKey { get; set; }
        @AuraEnabled public Integer elementIndex { get; set; }
        @AuraEnabled public String configJson { get; set; }
        @AuraEnabled public String parentElementId { get; set; }
        @AuraEnabled public Integer orderValue { get; set; }
    }

    public class DesignerWorkspace {
        @AuraEnabled public Id selectedProjectId { get; set; }
        @AuraEnabled public Id selectedFormId { get; set; }
        @AuraEnabled public Id selectedVersionId { get; set; }
        @AuraEnabled public Id selectedThemeId { get; set; }
        @AuraEnabled public String selectedProjectName { get; set; }
        @AuraEnabled public String selectedFormName { get; set; }
        @AuraEnabled public String selectedFormKey { get; set; }
        @AuraEnabled public String selectedFormDescription { get; set; }
        @AuraEnabled public Boolean selectedFormCaptchaEnabled { get; set; }
        @AuraEnabled public Boolean captchaKeysConfigured { get; set; }
        @AuraEnabled public String selectedVersionName { get; set; }
        @AuraEnabled public String selectedVersionStatus { get; set; }
        @AuraEnabled public String selectedVersionLanguageCode { get; set; }
        @AuraEnabled public String selectedVersionSubmitSuccessMessage { get; set; }
        @AuraEnabled public String selectedVersionSubmitLabel { get; set; }
        @AuraEnabled public Boolean selectedVersionRtlEnabled { get; set; }
        @AuraEnabled public Boolean selectedVersionPostSubmitAutoLinkEnabled { get; set; }
        @AuraEnabled public String selectedVersionPostSubmitUrlMode { get; set; }
        @AuraEnabled public String selectedVersionPostSubmitUrlTemplate { get; set; }
        @AuraEnabled public String selectedVersionPostSubmitUrlFormula { get; set; }
        @AuraEnabled public String selectedVersionPostSubmitButtonLabel { get; set; }
        @AuraEnabled public Integer selectedVersionPostSubmitDelaySeconds { get; set; }
        @AuraEnabled public Boolean selectedVersionUserVerificationEnabled { get; set; }
        @AuraEnabled public String selectedVersionUserVerificationMatchField { get; set; }
        @AuraEnabled public String selectedVersionUserVerificationIntroText { get; set; }
        @AuraEnabled public String selectedVersionUserVerificationSentMessage { get; set; }
        @AuraEnabled public String selectedVersionUserVerificationInvalidMessage { get; set; }
        @AuraEnabled public String selectedVersionUserVerificationVerifiedMessage { get; set; }
        @AuraEnabled public String selectedVersionUserVerificationSendButtonLabel { get; set; }
        @AuraEnabled public String selectedVersionUserVerificationVerifyButtonLabel { get; set; }
        @AuraEnabled public String selectedVersionUserVerificationResendButtonLabel { get; set; }
        @AuraEnabled public Integer selectedVersionUserVerificationExpiryMinutes { get; set; }
        @AuraEnabled public Integer selectedVersionUserVerificationMaxAttempts { get; set; }
        @AuraEnabled public Boolean selectedVersionUserVerificationAllowResend { get; set; }
        @AuraEnabled public String selectedVersionUserVerificationSessionMode { get; set; }
        @AuraEnabled public Boolean selectedVersionSubmitConditionalEnabled { get; set; }
        @AuraEnabled public String selectedVersionSubmitConditionalFieldKey { get; set; }
        @AuraEnabled public String selectedVersionSubmitConditionalOperator { get; set; }
        @AuraEnabled public String selectedVersionSubmitConditionalValue { get; set; }
        @AuraEnabled public String selectedVersionSubmitConditionalConditionsJson { get; set; }
        @AuraEnabled public String selectedVersionSubmitConditionalExpression { get; set; }
        @AuraEnabled public Boolean selectedVersionSubmissionPdfEnabled { get; set; }
        @AuraEnabled public Boolean selectedVersionSubmissionPdfAttachToRecord { get; set; }
        @AuraEnabled public String selectedVersionSubmissionPdfTargetSubmitActionKey { get; set; }
        @AuraEnabled public String selectedVersionSubmissionPdfTitle { get; set; }
        @AuraEnabled public Boolean selectedVersionSubmissionPdfIncludeEmptyFields { get; set; }
        @AuraEnabled public String selectedVersionCustomJs { get; set; }
        @AuraEnabled public String selectedPublishedUrl { get; set; }
        @AuraEnabled public List<SelectOption> projects { get; set; }
        @AuraEnabled public List<SelectOption> forms { get; set; }
        @AuraEnabled public List<SelectOption> publishedButtonTargets { get; set; }
        @AuraEnabled public List<VersionOption> versions { get; set; }
        @AuraEnabled public List<SelectOption> themes { get; set; }
        @AuraEnabled public ThemeRecord selectedTheme { get; set; }
        @AuraEnabled public List<ElementRecord> elements { get; set; }
        @AuraEnabled public List<PrefillAliasDetail> prefillAliases { get; set; }
        @AuraEnabled public List<SubmitActionDetail> submitActions { get; set; }
        @AuraEnabled public Boolean enableProConditionLogic { get; set; }
        @AuraEnabled public Boolean enableProRepeatGroups { get; set; }
        @AuraEnabled public Boolean enableProLoadFile { get; set; }
        @AuraEnabled public Boolean enableProElectronicSignature { get; set; }
        @AuraEnabled public Boolean enableProSubmissionPdf { get; set; }
        @AuraEnabled public Boolean enableProMergedDocument { get; set; }
        @AuraEnabled public Boolean enableProSurveyFields { get; set; }
        @AuraEnabled public Boolean enableProLocationFields { get; set; }
        @AuraEnabled public Boolean enableProFormulaFields { get; set; }
        @AuraEnabled public Boolean enableProPostSubmitAutoLink { get; set; }
        @AuraEnabled public Boolean enableProUserVerification { get; set; }
        @AuraEnabled public Boolean enableProAdvancedSubmitModes { get; set; }
        @AuraEnabled public Boolean enableProPageLayoutClone { get; set; }
        @AuraEnabled public Boolean enableProCustomJs { get; set; }
        @AuraEnabled public Boolean enableProButtonElements { get; set; }
        @AuraEnabled public Integer currentFormCount { get; set; }
        @AuraEnabled public Integer maxForms { get; set; }
        @AuraEnabled public Boolean formLimitReached { get; set; }
        @AuraEnabled public String formLimitMessage { get; set; }
        @AuraEnabled public String upgradeUrl { get; set; }
    }

    public class NewFormResult {
        @AuraEnabled public Id projectId { get; set; }
        @AuraEnabled public Id formId { get; set; }
        @AuraEnabled public Id versionId { get; set; }
        @AuraEnabled public String formName { get; set; }
        @AuraEnabled public Integer importedFieldCount { get; set; }
        @AuraEnabled public Integer skippedFieldCount { get; set; }
        @AuraEnabled public List<String> warnings { get; set; }
        @AuraEnabled public String importDiagnosticsJson { get; set; }
    }

    public class PageLayoutImportPreview {
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String objectLabel { get; set; }
        @AuraEnabled public String layoutKey { get; set; }
        @AuraEnabled public String layoutLabel { get; set; }
        @AuraEnabled public String mode { get; set; }
        @AuraEnabled public Integer supportedFieldCount { get; set; }
        @AuraEnabled public Integer skippedFieldCount { get; set; }
        @AuraEnabled public Integer createOnlyFieldCount { get; set; }
        @AuraEnabled public List<String> warnings { get; set; }
    }

    private class PageLayoutImportPlan {
        String objectApiName;
        String objectLabel;
        String layoutKey;
        String layoutLabel;
        String mode;
        String languageCode;
        Integer skippedFieldCount = 0;
        Integer createOnlyFieldCount = 0;
        List<String> warnings = new List<String>();
        List<Map<String, Object>> includedNotes = new List<Map<String, Object>>();
        List<Map<String, Object>> skippedDetails = new List<Map<String, Object>>();
        List<PageLayoutImportField> fields = new List<PageLayoutImportField>();
        List<PageLayoutImportSection> sections = new List<PageLayoutImportSection>();
    }

    private class PageLayoutImportSection {
        String heading;
        List<PageLayoutImportField> fields = new List<PageLayoutImportField>();
    }

    private class PageLayoutImportField {
        String apiName;
        String label;
        String elementType;
        String lookupTargetObject;
        String submitWhen;
        Boolean createOnly;
        Boolean required;
        List<Object> options;
    }

    private static Id normalizeProjectSelection(Id requestedProjectId) {
        Id defaultProjectId = NativeFormsProjectService.ensureDefaultProjectAndBackfillForms();
        if (requestedProjectId == null) {
            return defaultProjectId;
        }
        List<NF_Project__c> matchingProjects = [
            SELECT Id
            FROM NF_Project__c
            WHERE Id = :requestedProjectId
            WITH USER_MODE LIMIT 1
        ];
        return matchingProjects.isEmpty() ? defaultProjectId : matchingProjects[0].Id;
    }

    private class FormLimitState {
        Integer currentFormCount;
        Integer maxForms;
        Boolean limitReached;
        String message;
        String upgradeUrl;
    }

    private static FormLimitState buildFormLimitState() {
        FormLimitState state = new FormLimitState();
        state.currentFormCount = [SELECT COUNT() FROM NF_Form__c WITH USER_MODE];
        state.maxForms = null;
        state.limitReached = false;
        state.message = null;
        state.upgradeUrl = buildUpgradeUrl(null);

        NativeFormsTenantEntitlements.EntitlementSnapshot snapshot = NativeFormsTenantEntitlements.getCurrentOrgEntitlements();
        if (snapshot == null || snapshot.loadedSuccessfully != true) {
            return state;
        }

        state.maxForms = integerLimitValue(snapshot.effectiveLimits, 'maxForms');
        state.upgradeUrl = buildUpgradeUrl(snapshot.planCode);
        if (state.maxForms != null && state.currentFormCount >= state.maxForms) {
            state.limitReached = true;
            state.message = formLimitReachedMessage();
        }
        return state;
    }

    private static void enforceFormCreationLimit() {
        FormLimitState state = buildFormLimitState();
        if (state.limitReached == true) {
            throw new AuraHandledException(state.message);
        }
    }

    private static String formLimitReachedMessage() {
        return 'You have reached your plan limit for forms. Upgrade your plan or remove an existing form before creating a new one.';
    }

    private static String buildUpgradeUrl(String planCode) {
        String normalizedPlan = String.isBlank(planCode) ? 'trial' : planCode.trim().toLowerCase();
        return 'https://twinaforms.com/upgrade?source=salesforce-designer&plan='
            + EncodingUtil.urlEncode(normalizedPlan, 'UTF-8');
    }

    private static Integer integerLimitValue(Map<String, Object> source, String key) {
        if (source == null || String.isBlank(key) || !source.containsKey(key) || source.get(key) == null) {
            return null;
        }
        Object rawValue = source.get(key);
        if (rawValue instanceof Integer) {
            return (Integer) rawValue;
        }
        if (rawValue instanceof Long) {
            Long longValue = (Long) rawValue;
            return longValue > MAX_INTEGER_VALUE ? MAX_INTEGER_VALUE : Integer.valueOf(String.valueOf(longValue));
        }
        if (rawValue instanceof Decimal) {
            return ((Decimal) rawValue).intValue();
        }
        String textValue = String.valueOf(rawValue).trim();
        if (String.isBlank(textValue) || textValue.toLowerCase() == 'null' || textValue.toLowerCase() == 'unlimited') {
            return null;
        }
        try {
            return Decimal.valueOf(textValue).intValue();
        } catch (Exception e) {
            return null;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<SelectOption> getObjectOptions() {
        List<SelectOption> options = new List<SelectOption>();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        List<String> apiNames = new List<String>();

        for (String apiName : globalDescribe.keySet()) {
            Schema.DescribeSObjectResult describeResult = globalDescribe.get(apiName).getDescribe();
            if (!describeResult.isAccessible() || !describeResult.isQueryable()) {
                continue;
            }
            apiNames.add(apiName);
        }

        for (String apiName : apiNames) {
            Schema.DescribeSObjectResult describeResult = globalDescribe.get(apiName).getDescribe();
            SelectOption option = new SelectOption();
            option.label = describeResult.getLabel() + ' (' + describeResult.getName() + ')';
            option.value = describeResult.getName();
            options.add(option);
        }
        sortOptionsByLabel(options);
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<SelectOption> getPicklistFieldOptions(String objectApiName, String fieldType) {
        List<SelectOption> options = new List<SelectOption>();
        if (String.isBlank(objectApiName)) {
            return options;
        }

        String canonicalObjectName = canonicalObjectName(objectApiName);
        if (String.isBlank(canonicalObjectName)) {
            return options;
        }

        Schema.DisplayType requiredType = String.valueOf(fieldType).equalsIgnoreCase('MultiPicklist')
            ? Schema.DisplayType.MultiPicklist
            : Schema.DisplayType.Picklist;
        Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get(canonicalObjectName).getDescribe().fields.getMap();
        List<String> fieldApiNames = new List<String>();
        for (String fieldApiName : fieldsMap.keySet()) {
            Schema.DescribeFieldResult describeResult = fieldsMap.get(fieldApiName).getDescribe();
            if (!describeResult.isAccessible()) {
                continue;
            }
            if (describeResult.getType() != requiredType) {
                continue;
            }
            fieldApiNames.add(fieldApiName);
        }

        for (String fieldApiName : fieldApiNames) {
            Schema.DescribeFieldResult describeResult = fieldsMap.get(fieldApiName).getDescribe();
            SelectOption option = new SelectOption();
            option.label = describeResult.getLabel() + ' (' + describeResult.getName() + ')';
            option.value = describeResult.getName();
            options.add(option);
        }
        sortOptionsByLabel(options);
        return options;
    }
    @AuraEnabled(cacheable=true)
    public static List<SelectOption> getPicklistValueOptions(String objectApiName, String fieldApiName) {
        List<SelectOption> options = new List<SelectOption>();
        if (String.isBlank(objectApiName) || String.isBlank(fieldApiName)) {
            return options;
        }

        String canonicalObjectName = canonicalObjectName(objectApiName);
        if (String.isBlank(canonicalObjectName)) {
            return options;
        }

        Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get(canonicalObjectName).getDescribe().fields.getMap();
        String canonicalFieldName = canonicalFieldName(fieldsMap, fieldApiName);
        if (String.isBlank(canonicalFieldName)) {
            return options;
        }

        Schema.DescribeFieldResult describeResult = fieldsMap.get(canonicalFieldName).getDescribe();
        if (describeResult.getType() != Schema.DisplayType.Picklist
            && describeResult.getType() != Schema.DisplayType.MultiPicklist) {
            return options;
        }

        for (Schema.PicklistEntry entry : describeResult.getPicklistValues()) {
            SelectOption option = new SelectOption();
            option.label = entry.getLabel();
            option.value = entry.getValue();
            options.add(option);
        }
        return options;
    }

    @AuraEnabled
    public static DesignerWorkspace getWorkspace(Id projectId, Id formId, Id versionId) {
        DesignerWorkspace workspace = new DesignerWorkspace();
        workspace.projects = new List<SelectOption>();
        workspace.forms = new List<SelectOption>();
        workspace.publishedButtonTargets = new List<SelectOption>();
        workspace.versions = new List<VersionOption>();
        workspace.themes = new List<SelectOption>();
        workspace.elements = new List<ElementRecord>();
        workspace.prefillAliases = new List<PrefillAliasDetail>();
        workspace.submitActions = new List<SubmitActionDetail>();
        workspace.enableProConditionLogic = NativeFormsFeatureFlags.isProConditionLogicEnabled();
        workspace.enableProRepeatGroups = NativeFormsFeatureFlags.isProRepeatGroupsEnabled();
        workspace.enableProLoadFile = NativeFormsFeatureFlags.isProLoadFileEnabled();
        workspace.enableProElectronicSignature = NativeFormsFeatureFlags.isProElectronicSignatureEnabled();
        workspace.enableProSubmissionPdf = NativeFormsFeatureFlags.isProSubmissionPdfEnabled();
        workspace.enableProMergedDocument = NativeFormsFeatureFlags.isProMergedDocumentEnabled();
        workspace.enableProSurveyFields = NativeFormsFeatureFlags.isProSurveyFieldsEnabled();
        workspace.enableProLocationFields = NativeFormsFeatureFlags.isProLocationFieldsEnabled();
        workspace.enableProFormulaFields = NativeFormsFeatureFlags.isProFormulaFieldsEnabled();
        workspace.enableProPostSubmitAutoLink = NativeFormsFeatureFlags.isProPostSubmitAutoLinkEnabled();
        workspace.enableProUserVerification = NativeFormsFeatureFlags.isProSfUserVerificationAuthEnabled();
        workspace.enableProAdvancedSubmitModes = NativeFormsFeatureFlags.isProAdvancedSubmitModesEnabled();
        workspace.enableProPageLayoutClone = NativeFormsFeatureFlags.isProPageLayoutCloneEnabled();
        workspace.enableProCustomJs = NativeFormsFeatureFlags.isProCustomJsEnabled();
        workspace.enableProButtonElements = NativeFormsFeatureFlags.isProButtonElementsEnabled();
        FormLimitState formLimitState = buildFormLimitState();
        workspace.currentFormCount = formLimitState.currentFormCount;
        workspace.maxForms = formLimitState.maxForms;
        workspace.formLimitReached = formLimitState.limitReached;
        workspace.formLimitMessage = formLimitState.message;
        workspace.upgradeUrl = formLimitState.upgradeUrl;

        Id effectiveProjectId = normalizeProjectSelection(projectId);
        workspace.captchaKeysConfigured = NativeFormsPublisher.hasSharedCaptchaSiteKey();

        List<NF_Project__c> projectRecords = [
            SELECT Id, Name
            FROM NF_Project__c
            WITH USER_MODE ORDER BY Name ASC
            LIMIT 500
        ];
        Map<Id, NF_Project__c> projectsById = new Map<Id, NF_Project__c>(projectRecords);
        if (!projectsById.containsKey(effectiveProjectId)) {
            effectiveProjectId = NativeFormsProjectService.ensureDefaultProjectId();
        }
        workspace.selectedProjectId = effectiveProjectId;
        workspace.selectedProjectName = projectsById.containsKey(effectiveProjectId)
            ? projectsById.get(effectiveProjectId).Name
            : NativeFormsProjectService.DEFAULT_PROJECT_NAME;
        for (NF_Project__c projectRecord : projectRecords) {
            SelectOption option = new SelectOption();
            option.label = projectRecord.Name;
            option.value = (String) projectRecord.Id;
            workspace.projects.add(option);
        }
        sortOptionsByLabel(workspace.projects);

        List<NF_Form__c> forms = [
            SELECT Id, Name, NF_Key__c, Description__c, Status__c, Current_Published_Version__c, Theme__c,
                   Enable_Captcha__c, Project__c, Project__r.Name
            FROM NF_Form__c
            WHERE Project__c = :effectiveProjectId
            WITH USER_MODE ORDER BY Name ASC
            LIMIT 200
        ];

        for (NF_Form__c formRecord : forms) {
            SelectOption option = new SelectOption();
            option.label = formRecord.Description__c + (String.isNotBlank(formRecord.NF_Key__c) ? ' (' + formRecord.NF_Key__c + ')' : '');
            option.value = (String) formRecord.Id;
            workspace.forms.add(option);
        }
        sortOptionsByLabel(workspace.forms);

        for (NF_Form__c targetForm : [
            SELECT Id, NF_Key__c, Description__c
            FROM NF_Form__c
            WHERE Current_Published_Version__c != null
              AND NF_Key__c != null
            WITH USER_MODE
            LIMIT 200
        ]) {
            SelectOption targetOption = new SelectOption();
            targetOption.label = targetForm.Description__c + ' (' + targetForm.NF_Key__c + ')';
            targetOption.value = (String) targetForm.Id;
            workspace.publishedButtonTargets.add(targetOption);
        }
        sortOptionsByLabel(workspace.publishedButtonTargets);

        Map<Id, NF_Form__c> formsById = new Map<Id, NF_Form__c>(forms);

        Id effectiveFormId = formId;
        if (effectiveFormId != null && !formsById.containsKey(effectiveFormId)) {
            effectiveFormId = null;
        }
        if (effectiveFormId == null && !forms.isEmpty()) {
            effectiveFormId = forms[0].Id;
        }
        if (effectiveFormId == null) {
            return workspace;
        }

        NF_Form__c selectedForm = formsById.get(effectiveFormId);
        workspace.selectedProjectId = selectedForm.Project__c;
        workspace.selectedProjectName = selectedForm.Project__r == null ? workspace.selectedProjectName : selectedForm.Project__r.Name;
        workspace.selectedFormId = selectedForm.Id;
        workspace.selectedFormName = selectedForm.Description__c;
        workspace.selectedFormKey = selectedForm.NF_Key__c;
        workspace.selectedFormDescription = selectedForm.Description__c;
        workspace.selectedThemeId = selectedForm.Theme__c;
        workspace.selectedFormCaptchaEnabled = selectedForm.Enable_Captcha__c;

        for (NF_Theme__c themeRecord : [
            SELECT Id, Name
            FROM NF_Theme__c
            WITH USER_MODE ORDER BY Name ASC
            LIMIT 200
        ]) {
            SelectOption option = new SelectOption();
            option.label = themeRecord.Name;
            option.value = (String) themeRecord.Id;
            workspace.themes.add(option);
        }

        if (selectedForm.Theme__c != null) {
            workspace.selectedTheme = toThemeRecord([
                SELECT Id, Name, Logo_URL__c, Logo_Size_Px__c, Logo_Position__c,
                       Form_Width__c, Background_Color__c, Form_Background_Color__c, Form_Border_Color__c,
                       Title_Font__c, Title_Font_Size_Px__c, Title_Text_Color__c,
                       Section_Title_Font__c, Section_Title_Font_Size_Px__c, Section_Title_Text_Color__c,
                       Main_Font__c, Main_Text_Size_Px__c, Main_Text_Color__c, Hint_Text_Color__c,
                       Input_Border_Radius_Px__c, Input_Background_Color__c, Input_Border_Color__c,
                       Button_Font__c, Button_Font_Size_Px__c, Button_Text_Color__c, Button_Background_Color__c
                FROM NF_Theme__c
                WHERE Id = :selectedForm.Theme__c
                WITH USER_MODE LIMIT 1
            ]);
        }

        List<NF_Form_Version__c> versionRecords = [
            SELECT Id, Name, Version_Number__c, Version_Status__c, Publish_Status__c, LastModifiedDate, UI_Settings_JSON__c, Custom_JS__c
            FROM NF_Form_Version__c
            WHERE Form__c = :effectiveFormId
            WITH USER_MODE ORDER BY LastModifiedDate DESC
            LIMIT 200
        ];

        versionRecords.sort(new VersionSorter(selectedForm.Current_Published_Version__c));
        for (NF_Form_Version__c versionRecord : versionRecords) {
            VersionOption option = new VersionOption();
            option.value = versionRecord.Id;
            option.label = formatVersionDisplay(versionRecord.Version_Number__c, versionRecord.Name);
            option.status = versionRecord.Version_Status__c;
            option.isPublished = selectedForm.Current_Published_Version__c == versionRecord.Id || versionRecord.Publish_Status__c == 'Published';
            workspace.versions.add(option);
        }

        Map<Id, NF_Form_Version__c> versionsById = new Map<Id, NF_Form_Version__c>(versionRecords);

        Id effectiveVersionId = versionId;
        if (effectiveVersionId != null && !versionsById.containsKey(effectiveVersionId)) {
            effectiveVersionId = null;
        }
        if (effectiveVersionId == null) {
            if (selectedForm.Current_Published_Version__c != null) {
                effectiveVersionId = selectedForm.Current_Published_Version__c;
                if (!versionsById.containsKey(effectiveVersionId)) {
                    effectiveVersionId = null;
                }
            } else if (!versionRecords.isEmpty()) {
                effectiveVersionId = versionRecords[0].Id;
            }
        }
        if (effectiveVersionId == null) {
            return workspace;
        }

        NF_Form_Version__c selectedVersion = versionsById.get(effectiveVersionId);
        workspace.selectedVersionId = selectedVersion.Id;
        workspace.selectedVersionName = formatVersionDisplay(selectedVersion.Version_Number__c, selectedVersion.Name);
        workspace.selectedVersionStatus = selectedVersion.Version_Status__c;
        Map<String, Object> versionUiSettings = parseJsonMap(selectedVersion.UI_Settings_JSON__c);
        workspace.selectedVersionLanguageCode = defaultLanguageCode(
            stringValue(versionUiSettings.get('languageCode'))
        );
        workspace.selectedVersionSubmitSuccessMessage = defaultSubmitSuccessMessage(
            stringValue(versionUiSettings.get('submitSuccessMessage')),
            workspace.selectedVersionLanguageCode
        );
        workspace.selectedVersionSubmitLabel = defaultSubmitLabel(
            stringValue(versionUiSettings.get('submitLabel')),
            workspace.selectedVersionLanguageCode
        );
        workspace.selectedVersionRtlEnabled = booleanValue(versionUiSettings.get('rtlEnabled'));
        workspace.selectedVersionPostSubmitAutoLinkEnabled = booleanValue(versionUiSettings.get('postSubmitAutoLinkEnabled'));
        workspace.selectedVersionPostSubmitUrlMode = defaultPostSubmitUrlMode(
            stringValue(versionUiSettings.get('postSubmitUrlMode'))
        );
        workspace.selectedVersionPostSubmitUrlTemplate = defaultPostSubmitUrlTemplate(
            stringValue(versionUiSettings.get('postSubmitUrlTemplate'))
        );
        workspace.selectedVersionPostSubmitUrlFormula = stringValue(versionUiSettings.get('postSubmitUrlFormula'));
        workspace.selectedVersionPostSubmitButtonLabel = defaultPostSubmitButtonLabel(
            stringValue(versionUiSettings.get('postSubmitButtonLabel')),
            workspace.selectedVersionLanguageCode
        );
        workspace.selectedVersionPostSubmitDelaySeconds = defaultPostSubmitDelaySeconds(
            versionUiSettings.get('postSubmitDelaySeconds')
        );
        workspace.selectedVersionUserVerificationEnabled = booleanValue(versionUiSettings.get('userVerificationEnabled'));
        workspace.selectedVersionUserVerificationMatchField = defaultUserVerificationMatchField(
            stringValue(versionUiSettings.get('userVerificationMatchField'))
        );
        workspace.selectedVersionUserVerificationIntroText = defaultUserVerificationIntroText(
            stringValue(versionUiSettings.get('userVerificationIntroText')),
            workspace.selectedVersionLanguageCode
        );
        workspace.selectedVersionUserVerificationSentMessage = defaultUserVerificationSentMessage(
            stringValue(versionUiSettings.get('userVerificationSentMessage')),
            workspace.selectedVersionLanguageCode
        );
        workspace.selectedVersionUserVerificationInvalidMessage = defaultUserVerificationInvalidMessage(
            stringValue(versionUiSettings.get('userVerificationInvalidMessage')),
            workspace.selectedVersionLanguageCode
        );
        workspace.selectedVersionUserVerificationVerifiedMessage = defaultUserVerificationVerifiedMessage(
            stringValue(versionUiSettings.get('userVerificationVerifiedMessage')),
            workspace.selectedVersionLanguageCode
        );
        workspace.selectedVersionUserVerificationSendButtonLabel = defaultUserVerificationSendButtonLabel(
            stringValue(versionUiSettings.get('userVerificationSendButtonLabel')),
            workspace.selectedVersionLanguageCode
        );
        workspace.selectedVersionUserVerificationVerifyButtonLabel = defaultUserVerificationVerifyButtonLabel(
            stringValue(versionUiSettings.get('userVerificationVerifyButtonLabel')),
            workspace.selectedVersionLanguageCode
        );
        workspace.selectedVersionUserVerificationResendButtonLabel = defaultUserVerificationResendButtonLabel(
            stringValue(versionUiSettings.get('userVerificationResendButtonLabel')),
            workspace.selectedVersionLanguageCode
        );
        workspace.selectedVersionUserVerificationExpiryMinutes = defaultUserVerificationExpiryMinutes(
            versionUiSettings.get('userVerificationExpiryMinutes')
        );
        workspace.selectedVersionUserVerificationMaxAttempts = defaultUserVerificationMaxAttempts(
            versionUiSettings.get('userVerificationMaxAttempts')
        );
        workspace.selectedVersionUserVerificationAllowResend = defaultUserVerificationAllowResend(
            versionUiSettings.get('userVerificationAllowResend')
        );
        workspace.selectedVersionUserVerificationSessionMode = defaultUserVerificationSessionMode(
            stringValue(versionUiSettings.get('userVerificationSessionMode'))
        );
        workspace.selectedVersionSubmitConditionalEnabled = booleanValue(versionUiSettings.get('submitConditionalEnabled'));
        workspace.selectedVersionSubmitConditionalFieldKey = stringValue(versionUiSettings.get('submitConditionalFieldKey'));
        workspace.selectedVersionSubmitConditionalOperator = defaultConditionalOperator(
            stringValue(versionUiSettings.get('submitConditionalOperator'))
        );
        workspace.selectedVersionSubmitConditionalValue = stringValue(versionUiSettings.get('submitConditionalValue'));
        List<Object> submitConditionalConditions = normalizeConditionalConditions(
            parseJsonList(versionUiSettings.get('submitConditionalConditions')),
            workspace.selectedVersionSubmitConditionalFieldKey,
            workspace.selectedVersionSubmitConditionalOperator,
            workspace.selectedVersionSubmitConditionalValue
        );
        workspace.selectedVersionSubmitConditionalConditionsJson = JSON.serialize(submitConditionalConditions);
        workspace.selectedVersionSubmitConditionalExpression = defaultConditionalExpression(
            stringValue(versionUiSettings.get('submitConditionalExpression')),
            submitConditionalConditions.size()
        );
        workspace.selectedVersionSubmissionPdfEnabled = booleanValue(versionUiSettings.get('submissionPdfEnabled'));
        workspace.selectedVersionSubmissionPdfAttachToRecord = versionUiSettings.containsKey('submissionPdfAttachToRecord')
            ? booleanValue(versionUiSettings.get('submissionPdfAttachToRecord'))
            : true;
        workspace.selectedVersionSubmissionPdfTargetSubmitActionKey = stringValue(versionUiSettings.get('submissionPdfTargetSubmitActionKey'));
        workspace.selectedVersionSubmissionPdfTitle = defaultSubmissionPdfTitle(
            stringValue(versionUiSettings.get('submissionPdfTitle'))
        );
        workspace.selectedVersionSubmissionPdfIncludeEmptyFields = versionUiSettings.containsKey('submissionPdfIncludeEmptyFields')
            ? booleanValue(versionUiSettings.get('submissionPdfIncludeEmptyFields'))
            : true;
        workspace.selectedVersionCustomJs = stringValue(selectedVersion.Custom_JS__c);
        List<NF_Form_Publication__c> publicationRows = [
            SELECT Generated_HTML_Ref__c
            FROM NF_Form_Publication__c
            WHERE Form_Version__c = :effectiveVersionId
              AND Publication_Status__c = 'Success'
              AND Generated_HTML_Ref__c != null
            WITH USER_MODE ORDER BY Published_At__c DESC, CreatedDate DESC
            LIMIT 1
        ];
        workspace.selectedPublishedUrl = publicationRows.isEmpty() ? null : publicationRows[0].Generated_HTML_Ref__c;

        for (NF_Form_Element__c elementRecord : [
            SELECT Id, Element_Id__c, Label__c, Element_Type__c, Field_Key__c, Element_Index__c, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :effectiveVersionId
            WITH USER_MODE ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            workspace.elements.add(toElementRecord(elementRecord));
        }

        for (NF_Form_Action__c actionRecord : [
            SELECT Command_Key__c, Store_Result_As__c, Object_Api_Name__c
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :effectiveVersionId
              AND Action_Scope__c = 'Prefill'
              AND Store_Result_As__c != null
            WITH USER_MODE ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            PrefillAliasDetail detail = new PrefillAliasDetail();
            detail.alias = actionRecord.Store_Result_As__c;
            detail.actionKey = actionRecord.Command_Key__c;
            detail.objectApiName = actionRecord.Object_Api_Name__c;
            detail.fieldOptions = getReadableFieldOptions(actionRecord.Object_Api_Name__c);
            workspace.prefillAliases.add(detail);
        }

        Integer submitActionNumber = 1;
        for (NF_Form_Action__c actionRecord : [
            SELECT Command_Key__c, Store_Result_As__c, Object_Api_Name__c, Command_Type__c
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :effectiveVersionId
              AND Action_Scope__c = 'Submit'
              AND Command_Key__c != null
            WITH USER_MODE ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            SubmitActionDetail detail = new SubmitActionDetail();
            detail.displayNumber = submitActionNumber;
            detail.actionKey = actionRecord.Command_Key__c;
            detail.storeResultAs = actionRecord.Store_Result_As__c;
            detail.objectApiName = actionRecord.Object_Api_Name__c;
            detail.commandType = actionRecord.Command_Type__c;
            detail.fieldOptions = getWritableFieldOptions(actionRecord.Object_Api_Name__c);
            workspace.submitActions.add(detail);
            submitActionNumber += 1;
        }

        return workspace;
    }

    @AuraEnabled
    public static void updateFormSettings(
        Id formId,
        Id versionId,
        String formName,
        Id projectId,
        Id themeId,
        Boolean enableCaptcha,
        String languageCode,
        String submitSuccessMessage,
        Boolean rtlEnabled,
        Boolean postSubmitAutoLinkEnabled,
        String postSubmitUrlTemplate,
        String postSubmitButtonLabel,
        Integer postSubmitDelaySeconds,
        Boolean userVerificationEnabled,
        String userVerificationMatchField,
        String userVerificationIntroText,
        String userVerificationSentMessage,
        String userVerificationInvalidMessage,
        String userVerificationVerifiedMessage,
        String userVerificationSendButtonLabel,
        String userVerificationVerifyButtonLabel,
        String userVerificationResendButtonLabel,
        Integer userVerificationExpiryMinutes,
        Integer userVerificationMaxAttempts,
        Boolean userVerificationAllowResend,
        String submitLabel,
        Boolean submitConditionalEnabled,
        String submitConditionalFieldKey,
        String submitConditionalOperator,
        String submitConditionalValue,
        String submitConditionalConditionsJson,
        String submitConditionalExpression
    ) {
        if (formId == null) {
            throw new AuraHandledException('Form id is required.');
        }
        String normalizedFormName = String.isBlank(formName) ? null : formName.trim();
        if (String.isBlank(normalizedFormName)) {
            throw new AuraHandledException('Form name is required.');
        }

        NF_Form__c formRecord = [
            SELECT Id, Theme__c, Enable_Captcha__c, Description__c, Project__c
            FROM NF_Form__c
            WHERE Id = :formId
            WITH USER_MODE LIMIT 1
        ];
        formRecord.Description__c = normalizedFormName;
        formRecord.Project__c = projectId == null ? NativeFormsProjectService.ensureDefaultProjectId() : projectId;
        formRecord.Theme__c = themeId;
        formRecord.Enable_Captcha__c = enableCaptcha == true;

        List<SObject> recordsToUpdate = new List<SObject>{
            new NF_Form__c(
                Id = formRecord.Id,
                Description__c = formRecord.Description__c,
                Project__c = formRecord.Project__c,
                Theme__c = formRecord.Theme__c,
                Enable_Captcha__c = formRecord.Enable_Captcha__c
            )
        };
        if (versionId != null) {
            NF_Form_Version__c versionRecord = [
                SELECT Id, Form__c, UI_Settings_JSON__c
                FROM NF_Form_Version__c
                WHERE Id = :versionId
                WITH USER_MODE LIMIT 1
            ];
            if (versionRecord.Form__c != formId) {
                throw new AuraHandledException('Selected version does not belong to the selected form.');
            }
            Map<String, Object> uiSettings = parseJsonMap(versionRecord.UI_Settings_JSON__c);
            String normalizedLanguageCode = defaultLanguageCode(languageCode);
            uiSettings.put('languageCode', normalizedLanguageCode);
            uiSettings.put('submitSuccessMessage', defaultSubmitSuccessMessage(submitSuccessMessage, normalizedLanguageCode));
            uiSettings.put('rtlEnabled', rtlEnabled == true);
            uiSettings.put('postSubmitAutoLinkEnabled', postSubmitAutoLinkEnabled == true);
            uiSettings.put('postSubmitUrlTemplate', defaultPostSubmitUrlTemplate(postSubmitUrlTemplate));
            uiSettings.put('postSubmitButtonLabel', defaultPostSubmitButtonLabel(postSubmitButtonLabel, normalizedLanguageCode));
            uiSettings.put('postSubmitDelaySeconds', defaultPostSubmitDelaySeconds(postSubmitDelaySeconds));
            uiSettings.put('userVerificationEnabled', userVerificationEnabled == true);
            uiSettings.put('userVerificationMatchField', defaultUserVerificationMatchField(userVerificationMatchField));
            uiSettings.put('userVerificationIntroText', defaultUserVerificationIntroText(userVerificationIntroText, normalizedLanguageCode));
            uiSettings.put('userVerificationSentMessage', defaultUserVerificationSentMessage(userVerificationSentMessage, normalizedLanguageCode));
            uiSettings.put('userVerificationInvalidMessage', defaultUserVerificationInvalidMessage(userVerificationInvalidMessage, normalizedLanguageCode));
            uiSettings.put('userVerificationVerifiedMessage', defaultUserVerificationVerifiedMessage(userVerificationVerifiedMessage, normalizedLanguageCode));
            uiSettings.put('userVerificationSendButtonLabel', defaultUserVerificationSendButtonLabel(userVerificationSendButtonLabel, normalizedLanguageCode));
            uiSettings.put('userVerificationVerifyButtonLabel', defaultUserVerificationVerifyButtonLabel(userVerificationVerifyButtonLabel, normalizedLanguageCode));
            uiSettings.put('userVerificationResendButtonLabel', defaultUserVerificationResendButtonLabel(userVerificationResendButtonLabel, normalizedLanguageCode));
            uiSettings.put('userVerificationExpiryMinutes', defaultUserVerificationExpiryMinutes(userVerificationExpiryMinutes));
            uiSettings.put('userVerificationMaxAttempts', defaultUserVerificationMaxAttempts(userVerificationMaxAttempts));
            uiSettings.put('userVerificationAllowResend', defaultUserVerificationAllowResend(userVerificationAllowResend));
            uiSettings.put('submitLabel', defaultSubmitLabel(submitLabel, normalizedLanguageCode));
            uiSettings.put('submitConditionalEnabled', submitConditionalEnabled == true);
            uiSettings.put('submitConditionalFieldKey', stringValue(submitConditionalFieldKey));
            uiSettings.put('submitConditionalOperator', defaultConditionalOperator(submitConditionalOperator));
            uiSettings.put('submitConditionalValue', stringValue(submitConditionalValue));
            List<Object> normalizedConditions = normalizeConditionalConditions(
                parseJsonList(submitConditionalConditionsJson),
                submitConditionalFieldKey,
                submitConditionalOperator,
                submitConditionalValue
            );
            uiSettings.put('submitConditionalConditions', normalizedConditions);
            uiSettings.put(
                'submitConditionalExpression',
                defaultConditionalExpression(submitConditionalExpression, normalizedConditions.size())
            );
            versionRecord.UI_Settings_JSON__c = JSON.serializePretty(uiSettings);
            recordsToUpdate.add(new NF_Form_Version__c(
                Id = versionRecord.Id,
                UI_Settings_JSON__c = versionRecord.UI_Settings_JSON__c
            ));
        }

        update as user recordsToUpdate;
    }

    @AuraEnabled
    public static void updateUserVerificationSessionMode(Id formId, Id versionId, String userVerificationSessionMode) {
        if (formId == null || versionId == null) {
            throw new AuraHandledException('Form and version are required.');
        }
        NF_Form_Version__c versionRecord = [
            SELECT Id, Form__c, UI_Settings_JSON__c
            FROM NF_Form_Version__c
            WHERE Id = :versionId
            WITH USER_MODE LIMIT 1
        ];
        if (versionRecord.Form__c != formId) {
            throw new AuraHandledException('Selected version does not belong to the selected form.');
        }
        Map<String, Object> uiSettings = parseJsonMap(versionRecord.UI_Settings_JSON__c);
        uiSettings.put('userVerificationSessionMode', defaultUserVerificationSessionMode(userVerificationSessionMode));
        update as user new NF_Form_Version__c(
            Id = versionRecord.Id,
            UI_Settings_JSON__c = JSON.serializePretty(uiSettings)
        );
    }

    @AuraEnabled
    public static void updateVersionPostSubmitRedirectSettings(
        Id formId,
        Id versionId,
        Boolean enabled,
        String urlMode,
        String urlTemplate,
        String urlFormula,
        String buttonLabel,
        Integer delaySeconds
    ) {
        if (formId == null) {
            throw new AuraHandledException('Form id is required.');
        }
        if (versionId == null) {
            throw new AuraHandledException('Form version is required.');
        }
        if (enabled == true && !NativeFormsFeatureFlags.isProPostSubmitAutoLinkEnabled()) {
            throw new AuraHandledException('Post-submit redirect is available on Pro plans only. Enable it in your AWS plan entitlements first.');
        }

        NF_Form_Version__c versionRecord = [
            SELECT Id, Form__c, UI_Settings_JSON__c
            FROM NF_Form_Version__c
            WHERE Id = :versionId
            WITH USER_MODE LIMIT 1
        ];
        if (versionRecord.Form__c != formId) {
            throw new AuraHandledException('Selected version does not belong to the selected form.');
        }

        Map<String, Object> uiSettings = parseJsonMap(versionRecord.UI_Settings_JSON__c);
        String normalizedLanguageCode = defaultLanguageCode(stringValue(uiSettings.get('languageCode')));
        uiSettings.put('postSubmitAutoLinkEnabled', enabled == true);
        uiSettings.put('postSubmitUrlMode', defaultPostSubmitUrlMode(urlMode));
        uiSettings.put('postSubmitUrlTemplate', defaultPostSubmitUrlTemplate(urlTemplate));
        uiSettings.put('postSubmitUrlFormula', stringValue(urlFormula));
        uiSettings.put('postSubmitButtonLabel', defaultPostSubmitButtonLabel(buttonLabel, normalizedLanguageCode));
        uiSettings.put('postSubmitDelaySeconds', defaultPostSubmitDelaySeconds(delaySeconds));
        versionRecord.UI_Settings_JSON__c = JSON.serializePretty(uiSettings);

        update as user new NF_Form_Version__c(
            Id = versionRecord.Id,
            UI_Settings_JSON__c = versionRecord.UI_Settings_JSON__c
        );
    }

    @AuraEnabled
    public static void updateVersionSubmissionPdfSettings(
        Id formId,
        Id versionId,
        Boolean enabled,
        Boolean attachToRecord,
        String targetSubmitActionKey,
        String title,
        Boolean includeEmptyFields
    ) {
        if (formId == null) {
            throw new AuraHandledException('Form id is required.');
        }
        if (versionId == null) {
            throw new AuraHandledException('Form version is required.');
        }
        Boolean normalizedEnabled = enabled == true;
        if (normalizedEnabled && !NativeFormsFeatureFlags.isProSubmissionPdfEnabled()) {
            throw new AuraHandledException('Submission PDF is available on Pro plans only. Enable it in your AWS plan entitlements first.');
        }
        if (!normalizedEnabled && versionContainsRecordsListSignature(versionId)) {
            throw new AuraHandledException('Submission PDF is required while this form contains a Signature inside a Records List. Remove the row Signature first.');
        }

        NF_Form_Version__c versionRecord = [
            SELECT Id, Form__c, UI_Settings_JSON__c
            FROM NF_Form_Version__c
            WHERE Id = :versionId
            WITH USER_MODE LIMIT 1
        ];
        if (versionRecord.Form__c != formId) {
            throw new AuraHandledException('Selected version does not belong to the selected form.');
        }

        Map<String, Object> uiSettings = parseJsonMap(versionRecord.UI_Settings_JSON__c);
        uiSettings.put('submissionPdfEnabled', normalizedEnabled);
        uiSettings.put('submissionPdfAttachToRecord', attachToRecord != false);
        uiSettings.put('submissionPdfTargetSubmitActionKey', stringValue(targetSubmitActionKey));
        uiSettings.put('submissionPdfTitle', defaultSubmissionPdfTitle(title));
        uiSettings.put('submissionPdfIncludeEmptyFields', includeEmptyFields != false);
        versionRecord.UI_Settings_JSON__c = JSON.serializePretty(uiSettings);

        update as user new NF_Form_Version__c(
            Id = versionRecord.Id,
            UI_Settings_JSON__c = versionRecord.UI_Settings_JSON__c
        );
    }

    @AuraEnabled
    public static void updateVersionCustomJs(Id formId, Id versionId, String customJs) {
        if (formId == null) {
            throw new AuraHandledException('Form id is required.');
        }
        if (versionId == null) {
            throw new AuraHandledException('Form version is required.');
        }
        if (String.isNotBlank(customJs) && !NativeFormsFeatureFlags.isProCustomJsEnabled()) {
            throw new AuraHandledException('Custom JavaScript is available on Pro plans only. Enable it in your AWS plan entitlements first.');
        }

        NF_Form_Version__c versionRecord = [
            SELECT Id, Form__c, Custom_JS__c
            FROM NF_Form_Version__c
            WHERE Id = :versionId
            WITH USER_MODE LIMIT 1
        ];
        if (versionRecord.Form__c != formId) {
            throw new AuraHandledException('Selected version does not belong to the selected form.');
        }

        versionRecord.Custom_JS__c = String.isBlank(customJs) ? null : customJs;
        update as user new NF_Form_Version__c(
            Id = versionRecord.Id,
            Custom_JS__c = versionRecord.Custom_JS__c
        );
    }

    @AuraEnabled
    public static SelectOption createProject(String projectName) {
        Id projectId = NativeFormsProjectService.resolveProjectId(null, projectName);
        NF_Project__c projectRecord = [
            SELECT Id, Name
            FROM NF_Project__c
            WHERE Id = :projectId
            WITH USER_MODE
            LIMIT 1
        ];
        SelectOption option = new SelectOption();
        option.label = projectRecord.Name;
        option.value = (String) projectRecord.Id;
        return option;
    }

    @AuraEnabled
    public static NewFormResult createFormWithDraftVersion(String description, Id projectId, String newProjectName, Id themeId) {
        String normalizedDescription = String.isBlank(description) ? null : description.trim();
        if (String.isBlank(normalizedDescription)) {
            throw new AuraHandledException('Description is required.');
        }
        enforceFormCreationLimit();
        Id effectiveProjectId = NativeFormsProjectService.resolveProjectId(projectId, newProjectName);

        NF_Form__c formRecord = new NF_Form__c(
            Description__c = normalizedDescription,
            Status__c = 'Draft',
            Project__c = effectiveProjectId,
            Theme__c = themeId
        );
        insert as user formRecord;
        NF_Form_Version__c versionRecord = new NF_Form_Version__c(
            Form__c = formRecord.Id,
            Version_Number__c = 1,
            Version_Status__c = 'Draft',
            Publish_Status__c = 'Never Published',
            Security_Mode__c = pickPreferredPicklistValue(
                NF_Form_Version__c.Security_Mode__c,
                new List<String>{ 'secure-edit', 'public-prefill', 'public-create' }
            ),
            Prefill_Params_JSON__c = '[{"key":"email","label":"Email","required":true}]'
        );
        insert as user versionRecord;
        formRecord.Current_Draft_Version__c = versionRecord.Id;
        update as user formRecord;
        NewFormResult result = new NewFormResult();
        result.projectId = effectiveProjectId;
        result.formId = formRecord.Id;
        result.versionId = versionRecord.Id;
        result.formName = normalizedDescription;
        return result;
    }

    @AuraEnabled
    public static List<SelectOption> getPageLayoutImportOptions(String objectApiName, String languageCode) {
        String normalizedLanguageCode = defaultLanguageCode(languageCode);
        String canonicalObject = canonicalObjectName(objectApiName);
        if (String.isBlank(canonicalObject)) {
            throw new AuraHandledException('Select a valid Salesforce object.');
        }

        Map<String, Object> response = fetchPageLayoutMetadata(canonicalObject, null, normalizedLanguageCode);
        List<SelectOption> options = new List<SelectOption>();
        if (response.containsKey('layouts') && response.get('layouts') instanceof List<Object>) {
            for (Object layoutValue : (List<Object>) response.get('layouts')) {
                if (!(layoutValue instanceof Map<String, Object>)) {
                    continue;
                }
                Map<String, Object> layoutMap = (Map<String, Object>) layoutValue;
                String value = stringValue(layoutMap.get('value'));
                if (String.isBlank(value)) {
                    continue;
                }
                SelectOption option = new SelectOption();
                option.label = String.isBlank(stringValue(layoutMap.get('label'))) ? value : stringValue(layoutMap.get('label'));
                option.value = value;
                options.add(option);
            }
        }
        if (options.isEmpty() && response.get('layout') instanceof Map<String, Object>) {
            Map<String, Object> layoutMap = (Map<String, Object>) response.get('layout');
            SelectOption option = new SelectOption();
            option.label = String.isBlank(stringValue(layoutMap.get('layoutLabel'))) ? 'Assigned Salesforce layout' : stringValue(layoutMap.get('layoutLabel'));
            option.value = String.isBlank(stringValue(layoutMap.get('layoutKey'))) ? 'assigned:default' : stringValue(layoutMap.get('layoutKey'));
            options.add(option);
        }
        return options;
    }

    @AuraEnabled
    public static PageLayoutImportPreview previewPageLayoutImport(String objectApiName, String layoutKey, String mode, String languageCode) {
        String normalizedLanguageCode = defaultLanguageCode(languageCode);
        PageLayoutImportPlan plan = buildPageLayoutImportPlan(objectApiName, layoutKey, normalizePageLayoutImportMode(mode), normalizedLanguageCode);
        PageLayoutImportPreview preview = new PageLayoutImportPreview();
        preview.objectApiName = plan.objectApiName;
        preview.objectLabel = plan.objectLabel;
        preview.layoutKey = plan.layoutKey;
        preview.layoutLabel = plan.layoutLabel;
        preview.mode = plan.mode;
        preview.supportedFieldCount = plan.fields.size();
        preview.skippedFieldCount = plan.skippedFieldCount;
        preview.createOnlyFieldCount = plan.createOnlyFieldCount;
        preview.warnings = plan.warnings;
        return preview;
    }

    @AuraEnabled
    public static NewFormResult createFormFromPageLayout(
        String description,
        Id projectId,
        String newProjectName,
        Id themeId,
        String objectApiName,
        String layoutKey,
        String mode,
        String languageCode
    ) {
        String normalizedDescription = String.isBlank(description) ? null : description.trim();
        if (String.isBlank(normalizedDescription)) {
            throw new AuraHandledException('Form name is required.');
        }
        if (String.isBlank(languageCode)) {
            throw new AuraHandledException('Select a language for the new form.');
        }
        String normalizedLanguageCode = defaultLanguageCode(languageCode);
        if (!NativeFormsFeatureFlags.isProPageLayoutCloneEnabled()) {
            throw new AuraHandledException('Page Layout Clone is available on Pro plans only.');
        }
        String normalizedMode = normalizePageLayoutImportMode(mode);
        if (normalizedMode != 'create' && !NativeFormsFeatureFlags.isProAdvancedSubmitModesEnabled()) {
            throw new AuraHandledException('Secure Page Layout Clone requires Advanced Submit Actions on your Pro plan.');
        }

        Boolean secureMode = normalizedMode != 'create';
        if (secureMode && !NativeFormsFeatureFlags.isProSfUserVerificationAuthEnabled()) {
            throw new AuraHandledException('Secure page-layout forms require User Verification with Contact/email matching on your Pro plan.');
        }

        normalizePageLayoutImportLayoutKey(layoutKey);
        enforceFormCreationLimit();
        PageLayoutImportPlan plan = buildPageLayoutImportPlan(objectApiName, layoutKey, normalizedMode, normalizedLanguageCode);
        if (plan.fields.isEmpty()) {
            throw new AuraHandledException('No supported editable fields were found for the selected object.');
        }

        Id effectiveProjectId = NativeFormsProjectService.resolveProjectId(projectId, newProjectName);
        NF_Form__c formRecord = new NF_Form__c(
            Description__c = normalizedDescription,
            Status__c = 'Draft',
            Project__c = effectiveProjectId,
            Theme__c = themeId
        );
        insert as user formRecord;

        NF_Form_Version__c versionRecord = new NF_Form_Version__c(
            Form__c = formRecord.Id,
            Version_Number__c = 1,
            Version_Status__c = 'Draft',
            Publish_Status__c = 'Never Published',
            Security_Mode__c = pickPreferredPicklistValue(
                NF_Form_Version__c.Security_Mode__c,
                secureMode
                    ? new List<String>{ 'secure-edit', 'public-find-update-create', 'public-prefill', 'public-create' }
                    : new List<String>{ 'public-create', 'public-prefill', 'secure-edit' }
            ),
            UI_Settings_JSON__c = buildPageLayoutImportUiSettingsJson(secureMode, normalizedLanguageCode),
            Prefill_Params_JSON__c = secureMode
                ? buildPageLayoutImportPrefillParamsJson(normalizedMode, normalizedLanguageCode)
                : '[]'
        );
        insert as user versionRecord;

        List<NF_Form_Action__c> actions = new List<NF_Form_Action__c>();
        String prefillAlias = pageLayoutImportActionName('Prefill', plan.objectApiName);
        String submitActionKey = pageLayoutImportActionName('Submit', plan.objectApiName);
        if (secureMode) {
            actions.add(new NF_Form_Action__c(
                Form_Version__c = versionRecord.Id,
                Action_Scope__c = 'Prefill',
                Command_Key__c = prefillAlias,
                Command_Type__c = 'findOne',
                Object_Api_Name__c = plan.objectApiName,
                Store_Result_As__c = prefillAlias,
                Order__c = 10,
                Config_JSON__c = JSON.serializePretty(new Map<String, Object>{
                    'conditions' => new List<Object>{
                        new Map<String, Object>{
                            'fieldApiName' => 'Id',
                            'operator' => 'eq',
                            'valueSource' => 'param',
                            'valueText' => 'recordId'
                        }
                    },
                    'conditionLogic' => '1',
                    'conditionExpression' => '1',
                    'onNotFound' => 'ignore'
                })
            ));
        }

        Map<String, Object> submitConfig = new Map<String, Object>();
        String submitCommandType = 'create';
        if (secureMode) {
            submitCommandType = 'updateById';
            submitConfig.put('recordIdSource', '{input.recordId}');
            if (normalizedMode == 'secureUpdateOrCreate') {
                submitConfig.put('onNotFound', 'create');
            }
        }
        actions.add(new NF_Form_Action__c(
            Form_Version__c = versionRecord.Id,
            Action_Scope__c = 'Submit',
            Command_Key__c = submitActionKey,
            Command_Type__c = submitCommandType,
            Object_Api_Name__c = plan.objectApiName,
            Store_Result_As__c = submitActionKey,
            Order__c = secureMode ? 20 : 10,
            Config_JSON__c = JSON.serializePretty(submitConfig)
        ));
        insert as user actions;

        List<NF_Form_Element__c> elements = buildPageLayoutImportElements(
            versionRecord.Id,
            plan,
            secureMode,
            prefillAlias,
            submitActionKey,
            normalizedLanguageCode
        );
        elements = filterStorableImportedElements(elements, plan);
        if (elements.isEmpty()) {
            throw new AuraHandledException('No supported fields could be stored from this Salesforce layout.');
        }
        try {
            insert as user elements;
        } catch (DmlException e) {
            throw new AuraHandledException('TwinaForms could not create the form elements from this Salesforce layout. ' + dmlMessage(e));
        }

        formRecord.Current_Draft_Version__c = versionRecord.Id;
        update as user formRecord;

        NewFormResult result = new NewFormResult();
        result.projectId = effectiveProjectId;
        result.formId = formRecord.Id;
        result.versionId = versionRecord.Id;
        result.formName = normalizedDescription;
        result.importedFieldCount = plan.fields.size();
        result.skippedFieldCount = plan.skippedFieldCount;
        result.warnings = plan.warnings;
        result.importDiagnosticsJson = buildPageLayoutImportDiagnosticsJson(plan);
        return result;
    }

    @AuraEnabled
    public static NewFormResult cloneFormWithDraftVersion(
        Id sourceFormId,
        Id sourceVersionId,
        String description,
        Id projectId,
        String newProjectName
    ) {
        if (sourceFormId == null) {
            throw new AuraHandledException('Select a form to clone first.');
        }
        if (sourceVersionId == null) {
            throw new AuraHandledException('Select a form version to clone first.');
        }
        String normalizedDescription = String.isBlank(description) ? null : description.trim();
        if (String.isBlank(normalizedDescription)) {
            throw new AuraHandledException('Form name is required.');
        }
        enforceFormCreationLimit();
        Id effectiveProjectId = NativeFormsProjectService.resolveProjectId(projectId, newProjectName);

        NF_Form__c sourceForm = [
            SELECT Id, Theme__c, Enable_Captcha__c
            FROM NF_Form__c
            WHERE Id = :sourceFormId
            WITH USER_MODE LIMIT 1
        ];
        NF_Form_Version__c sourceVersion = [
            SELECT Id,
                   Form__c,
                   Security_Mode__c,
                   Rate_Limit_Profile__c,
                   Custom_CSS__c,
                   Custom_JS__c,
                   Theme_JSON__c,
                   UI_Settings_JSON__c,
                   Prefill_Params_JSON__c
            FROM NF_Form_Version__c
            WHERE Id = :sourceVersionId
            WITH USER_MODE LIMIT 1
        ];
        if (sourceVersion.Form__c != sourceForm.Id) {
            throw new AuraHandledException('Selected version does not belong to the selected form.');
        }

        NF_Form__c clonedForm = new NF_Form__c(
            Description__c = normalizedDescription,
            Status__c = 'Draft',
            Project__c = effectiveProjectId,
            Theme__c = sourceForm.Theme__c,
            Enable_Captcha__c = sourceForm.Enable_Captcha__c
        );
        insert as user clonedForm;

        NF_Form_Version__c clonedVersion = new NF_Form_Version__c(
            Form__c = clonedForm.Id,
            Version_Number__c = 1,
            Version_Status__c = 'Draft',
            Publish_Status__c = 'Never Published',
            Security_Mode__c = sourceVersion.Security_Mode__c,
            Rate_Limit_Profile__c = sourceVersion.Rate_Limit_Profile__c,
            Custom_CSS__c = sourceVersion.Custom_CSS__c,
            Custom_JS__c = sourceVersion.Custom_JS__c,
            Theme_JSON__c = sourceVersion.Theme_JSON__c,
            UI_Settings_JSON__c = sourceVersion.UI_Settings_JSON__c,
            Prefill_Params_JSON__c = sourceVersion.Prefill_Params_JSON__c
        );
        insert as user clonedVersion;

        List<NF_Form_Element__c> clonedElements = new List<NF_Form_Element__c>();
        for (NF_Form_Element__c sourceElement : [
            SELECT Element_Id__c,
                   Element_Type__c,
                   Field_Key__c,
                   Element_Index__c,
                   Label__c,
                   Config_JSON__c,
                   Parent_Element_Id__c,
                   Order__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :sourceVersion.Id
            WITH USER_MODE ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            NF_Form_Element__c clonedElement = sourceElement.clone(false, true, false, false);
            clonedElement.Form_Version__c = clonedVersion.Id;
            clonedElements.add(clonedElement);
        }
        if (!clonedElements.isEmpty()) {
            insert as user clonedElements;
        }

        List<NF_Form_Action__c> clonedActions = new List<NF_Form_Action__c>();
        for (NF_Form_Action__c sourceAction : [
            SELECT Action_Scope__c,
                   Command_Key__c,
                   Command_Type__c,
                   Object_Api_Name__c,
                   Store_Result_As__c,
                   Config_JSON__c,
                   Order__c
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :sourceVersion.Id
            WITH USER_MODE ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            NF_Form_Action__c clonedAction = sourceAction.clone(false, true, false, false);
            clonedAction.Form_Version__c = clonedVersion.Id;
            clonedActions.add(clonedAction);
        }
        if (!clonedActions.isEmpty()) {
            insert as user clonedActions;
        }

        update as user new NF_Form__c(
            Id = clonedForm.Id,
            Current_Draft_Version__c = clonedVersion.Id
        );

        NewFormResult result = new NewFormResult();
        result.projectId = effectiveProjectId;
        result.formId = clonedForm.Id;
        result.versionId = clonedVersion.Id;
        result.formName = normalizedDescription;
        return result;
    }

    @AuraEnabled
    public static NewFormResult restoreDraftFromPublished(Id formId, Id sourceVersionId) {
        if (formId == null) {
            throw new AuraHandledException('Select a form to restore first.');
        }
        if (sourceVersionId == null) {
            throw new AuraHandledException('Select a published version to restore from.');
        }

        NF_Form__c formRecord = [
            SELECT Id, Description__c, Project__c
            FROM NF_Form__c
            WHERE Id = :formId
            WITH USER_MODE LIMIT 1
        ];

        NF_Form_Version__c publishedVersion = [
            SELECT Id,
                   Form__c,
                   Version_Status__c,
                   Publish_Status__c,
                   Security_Mode__c,
                   Rate_Limit_Profile__c,
                   Custom_CSS__c,
                   Custom_JS__c,
                   Theme_JSON__c,
                   UI_Settings_JSON__c,
                   Prefill_Params_JSON__c
            FROM NF_Form_Version__c
            WHERE Id = :sourceVersionId
            WITH USER_MODE LIMIT 1
        ];
        if (publishedVersion.Form__c != formRecord.Id) {
            throw new AuraHandledException('The selected version does not belong to the selected form.');
        }
        if (publishedVersion.Version_Status__c != 'Published' && publishedVersion.Publish_Status__c != 'Published') {
            throw new AuraHandledException('Select a published version to restore from.');
        }

        AggregateResult versionAggregate = [
            SELECT MAX(Version_Number__c) maxVersion
            FROM NF_Form_Version__c
            WHERE Form__c = :formRecord.Id
            WITH USER_MODE
        ];
        Decimal maxVersion = (Decimal) versionAggregate.get('maxVersion');
        Integer nextVersionNumber = maxVersion == null ? 1 : maxVersion.intValue() + 1;

        NF_Form_Version__c restoredVersion = new NF_Form_Version__c(
            Form__c = formRecord.Id,
            Version_Number__c = nextVersionNumber,
            Version_Status__c = 'Draft',
            Publish_Status__c = 'Never Published',
            Security_Mode__c = publishedVersion.Security_Mode__c,
            Rate_Limit_Profile__c = publishedVersion.Rate_Limit_Profile__c,
            Custom_CSS__c = publishedVersion.Custom_CSS__c,
            Custom_JS__c = publishedVersion.Custom_JS__c,
            Theme_JSON__c = publishedVersion.Theme_JSON__c,
            UI_Settings_JSON__c = publishedVersion.UI_Settings_JSON__c,
            Prefill_Params_JSON__c = publishedVersion.Prefill_Params_JSON__c
        );
        insert as user restoredVersion;

        List<NF_Form_Element__c> restoredElements = new List<NF_Form_Element__c>();
        for (NF_Form_Element__c sourceElement : [
            SELECT Element_Id__c,
                   Element_Type__c,
                   Field_Key__c,
                   Element_Index__c,
                   Label__c,
                   Config_JSON__c,
                   Parent_Element_Id__c,
                   Order__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :publishedVersion.Id
            WITH USER_MODE ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            NF_Form_Element__c restoredElement = sourceElement.clone(false, true, false, false);
            restoredElement.Form_Version__c = restoredVersion.Id;
            restoredElements.add(restoredElement);
        }
        if (!restoredElements.isEmpty()) {
            insert as user restoredElements;
        }

        List<NF_Form_Action__c> restoredActions = new List<NF_Form_Action__c>();
        for (NF_Form_Action__c sourceAction : [
            SELECT Action_Scope__c,
                   Command_Key__c,
                   Command_Type__c,
                   Object_Api_Name__c,
                   Store_Result_As__c,
                   Config_JSON__c,
                   Order__c
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :publishedVersion.Id
            WITH USER_MODE ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            NF_Form_Action__c restoredAction = sourceAction.clone(false, true, false, false);
            restoredAction.Form_Version__c = restoredVersion.Id;
            restoredActions.add(restoredAction);
        }
        if (!restoredActions.isEmpty()) {
            insert as user restoredActions;
        }

        update as user new NF_Form__c(
            Id = formRecord.Id,
            Status__c = 'Draft',
            Current_Draft_Version__c = restoredVersion.Id
        );

        NewFormResult result = new NewFormResult();
        result.projectId = formRecord.Project__c;
        result.formId = formRecord.Id;
        result.versionId = restoredVersion.Id;
        result.formName = formRecord.Description__c;
        return result;
    }

    @AuraEnabled
    public static void deleteForm(Id formId, String confirmationText) {
        if (formId == null) {
            throw new AuraHandledException('Form id is required.');
        }

        NF_Form__c formRecord = [
            SELECT Id, Description__c, NF_Key__c
            FROM NF_Form__c
            WHERE Id = :formId
            WITH USER_MODE LIMIT 1
        ];

        if (!matchesDeleteFormConfirmation(confirmationText, formRecord.Description__c, formRecord.NF_Key__c)) {
            throw new AuraHandledException('Type the form name or form key to confirm delete.');
        }

        List<NF_Form_Publication__c> publicationRows = [
            SELECT Id, Published_Form_Id__c, Publication_Status__c
            FROM NF_Form_Publication__c
            WHERE Form__c = :formId WITH USER_MODE
        ];
        Set<String> runtimeFormIds = new Set<String>();
        for (NF_Form_Publication__c publicationRow : publicationRows) {
            if (publicationRow.Publication_Status__c == 'Success' && String.isNotBlank(publicationRow.Published_Form_Id__c)) {
                runtimeFormIds.add(publicationRow.Published_Form_Id__c);
            }
        }

        for (NF_Form_Version__c versionRecord : [
            SELECT Id, Form_Id__c, Publish_Status__c
            FROM NF_Form_Version__c
            WHERE Form__c = :formId
              AND Form_Id__c != null
              AND Publish_Status__c = 'Published' WITH USER_MODE
        ]) {
            runtimeFormIds.add(versionRecord.Form_Id__c);
        }

        if (!runtimeFormIds.isEmpty()) {
            unpublishRuntimeForms(runtimeFormIds);
        }

        if (!publicationRows.isEmpty()) {
            delete as user publicationRows;
        }
        delete as user formRecord;
    }

    private static Boolean matchesDeleteFormConfirmation(String confirmationText, String formName, String formKey) {
        String normalizedConfirmation = normalizeDeleteConfirmation(confirmationText);
        if (String.isBlank(normalizedConfirmation)) {
            return false;
        }

        return normalizedConfirmation == normalizeDeleteConfirmation(formName)
            || normalizedConfirmation == normalizeDeleteConfirmation(formKey);
    }

    private static String normalizeDeleteConfirmation(String value) {
        return String.isBlank(value) ? null : value.trim().toLowerCase();
    }

    private static void unpublishRuntimeForms(Set<String> runtimeFormIds) {
        String orgId = UserInfo.getOrganizationId().substring(0, 15);
        for (String runtimeFormId : runtimeFormIds) {
            try {
                Map<String, Object> response = NativeFormsAwsClient.unpublishForm(new Map<String, Object>{
                    'orgId' => orgId,
                    'formId' => runtimeFormId
                });
                Boolean success = response != null && Boolean.valueOf(String.valueOf(response.get('success')));
                if (!success) {
                    throw new CalloutException('Unpublish API did not return success.');
                }
            } catch (Exception error) {
                throw new AuraHandledException('TwinaForms could not disable the published link for this form. The form was not deleted. Try again or contact support. Details: ' + error.getMessage());
            }
        }
    }

    @AuraEnabled
    public static void deleteElement(Id elementId) {
        if (elementId == null) {
            throw new AuraHandledException('Element id is required.');
        }
        ensureElementVersionEditable(elementId);

        NF_Form_Element__c elementRecord = [
            SELECT Id, Element_Id__c, Element_Type__c
            FROM NF_Form_Element__c
            WHERE Id = :elementId
            WITH USER_MODE LIMIT 1
        ];

        List<NF_Form_Element__c> recordsToDelete = new List<NF_Form_Element__c>();
        if ((elementRecord.Element_Type__c == 'section' || elementRecord.Element_Type__c == 'repeatGroup' || elementRecord.Element_Type__c == 'group') && String.isNotBlank(elementRecord.Element_Id__c)) {
            recordsToDelete.addAll([
                SELECT Id
                FROM NF_Form_Element__c
                WHERE Parent_Element_Id__c = :elementRecord.Element_Id__c WITH USER_MODE
            ]);
        }
        recordsToDelete.add(elementRecord);
        delete as user recordsToDelete;
    }

    @AuraEnabled
    public static void restoreVersionElementsSnapshot(Id versionId, String snapshotJson) {
        if (versionId == null) {
            throw new AuraHandledException('Version id is required.');
        }
        ensureVersionEditable(versionId);
        List<ElementSnapshotRecord> snapshot = parseElementSnapshot(snapshotJson);

        List<NF_Form_Element__c> existingElements = [
            SELECT Id
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :versionId
            WITH USER_MODE
        ];
        if (!existingElements.isEmpty()) {
            delete as user existingElements;
        }

        List<NF_Form_Element__c> restoredElements = new List<NF_Form_Element__c>();
        Integer fallbackOrder = 10;
        for (ElementSnapshotRecord snapshotRecord : snapshot) {
            if (String.isBlank(snapshotRecord.elementId) || String.isBlank(snapshotRecord.elementType)) {
                continue;
            }
            restoredElements.add(new NF_Form_Element__c(
                Form_Version__c = versionId,
                Element_Id__c = snapshotRecord.elementId,
                Element_Type__c = snapshotRecord.elementType,
                Field_Key__c = snapshotRecord.fieldKey,
                Element_Index__c = snapshotRecord.elementIndex,
                Label__c = snapshotRecord.label,
                Config_JSON__c = snapshotRecord.configJson,
                Parent_Element_Id__c = snapshotRecord.parentElementId,
                Order__c = snapshotRecord.orderValue == null ? fallbackOrder : snapshotRecord.orderValue
            ));
            fallbackOrder += 10;
        }
        if (!restoredElements.isEmpty()) {
            insert as user restoredElements;
        }
    }

    public static ElementRecord addElement(Id versionId, String elementType) {
        return addElement(versionId, elementType, null);
    }

    @AuraEnabled
    public static ElementRecord addElement(Id versionId, String elementType, String elementPreset) {
        if (versionId == null) {
            throw new AuraHandledException('Choose a form version first.');
        }
        ensureVersionEditable(versionId);
        if (String.isBlank(elementType)) {
            throw new AuraHandledException('Choose an element type first.');
        }
        String normalizedPreset = normalizeElementPreset(elementType, elementPreset);
        if (!new Set<String>{ 'text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'location', 'radio', 'ranking', 'fileUpload', 'signature', 'section', 'group', 'heading', 'mergedDocument', 'image', 'button', 'repeatGroup' }.contains(elementType)) {
            throw new AuraHandledException('This Designer prototype currently supports visual-only field and display elements.');
        }
        if (elementType == 'repeatGroup' && !NativeFormsFeatureFlags.isProRepeatGroupsEnabled()) {
            throw new AuraHandledException('Records List is not available on your current TwinaForms plan.');
        }
        if (elementType == 'fileUpload' && !NativeFormsFeatureFlags.isProLoadFileEnabled()) {
            throw new AuraHandledException('File Uploads are not available on your current TwinaForms plan.');
        }
        if (elementType == 'signature' && !NativeFormsFeatureFlags.isProElectronicSignatureEnabled()) {
            throw new AuraHandledException('Electronic Signature is not available on your current TwinaForms plan.');
        }
        if (elementType == 'button' && !NativeFormsFeatureFlags.isProButtonElementsEnabled()) {
            throw new AuraHandledException('Portal Buttons are not available on your current TwinaForms plan.');
        }
        if ((elementType == 'ranking' || String.isNotBlank(normalizedPreset)) && !NativeFormsFeatureFlags.isProSurveyFieldsEnabled()) {
            throw new AuraHandledException('Survey Fields are not available on your current TwinaForms plan.');
        }
        if (elementType == 'location' && !NativeFormsFeatureFlags.isProLocationFieldsEnabled()) {
            throw new AuraHandledException('Country / State / City is not available on your current TwinaForms plan.');
        }
        if (elementType == 'mergedDocument' && !NativeFormsFeatureFlags.isProMergedDocumentEnabled()) {
            throw new AuraHandledException('Merged Document is not available on your current TwinaForms plan.');
        }

        NF_Form_Version__c versionRecord = [
            SELECT Id, Form__c, UI_Settings_JSON__c
            FROM NF_Form_Version__c
            WHERE Id = :versionId
            WITH USER_MODE LIMIT 1
        ];
        String languageCode = NativeFormsRuntimeI18n.normalizeLanguageCode(
            stringValue(parseJsonMap(versionRecord.UI_Settings_JSON__c).get('languageCode'))
        );

        Integer nextOrder = 10;
        AggregateResult[] maxRows = [
            SELECT MAX(Order__c) maxOrder
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :versionId WITH USER_MODE
        ];
        if (!maxRows.isEmpty() && maxRows[0].get('maxOrder') != null) {
            nextOrder = Integer.valueOf(String.valueOf(maxRows[0].get('maxOrder'))) + 10;
        }

        Integer nextElementIndex = getNextElementIndex(versionRecord.Form__c);

        NF_Form_Element__c elementRecord = new NF_Form_Element__c(
            Form_Version__c = versionId,
            Element_Id__c = buildElementId(elementType),
            Element_Type__c = elementType,
            Field_Key__c = defaultFieldKeyForType(elementType, nextElementIndex, normalizedPreset),
            Element_Index__c = nextElementIndex,
            Label__c = defaultLabelForType(elementType, normalizedPreset, languageCode),
            Config_JSON__c = defaultConfigJsonForType(elementType, languageCode, normalizedPreset),
            Order__c = nextOrder
        );
        insert as user elementRecord;
        elementRecord = [
            SELECT Id, Element_Id__c, Label__c, Element_Type__c, Field_Key__c, Element_Index__c, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Id = :elementRecord.Id
            WITH USER_MODE LIMIT 1
        ];
        return toElementRecord(elementRecord);
    }

    @AuraEnabled
    public static void reorderElement(Id versionId, Id elementId, Integer targetIndex) {
        if (versionId == null) {
            throw new AuraHandledException('Version id is required.');
        }
        ensureVersionEditable(versionId);
        if (elementId == null) {
            throw new AuraHandledException('Element id is required.');
        }
        if (targetIndex == null) {
            throw new AuraHandledException('Target index is required.');
        }

        NF_Form_Element__c draggedRecord = [
            SELECT Id, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Id = :elementId
            WITH USER_MODE LIMIT 1
        ];

        Map<String, Object> draggedConfig = parseJsonMap(draggedRecord.Config_JSON__c);
        if (draggedConfig.containsKey('sectionColumn')) {
            draggedConfig.remove('sectionColumn');
            draggedRecord.Config_JSON__c = JSON.serializePretty(draggedConfig);
        }
        draggedRecord.Parent_Element_Id__c = null;

        List<NF_Form_Element__c> siblings = [
            SELECT Id, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :versionId
              AND Parent_Element_Id__c = null
              AND Id != :elementId
            WITH USER_MODE ORDER BY Order__c ASC, CreatedDate ASC
        ];
        if (siblings.isEmpty()) {
            draggedRecord.Order__c = 10;
            update as user new NF_Form_Element__c(
                Id = draggedRecord.Id,
                Parent_Element_Id__c = draggedRecord.Parent_Element_Id__c,
                Config_JSON__c = draggedRecord.Config_JSON__c,
                Order__c = draggedRecord.Order__c
            );
            return;
        }

        if (targetIndex < 0) {
            targetIndex = 0;
        }
        if (targetIndex > siblings.size()) {
            targetIndex = siblings.size();
        }
        siblings.add(targetIndex, draggedRecord);

        Integer orderValue = 10;
        List<NF_Form_Element__c> siblingUpdates = new List<NF_Form_Element__c>();
        for (NF_Form_Element__c sibling : siblings) {
            sibling.Order__c = orderValue;
            NF_Form_Element__c siblingUpdate = new NF_Form_Element__c(
                Id = sibling.Id,
                Order__c = sibling.Order__c
            );
            if (sibling.Id == draggedRecord.Id) {
                siblingUpdate.Parent_Element_Id__c = draggedRecord.Parent_Element_Id__c;
                siblingUpdate.Config_JSON__c = draggedRecord.Config_JSON__c;
            }
            siblingUpdates.add(siblingUpdate);
            orderValue += 10;
        }
        update as user siblingUpdates;
    }

    @AuraEnabled
    public static void moveElement(Id versionId, Id elementId, Id targetParentId, Integer columnNumber, Integer targetIndex) {
        if (versionId == null) {
            throw new AuraHandledException('Version id is required.');
        }
        ensureVersionEditable(versionId);
        if (elementId == null) {
            throw new AuraHandledException('Element id is required.');
        }
        if (targetIndex == null) {
            throw new AuraHandledException('Target index is required.');
        }

        NF_Form_Element__c elementRecord = [
            SELECT Id, Form_Version__c, Element_Type__c, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Id = :elementId
            WITH USER_MODE LIMIT 1
        ];
        if (elementRecord.Form_Version__c != versionId) {
            throw new AuraHandledException('Element must belong to the selected version.');
        }
        String originalParentElementId = elementRecord.Parent_Element_Id__c;
        Integer originalColumn = readSectionColumn(elementRecord.Config_JSON__c);

        String targetParentElementId = null;
        Boolean placedRowSignature = false;
        if (targetParentId != null) {
            NF_Form_Element__c parentRecord = [
                SELECT Id, Form_Version__c, Element_Id__c, Element_Type__c, Config_JSON__c
                FROM NF_Form_Element__c
                WHERE Id = :targetParentId
                WITH USER_MODE LIMIT 1
            ];
            if (parentRecord.Form_Version__c != versionId) {
                throw new AuraHandledException('Target section must belong to the selected version.');
            }
            if (parentRecord.Element_Type__c != 'section' && parentRecord.Element_Type__c != 'repeatGroup' && parentRecord.Element_Type__c != 'group') {
                throw new AuraHandledException('Only sections, groups, or repeat groups can receive dropped elements.');
            }
            validateContainerPlacement(parentRecord, elementRecord);
            validateRecordsListSignaturePlacement(versionId, parentRecord, elementRecord);
            Integer parentColumns = readColumns(parentRecord.Config_JSON__c);
            if (columnNumber == null || columnNumber < 1 || columnNumber > parentColumns) {
                throw new AuraHandledException('Column number must be between 1 and the container column count.');
            }
            targetParentElementId = parentRecord.Element_Id__c;
            placedRowSignature = parentRecord.Element_Type__c == 'repeatGroup' && elementRecord.Element_Type__c == 'signature';
        }

        Map<String, Object> elementConfig = parseJsonMap(elementRecord.Config_JSON__c);
        Integer targetColumn = columnNumber == null ? 1 : columnNumber;
        if (targetParentElementId == null) {
            elementConfig.remove('sectionColumn');
        } else {
            elementConfig.put('sectionColumn', targetColumn);
        }
        if (placedRowSignature) {
            elementConfig.put('targetSubmitActionKey', '');
            if (!elementConfig.containsKey('attachToRowRecord')) {
                elementConfig.put('attachToRowRecord', false);
            }
        }
        elementRecord.Config_JSON__c = JSON.serializePretty(elementConfig);
        elementRecord.Parent_Element_Id__c = targetParentElementId;

        List<NF_Form_Element__c> siblings = [
            SELECT Id, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :versionId
              AND Parent_Element_Id__c = :targetParentElementId
              AND Id != :elementId
            WITH USER_MODE ORDER BY Order__c ASC, CreatedDate ASC
        ];

        Integer normalizedTargetIndex = Math.max(0, targetIndex);
        Boolean sameTargetGroup = originalParentElementId == targetParentElementId
            && (targetParentElementId == null || originalColumn == targetColumn);
        if (sameTargetGroup) {
            Integer currentIndex = 0;
            for (NF_Form_Element__c sibling : siblings) {
                if (targetParentElementId != null && readSectionColumn(sibling.Config_JSON__c) != targetColumn) {
                    continue;
                }
                if ((sibling.Order__c == null ? 0 : Integer.valueOf(String.valueOf(sibling.Order__c)))
                    < (elementRecord.Order__c == null ? 0 : Integer.valueOf(String.valueOf(elementRecord.Order__c)))) {
                    currentIndex++;
                }
            }
            if (normalizedTargetIndex > currentIndex) {
                normalizedTargetIndex--;
            }
        }

        List<NF_Form_Element__c> orderedSiblings = new List<NF_Form_Element__c>();
        if (targetParentElementId == null) {
            if (normalizedTargetIndex > siblings.size()) {
                normalizedTargetIndex = siblings.size();
            }
            if (normalizedTargetIndex >= siblings.size()) {
                siblings.add(elementRecord);
            } else {
                siblings.add(normalizedTargetIndex, elementRecord);
            }
            orderedSiblings.addAll(siblings);
        } else {
            Map<Integer, List<NF_Form_Element__c>> siblingsByColumn = new Map<Integer, List<NF_Form_Element__c>>();
            for (NF_Form_Element__c sibling : siblings) {
                Integer siblingColumn = readSectionColumn(sibling.Config_JSON__c);
                if (siblingColumn == null || siblingColumn < 1 || siblingColumn > 10) {
                    siblingColumn = 1;
                }
                if (!siblingsByColumn.containsKey(siblingColumn)) {
                    siblingsByColumn.put(siblingColumn, new List<NF_Form_Element__c>());
                }
                siblingsByColumn.get(siblingColumn).add(sibling);
            }
            if (!siblingsByColumn.containsKey(targetColumn)) {
                siblingsByColumn.put(targetColumn, new List<NF_Form_Element__c>());
            }
            List<NF_Form_Element__c> targetColumnSiblings = siblingsByColumn.get(targetColumn);
            if (normalizedTargetIndex > targetColumnSiblings.size()) {
                normalizedTargetIndex = targetColumnSiblings.size();
            }
            if (normalizedTargetIndex >= targetColumnSiblings.size()) {
                targetColumnSiblings.add(elementRecord);
            } else {
                targetColumnSiblings.add(normalizedTargetIndex, elementRecord);
            }
            for (Integer columnIndex = 1; columnIndex <= 10; columnIndex++) {
                if (siblingsByColumn.containsKey(columnIndex)) {
                    orderedSiblings.addAll(siblingsByColumn.get(columnIndex));
                }
            }
        }

        Integer orderValue = 10;
        List<NF_Form_Element__c> updates = new List<NF_Form_Element__c>();
        for (NF_Form_Element__c sibling : orderedSiblings) {
            NF_Form_Element__c updateRecord = new NF_Form_Element__c(
                Id = sibling.Id,
                Order__c = orderValue
            );
            if (sibling.Id == elementRecord.Id) {
                updateRecord.Parent_Element_Id__c = elementRecord.Parent_Element_Id__c;
                updateRecord.Config_JSON__c = elementRecord.Config_JSON__c;
            }
            updates.add(updateRecord);
            orderValue += 10;
        }
        update as user updates;
        if (placedRowSignature) {
            enableSubmissionPdfForRecordsListSignature(versionId);
        }
    }

    @AuraEnabled
    public static void placeElementInSection(Id elementId, Id sectionId, Integer columnNumber) {
        if (elementId == null) {
            throw new AuraHandledException('Element id is required.');
        }
        ensureElementVersionEditable(elementId);
        if (sectionId == null) {
            throw new AuraHandledException('Section id is required.');
        }
        if (columnNumber == null || columnNumber < 1 || columnNumber > 10) {
            throw new AuraHandledException('Column number must be between 1 and 10.');
        }

        NF_Form_Element__c sectionRecord = [
            SELECT Id, Form_Version__c, Element_Id__c, Element_Type__c
            FROM NF_Form_Element__c
            WHERE Id = :sectionId
            WITH USER_MODE LIMIT 1
        ];
        if (sectionRecord.Element_Type__c != 'section' && sectionRecord.Element_Type__c != 'repeatGroup' && sectionRecord.Element_Type__c != 'group') {
            throw new AuraHandledException('Only sections, groups, or repeat groups can receive dropped elements.');
        }

        NF_Form_Element__c elementRecord = [
            SELECT Id, Element_Type__c, Config_JSON__c, Parent_Element_Id__c
            FROM NF_Form_Element__c
            WHERE Id = :elementId
            WITH USER_MODE LIMIT 1
        ];

        validateContainerPlacement(sectionRecord, elementRecord);
        validateRecordsListSignaturePlacement(sectionRecord.Form_Version__c, sectionRecord, elementRecord);

        Map<String, Object> config = parseJsonMap(elementRecord.Config_JSON__c);
        config.put('sectionColumn', columnNumber);
        if (sectionRecord.Element_Type__c == 'repeatGroup' && elementRecord.Element_Type__c == 'signature') {
            config.put('targetSubmitActionKey', '');
            if (!config.containsKey('attachToRowRecord')) {
                config.put('attachToRowRecord', false);
            }
        }
        elementRecord.Config_JSON__c = JSON.serializePretty(config);
        elementRecord.Parent_Element_Id__c = sectionRecord.Element_Id__c;
        update as user new NF_Form_Element__c(
            Id = elementRecord.Id,
            Parent_Element_Id__c = elementRecord.Parent_Element_Id__c,
            Config_JSON__c = elementRecord.Config_JSON__c
        );
        if (sectionRecord.Element_Type__c == 'repeatGroup' && elementRecord.Element_Type__c == 'signature') {
            enableSubmissionPdfForRecordsListSignature(sectionRecord.Form_Version__c);
        }
    }

    @AuraEnabled
    public static void insertElementAfter(Id elementId, Id anchorElementId) {
        if (elementId == null) {
            throw new AuraHandledException('Element id is required.');
        }
        if (anchorElementId == null) {
            throw new AuraHandledException('Anchor element id is required.');
        }
        ensureElementVersionEditable(elementId);

        NF_Form_Element__c elementRecord = [
            SELECT Id, Form_Version__c, Element_Type__c, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Id = :elementId
            WITH USER_MODE LIMIT 1
        ];
        NF_Form_Element__c anchorRecord = [
            SELECT Id, Form_Version__c, Element_Id__c, Element_Type__c, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Id = :anchorElementId
            WITH USER_MODE LIMIT 1
        ];

        if (elementRecord.Form_Version__c != anchorRecord.Form_Version__c) {
            throw new AuraHandledException('Elements must belong to the same version.');
        }

        String targetParentElementId = anchorRecord.Parent_Element_Id__c;
        Boolean placedRowSignature = false;
        Integer targetColumn = readSectionColumn(anchorRecord.Config_JSON__c);
        if (targetParentElementId != null) {
            NF_Form_Element__c parentRecord = [
                SELECT Id, Element_Id__c, Element_Type__c
                FROM NF_Form_Element__c
                WHERE Element_Id__c = :targetParentElementId
                  AND Form_Version__c = :anchorRecord.Form_Version__c
                WITH USER_MODE LIMIT 1
            ];
            validateContainerPlacement(parentRecord, elementRecord);
            validateRecordsListSignaturePlacement(anchorRecord.Form_Version__c, parentRecord, elementRecord);
            placedRowSignature = parentRecord.Element_Type__c == 'repeatGroup' && elementRecord.Element_Type__c == 'signature';
        }

        Map<String, Object> elementConfig = parseJsonMap(elementRecord.Config_JSON__c);
        if (targetParentElementId == null) {
            elementConfig.remove('sectionColumn');
        } else {
            elementConfig.put('sectionColumn', targetColumn == null ? 1 : targetColumn);
        }
        if (placedRowSignature) {
            elementConfig.put('targetSubmitActionKey', '');
            if (!elementConfig.containsKey('attachToRowRecord')) {
                elementConfig.put('attachToRowRecord', false);
            }
        }
        elementRecord.Config_JSON__c = JSON.serializePretty(elementConfig);
        elementRecord.Parent_Element_Id__c = targetParentElementId;

        List<NF_Form_Element__c> siblings = [
            SELECT Id, Order__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :anchorRecord.Form_Version__c
              AND Parent_Element_Id__c = :targetParentElementId
              AND Id != :elementId
            WITH USER_MODE ORDER BY Order__c ASC, CreatedDate ASC
        ];

        Integer anchorIndex = -1;
        for (Integer i = 0; i < siblings.size(); i++) {
            if (siblings[i].Id == anchorRecord.Id) {
                anchorIndex = i;
                break;
            }
        }
        if (anchorIndex < 0) {
            anchorIndex = siblings.size() - 1;
        }

        Integer insertIndex = anchorIndex + 1;
        if (insertIndex >= siblings.size()) {
            siblings.add(elementRecord);
        } else {
            siblings.add(insertIndex, elementRecord);
        }

        Integer orderValue = 10;
        List<NF_Form_Element__c> siblingUpdates = new List<NF_Form_Element__c>();
        for (NF_Form_Element__c sibling : siblings) {
            sibling.Order__c = orderValue;
            NF_Form_Element__c siblingUpdate = new NF_Form_Element__c(
                Id = sibling.Id,
                Order__c = sibling.Order__c
            );
            if (sibling.Id == elementRecord.Id) {
                siblingUpdate.Parent_Element_Id__c = elementRecord.Parent_Element_Id__c;
                siblingUpdate.Config_JSON__c = elementRecord.Config_JSON__c;
            }
            siblingUpdates.add(siblingUpdate);
            orderValue += 10;
        }
        update as user siblingUpdates;
        if (placedRowSignature) {
            enableSubmissionPdfForRecordsListSignature(anchorRecord.Form_Version__c);
        }
    }

    @AuraEnabled
    public static ElementRecord updateSectionColumns(Id elementId, Integer columns) {
        if (elementId == null) {
            throw new AuraHandledException('Element id is required.');
        }
        ensureElementVersionEditable(elementId);
        if (columns == null || columns < 1 || columns > 10) {
            throw new AuraHandledException('Section columns must be between 1 and 10.');
        }

        NF_Form_Element__c elementRecord = [
            SELECT Id, Element_Id__c, Label__c, Element_Type__c, Field_Key__c, Element_Index__c, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Id = :elementId
            WITH USER_MODE LIMIT 1
        ];

        if (elementRecord.Element_Type__c != 'section' && elementRecord.Element_Type__c != 'group' && elementRecord.Element_Type__c != 'repeatGroup') {
            throw new AuraHandledException('Only sections, groups, and records lists can set column counts.');
        }

        Map<String, Object> config = parseJsonMap(elementRecord.Config_JSON__c);
        config.put('columns', columns);
        elementRecord.Config_JSON__c = JSON.serializePretty(config);
        update as user new NF_Form_Element__c(
            Id = elementRecord.Id,
            Config_JSON__c = elementRecord.Config_JSON__c
        );
        return toElementRecord(elementRecord);
    }

    @AuraEnabled
    public static UploadedImageResult uploadImageFile(
        Id elementId,
        Id versionId,
        String fileName,
        String contentType,
        String base64Data
    ) {
        if (elementId == null) {
            throw new AuraHandledException('Element id is required.');
        }
        if (versionId == null) {
            throw new AuraHandledException('Version id is required.');
        }
        ensureVersionEditable(versionId);
        if (String.isBlank(fileName) || String.isBlank(base64Data)) {
            throw new AuraHandledException('Choose an image file first.');
        }
        Blob imageBlob = EncodingUtil.base64Decode(base64Data);
        if (imageBlob.size() > MAX_EMBEDDED_IMAGE_BYTES) {
            throw new AuraHandledException('Image is too large. Please upload an optimized image under 69 KB.');
        }

        NF_Form_Element__c elementRecord = [
            SELECT Id, Element_Id__c, Label__c, Element_Type__c, Field_Key__c, Element_Index__c, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Id = :elementId
            WITH USER_MODE LIMIT 1
        ];
        if (elementRecord.Element_Type__c != 'image') {
            throw new AuraHandledException('Only image elements can receive uploaded image files.');
        }

        ContentVersion versionRecord = new ContentVersion(
            Title = titleFromFileName(fileName),
            PathOnClient = fileName,
            VersionData = imageBlob,
            FirstPublishLocationId = versionId
        );
        insert as user versionRecord;
        versionRecord = [
            SELECT Id, ContentDocumentId, Title
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
            WITH USER_MODE LIMIT 1
        ];

        Map<String, Object> config = parseJsonMap(elementRecord.Config_JSON__c);
        config.put('contentDocumentId', String.valueOf(versionRecord.ContentDocumentId));
        config.put('contentVersionId', String.valueOf(versionRecord.Id));
        config.put('fileName', fileName);
        config.put('imageUrl', buildContentVersionUrl(versionRecord.Id));
        if (String.isBlank(stringValue(config.get('altText')))) {
            config.put('altText', titleFromFileName(fileName));
        }
        elementRecord.Config_JSON__c = JSON.serializePretty(config);
        update as user new NF_Form_Element__c(
            Id = elementRecord.Id,
            Config_JSON__c = elementRecord.Config_JSON__c
        );
        UploadedImageResult result = new UploadedImageResult();
        result.contentDocumentId = versionRecord.ContentDocumentId;
        result.contentVersionId = versionRecord.Id;
        result.fileName = fileName;
        result.previewUrl = buildContentVersionUrl(versionRecord.Id);
        result.altText = stringValue(config.get('altText'));
        result.element = toElementRecord(elementRecord);
        return result;
    }

    private static ElementRecord toElementRecord(NF_Form_Element__c elementRecord) {
        ElementRecord dto = new ElementRecord();
        dto.id = elementRecord.Id;
        dto.elementId = elementRecord.Element_Id__c;
        dto.label = elementRecord.Label__c;
        dto.elementType = elementRecord.Element_Type__c;
        dto.fieldKey = elementRecord.Field_Key__c;
        dto.elementIndex = elementRecord.Element_Index__c == null ? null : Integer.valueOf(String.valueOf(elementRecord.Element_Index__c));
        dto.configJson = elementRecord.Config_JSON__c;
        dto.parentElementId = elementRecord.Parent_Element_Id__c;
        dto.sectionColumn = readSectionColumn(elementRecord.Config_JSON__c);
        dto.orderValue = elementRecord.Order__c == null ? null : Integer.valueOf(String.valueOf(elementRecord.Order__c));
        return dto;
    }

    private static List<ElementSnapshotRecord> parseElementSnapshot(String snapshotJson) {
        if (String.isBlank(snapshotJson)) {
            return new List<ElementSnapshotRecord>();
        }
        try {
            List<ElementSnapshotRecord> snapshot = (List<ElementSnapshotRecord>) JSON.deserialize(
                snapshotJson,
                List<ElementSnapshotRecord>.class
            );
            return snapshot == null ? new List<ElementSnapshotRecord>() : snapshot;
        } catch (Exception error) {
            throw new AuraHandledException('Undo snapshot could not be read.');
        }
    }

    private static ThemeRecord toThemeRecord(NF_Theme__c row) {
        ThemeRecord dto = new ThemeRecord();
        dto.id = row.Id;
        dto.name = row.Name;
        dto.logoUrl = row.Logo_URL__c;
        dto.logoSizePx = row.Logo_Size_Px__c;
        dto.logoPosition = row.Logo_Position__c;
        dto.formWidth = row.Form_Width__c;
        dto.backgroundColor = row.Background_Color__c;
        dto.formBackgroundColor = row.Form_Background_Color__c;
        dto.formBorderColor = row.Form_Border_Color__c;
        dto.titleFont = row.Title_Font__c;
        dto.titleFontSizePx = row.Title_Font_Size_Px__c;
        dto.titleTextColor = row.Title_Text_Color__c;
        dto.sectionTitleFont = row.Section_Title_Font__c;
        dto.sectionTitleFontSizePx = row.Section_Title_Font_Size_Px__c;
        dto.sectionTitleTextColor = row.Section_Title_Text_Color__c;
        dto.mainFont = row.Main_Font__c;
        dto.mainTextSizePx = row.Main_Text_Size_Px__c;
        dto.mainTextColor = row.Main_Text_Color__c;
        dto.hintTextColor = row.Hint_Text_Color__c;
        dto.inputBorderRadiusPx = row.Input_Border_Radius_Px__c;
        dto.inputBackgroundColor = row.Input_Background_Color__c;
        dto.inputBorderColor = row.Input_Border_Color__c;
        dto.buttonFont = row.Button_Font__c;
        dto.buttonFontSizePx = row.Button_Font_Size_Px__c;
        dto.buttonTextColor = row.Button_Text_Color__c;
        dto.buttonBackgroundColor = row.Button_Background_Color__c;
        return dto;
    }

    private static String buildElementId(String elementType) {
        return elementType.toLowerCase() + '-' + String.valueOf(Datetime.now().getTime());
    }

    private static String defaultLabelForType(String elementType) {
        return defaultLabelForType(elementType, null);
    }

    private static String defaultLabelForType(String elementType, String elementPreset) {
        return defaultLabelForType(elementType, elementPreset, 'en');
    }

    private static String defaultLabelForType(String elementType, String elementPreset, String languageCode) {
        String labelKey = elementType;
        if (elementType == 'radio' && String.isNotBlank(elementPreset)) {
            labelKey = 'radio:' + elementPreset;
        }
        String normalizedLanguage = NativeFormsRuntimeI18n.normalizeLanguageCode(languageCode);
        Map<String, String> labels = defaultElementLabelsByLanguage().get(normalizedLanguage);
        if (labels == null) {
            labels = defaultElementLabelsByLanguage().get('en');
        }
        String value = labels == null ? null : labels.get(labelKey);
        if (String.isBlank(value) && normalizedLanguage != 'en') {
            value = defaultElementLabelsByLanguage().get('en').get(labelKey);
        }
        return String.isBlank(value) ? 'Text Input' : value;
    }

    private static Map<String, Map<String, String>> defaultElementLabelsByLanguage() {
        return new Map<String, Map<String, String>>{
            'en' => new Map<String, String>{
                'radio:stars' => 'Rating',
                'radio:nps' => 'How likely are you to recommend us?',
                'radio:likert' => 'Agreement',
                'radio:satisfaction' => 'Satisfaction',
                'ranking' => 'Rank these choices',
                'section' => 'Section',
                'repeatGroup' => 'Records List',
                'group' => 'Group',
                'heading' => 'Display Text',
                'mergedDocument' => 'Merged Document',
                'image' => 'Image',
                'button' => 'Continue',
                'fileUpload' => 'File Upload',
                'signature' => 'Signature',
                'lookup' => 'Lookup',
                'location' => 'Country / State / City',
                'checkbox' => 'Checkbox',
                'textarea' => 'Textarea',
                'number' => 'Number',
                'date' => 'Date',
                'time' => 'Time',
                'email' => 'Email',
                'tel' => 'Phone',
                'url' => 'URL',
                'select' => 'Picklist',
                'multiCheckbox' => 'Multi Checkbox',
                'radio' => 'Radio Group',
                'text' => 'Text Input'
            },
            'he' => new Map<String, String>{
                'radio:stars' => '\u05D3\u05D9\u05E8\u05D5\u05D2',
                'radio:nps' => '\u05D4\u05E1\u05EA\u05D1\u05E8\u05D5\u05EA \u05DC\u05D4\u05DE\u05DC\u05E6\u05D4',
                'radio:likert' => '\u05D4\u05E1\u05DB\u05DE\u05D4',
                'radio:satisfaction' => '\u05E9\u05D1\u05D9\u05E2\u05D5\u05EA \u05E8\u05E6\u05D5\u05DF',
                'ranking' => '\u05D3\u05E8\u05D2 \u05D0\u05EA \u05D4\u05D0\u05E4\u05E9\u05E8\u05D5\u05D9\u05D5\u05EA',
                'section' => '\u05DE\u05E7\u05D8\u05E2',
                'repeatGroup' => '\u05E8\u05E9\u05D9\u05DE\u05EA \u05E8\u05E9\u05D5\u05DE\u05D5\u05EA',
                'group' => '\u05E7\u05D1\u05D5\u05E6\u05D4',
                'heading' => '\u05D8\u05E7\u05E1\u05D8 \u05DC\u05EA\u05E6\u05D5\u05D2\u05D4',
                'mergedDocument' => '\u05DE\u05E1\u05DE\u05DA \u05DE\u05DE\u05D5\u05D6\u05D2',
                'image' => '\u05EA\u05DE\u05D5\u05E0\u05D4',
                'button' => '\u05D4\u05DE\u05E9\u05DA',
                'fileUpload' => '\u05D4\u05E2\u05DC\u05D0\u05EA \u05E7\u05D5\u05D1\u05E5',
                'signature' => '\u05D7\u05EA\u05D9\u05DE\u05D4',
                'lookup' => '\u05D7\u05D9\u05E4\u05D5\u05E9',
                'location' => '\u05DE\u05D3\u05D9\u05E0\u05D4 / \u05D0\u05D6\u05D5\u05E8 / \u05E2\u05D9\u05E8',
                'checkbox' => '\u05EA\u05D9\u05D1\u05EA \u05E1\u05D9\u05DE\u05D5\u05DF',
                'textarea' => '\u05D8\u05E7\u05E1\u05D8 \u05D0\u05E8\u05D5\u05DA',
                'number' => '\u05DE\u05E1\u05E4\u05E8',
                'date' => '\u05EA\u05D0\u05E8\u05D9\u05DA',
                'time' => '\u05E9\u05E2\u05D4',
                'email' => '\u05D0\u05D9\u05DE\u05D9\u05D9\u05DC',
                'tel' => '\u05D8\u05DC\u05E4\u05D5\u05DF',
                'url' => '\u05DB\u05EA\u05D5\u05D1\u05EA URL',
                'select' => '\u05E8\u05E9\u05D9\u05DE\u05EA \u05D1\u05D7\u05D9\u05E8\u05D4',
                'multiCheckbox' => '\u05D1\u05D7\u05D9\u05E8\u05D4 \u05DE\u05E8\u05D5\u05D1\u05D4',
                'radio' => '\u05E7\u05D1\u05D5\u05E6\u05EA \u05D1\u05D7\u05D9\u05E8\u05D4',
                'text' => '\u05D8\u05E7\u05E1\u05D8'
            },
            'es' => new Map<String, String>{
                'radio:stars' => 'Calificaci\u00F3n',
                'radio:nps' => 'Probabilidad de recomendaci\u00F3n',
                'radio:likert' => 'Acuerdo',
                'radio:satisfaction' => 'Satisfacci\u00F3n',
                'ranking' => 'Ordena estas opciones',
                'section' => 'Secci\u00F3n',
                'repeatGroup' => 'Lista de registros',
                'group' => 'Grupo',
                'heading' => 'Texto de visualizaci\u00F3n',
                'mergedDocument' => 'Documento combinado',
                'image' => 'Imagen',
                'button' => 'Continuar',
                'fileUpload' => 'Carga de archivo',
                'signature' => 'Firma',
                'lookup' => 'B\u00FAsqueda',
                'location' => 'Pa\u00EDs / Regi\u00F3n / Ciudad',
                'checkbox' => 'Casilla',
                'textarea' => 'Texto largo',
                'number' => 'N\u00FAmero',
                'date' => 'Fecha',
                'time' => 'Hora',
                'email' => 'Correo electr\u00F3nico',
                'tel' => 'Tel\u00E9fono',
                'url' => 'URL',
                'select' => 'Lista de selecci\u00F3n',
                'multiCheckbox' => 'Casillas m\u00FAltiples',
                'radio' => 'Grupo de opciones',
                'text' => 'Entrada de texto'
            },
            'de' => new Map<String, String>{
                'radio:stars' => 'Bewertung',
                'radio:nps' => 'Empfehlungswahrscheinlichkeit',
                'radio:likert' => 'Zustimmung',
                'radio:satisfaction' => 'Zufriedenheit',
                'ranking' => 'Ordnen Sie diese Optionen',
                'section' => 'Abschnitt',
                'repeatGroup' => 'Datensatzliste',
                'group' => 'Gruppe',
                'heading' => 'Anzeigetext',
                'mergedDocument' => 'Zusammengef\u00FChrtes Dokument',
                'image' => 'Bild',
                'button' => 'Weiter',
                'fileUpload' => 'Datei-Upload',
                'signature' => 'Unterschrift',
                'lookup' => 'Suche',
                'location' => 'Land / Region / Stadt',
                'checkbox' => 'Kontrollk\u00E4stchen',
                'textarea' => 'Langer Text',
                'number' => 'Zahl',
                'date' => 'Datum',
                'time' => 'Uhrzeit',
                'email' => 'E-Mail',
                'tel' => 'Telefon',
                'url' => 'URL',
                'select' => 'Auswahlliste',
                'multiCheckbox' => 'Mehrfachauswahl',
                'radio' => 'Optionsgruppe',
                'text' => 'Texteingabe'
            },
            'fr' => new Map<String, String>{
                'radio:stars' => '\u00C9valuation',
                'radio:nps' => 'Probabilit\u00E9 de recommandation',
                'radio:likert' => 'Accord',
                'radio:satisfaction' => 'Satisfaction',
                'ranking' => 'Classez ces choix',
                'section' => 'Section',
                'repeatGroup' => 'Liste des enregistrements',
                'group' => 'Groupe',
                'heading' => 'Texte affich\u00E9',
                'mergedDocument' => 'Document fusionn\u00E9',
                'image' => 'Image',
                'button' => 'Continuer',
                'fileUpload' => 'Import de fichier',
                'signature' => 'Signature',
                'lookup' => 'Recherche',
                'location' => 'Pays / R\u00E9gion / Ville',
                'checkbox' => 'Case \u00E0 cocher',
                'textarea' => 'Texte long',
                'number' => 'Nombre',
                'date' => 'Date',
                'time' => 'Heure',
                'email' => 'E-mail',
                'tel' => 'T\u00E9l\u00E9phone',
                'url' => 'URL',
                'select' => 'Liste de s\u00E9lection',
                'multiCheckbox' => 'Choix multiples',
                'radio' => 'Groupe options',
                'text' => 'Saisie de texte'
            }
        };
    }

    private static String defaultFieldKeyForType(String elementType, Integer elementIndex) {
        return defaultFieldKeyForType(elementType, elementIndex, null);
    }

    private static String defaultFieldKeyForType(String elementType, Integer elementIndex, String elementPreset) {
        if (!new Set<String>{ 'text', 'textarea', 'number', 'date', 'time', 'email', 'tel', 'url', 'checkbox', 'select', 'multiCheckbox', 'lookup', 'location', 'radio', 'ranking', 'fileUpload', 'signature', 'repeatGroup' }.contains(elementType)) {
            return null;
        }
        String prefix = 'field';
        if (elementType == 'checkbox') prefix = 'checkbox';
        if (elementType == 'textarea') prefix = 'textarea';
        if (elementType == 'number') prefix = 'number';
        if (elementType == 'date') prefix = 'date';
        if (elementType == 'time') prefix = 'time';
        if (elementType == 'email') prefix = 'email';
        if (elementType == 'tel') prefix = 'phone';
        if (elementType == 'url') prefix = 'url';
        if (elementType == 'select') prefix = 'picklist';
        if (elementType == 'multiCheckbox') prefix = 'multiPicklist';
        if (elementType == 'lookup') prefix = 'lookup';
        if (elementType == 'location') prefix = 'location';
        if (elementType == 'radio') prefix = 'radio';
        if (elementType == 'radio' && elementPreset == 'stars') prefix = 'rating';
        if (elementType == 'radio' && elementPreset == 'nps') prefix = 'nps';
        if (elementType == 'radio' && elementPreset == 'likert') prefix = 'likert';
        if (elementType == 'radio' && elementPreset == 'satisfaction') prefix = 'satisfaction';
        if (elementType == 'ranking') prefix = 'ranking';
        if (elementType == 'fileUpload') prefix = 'file';
        if (elementType == 'signature') prefix = 'signature';
        if (elementType == 'text') prefix = 'text';
        if (elementType == 'repeatGroup') prefix = 'repeatGroup';
        Integer safeIndex = elementIndex == null || elementIndex <= 0 ? 1 : elementIndex;
        return prefix + String.valueOf(safeIndex);
    }

    private static String defaultConfigJsonForType(String elementType, String languageCode) {
        return defaultConfigJsonForType(elementType, languageCode, null);
    }

    private static String defaultConfigJsonForType(String elementType, String languageCode, String elementPreset) {
        Map<String, Object> config = new Map<String, Object>();
        if (elementType == 'text') {
            config.put('defaultValue', '');
            config.put('placeholder', NativeFormsRuntimeI18n.text(languageCode, 'placeholderText', 'Enter text'));
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('required', false);
            config.put('isFormula', false);
            config.put('formulaExpression', '');
        }
        if (elementType == 'textarea') {
            config.put('defaultValue', '');
            config.put('placeholder', NativeFormsRuntimeI18n.text(languageCode, 'placeholderTextarea', 'Enter longer text'));
            config.put('labelPosition', 'above');
            config.put('rows', 4);
            config.put('maxLength', 254);
            config.put('fieldBehavior', 'editable');
            config.put('required', false);
        }
        if (elementType == 'number') {
            config.put('defaultValue', '');
            config.put('placeholder', NativeFormsRuntimeI18n.text(languageCode, 'placeholderNumber', 'Enter number'));
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('required', false);
            config.put('isFormula', false);
            config.put('formulaExpression', '');
        }
        if (elementType == 'date') {
            config.put('defaultValue', '');
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('dateDisplayFormat', 'us');
            config.put('dateGmtOffset', '+00:00');
            config.put('required', false);
        }
        if (elementType == 'time') {
            config.put('defaultValue', '');
            config.put('placeholder', '19:00');
            config.put('timeFormat', '24h');
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('required', false);
        }
        if (elementType == 'button') {
            config.put('destinationType', 'form');
            config.put('targetFormId', '');
            config.put('externalUrlMode', 'template');
            config.put('externalUrlTemplate', '');
            config.put('externalUrlFormula', '');
            config.put('queryParameters', new List<Object>());
            config.put('submitBeforeNavigation', false);
            config.put('conditionalEnabled', false);
            config.put('conditionalConditions', new List<Object>());
            config.put('conditionalExpression', '');
        }
        if (elementType == 'email') {
            config.put('defaultValue', '');
            config.put('placeholder', NativeFormsRuntimeI18n.text(languageCode, 'placeholderEmail', 'name@example.com'));
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('required', false);
        }
        if (elementType == 'tel') {
            config.put('defaultValue', '');
            config.put('placeholder', NativeFormsRuntimeI18n.text(languageCode, 'placeholderPhone', 'Phone number'));
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('required', false);
        }
        if (elementType == 'url') {
            config.put('defaultValue', '');
            config.put('placeholder', NativeFormsRuntimeI18n.text(languageCode, 'placeholderUrl', 'https://example.com'));
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('required', false);
        }
        if (elementType == 'checkbox') {
            config.put('checked', false);
            config.put('defaultValue', 'false');
            config.put('labelPosition', 'inline');
            config.put('fieldBehavior', 'editable');
            config.put('required', false);
        }
        if (elementType == 'select' || elementType == 'radio' || elementType == 'multiCheckbox') {
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('defaultValue', elementType == 'multiCheckbox'
                ? ''
                : (String.isNotBlank(elementPreset) ? '' : 'option1'));
            config.put('required', false);
            config.put('options', defaultOptionsForPreset(elementPreset));
            if (String.isNotBlank(elementPreset)) {
                config.put('presentation', elementPreset);
            }
        }
        if (elementType == 'lookup') {
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('placeholder', 'Search records');
            config.put('required', false);
            config.put('lookupTargetObject', '');
            config.put('lookupSearchFields', new List<Object>{ 'Name' });
            config.put('lookupDisplayFields', new List<Object>{ 'Name' });
            config.put('lookupMinSearchLength', 2);
            config.put('lookupLimit', 10);
        }
        if (elementType == 'location') {
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('required', false);
            config.put('locationMode', 'countryRegionCity');
            config.put('locationRequiredCountry', true);
            config.put('locationRequiredRegion', false);
            config.put('locationRequiredCity', false);
            config.put('locationDefaultCountryCode', '');
            config.put('locationAllowedCountries', new List<Object>());
            config.put('locationMinSearchLength', 2);
            config.put('locationLimit', 10);
            config.put('locationOutputMode', 'structured');
        }
        if (elementType == 'ranking') {
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('defaultValue', '');
            config.put('required', false);
            config.put('presentation', 'ranking');
            config.put('options', defaultOptionsForPreset('ranking'));
        }
        if (elementType == 'fileUpload') {
            config.put('labelPosition', 'above');
            config.put('required', false);
            config.put('allowMultiple', false);
            config.put('allowedExtensions', new List<Object>{ 'pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx' });
            config.put('maxFileSizeMb', 10);
            config.put('targetSubmitActionKey', '');
        }
        if (elementType == 'signature') {
            config.put('labelPosition', 'above');
            config.put('required', false);
            config.put('helpText', '');
            config.put('clearButtonLabel', NativeFormsRuntimeI18n.text(languageCode, 'signatureClear', 'Clear'));
            config.put('targetSubmitActionKey', '');
            config.put('attachToRowRecord', false);
        }
        if (elementType == 'section') {
            config.put('text', 'Section description');
            config.put('columns', 2);
            config.put('showTitle', true);
            config.put('boxed', true);
        }
        if (elementType == 'group') {
            config.put('columns', 1);
            config.put('boxed', false);
        }
        if (elementType == 'repeatGroup') {
            config.put('showTitle', true);
            config.put('boxed', true);
            config.put('columns', 2);
            config.put('repeatSourceAlias', '');
            config.put('allowAddRows', true);
            config.put('allowDeleteRows', true);
        }
        if (elementType == 'heading' || elementType == 'mergedDocument') {
            config.put('html', elementType == 'mergedDocument' ? '<p>Merged document text</p>' : '<p>Display text</p>');
        }
        if (elementType == 'image') {
            config.put('imageUrl', '');
            config.put('altText', 'Image preview');
        }
        return JSON.serializePretty(config);
    }

    private static String normalizeElementPreset(String elementType, String elementPreset) {
        String preset = String.isBlank(elementPreset) ? '' : elementPreset.trim().toLowerCase();
        if (elementType == 'ranking') {
            return 'ranking';
        }
        if (elementType != 'radio') {
            return '';
        }
        return new Set<String>{ 'stars', 'nps', 'likert', 'satisfaction' }.contains(preset) ? preset : '';
    }

    private static List<Object> defaultOptionsForPreset(String elementPreset) {
        if (elementPreset == 'stars') {
            return new List<Object>{
                new Map<String, Object>{ 'label' => '1 star', 'value' => '1' },
                new Map<String, Object>{ 'label' => '2 stars', 'value' => '2' },
                new Map<String, Object>{ 'label' => '3 stars', 'value' => '3' },
                new Map<String, Object>{ 'label' => '4 stars', 'value' => '4' },
                new Map<String, Object>{ 'label' => '5 stars', 'value' => '5' }
            };
        }
        if (elementPreset == 'nps') {
            List<Object> options = new List<Object>();
            for (Integer index = 0; index <= 10; index++) {
                options.add(new Map<String, Object>{ 'label' => String.valueOf(index), 'value' => String.valueOf(index) });
            }
            return options;
        }
        if (elementPreset == 'likert') {
            return new List<Object>{
                new Map<String, Object>{ 'label' => 'Strongly disagree', 'value' => 'strongly_disagree' },
                new Map<String, Object>{ 'label' => 'Disagree', 'value' => 'disagree' },
                new Map<String, Object>{ 'label' => 'Neutral', 'value' => 'neutral' },
                new Map<String, Object>{ 'label' => 'Agree', 'value' => 'agree' },
                new Map<String, Object>{ 'label' => 'Strongly agree', 'value' => 'strongly_agree' }
            };
        }
        if (elementPreset == 'satisfaction') {
            return new List<Object>{
                new Map<String, Object>{ 'label' => 'Very unsatisfied', 'value' => 'very_unsatisfied' },
                new Map<String, Object>{ 'label' => 'Unsatisfied', 'value' => 'unsatisfied' },
                new Map<String, Object>{ 'label' => 'Neutral', 'value' => 'neutral' },
                new Map<String, Object>{ 'label' => 'Satisfied', 'value' => 'satisfied' },
                new Map<String, Object>{ 'label' => 'Very satisfied', 'value' => 'very_satisfied' }
            };
        }
        if (elementPreset == 'ranking') {
            return new List<Object>{
                new Map<String, Object>{ 'label' => 'Quality', 'value' => 'quality' },
                new Map<String, Object>{ 'label' => 'Price', 'value' => 'price' },
                new Map<String, Object>{ 'label' => 'Support', 'value' => 'support' }
            };
        }
        return new List<Object>{
            new Map<String, Object>{ 'label' => 'Option 1', 'value' => 'option1' },
            new Map<String, Object>{ 'label' => 'Option 2', 'value' => 'option2' }
        };
    }

    private static Map<String, Object> fetchPageLayoutMetadata(String objectApiName, String layoutKey, String languageCode) {
        if (Test.isRunningTest() && pageLayoutImportMetadataMock != null) {
            return pageLayoutImportMetadataMock;
        }
        String normalizedLanguageCode = defaultLanguageCode(languageCode);
        Map<String, Object> requestBody = new Map<String, Object>{
            'orgId' => UserInfo.getOrganizationId().substring(0, 15),
            'objectApiName' => objectApiName,
            'languageCode' => normalizedLanguageCode
        };
        if (String.isNotBlank(layoutKey)) {
            requestBody.put('layoutKey', layoutKey);
        }

        try {
            Map<String, Object> response = NativeFormsAwsClient.getSalesforceLayouts(requestBody);
            if (response == null) {
                throw new AuraHandledException('Salesforce layout metadata response was empty.');
            }
            if (response.containsKey('success') && booleanValue(response.get('success')) != true) {
                String errorMessage = stringValue(response.get('error'));
                throw new AuraHandledException(String.isBlank(errorMessage) ? 'Salesforce layout metadata could not be loaded.' : errorMessage);
            }
            return response;
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Salesforce layout metadata could not be loaded: ' + e.getMessage());
        }
    }

    private static PageLayoutImportPlan buildPageLayoutImportPlan(String objectApiName, String layoutKey, String mode, String languageCode) {
        String normalizedLanguageCode = defaultLanguageCode(languageCode);
        String canonicalObject = canonicalObjectName(objectApiName);
        if (String.isBlank(canonicalObject)) {
            throw new AuraHandledException('Select a valid Salesforce object.');
        }

        Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe().get(canonicalObject).getDescribe();
        if (!objectDescribe.isAccessible()) {
            throw new AuraHandledException('You do not have access to the selected Salesforce object.');
        }

        PageLayoutImportPlan plan = new PageLayoutImportPlan();
        plan.objectApiName = objectDescribe.getName();
        plan.objectLabel = objectDescribe.getLabel();
        plan.mode = normalizePageLayoutImportMode(mode);
        plan.languageCode = normalizedLanguageCode;
        if (plan.mode != 'create') {
            plan.warnings.add('Secure edit uses Salesforce Contact email verification only. Visitors without a matching Contact cannot edit.');
        }

        Map<String, Object> response = fetchPageLayoutMetadata(plan.objectApiName, layoutKey, normalizedLanguageCode);
        Map<String, Object> layoutMap = response.get('layout') instanceof Map<String, Object>
            ? (Map<String, Object>) response.get('layout')
            : null;
        if (layoutMap == null) {
            throw new AuraHandledException('Salesforce layout metadata response did not include a layout.');
        }
        String translatedObjectLabel = String.isBlank(stringValue(response.get('objectLabel')))
            ? stringValue(layoutMap.get('objectLabel'))
            : stringValue(response.get('objectLabel'));
        if (String.isNotBlank(translatedObjectLabel)) {
            plan.objectLabel = translatedObjectLabel;
        }
        plan.layoutKey = String.isBlank(stringValue(layoutMap.get('layoutKey')))
            ? normalizePageLayoutImportLayoutKey(layoutKey)
            : stringValue(layoutMap.get('layoutKey'));
        plan.layoutLabel = String.isBlank(stringValue(layoutMap.get('layoutLabel')))
            ? 'Assigned Salesforce layout'
            : stringValue(layoutMap.get('layoutLabel'));

        if (layoutMap.containsKey('warnings') && layoutMap.get('warnings') instanceof List<Object>) {
            for (Object warningValue : (List<Object>) layoutMap.get('warnings')) {
                String warning = stringValue(warningValue);
                if (String.isNotBlank(warning)) {
                    plan.warnings.add(warning);
                }
            }
        }

        Map<String, Schema.SObjectField> fieldsMap = objectDescribe.fields.getMap();
        Set<String> importedFieldNames = new Set<String>();
        List<Object> rawSections = layoutMap.get('sections') instanceof List<Object>
            ? (List<Object>) layoutMap.get('sections')
            : new List<Object>();
        for (Object rawSectionValue : rawSections) {
            if (!(rawSectionValue instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> rawSection = (Map<String, Object>) rawSectionValue;
            PageLayoutImportSection section = new PageLayoutImportSection();
            section.heading = String.isBlank(stringValue(rawSection.get('heading')))
                ? plan.objectLabel + ' Details'
                : stringValue(rawSection.get('heading'));
            List<Object> rawFields = rawSection.get('fields') instanceof List<Object>
                ? (List<Object>) rawSection.get('fields')
                : new List<Object>();

            for (Object rawFieldValue : rawFields) {
                if (!(rawFieldValue instanceof Map<String, Object>)) {
                    plan.skippedFieldCount++;
                    continue;
                }
                Map<String, Object> rawField = (Map<String, Object>) rawFieldValue;
                String canonicalField = canonicalFieldName(fieldsMap, stringValue(rawField.get('apiName')));
                if (isIgnoredPageLayoutSystemField(canonicalField)) {
                    continue;
                }
                if (String.isBlank(canonicalField) || importedFieldNames.contains(canonicalField.toLowerCase())) {
                    plan.skippedFieldCount++;
                    addPageLayoutSkippedDetail(
                        plan,
                        stringValue(rawField.get('apiName')),
                        layoutFieldLabel(rawField, stringValue(rawField.get('apiName'))),
                        'Unknown or duplicate field',
                        'The field was not found on the selected object or already appeared earlier in the layout.',
                        'Check the Salesforce page layout and object metadata.'
                    );
                    continue;
                }
                Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(canonicalField).getDescribe();
                PageLayoutImportField fieldSpec = toPageLayoutImportField(fieldDescribe);
                if (fieldSpec == null) {
                    plan.skippedFieldCount++;
                    addPageLayoutSkippedDetail(
                        plan,
                        canonicalField,
                        layoutFieldLabel(rawField, canonicalField),
                        'Unsupported or read-only field',
                        'TwinaForms cannot import this Salesforce field type, or the field is not accessible.',
                        'Use a supported editable field type, or adjust field-level security.'
                    );
                    continue;
                }

                String inclusionMode = pageLayoutFieldInclusionMode(rawField, fieldDescribe, plan.mode);
                if (String.isBlank(inclusionMode)) {
                    plan.skippedFieldCount++;
                    addPageLayoutSkippedDetail(
                        plan,
                        canonicalField,
                        layoutFieldLabel(rawField, canonicalField),
                        'Not writable for selected mode',
                        pageLayoutFieldSkipMessage(rawField, fieldDescribe, plan.mode),
                        pageLayoutFieldSkipChangeHint(plan.mode)
                    );
                    continue;
                }
                String translatedLabel = stringValue(rawField.get('label'));
                if (String.isNotBlank(translatedLabel)) {
                    fieldSpec.label = translatedLabel;
                }
                if (fieldSpec.elementType == 'select' || fieldSpec.elementType == 'multiCheckbox') {
                    List<Object> translatedOptions = picklistOptionsFromLayoutField(rawField);
                    if (!translatedOptions.isEmpty()) {
                        fieldSpec.options = translatedOptions;
                    }
                }
                if (booleanValue(rawField.get('required'))) {
                    fieldSpec.required = true;
                }
                if (inclusionMode == 'createOnly') {
                    fieldSpec.createOnly = true;
                    fieldSpec.submitWhen = 'create';
                    plan.createOnlyFieldCount++;
                    addPageLayoutIncludedNote(
                        plan,
                        fieldSpec.apiName,
                        fieldSpec.label,
                        'Create-only field',
                        'This field is included for the create path only. Existing records will show the prefilled value as locked, and new records must provide a value.',
                        'If it should be editable on existing records, make the Salesforce field updateable on the page layout and field security.'
                    );
                } else {
                    fieldSpec.createOnly = false;
                    fieldSpec.submitWhen = 'always';
                }
                if (plan.fields.size() >= MAX_PAGE_LAYOUT_IMPORT_FIELDS) {
                    plan.skippedFieldCount++;
                    addPageLayoutSkippedDetail(
                        plan,
                        fieldSpec.apiName,
                        fieldSpec.label,
                        'Import limit reached',
                        'Only the first ' + String.valueOf(MAX_PAGE_LAYOUT_IMPORT_FIELDS) + ' supported fields are imported in V1.',
                        'Remove less important fields from the Salesforce layout or create another form.'
                    );
                    continue;
                }
                importedFieldNames.add(canonicalField.toLowerCase());
                plan.fields.add(fieldSpec);
                section.fields.add(fieldSpec);
            }
            if (!section.fields.isEmpty()) {
                plan.sections.add(section);
            }
        }

        if (plan.skippedFieldCount > 0) {
            plan.warnings.add(String.valueOf(plan.skippedFieldCount) + ' read-only or unsupported fields will be skipped.');
        }
        if (plan.createOnlyFieldCount > 0) {
            plan.warnings.add(String.valueOf(plan.createOnlyFieldCount) + ' create-only fields will be included only when TwinaForms creates a missing record.');
        }
        if (plan.fields.size() >= MAX_PAGE_LAYOUT_IMPORT_FIELDS) {
            plan.warnings.add('Only the first ' + String.valueOf(MAX_PAGE_LAYOUT_IMPORT_FIELDS) + ' supported fields are imported in V1.');
        }
        addMissingTranslationWarning(plan, objectDescribe, layoutKey);
        return plan;
    }

    private static void addMissingTranslationWarning(PageLayoutImportPlan plan, Schema.DescribeSObjectResult objectDescribe, String layoutKey) {
        if (plan == null || plan.languageCode == 'en' || Test.isRunningTest()) {
            return;
        }
        try {
            Map<String, Object> englishResponse = fetchPageLayoutMetadata(plan.objectApiName, layoutKey, 'en');
            Map<String, String> englishLabelsByField = labelsByFieldFromLayoutResponse(englishResponse, objectDescribe);
            Integer unchangedFieldCount = 0;
            for (PageLayoutImportField fieldSpec : plan.fields) {
                String englishLabel = englishLabelsByField.get(String.valueOf(fieldSpec.apiName).toLowerCase());
                if (String.isNotBlank(englishLabel) && englishLabel == fieldSpec.label) {
                    unchangedFieldCount++;
                }
            }
            if (unchangedFieldCount > 0) {
                plan.warnings.add(
                    'Salesforce returned base labels for ' +
                    String.valueOf(unchangedFieldCount) +
                    ' imported fields. Check Translation Workbench for missing translations.'
                );
            }
        } catch (Exception ignored) {
            // Translation diagnostics should not block layout import.
        }
    }

    private static Map<String, String> labelsByFieldFromLayoutResponse(Map<String, Object> response, Schema.DescribeSObjectResult objectDescribe) {
        Map<String, String> labelsByField = new Map<String, String>();
        if (response == null || objectDescribe == null) {
            return labelsByField;
        }
        Map<String, Object> layoutMap = response.get('layout') instanceof Map<String, Object>
            ? (Map<String, Object>) response.get('layout')
            : null;
        if (layoutMap == null) {
            return labelsByField;
        }
        Map<String, Schema.SObjectField> fieldsMap = objectDescribe.fields.getMap();
        List<Object> rawSections = layoutMap.get('sections') instanceof List<Object>
            ? (List<Object>) layoutMap.get('sections')
            : new List<Object>();
        for (Object rawSectionValue : rawSections) {
            if (!(rawSectionValue instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> rawSection = (Map<String, Object>) rawSectionValue;
            List<Object> rawFields = rawSection.get('fields') instanceof List<Object>
                ? (List<Object>) rawSection.get('fields')
                : new List<Object>();
            for (Object rawFieldValue : rawFields) {
                if (!(rawFieldValue instanceof Map<String, Object>)) {
                    continue;
                }
                Map<String, Object> rawField = (Map<String, Object>) rawFieldValue;
                String canonicalField = canonicalFieldName(fieldsMap, stringValue(rawField.get('apiName')));
                String label = stringValue(rawField.get('label'));
                if (String.isNotBlank(canonicalField) && String.isNotBlank(label)) {
                    labelsByField.put(canonicalField.toLowerCase(), label);
                }
            }
        }
        return labelsByField;
    }

    private static Boolean layoutFieldEditableForNew(Map<String, Object> rawField) {
        if (rawField == null) {
            return false;
        }
        return !rawField.containsKey('editableForNew') || booleanValue(rawField.get('editableForNew'));
    }

    private static Boolean isIgnoredPageLayoutSystemField(String fieldApiName) {
        if (String.isBlank(fieldApiName)) {
            return false;
        }
        return new Set<String>{
            'OwnerId',
            'CreatedById',
            'CreatedDate',
            'LastModifiedById',
            'LastModifiedDate',
            'SystemModstamp',
            'LastActivityDate',
            'LastViewedDate',
            'LastReferencedDate',
            'IsDeleted'
        }.contains(fieldApiName);
    }

    private static Boolean layoutFieldEditableForUpdate(Map<String, Object> rawField) {
        if (rawField == null) {
            return false;
        }
        return !rawField.containsKey('editableForUpdate') || booleanValue(rawField.get('editableForUpdate'));
    }

    private static String layoutFieldLabel(Map<String, Object> rawField, String fallback) {
        if (rawField != null && String.isNotBlank(stringValue(rawField.get('label')))) {
            return stringValue(rawField.get('label'));
        }
        return String.isBlank(fallback) ? 'Unknown field' : fallback;
    }

    private static String pageLayoutFieldInclusionMode(Map<String, Object> rawField, Schema.DescribeFieldResult fieldDescribe, String mode) {
        if (fieldDescribe == null) {
            return null;
        }
        Boolean editableForNew = !rawField.containsKey('editableForNew') || booleanValue(rawField.get('editableForNew'));
        Boolean editableForUpdate = !rawField.containsKey('editableForUpdate') || booleanValue(rawField.get('editableForUpdate'));
        if (mode == 'create') {
            return editableForNew && fieldDescribe.isCreateable() ? 'always' : null;
        }
        if (mode == 'secureUpdateOrCreate') {
            if (editableForNew && fieldDescribe.isCreateable() && editableForUpdate && fieldDescribe.isUpdateable()) {
                return 'always';
            }
            if (editableForNew && fieldDescribe.isCreateable()) {
                return 'createOnly';
            }
            return null;
        }
        return editableForUpdate && fieldDescribe.isUpdateable() ? 'always' : null;
    }

    private static String pageLayoutFieldSkipMessage(Map<String, Object> rawField, Schema.DescribeFieldResult fieldDescribe, String mode) {
        Boolean editableForNew = layoutFieldEditableForNew(rawField);
        Boolean editableForUpdate = layoutFieldEditableForUpdate(rawField);
        Boolean createable = fieldDescribe != null && fieldDescribe.isCreateable();
        Boolean updateable = fieldDescribe != null && fieldDescribe.isUpdateable();
        if (mode == 'create') {
            return 'The selected create mode needs fields that are createable in Salesforce and editable for new records on the layout. This field does not meet that requirement.';
        }
        if (mode == 'secureUpdate') {
            return 'The selected secure edit mode needs fields that are updateable in Salesforce and editable for existing records on the layout. This field does not meet that requirement.';
        }
        if (editableForUpdate && updateable && (!editableForNew || !createable)) {
            return 'This field can be updated but cannot be sent when TwinaForms creates a missing record, so it was skipped for secure edit-or-create mode.';
        }
        return 'This field is not writable for the create or update path required by the selected submit mode.';
    }

    private static String pageLayoutFieldSkipChangeHint(String mode) {
        if (mode == 'create') {
            return 'Choose a createable field, or adjust Salesforce field-level security and page layout editability.';
        }
        if (mode == 'secureUpdate') {
            return 'Choose an updateable field, or adjust Salesforce field-level security and page layout editability.';
        }
        return 'Use Create only mode if you only need creation, or make the field writable for the path where it should be submitted.';
    }

    private static void addPageLayoutIncludedNote(
        PageLayoutImportPlan plan,
        String apiName,
        String label,
        String reason,
        String impact,
        String changeHint
    ) {
        if (plan == null) {
            return;
        }
        plan.includedNotes.add(new Map<String, Object>{
            'apiName' => apiName,
            'label' => label,
            'reason' => reason,
            'impact' => impact,
            'changeHint' => changeHint
        });
    }

    private static void addPageLayoutSkippedDetail(
        PageLayoutImportPlan plan,
        String apiName,
        String label,
        String reason,
        String impact,
        String changeHint
    ) {
        if (plan == null) {
            return;
        }
        plan.skippedDetails.add(new Map<String, Object>{
            'apiName' => apiName,
            'label' => label,
            'reason' => reason,
            'impact' => impact,
            'changeHint' => changeHint
        });
    }

    private static String buildPageLayoutImportDiagnosticsJson(PageLayoutImportPlan plan) {
        if (plan == null) {
            return '{}';
        }
        Map<String, Object> diagnostics = new Map<String, Object>{
            'objectApiName' => plan.objectApiName,
            'objectLabel' => plan.objectLabel,
            'layoutLabel' => plan.layoutLabel,
            'mode' => plan.mode,
            'summary' => new Map<String, Object>{
                'importedFieldCount' => plan.fields == null ? 0 : plan.fields.size(),
                'createOnlyFieldCount' => plan.createOnlyFieldCount,
                'skippedFieldCount' => plan.skippedFieldCount
            },
            'includedNotes' => plan.includedNotes,
            'skippedFields' => plan.skippedDetails,
            'warnings' => plan.warnings
        };
        return JSON.serializePretty(diagnostics);
    }

    private static PageLayoutImportField toPageLayoutImportField(Schema.DescribeFieldResult fieldDescribe) {
        if (fieldDescribe == null || !fieldDescribe.isAccessible()) {
            return null;
        }
        String fieldName = fieldDescribe.getName();
        if (fieldName == 'Id' || fieldDescribe.isCalculated() || fieldDescribe.isAutoNumber()) {
            return null;
        }

        PageLayoutImportField fieldSpec = new PageLayoutImportField();
        fieldSpec.apiName = fieldName;
        fieldSpec.label = fieldDescribe.getLabel();
        fieldSpec.required = !fieldDescribe.isNillable() && !fieldDescribe.isDefaultedOnCreate();
        fieldSpec.createOnly = false;
        fieldSpec.submitWhen = 'always';
        Schema.DisplayType fieldType = fieldDescribe.getType();

        if (fieldType == Schema.DisplayType.Boolean) {
            fieldSpec.elementType = 'checkbox';
            fieldSpec.required = false;
            return fieldSpec;
        }
        if (fieldType == Schema.DisplayType.TextArea) {
            fieldSpec.elementType = 'textarea';
            return fieldSpec;
        }
        if (fieldType == Schema.DisplayType.Email) {
            fieldSpec.elementType = 'email';
            return fieldSpec;
        }
        if (fieldType == Schema.DisplayType.Phone) {
            fieldSpec.elementType = 'tel';
            return fieldSpec;
        }
        if (fieldType == Schema.DisplayType.Url) {
            fieldSpec.elementType = 'url';
            return fieldSpec;
        }
        if (fieldType == Schema.DisplayType.Date) {
            fieldSpec.elementType = 'date';
            return fieldSpec;
        }
        if (fieldType == Schema.DisplayType.Time) {
            fieldSpec.elementType = 'time';
            return fieldSpec;
        }
        if (fieldType == Schema.DisplayType.Integer
            || fieldType == Schema.DisplayType.Double
            || fieldType == Schema.DisplayType.Currency
            || fieldType == Schema.DisplayType.Percent) {
            fieldSpec.elementType = 'number';
            return fieldSpec;
        }
        if (fieldType == Schema.DisplayType.Picklist) {
            fieldSpec.elementType = 'select';
            fieldSpec.options = picklistOptionsForImport(fieldDescribe);
            return fieldSpec.options.isEmpty() ? null : fieldSpec;
        }
        if (fieldType == Schema.DisplayType.MultiPicklist) {
            fieldSpec.elementType = 'multiCheckbox';
            fieldSpec.options = picklistOptionsForImport(fieldDescribe);
            return fieldSpec.options.isEmpty() ? null : fieldSpec;
        }
        if (fieldType == Schema.DisplayType.Reference) {
            List<Schema.SObjectType> targets = fieldDescribe.getReferenceTo();
            if (targets == null || targets.size() != 1) {
                return null;
            }
            Schema.DescribeSObjectResult targetDescribe = targets[0].getDescribe();
            if (!targetDescribe.isQueryable()) {
                return null;
            }
            fieldSpec.elementType = 'lookup';
            fieldSpec.lookupTargetObject = targetDescribe.getName();
            return fieldSpec;
        }
        if (fieldType == Schema.DisplayType.String) {
            fieldSpec.elementType = 'text';
            return fieldSpec;
        }
        return null;
    }

    private static List<Object> picklistOptionsForImport(Schema.DescribeFieldResult fieldDescribe) {
        List<Object> options = new List<Object>();
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (!entry.isActive()) {
                continue;
            }
            options.add(new Map<String, Object>{
                'label' => entry.getLabel(),
                'value' => entry.getValue()
            });
        }
        return options;
    }

    private static List<Object> picklistOptionsFromLayoutField(Map<String, Object> rawField) {
        List<Object> options = new List<Object>();
        Object rawOptions = rawField == null ? null : rawField.get('picklistValues');
        if (!(rawOptions instanceof List<Object>)) {
            rawOptions = rawField == null ? null : rawField.get('options');
        }
        if (!(rawOptions instanceof List<Object>)) {
            return options;
        }
        Set<String> seenValues = new Set<String>();
        for (Object rawOption : (List<Object>) rawOptions) {
            if (!(rawOption instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> optionMap = (Map<String, Object>) rawOption;
            String optionValue = stringValue(optionMap.get('value'));
            if (String.isBlank(optionValue) || seenValues.contains(optionValue)) {
                continue;
            }
            String optionLabel = stringValue(optionMap.get('label'));
            options.add(new Map<String, Object>{
                'label' => String.isBlank(optionLabel) ? optionValue : optionLabel,
                'value' => optionValue
            });
            seenValues.add(optionValue);
        }
        return options;
    }

    private static List<NF_Form_Element__c> buildPageLayoutImportElements(
        Id versionId,
        PageLayoutImportPlan plan,
        Boolean secureMode,
        String prefillAlias,
        String submitActionKey,
        String languageCode
    ) {
        List<NF_Form_Element__c> elements = new List<NF_Form_Element__c>();
        Integer orderValue = 10;
        Integer elementIndex = 1;

        if (secureMode) {
            elements.add(new NF_Form_Element__c(
                Form_Version__c = versionId,
                Element_Id__c = 'layout-record-id',
                Element_Type__c = 'hidden',
                Field_Key__c = 'recordId',
                Element_Index__c = elementIndex++,
                Label__c = 'Record Id',
                Config_JSON__c = JSON.serializePretty(new Map<String, Object>{
                    'fieldBehavior' => 'hidden',
                    'defaultValue' => '',
                    'prefillEnabled' => true,
                    'prefillAlias' => prefillAlias,
                    'prefillFieldPath' => 'Id',
                    'submitEnabled' => false
                }),
                Order__c = orderValue
            ));
            orderValue += 10;
        }

        Set<String> usedFieldKeys = new Set<String>{ 'recordId', 'layoutSection' };
        Integer sectionIndex = 1;
        for (PageLayoutImportSection sectionSpec : plan.sections) {
            String sectionElementId = 'layout-section-' + String.valueOf(sectionIndex);
            String sectionFieldKey = uniqueImportedFieldKey('layoutSection' + String.valueOf(sectionIndex), usedFieldKeys);
            elements.add(new NF_Form_Element__c(
                Form_Version__c = versionId,
                Element_Id__c = sectionElementId,
                Element_Type__c = 'section',
                Field_Key__c = sectionFieldKey,
                Element_Index__c = elementIndex++,
                Label__c = String.isBlank(sectionSpec.heading) ? plan.objectLabel + ' Details' : sectionSpec.heading,
                Config_JSON__c = JSON.serializePretty(new Map<String, Object>{
                    'text' => '',
                    'columns' => 2,
                    'showTitle' => true,
                    'boxed' => true
                }),
                Order__c = orderValue
            ));
            orderValue += 10;

            Integer column = 2;
            for (PageLayoutImportField fieldSpec : sectionSpec.fields) {
                String fieldKey = uniqueImportedFieldKey(fieldSpec.apiName, usedFieldKeys);
                Map<String, Object> config = configForImportedField(fieldSpec, plan.objectApiName, secureMode, prefillAlias, submitActionKey, languageCode);
                config.put('sectionColumn', column);
                elements.add(new NF_Form_Element__c(
                    Form_Version__c = versionId,
                    Element_Id__c = 'layout-' + fieldKey,
                    Element_Type__c = fieldSpec.elementType,
                    Field_Key__c = fieldKey,
                    Element_Index__c = elementIndex++,
                    Label__c = fieldSpec.label,
                    Config_JSON__c = JSON.serializePretty(config),
                    Parent_Element_Id__c = sectionElementId,
                    Order__c = orderValue
                ));
                orderValue += 10;
                column = column == 2 ? 1 : 2;
            }
            sectionIndex++;
        }
        return elements;
    }

    private static List<NF_Form_Element__c> filterStorableImportedElements(List<NF_Form_Element__c> elements, PageLayoutImportPlan plan) {
        List<NF_Form_Element__c> storable = new List<NF_Form_Element__c>();
        if (elements == null) {
            return storable;
        }
        for (NF_Form_Element__c elementRecord : elements) {
            elementRecord.Label__c = truncateText(elementRecord.Label__c, ELEMENT_LABEL_MAX_LENGTH);
            Integer configLength = String.isBlank(elementRecord.Config_JSON__c) ? 0 : elementRecord.Config_JSON__c.length();
            if (configLength > ELEMENT_CONFIG_JSON_MAX_LENGTH) {
                if (plan != null) {
                    plan.skippedFieldCount++;
                    addPageLayoutSkippedDetail(
                        plan,
                        elementRecord.Field_Key__c,
                        elementRecord.Label__c,
                        'Too many choices to store',
                        'This field generated more option/configuration data than Salesforce can store in the TwinaForms element record.',
                        'Reduce the number of active Salesforce picklist values for this field, or add the field manually later with a smaller choice set.'
                    );
                    plan.warnings.add('One field was skipped because its generated options were too large to store.');
                }
                continue;
            }
            storable.add(elementRecord);
        }
        return storable;
    }

    private static String truncateText(String value, Integer maxLength) {
        if (String.isBlank(value) || maxLength == null || maxLength <= 0 || value.length() <= maxLength) {
            return value;
        }
        return value.substring(0, maxLength);
    }

    private static String dmlMessage(DmlException e) {
        if (e == null) {
            return 'Salesforce did not return more details.';
        }
        try {
            if (e.getNumDml() > 0 && String.isNotBlank(e.getDmlMessage(0))) {
                return e.getDmlMessage(0);
            }
        } catch (Exception ignored) {
        }
        return String.isBlank(e.getMessage()) ? 'Salesforce did not return more details.' : e.getMessage();
    }

    private static Map<String, Object> configForImportedField(
        PageLayoutImportField fieldSpec,
        String objectApiName,
        Boolean secureMode,
        String prefillAlias,
        String submitActionKey,
        String languageCode
    ) {
        Map<String, Object> config = new Map<String, Object>{
            'labelPosition' => fieldSpec.elementType == 'checkbox' ? 'inline' : 'above',
            'fieldBehavior' => fieldSpec.createOnly == true ? 'readonlyWhenPrefilled' : 'editable',
            'required' => fieldSpec.required == true,
            'defaultValue' => '',
            'submitEnabled' => true,
            'submitActionKey' => submitActionKey,
            'submitFieldPath' => fieldSpec.apiName,
            'submitWhen' => String.isBlank(fieldSpec.submitWhen) ? 'always' : fieldSpec.submitWhen
        };
        if (secureMode) {
            config.put('prefillEnabled', true);
            config.put('prefillAlias', prefillAlias);
            config.put('prefillFieldPath', fieldSpec.apiName);
        }
        if (fieldSpec.elementType == 'textarea') {
            config.put('rows', 4);
            config.put('maxLength', 254);
            config.put('placeholder', NativeFormsRuntimeI18n.text(languageCode, 'placeholderTextarea', 'Enter longer text'));
        } else if (fieldSpec.elementType == 'number') {
            config.put('placeholder', NativeFormsRuntimeI18n.text(languageCode, 'placeholderNumber', 'Enter number'));
            config.put('isFormula', false);
            config.put('formulaExpression', '');
        } else if (fieldSpec.elementType == 'email') {
            config.put('placeholder', NativeFormsRuntimeI18n.text(languageCode, 'placeholderEmail', 'name@example.com'));
        } else if (fieldSpec.elementType == 'tel') {
            config.put('placeholder', NativeFormsRuntimeI18n.text(languageCode, 'placeholderPhone', 'Phone number'));
        } else if (fieldSpec.elementType == 'url') {
            config.put('placeholder', NativeFormsRuntimeI18n.text(languageCode, 'placeholderUrl', 'https://example.com'));
        } else if (fieldSpec.elementType == 'checkbox') {
            config.put('checked', false);
        } else if (fieldSpec.elementType == 'select' || fieldSpec.elementType == 'multiCheckbox') {
            config.put('sourceObjectApiName', objectApiName);
            config.put('sourcePicklistFieldApiName', fieldSpec.apiName);
            config.put('options', fieldSpec.options == null ? new List<Object>() : fieldSpec.options);
        } else if (fieldSpec.elementType == 'lookup') {
            config.put('placeholder', NativeFormsRuntimeI18n.text(languageCode, 'lookupSearchPlaceholder', 'Search records'));
            config.put('lookupTargetObject', fieldSpec.lookupTargetObject);
            config.put('lookupSearchFields', new List<Object>{ 'Name' });
            config.put('lookupDisplayFields', new List<Object>{ 'Name' });
            config.put('lookupMinSearchLength', 2);
            config.put('lookupLimit', 10);
        } else if (fieldSpec.elementType == 'date') {
            config.put('dateDisplayFormat', 'us');
            config.put('dateGmtOffset', '+00:00');
        } else if (fieldSpec.elementType == 'time') {
            config.put('placeholder', '19:00');
            config.put('timeFormat', '24h');
        } else {
            config.put('placeholder', NativeFormsRuntimeI18n.text(languageCode, 'placeholderText', 'Enter text'));
            config.put('isFormula', false);
            config.put('formulaExpression', '');
        }
        return config;
    }

    private static String uniqueImportedFieldKey(String fieldApiName, Set<String> usedKeys) {
        String baseKey = String.isBlank(fieldApiName) ? 'field' : fieldApiName.replaceAll('[^A-Za-z0-9_]', '_');
        if (baseKey.endsWith('__c')) {
            baseKey = baseKey.substring(0, baseKey.length() - 3);
        }
        if (String.isBlank(baseKey)) {
            baseKey = 'field';
        }
        String firstChar = baseKey.substring(0, 1);
        if (firstChar.replaceAll('[A-Za-z]', '') != '') {
            baseKey = 'field_' + baseKey;
        }
        if (baseKey.length() > 40) {
            baseKey = baseKey.substring(0, 40);
        }
        String candidate = baseKey;
        Integer counter = 2;
        while (usedKeys.contains(candidate)) {
            String suffix = '_' + String.valueOf(counter);
            Integer maxBaseLength = 40 - suffix.length();
            if (maxBaseLength < 1) {
                maxBaseLength = 1;
            }
            candidate = (baseKey.length() > maxBaseLength ? baseKey.substring(0, maxBaseLength) : baseKey) + suffix;
            counter++;
        }
        usedKeys.add(candidate);
        return candidate;
    }

    private static String normalizePageLayoutImportMode(String mode) {
        String normalized = String.isBlank(mode) ? 'secureUpdateOrCreate' : mode.trim();
        return new Set<String>{ 'secureUpdate', 'secureUpdateOrCreate', 'create' }.contains(normalized)
            ? normalized
            : 'secureUpdateOrCreate';
    }

    private static String normalizePageLayoutImportLayoutKey(String layoutKey) {
        if (String.isBlank(layoutKey) || layoutKey == 'defaultSupportedFields') {
            return 'assigned:default';
        }
        String normalized = layoutKey.trim();
        if (normalized.startsWith('assigned:')) {
            return normalized;
        }
        throw new AuraHandledException('Select a supported Salesforce page layout source.');
    }

    private static String pageLayoutImportActionName(String prefix, String objectApiName) {
        String normalizedPrefix = String.isBlank(prefix) ? 'Action' : prefix.trim();
        String objectToken = String.isBlank(objectApiName) ? 'Record' : objectApiName.trim();
        objectToken = objectToken.replaceAll('[^A-Za-z0-9_]', '_').replaceAll('_+', '_').replaceAll('^_+|_+$', '');
        if (String.isBlank(objectToken)) {
            objectToken = 'Record';
        }
        if (Pattern.matches('^[0-9].*', objectToken)) {
            objectToken = 'Object_' + objectToken;
        }

        String actionName = normalizedPrefix + '_' + objectToken;
        return actionName.length() > 120 ? actionName.substring(0, 120) : actionName;
    }

    private static String buildPageLayoutImportUiSettingsJson(Boolean secureMode, String languageCode) {
        String normalizedLanguageCode = defaultLanguageCode(languageCode);
        Map<String, Object> uiSettings = new Map<String, Object>{
            'languageCode' => normalizedLanguageCode,
            'submitSuccessMessage' => localizedFormSettingDefault('submitSuccessMessage', normalizedLanguageCode, 'Your form was submitted successfully.'),
            'submitLabel' => localizedFormSettingDefault('submitLabel', normalizedLanguageCode, 'Submit'),
            'rtlEnabled' => normalizedLanguageCode == 'he',
            'userVerificationEnabled' => secureMode == true,
            'userVerificationMatchField' => 'Email',
            'userVerificationIntroText' => NativeFormsRuntimeI18n.text(normalizedLanguageCode, 'userVerificationIntroText', ''),
            'userVerificationSentMessage' => NativeFormsRuntimeI18n.text(normalizedLanguageCode, 'userVerificationSentMessage', ''),
            'userVerificationInvalidMessage' => NativeFormsRuntimeI18n.text(normalizedLanguageCode, 'userVerificationInvalidMessage', ''),
            'userVerificationVerifiedMessage' => NativeFormsRuntimeI18n.text(normalizedLanguageCode, 'userVerificationVerifiedMessage', ''),
            'userVerificationSendButtonLabel' => NativeFormsRuntimeI18n.text(normalizedLanguageCode, 'userVerificationSendButtonLabel', ''),
            'userVerificationVerifyButtonLabel' => NativeFormsRuntimeI18n.text(normalizedLanguageCode, 'userVerificationVerifyButtonLabel', ''),
            'userVerificationResendButtonLabel' => NativeFormsRuntimeI18n.text(normalizedLanguageCode, 'userVerificationResendButtonLabel', ''),
            'userVerificationExpiryMinutes' => 10,
            'userVerificationMaxAttempts' => 5,
            'userVerificationAllowResend' => true,
            'userVerificationSessionMode' => 'short'
        };
        return JSON.serializePretty(uiSettings);
    }

    private static String buildPageLayoutImportPrefillParamsJson(String mode, String languageCode) {
        Boolean recordIdRequired = normalizePageLayoutImportMode(mode) == 'secureUpdate';
        return JSON.serializePretty(new List<Object>{
            new Map<String, Object>{ 'key' => 'recordId', 'label' => localizedRecordIdLabel(languageCode), 'required' => recordIdRequired },
            new Map<String, Object>{ 'key' => 'email', 'label' => defaultLabelForType('email', null, languageCode), 'required' => false }
        });
    }

    private static String localizedRecordIdLabel(String languageCode) {
        String normalizedLanguageCode = defaultLanguageCode(languageCode);
        if (normalizedLanguageCode == 'he') return '\u05DE\u05D6\u05D4\u05D4 \u05E8\u05E9\u05D5\u05DE\u05D4';
        if (normalizedLanguageCode == 'es') return 'Id. de registro';
        if (normalizedLanguageCode == 'de') return 'Datensatz-ID';
        if (normalizedLanguageCode == 'fr') return 'ID enregistrement';
        return 'Record Id';
    }

    private static String titleFromFileName(String fileName) {
        if (String.isBlank(fileName)) {
            return 'TwinaForms Image';
        }
        Integer dotIndex = fileName.lastIndexOf('.');
        return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    }

    private static String buildContentVersionUrl(Id contentVersionId) {
        return '/sfc/servlet.shepherd/version/download/' + String.valueOf(contentVersionId);
    }

    private static String stringValue(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Boolean booleanValue(Object value) {
        if (value == null) {
            return false;
        }
        if (value instanceof Boolean) {
            return (Boolean) value;
        }
        return String.valueOf(value).toLowerCase() == 'true';
    }

    private static Integer integerValue(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Integer) {
            return (Integer) value;
        }
        try {
            return Integer.valueOf(String.valueOf(value).trim());
        } catch (Exception ignored) {
            return null;
        }
    }

    private static String defaultSubmitSuccessMessage(String value, String languageCode) {
        return localizedFormSettingValue(
            value,
            languageCode,
            'submitSuccessMessage',
            'Your form was submitted successfully.'
        );
    }

    private static String defaultLanguageCode(String value) {
        String normalized = String.isBlank(value) ? 'en' : value.trim().toLowerCase();
        Set<String> allowed = new Set<String>{ 'en', 'he', 'es', 'de', 'fr' };
        return allowed.contains(normalized) ? normalized : 'en';
    }

    private static String defaultSubmitLabel(String value, String languageCode) {
        return localizedFormSettingValue(
            value,
            languageCode,
            'submitLabel',
            'Submit'
        );
    }

    private static String defaultPostSubmitUrlTemplate(String value) {
        return String.isBlank(value) ? '' : value.trim();
    }

    private static String defaultPostSubmitUrlMode(String value) {
        return String.isNotBlank(value) && value.trim().toLowerCase() == 'formula' ? 'formula' : 'template';
    }

    private static String defaultUserVerificationMatchField(String value) {
        return 'Email';
    }

    private static String defaultUserVerificationIntroText(String value, String languageCode) {
        return localizedUserVerificationValue(
            value,
            languageCode,
            'userVerificationIntroText',
            'Enter your email and click Enter. We will send you a 6-digit code before you can continue.'
        );
    }

    private static String defaultUserVerificationSentMessage(String value, String languageCode) {
        return localizedUserVerificationValue(
            value,
            languageCode,
            'userVerificationSentMessage',
            'If we found a matching contact, we sent a 6-digit code to that email.'
        );
    }

    private static String defaultUserVerificationInvalidMessage(String value, String languageCode) {
        return localizedUserVerificationValue(
            value,
            languageCode,
            'userVerificationInvalidMessage',
            'The code is invalid or expired. Try again or request a new code.'
        );
    }

    private static String defaultUserVerificationVerifiedMessage(String value, String languageCode) {
        return localizedUserVerificationValue(
            value,
            languageCode,
            'userVerificationVerifiedMessage',
            'Code verified. You can continue with the form now.'
        );
    }

    private static String defaultUserVerificationSendButtonLabel(String value, String languageCode) {
        return localizedUserVerificationValue(
            value,
            languageCode,
            'userVerificationSendButtonLabel',
            'Enter'
        );
    }

    private static String defaultUserVerificationVerifyButtonLabel(String value, String languageCode) {
        return localizedUserVerificationValue(
            value,
            languageCode,
            'userVerificationVerifyButtonLabel',
            'Verify'
        );
    }

    private static String defaultUserVerificationResendButtonLabel(String value, String languageCode) {
        return localizedUserVerificationValue(
            value,
            languageCode,
            'userVerificationResendButtonLabel',
            'Resend Verification Number'
        );
    }

    private static String localizedUserVerificationValue(String value, String languageCode, String key, String fallback) {
        String trimmedValue = String.isBlank(value) ? '' : value.trim();
        if (String.isBlank(trimmedValue) || NativeFormsRuntimeI18n.matchesAnyLanguageValue(key, trimmedValue)) {
            return NativeFormsRuntimeI18n.text(languageCode, key, fallback);
        }
        return trimmedValue;
    }

    private static Integer defaultUserVerificationExpiryMinutes(Object value) {
        Integer parsedValue = integerValue(value);
        return parsedValue == null || parsedValue < 1 ? 10 : parsedValue;
    }

    private static Integer defaultUserVerificationMaxAttempts(Object value) {
        Integer parsedValue = integerValue(value);
        return parsedValue == null || parsedValue < 1 ? 5 : parsedValue;
    }

    private static Boolean defaultUserVerificationAllowResend(Object value) {
        return value == null ? true : booleanValue(value);
    }

    private static String defaultUserVerificationSessionMode(String value) {
        String normalized = String.isBlank(value) ? 'short' : value.trim();
        return normalized == 'sameTabUntilMidnight' ? 'sameTabUntilMidnight' : 'short';
    }

    private static String defaultPostSubmitButtonLabel(String value, String languageCode) {
        return localizedFormSettingValue(
            value,
            languageCode,
            'postSubmitButtonLabel',
            'Continue'
        );
    }

    private static String localizedFormSettingValue(String value, String languageCode, String key, String fallback) {
        String trimmedValue = String.isBlank(value) ? '' : value.trim();
        if (String.isBlank(trimmedValue) || matchesLocalizedFormSettingDefault(key, trimmedValue)) {
            return localizedFormSettingDefault(key, languageCode, fallback);
        }
        return trimmedValue;
    }

    private static Boolean matchesLocalizedFormSettingDefault(String key, String candidate) {
        String trimmedCandidate = String.isBlank(candidate) ? '' : candidate.trim();
        if (String.isBlank(trimmedCandidate)) {
            return false;
        }
        for (String languageCode : new List<String>{ 'en', 'he', 'es', 'de', 'fr' }) {
            if (localizedFormSettingDefault(key, languageCode, '') == trimmedCandidate) {
                return true;
            }
        }
        return false;
    }

    private static String localizedFormSettingDefault(String key, String languageCode, String fallback) {
        String normalizedLanguageCode = defaultLanguageCode(languageCode);
        if (key == 'submitLabel') {
            if (normalizedLanguageCode == 'de') return 'Senden';
            if (normalizedLanguageCode == 'fr') return 'Envoyer';
            if (normalizedLanguageCode == 'he') return 'שלח';
            if (normalizedLanguageCode == 'es') return 'Enviar';
            return 'Submit';
        }
        if (key == 'submitSuccessMessage') {
            if (normalizedLanguageCode == 'de') return 'Ihr Formular wurde erfolgreich gesendet.';
            if (normalizedLanguageCode == 'fr') return 'Votre formulaire a été envoyé avec succès.';
            if (normalizedLanguageCode == 'he') return 'הטופס נשלח בהצלחה.';
            if (normalizedLanguageCode == 'es') return 'Tu formulario se envió correctamente.';
            return 'Your form was submitted successfully.';
        }
        if (key == 'postSubmitButtonLabel') {
            if (normalizedLanguageCode == 'de') return 'Weiter';
            if (normalizedLanguageCode == 'fr') return 'Continuer';
            if (normalizedLanguageCode == 'he') return 'המשך';
            if (normalizedLanguageCode == 'es') return 'Continuar';
            return 'Continue';
        }
        return fallback;
    }

    private static Integer defaultPostSubmitDelaySeconds(Object value) {
        if (value == null) {
            return 3;
        }
        Integer parsedValue;
        if (value instanceof Integer) {
            parsedValue = (Integer) value;
        } else {
            try {
                parsedValue = Integer.valueOf(String.valueOf(value).trim());
            } catch (Exception ignored) {
                parsedValue = 3;
            }
        }
        return parsedValue < 0 ? 0 : parsedValue;
    }

    private static String defaultSubmissionPdfTitle(String value) {
        String trimmedValue = String.isBlank(value) ? '' : value.trim();
        return String.isBlank(trimmedValue) ? 'Submitted Response' : trimmedValue.left(120);
    }

    private static String defaultConditionalOperator(String value) {
        String normalized = String.isBlank(value) ? 'equals' : value.trim();
        Set<String> allowed = new Set<String>{ 'equals', 'notEquals', 'isTrue', 'isFalse', 'isBlank', 'isNotBlank' };
        return allowed.contains(normalized) ? normalized : 'equals';
    }

    private static String defaultConditionalExpression(String value, Integer conditionCount) {
        if (conditionCount == null || conditionCount < 1) {
            return '';
        }
        if (String.isNotBlank(value)) {
            return value.trim();
        }
        List<String> references = new List<String>();
        for (Integer index = 1; index <= conditionCount; index += 1) {
            references.add(String.valueOf(index));
        }
        return String.join(references, ' AND ');
    }

    private static Map<String, Object> parseJsonMap(String rawJson) {
        if (String.isBlank(rawJson)) {
            return new Map<String, Object>();
        }
        try {
            return (Map<String, Object>) JSON.deserializeUntyped(rawJson);
        } catch (Exception e) {
            return new Map<String, Object>();
        }
    }

    private static List<Object> parseJsonList(Object rawValue) {
        if (rawValue == null) {
            return new List<Object>();
        }
        if (rawValue instanceof List<Object>) {
            return (List<Object>) rawValue;
        }
        String rawJson = String.valueOf(rawValue);
        if (String.isBlank(rawJson)) {
            return new List<Object>();
        }
        try {
            Object parsed = JSON.deserializeUntyped(rawJson);
            return parsed instanceof List<Object> ? (List<Object>) parsed : new List<Object>();
        } catch (Exception e) {
            return new List<Object>();
        }
    }

    private static List<Object> normalizeConditionalConditions(
        List<Object> rawConditions,
        String fallbackFieldKey,
        String fallbackOperator,
        String fallbackValue
    ) {
        List<Object> normalized = new List<Object>();
        if (rawConditions != null) {
            for (Object rawCondition : rawConditions) {
                if (!(rawCondition instanceof Map<String, Object>)) {
                    continue;
                }
                Map<String, Object> condition = (Map<String, Object>) rawCondition;
                String fieldKey = stringValue(condition.get('fieldKey'));
                String operator = defaultConditionalOperator(stringValue(condition.get('operator')));
                if (String.isBlank(fieldKey) || String.isBlank(operator)) {
                    continue;
                }
                normalized.add(new Map<String, Object>{
                    'fieldKey' => fieldKey,
                    'operator' => operator,
                    'value' => stringValue(condition.get('value'))
                });
            }
        }
        if (normalized.isEmpty() && String.isNotBlank(fallbackFieldKey)) {
            normalized.add(new Map<String, Object>{
                'fieldKey' => fallbackFieldKey,
                'operator' => defaultConditionalOperator(fallbackOperator),
                'value' => stringValue(fallbackValue)
            });
        }
        return normalized;
    }

    private static Integer readSectionColumn(String rawJson) {
        Map<String, Object> config = parseJsonMap(rawJson);
        if (!config.containsKey('sectionColumn')) {
            return null;
        }
        try {
            return Integer.valueOf(String.valueOf(config.get('sectionColumn')));
        } catch (Exception e) {
            return null;
        }
    }

    private static Integer readColumns(String rawJson) {
        Integer parsed = integerValue(parseJsonMap(rawJson).get('columns'));
        if (parsed == null || parsed < 1) {
            return 1;
        }
        return Math.min(10, parsed);
    }

    private static void validateContainerPlacement(NF_Form_Element__c sectionRecord, NF_Form_Element__c elementRecord) {
        if (elementRecord.Element_Type__c == 'repeatGroup') {
            throw new AuraHandledException('Repeat groups cannot be nested inside another container in this version.');
        }
        if (elementRecord.Element_Type__c == 'group') {
            throw new AuraHandledException('Groups cannot be nested inside another container in this version.');
        }
        if (sectionRecord.Element_Type__c == 'repeatGroup' && (elementRecord.Element_Type__c == 'section' || elementRecord.Element_Type__c == 'repeatGroup')) {
            throw new AuraHandledException('Repeat groups can contain fields and display elements, but not other containers.');
        }
        if (sectionRecord.Element_Type__c == 'repeatGroup' && elementRecord.Element_Type__c == 'fileUpload') {
            throw new AuraHandledException('File Upload fields are not supported inside repeat groups in Pro V1.');
        }
        if (sectionRecord.Element_Type__c == 'repeatGroup' && elementRecord.Element_Type__c == 'lookup') {
            throw new AuraHandledException('Lookup fields are not supported inside repeat groups in Starter V1.');
        }
        if (sectionRecord.Element_Type__c == 'repeatGroup' && elementRecord.Element_Type__c == 'location') {
            throw new AuraHandledException('Country / State / City fields are not supported inside Records Lists in Pro V1.');
        }
        if (sectionRecord.Element_Type__c == 'repeatGroup'
            && elementRecord.Element_Type__c == 'button'
            && booleanValue(parseJsonMap(elementRecord.Config_JSON__c).get('submitBeforeNavigation'))) {
            throw new AuraHandledException('Buttons inside Records Lists cannot submit the form in Pro V1.');
        }
        if (sectionRecord.Element_Type__c == 'group' && (elementRecord.Element_Type__c == 'section' || elementRecord.Element_Type__c == 'repeatGroup' || elementRecord.Element_Type__c == 'group')) {
            throw new AuraHandledException('Groups can contain fields and display elements, but not other containers.');
        }
    }

    private static void validateRecordsListSignaturePlacement(
        Id versionId,
        NF_Form_Element__c parentRecord,
        NF_Form_Element__c elementRecord
    ) {
        if (parentRecord == null || elementRecord == null
            || parentRecord.Element_Type__c != 'repeatGroup'
            || elementRecord.Element_Type__c != 'signature') {
            return;
        }
        if (!NativeFormsFeatureFlags.isProElectronicSignatureEnabled()
            || !NativeFormsFeatureFlags.isProSubmissionPdfEnabled()) {
            throw new AuraHandledException('A Signature inside a Records List requires Electronic Signature and Submission PDF on your Pro plan.');
        }
        List<NF_Form_Element__c> existingSignatures = [
            SELECT Id
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :versionId
              AND Parent_Element_Id__c = :parentRecord.Element_Id__c
              AND Element_Type__c = 'signature'
              AND Id != :elementRecord.Id
            WITH USER_MODE LIMIT 1
        ];
        if (!existingSignatures.isEmpty()) {
            throw new AuraHandledException('A Records List supports one Signature element in this version.');
        }
    }

    private static Boolean versionContainsRecordsListSignature(Id versionId) {
        if (versionId == null) {
            return false;
        }
        Set<String> recordsListIds = new Set<String>();
        for (NF_Form_Element__c record : [
            SELECT Element_Id__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :versionId
              AND Element_Type__c = 'repeatGroup'
            WITH USER_MODE
        ]) {
            recordsListIds.add(record.Element_Id__c);
        }
        if (recordsListIds.isEmpty()) {
            return false;
        }
        return ![
            SELECT Id
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :versionId
              AND Element_Type__c = 'signature'
              AND Parent_Element_Id__c IN :recordsListIds
            WITH USER_MODE LIMIT 1
        ].isEmpty();
    }

    private static void enableSubmissionPdfForRecordsListSignature(Id versionId) {
        NF_Form_Version__c versionRecord = [
            SELECT Id, UI_Settings_JSON__c
            FROM NF_Form_Version__c
            WHERE Id = :versionId
            WITH USER_MODE LIMIT 1
        ];
        Map<String, Object> uiSettings = parseJsonMap(versionRecord.UI_Settings_JSON__c);
        if (booleanValue(uiSettings.get('submissionPdfEnabled'))) {
            return;
        }
        uiSettings.put('submissionPdfEnabled', true);
        if (!uiSettings.containsKey('submissionPdfAttachToRecord')) {
            uiSettings.put('submissionPdfAttachToRecord', true);
        }
        if (!uiSettings.containsKey('submissionPdfTitle')) {
            uiSettings.put('submissionPdfTitle', 'Submitted Response');
        }
        if (!uiSettings.containsKey('submissionPdfIncludeEmptyFields')) {
            uiSettings.put('submissionPdfIncludeEmptyFields', true);
        }
        update as user new NF_Form_Version__c(
            Id = versionRecord.Id,
            UI_Settings_JSON__c = JSON.serializePretty(uiSettings)
        );
    }

    private static String canonicalObjectName(String requestedObjectName) {
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (globalDescribe.containsKey(requestedObjectName)) {
            return globalDescribe.get(requestedObjectName).getDescribe().getName();
        }
        for (String apiName : globalDescribe.keySet()) {
            if (apiName.equalsIgnoreCase(requestedObjectName)) {
                return globalDescribe.get(apiName).getDescribe().getName();
            }
        }
        return null;
    }

    private static String canonicalFieldName(Map<String, Schema.SObjectField> fieldsMap, String requestedFieldName) {
        if (fieldsMap.containsKey(requestedFieldName)) {
            return fieldsMap.get(requestedFieldName).getDescribe().getName();
        }
        for (String fieldApiName : fieldsMap.keySet()) {
            if (fieldApiName.equalsIgnoreCase(requestedFieldName)) {
                return fieldsMap.get(fieldApiName).getDescribe().getName();
            }
        }
        return null;
    }

    private static List<SelectOption> getReadableFieldOptions(String objectApiName) {
        List<SelectOption> options = new List<SelectOption>();
        if (String.isBlank(objectApiName)) {
            return options;
        }

        String canonicalObject = canonicalObjectName(objectApiName);
        if (String.isBlank(canonicalObject)) {
            return options;
        }

        Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get(canonicalObject).getDescribe().fields.getMap();
        for (String fieldApiName : fieldsMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldApiName).getDescribe();
            if (!fieldDescribe.isAccessible()) {
                continue;
            }
            SelectOption option = new SelectOption();
            option.label = fieldDescribe.getLabel() + ' (' + fieldDescribe.getName() + ')';
            option.value = fieldDescribe.getName();
            options.add(option);
        }
        sortOptionsByLabel(options);
        return options;
    }

    private static List<SelectOption> getWritableFieldOptions(String objectApiName) {
        List<SelectOption> options = new List<SelectOption>();
        if (String.isBlank(objectApiName)) {
            return options;
        }

        String canonicalObject = canonicalObjectName(objectApiName);
        if (String.isBlank(canonicalObject)) {
            return options;
        }

        Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get(canonicalObject).getDescribe().fields.getMap();
        for (String fieldApiName : fieldsMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldApiName).getDescribe();
            if (!fieldDescribe.isAccessible()) {
                continue;
            }
            if (fieldDescribe.getName() == 'Id') {
                SelectOption idOption = new SelectOption();
                idOption.label = fieldDescribe.getLabel() + ' (' + fieldDescribe.getName() + ')';
                idOption.value = fieldDescribe.getName();
                options.add(idOption);
                continue;
            }
            if (!fieldDescribe.isCreateable() && !fieldDescribe.isUpdateable()) {
                continue;
            }
            if (fieldDescribe.isCalculated() || fieldDescribe.isAutoNumber()) {
                continue;
            }
            SelectOption option = new SelectOption();
            option.label = fieldDescribe.getLabel() + ' (' + fieldDescribe.getName() + ')';
            option.value = fieldDescribe.getName();
            options.add(option);
        }
        sortOptionsByLabel(options);
        return options;
    }

    private static String formatVersionDisplay(Decimal versionNumber, String fallbackName) {
        if (versionNumber != null) {
            return 'V' + String.valueOf(Integer.valueOf(String.valueOf(versionNumber)));
        }
        return fallbackName;
    }

    private static String pickPreferredPicklistValue(Schema.SObjectField fieldRef, List<String> preferredValues) {
        Schema.DescribeFieldResult describeResult = fieldRef.getDescribe();
        List<Schema.PicklistEntry> entries = describeResult.getPicklistValues();
        for (String preferredValue : preferredValues) {
            for (Schema.PicklistEntry entry : entries) {
                if (entry.getValue() == preferredValue && entry.isActive()) {
                    return entry.getValue();
                }
            }
        }
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                return entry.getValue();
            }
        }
        return null;
    }

    private static void ensureVersionEditable(Id versionId) {
        NF_Form_Version__c versionRecord = [
            SELECT Id, Version_Status__c
            FROM NF_Form_Version__c
            WHERE Id = :versionId
            WITH USER_MODE LIMIT 1
        ];
        if (versionRecord.Version_Status__c == 'Published') {
            throw new AuraHandledException('Published versions are read-only. Open the latest draft version to continue editing.');
        }
    }

    private static void ensureElementVersionEditable(Id elementId) {
        NF_Form_Element__c elementRecord = [
            SELECT Id, Form_Version__c
            FROM NF_Form_Element__c
            WHERE Id = :elementId
            WITH USER_MODE LIMIT 1
        ];
        ensureVersionEditable(elementRecord.Form_Version__c);
    }

    private static Integer getNextElementIndex(Id formId) {
        if (formId == null) {
            return 1;
        }
        AggregateResult[] rows = [
            SELECT MAX(Element_Index__c) maxIndex
            FROM NF_Form_Element__c
            WHERE Form_Version__r.Form__c = :formId WITH USER_MODE
        ];
        if (!rows.isEmpty() && rows[0].get('maxIndex') != null) {
            return Integer.valueOf(String.valueOf(rows[0].get('maxIndex'))) + 1;
        }
        return 1;
    }

    public class VersionSorter implements Comparator<NF_Form_Version__c> {
        private Id publishedVersionId;

        public VersionSorter(Id publishedVersionId) {
            this.publishedVersionId = publishedVersionId;
        }

        public Integer compare(NF_Form_Version__c a, NF_Form_Version__c b) {
            return String.valueOf(b.Name).toLowerCase().compareTo(String.valueOf(a.Name).toLowerCase());
        }
    }
}
