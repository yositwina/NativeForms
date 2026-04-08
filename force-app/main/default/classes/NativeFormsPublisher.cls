public with sharing class NativeFormsPublisher {
    private static final String TEMP_SUBMIT_URL = 'https://hfkuwm6emqiaz2drmuip6zqn5m0agbyp.lambda-url.eu-north-1.on.aws/';

    public class PublishResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public String publicUrl { get; set; }
        @AuraEnabled public String key { get; set; }
        @AuraEnabled public Id publicationId { get; set; }
        @AuraEnabled public Id newDraftVersionId { get; set; }
        @AuraEnabled public String newDraftVersionName { get; set; }
    }

    @AuraEnabled
    public static PublishResult publishVersion(Id versionId) {
        PublishResult result = new PublishResult();

        NF_Form_Version__c versionRecord = [
            SELECT Id,
                   Name,
                   Form__c,
                   Form__r.Id,
                   Form__r.NF_Key__c,
                   Form__r.Status__c,
                   Form_Id__c,
                   Version_Number__c,
                   Publish_Token__c,
                   Publish_Status__c,
                   Version_Status__c,
                   Security_Mode__c,
                   Rate_Limit_Profile__c,
                   Custom_CSS__c,
                   Custom_JS__c,
                   Theme_JSON__c,
                   UI_Settings_JSON__c,
                   Prefill_Params_JSON__c
            FROM NF_Form_Version__c
            WHERE Id = :versionId
            LIMIT 1
        ];

        if (versionRecord.Version_Status__c == 'Published') {
            result.success = false;
            result.message = 'Published versions are read-only. Open the latest draft version to continue editing.';
            return result;
        }

        List<NF_Form_Element__c> elements = [
            SELECT Id,
                   Element_Id__c,
                   Element_Type__c,
                   Field_Key__c,
                   Element_Index__c,
                   Label__c,
                   Config_JSON__c,
                   Parent_Element_Id__c,
                   Order__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :versionId
            ORDER BY Order__c ASC, CreatedDate ASC
        ];

        List<NF_Form_Action__c> actions = [
            SELECT Id,
                   Action_Scope__c,
                   Command_Key__c,
                   Command_Type__c,
                   Object_Api_Name__c,
                   Store_Result_As__c,
                   Config_JSON__c,
                   Order__c
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :versionId
            ORDER BY Order__c ASC, CreatedDate ASC
        ];

        String orgId = UserInfo.getOrganizationId().substring(0, 15);
        String formId = String.isNotBlank(versionRecord.Form_Id__c)
            ? versionRecord.Form_Id__c
            : String.isNotBlank(versionRecord.Form__r.NF_Key__c)
                ? versionRecord.Form__r.NF_Key__c
                : 'nativeforms-' + String.valueOf(versionRecord.Id).substring(0, 8);

        String publishToken = String.isNotBlank(versionRecord.Publish_Token__c)
            ? versionRecord.Publish_Token__c
            : EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(String.valueOf(versionRecord.Id) + ':' + String.valueOf(Datetime.now().getTime())))).substring(0, 32);

        List<NF_Form_Element__c> publishElements = prepareElementsForPublish(elements);
        String html = buildHtml(versionRecord, publishElements, formId, publishToken);
        String fileName = 'index.v' + String.valueOf(Datetime.now().getTime()) + '.html';

        try {
            NativeFormsAwsClient.PresignRequest presignRequest = new NativeFormsAwsClient.PresignRequest();
            presignRequest.orgId = orgId;
            presignRequest.formId = formId;
            presignRequest.versionId = (String) versionRecord.Id;
            presignRequest.fileName = fileName;
            presignRequest.contentType = 'text/html; charset=utf-8';
            presignRequest.expires = 900;

            NativeFormsAwsClient.PresignResponse presignResponse = NativeFormsAwsClient.presignHtml(presignRequest);
            NativeFormsAwsClient.uploadHtml(presignResponse.putUrl, html);

            Map<String, Object> registerPayload = new Map<String, Object>{
                'orgId' => orgId,
                'formId' => formId,
                'publishedVersionId' => (String) versionRecord.Id,
                'publishToken' => publishToken,
                'status' => 'published',
                'securityMode' => String.isNotBlank(versionRecord.Security_Mode__c) ? versionRecord.Security_Mode__c : 'public-create',
                'rateLimitProfile' => String.isNotBlank(versionRecord.Rate_Limit_Profile__c) ? versionRecord.Rate_Limit_Profile__c : 'standard',
                'generatedHtmlRef' => presignResponse.key,
                'publicUrl' => presignResponse.publicUrl,
                'prefillPolicy' => buildPolicy(filterReferencedActions(actions, 'Prefill', publishElements), publishElements, true),
                'submitPolicy' => buildPolicy(filterReferencedActions(actions, 'Submit', publishElements), publishElements, false),
                'prefillDefinition' => buildDefinition(filterReferencedActions(actions, 'Prefill', publishElements), true, publishElements),
                'submitDefinition' => buildDefinition(filterReferencedActions(actions, 'Submit', publishElements), false, publishElements)
            };

            Map<String, Object> registerResponse = NativeFormsAwsClient.registerForm(registerPayload);
            String publicationType = versionRecord.Publish_Status__c == 'Published' ? 'Republish' : 'Publish';

            NF_Form_Publication__c publicationRecord = new NF_Form_Publication__c(
                Form__c = versionRecord.Form__c,
                Form_Version__c = versionRecord.Id,
                Publication_Status__c = 'Success',
                Publication_Type__c = publicationType,
                Published_At__c = System.now(),
                Published_By__c = UserInfo.getUserId(),
                Published_Form_Id__c = formId,
                Generated_HTML_Ref__c = presignResponse.publicUrl,
                AWS_Response_JSON__c = JSON.serialize(registerResponse),
                Error_Message__c = null
            );
            insert publicationRecord;

            versionRecord.Publish_Token__c = publishToken;
            versionRecord.Publish_Status__c = 'Published';
            versionRecord.Version_Status__c = 'Published';
            versionRecord.Last_Published_At__c = System.now();
            versionRecord.Last_Published_By__c = UserInfo.getUserId();
            versionRecord.Last_Publish_Error__c = null;
            update versionRecord;

            update new NF_Form__c(
                Id = versionRecord.Form__c,
                Current_Published_Version__c = versionRecord.Id,
                Status__c = 'Active'
            );

            NF_Form_Version__c successorDraft = null;
            try {
                successorDraft = createSuccessorDraft(versionRecord, publishElements, actions);
                if (successorDraft != null) {
                    result.newDraftVersionId = successorDraft.Id;
                    result.newDraftVersionName = successorDraft.Name;
                }
            } catch (Exception cloneError) {
                System.debug(LoggingLevel.ERROR, 'Failed to create successor draft: ' + cloneError.getMessage());
            }

            result.success = true;
            result.publicUrl = presignResponse.publicUrl;
            result.key = presignResponse.key;
            result.publicationId = publicationRecord.Id;
            result.message = successorDraft == null
                ? 'Published successfully.'
                : 'Published successfully. A new draft version was created.';
            return result;
        } catch (Exception e) {
            String detailedError = formatException(e);
            NF_Form_Publication__c failureRecord = new NF_Form_Publication__c(
                Form__c = versionRecord.Form__c,
                Form_Version__c = versionRecord.Id,
                Publication_Status__c = 'Failed',
                Publication_Type__c = 'Publish',
                Published_At__c = System.now(),
                Published_By__c = UserInfo.getUserId(),
                Published_Form_Id__c = formId,
                Error_Message__c = detailedError
            );
            insert failureRecord;

            versionRecord.Publish_Status__c = 'Publish Failed';
            versionRecord.Last_Publish_Error__c = detailedError;
            update versionRecord;

            result.success = false;
            result.publicationId = failureRecord.Id;
            result.message = detailedError;
            return result;
        }
    }

    private static List<NF_Form_Action__c> filterActions(List<NF_Form_Action__c> actions, String scope) {
        List<NF_Form_Action__c> filtered = new List<NF_Form_Action__c>();
        for (NF_Form_Action__c actionRecord : actions) {
            if (actionRecord.Action_Scope__c == scope) {
                filtered.add(actionRecord);
            }
        }
        return filtered;
    }

    private static List<NF_Form_Action__c> filterReferencedActions(List<NF_Form_Action__c> actions, String scope, List<NF_Form_Element__c> elements) {
        List<NF_Form_Action__c> scoped = filterActions(actions, scope);
        if (scoped.isEmpty()) {
            return scoped;
        }

        Set<String> referencedKeys = new Set<String>();
        Set<String> referencedAliases = new Set<String>();

        for (NF_Form_Element__c elementRecord : elements) {
            if (elementRecord == null || String.isBlank(elementRecord.Config_JSON__c)) {
                continue;
            }
            Map<String, Object> config = parseJsonMap(elementRecord.Config_JSON__c);
            if (scope == 'Submit') {
                if (booleanValue(config.get('submitEnabled'))) {
                    String actionKey = stringValue(config.get('submitActionKey'));
                    if (String.isNotBlank(actionKey)) {
                        referencedKeys.add(actionKey);
                    }
                }
            } else if (scope == 'Prefill') {
                if (booleanValue(config.get('prefillEnabled'))) {
                    String aliasValue = stringValue(config.get('prefillAlias'));
                    if (String.isNotBlank(aliasValue)) {
                        referencedAliases.add(aliasValue);
                    }
                }
            }
        }

        List<NF_Form_Action__c> filtered = new List<NF_Form_Action__c>();
        for (NF_Form_Action__c actionRecord : scoped) {
            if (scope == 'Submit' && referencedKeys.contains(actionRecord.Command_Key__c)) {
                filtered.add(actionRecord);
            }
            if (scope == 'Prefill' && referencedAliases.contains(actionRecord.Store_Result_As__c)) {
                filtered.add(actionRecord);
            }
        }
        return filtered;
    }

    private static NF_Form_Version__c createSuccessorDraft(
        NF_Form_Version__c publishedVersion,
        List<NF_Form_Element__c> elements,
        List<NF_Form_Action__c> actions
    ) {
        Integer nextVersionNumber = getNextVersionNumber(publishedVersion.Form__c);

        NF_Form_Version__c draftVersion = new NF_Form_Version__c(
            Form__c = publishedVersion.Form__c,
            Form_Id__c = publishedVersion.Form_Id__c,
            Version_Number__c = nextVersionNumber,
            Version_Status__c = 'Draft',
            Publish_Status__c = 'Never Published',
            Publish_Token__c = null,
            Security_Mode__c = publishedVersion.Security_Mode__c,
            Rate_Limit_Profile__c = publishedVersion.Rate_Limit_Profile__c,
            Custom_CSS__c = publishedVersion.Custom_CSS__c,
            Custom_JS__c = publishedVersion.Custom_JS__c,
            Theme_JSON__c = publishedVersion.Theme_JSON__c,
            UI_Settings_JSON__c = publishedVersion.UI_Settings_JSON__c,
            Prefill_Params_JSON__c = publishedVersion.Prefill_Params_JSON__c,
            Last_Published_At__c = null,
            Last_Published_By__c = null,
            Last_Publish_Error__c = null
        );
        insert draftVersion;

        List<NF_Form_Element__c> clonedElements = new List<NF_Form_Element__c>();
        for (NF_Form_Element__c sourceElement : elements) {
            NF_Form_Element__c cloneElement = sourceElement.clone(false, true, false, false);
            cloneElement.Form_Version__c = draftVersion.Id;
            clonedElements.add(cloneElement);
        }
        if (!clonedElements.isEmpty()) {
            insert clonedElements;
        }

        List<NF_Form_Action__c> clonedActions = new List<NF_Form_Action__c>();
        for (NF_Form_Action__c sourceAction : actions) {
            NF_Form_Action__c cloneAction = sourceAction.clone(false, true, false, false);
            cloneAction.Form_Version__c = draftVersion.Id;
            clonedActions.add(cloneAction);
        }
        if (!clonedActions.isEmpty()) {
            insert clonedActions;
        }

        return draftVersion;
    }

    private static Integer getNextVersionNumber(Id formId) {
        AggregateResult[] rows = [
            SELECT MAX(Version_Number__c) maxVersion
            FROM NF_Form_Version__c
            WHERE Form__c = :formId
        ];
        if (!rows.isEmpty() && rows[0].get('maxVersion') != null) {
            return Integer.valueOf(String.valueOf(rows[0].get('maxVersion'))) + 1;
        }
        return 1;
    }

    private static List<NF_Form_Element__c> prepareElementsForPublish(List<NF_Form_Element__c> elements) {
        if (elements == null || elements.isEmpty()) {
            return new List<NF_Form_Element__c>();
        }

        Map<String, NF_Form_Element__c> sectionsByElementId = new Map<String, NF_Form_Element__c>();
        Set<String> imageVersionIds = new Set<String>();
        for (NF_Form_Element__c elementRecord : elements) {
            if (elementRecord == null) {
                continue;
            }
            if (elementRecord.Element_Type__c == 'section' && String.isNotBlank(elementRecord.Element_Id__c)) {
                sectionsByElementId.put(elementRecord.Element_Id__c, elementRecord);
            }
            Map<String, Object> config = parseJsonMap(elementRecord.Config_JSON__c);
            String contentVersionId = stringValue(config.get('contentVersionId'));
            if (elementRecord.Element_Type__c == 'image' && String.isNotBlank(contentVersionId)) {
                imageVersionIds.add(contentVersionId);
            }
        }

        Map<String, String> publishedImageUrlsByVersionId = buildPublishedImageUrls(imageVersionIds);
        List<NF_Form_Element__c> filtered = new List<NF_Form_Element__c>();
        for (NF_Form_Element__c sourceRecord : elements) {
            if (sourceRecord == null) {
                continue;
            }

            Boolean isValidTopLevel = String.isBlank(sourceRecord.Parent_Element_Id__c);
            Boolean isValidSectionChild =
                String.isNotBlank(sourceRecord.Parent_Element_Id__c) &&
                sourceRecord.Parent_Element_Id__c != sourceRecord.Element_Id__c &&
                sectionsByElementId.containsKey(sourceRecord.Parent_Element_Id__c);

            if (!isValidTopLevel && !isValidSectionChild) {
                continue;
            }

            NF_Form_Element__c cloneRecord = sourceRecord.clone(false, true, false, false);
            if (cloneRecord.Element_Type__c == 'image') {
                Map<String, Object> config = parseJsonMap(cloneRecord.Config_JSON__c);
                String contentVersionId = stringValue(config.get('contentVersionId'));
                if (String.isNotBlank(contentVersionId) && publishedImageUrlsByVersionId.containsKey(contentVersionId)) {
                    config.put('publishedAssetUrl', publishedImageUrlsByVersionId.get(contentVersionId));
                    cloneRecord.Config_JSON__c = JSON.serialize(config);
                }
            }
            filtered.add(cloneRecord);
        }
        return filtered;
    }

    private static Map<String, String> buildPublishedImageUrls(Set<String> contentVersionIds) {
        Map<String, String> urlsByVersionId = new Map<String, String>();
        if (contentVersionIds == null || contentVersionIds.isEmpty()) {
            return urlsByVersionId;
        }

        for (ContentVersion versionRecord : [
            SELECT Id, PathOnClient, VersionData
            FROM ContentVersion
            WHERE Id IN :contentVersionIds
        ]) {
            String mimeType = mimeTypeFromFileName(versionRecord.PathOnClient);
            if (String.isBlank(mimeType) || versionRecord.VersionData == null) {
                continue;
            }
            urlsByVersionId.put(
                String.valueOf(versionRecord.Id),
                'data:' + mimeType + ';base64,' + EncodingUtil.base64Encode(versionRecord.VersionData)
            );
        }

        return urlsByVersionId;
    }

    private static Map<String, Object> buildPolicy(List<NF_Form_Action__c> actions, List<NF_Form_Element__c> elements, Boolean isPrefill) {
        Set<String> commands = new Set<String>();
        Set<String> objects = new Set<String>();
        Map<String, Set<String>> allowedWriteFields = new Map<String, Set<String>>();

        for (NF_Form_Action__c actionRecord : actions) {
            String canonicalObject = canonicalObjectApiName(actionRecord.Object_Api_Name__c);
            for (String expandedType : expandCommandTypesForPolicy(actionRecord.Command_Type__c, parseJsonMap(actionRecord.Config_JSON__c))) {
                if (String.isNotBlank(expandedType)) {
                    commands.add(expandedType);
                }
            }
            if (String.isNotBlank(canonicalObject)) {
                objects.add(canonicalObject);
            }

            if (!isPrefill && String.isNotBlank(actionRecord.Command_Key__c) && String.isNotBlank(canonicalObject)) {
                if (!allowedWriteFields.containsKey(canonicalObject)) {
                    allowedWriteFields.put(canonicalObject, new Set<String>());
                }
                collectAllowedWriteFields(allowedWriteFields.get(canonicalObject), actionRecord.Command_Key__c, canonicalObject, elements);
            }
        }

        Map<String, Object> policy = new Map<String, Object>{
            'allowedCommands' => new List<String>(commands),
            'allowedObjects' => new List<String>(objects)
        };
        if (!isPrefill) {
            Map<String, Object> writeFieldsOut = new Map<String, Object>();
            for (String objectApiName : allowedWriteFields.keySet()) {
                writeFieldsOut.put(objectApiName, new List<String>(allowedWriteFields.get(objectApiName)));
            }
            policy.put('allowedWriteFields', writeFieldsOut);
        }

        return policy;
    }

    private static Map<String, Object> buildDefinition(List<NF_Form_Action__c> actions, Boolean isPrefill, List<NF_Form_Element__c> elements) {
        List<Object> commands = new List<Object>();
        Map<String, Object> response = new Map<String, Object>();

        for (NF_Form_Action__c actionRecord : actions) {
            if (isPrefill) {
                Map<String, Object> commandConfig = parseJsonMap(actionRecord.Config_JSON__c);
                String normalizedType = normalizeCommandType(actionRecord.Command_Type__c, commandConfig);
                if (String.isBlank(normalizedType)) {
                    continue;
                }
                commandConfig.put('type', normalizedType);

                if (String.isNotBlank(actionRecord.Command_Key__c)) {
                    commandConfig.put('commandKey', actionRecord.Command_Key__c);
                }
                String canonicalObject = canonicalObjectApiName(actionRecord.Object_Api_Name__c);
                if (String.isNotBlank(canonicalObject)) {
                    commandConfig.put('objectApiName', canonicalObject);
                }
                if (String.isNotBlank(actionRecord.Store_Result_As__c)) {
                    commandConfig.put('storeResultAs', actionRecord.Store_Result_As__c);
                }
                String whereClause = buildConditionWhereClause(commandConfig, canonicalObject);
                if (String.isNotBlank(whereClause)) {
                    commandConfig.put('whereClause', whereClause);
                }
                commands.add(commandConfig);
                continue;
            }

            commands.addAll(buildSubmitCommandsForAction(actionRecord, elements));
        }

        if (isPrefill) {
            return new Map<String, Object>{
                'onNotFound' => 'ignore',
                'commands' => commands,
                'responseMapping' => response
            };
        }

        return new Map<String, Object>{
            'commands' => commands
        };
    }

    private static List<Object> buildSubmitCommandsForAction(NF_Form_Action__c actionRecord, List<NF_Form_Element__c> elements) {
        List<Object> commands = new List<Object>();
        if (actionRecord == null) {
            return commands;
        }

        Map<String, Object> commandConfig = parseJsonMap(actionRecord.Config_JSON__c);
        String canonicalObject = canonicalObjectApiName(actionRecord.Object_Api_Name__c);
        String actionKey = actionRecord.Command_Key__c;
        String commandType = actionRecord.Command_Type__c;

        if (commandType == 'findAndUpdate') {
            String whereClause = buildConditionWhereClause(commandConfig, canonicalObject);
            if (String.isBlank(actionKey) || String.isBlank(canonicalObject) || String.isBlank(whereClause)) {
                return commands;
            }
            String onNotFound = String.isBlank(stringValue(commandConfig.get('onNotFound')))
                ? 'create'
                : stringValue(commandConfig.get('onNotFound'));

            String lookupAlias = String.isNotBlank(actionRecord.Store_Result_As__c)
                ? actionRecord.Store_Result_As__c
                : actionKey + 'Match';

            Map<String, Object> findCommand = new Map<String, Object>{
                'type' => 'findOne',
                'commandKey' => actionKey + '_find',
                'objectApiName' => canonicalObject,
                'whereClause' => whereClause,
                'fieldsToReturn' => new List<String>{ 'Id' },
                'storeResultAs' => lookupAlias
            };
            commands.add(findCommand);

            Map<String, Object> updateCommand = new Map<String, Object>{
                'type' => 'update',
                'commandKey' => actionKey,
                'objectApiName' => canonicalObject,
                'storeResultAs' => actionRecord.Store_Result_As__c,
                'id' => '{' + lookupAlias + '.Id}',
                'runIf' => new Map<String, Object>{
                    'var' => lookupAlias + '.Id',
                    'isNotBlank' => true
                }
            };
            applySubmitFieldMappings(updateCommand, actionRecord, canonicalObject, elements);
            commands.add(updateCommand);

            if (onNotFound == 'create') {
                Map<String, Object> createCommand = new Map<String, Object>{
                    'type' => 'create',
                    'commandKey' => actionKey + '_create',
                    'objectApiName' => canonicalObject,
                    'storeResultAs' => actionRecord.Store_Result_As__c,
                    'runIf' => new Map<String, Object>{
                        'var' => lookupAlias + '.Id',
                        'isBlank' => true
                    }
                };
                applySubmitFieldMappings(createCommand, actionRecord, canonicalObject, elements);
                commands.add(createCommand);
            }
            return commands;
        }

        String normalizedType = normalizeCommandType(commandType, commandConfig);
        if (String.isBlank(normalizedType)) {
            return commands;
        }

        commandConfig.put('type', normalizedType);
        if (String.isNotBlank(actionKey)) {
            commandConfig.put('commandKey', actionKey);
        }
        if (String.isNotBlank(canonicalObject)) {
            commandConfig.put('objectApiName', canonicalObject);
        }
        if (String.isNotBlank(actionRecord.Store_Result_As__c)) {
            commandConfig.put('storeResultAs', actionRecord.Store_Result_As__c);
        }
        applySubmitFieldMappings(commandConfig, actionRecord, canonicalObject, elements);
        commands.add(commandConfig);
        return commands;
    }

    private static void applySubmitFieldMappings(
        Map<String, Object> commandConfig,
        NF_Form_Action__c actionRecord,
        String canonicalObjectApiName,
        List<NF_Form_Element__c> elements
    ) {
        if (commandConfig == null || actionRecord == null || elements == null || elements.isEmpty()) {
            return;
        }

        Map<String, Object> fields = new Map<String, Object>();
        String actionKey = actionRecord.Command_Key__c;
        if (String.isBlank(actionKey)) {
            return;
        }

        for (NF_Form_Element__c elementRecord : elements) {
            if (elementRecord == null || String.isBlank(elementRecord.Field_Key__c) || String.isBlank(elementRecord.Config_JSON__c)) {
                continue;
            }

            Map<String, Object> elementConfig = parseJsonMap(elementRecord.Config_JSON__c);
            String submitActionKey = stringValue(elementConfig.get('submitActionKey'));
            String submitFieldPath = stringValue(elementConfig.get('submitFieldPath'));
            Boolean submitEnabled = booleanValue(elementConfig.get('submitEnabled'));

            if (!submitEnabled || String.isBlank(submitActionKey) || String.isBlank(submitFieldPath)) {
                continue;
            }
            if (submitActionKey != actionKey) {
                continue;
            }

            submitFieldPath = canonicalFieldApiName(canonicalObjectApiName, submitFieldPath);
            if (String.isBlank(submitFieldPath)) {
                continue;
            }

            String inputExpression = '{input.' + elementRecord.Field_Key__c + '}';
            if (String.isBlank(submitFieldPath) || String.isBlank(inputExpression)) {
                continue;
            }

            fields.put(String.valueOf(submitFieldPath), inputExpression);
        }

        if (!fields.isEmpty()) {
            commandConfig.put('fields', fields);
        }

        String normalizedType = stringValue(commandConfig.get('type'));
        if (normalizedType == 'update') {
            String recordIdSource = stringValue(commandConfig.get('recordIdSource'));
            if (String.isNotBlank(recordIdSource)) {
                commandConfig.put('id', recordIdSource);
            }
        }
    }

    private static String normalizeCommandType(String commandType, Map<String, Object> config) {
        if (String.isBlank(commandType)) {
            return null;
        }
        if (commandType == 'updateById') {
            return 'update';
        }
        if (commandType == 'findAndUpdate') {
            return null;
        }
        return commandType;
    }

    private static List<String> expandCommandTypesForPolicy(String commandType, Map<String, Object> config) {
        if (String.isBlank(commandType)) {
            return new List<String>();
        }
        if (commandType == 'findAndUpdate') {
            String whereClause = buildConditionWhereClause(config, null);
            if (String.isBlank(whereClause)) {
                return new List<String>();
            }
            String onNotFound = stringValue(config.get('onNotFound'));
            return onNotFound == 'create'
                ? new List<String>{ 'findOne', 'update', 'create' }
                : new List<String>{ 'findOne', 'update' };
        }

        String normalized = normalizeCommandType(commandType, config);
        if (String.isBlank(normalized)) {
            return new List<String>();
        }
        if (commandType == 'updateById' && stringValue(config.get('onNotFound')) == 'create') {
            return new List<String>{ normalized, 'create' };
        }
        return new List<String>{ normalized };
    }

    private static String buildConditionWhereClause(Map<String, Object> config, String objectApiName) {
        if (config == null) {
            return null;
        }

        Object rawConditions = config.get('conditions');
        List<String> clauses = new List<String>();
        if (rawConditions instanceof List<Object>) {
            for (Object rawItem : (List<Object>) rawConditions) {
                if (!(rawItem instanceof Map<String, Object>)) {
                    continue;
                }
                Map<String, Object> condition = (Map<String, Object>) rawItem;
                String fieldApiName = canonicalFieldApiName(objectApiName, stringValue(condition.get('fieldApiName')));
                String operator = stringValue(condition.get('operator'));
                String paramName = stringValue(condition.get('paramName'));
                String clause = buildConditionClause(fieldApiName, operator, paramName);
                if (String.isNotBlank(clause)) {
                    clauses.add(clause);
                }
            }
        }

        if (!clauses.isEmpty()) {
            String logic = stringValue(config.get('conditionLogic'));
            logic = logic == 'OR' ? 'OR' : 'AND';
            return String.join(clauses, ' ' + logic + ' ');
        }

        return stringValue(config.get('where'));
    }

    private static String buildConditionClause(String fieldApiName, String operator, String paramName) {
        if (String.isBlank(fieldApiName) || String.isBlank(operator)) {
            return null;
        }

        String expression = String.isBlank(paramName) ? null : '{params.' + paramName + '}';
        if (operator == 'isBlank') {
            return '(' + fieldApiName + ' = null OR ' + fieldApiName + ' = \'\')';
        }
        if (operator == 'isNotBlank') {
            return '(' + fieldApiName + ' != null AND ' + fieldApiName + ' != \'\')';
        }
        if (String.isBlank(expression)) {
            return null;
        }
        if (operator == 'eq') {
            return fieldApiName + ' = \'' + expression + '\'';
        }
        if (operator == 'neq') {
            return fieldApiName + ' != \'' + expression + '\'';
        }
        if (operator == 'contains') {
            return fieldApiName + ' LIKE \'%' + expression + '%\'';
        }
        if (operator == 'startsWith') {
            return fieldApiName + ' LIKE \'' + expression + '%\'';
        }
        if (operator == 'gt') {
            return fieldApiName + ' > \'' + expression + '\'';
        }
        if (operator == 'lt') {
            return fieldApiName + ' < \'' + expression + '\'';
        }
        return null;
    }

    private static Map<String, Object> parseWhereClause(String rawWhereClause, String objectApiName) {
        Map<String, Object> whereObject = new Map<String, Object>();
        if (String.isBlank(rawWhereClause)) {
            return whereObject;
        }

        List<String> conditions = rawWhereClause.split('(?i)\\s+AND\\s+');
        for (String condition : conditions) {
            if (String.isBlank(condition) || !condition.contains('=')) {
                continue;
            }

            List<String> parts = condition.split('=', 2);
            if (parts.size() != 2) {
                continue;
            }

            String fieldApiName = canonicalFieldApiName(objectApiName, parts[0].trim());
            String rawValue = parts[1].trim();
            if (String.isBlank(fieldApiName) || String.isBlank(rawValue)) {
                continue;
            }

            if (
                (rawValue.startsWith('\'') && rawValue.endsWith('\'')) ||
                (rawValue.startsWith('"') && rawValue.endsWith('"'))
            ) {
                rawValue = rawValue.substring(1, rawValue.length() - 1);
            }

            whereObject.put(fieldApiName, rawValue);
        }

        return whereObject;
    }

    private static void collectAllowedWriteFields(
        Set<String> fieldNames,
        String actionKey,
        String objectApiName,
        List<NF_Form_Element__c> elements
    ) {
        if (fieldNames == null || String.isBlank(actionKey) || String.isBlank(objectApiName) || elements == null) {
            return;
        }

        for (NF_Form_Element__c elementRecord : elements) {
            if (elementRecord == null || String.isBlank(elementRecord.Config_JSON__c)) {
                continue;
            }
            Map<String, Object> elementConfig = parseJsonMap(elementRecord.Config_JSON__c);
            String submitActionKey = stringValue(elementConfig.get('submitActionKey'));
            String submitFieldPath = canonicalFieldApiName(objectApiName, stringValue(elementConfig.get('submitFieldPath')));
            Boolean submitEnabled = booleanValue(elementConfig.get('submitEnabled'));

            if (!submitEnabled || String.isBlank(submitActionKey) || String.isBlank(submitFieldPath)) {
                continue;
            }
            if (submitActionKey != actionKey) {
                continue;
            }

            fieldNames.add(submitFieldPath);
        }
    }

    private static Map<String, Object> parseJsonMap(String rawJson) {
        if (String.isBlank(rawJson)) {
            return new Map<String, Object>();
        }

        try {
            return (Map<String, Object>) JSON.deserializeUntyped(rawJson);
        } catch (Exception ignored) {
            return new Map<String, Object>();
        }
    }

    private static String buildHtml(NF_Form_Version__c versionRecord, List<NF_Form_Element__c> elements, String formId, String publishToken) {
        Map<String, Object> theme = parseJsonMap(versionRecord.Theme_JSON__c);
        Map<String, Object> uiSettings = parseJsonMap(versionRecord.UI_Settings_JSON__c);
        String titleText = firstNonBlank(
            stringValue(uiSettings.get('title')),
            stringValue(uiSettings.get('formTitle')),
            versionRecord.Form_Id__c,
            'NativeForms Form'
        );
        String introText = firstNonBlank(
            stringValue(uiSettings.get('description')),
            stringValue(uiSettings.get('introText')),
            ''
        );
        String submitLabel = firstNonBlank(
            stringValue(uiSettings.get('submitLabel')),
            'Submit'
        );

        String html = '';
        html += '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">';
        html += '<meta name="viewport" content="width=device-width, initial-scale=1.0">';
        html += '<title>' + escapeHtml(titleText) + '</title>';
        html += '<style>';
        html += ':root{';
        html += '--nf-bg:' + cssColor(theme, 'pageBackground', '#f4f7fb') + ';';
        html += '--nf-surface:' + cssColor(theme, 'cardBackground', '#ffffff') + ';';
        html += '--nf-text:' + cssColor(theme, 'textColor', '#16325c') + ';';
        html += '--nf-border:' + cssColor(theme, 'borderColor', '#d8dde6') + ';';
        html += '--nf-muted:' + cssColor(theme, 'mutedTextColor', '#5f6f89') + ';';
        html += '--nf-accent:' + cssColor(theme, 'primaryColor', '#0f6cbd') + ';';
        html += '--nf-accent-contrast:' + cssColor(theme, 'primaryTextColor', '#ffffff') + ';';
        html += '--nf-radius:' + cssLength(theme, 'borderRadius', '16px') + ';';
        html += '--nf-field-radius:' + cssLength(theme, 'fieldBorderRadius', '10px') + ';';
        html += '--nf-font:' + cssFontFamily(theme, 'fontFamily', '\'Segoe UI\', Arial, sans-serif') + ';';
        html += '}';
        html += 'body{font-family:var(--nf-font);background:linear-gradient(180deg,var(--nf-bg),#edf2f8);color:var(--nf-text);margin:0;padding:24px;}';
        html += '.nf-shell{max-width:880px;margin:0 auto;background:var(--nf-surface);border:1px solid var(--nf-border);border-radius:var(--nf-radius);padding:32px;box-shadow:0 16px 44px rgba(22,50,92,.10);}';
        html += '.nf-grid{display:grid;gap:16px;}';
        html += '.nf-section{padding:18px 20px;border:1px solid var(--nf-border);border-radius:calc(var(--nf-radius) - 4px);background:rgba(255,255,255,.65);}';
        html += '.nf-section--plain{padding:0;border:0;background:transparent;border-radius:0;}';
        html += '.nf-section h2{margin:0 0 8px;font-size:20px;}';
        html += '.nf-section__grid{display:grid;gap:18px;}';
        html += '.nf-section__grid--1{grid-template-columns:1fr;}';
        html += '.nf-section__grid--2{grid-template-columns:repeat(2,minmax(0,1fr));}';
        html += '.nf-section__grid--3{grid-template-columns:repeat(3,minmax(0,1fr));}';
        html += '.nf-section__grid--4{grid-template-columns:repeat(4,minmax(0,1fr));}';
        html += '.nf-section__column{display:grid;gap:16px;align-content:start;}';
        html += '.nf-copy{margin:0;color:var(--nf-muted);line-height:1.6;}';
        html += '.nf-richtext{color:var(--nf-text);line-height:1.6;}';
        html += '.nf-richtext a{color:var(--nf-accent);text-decoration:underline;}';
        html += '.nf-image{display:block;max-width:100%;height:auto;border-radius:var(--nf-field-radius);}';
        html += '.nf-image-wrap{display:flex;}';
        html += '.nf-image-wrap--left{justify-content:flex-start;}';
        html += '.nf-image-wrap--center,.nf-image-wrap--original{justify-content:center;}';
        html += '.nf-image-wrap--right{justify-content:flex-end;}';
        html += '.nf-image-wrap--stretch{justify-content:stretch;}';
        html += '.nf-image--stretch{width:100%;max-width:100%;object-fit:cover;}';
        html += '.nf-field{display:grid;gap:6px;align-items:start;}';
        html += '.nf-field label{display:block;font-weight:400;}';
        html += '.nf-field label.nf-label--bold{font-weight:700;}';
        html += '.nf-field--above{grid-template-columns:minmax(0,1fr);}';
        html += '.nf-field--left{grid-template-columns:140px minmax(0,1fr);column-gap:12px;}';
        html += '.nf-field--left label{padding-top:12px;word-break:break-word;}';
        html += '.nf-field--right{grid-template-columns:minmax(0,1fr) auto;column-gap:12px;align-items:center;}';
        html += '.nf-field--right label{word-break:break-word;text-align:left;}';
        html += '.nf-field--hidden label{display:none;}';
        html += '.nf-field input,.nf-field textarea,.nf-field select{width:100%;padding:12px 14px;border:1px solid #c9d3df;border-radius:var(--nf-field-radius);font:inherit;box-sizing:border-box;background:#fff;color:var(--nf-text);}';
        html += '.nf-field textarea{min-height:120px;resize:vertical;}';
        html += '.nf-field--checkbox label{display:flex;gap:10px;align-items:center;font-weight:400;}';
        html += '.nf-field--checkbox input{width:auto;}';
        html += '.nf-field--radio-group{display:grid;gap:10px;}';
        html += '.nf-radio-option{display:flex;gap:10px;align-items:center;padding:10px 12px;border:1px solid #d8dde6;border-radius:var(--nf-field-radius);background:#fff;}';
        html += '.nf-radio-option input{width:auto;margin:0;}';
        html += '.nf-status{margin-top:16px;padding:12px 14px;border-radius:12px;display:none;}';
        html += '.nf-status--success{display:block;background:#e8f6ee;color:#165b33;border:1px solid #b8e0c7;}';
        html += '.nf-status--error{display:block;background:#fde7e9;color:#7f1d1d;border:1px solid #f5c2c7;}';
        html += '.nf-actions{margin-top:28px;display:flex;justify-content:flex-end;}';
        html += '.nf-actions button{background:var(--nf-accent);color:var(--nf-accent-contrast);border:0;border-radius:999px;padding:12px 20px;font-weight:700;cursor:pointer;box-shadow:0 10px 20px rgba(15,108,189,.18);}';
        html += '.nf-meta{display:none;}';
        if (String.isNotBlank(versionRecord.Custom_CSS__c)) {
            html += versionRecord.Custom_CSS__c;
        }
        html += '</style></head><body>';
        html += '<div class="nf-shell">';
        html += '<form class="nf-grid" data-nativeforms-version="' + escapeHtml(String.valueOf(versionRecord.Id)) + '">';
        html += '<input class="nf-meta" type="hidden" name="nativeformsVersionId" value="' + escapeHtml(String.valueOf(versionRecord.Id)) + '">';

        Map<String, List<NF_Form_Element__c>> childrenByParent = new Map<String, List<NF_Form_Element__c>>();
        Set<String> sectionElementIds = new Set<String>();
        for (NF_Form_Element__c elementRecord : elements) {
            if (elementRecord.Element_Type__c == 'section' && String.isNotBlank(elementRecord.Element_Id__c)) {
                sectionElementIds.add(elementRecord.Element_Id__c);
            }
        }

        List<NF_Form_Element__c> topLevelElements = new List<NF_Form_Element__c>();
        for (NF_Form_Element__c elementRecord : elements) {
            Boolean isValidChild =
                String.isNotBlank(elementRecord.Parent_Element_Id__c) &&
                elementRecord.Parent_Element_Id__c != elementRecord.Element_Id__c &&
                sectionElementIds.contains(elementRecord.Parent_Element_Id__c);
            if (String.isBlank(elementRecord.Parent_Element_Id__c)) {
                topLevelElements.add(elementRecord);
            } else if (isValidChild) {
                if (!childrenByParent.containsKey(elementRecord.Parent_Element_Id__c)) {
                    childrenByParent.put(elementRecord.Parent_Element_Id__c, new List<NF_Form_Element__c>());
                }
                childrenByParent.get(elementRecord.Parent_Element_Id__c).add(elementRecord);
            }
        }

        topLevelElements.sort(new ElementOrderSorter());
        for (String parentKey : childrenByParent.keySet()) {
            childrenByParent.get(parentKey).sort(new ElementOrderSorter());
        }

        for (NF_Form_Element__c elementRecord : topLevelElements) {
            html += renderElement(elementRecord, childrenByParent);
        }

        html += '<div class="nf-actions"><button type="submit">' + escapeHtml(submitLabel) + '</button></div>';
        html += '<div class="nf-status" data-nativeforms-status></div>';
        html += '</form></div>';
        html += '<script>window.NativeFormsConfig=' + JSON.serialize(new Map<String, Object>{
            'versionId' => (String) versionRecord.Id,
            'formId' => formId,
            'publishToken' => publishToken,
            'submitUrl' => TEMP_SUBMIT_URL,
            'theme' => theme,
            'uiSettings' => uiSettings
        }) + ';</script>';
        html += '<script>(function(){';
        html += 'const config=window.NativeFormsConfig||{};';
        html += 'const form=document.querySelector("form[data-nativeforms-version]");';
        html += 'const statusEl=document.querySelector("[data-nativeforms-status]");';
        html += 'if(!form||!config.submitUrl){return;}';
        html += 'function setStatus(kind,message){if(!statusEl){return;}statusEl.className="nf-status nf-status--"+kind;statusEl.textContent=message||"";}';
        html += 'function clearStatus(){if(!statusEl){return;}statusEl.className="nf-status";statusEl.textContent="";}';
        html += 'function readFieldValue(fieldKey){const fields=form.querySelectorAll("[name=\'"+fieldKey+"\']");if(!fields.length){return "";}const first=fields[0];if(first.type==="checkbox"){return !!first.checked;}if(first.type==="radio"){const checked=form.querySelector("[name=\'"+fieldKey+"\']:checked");return checked?checked.value:"";}return first.value||"";}';
        html += 'function isoDate(value){return value.toISOString().split("T")[0];}';
        html += 'function applyDateConstraints(){form.querySelectorAll("input[type=\'date\']").forEach(function(el){const now=new Date();let minDate=null;let maxDate=null;const pastYears=Number(el.dataset.pastYears||0);const pastMonths=Number(el.dataset.pastMonths||0);const futureYears=Number(el.dataset.futureYears||0);const futureMonths=Number(el.dataset.futureMonths||0);if(pastYears||pastMonths){minDate=new Date(now);minDate.setFullYear(minDate.getFullYear()-pastYears);minDate.setMonth(minDate.getMonth()-pastMonths);}if(futureYears||futureMonths){maxDate=new Date(now);maxDate.setFullYear(maxDate.getFullYear()+futureYears);maxDate.setMonth(maxDate.getMonth()+futureMonths);}if(minDate){el.min=isoDate(minDate);}if(maxDate){el.max=isoDate(maxDate);}});}';
        html += 'function validateField(el){if(!el||el.type==="hidden"){return true;}const valid=el.checkValidity();if(!valid){el.reportValidity();}return valid;}';
        html += 'function wireLiveValidation(){form.querySelectorAll("input,textarea,select").forEach(function(el){if(el.type==="hidden"){return;}["input","change","blur"].forEach(function(evt){el.addEventListener(evt,function(){validateField(el);});});});}';
        html += 'function evaluateConditions(){form.querySelectorAll("[data-condition-source]").forEach(function(el){const source=el.dataset.conditionSource;const operator=el.dataset.conditionOperator;const compare=el.dataset.conditionValue||"";const actual=readFieldValue(source);let visible=true;if(operator==="equals"){visible=String(actual)===compare;}else if(operator==="notEquals"){visible=String(actual)!==compare;}else if(operator==="isTrue"){visible=actual===true||String(actual).toLowerCase()==="true";}else if(operator==="isFalse"){visible=actual===false||String(actual).toLowerCase()==="false"||String(actual)==="";}else if(operator==="isBlank"){visible=String(actual)==="";}else if(operator==="isNotBlank"){visible=String(actual)!=="";}el.style.display=visible?"":"none";});}';
        html += 'applyDateConstraints();';
        html += 'wireLiveValidation();';
        html += 'form.addEventListener("change",evaluateConditions);';
        html += 'evaluateConditions();';
        html += 'form.addEventListener("submit",async function(event){event.preventDefault();clearStatus();';
        html += 'if(!form.reportValidity()){return;}';
        html += 'const submitButton=form.querySelector("button[type=\'submit\']");if(submitButton){submitButton.disabled=true;}';
        html += 'try{const formData=new FormData(form);const input={};for(const [key,value] of formData.entries()){input[key]=value;}';
        html += 'form.querySelectorAll("input[type=\'checkbox\'][name]").forEach(function(el){input[el.name]=!!el.checked;});';
        html += 'const response=await fetch(config.submitUrl,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({formId:config.formId,publishToken:config.publishToken,input:input})});';
        html += 'const data=await response.json();';
        html += 'if(!response.ok||data.success===false){throw new Error((data.error&&data.error.message)||data.error||"Submit failed");}';
        html += 'setStatus("success","Form submitted successfully.");form.reset();';
        html += '}catch(error){setStatus("error",error&&error.message?error.message:"Submit failed.");}finally{if(submitButton){submitButton.disabled=false;}}';
        html += '});';
        html += '})();</script>';
        if (String.isNotBlank(versionRecord.Custom_JS__c)) {
            html += '<script>' + versionRecord.Custom_JS__c + '</script>';
        }
        html += '</body></html>';
        return html;
    }

    private static String renderElement(NF_Form_Element__c elementRecord, Map<String, List<NF_Form_Element__c>> childrenByParent) {
        Map<String, Object> config = parseJsonMap(elementRecord.Config_JSON__c);
        String typeValue = String.isBlank(elementRecord.Element_Type__c) ? 'text' : elementRecord.Element_Type__c;
        String fieldName = String.isNotBlank(elementRecord.Field_Key__c) ? elementRecord.Field_Key__c : String.valueOf(elementRecord.Id);
        String label = String.isNotBlank(elementRecord.Label__c) ? elementRecord.Label__c : fieldName;
        String placeholder = config.containsKey('placeholder') ? String.valueOf(config.get('placeholder')) : '';
        Boolean required = config.containsKey('required') ? Boolean.valueOf(String.valueOf(config.get('required'))) : false;
        String defaultValue = config.containsKey('defaultValue') ? String.valueOf(config.get('defaultValue')) : '';
        Boolean checkedByDefault = config.containsKey('checked') ? Boolean.valueOf(String.valueOf(config.get('checked'))) : false;
        String hiddenValue = config.containsKey('value') ? String.valueOf(config.get('value')) : '';
        String requiredAttr = required ? ' required' : '';
        String placeholderAttr = String.isNotBlank(placeholder) ? ' placeholder="' + escapeHtml(placeholder) + '"' : '';
        String minAttr = config.containsKey('minValue') && String.isNotBlank(String.valueOf(config.get('minValue')))
            ? ' min="' + escapeHtml(String.valueOf(config.get('minValue'))) + '"'
            : '';
        String maxAttr = config.containsKey('maxValue') && String.isNotBlank(String.valueOf(config.get('maxValue')))
            ? ' max="' + escapeHtml(String.valueOf(config.get('maxValue'))) + '"'
            : '';
        String dateRangeAttrs = typeValue == 'date' ? dateRangeDataAttrs(config) : '';
        String patternAttr = textPatternAttr(config);
        String safeName = escapeHtml(fieldName);
        String safeLabel = escapeHtml(label);
        String safeElementId = escapeHtml(String.isNotBlank(elementRecord.Element_Id__c) ? elementRecord.Element_Id__c : String.valueOf(elementRecord.Id));
        String wrapperAttrs = conditionalDataAttrs(config) + hiddenBehaviorStyle(config);
        String labelPosition = normalizedLabelPosition(config);
        Boolean labelBold = booleanValue(config.get('labelBold'));
        String labelClassAttr = labelBold ? ' class="nf-label--bold"' : '';

        if (typeValue == 'section' || typeValue == 'sectionBreak') {
            String bodyText = config.containsKey('text') ? escapeHtml(String.valueOf(config.get('text'))) : '';
            Boolean showTitle = !config.containsKey('showTitle') || booleanValue(config.get('showTitle'));
            Boolean boxed = !config.containsKey('boxed') || booleanValue(config.get('boxed'));
            Integer columnCount = safeSectionColumnCount(config);
            List<NF_Form_Element__c> childElements = childrenByParent != null && String.isNotBlank(elementRecord.Element_Id__c)
                ? childrenByParent.get(elementRecord.Element_Id__c)
                : null;
            String sectionHtml = '<div class="nf-section' + (boxed ? '' : ' nf-section--plain') + '" data-element-id="' + safeElementId + '"' + wrapperAttrs + '>';
            if (showTitle) {
                sectionHtml += '<h2>' + safeLabel + '</h2>';
            }
            if (String.isNotBlank(bodyText) && bodyText != 'Section description') {
                sectionHtml += '<p class="nf-copy">' + bodyText + '</p>';
            }
            if (childElements != null && !childElements.isEmpty()) {
                sectionHtml += '<div class="nf-section__grid nf-section__grid--' + String.valueOf(columnCount) + '">';
                for (Integer columnIndex = 1; columnIndex <= columnCount; columnIndex++) {
                    sectionHtml += '<div class="nf-section__column">';
                    for (NF_Form_Element__c childElement : childElements) {
                        if (readSectionColumn(childElement.Config_JSON__c) == columnIndex) {
                            sectionHtml += renderElement(childElement, childrenByParent);
                        }
                    }
                    sectionHtml += '</div>';
                }
                sectionHtml += '</div>';
            }
            sectionHtml += '</div>';
            return sectionHtml;
        }

        if (typeValue == 'heading') {
            String richHtml = config.containsKey('html') ? String.valueOf(config.get('html')) : '';
            if (String.isNotBlank(richHtml)) {
                return '<div class="nf-richtext" data-element-id="' + safeElementId + '"' + wrapperAttrs + '>' + richHtml + '</div>';
            }
            return '<div class="nf-richtext" data-element-id="' + safeElementId + '"' + wrapperAttrs + '><p>' + safeLabel + '</p></div>';
        }

        if (typeValue == 'paragraph' || typeValue == 'richText') {
            String bodyHtml = config.containsKey('html') ? String.valueOf(config.get('html')) : '';
            if (String.isBlank(bodyHtml) && config.containsKey('text')) {
                bodyHtml = '<p>' + escapeHtml(String.valueOf(config.get('text'))) + '</p>';
            }
            if (String.isBlank(bodyHtml)) {
                bodyHtml = '<p>' + safeLabel + '</p>';
            }
            return '<div class="nf-richtext" data-element-id="' + safeElementId + '"' + wrapperAttrs + '>' + bodyHtml + '</div>';
        }

        if (typeValue == 'image') {
            String imageUrl = config.containsKey('publishedAssetUrl')
                ? String.valueOf(config.get('publishedAssetUrl'))
                : config.containsKey('imageUrl')
                    ? String.valueOf(config.get('imageUrl'))
                    : '';
            String altText = config.containsKey('altText') ? String.valueOf(config.get('altText')) : safeLabel;
            String imageFit = config.containsKey('imageFit') ? String.valueOf(config.get('imageFit')) : 'original';
            Integer imageWidthPercent = integerValue(config.get('imageWidthPercent'));
            if (imageWidthPercent == null || imageWidthPercent <= 0 || imageWidthPercent > 100) {
                imageWidthPercent = 100;
            }
            String imageStyleAttr = ' style="width:' + String.valueOf(imageWidthPercent) + '%;"';
            if (String.isNotBlank(imageUrl)) {
                return '<div class="nf-image-wrap nf-image-wrap--' + escapeHtml(imageFit) + '" data-element-id="' + safeElementId + '"' + wrapperAttrs + '><img class="nf-image nf-image--' + escapeHtml(imageFit) + '" src="' + escapeHtml(imageUrl) + '" alt="' + escapeHtml(altText) + '"' + imageStyleAttr + '></div>';
            }
            return '<div class="nf-copy" data-element-id="' + safeElementId + '"' + wrapperAttrs + '>' + escapeHtml(altText) + '</div>';
        }

        if (typeValue == 'textarea') {
            String labelHtml = labelPosition == 'hidden' ? '' : '<label for="' + safeName + '"' + labelClassAttr + '>' + safeLabel + '</label>';
            String controlHtml = '<textarea id="' + safeName + '" name="' + safeName + '"' + placeholderAttr + requiredAttr + patternAttr + '></textarea>';
            return renderFieldWrapper(safeElementId, wrapperAttrs, labelPosition, labelHtml, controlHtml);
        }
        if (typeValue == 'select' && config.containsKey('options')) {
            String optionsHtml = '<option value="">Select...</option>';
            for (Object rawOption : (List<Object>) config.get('options')) {
                if (rawOption instanceof Map<String, Object>) {
                    Map<String, Object> option = (Map<String, Object>) rawOption;
                    String optionValue = escapeHtml(String.valueOf(option.get('value')));
                    String optionLabel = escapeHtml(String.valueOf(option.get('label')));
                    String selectedAttr = String.valueOf(option.get('value')) == defaultValue ? ' selected' : '';
                    optionsHtml += '<option value="' + optionValue + '"' + selectedAttr + '>' + optionLabel + '</option>';
                }
            }
            String labelHtml = labelPosition == 'hidden' ? '' : '<label for="' + safeName + '"' + labelClassAttr + '>' + safeLabel + '</label>';
            String controlHtml = '<select id="' + safeName + '" name="' + safeName + '"' + requiredAttr + '>' + optionsHtml + '</select>';
            return renderFieldWrapper(safeElementId, wrapperAttrs, labelPosition, labelHtml, controlHtml);
        }
        if (typeValue == 'radio' && config.containsKey('options')) {
            String radiosHtml = '<div class="nf-field nf-field--' + escapeHtml(labelPosition) + '" data-element-id="' + safeElementId + '"' + wrapperAttrs + '>';
            if (labelPosition != 'hidden') {
                radiosHtml += '<label' + labelClassAttr + '>' + safeLabel + '</label>';
            }
            radiosHtml += '<div class="nf-field--radio-group">';
            Integer optionIndex = 0;
            for (Object rawOption : (List<Object>) config.get('options')) {
                if (rawOption instanceof Map<String, Object>) {
                    Map<String, Object> option = (Map<String, Object>) rawOption;
                    String optionValue = String.valueOf(option.get('value'));
                    String optionId = safeName + '-' + String.valueOf(optionIndex);
                    String checkedAttr = optionValue == defaultValue ? ' checked' : '';
                    radiosHtml += '<label class="nf-radio-option" for="' + escapeHtml(optionId) + '">';
                    radiosHtml += '<input type="radio" id="' + escapeHtml(optionId) + '" name="' + safeName + '" value="' + escapeHtml(optionValue) + '"' + checkedAttr + requiredAttr + '>';
                    radiosHtml += '<span>' + escapeHtml(String.valueOf(option.get('label'))) + '</span>';
                    radiosHtml += '</label>';
                    optionIndex += 1;
                }
            }
            radiosHtml += '</div></div>';
            return radiosHtml;
        }
        if (typeValue == 'checkbox') {
            String checkedAttr = checkedByDefault ? ' checked' : '';
            if (labelPosition == 'hidden') {
                return '<div class="nf-field nf-field--checkbox" data-element-id="' + safeElementId + '"' + wrapperAttrs + '><label><input type="checkbox" name="' + safeName + '"' + checkedAttr + requiredAttr + '></label></div>';
            }
            return '<div class="nf-field nf-field--checkbox nf-field--' + escapeHtml(labelPosition) + '" data-element-id="' + safeElementId + '"' + wrapperAttrs + '><label' + labelClassAttr + '><input type="checkbox" name="' + safeName + '"' + checkedAttr + requiredAttr + '> ' + safeLabel + '</label></div>';
        }
        if (typeValue == 'hidden') {
            return '<input type="hidden" data-element-id="' + safeElementId + '" name="' + safeName + '" value="' + escapeHtml(hiddenValue) + '">';
        }

        String htmlType = normalizeInputType(typeValue);
        String valueAttr = String.isNotBlank(defaultValue) ? ' value="' + escapeHtml(defaultValue) + '"' : '';
        String labelHtml = labelPosition == 'hidden' ? '' : '<label for="' + safeName + '"' + labelClassAttr + '>' + safeLabel + '</label>';
        String controlHtml = '<input type="' + escapeHtml(htmlType) + '" id="' + safeName + '" name="' + safeName + '"' + placeholderAttr + valueAttr + requiredAttr + minAttr + maxAttr + dateRangeAttrs + patternAttr + '>';
        return renderFieldWrapper(safeElementId, wrapperAttrs, labelPosition, labelHtml, controlHtml);
    }

    private static String renderFieldWrapper(String safeElementId, String wrapperAttrs, String labelPosition, String labelHtml, String controlHtml) {
        String normalizedPosition = String.isBlank(labelPosition) ? 'above' : labelPosition;
        String html = '<div class="nf-field nf-field--' + escapeHtml(normalizedPosition) + '" data-element-id="' + safeElementId + '"' + wrapperAttrs + '>';
        if (normalizedPosition == 'right') {
            html += controlHtml;
            html += labelHtml;
        } else {
            html += labelHtml;
            html += controlHtml;
        }
        html += '</div>';
        return html;
    }

    private static String normalizedLabelPosition(Map<String, Object> config) {
        String rawPosition = stringValue(config.get('labelPosition'));
        if (rawPosition == 'left' || rawPosition == 'right' || rawPosition == 'hidden') {
            return rawPosition;
        }
        return 'above';
    }

    private static Integer safeSectionColumnCount(Map<String, Object> config) {
        if (config == null || !config.containsKey('columns')) {
            return 2;
        }
        try {
            Integer columns = Integer.valueOf(String.valueOf(config.get('columns')));
            if (columns < 1) {
                return 1;
            }
            if (columns > 4) {
                return 4;
            }
            return columns;
        } catch (Exception e) {
            return 2;
        }
    }

    private static Integer readSectionColumn(String rawJson) {
        Map<String, Object> config = parseJsonMap(rawJson);
        if (config == null || !config.containsKey('sectionColumn')) {
            return 1;
        }
        try {
            Integer columnValue = Integer.valueOf(String.valueOf(config.get('sectionColumn')));
            if (columnValue < 1) {
                return 1;
            }
            if (columnValue > 4) {
                return 4;
            }
            return columnValue;
        } catch (Exception e) {
            return 1;
        }
    }

    private static String mimeTypeFromFileName(String fileName) {
        if (String.isBlank(fileName) || !fileName.contains('.')) {
            return null;
        }
        String extension = fileName.substringAfterLast('.').toLowerCase();
        if (extension == 'png') return 'image/png';
        if (extension == 'jpg' || extension == 'jpeg') return 'image/jpeg';
        if (extension == 'gif') return 'image/gif';
        if (extension == 'svg') return 'image/svg+xml';
        if (extension == 'webp') return 'image/webp';
        return 'application/octet-stream';
    }

    private static String conditionalDataAttrs(Map<String, Object> config) {
        if (config == null || !booleanValue(config.get('conditionalEnabled'))) {
            return '';
        }
        String fieldKey = stringValue(config.get('conditionalFieldKey'));
        String operator = stringValue(config.get('conditionalOperator'));
        String value = stringValue(config.get('conditionalValue'));
        if (String.isBlank(fieldKey) || String.isBlank(operator)) {
            return '';
        }
        String attrs = ' data-condition-source="' + escapeHtml(fieldKey) + '"';
        attrs += ' data-condition-operator="' + escapeHtml(operator) + '"';
        attrs += ' data-condition-value="' + escapeHtml(value) + '"';
        return attrs;
    }

    private static String hiddenBehaviorStyle(Map<String, Object> config) {
        if (config != null && stringValue(config.get('fieldBehavior')) == 'hidden') {
            return ' style="display:none;"';
        }
        return '';
    }

    private static String textPatternAttr(Map<String, Object> config) {
        if (config == null) {
            return '';
        }
        String rule = stringValue(config.get('textRule'));
        if (rule == 'alphanumeric') {
            return ' pattern="[A-Za-z0-9 ]+"';
        }
        if (rule == 'letters') {
            return ' pattern="[A-Za-z ]+"';
        }
        if (rule == 'numbers') {
            return ' pattern="[0-9]+"';
        }
        return '';
    }

    private static String dateRangeDataAttrs(Map<String, Object> config) {
        if (config == null) {
            return '';
        }
        List<String> attrs = new List<String>();
        if (config.containsKey('pastYears')) {
            attrs.add(' data-past-years="' + escapeHtml(String.valueOf(config.get('pastYears'))) + '"');
        }
        if (config.containsKey('pastMonths')) {
            attrs.add(' data-past-months="' + escapeHtml(String.valueOf(config.get('pastMonths'))) + '"');
        }
        if (config.containsKey('futureYears')) {
            attrs.add(' data-future-years="' + escapeHtml(String.valueOf(config.get('futureYears'))) + '"');
        }
        if (config.containsKey('futureMonths')) {
            attrs.add(' data-future-months="' + escapeHtml(String.valueOf(config.get('futureMonths'))) + '"');
        }
        return String.join(attrs, '');
    }

    private static String normalizeInputType(String typeValue) {
        Set<String> allowed = new Set<String>{ 'text', 'email', 'number', 'date', 'datetime-local', 'tel', 'url', 'hidden' };
        return allowed.contains(typeValue) ? typeValue : 'text';
    }

    public class ElementOrderSorter implements Comparator<NF_Form_Element__c> {
        public Integer compare(NF_Form_Element__c a, NF_Form_Element__c b) {
            Integer orderA = a.Order__c == null ? 0 : Integer.valueOf(String.valueOf(a.Order__c));
            Integer orderB = b.Order__c == null ? 0 : Integer.valueOf(String.valueOf(b.Order__c));
            if (orderA == orderB) {
                return String.valueOf(a.Id).compareTo(String.valueOf(b.Id));
            }
            return orderA < orderB ? -1 : 1;
        }
    }

    private static String escapeHtml(String value) {
        if (value == null) {
            return '';
        }

        return value
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace('\'', '&#39;');
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
        String stringValue = String.valueOf(value);
        return String.isNotBlank(stringValue) && stringValue.toLowerCase() == 'true';
    }

    private static Integer integerValue(Object value) {
        if (value == null) {
            return null;
        }
        try {
            return Integer.valueOf(String.valueOf(value));
        } catch (Exception e) {
            return null;
        }
    }

    private static String canonicalFieldApiName(String objectApiName, String requestedFieldName) {
        if (String.isBlank(objectApiName) || String.isBlank(requestedFieldName)) {
            return requestedFieldName;
        }
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        String canonicalObjectName = canonicalObjectApiName(objectApiName);
        if (String.isBlank(canonicalObjectName) || !globalDescribe.containsKey(canonicalObjectName)) {
            return requestedFieldName;
        }

        Map<String, Schema.SObjectField> fieldsMap = globalDescribe.get(canonicalObjectName).getDescribe().fields.getMap();
        if (!fieldsMap.containsKey(requestedFieldName)) {
            for (String fieldApiName : fieldsMap.keySet()) {
                if (fieldApiName != null && fieldApiName.toLowerCase() == requestedFieldName.toLowerCase()) {
                    return fieldsMap.get(fieldApiName).getDescribe().getName();
                }
            }
            return requestedFieldName;
        }

        return fieldsMap.get(requestedFieldName).getDescribe().getName();
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

    private static String firstNonBlank(String firstValue, String secondValue, String thirdValue, String fallbackValue) {
        List<String> candidates = new List<String>{ firstValue, secondValue, thirdValue, fallbackValue };
        for (String candidate : candidates) {
            if (String.isNotBlank(candidate)) {
                return candidate;
            }
        }
        return fallbackValue;
    }

    private static String firstNonBlank(String firstValue, String fallbackValue) {
        return String.isNotBlank(firstValue) ? firstValue : fallbackValue;
    }

    private static String firstNonBlank(String firstValue, String secondValue, String fallbackValue) {
        List<String> candidates = new List<String>{ firstValue, secondValue, fallbackValue };
        for (String candidate : candidates) {
            if (String.isNotBlank(candidate)) {
                return candidate;
            }
        }
        return fallbackValue;
    }

    private static String cssColor(Map<String, Object> source, String key, String fallbackValue) {
        String value = stringValue(source.get(key));
        return String.isNotBlank(value) ? escapeHtml(value) : fallbackValue;
    }

    private static String cssLength(Map<String, Object> source, String key, String fallbackValue) {
        String value = stringValue(source.get(key));
        return String.isNotBlank(value) ? escapeHtml(value) : fallbackValue;
    }

    private static String cssFontFamily(Map<String, Object> source, String key, String fallbackValue) {
        String value = stringValue(source.get(key));
        return String.isNotBlank(value) ? escapeHtml(value) : fallbackValue;
    }

    private static String formatException(Exception e) {
        if (e == null) {
            return 'Unknown publish error';
        }

        String message = e.getTypeName() + ': ' + e.getMessage();
        String stackTrace = e.getStackTraceString();
        if (String.isBlank(stackTrace)) {
            return message;
        }

        List<String> lines = stackTrace.split('\n');
        if (lines.isEmpty()) {
            return message;
        }

        return message + ' @ ' + lines[0].trim();
    }
}
