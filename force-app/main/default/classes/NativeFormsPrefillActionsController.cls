public with sharing class NativeFormsPrefillActionsController {
    public class SelectOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
    }

    public class VersionOption {
        @AuraEnabled public Id value { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String status { get; set; }
    }

    public class PrefillActionRecord {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String actionKey { get; set; }
        @AuraEnabled public String commandType { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String storeResultAs { get; set; }
        @AuraEnabled public Integer orderValue { get; set; }
        @AuraEnabled public String configJson { get; set; }
    }

    public class PrefillWorkspace {
        @AuraEnabled public Id selectedVersionId { get; set; }
        @AuraEnabled public String selectedVersionName { get; set; }
        @AuraEnabled public String selectedVersionStatus { get; set; }
        @AuraEnabled public String selectedFormName { get; set; }
        @AuraEnabled public List<VersionOption> versions { get; set; }
        @AuraEnabled public List<PrefillActionRecord> actions { get; set; }
        @AuraEnabled public List<PrefillAliasDetail> prefillAliasDetails { get; set; }
        @AuraEnabled public List<SelectOption> objectOptions { get; set; }
        @AuraEnabled public List<SelectOption> formFieldOptions { get; set; }
        @AuraEnabled public List<MappingRecord> mappings { get; set; }
        @AuraEnabled public Boolean enableProConditionLogic { get; set; }
        @AuraEnabled public Boolean enableProPrefillAliasReferences { get; set; }
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
        @AuraEnabled public String aliasValue { get; set; }
        @AuraEnabled public String fieldPath { get; set; }
    }

    public class PrefillActionInput {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public Id versionId { get; set; }
        @AuraEnabled public String actionKey { get; set; }
        @AuraEnabled public String commandType { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String storeResultAs { get; set; }
        @AuraEnabled public String configJson { get; set; }
    }

    @AuraEnabled
    public static PrefillWorkspace getWorkspace(Id versionId) {
        PrefillWorkspace workspace = new PrefillWorkspace();
        workspace.versions = new List<VersionOption>();
        workspace.actions = new List<PrefillActionRecord>();
        workspace.prefillAliasDetails = new List<PrefillAliasDetail>();
        workspace.objectOptions = getObjectOptions();
        workspace.formFieldOptions = new List<SelectOption>();
        workspace.mappings = new List<MappingRecord>();
        workspace.enableProConditionLogic = NativeFormsFeatureFlags.isProConditionLogicEnabled();
        workspace.enableProPrefillAliasReferences = NativeFormsFeatureFlags.isProPrefillAliasReferencesEnabled();

        List<NF_Form_Version__c> versions = [
            SELECT Id,
                   Name,
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
            option.label = versionRecord.Form__r.Name + ' - ' + versionRecord.Name;
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
            SELECT Id, Name, Version_Status__c, Form__r.Name
            FROM NF_Form_Version__c
            WHERE Id = :effectiveVersionId
            LIMIT 1
        ];
        workspace.selectedVersionId = selectedVersion.Id;
        workspace.selectedVersionName = selectedVersion.Name;
        workspace.selectedVersionStatus = selectedVersion.Version_Status__c;
        workspace.selectedFormName = selectedVersion.Form__r.Name;

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
              AND Action_Scope__c = 'Prefill'
            ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            workspace.actions.add(toRecord(actionRecord));
            if (String.isNotBlank(actionRecord.Store_Result_As__c) && String.isNotBlank(actionRecord.Object_Api_Name__c)) {
                PrefillAliasDetail aliasDetail = new PrefillAliasDetail();
                aliasDetail.alias = actionRecord.Store_Result_As__c;
                aliasDetail.objectApiName = actionRecord.Object_Api_Name__c;
                aliasDetail.fieldOptions = getReadableFieldOptions(actionRecord.Object_Api_Name__c);
                workspace.prefillAliasDetails.add(aliasDetail);
            }
        }

        for (NF_Form_Element__c elementRecord : [
            SELECT Id, Label__c, Field_Key__c, Config_JSON__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :effectiveVersionId
            ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            if (String.isNotBlank(elementRecord.Field_Key__c)) {
                SelectOption fieldOption = new SelectOption();
                fieldOption.label = String.isBlank(elementRecord.Label__c)
                    ? elementRecord.Field_Key__c
                    : elementRecord.Label__c + ' (' + elementRecord.Field_Key__c + ')';
                fieldOption.value = elementRecord.Field_Key__c;
                workspace.formFieldOptions.add(fieldOption);
            }
            Map<String, Object> config = parseJsonMap(elementRecord.Config_JSON__c);
            if (!booleanValue(config.get('prefillEnabled'))) {
                continue;
            }
            String aliasValue = stringValue(config.get('prefillAlias'));
            String fieldPath = stringValue(config.get('prefillFieldPath'));
            if (String.isBlank(aliasValue) || String.isBlank(fieldPath)) {
                continue;
            }
            MappingRecord mapping = new MappingRecord();
            mapping.elementId = elementRecord.Id;
            mapping.elementLabel = elementRecord.Label__c;
            mapping.fieldKey = elementRecord.Field_Key__c;
            mapping.aliasValue = aliasValue;
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
    public static PrefillActionRecord addPrefillAction(Id versionId) {
        if (versionId == null) {
            throw new AuraHandledException('Select a form version first.');
        }
        ensureVersionEditable(versionId);

        Integer nextOrder = 10;
        AggregateResult[] maxRows = [
            SELECT MAX(Order__c) maxOrder
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :versionId
              AND Action_Scope__c = 'Prefill'
        ];
        if (!maxRows.isEmpty() && maxRows[0].get('maxOrder') != null) {
            nextOrder = Integer.valueOf(String.valueOf(maxRows[0].get('maxOrder'))) + 10;
        }

        NF_Form_Action__c actionRecord = new NF_Form_Action__c(
            Form_Version__c = versionId,
            Action_Scope__c = 'Prefill',
            Command_Key__c = 'prefillAction' + String.valueOf(Datetime.now().getTime()),
            Command_Type__c = 'findOne',
            Object_Api_Name__c = 'Contact',
            Store_Result_As__c = 'foundRecord',
            Order__c = nextOrder,
            Config_JSON__c = JSON.serializePretty(new Map<String, Object>{
                'where' => '',
                'onNotFound' => 'ignore'
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
        return toRecord(actionRecord);
    }

    @AuraEnabled
    public static PrefillActionRecord savePrefillAction(PrefillActionInput inputValue) {
        if (inputValue == null) {
            throw new AuraHandledException('Action data is required.');
        }
        if (inputValue.id == null) {
            throw new AuraHandledException('Action id is required.');
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
            ? buildActionKey(inputValue.storeResultAs, inputValue.objectApiName)
            : inputValue.actionKey;
        actionRecord.Command_Type__c = inputValue.commandType;
        actionRecord.Object_Api_Name__c = inputValue.objectApiName;
        actionRecord.Store_Result_As__c = inputValue.storeResultAs;
        actionRecord.Config_JSON__c = String.isBlank(inputValue.configJson) ? '{}' : inputValue.configJson;
        update actionRecord;

        return toRecord(actionRecord);
    }

    @AuraEnabled
    public static void deletePrefillAction(Id actionId) {
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

    private static PrefillActionRecord toRecord(NF_Form_Action__c actionRecord) {
        PrefillActionRecord dto = new PrefillActionRecord();
        dto.id = actionRecord.Id;
        dto.name = actionRecord.Name;
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
            if (apiName.endsWith('History') || apiName.endsWith('Feed') || apiName.endsWith('Share') || apiName.endsWith('ChangeEvent')) {
                continue;
            }
            objectNames.add(apiName);
        }

        objectNames.sort();
        for (String apiName : objectNames) {
            Schema.DescribeSObjectResult describeResult = globalDescribe.get(apiName).getDescribe();
            SelectOption option = new SelectOption();
            option.label = describeResult.getLabel() + ' (' + apiName + ')';
            option.value = apiName;
            options.add(option);
        }

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
        List<String> fieldNames = new List<String>(fieldsMap.keySet());
        fieldNames.sort();
        for (String fieldApiName : fieldNames) {
            Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldApiName).getDescribe();
            if (!fieldDescribe.isAccessible()) {
                continue;
            }
            SelectOption option = new SelectOption();
            option.label = fieldDescribe.getLabel() + ' (' + fieldApiName + ')';
            option.value = fieldDescribe.getName();
            options.add(option);
        }
        return options;
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

    private static String buildActionKey(String aliasValue, String objectApiName) {
        String aliasSeed = String.isBlank(aliasValue) ? '' : aliasValue.replaceAll('[^a-zA-Z0-9]', '');
        if (!String.isBlank(aliasSeed)) {
            return aliasSeed.left(80);
        }

        String objectSeed = String.isBlank(objectApiName) ? 'prefillAction' : objectApiName.replaceAll('[^a-zA-Z0-9]', '');
        return ('find' + objectSeed).left(80);
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
