public with sharing class NativeFormsSubmitActionsController {
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

    public class VersionOption {
        @AuraEnabled public Id value { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String status { get; set; }
    }

    public class SubmitActionRecord {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public Integer displayNumber { get; set; }
        @AuraEnabled public String actionKey { get; set; }
        @AuraEnabled public String commandType { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String storeResultAs { get; set; }
        @AuraEnabled public Integer orderValue { get; set; }
        @AuraEnabled public String configJson { get; set; }
    }

    public class SubmitWorkspace {
        @AuraEnabled public Id selectedVersionId { get; set; }
        @AuraEnabled public String selectedVersionName { get; set; }
        @AuraEnabled public String selectedVersionStatus { get; set; }
        @AuraEnabled public String selectedFormName { get; set; }
        @AuraEnabled public List<VersionOption> versions { get; set; }
        @AuraEnabled public List<SubmitActionRecord> actions { get; set; }
        @AuraEnabled public List<PrefillAliasDetail> prefillAliasDetails { get; set; }
        @AuraEnabled public List<SelectOption> objectOptions { get; set; }
        @AuraEnabled public List<SelectOption> formFieldOptions { get; set; }
        @AuraEnabled public List<SelectOption> repeatGroupOptions { get; set; }
        @AuraEnabled public List<MappingRecord> mappings { get; set; }
        @AuraEnabled public Boolean enableProConditionLogic { get; set; }
        @AuraEnabled public Boolean enableProRepeatGroups { get; set; }
        @AuraEnabled public Boolean enableProPrefillAliasReferences { get; set; }
        @AuraEnabled public Boolean enableProAdvancedSubmitModes { get; set; }
    }

    public class PrefillAliasDetail {
        @AuraEnabled public String alias { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public List<SelectOption> fieldOptions { get; set; }
    }

    public class MappingRecord {
        @AuraEnabled public Id elementId { get; set; }
        @AuraEnabled public String elementLabel { get; set; }
        @AuraEnabled public String fieldKey { get; set; }
        @AuraEnabled public String actionKey { get; set; }
        @AuraEnabled public String fieldPath { get; set; }
    }

    public class SubmitActionInput {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public Id versionId { get; set; }
        @AuraEnabled public String actionKey { get; set; }
        @AuraEnabled public String commandType { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String storeResultAs { get; set; }
        @AuraEnabled public String configJson { get; set; }
    }

    @AuraEnabled
    public static SubmitWorkspace getWorkspace(Id versionId) {
        SubmitWorkspace workspace = new SubmitWorkspace();
        workspace.versions = new List<VersionOption>();
        workspace.actions = new List<SubmitActionRecord>();
        workspace.prefillAliasDetails = new List<PrefillAliasDetail>();
        workspace.objectOptions = getObjectOptions();
        workspace.formFieldOptions = new List<SelectOption>();
        workspace.repeatGroupOptions = new List<SelectOption>();
        workspace.mappings = new List<MappingRecord>();
        workspace.enableProConditionLogic = NativeFormsFeatureFlags.isProConditionLogicEnabled();
        workspace.enableProRepeatGroups = NativeFormsFeatureFlags.isProRepeatGroupsEnabled();
        workspace.enableProPrefillAliasReferences = NativeFormsFeatureFlags.isProPrefillAliasReferencesEnabled();
        workspace.enableProAdvancedSubmitModes = NativeFormsFeatureFlags.isProAdvancedSubmitModesEnabled();

        List<NF_Form_Version__c> versions = [
            SELECT Id,
                   Name,
                   Version_Number__c,
                   Version_Status__c,
                   Form__r.Name,
                   LastModifiedDate
            FROM NF_Form_Version__c
            ORDER BY LastModifiedDate DESC
            LIMIT 100
        ];

        for (NF_Form_Version__c versionRecord : versions) {
            VersionOption option = new VersionOption();
            option.value = versionRecord.Id;
            option.label = versionRecord.Form__r.Name + ' - ' + formatVersionDisplay(versionRecord.Version_Number__c, versionRecord.Name);
            option.status = versionRecord.Version_Status__c;
            workspace.versions.add(option);
        }

        Id effectiveVersionId = versionId;
        if (effectiveVersionId == null && !versions.isEmpty()) {
            effectiveVersionId = versions[0].Id;
        }
        if (effectiveVersionId == null) {
            return workspace;
        }

        NF_Form_Version__c selectedVersion = [
            SELECT Id, Name, Version_Number__c, Version_Status__c, Form__r.Name
            FROM NF_Form_Version__c
            WHERE Id = :effectiveVersionId
            LIMIT 1
        ];
        workspace.selectedVersionId = selectedVersion.Id;
        workspace.selectedVersionName = formatVersionDisplay(selectedVersion.Version_Number__c, selectedVersion.Name);
        workspace.selectedVersionStatus = selectedVersion.Version_Status__c;
        workspace.selectedFormName = selectedVersion.Form__r.Name;

        for (NF_Form_Action__c actionRecord : [
            SELECT Store_Result_As__c, Object_Api_Name__c
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :effectiveVersionId
              AND Action_Scope__c = 'Prefill'
              AND Store_Result_As__c != null
            ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            if (String.isNotBlank(actionRecord.Store_Result_As__c) && String.isNotBlank(actionRecord.Object_Api_Name__c)) {
                PrefillAliasDetail aliasDetail = new PrefillAliasDetail();
                aliasDetail.alias = actionRecord.Store_Result_As__c;
                aliasDetail.objectApiName = actionRecord.Object_Api_Name__c;
                aliasDetail.fieldOptions = getReadableFieldOptions(actionRecord.Object_Api_Name__c);
                workspace.prefillAliasDetails.add(aliasDetail);
            }
        }

        Integer actionNumber = 1;
        for (NF_Form_Action__c actionRecord : [
            SELECT Id,
                   Name,
                   Command_Key__c,
                   Command_Type__c,
                   Object_Api_Name__c,
                   Store_Result_As__c,
                   Order__c,
                   Config_JSON__c
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :effectiveVersionId
              AND Action_Scope__c = 'Submit'
            ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            workspace.actions.add(toRecord(actionRecord, actionNumber));
            actionNumber += 1;
        }

        for (NF_Form_Element__c elementRecord : [
            SELECT Id, Label__c, Field_Key__c, Element_Type__c, Config_JSON__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :effectiveVersionId
            ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            if (elementRecord.Element_Type__c == 'repeatGroup' && String.isNotBlank(elementRecord.Field_Key__c)) {
                SelectOption groupOption = new SelectOption();
                groupOption.label = String.isBlank(elementRecord.Label__c)
                    ? elementRecord.Field_Key__c
                    : elementRecord.Label__c + ' (' + elementRecord.Field_Key__c + ')';
                groupOption.value = elementRecord.Field_Key__c;
                workspace.repeatGroupOptions.add(groupOption);
            }
            if (String.isNotBlank(elementRecord.Field_Key__c)) {
                SelectOption fieldOption = new SelectOption();
                fieldOption.label = String.isBlank(elementRecord.Label__c)
                    ? elementRecord.Field_Key__c
                    : elementRecord.Label__c + ' (' + elementRecord.Field_Key__c + ')';
                fieldOption.value = elementRecord.Field_Key__c;
                workspace.formFieldOptions.add(fieldOption);
            }
            Map<String, Object> config = parseJsonMap(elementRecord.Config_JSON__c);
            if (!booleanValue(config.get('submitEnabled'))) {
                continue;
            }
            String actionKey = stringValue(config.get('submitActionKey'));
            String fieldPath = stringValue(config.get('submitFieldPath'));
            if (String.isBlank(actionKey) || String.isBlank(fieldPath)) {
                continue;
            }
            MappingRecord mapping = new MappingRecord();
            mapping.elementId = elementRecord.Id;
            mapping.elementLabel = elementRecord.Label__c;
            mapping.fieldKey = elementRecord.Field_Key__c;
            mapping.actionKey = actionKey;
            mapping.fieldPath = fieldPath;
            workspace.mappings.add(mapping);
        }

        return workspace;
    }

    @AuraEnabled(cacheable=true)
    public static List<SelectOption> getFieldOptions(String objectApiName) {
        return getReadableFieldOptions(objectApiName);
    }

    @AuraEnabled
    public static SubmitActionRecord addSubmitAction(Id versionId) {
        if (versionId == null) {
            throw new AuraHandledException('Select a form version first.');
        }
        ensureVersionEditable(versionId);

        NF_Form_Version__c versionRecord = [
            SELECT Id, Form__c
            FROM NF_Form_Version__c
            WHERE Id = :versionId
            LIMIT 1
        ];

        Integer nextOrder = 10;
        AggregateResult[] maxRows = [
            SELECT MAX(Order__c) maxOrder
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :versionId
              AND Action_Scope__c = 'Submit'
        ];
        if (!maxRows.isEmpty() && maxRows[0].get('maxOrder') != null) {
            nextOrder = Integer.valueOf(String.valueOf(maxRows[0].get('maxOrder'))) + 10;
        }

        NF_Form_Action__c actionRecord = new NF_Form_Action__c(
            Form_Version__c = versionId,
            Action_Scope__c = 'Submit',
            Command_Key__c = buildNextSubmitActionKey(versionRecord.Form__c),
            Command_Type__c = 'create',
            Object_Api_Name__c = 'Contact',
            Store_Result_As__c = buildNextSubmitAlias(versionRecord.Form__c),
            Order__c = nextOrder,
            Config_JSON__c = JSON.serializePretty(new Map<String, Object>{
                'targetBy' => 'create'
            })
        );
        insert actionRecord;

        actionRecord = [
            SELECT Id,
                   Name,
                   Command_Key__c,
                   Command_Type__c,
                   Object_Api_Name__c,
                   Store_Result_As__c,
                   Order__c,
                   Config_JSON__c
            FROM NF_Form_Action__c
            WHERE Id = :actionRecord.Id
            LIMIT 1
        ];
        return toRecord(actionRecord, null);
    }

    @AuraEnabled
    public static SubmitActionRecord saveSubmitAction(SubmitActionInput inputValue) {
        if (inputValue == null) {
            throw new AuraHandledException('Action data is required.');
        }
        if (inputValue.id == null) {
            throw new AuraHandledException('Action id is required.');
        }
        if (String.isBlank(inputValue.objectApiName)) {
            throw new AuraHandledException('Choose a Salesforce object.');
        }
        if (String.isBlank(inputValue.commandType)) {
            throw new AuraHandledException('Choose a submit mode.');
        }

        NF_Form_Action__c actionRecord = [
            SELECT Id,
                   Name,
                   Form_Version__c,
                   Action_Scope__c,
                   Command_Key__c,
                   Command_Type__c,
                   Object_Api_Name__c,
                   Store_Result_As__c,
                   Order__c,
                   Config_JSON__c
            FROM NF_Form_Action__c
            WHERE Id = :inputValue.id
            LIMIT 1
        ];
        ensureActionVersionEditable(actionRecord.Form_Version__c);

        actionRecord.Command_Key__c = String.isBlank(inputValue.actionKey)
            ? buildActionKey(inputValue.objectApiName, inputValue.commandType)
            : inputValue.actionKey;
        actionRecord.Command_Type__c = inputValue.commandType;
        actionRecord.Object_Api_Name__c = canonicalObjectApiName(inputValue.objectApiName);
        actionRecord.Store_Result_As__c = inputValue.storeResultAs;
        actionRecord.Config_JSON__c = String.isBlank(inputValue.configJson) ? '{}' : inputValue.configJson;
        update actionRecord;

        return toRecord(actionRecord, null);
    }

    @AuraEnabled
    public static void deleteSubmitAction(Id actionId) {
        if (actionId == null) {
            throw new AuraHandledException('Action id is required.');
        }

        NF_Form_Action__c actionRecord = [
            SELECT Id, Form_Version__c
            FROM NF_Form_Action__c
            WHERE Id = :actionId
            LIMIT 1
        ];
        ensureActionVersionEditable(actionRecord.Form_Version__c);

        delete actionRecord;
    }

    private static SubmitActionRecord toRecord(NF_Form_Action__c actionRecord, Integer displayNumber) {
        SubmitActionRecord dto = new SubmitActionRecord();
        dto.id = actionRecord.Id;
        dto.name = actionRecord.Name;
        dto.displayNumber = displayNumber;
        dto.actionKey = actionRecord.Command_Key__c;
        dto.commandType = actionRecord.Command_Type__c;
        dto.objectApiName = actionRecord.Object_Api_Name__c;
        dto.storeResultAs = actionRecord.Store_Result_As__c;
        dto.orderValue = actionRecord.Order__c == null ? null : Integer.valueOf(String.valueOf(actionRecord.Order__c));
        dto.configJson = actionRecord.Config_JSON__c;
        return dto;
    }

    private static List<SelectOption> getObjectOptions() {
        List<SelectOption> options = new List<SelectOption>();
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        List<String> objectNames = new List<String>();

        for (String apiName : globalDescribe.keySet()) {
            Schema.DescribeSObjectResult describeResult = globalDescribe.get(apiName).getDescribe();
            if (!describeResult.isQueryable()) {
                continue;
            }
            if (!describeResult.isCreateable() && !describeResult.isUpdateable()) {
                continue;
            }
            if (apiName.endsWith('History') || apiName.endsWith('Feed') || apiName.endsWith('Share') || apiName.endsWith('ChangeEvent')) {
                continue;
            }
            objectNames.add(apiName);
        }

        for (String apiName : objectNames) {
            Schema.DescribeSObjectResult describeResult = globalDescribe.get(apiName).getDescribe();
            SelectOption option = new SelectOption();
            option.label = describeResult.getLabel() + ' (' + apiName + ')';
            option.value = apiName;
            options.add(option);
        }

        sortOptionsByLabel(options);
        return options;
    }

    private static List<SelectOption> getReadableFieldOptions(String objectApiName) {
        List<SelectOption> options = new List<SelectOption>();
        if (String.isBlank(objectApiName)) {
            return options;
        }

        String canonicalObject = canonicalObjectApiName(objectApiName);
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (String.isBlank(canonicalObject) || !globalDescribe.containsKey(canonicalObject)) {
            return options;
        }

        Map<String, Schema.SObjectField> fieldsMap = globalDescribe.get(canonicalObject).getDescribe().fields.getMap();
        for (String fieldApiName : fieldsMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldApiName).getDescribe();
            if (!fieldDescribe.isAccessible()) {
                continue;
            }
            SelectOption option = new SelectOption();
            option.label = fieldDescribe.getLabel() + ' (' + fieldApiName + ')';
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

    private static Map<String, Object> parseJsonMap(String rawJson) {
        if (String.isBlank(rawJson)) {
            return new Map<String, Object>();
        }
        try {
            Object parsedValue = JSON.deserializeUntyped(rawJson);
            return parsedValue instanceof Map<String, Object>
                ? (Map<String, Object>) parsedValue
                : new Map<String, Object>();
        } catch (Exception e) {
            return new Map<String, Object>();
        }
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

    private static String buildActionKey(String objectApiName, String commandType) {
        String objectSeed = String.isBlank(objectApiName) ? 'Record' : objectApiName.replaceAll('[^a-zA-Z0-9]', '');
        String actionSeed = String.isBlank(commandType) ? 'create' : commandType.replaceAll('[^a-zA-Z0-9]', '');
        return (actionSeed + objectSeed).left(80);
    }

    private static String buildNextSubmitActionKey(Id formId) {
        return buildNextScopedKey(formId, 'Submit', 'submitAction');
    }

    private static String buildNextSubmitAlias(Id formId) {
        return buildNextScopedAlias(formId, 'Submit', 'savedRecord');
    }

    private static String buildNextScopedKey(Id formId, String actionScope, String prefix) {
        Integer suffix = nextScopedSequence(formId, actionScope, prefix, true);
        return (prefix + String.valueOf(suffix)).left(80);
    }

    private static String buildNextScopedAlias(Id formId, String actionScope, String prefix) {
        Integer suffix = nextScopedSequence(formId, actionScope, prefix, false);
        return (prefix + String.valueOf(suffix)).left(80);
    }

    private static Integer nextScopedSequence(Id formId, String actionScope, String prefix, Boolean useCommandKey) {
        if (formId == null) {
            return 1;
        }

        Integer maxSuffix = 0;
        for (NF_Form_Action__c actionRecord : [
            SELECT Command_Key__c, Store_Result_As__c
            FROM NF_Form_Action__c
            WHERE Form_Version__r.Form__c = :formId
              AND Action_Scope__c = :actionScope
        ]) {
            String candidate = useCommandKey ? actionRecord.Command_Key__c : actionRecord.Store_Result_As__c;
            Integer parsedSuffix = readTrailingSequence(candidate, prefix);
            if (parsedSuffix != null && parsedSuffix > maxSuffix) {
                maxSuffix = parsedSuffix;
            }
        }
        return maxSuffix + 1;
    }

    private static Integer readTrailingSequence(String value, String prefix) {
        if (String.isBlank(value) || String.isBlank(prefix) || !value.startsWith(prefix)) {
            return null;
        }

        String suffix = value.substring(prefix.length());
        if (String.isBlank(suffix) || !Pattern.matches('^[0-9]+$', suffix)) {
            return null;
        }

        try {
            return Integer.valueOf(suffix);
        } catch (Exception e) {
            return null;
        }
    }

    private static String canonicalObjectApiName(String requestedObjectName) {
        if (String.isBlank(requestedObjectName)) {
            return requestedObjectName;
        }

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (globalDescribe.containsKey(requestedObjectName)) {
            return globalDescribe.get(requestedObjectName).getDescribe().getName();
        }

        for (String apiName : globalDescribe.keySet()) {
            if (apiName != null && apiName.toLowerCase() == requestedObjectName.toLowerCase()) {
                return globalDescribe.get(apiName).getDescribe().getName();
            }
        }

        return requestedObjectName;
    }

    private static void ensureVersionEditable(Id versionId) {
        NF_Form_Version__c versionRecord = [
            SELECT Id, Version_Status__c
            FROM NF_Form_Version__c
            WHERE Id = :versionId
            LIMIT 1
        ];
        if (versionRecord.Version_Status__c == 'Published') {
            throw new AuraHandledException('Published versions are read-only. Open the latest draft in NativeForms Designer.');
        }
    }

    private static void ensureActionVersionEditable(Id versionId) {
        ensureVersionEditable(versionId);
    }
}
