public with sharing class NativeFormsBuilderController {
    public class BuilderPublishResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public String publicUrl { get; set; }
        @AuraEnabled public String key { get; set; }
        @AuraEnabled public Id publicationId { get; set; }
        @AuraEnabled public Id newDraftVersionId { get; set; }
        @AuraEnabled public String newDraftVersionName { get; set; }
    }

    public class VersionOption {
        @AuraEnabled public Id value { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String formName { get; set; }
    }

    public class ElementRecord {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String elementId { get; set; }
        @AuraEnabled public String elementType { get; set; }
        @AuraEnabled public String fieldKey { get; set; }
        @AuraEnabled public Integer elementIndex { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String configJson { get; set; }
        @AuraEnabled public String parentElementId { get; set; }
        @AuraEnabled public Integer orderValue { get; set; }
    }

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

    public class PrefillAliasDetail {
        @AuraEnabled public String alias { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public List<SelectOption> fieldOptions { get; set; }
    }

    public class SubmitActionDetail {
        @AuraEnabled public String actionKey { get; set; }
        @AuraEnabled public String objectApiName { get; set; }
        @AuraEnabled public String commandType { get; set; }
        @AuraEnabled public List<SelectOption> fieldOptions { get; set; }
    }

    public class BuilderWorkspace {
        @AuraEnabled public Id selectedVersionId { get; set; }
        @AuraEnabled public String selectedVersionName { get; set; }
        @AuraEnabled public String selectedVersionStatus { get; set; }
        @AuraEnabled public String selectedFormName { get; set; }
        @AuraEnabled public String selectedFormKey { get; set; }
        @AuraEnabled public List<VersionOption> versions { get; set; }
        @AuraEnabled public List<ElementRecord> elements { get; set; }
        @AuraEnabled public List<PrefillAliasDetail> prefillAliases { get; set; }
        @AuraEnabled public List<SubmitActionDetail> submitActions { get; set; }
    }

    public class ElementUpsertInput {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String fieldKey { get; set; }
        @AuraEnabled public String configJson { get; set; }
        @AuraEnabled public String elementType { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static BuilderWorkspace getWorkspace(Id versionId) {
        BuilderWorkspace workspace = new BuilderWorkspace();
        workspace.versions = new List<VersionOption>();
        workspace.elements = new List<ElementRecord>();
        workspace.prefillAliases = new List<PrefillAliasDetail>();
        workspace.submitActions = new List<SubmitActionDetail>();

        List<NF_Form_Version__c> versions = [
            SELECT Id,
                   Name,
                   Version_Number__c,
                   Version_Status__c,
                   Form__r.Name,
                   Form__r.NF_Key__c,
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
            option.formName = versionRecord.Form__r.Name;
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
            SELECT Id,
                   Name,
                   Version_Number__c,
                   Version_Status__c,
                   Form__r.Name,
                   Form__r.NF_Key__c
            FROM NF_Form_Version__c
            WHERE Id = :effectiveVersionId
            LIMIT 1
        ];

        workspace.selectedVersionId = selectedVersion.Id;
        workspace.selectedVersionName = formatVersionDisplay(selectedVersion.Version_Number__c, selectedVersion.Name);
        workspace.selectedVersionStatus = selectedVersion.Version_Status__c;
        workspace.selectedFormName = selectedVersion.Form__r.Name;
        workspace.selectedFormKey = selectedVersion.Form__r.NF_Key__c;

        for (NF_Form_Element__c elementRecord : [
            SELECT Id,
                   Name,
                   Element_Id__c,
                   Element_Type__c,
                   Field_Key__c,
                   Element_Index__c,
                   Label__c,
                   Config_JSON__c,
                   Parent_Element_Id__c,
                   Order__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :effectiveVersionId
            ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            workspace.elements.add(toElementRecord(elementRecord));
        }

        for (NF_Form_Action__c actionRecord : [
            SELECT Store_Result_As__c, Object_Api_Name__c
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :effectiveVersionId
              AND Action_Scope__c = 'Prefill'
              AND Store_Result_As__c != null
            ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            PrefillAliasDetail detail = new PrefillAliasDetail();
            detail.alias = actionRecord.Store_Result_As__c;
            detail.objectApiName = actionRecord.Object_Api_Name__c;
            detail.fieldOptions = getReadableFieldOptions(actionRecord.Object_Api_Name__c);
            workspace.prefillAliases.add(detail);
        }

        for (NF_Form_Action__c actionRecord : [
            SELECT Command_Key__c, Object_Api_Name__c, Command_Type__c
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :effectiveVersionId
              AND Action_Scope__c = 'Submit'
              AND Command_Key__c != null
            ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            SubmitActionDetail detail = new SubmitActionDetail();
            detail.actionKey = actionRecord.Command_Key__c;
            detail.objectApiName = actionRecord.Object_Api_Name__c;
            detail.commandType = actionRecord.Command_Type__c;
            detail.fieldOptions = getWritableFieldOptions(actionRecord.Object_Api_Name__c);
            workspace.submitActions.add(detail);
        }

        return workspace;
    }

    @AuraEnabled
    public static ElementRecord addElement(Id versionId, String elementType) {
        if (versionId == null) {
            throw new AuraHandledException('Select a form version first.');
        }
        ensureVersionEditable(versionId);
        if (String.isBlank(elementType)) {
            throw new AuraHandledException('Element type is required.');
        }
        if (!new Set<String>{ 'text', 'input', 'textarea', 'select', 'checkbox', 'radio', 'hidden' }.contains(elementType)) {
            throw new AuraHandledException('Only basic input elements are supported in this builder version.');
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
            SELECT Id,
                   Name,
                   Element_Id__c,
                   Element_Type__c,
                   Field_Key__c,
                   Element_Index__c,
                   Label__c,
                   Config_JSON__c,
                   Parent_Element_Id__c,
                   Order__c
            FROM NF_Form_Element__c
            WHERE Id = :elementRecord.Id
            LIMIT 1
        ];

        return toElementRecord(elementRecord);
    }

    @AuraEnabled
    public static ElementRecord updateElement(ElementUpsertInput inputValue) {
        if (inputValue == null || inputValue.id == null) {
            throw new AuraHandledException('Element id is required.');
        }
        ensureElementVersionEditable(inputValue.id);

        NF_Form_Element__c elementRecord = [
            SELECT Id,
                   Name,
                   Element_Id__c,
                   Element_Type__c,
                   Field_Key__c,
                   Element_Index__c,
                   Label__c,
                   Config_JSON__c,
                   Parent_Element_Id__c,
                   Order__c
            FROM NF_Form_Element__c
            WHERE Id = :inputValue.id
            LIMIT 1
        ];

        elementRecord.Label__c = inputValue.label;
        if (String.isNotBlank(inputValue.fieldKey)) {
            elementRecord.Field_Key__c = inputValue.fieldKey;
        } else if (String.isBlank(elementRecord.Field_Key__c)) {
            elementRecord.Field_Key__c = defaultFieldKeyForType(
                String.isNotBlank(inputValue.elementType) ? inputValue.elementType : elementRecord.Element_Type__c,
                elementRecord.Element_Index__c == null ? 1 : Integer.valueOf(String.valueOf(elementRecord.Element_Index__c))
            );
        }
        elementRecord.Config_JSON__c = String.isBlank(inputValue.configJson) ? '{}' : inputValue.configJson;
        if (String.isNotBlank(inputValue.elementType)) {
            if (inputValue.elementType == 'fileUpload' && !NativeFormsFeatureFlags.isProLoadFileEnabled()) {
                throw new AuraHandledException('File Uploads are not available on your current TwinaForms plan.');
            }
            if (inputValue.elementType == 'fileUpload' && String.isNotBlank(elementRecord.Parent_Element_Id__c)) {
                List<NF_Form_Element__c> parentRows = [
                    SELECT Id, Element_Type__c
                    FROM NF_Form_Element__c
                    WHERE Element_Id__c = :elementRecord.Parent_Element_Id__c
                    LIMIT 1
                ];
                if (!parentRows.isEmpty() && parentRows[0].Element_Type__c == 'repeatGroup') {
                    throw new AuraHandledException('File Upload fields are not supported inside repeat groups in Pro V1.');
                }
            }
            elementRecord.Element_Type__c = inputValue.elementType;
        }
        validateElementBeforeSave(elementRecord);
        update elementRecord;

        return toElementRecord(elementRecord);
    }

    @AuraEnabled
    public static void deleteElement(Id elementId) {
        if (elementId == null) {
            throw new AuraHandledException('Element id is required.');
        }
        ensureElementVersionEditable(elementId);

        delete [
            SELECT Id
            FROM NF_Form_Element__c
            WHERE Id = :elementId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static void moveElement(Id elementId, String direction) {
        if (elementId == null) {
            throw new AuraHandledException('Element id is required.');
        }
        ensureElementVersionEditable(elementId);
        if (String.isBlank(direction)) {
            throw new AuraHandledException('Move direction is required.');
        }

        NF_Form_Element__c currentElement = [
            SELECT Id, Form_Version__c, Order__c
            FROM NF_Form_Element__c
            WHERE Id = :elementId
            LIMIT 1
        ];

        List<NF_Form_Element__c> siblings = [
            SELECT Id, Order__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :currentElement.Form_Version__c
            ORDER BY Order__c ASC, CreatedDate ASC
        ];

        Integer sequence = 10;
        List<NF_Form_Element__c> resequenceUpdates = new List<NF_Form_Element__c>();
        for (NF_Form_Element__c sibling : siblings) {
            if (sibling.Order__c == null || Integer.valueOf(String.valueOf(sibling.Order__c)) != sequence) {
                sibling.Order__c = sequence;
                resequenceUpdates.add(sibling);
            }
            sequence += 10;
        }
        if (!resequenceUpdates.isEmpty()) {
            update resequenceUpdates;
            siblings = [
                SELECT Id, Order__c
                FROM NF_Form_Element__c
                WHERE Form_Version__c = :currentElement.Form_Version__c
                ORDER BY Order__c ASC, CreatedDate ASC
            ];
            currentElement = [
                SELECT Id, Form_Version__c, Order__c
                FROM NF_Form_Element__c
                WHERE Id = :elementId
                LIMIT 1
            ];
        }

        Integer indexValue = -1;
        for (Integer i = 0; i < siblings.size(); i++) {
            if (siblings[i].Id == currentElement.Id) {
                indexValue = i;
                break;
            }
        }
        if (indexValue < 0) {
            return;
        }

        Integer swapIndex = direction == 'up' ? indexValue - 1 : indexValue + 1;
        if (swapIndex < 0 || swapIndex >= siblings.size()) {
            return;
        }

        NF_Form_Element__c swapElement = siblings[swapIndex];
        Integer currentOrder = Integer.valueOf(String.valueOf(currentElement.Order__c));
        Integer swapOrder = Integer.valueOf(String.valueOf(swapElement.Order__c));

        currentElement.Order__c = swapOrder;
        swapElement.Order__c = currentOrder;
        update new List<NF_Form_Element__c>{ currentElement, swapElement };
    }

    @AuraEnabled
    public static BuilderPublishResult publishVersion(Id versionId) {
        if (versionId == null) {
            throw new AuraHandledException('Select a form version first.');
        }

        NativeFormsPublisher.PublishResult publishResult = NativeFormsPublisher.publishVersion(versionId);
        BuilderPublishResult result = new BuilderPublishResult();
        result.success = publishResult.success;
        result.message = publishResult.message;
        result.publicUrl = publishResult.publicUrl;
        result.key = publishResult.key;
        result.publicationId = publishResult.publicationId;
        result.newDraftVersionId = publishResult.newDraftVersionId;
        result.newDraftVersionName = publishResult.newDraftVersionName;
        return result;
    }

    private static ElementRecord toElementRecord(NF_Form_Element__c elementRecord) {
        ElementRecord dto = new ElementRecord();
        dto.id = elementRecord.Id;
        dto.name = elementRecord.Name;
        dto.elementId = elementRecord.Element_Id__c;
        dto.elementType = elementRecord.Element_Type__c;
        dto.fieldKey = elementRecord.Field_Key__c;
        dto.elementIndex = elementRecord.Element_Index__c == null ? null : Integer.valueOf(String.valueOf(elementRecord.Element_Index__c));
        dto.label = elementRecord.Label__c;
        dto.configJson = elementRecord.Config_JSON__c;
        dto.parentElementId = elementRecord.Parent_Element_Id__c;
        dto.orderValue = elementRecord.Order__c == null ? null : Integer.valueOf(String.valueOf(elementRecord.Order__c));
        return dto;
    }

    private static String buildElementId(String elementType) {
        return elementType.toLowerCase() + '-' + String.valueOf(Datetime.now().getTime());
    }

    private static String defaultLabelForType(String elementType) {
        Map<String, String> labelsByType = new Map<String, String>{
            'heading' => 'Section Heading',
            'text' => 'Text Field',
            'input' => 'Input Field',
            'textarea' => 'Long Text',
            'select' => 'Select Option',
            'checkbox' => 'Checkbox',
            'radio' => 'Radio Group',
            'image' => 'Image',
            'section' => 'Section',
            'columns' => 'Columns',
            'hidden' => 'Hidden Field',
            'repeatGroup' => 'Repeat Group'
        };
        return labelsByType.containsKey(elementType) ? labelsByType.get(elementType) : 'Form Element';
    }

    private static String defaultFieldKeyForType(String elementType, Integer elementIndex) {
        Set<String> nonInputTypes = new Set<String>{ 'heading', 'image', 'section', 'columns' };
        if (nonInputTypes.contains(elementType)) {
            return null;
        }

        String seed = elementType == 'input' ? 'field' : elementType;
        if (seed == 'select') seed = 'picklist';
        if (seed == 'tel') seed = 'phone';
        Integer safeIndex = elementIndex == null || elementIndex <= 0 ? 1 : elementIndex;
        return seed + String.valueOf(safeIndex);
    }

    private static String defaultConfigJsonForType(String elementType) {
        Map<String, Object> config = new Map<String, Object>();

        if (elementType == 'select' || elementType == 'radio') {
            config.put('options', new List<Object>{
                new Map<String, Object>{ 'label' => 'Option 1', 'value' => 'option1' },
                new Map<String, Object>{ 'label' => 'Option 2', 'value' => 'option2' }
            });
            config.put('defaultValue', '');
        }
        if (elementType == 'textarea' || elementType == 'text' || elementType == 'input') {
            config.put('placeholder', 'Enter a value');
        }
        if (elementType == 'text' || elementType == 'number') {
            config.put('isFormula', false);
            config.put('formulaExpression', '');
        }
        if (elementType == 'checkbox') {
            config.put('checked', false);
        }
        if (elementType == 'date') {
            config.put('dateDisplayFormat', 'us');
            config.put('dateGmtOffset', '+00:00');
        }
        if (elementType == 'hidden') {
            config.put('value', '');
        }
        if (elementType == 'heading') {
            config.put('text', 'Add a helpful heading for this section');
        }
        if (elementType == 'section') {
            config.put('text', 'Use this section to group related fields together.');
        }
        if (elementType == 'repeatGroup') {
            config.put('maxRows', 10);
            config.put('allowDelete', true);
        }

        return JSON.serializePretty(config);
    }

    private static void validateElementBeforeSave(NF_Form_Element__c elementRecord) {
        if (elementRecord == null) {
            return;
        }

        Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped(
            String.isBlank(elementRecord.Config_JSON__c) ? '{}' : elementRecord.Config_JSON__c
        );

        if (booleanValue(config.get('isFormula'))) {
            if (!NativeFormsFeatureFlags.isProFormulaFieldsEnabled()) {
                throw new AuraHandledException('Formula Fields are not available on your current TwinaForms plan.');
            }
            if (elementRecord.Element_Type__c != 'text' && elementRecord.Element_Type__c != 'number') {
                throw new AuraHandledException('Only Text and Number fields can use formulas in Pro V1.');
            }
            if (String.isBlank(elementRecord.Field_Key__c)) {
                throw new AuraHandledException('Formula fields must keep a field key.');
            }
            if (String.isNotBlank(elementRecord.Parent_Element_Id__c)) {
                List<NF_Form_Element__c> parentRows = [
                    SELECT Id, Element_Type__c
                    FROM NF_Form_Element__c
                    WHERE Element_Id__c = :elementRecord.Parent_Element_Id__c
                    LIMIT 1
                ];
                if (!parentRows.isEmpty() && parentRows[0].Element_Type__c == 'repeatGroup') {
                    throw new AuraHandledException('Formula fields are not supported inside repeat groups in Pro V1.');
                }
            }
        }

        if (elementRecord.Element_Type__c != 'fileUpload') {
            return;
        }

        if (String.isBlank(elementRecord.Field_Key__c)) {
            throw new AuraHandledException('File Upload fields must keep a field key.');
        }
        String targetSubmitActionKey = config != null && config.containsKey('targetSubmitActionKey')
            ? String.valueOf(config.get('targetSubmitActionKey'))
            : '';
        if (String.isBlank(targetSubmitActionKey)) {
            throw new AuraHandledException('Choose a target submit action for the File Upload field before saving.');
        }
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

    private static List<SelectOption> getReadableFieldOptions(String objectApiName) {
        List<SelectOption> options = new List<SelectOption>();
        if (String.isBlank(objectApiName) || !Schema.getGlobalDescribe().containsKey(objectApiName)) {
            return options;
        }

        Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
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
        if (String.isBlank(objectApiName) || !Schema.getGlobalDescribe().containsKey(objectApiName)) {
            return options;
        }

        Map<String, Schema.SObjectField> fieldsMap = Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap();
        for (String fieldApiName : fieldsMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe = fieldsMap.get(fieldApiName).getDescribe();
            if (!fieldDescribe.isAccessible()) {
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

    private static String formatVersionDisplay(Decimal versionNumber, String fallbackName) {
        if (versionNumber != null) {
            return 'V' + String.valueOf(Integer.valueOf(String.valueOf(versionNumber)));
        }
        return fallbackName;
    }
}
