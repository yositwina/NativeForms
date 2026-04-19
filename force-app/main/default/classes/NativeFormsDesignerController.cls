public with sharing class NativeFormsDesignerController {
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

    public class DesignerWorkspace {
        @AuraEnabled public Id selectedFormId { get; set; }
        @AuraEnabled public Id selectedVersionId { get; set; }
        @AuraEnabled public Id selectedThemeId { get; set; }
        @AuraEnabled public String selectedFormName { get; set; }
        @AuraEnabled public String selectedFormKey { get; set; }
        @AuraEnabled public String selectedFormDescription { get; set; }
        @AuraEnabled public Boolean selectedFormCaptchaEnabled { get; set; }
        @AuraEnabled public Boolean captchaKeysConfigured { get; set; }
        @AuraEnabled public String selectedVersionName { get; set; }
        @AuraEnabled public String selectedVersionStatus { get; set; }
        @AuraEnabled public String selectedVersionSubmitSuccessMessage { get; set; }
        @AuraEnabled public Boolean selectedVersionRtlEnabled { get; set; }
        @AuraEnabled public String selectedPublishedUrl { get; set; }
        @AuraEnabled public List<SelectOption> forms { get; set; }
        @AuraEnabled public List<VersionOption> versions { get; set; }
        @AuraEnabled public List<SelectOption> themes { get; set; }
        @AuraEnabled public ThemeRecord selectedTheme { get; set; }
        @AuraEnabled public List<ElementRecord> elements { get; set; }
        @AuraEnabled public List<PrefillAliasDetail> prefillAliases { get; set; }
        @AuraEnabled public List<SubmitActionDetail> submitActions { get; set; }
        @AuraEnabled public Boolean enableProRepeatGroups { get; set; }
    }

    public class NewFormResult {
        @AuraEnabled public Id formId { get; set; }
        @AuraEnabled public Id versionId { get; set; }
        @AuraEnabled public String formName { get; set; }
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
    public static List<SelectOption> getPicklistFieldOptions(String objectApiName) {
        List<SelectOption> options = new List<SelectOption>();
        if (String.isBlank(objectApiName)) {
            return options;
        }

        String canonicalObjectName = canonicalObjectName(objectApiName);
        if (String.isBlank(canonicalObjectName)) {
            return options;
        }

        Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get(canonicalObjectName).getDescribe().fields.getMap();
        List<String> fieldApiNames = new List<String>();
        for (String fieldApiName : fieldsMap.keySet()) {
            Schema.DescribeFieldResult describeResult = fieldsMap.get(fieldApiName).getDescribe();
            if (!describeResult.isAccessible()) {
                continue;
            }
            if (describeResult.getType() != Schema.DisplayType.Picklist) {
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
        if (describeResult.getType() != Schema.DisplayType.Picklist) {
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
    public static DesignerWorkspace getWorkspace(Id formId, Id versionId) {
        DesignerWorkspace workspace = new DesignerWorkspace();
        workspace.forms = new List<SelectOption>();
        workspace.versions = new List<VersionOption>();
        workspace.themes = new List<SelectOption>();
        workspace.elements = new List<ElementRecord>();
        workspace.prefillAliases = new List<PrefillAliasDetail>();
        workspace.submitActions = new List<SubmitActionDetail>();
        workspace.enableProRepeatGroups = NativeFormsFeatureFlags.isProRepeatGroupsEnabled();

        List<NF_Form__c> forms = [
            SELECT Id, Name, NF_Key__c, Description__c, Status__c, Current_Published_Version__c, Theme__c, Enable_Captcha__c
            FROM NF_Form__c
            ORDER BY Name ASC
            LIMIT 200
        ];

        workspace.captchaKeysConfigured = NativeFormsPublisher.hasSharedCaptchaSiteKey();

        for (NF_Form__c formRecord : forms) {
            SelectOption option = new SelectOption();
            option.label = formRecord.Description__c + (String.isNotBlank(formRecord.NF_Key__c) ? ' (' + formRecord.NF_Key__c + ')' : '');
            option.value = (String) formRecord.Id;
            workspace.forms.add(option);
        }
        sortOptionsByLabel(workspace.forms);

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
        workspace.selectedFormId = selectedForm.Id;
        workspace.selectedFormName = selectedForm.Description__c;
        workspace.selectedFormKey = selectedForm.NF_Key__c;
        workspace.selectedFormDescription = selectedForm.Description__c;
        workspace.selectedThemeId = selectedForm.Theme__c;
        workspace.selectedFormCaptchaEnabled = selectedForm.Enable_Captcha__c;

        for (NF_Theme__c themeRecord : [
            SELECT Id, Name
            FROM NF_Theme__c
            ORDER BY Name ASC
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
                LIMIT 1
            ]);
        }

        List<NF_Form_Version__c> versionRecords = [
            SELECT Id, Name, Version_Number__c, Version_Status__c, Publish_Status__c, LastModifiedDate, UI_Settings_JSON__c
            FROM NF_Form_Version__c
            WHERE Form__c = :effectiveFormId
            ORDER BY LastModifiedDate DESC
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
        workspace.selectedVersionSubmitSuccessMessage = defaultSubmitSuccessMessage(
            stringValue(versionUiSettings.get('submitSuccessMessage'))
        );
        workspace.selectedVersionRtlEnabled = booleanValue(versionUiSettings.get('rtlEnabled'));
        List<NF_Form_Publication__c> publicationRows = [
            SELECT Generated_HTML_Ref__c
            FROM NF_Form_Publication__c
            WHERE Form_Version__c = :effectiveVersionId
              AND Publication_Status__c = 'Success'
              AND Generated_HTML_Ref__c != null
            ORDER BY Published_At__c DESC, CreatedDate DESC
            LIMIT 1
        ];
        workspace.selectedPublishedUrl = publicationRows.isEmpty() ? null : publicationRows[0].Generated_HTML_Ref__c;

        for (NF_Form_Element__c elementRecord : [
            SELECT Id, Element_Id__c, Label__c, Element_Type__c, Field_Key__c, Element_Index__c, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :effectiveVersionId
            ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            workspace.elements.add(toElementRecord(elementRecord));
        }

        for (NF_Form_Action__c actionRecord : [
            SELECT Command_Key__c, Store_Result_As__c, Object_Api_Name__c
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :effectiveVersionId
              AND Action_Scope__c = 'Prefill'
              AND Store_Result_As__c != null
            ORDER BY Order__c ASC, CreatedDate ASC
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
            ORDER BY Order__c ASC, CreatedDate ASC
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
    public static void updateFormSettings(Id formId, Id versionId, String formName, Id themeId, Boolean enableCaptcha, String submitSuccessMessage, Boolean rtlEnabled) {
        if (formId == null) {
            throw new AuraHandledException('Form id is required.');
        }
        String normalizedFormName = String.isBlank(formName) ? null : formName.trim();
        if (String.isBlank(normalizedFormName)) {
            throw new AuraHandledException('Form name is required.');
        }

        NF_Form__c formRecord = [
            SELECT Id, Theme__c, Enable_Captcha__c, Description__c
            FROM NF_Form__c
            WHERE Id = :formId
            LIMIT 1
        ];
        formRecord.Description__c = normalizedFormName;
        formRecord.Theme__c = themeId;
        formRecord.Enable_Captcha__c = enableCaptcha == true;

        List<SObject> recordsToUpdate = new List<SObject>{ formRecord };
        if (versionId != null) {
            NF_Form_Version__c versionRecord = [
                SELECT Id, Form__c, UI_Settings_JSON__c
                FROM NF_Form_Version__c
                WHERE Id = :versionId
                LIMIT 1
            ];
            if (versionRecord.Form__c != formId) {
                throw new AuraHandledException('Selected version does not belong to the selected form.');
            }
            Map<String, Object> uiSettings = parseJsonMap(versionRecord.UI_Settings_JSON__c);
            uiSettings.put('submitSuccessMessage', defaultSubmitSuccessMessage(submitSuccessMessage));
            uiSettings.put('rtlEnabled', rtlEnabled == true);
            versionRecord.UI_Settings_JSON__c = JSON.serializePretty(uiSettings);
            recordsToUpdate.add(versionRecord);
        }

        update recordsToUpdate;
    }

    @AuraEnabled
    public static NewFormResult createFormWithDraftVersion(String description, Id themeId) {
        String normalizedDescription = String.isBlank(description) ? null : description.trim();
        if (String.isBlank(normalizedDescription)) {
            throw new AuraHandledException('Description is required.');
        }

        NF_Form__c formRecord = new NF_Form__c(
            Description__c = normalizedDescription,
            Status__c = 'Draft',
            Theme__c = themeId
        );
        insert formRecord;

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
        insert versionRecord;

        formRecord.Current_Draft_Version__c = versionRecord.Id;
        update formRecord;

        NewFormResult result = new NewFormResult();
        result.formId = formRecord.Id;
        result.versionId = versionRecord.Id;
        result.formName = normalizedDescription;
        return result;
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
            LIMIT 1
        ];

        List<NF_Form_Element__c> recordsToDelete = new List<NF_Form_Element__c>();
        if ((elementRecord.Element_Type__c == 'section' || elementRecord.Element_Type__c == 'repeatGroup' || elementRecord.Element_Type__c == 'group') && String.isNotBlank(elementRecord.Element_Id__c)) {
            recordsToDelete.addAll([
                SELECT Id
                FROM NF_Form_Element__c
                WHERE Parent_Element_Id__c = :elementRecord.Element_Id__c
            ]);
        }
        recordsToDelete.add(elementRecord);
        delete recordsToDelete;
    }

    @AuraEnabled
    public static ElementRecord addElement(Id versionId, String elementType) {
        if (versionId == null) {
            throw new AuraHandledException('Choose a form version first.');
        }
        ensureVersionEditable(versionId);
        if (String.isBlank(elementType)) {
            throw new AuraHandledException('Choose an element type first.');
        }
        if (!new Set<String>{ 'text', 'textarea', 'number', 'date', 'email', 'tel', 'url', 'checkbox', 'select', 'radio', 'section', 'group', 'heading', 'image', 'repeatGroup' }.contains(elementType)) {
            throw new AuraHandledException('This Designer prototype currently supports visual-only field and display elements.');
        }
        if (elementType == 'repeatGroup' && !NativeFormsFeatureFlags.isProRepeatGroupsEnabled()) {
            throw new AuraHandledException('Repeat Groups are not available on your current TwinaForms plan.');
        }

        NF_Form_Version__c versionRecord = [
            SELECT Id, Form__c
            FROM NF_Form_Version__c
            WHERE Id = :versionId
            LIMIT 1
        ];

        Integer nextOrder = 10;
        AggregateResult[] maxRows = [
            SELECT MAX(Order__c) maxOrder
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :versionId
        ];
        if (!maxRows.isEmpty() && maxRows[0].get('maxOrder') != null) {
            nextOrder = Integer.valueOf(String.valueOf(maxRows[0].get('maxOrder'))) + 10;
        }

        Integer nextElementIndex = getNextElementIndex(versionRecord.Form__c);

        NF_Form_Element__c elementRecord = new NF_Form_Element__c(
            Form_Version__c = versionId,
            Element_Id__c = buildElementId(elementType),
            Element_Type__c = elementType,
            Field_Key__c = defaultFieldKeyForType(elementType, nextElementIndex),
            Element_Index__c = nextElementIndex,
            Label__c = defaultLabelForType(elementType),
            Config_JSON__c = defaultConfigJsonForType(elementType),
            Order__c = nextOrder
        );
        insert elementRecord;

        elementRecord = [
            SELECT Id, Element_Id__c, Label__c, Element_Type__c, Field_Key__c, Element_Index__c, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Id = :elementRecord.Id
            LIMIT 1
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
            LIMIT 1
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
            ORDER BY Order__c ASC, CreatedDate ASC
        ];
        if (siblings.isEmpty()) {
            draggedRecord.Order__c = 10;
            update draggedRecord;
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
        for (NF_Form_Element__c sibling : siblings) {
            sibling.Order__c = orderValue;
            orderValue += 10;
        }
        update siblings;
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
        if (columnNumber == null || columnNumber < 1 || columnNumber > 4) {
            throw new AuraHandledException('Column number must be between 1 and 4.');
        }

        NF_Form_Element__c sectionRecord = [
            SELECT Id, Element_Id__c, Element_Type__c
            FROM NF_Form_Element__c
            WHERE Id = :sectionId
            LIMIT 1
        ];
        if (sectionRecord.Element_Type__c != 'section' && sectionRecord.Element_Type__c != 'repeatGroup' && sectionRecord.Element_Type__c != 'group') {
            throw new AuraHandledException('Only sections, groups, or repeat groups can receive dropped elements.');
        }

        NF_Form_Element__c elementRecord = [
            SELECT Id, Element_Type__c, Config_JSON__c, Parent_Element_Id__c
            FROM NF_Form_Element__c
            WHERE Id = :elementId
            LIMIT 1
        ];

        validateContainerPlacement(sectionRecord, elementRecord);

        Map<String, Object> config = parseJsonMap(elementRecord.Config_JSON__c);
        config.put('sectionColumn', columnNumber);
        elementRecord.Config_JSON__c = JSON.serializePretty(config);
        elementRecord.Parent_Element_Id__c = sectionRecord.Element_Id__c;
        update elementRecord;
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
            LIMIT 1
        ];
        NF_Form_Element__c anchorRecord = [
            SELECT Id, Form_Version__c, Element_Id__c, Element_Type__c, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Id = :anchorElementId
            LIMIT 1
        ];

        if (elementRecord.Form_Version__c != anchorRecord.Form_Version__c) {
            throw new AuraHandledException('Elements must belong to the same version.');
        }

        String targetParentElementId = anchorRecord.Parent_Element_Id__c;
        Integer targetColumn = readSectionColumn(anchorRecord.Config_JSON__c);
        if (targetParentElementId != null) {
            NF_Form_Element__c parentRecord = [
                SELECT Id, Element_Id__c, Element_Type__c
                FROM NF_Form_Element__c
                WHERE Element_Id__c = :targetParentElementId
                  AND Form_Version__c = :anchorRecord.Form_Version__c
                LIMIT 1
            ];
            validateContainerPlacement(parentRecord, elementRecord);
        }

        Map<String, Object> elementConfig = parseJsonMap(elementRecord.Config_JSON__c);
        if (targetParentElementId == null) {
            elementConfig.remove('sectionColumn');
        } else {
            elementConfig.put('sectionColumn', targetColumn == null ? 1 : targetColumn);
        }
        elementRecord.Config_JSON__c = JSON.serializePretty(elementConfig);
        elementRecord.Parent_Element_Id__c = targetParentElementId;

        List<NF_Form_Element__c> siblings = [
            SELECT Id, Order__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :anchorRecord.Form_Version__c
              AND Parent_Element_Id__c = :targetParentElementId
              AND Id != :elementId
            ORDER BY Order__c ASC, CreatedDate ASC
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
        for (NF_Form_Element__c sibling : siblings) {
            sibling.Order__c = orderValue;
            orderValue += 10;
        }
        update siblings;
    }

    @AuraEnabled
    public static ElementRecord updateSectionColumns(Id elementId, Integer columns) {
        if (elementId == null) {
            throw new AuraHandledException('Element id is required.');
        }
        ensureElementVersionEditable(elementId);
        if (columns == null || columns < 1 || columns > 4) {
            throw new AuraHandledException('Section columns must be between 1 and 4.');
        }

        NF_Form_Element__c elementRecord = [
            SELECT Id, Element_Id__c, Label__c, Element_Type__c, Field_Key__c, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Id = :elementId
            LIMIT 1
        ];

        if (elementRecord.Element_Type__c != 'section' && elementRecord.Element_Type__c != 'group') {
            throw new AuraHandledException('Only sections and groups can set column counts.');
        }

        Map<String, Object> config = parseJsonMap(elementRecord.Config_JSON__c);
        config.put('columns', columns);
        elementRecord.Config_JSON__c = JSON.serializePretty(config);
        update elementRecord;

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

        NF_Form_Element__c elementRecord = [
            SELECT Id, Element_Id__c, Label__c, Element_Type__c, Field_Key__c, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Id = :elementId
            LIMIT 1
        ];
        if (elementRecord.Element_Type__c != 'image') {
            throw new AuraHandledException('Only image elements can receive uploaded image files.');
        }

        ContentVersion versionRecord = new ContentVersion(
            Title = titleFromFileName(fileName),
            PathOnClient = fileName,
            VersionData = EncodingUtil.base64Decode(base64Data),
            FirstPublishLocationId = versionId
        );
        insert versionRecord;

        versionRecord = [
            SELECT Id, ContentDocumentId, Title
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
            LIMIT 1
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
        update elementRecord;

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
        if (elementType == 'section') return 'Section';
        if (elementType == 'repeatGroup') return 'Repeat Group';
        if (elementType == 'group') return 'Group';
        if (elementType == 'heading') return 'Display Text';
        if (elementType == 'image') return 'Image';
        if (elementType == 'checkbox') return 'Checkbox';
        if (elementType == 'textarea') return 'Textarea';
        if (elementType == 'number') return 'Number';
        if (elementType == 'date') return 'Date';
        if (elementType == 'email') return 'Email';
        if (elementType == 'tel') return 'Phone';
        if (elementType == 'url') return 'URL';
        if (elementType == 'select') return 'Picklist';
        if (elementType == 'radio') return 'Radio Group';
        return 'Text Input';
    }

    private static String defaultFieldKeyForType(String elementType, Integer elementIndex) {
        if (!new Set<String>{ 'text', 'textarea', 'number', 'date', 'email', 'tel', 'url', 'checkbox', 'select', 'radio', 'repeatGroup' }.contains(elementType)) {
            return null;
        }
        String prefix = 'field';
        if (elementType == 'checkbox') prefix = 'checkbox';
        if (elementType == 'textarea') prefix = 'textarea';
        if (elementType == 'number') prefix = 'number';
        if (elementType == 'date') prefix = 'date';
        if (elementType == 'email') prefix = 'email';
        if (elementType == 'tel') prefix = 'phone';
        if (elementType == 'url') prefix = 'url';
        if (elementType == 'select') prefix = 'picklist';
        if (elementType == 'radio') prefix = 'radio';
        if (elementType == 'text') prefix = 'text';
        if (elementType == 'repeatGroup') prefix = 'repeatGroup';
        Integer safeIndex = elementIndex == null || elementIndex <= 0 ? 1 : elementIndex;
        return prefix + String.valueOf(safeIndex);
    }

    private static String defaultConfigJsonForType(String elementType) {
        Map<String, Object> config = new Map<String, Object>();
        if (elementType == 'text') {
            config.put('defaultValue', 'Enter text');
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('required', false);
        }
        if (elementType == 'textarea') {
            config.put('defaultValue', 'Enter longer text');
            config.put('labelPosition', 'above');
            config.put('rows', 4);
            config.put('fieldBehavior', 'editable');
            config.put('required', false);
        }
        if (elementType == 'number') {
            config.put('defaultValue', 'Enter number');
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('required', false);
        }
        if (elementType == 'date') {
            config.put('defaultValue', '');
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('dateDisplayFormat', 'us');
            config.put('dateGmtOffset', '+00:00');
            config.put('required', false);
        }
        if (elementType == 'email') {
            config.put('defaultValue', 'name@example.com');
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('required', false);
        }
        if (elementType == 'tel') {
            config.put('defaultValue', 'Phone number');
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('required', false);
        }
        if (elementType == 'url') {
            config.put('defaultValue', 'https://example.com');
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
        if (elementType == 'select' || elementType == 'radio') {
            config.put('labelPosition', 'above');
            config.put('fieldBehavior', 'editable');
            config.put('defaultValue', 'option1');
            config.put('required', false);
            config.put('options', new List<Object>{
                new Map<String, Object>{ 'label' => 'Option 1', 'value' => 'option1' },
                new Map<String, Object>{ 'label' => 'Option 2', 'value' => 'option2' }
            });
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
        if (elementType == 'heading') {
            config.put('html', '<p>Display text</p>');
        }
        if (elementType == 'image') {
            config.put('imageUrl', '');
            config.put('altText', 'Image preview');
        }
        return JSON.serializePretty(config);
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

    private static String defaultSubmitSuccessMessage(String value) {
        return String.isBlank(value)
            ? 'Your form was submitted successfully.'
            : value.trim();
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
        if (sectionRecord.Element_Type__c == 'group' && (elementRecord.Element_Type__c == 'section' || elementRecord.Element_Type__c == 'repeatGroup' || elementRecord.Element_Type__c == 'group')) {
            throw new AuraHandledException('Groups can contain fields and display elements, but not other containers.');
        }
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
            LIMIT 1
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
            LIMIT 1
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
            WHERE Form_Version__r.Form__c = :formId
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
