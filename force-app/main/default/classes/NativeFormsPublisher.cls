public with sharing class NativeFormsPublisher {
    private static final String TEMP_PREFILL_URL = 'https://a2guxusajjhwzakf3tg6ispb640pgsno.lambda-url.eu-north-1.on.aws/';
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
                   Form__r.Theme__c,
                   Form__r.Theme__r.Id,
                   Form__r.Theme__r.Name,
                   Form__r.Theme__r.Logo_URL__c,
                   Form__r.Theme__r.Logo_Content_Document_Id__c,
                   Form__r.Theme__r.Logo_Size_Px__c,
                   Form__r.Theme__r.Logo_Position__c,
                   Form__r.Theme__r.Form_Width__c,
                   Form__r.Theme__r.Background_Color__c,
                   Form__r.Theme__r.Form_Background_Color__c,
                   Form__r.Theme__r.Form_Border_Color__c,
                   Form__r.Theme__r.Title_Font__c,
                   Form__r.Theme__r.Title_Font_Size_Px__c,
                   Form__r.Theme__r.Title_Text_Color__c,
                   Form__r.Theme__r.Section_Title_Font__c,
                   Form__r.Theme__r.Section_Title_Font_Size_Px__c,
                   Form__r.Theme__r.Section_Title_Text_Color__c,
                   Form__r.Theme__r.Main_Font__c,
                   Form__r.Theme__r.Main_Text_Size_Px__c,
                   Form__r.Theme__r.Main_Text_Color__c,
                   Form__r.Theme__r.Link_Text_Color__c,
                   Form__r.Theme__r.Hint_Text_Color__c,
                   Form__r.Theme__r.Error_Color__c,
                   Form__r.Theme__r.Input_Border_Radius_Px__c,
                   Form__r.Theme__r.Input_Background_Color__c,
                   Form__r.Theme__r.Input_Border_Color__c,
                   Form__r.Theme__r.Button_Font__c,
                   Form__r.Theme__r.Button_Font_Size_Px__c,
                   Form__r.Theme__r.Button_Text_Color__c,
                   Form__r.Theme__r.Button_Background_Color__c,
                   Form__r.Theme__r.Button_Hover_Background_Color__c,
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
        String fileName = 'index.html';

        try {
            NativeFormsAwsClient.PresignRequest presignRequest = new NativeFormsAwsClient.PresignRequest();
            presignRequest.orgId = orgId;
            presignRequest.formId = formId;
            presignRequest.versionId = 'current';
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
                'securityMode' => determineSecurityMode(versionRecord.Security_Mode__c, actions, publishElements),
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

    private static Map<String, NF_Form_Element__c> elementsByElementId(List<NF_Form_Element__c> elements) {
        Map<String, NF_Form_Element__c> recordsByElementId = new Map<String, NF_Form_Element__c>();
        if (elements == null) {
            return recordsByElementId;
        }
        for (NF_Form_Element__c elementRecord : elements) {
            if (elementRecord != null && String.isNotBlank(elementRecord.Element_Id__c)) {
                recordsByElementId.put(elementRecord.Element_Id__c, elementRecord);
            }
        }
        return recordsByElementId;
    }

    private static NF_Form_Element__c repeatGroupParentForElement(
        NF_Form_Element__c elementRecord,
        Map<String, NF_Form_Element__c> recordsByElementId
    ) {
        if (elementRecord == null || String.isBlank(elementRecord.Parent_Element_Id__c) || recordsByElementId == null) {
            return null;
        }
        NF_Form_Element__c parentRecord = recordsByElementId.get(elementRecord.Parent_Element_Id__c);
        while (parentRecord != null) {
            if (parentRecord.Element_Type__c == 'repeatGroup') {
                return parentRecord;
            }
            if (String.isBlank(parentRecord.Parent_Element_Id__c)) {
                return null;
            }
            parentRecord = recordsByElementId.get(parentRecord.Parent_Element_Id__c);
        }
        return null;
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

        Map<String, NF_Form_Element__c> containersByElementId = new Map<String, NF_Form_Element__c>();
        Set<String> imageVersionIds = new Set<String>();
        for (NF_Form_Element__c elementRecord : elements) {
            if (elementRecord == null) {
                continue;
            }
            if ((elementRecord.Element_Type__c == 'section' || elementRecord.Element_Type__c == 'group' || elementRecord.Element_Type__c == 'repeatGroup') && String.isNotBlank(elementRecord.Element_Id__c)) {
                containersByElementId.put(elementRecord.Element_Id__c, elementRecord);
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
                containersByElementId.containsKey(sourceRecord.Parent_Element_Id__c);

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

    private static String buildPublishedThemeLogoUrl(NF_Form_Version__c versionRecord) {
        if (versionRecord == null || versionRecord.Form__r == null || versionRecord.Form__r.Theme__r == null) {
            return null;
        }

        String contentDocumentId = versionRecord.Form__r.Theme__r.Logo_Content_Document_Id__c;
        if (String.isBlank(contentDocumentId)) {
            return versionRecord.Form__r.Theme__r.Logo_URL__c;
        }

        List<ContentVersion> versions = [
            SELECT Id, PathOnClient, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            ORDER BY VersionNumber DESC
            LIMIT 1
        ];
        if (versions.isEmpty()) {
            return versionRecord.Form__r.Theme__r.Logo_URL__c;
        }

        ContentVersion versionData = versions[0];
        String mimeType = mimeTypeFromFileName(versionData.PathOnClient);
        if (String.isBlank(mimeType) || versionData.VersionData == null) {
            return versionRecord.Form__r.Theme__r.Logo_URL__c;
        }

        return 'data:' + mimeType + ';base64,' + EncodingUtil.base64Encode(versionData.VersionData);
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
                if (String.isBlank(canonicalObject)) {
                    continue;
                }
                commandConfig.put('objectApiName', canonicalObject);
                if (normalizedType == 'findMany') {
                    Integer limitValue = integerValue(commandConfig.get('limit'));
                    if (limitValue == null || limitValue < 1) {
                        commandConfig.put('limit', 25);
                    }
                }
                if (String.isNotBlank(actionRecord.Store_Result_As__c)) {
                    commandConfig.put('storeResultAs', actionRecord.Store_Result_As__c);
                }
                String whereClause = buildConditionWhereClause(commandConfig, canonicalObject);
                if (String.isNotBlank(whereClause)) {
                    commandConfig.put('whereClause', whereClause);
                }
                List<String> fieldsToReturn = mergePrefillResponseMappings(response, actionRecord, canonicalObject, elements);
                if (!fieldsToReturn.isEmpty()) {
                    commandConfig.put('fieldsToReturn', fieldsToReturn);
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

    private static List<String> mergePrefillResponseMappings(
        Map<String, Object> response,
        NF_Form_Action__c actionRecord,
        String canonicalObjectApiName,
        List<NF_Form_Element__c> elements
    ) {
        Set<String> collectedFields = new Set<String>{ 'Id' };
        if (response == null || actionRecord == null || elements == null || elements.isEmpty()) {
            return new List<String>(collectedFields);
        }
        String aliasValue = actionRecord.Store_Result_As__c;
        if (String.isBlank(aliasValue)) {
            return new List<String>(collectedFields);
        }

        Map<String, NF_Form_Element__c> recordsByElementId = elementsByElementId(elements);

        for (NF_Form_Element__c elementRecord : elements) {
            if (elementRecord == null || elementRecord.Element_Type__c != 'repeatGroup' || String.isBlank(elementRecord.Field_Key__c)) {
                continue;
            }
            Map<String, Object> groupConfig = parseJsonMap(elementRecord.Config_JSON__c);
            if (stringValue(groupConfig.get('repeatSourceAlias')) == aliasValue) {
                response.put('repeatGroups.' + elementRecord.Field_Key__c + '.rows', '{' + aliasValue + '}');
            }
        }

        for (NF_Form_Element__c elementRecord : elements) {
            if (elementRecord == null || String.isBlank(elementRecord.Field_Key__c) || String.isBlank(elementRecord.Config_JSON__c)) {
                continue;
            }

            Map<String, Object> elementConfig = parseJsonMap(elementRecord.Config_JSON__c);
            if (!booleanValue(elementConfig.get('prefillEnabled'))) {
                continue;
            }

            String prefillAlias = stringValue(elementConfig.get('prefillAlias'));
            String prefillFieldPath = stringValue(elementConfig.get('prefillFieldPath'));
            if (String.isBlank(prefillAlias) || String.isBlank(prefillFieldPath) || prefillAlias != aliasValue) {
                continue;
            }

            String sourcePath = canonicalFieldApiName(canonicalObjectApiName, prefillFieldPath);
            if (String.isBlank(sourcePath)) {
                continue;
            }

            NF_Form_Element__c repeatGroupParent = repeatGroupParentForElement(elementRecord, recordsByElementId);
            if (repeatGroupParent != null) {
                Map<String, Object> repeatConfig = parseJsonMap(repeatGroupParent.Config_JSON__c);
                if (stringValue(repeatConfig.get('repeatSourceAlias')) == aliasValue) {
                    collectedFields.add(sourcePath);
                    continue;
                }
            }

            String fieldBehavior = stringValue(elementConfig.get('fieldBehavior'));
            String targetGroup = fieldBehavior == 'hidden' || elementRecord.Element_Type__c == 'hidden'
                ? 'hidden'
                : 'input';

            response.put(
                targetGroup + '.' + elementRecord.Field_Key__c,
                '{' + aliasValue + '.' + sourcePath + '}'
            );
            collectedFields.add(sourcePath);
        }

        return new List<String>(collectedFields);
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

        if (commandType == 'upsertMany') {
            Map<String, Object> upsertManyCommand = buildUpsertManyCommand(actionRecord, commandConfig, canonicalObject, elements);
            if (!upsertManyCommand.isEmpty()) {
                commands.add(upsertManyCommand);
            }
            return commands;
        }

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

    private static Map<String, Object> buildUpsertManyCommand(
        NF_Form_Action__c actionRecord,
        Map<String, Object> commandConfig,
        String canonicalObjectApiName,
        List<NF_Form_Element__c> elements
    ) {
        Map<String, Object> command = new Map<String, Object>();
        if (actionRecord == null || String.isBlank(canonicalObjectApiName) || elements == null || elements.isEmpty()) {
            return command;
        }

        String repeatGroupKey = stringValue(commandConfig.get('repeatGroupKey'));
        if (String.isBlank(repeatGroupKey)) {
            return command;
        }

        command.put('type', 'upsertMany');
        command.put('commandKey', actionRecord.Command_Key__c);
        command.put('objectApiName', canonicalObjectApiName);
        if (String.isNotBlank(actionRecord.Store_Result_As__c)) {
            command.put('storeResultAs', actionRecord.Store_Result_As__c);
        }
        command.put('rows', '{input.repeatGroups.' + repeatGroupKey + '.rows}');
        command.put('deleteIds', '{input.repeatGroups.' + repeatGroupKey + '.deletedIds}');
        command.put('allowDelete', booleanValue(commandConfig.get('allowDelete')));

        String relationshipField = canonicalFieldApiName(canonicalObjectApiName, stringValue(commandConfig.get('relationshipField')));
        String relationshipValue = buildConditionValueExpression(
            stringValue(commandConfig.get('relationshipValueSource')),
            stringValue(commandConfig.get('relationshipValueText'))
        );
        if (String.isNotBlank(relationshipField) && String.isNotBlank(relationshipValue)) {
            command.put('relationshipField', relationshipField);
            command.put('relationshipValue', relationshipValue);
        }

        applySubmitFieldMappings(command, actionRecord, canonicalObjectApiName, elements);
        if (!command.containsKey('fields')) {
            applyUpsertManyFallbackFieldMappings(command, actionRecord, canonicalObjectApiName, elements);
        }
        if (!command.containsKey('fields')) {
            return new Map<String, Object>();
        }
        return command;
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
        String normalizedType = stringValue(commandConfig.get('type'));
        Map<String, NF_Form_Element__c> recordsByElementId = elementsByElementId(elements);
        String repeatGroupKey = stringValue(commandConfig.get('repeatGroupKey'));
        String idFieldKey;

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

            if (normalizedType == 'upsertMany') {
                NF_Form_Element__c repeatGroupParent = repeatGroupParentForElement(elementRecord, recordsByElementId);
                if (repeatGroupParent == null || repeatGroupParent.Field_Key__c != repeatGroupKey) {
                    continue;
                }
                if (submitFieldPath == 'Id') {
                    idFieldKey = elementRecord.Field_Key__c;
                    continue;
                }
            }

            String inputExpression = normalizedType == 'upsertMany'
                ? '{row.' + elementRecord.Field_Key__c + '}'
                : '{input.' + elementRecord.Field_Key__c + '}';
            if (String.isBlank(submitFieldPath) || String.isBlank(inputExpression)) {
                continue;
            }

            fields.put(String.valueOf(submitFieldPath), inputExpression);
        }

        if (!fields.isEmpty()) {
            commandConfig.put('fields', fields);
        }

        if (normalizedType == 'update') {
            String recordIdSource = stringValue(commandConfig.get('recordIdSource'));
            if (String.isNotBlank(recordIdSource)) {
                commandConfig.put('id', recordIdSource);
            }
        }
        if (normalizedType == 'upsertMany' && String.isNotBlank(idFieldKey)) {
            commandConfig.put('idField', idFieldKey);
        }
    }

    private static void applyUpsertManyFallbackFieldMappings(
        Map<String, Object> commandConfig,
        NF_Form_Action__c actionRecord,
        String canonicalObjectApiName,
        List<NF_Form_Element__c> elements
    ) {
        if (commandConfig == null || actionRecord == null || String.isBlank(canonicalObjectApiName) || elements == null || elements.isEmpty()) {
            return;
        }

        String actionKey = actionRecord.Command_Key__c;
        if (String.isBlank(actionKey)) {
            return;
        }

        Map<String, Object> fields = new Map<String, Object>();
        String idFieldKey;

        for (NF_Form_Element__c elementRecord : elements) {
            if (elementRecord == null || String.isBlank(elementRecord.Field_Key__c) || String.isBlank(elementRecord.Config_JSON__c)) {
                continue;
            }
            Map<String, Object> elementConfig = parseJsonMap(elementRecord.Config_JSON__c);
            if (!booleanValue(elementConfig.get('submitEnabled'))) {
                continue;
            }
            if (stringValue(elementConfig.get('submitActionKey')) != actionKey) {
                continue;
            }

            String submitFieldPath = canonicalFieldApiName(canonicalObjectApiName, stringValue(elementConfig.get('submitFieldPath')));
            if (String.isBlank(submitFieldPath)) {
                continue;
            }
            if (submitFieldPath == 'Id') {
                idFieldKey = elementRecord.Field_Key__c;
                continue;
            }
            fields.put(submitFieldPath, '{row.' + elementRecord.Field_Key__c + '}');
        }

        if (!fields.isEmpty()) {
            commandConfig.put('fields', fields);
        }
        if (String.isNotBlank(idFieldKey)) {
            commandConfig.put('idField', idFieldKey);
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
        if (commandType == 'upsertMany') {
            return new List<String>{ 'upsertMany' };
        }
        if (commandType == 'updateById' && stringValue(config.get('onNotFound')) == 'create') {
            return new List<String>{ normalized, 'create' };
        }
        return new List<String>{ normalized };
    }

    private static String determineSecurityMode(String explicitSecurityMode, List<NF_Form_Action__c> actions, List<NF_Form_Element__c> elements) {
        List<NF_Form_Action__c> referencedSubmitActions = filterReferencedActions(actions, 'Submit', elements);
        Boolean needsFindUpdateCreate = false;
        Boolean needsSecureEdit = false;

        for (NF_Form_Action__c actionRecord : referencedSubmitActions) {
            Map<String, Object> config = parseJsonMap(actionRecord.Config_JSON__c);
            String commandType = actionRecord.Command_Type__c;
            String onNotFound = stringValue(config.get('onNotFound'));

            if (commandType == 'findAndUpdate' && onNotFound == 'create') {
                needsFindUpdateCreate = true;
                continue;
            }
            if (commandType == 'findAndUpdate' || commandType == 'updateById' || commandType == 'upsertMany') {
                needsSecureEdit = true;
            }
        }

        if (needsFindUpdateCreate) {
            if (String.isBlank(explicitSecurityMode) || explicitSecurityMode == 'public-create' || explicitSecurityMode == 'public-find-update-create') {
                return 'public-find-update-create';
            }
            return explicitSecurityMode;
        }
        if (needsSecureEdit) {
            if (String.isBlank(explicitSecurityMode) || explicitSecurityMode == 'public-create' || explicitSecurityMode == 'secure-edit') {
                return 'secure-edit';
            }
            return explicitSecurityMode;
        }

        if (String.isNotBlank(explicitSecurityMode)) {
            return explicitSecurityMode;
        }

        if (needsFindUpdateCreate) {
            return 'public-find-update-create';
        }
        return 'public-create';
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
                String valueSource = stringValue(condition.get('valueSource'));
                String valueText = stringValue(condition.get('valueText'));
                String paramName = stringValue(condition.get('paramName'));
                if (String.isBlank(valueText) && String.isNotBlank(paramName)) {
                    valueSource = 'param';
                    valueText = paramName;
                }
                String clause = buildConditionClause(fieldApiName, operator, valueSource, valueText);
                if (String.isNotBlank(clause)) {
                    clauses.add(clause);
                }
            }
        }

        if (!clauses.isEmpty()) {
            String logic = normalizeConditionLogicExpression(stringValue(config.get('conditionLogic')), clauses.size());
            if (String.isBlank(logic)) {
                return String.join(clauses, ' AND ');
            }
            for (Integer i = 0; i < clauses.size(); i++) {
                logic = logic.replaceAll('\\b' + String.valueOf(i + 1) + '\\b', '(' + clauses[i] + ')');
            }
            return logic;
        }

        return normalizeLegacyWhereClause(stringValue(config.get('where')));
    }

    private static String buildConditionClause(String fieldApiName, String operator, String valueSource, String valueText) {
        if (String.isBlank(fieldApiName) || String.isBlank(operator)) {
            return null;
        }

        String expression = buildConditionValueExpression(valueSource, valueText);
        if (operator == 'isBlank') {
            return '(' + fieldApiName + ' = null OR ' + fieldApiName + ' = \'\')';
        }
        if (operator == 'isNotBlank') {
            return '(' + fieldApiName + ' != null AND ' + fieldApiName + ' != \'\')';
        }
        if (String.isBlank(expression)) {
            return null;
        }
        String soqlValue = formatConditionValueForSoql(expression, operator);
        if (operator == 'eq') {
            return fieldApiName + ' = ' + soqlValue;
        }
        if (operator == 'neq') {
            return fieldApiName + ' != ' + soqlValue;
        }
        if (operator == 'contains') {
            return fieldApiName + ' LIKE ' + formatConditionLikeValue(expression, true, true);
        }
        if (operator == 'startsWith') {
            return fieldApiName + ' LIKE ' + formatConditionLikeValue(expression, false, true);
        }
        if (operator == 'gt') {
            return fieldApiName + ' > ' + soqlValue;
        }
        if (operator == 'lt') {
            return fieldApiName + ' < ' + soqlValue;
        }
        return null;
    }

    private static String buildConditionValueExpression(String valueSource, String valueText) {
        if (String.isBlank(valueText)) {
            return null;
        }
        if (String.isBlank(valueSource) || valueSource == 'param') {
            String paramName = valueText.trim();
            if (paramName.startsWith('{params.') && paramName.endsWith('}')) {
                paramName = paramName.substring(8, paramName.length() - 1);
            } else if (paramName.toLowerCase().startsWith('params.')) {
                paramName = paramName.substring(7);
            }
            return String.isBlank(paramName) ? null : '{params.' + paramName + '}';
        }
        if (valueSource == 'field') {
            String fieldKey = valueText.trim();
            if (fieldKey.startsWith('{input.') && fieldKey.endsWith('}')) {
                fieldKey = fieldKey.substring(7, fieldKey.length() - 1);
            } else if (fieldKey.toLowerCase().startsWith('input.')) {
                fieldKey = fieldKey.substring(6);
            }
            return String.isBlank(fieldKey) ? null : '{input.' + fieldKey + '}';
        }
        if (valueSource == 'alias') {
            String aliasPath = valueText.trim();
            if (aliasPath.startsWith('{') && aliasPath.endsWith('}')) {
                aliasPath = aliasPath.substring(1, aliasPath.length() - 1);
            }
            return String.isBlank(aliasPath) ? null : '{' + aliasPath + '}';
        }
        if (Pattern.matches('^-?\\d+(\\.\\d+)?$', valueText) || valueText == 'true' || valueText == 'false') {
            return valueText;
        }
        return valueText.replace('\'', '\\\'');
    }

    private static String formatConditionValueForSoql(String expression, String operator) {
        if (String.isBlank(expression)) {
            return 'null';
        }
        if (expression.startsWith('{') && expression.endsWith('}')) {
            return '\'' + expression + '\'';
        }
        if (Pattern.matches('^-?\\d+(\\.\\d+)?$', expression) || expression == 'true' || expression == 'false') {
            return expression;
        }
        return '\'' + expression + '\'';
    }

    private static String formatConditionLikeValue(String expression, Boolean prefixWildcard, Boolean suffixWildcard) {
        String resolvedExpression = expression;
        if (expression.startsWith('{') && expression.endsWith('}')) {
            resolvedExpression = expression;
        }
        String value = '';
        if (prefixWildcard) {
            value += '%';
        }
        value += resolvedExpression;
        if (suffixWildcard) {
            value += '%';
        }
        return '\'' + value + '\'';
    }

    private static String normalizeLegacyWhereClause(String rawWhereClause) {
        if (String.isBlank(rawWhereClause)) {
            return null;
        }

        String normalized = rawWhereClause;
        normalized = normalized.replace('{param.', '{params.');
        normalized = normalized.replaceAll('"\\s*(input\\.[A-Za-z0-9_\\.]+)\\s*"', '{$1}');
        normalized = normalized.replaceAll('\'\\s*(input\\.[A-Za-z0-9_\\.]+)\\s*\'', '{$1}');
        normalized = normalized.replaceAll('"\\s*(params\\.[A-Za-z0-9_\\.]+)\\s*"', '{$1}');
        normalized = normalized.replaceAll('\'\\s*(params\\.[A-Za-z0-9_\\.]+)\\s*\'', '{$1}');
        return normalized;
    }

    private static String normalizeConditionLogicExpression(String rawLogic, Integer clauseCount) {
        if (clauseCount == null || clauseCount <= 0) {
            return null;
        }
        if (clauseCount == 1) {
            return '1';
        }
        if (String.isBlank(rawLogic)) {
            return null;
        }

        String logic = rawLogic.trim().toUpperCase();
        if (!Pattern.matches('^[0-9()\\sANDOR]+$', logic)) {
            return null;
        }
        if (!Pattern.matches('.*\\d+.*', logic)) {
            return null;
        }

        for (Integer i = 1; i <= clauseCount; i++) {
            logic = logic.replaceAll('\\b' + String.valueOf(i) + '\\b', '@' + String.valueOf(i) + '@');
        }

        if (Pattern.matches('.*\\b\\d+\\b.*', logic)) {
            return null;
        }

        return logic.replace('@', '');
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

        for (NF_Form_Action__c actionRecord : [
            SELECT Config_JSON__c
            FROM NF_Form_Action__c
            WHERE Command_Key__c = :actionKey
            LIMIT 1
        ]) {
            Map<String, Object> actionConfig = parseJsonMap(actionRecord.Config_JSON__c);
            String relationshipField = canonicalFieldApiName(objectApiName, stringValue(actionConfig.get('relationshipField')));
            if (String.isNotBlank(relationshipField)) {
                fieldNames.add(relationshipField);
            }
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
        Map<String, Object> theme = buildPublishedTheme(versionRecord);
        Map<String, Object> uiSettings = parseJsonMap(versionRecord.UI_Settings_JSON__c);
        String themeLogoUrl = buildPublishedThemeLogoUrl(versionRecord);
        String titleText = firstNonBlank(
            stringValue(uiSettings.get('title')),
            stringValue(uiSettings.get('formTitle'))
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
        html += '--nf-bg:' + cssColor(theme, 'backgroundColor', '#f4f7fb') + ';';
        html += '--nf-surface:' + cssColor(theme, 'formBackgroundColor', '#ffffff') + ';';
        html += '--nf-text:' + cssColor(theme, 'mainTextColor', '#16325c') + ';';
        html += '--nf-border:' + cssColor(theme, 'formBorderColor', '#d8dde6') + ';';
        html += '--nf-muted:' + cssColor(theme, 'hintTextColor', '#5f6f89') + ';';
        html += '--nf-accent:' + cssColor(theme, 'buttonBackgroundColor', '#0f6cbd') + ';';
        html += '--nf-accent-contrast:' + cssColor(theme, 'buttonTextColor', '#ffffff') + ';';
        html += '--nf-radius:' + cssLength(theme, 'inputBorderRadiusPx', '16px') + ';';
        html += '--nf-field-radius:' + cssLength(theme, 'inputBorderRadiusPx', '10px') + ';';
        html += '--nf-form-bg:' + cssColor(theme, 'formBackgroundColor', '#ffffff') + ';';
        html += '--nf-font:' + cssFontFamily(theme, 'mainFont', '\'Segoe UI\', Arial, sans-serif') + ';';
        html += '--nf-title-font:' + cssFontFamily(theme, 'titleFont', '\'Segoe UI\', Arial, sans-serif') + ';';
        html += '--nf-title-size:' + cssLength(theme, 'titleFontSizePx', '22px') + ';';
        html += '--nf-title-color:' + cssColor(theme, 'titleTextColor', '#16325c') + ';';
        html += '--nf-section-font:' + cssFontFamily(theme, 'sectionTitleFont', '\'Segoe UI\', Arial, sans-serif') + ';';
        html += '--nf-section-size:' + cssLength(theme, 'sectionTitleFontSizePx', '16px') + ';';
        html += '--nf-section-color:' + cssColor(theme, 'sectionTitleTextColor', '#16325c') + ';';
        html += '--nf-input-bg:' + cssColor(theme, 'inputBackgroundColor', '#ffffff') + ';';
        html += '--nf-input-border:' + cssColor(theme, 'inputBorderColor', '#c9d3df') + ';';
        html += '--nf-form-width:' + cssFormWidth(theme, 'formWidth', '880px') + ';';
        html += '}';
        html += 'body{font-family:var(--nf-font);background:linear-gradient(180deg,var(--nf-bg) 0%, #8fb5de 38%, #dce9f7 72%, #f8fbff 100%);color:var(--nf-text);margin:0;padding:28px 24px;min-height:100vh;box-sizing:border-box;}';
        html += '.nf-shell{max-width:var(--nf-form-width);min-height:calc(100vh - 56px);margin:0 auto;background:var(--nf-surface);border:1px solid var(--nf-border);border-radius:calc(var(--nf-radius) + 6px);padding:32px;box-shadow:0 16px 44px rgba(22,50,92,.08);box-sizing:border-box;}';
        html += '.nf-grid{display:grid;gap:16px;}';
        html += '.nf-section{position:relative;padding:1.5rem 1.25rem 1.25rem;border:1px solid var(--nf-input-border);border-radius:calc(var(--nf-radius) + 2px);background:var(--nf-form-bg);margin-top:0.95rem;box-shadow:0 8px 24px rgba(15,35,65,.04);}';
        html += '.nf-section--plain{padding:0;border:0;background:transparent;border-radius:0;margin-top:0;}';
        html += '.nf-section__top{position:absolute;top:0;left:1.1rem;transform:translateY(-50%);background:var(--nf-form-bg,#ffffff);padding:0 0.4rem;line-height:1;}';
        html += '.nf-section__top h2{margin:0;font-size:var(--nf-section-size);font-family:var(--nf-section-font);color:var(--nf-section-color);line-height:1;white-space:nowrap;}';
        html += '.nf-section__grid{display:grid;gap:16px;}';
        html += '.nf-section__grid--1{grid-template-columns:1fr;}';
        html += '.nf-section__grid--2{grid-template-columns:repeat(2,minmax(0,1fr));}';
        html += '.nf-section__grid--3{grid-template-columns:repeat(3,minmax(0,1fr));}';
        html += '.nf-section__grid--4{grid-template-columns:repeat(4,minmax(0,1fr));}';
        html += '.nf-section__column{display:grid;gap:14px;align-content:start;}';
        html += '.nf-repeat{display:grid;gap:16px;}';
        html += '.nf-repeat__meta{display:flex;justify-content:flex-end;gap:8px;flex-wrap:wrap;color:var(--nf-muted);font-size:12px;}';
        html += '.nf-repeat__meta span{padding:4px 10px;border-radius:999px;background:rgba(15,108,189,.08);}';
        html += '.nf-repeat__rows{display:grid;gap:0;overflow:hidden;border-radius:calc(var(--nf-radius) - 4px);}';
        html += '.nf-repeat__row{padding:12px 14px;border:none;border-radius:0;background:var(--nf-input-bg);display:flex;gap:12px;align-items:flex-start;}';
        html += '.nf-repeat__row:nth-child(even){background:#eef3f8;}';
        html += '.nf-repeat__row .nf-field input,.nf-repeat__row .nf-field textarea,.nf-repeat__row .nf-field select{background:var(--nf-input-bg);padding:12px 14px;}';
        html += '.nf-repeat__row-delete{flex:0 0 32px;width:32px;display:flex;align-items:center;}';
        html += '.nf-repeat__row-delete button{border:1px solid #d5e6f8;background:#fff;color:#9aa8ba;border-radius:10px;padding:4px 7px;font-size:11px;line-height:1;cursor:pointer;white-space:nowrap;}';
        html += '.nf-repeat__row-delete button:hover{border-color:#f5c2c7;color:#b42318;background:#fde7e9;}';
        html += '.nf-repeat__row-body{flex:1 1 auto;min-width:0;display:grid;gap:14px;}';
        html += '.nf-repeat__header-row{display:flex;gap:12px;align-items:flex-end;padding:10px 12px 10px;margin-bottom:0;background:#e7edf5;border-radius:calc(var(--nf-radius) - 6px) calc(var(--nf-radius) - 6px) 0 0;font-weight:700;color:#355070;}';
        html += '.nf-repeat__header-spacer{flex:0 0 auto;width:32px;}';
        html += '.nf-repeat__header-body{flex:1 1 auto;min-width:0;}';
        html += '.nf-repeat__actions button{border:1px solid var(--nf-border);background:#fff;color:var(--nf-text);border-radius:999px;padding:8px 14px;font:inherit;cursor:pointer;}';
        html += '.nf-repeat__actions{display:flex;justify-content:flex-start;}';
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
        html += '.nf-field{display:grid;gap:8px;align-items:start;}';
        html += '.nf-field label{display:block;font-weight:400;color:var(--nf-text);}';
        html += '.nf-field label.nf-label--bold{font-weight:700;}';
        html += '.nf-field--above{grid-template-columns:minmax(0,1fr);}';
        html += '.nf-field--left{grid-template-columns:140px minmax(0,1fr);column-gap:12px;}';
        html += '.nf-field--left label{padding-top:12px;word-break:break-word;}';
        html += '.nf-field--right{grid-template-columns:minmax(0,1fr) auto;column-gap:12px;align-items:center;}';
        html += '.nf-field--right label{word-break:break-word;text-align:left;}';
        html += '.nf-field--hidden label{display:none;}';
        html += '.nf-field input,.nf-field textarea,.nf-field select{width:100%;padding:12px 14px;border:1px solid var(--nf-input-border);border-radius:var(--nf-field-radius);font:inherit;box-sizing:border-box;background:var(--nf-input-bg);color:var(--nf-text);box-shadow:none;}';
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
        html += '.nf-logo-wrap{display:flex;margin-bottom:20px;}';
        html += '.nf-logo-wrap--left{justify-content:flex-start;}';
        html += '.nf-logo-wrap--center{justify-content:center;}';
        html += '.nf-logo-wrap--right{justify-content:flex-end;}';
        html += '.nf-logo{display:block;max-width:100%;}';
        html += '.nf-title{margin:0;color:var(--nf-title-color);font-family:var(--nf-title-font);font-size:var(--nf-title-size);}';
        html += '.nf-intro{margin:8px 0 0;color:var(--nf-muted);}';
        html += '@media (max-width: 768px){';
        html += 'body{padding:16px;background:linear-gradient(180deg,var(--nf-bg) 0%, #97bbdf 38%, #dce9f7 72%, #f8fbff 100%);}';
        html += '.nf-shell{min-height:0;padding:18px 16px 20px;border-radius:20px;}';
        html += '.nf-section{padding:1.2rem 0.95rem 1rem;border-radius:18px;}';
        html += '.nf-section__top{left:0.85rem;padding:0 0.35rem;}';
        html += '.nf-section__top h2{font-size:calc(var(--nf-section-size) * 0.95);}';
        html += '.nf-section__grid--2,.nf-section__grid--3,.nf-section__grid--4{grid-template-columns:1fr;}';
        html += '.nf-field--left,.nf-field--right{grid-template-columns:1fr;row-gap:8px;}';
        html += '.nf-field--left label,.nf-field--right label{padding-top:0;text-align:left;}';
        html += '.nf-repeat__header-row{display:none;}';
        html += '.nf-repeat__rows{gap:8px;overflow:visible;border-radius:0;}';
        html += '.nf-repeat__row{display:block;padding:12px;border:1px solid var(--nf-input-border);border-radius:16px;background:var(--nf-input-bg);}';
        html += '.nf-repeat__row:nth-child(even){background:#eef3f8;}';
        html += '.nf-repeat__row-delete{width:auto;display:flex;justify-content:flex-end;align-items:center;margin-top:10px;}';
        html += '.nf-repeat__row-body{display:grid;gap:12px;}';
        html += '.nf-repeat__row-body .nf-section__grid{grid-template-columns:1fr;}';
        html += '.nf-repeat__row .nf-field{gap:6px;}';
        html += '.nf-repeat__row .nf-field label{display:block;}';
        html += '.nf-repeat__row .nf-field--hidden{grid-template-columns:1fr;}';
        html += '.nf-repeat__row .nf-field--hidden label{display:block;}';
        html += '.nf-repeat__actions,.nf-actions{display:grid;justify-content:stretch;}';
        html += '.nf-repeat__actions button,.nf-actions button{width:100%;}';
        html += '.nf-logo{max-height:4rem !important;}';
        html += '}';
        if (String.isNotBlank(versionRecord.Custom_CSS__c)) {
            html += versionRecord.Custom_CSS__c;
        }
        html += '</style></head><body>';
        html += '<div class="nf-shell">';
        html += '<form class="nf-grid" data-nativeforms-version="' + escapeHtml(String.valueOf(versionRecord.Id)) + '">';
        html += '<input class="nf-meta" type="hidden" name="nativeformsVersionId" value="' + escapeHtml(String.valueOf(versionRecord.Id)) + '">';
        if (String.isNotBlank(themeLogoUrl)) {
            String logoPosition = firstNonBlank(stringValue(theme.get('logoPosition')), 'left').toLowerCase();
            String logoSize = cssLength(theme, 'logoSizePx', '120px');
            html += '<div class="nf-logo-wrap nf-logo-wrap--' + escapeHtml(logoPosition) + '"><img class="nf-logo" src="' + escapeHtml(themeLogoUrl) + '" alt="Theme logo" style="max-height:' + escapeHtml(logoSize) + ';"></div>';
        }
        if (String.isNotBlank(titleText) || String.isNotBlank(introText)) {
            html += '<div class="nf-header">';
            if (String.isNotBlank(titleText)) {
                html += '<h1 class="nf-title">' + escapeHtml(titleText) + '</h1>';
            }
            if (String.isNotBlank(introText)) {
                html += '<p class="nf-intro">' + escapeHtml(introText) + '</p>';
            }
            html += '</div>';
        }

        Map<String, List<NF_Form_Element__c>> childrenByParent = new Map<String, List<NF_Form_Element__c>>();
        Set<String> containerElementIds = new Set<String>();
        for (NF_Form_Element__c elementRecord : elements) {
            if ((elementRecord.Element_Type__c == 'section' || elementRecord.Element_Type__c == 'group' || elementRecord.Element_Type__c == 'repeatGroup') && String.isNotBlank(elementRecord.Element_Id__c)) {
                containerElementIds.add(elementRecord.Element_Id__c);
            }
        }

        List<NF_Form_Element__c> topLevelElements = new List<NF_Form_Element__c>();
        for (NF_Form_Element__c elementRecord : elements) {
            Boolean isValidChild =
                String.isNotBlank(elementRecord.Parent_Element_Id__c) &&
                elementRecord.Parent_Element_Id__c != elementRecord.Element_Id__c &&
                containerElementIds.contains(elementRecord.Parent_Element_Id__c);
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
            'prefillUrl' => TEMP_PREFILL_URL,
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
        html += 'function setFieldValue(fieldKey,value){const fields=form.querySelectorAll("[name=\'"+fieldKey+"\']");if(!fields.length){return;}fields.forEach(function(el){if(el.type==="checkbox"){el.checked=!!value;}else if(el.type==="radio"){el.checked=String(el.value)===String(value);}else{el.value=value==null?"":value;}});}';
        html += 'const repeatDeleteState={};';
        html += 'function readRepeatFieldValueByKey(rowEl,fieldKey){const fields=rowEl.querySelectorAll("[data-repeat-field-key=\'"+fieldKey+"\']");if(!fields.length){return "";}const first=fields[0];if(first.type==="checkbox"){return !!first.checked;}if(first.type==="radio"){const checked=Array.from(fields).find(function(el){return el.checked;});return checked?checked.value:"";}return first.value||"";}';
        html += 'function setRepeatFieldValue(field,value){if(!field){return;}if(field.type==="checkbox"){field.checked=!!value;return;}if(field.type==="radio"){field.checked=String(field.value)===String(value==null?"":value);return;}field.value=value==null?"":value;}';
        html += 'function setupRepeatRow(groupKey,rowEl,rowData,rowIndex){rowEl.dataset.repeatRowIndex=String(rowIndex);rowEl.querySelectorAll("[data-repeat-field-key]").forEach(function(field){const fieldKey=field.dataset.repeatFieldKey;const sourceField=field.dataset.repeatSourceField||fieldKey;const value=rowData&&Object.prototype.hasOwnProperty.call(rowData,sourceField)?rowData[sourceField]:"";if(field.id){field.id=groupKey+"-"+rowIndex+"-"+field.id;}if(field.type==="radio"){field.name=groupKey+"-"+rowIndex+"-"+fieldKey;}else if(field.name){field.removeAttribute("name");}setRepeatFieldValue(field,value);});rowEl.querySelectorAll("label[for]").forEach(function(label,index){const target=rowEl.querySelectorAll("[data-repeat-field-key]")[index];if(target&&target.id){label.setAttribute("for",target.id);}});}';
        html += 'function renderRepeatGroup(groupKey,groupPayload){const rowsHost=form.querySelector("[data-repeat-rows=\'"+groupKey+"\']");const template=form.querySelector("template[data-repeat-template=\'"+groupKey+"\']");if(!rowsHost||!template){return;}repeatDeleteState[groupKey]=[];rowsHost.innerHTML="";const rows=(groupPayload&&Array.isArray(groupPayload.rows))?groupPayload.rows:[];rows.forEach(function(rowData,rowIndex){const fragment=template.content.cloneNode(true);const rowEl=fragment.querySelector("[data-repeat-row]");setupRepeatRow(groupKey,rowEl,rowData||{},rowIndex);rowsHost.appendChild(fragment);});}';
        html += 'function clearRepeatGroups(){form.querySelectorAll("[data-repeat-rows]").forEach(function(host){host.innerHTML="";});Object.keys(repeatDeleteState).forEach(function(key){repeatDeleteState[key]=[];});}';
        html += 'function addRepeatRow(groupKey){const rowsHost=form.querySelector("[data-repeat-rows=\'"+groupKey+"\']");const template=form.querySelector("template[data-repeat-template=\'"+groupKey+"\']");if(!rowsHost||!template){return;}const fragment=template.content.cloneNode(true);const rowEl=fragment.querySelector("[data-repeat-row]");setupRepeatRow(groupKey,rowEl,{},rowsHost.children.length);rowsHost.appendChild(fragment);}';
        html += 'function collectRepeatGroups(){const groups={};form.querySelectorAll("[data-repeat-group]").forEach(function(groupEl){const groupKey=groupEl.dataset.repeatGroup;const rows=[];groupEl.querySelectorAll("[data-repeat-row]").forEach(function(rowEl){const row={};const seen={};rowEl.querySelectorAll("[data-repeat-field-key]").forEach(function(field){const fieldKey=field.dataset.repeatFieldKey;if(seen[fieldKey]){return;}row[fieldKey]=readRepeatFieldValueByKey(rowEl,fieldKey);seen[fieldKey]=true;});rows.push(row);});groups[groupKey]={rows:rows,deletedIds:repeatDeleteState[groupKey]||[]};});return groups;}';
        html += 'form.addEventListener("click",function(event){const addButton=event.target.closest("[data-repeat-add]");if(addButton){event.preventDefault();addRepeatRow(addButton.dataset.repeatAdd);return;}const deleteButton=event.target.closest("[data-repeat-delete-row]");if(deleteButton){event.preventDefault();const rowEl=deleteButton.closest("[data-repeat-row]");const groupEl=deleteButton.closest("[data-repeat-group]");if(!rowEl||!groupEl){return;}const groupKey=groupEl.dataset.repeatGroup;const idFieldKey=groupEl.dataset.repeatIdField;const existingId=idFieldKey?readRepeatFieldValueByKey(rowEl,idFieldKey):"";if(existingId){repeatDeleteState[groupKey]=repeatDeleteState[groupKey]||[];repeatDeleteState[groupKey].push(existingId);}rowEl.remove();}});';
        html += 'function applyLockState(control){if(!control||control.dataset.lockOnPrefill!=="true"){return;}let hasValue=false;if(control.type==="checkbox"||control.type==="radio"){hasValue=!!control.checked;}else{hasValue=String(control.value==null?"":control.value).trim()!=="";}if(control.tagName==="SELECT"||control.type==="checkbox"||control.type==="radio"){control.disabled=hasValue;}else{control.readOnly=hasValue;}}';
        html += 'function applyLockedFields(){form.querySelectorAll("[data-lock-on-prefill=\'true\']").forEach(function(control){applyLockState(control);});}';
        html += 'function applyPrefillPayload(payload){if(!payload){return;}const input=payload.input||{};const hidden=payload.hidden||{};const repeatGroups=payload.repeatGroups||{};Object.keys(input).forEach(function(key){setFieldValue(key,input[key]);});Object.keys(hidden).forEach(function(key){setFieldValue(key,hidden[key]);});clearRepeatGroups();Object.keys(repeatGroups).forEach(function(groupKey){renderRepeatGroup(groupKey,repeatGroups[groupKey]);});applyLockedFields();evaluateConditions();}';
        html += 'async function runPrefill(){if(!config.prefillUrl){return;}const params={};new URLSearchParams(window.location.search).forEach(function(value,key){params[key]=value;});if(Object.keys(params).length===0){return;}const response=await fetch(config.prefillUrl,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({publishToken:config.publishToken,request:{formId:config.formId,params:params}})});const data=await response.json();if(!response.ok||data.success===false){throw new Error((data.error&&data.error.message)||data.error||"Prefill failed");}applyPrefillPayload(data);}';
        html += 'function isoDate(value){return value.toISOString().split("T")[0];}';
        html += 'function applyDateConstraints(){form.querySelectorAll("input[type=\'date\']").forEach(function(el){const now=new Date();let minDate=null;let maxDate=null;const pastYears=Number(el.dataset.pastYears||0);const pastMonths=Number(el.dataset.pastMonths||0);const futureYears=Number(el.dataset.futureYears||0);const futureMonths=Number(el.dataset.futureMonths||0);if(pastYears||pastMonths){minDate=new Date(now);minDate.setFullYear(minDate.getFullYear()-pastYears);minDate.setMonth(minDate.getMonth()-pastMonths);}if(futureYears||futureMonths){maxDate=new Date(now);maxDate.setFullYear(maxDate.getFullYear()+futureYears);maxDate.setMonth(maxDate.getMonth()+futureMonths);}if(minDate){el.min=isoDate(minDate);}if(maxDate){el.max=isoDate(maxDate);}});}';
        html += 'function validateField(el){if(!el||el.type==="hidden"){return true;}const valid=el.checkValidity();if(!valid){el.reportValidity();}return valid;}';
        html += 'function wireLiveValidation(){form.querySelectorAll("input,textarea,select").forEach(function(el){if(el.type==="hidden"){return;}["input","change","blur"].forEach(function(evt){el.addEventListener(evt,function(){validateField(el);});});});}';
        html += 'function evaluateConditions(){form.querySelectorAll("[data-condition-source]").forEach(function(el){const source=el.dataset.conditionSource;const operator=el.dataset.conditionOperator;const compare=el.dataset.conditionValue||"";const actual=readFieldValue(source);let visible=true;if(operator==="equals"){visible=String(actual)===compare;}else if(operator==="notEquals"){visible=String(actual)!==compare;}else if(operator==="isTrue"){visible=actual===true||String(actual).toLowerCase()==="true";}else if(operator==="isFalse"){visible=actual===false||String(actual).toLowerCase()==="false"||String(actual)==="";}else if(operator==="isBlank"){visible=String(actual)==="";}else if(operator==="isNotBlank"){visible=String(actual)!=="";}el.style.display=visible?"":"none";});}';
        html += 'applyDateConstraints();';
        html += 'wireLiveValidation();';
        html += 'form.addEventListener("change",evaluateConditions);';
        html += 'evaluateConditions();';
        html += 'runPrefill().catch(function(error){setStatus("error",error&&error.message?error.message:"Prefill failed.");});';
        html += 'form.addEventListener("submit",async function(event){event.preventDefault();clearStatus();';
        html += 'if(!form.reportValidity()){return;}';
        html += 'const submitButton=form.querySelector("button[type=\'submit\']");if(submitButton){submitButton.disabled=true;}';
        html += 'try{const formData=new FormData(form);const input={};for(const [key,value] of formData.entries()){input[key]=value;}';
        html += 'form.querySelectorAll("input[type=\'checkbox\'][name]").forEach(function(el){input[el.name]=!!el.checked;});';
        html += 'input.repeatGroups=collectRepeatGroups();';
        html += 'const response=await fetch(config.submitUrl,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({formId:config.formId,publishToken:config.publishToken,input:input})});';
        html += 'const data=await response.json();';
        html += 'if(!response.ok||data.success===false){throw new Error((data.error&&data.error.message)||data.error||"Submit failed");}';
        html += 'setStatus("success","Form submitted successfully.");form.reset();clearRepeatGroups();';
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
        String lockOnPrefillAttr = lockOnPrefillDataAttr(config);
        if (String.isNotBlank(lockOnPrefillAttr)) {
            wrapperAttrs += lockOnPrefillAttr;
        }
        String labelPosition = normalizedLabelPosition(config);
        Boolean labelBold = booleanValue(config.get('labelBold'));
        String labelClassAttr = labelBold ? ' class="nf-label--bold"' : '';
        Boolean hiddenByBehavior = isHiddenBehavior(config);

        if (hiddenByBehavior && typeValue != 'repeatGroup' && typeValue != 'group' && typeValue != 'section' && typeValue != 'sectionBreak') {
            String hiddenDefaultValue = String.isNotBlank(hiddenValue) ? hiddenValue : defaultValue;
            return '<input type="hidden" data-element-id="' + safeElementId + '" name="' + safeName + '" value="' + escapeHtml(hiddenDefaultValue) + '"' + lockOnPrefillAttr + '>';
        }

        if (typeValue == 'repeatGroup') {
            List<NF_Form_Element__c> childElements = childrenByParent != null && String.isNotBlank(elementRecord.Element_Id__c)
                ? childrenByParent.get(elementRecord.Element_Id__c)
                : null;
            String repeatGroupKey = String.isNotBlank(elementRecord.Field_Key__c) ? elementRecord.Field_Key__c : safeName;
            String repeatAlias = stringValue(config.get('repeatSourceAlias'));
            Boolean showTitle = !config.containsKey('showTitle') || booleanValue(config.get('showTitle'));
            Boolean boxed = !config.containsKey('boxed') || booleanValue(config.get('boxed'));
            Boolean allowAddRows = !config.containsKey('allowAddRows') || booleanValue(config.get('allowAddRows'));
            Boolean allowDeleteRows = !config.containsKey('allowDeleteRows') || booleanValue(config.get('allowDeleteRows'));
            Boolean showLabelsOnEachRow = !config.containsKey('showLabelsOnEachRow') || booleanValue(config.get('showLabelsOnEachRow'));
            Integer columnCount = safeSectionColumnCount(config);
            String idFieldKey = repeatGroupIdFieldKey(childElements);
            Boolean hasHeader = !showLabelsOnEachRow && childElements != null && !childElements.isEmpty();
            String repeatHtml = '<div class="nf-section nf-repeat' + (boxed ? '' : ' nf-section--plain') + (hasHeader ? ' nf-repeat--has-header' : '') + '" data-element-id="' + safeElementId + '"' + wrapperAttrs + ' data-repeat-group="' + escapeHtml(repeatGroupKey) + '" data-repeat-id-field="' + escapeHtml(firstNonBlank(idFieldKey, '')) + '">';
            if (showTitle) {
                repeatHtml += '<div class="nf-section__top"><h2>' + safeLabel + '</h2></div>';
            }
            // Header row (column labels) — only shown when showLabelsOnEachRow is false
            if (hasHeader) {
                repeatHtml += '<div class="nf-repeat__header-row">';
                if (allowDeleteRows) {
                    repeatHtml += '<div class="nf-repeat__header-spacer"></div>';
                }
                repeatHtml += '<div class="nf-repeat__header-body"><div class="nf-section__grid nf-section__grid--' + String.valueOf(columnCount) + '">';
                for (Integer columnIndex = 1; columnIndex <= columnCount; columnIndex++) {
                    repeatHtml += '<div class="nf-section__column">';
                    for (NF_Form_Element__c childElement : childElements) {
                        if (readSectionColumn(childElement.Config_JSON__c) == columnIndex) {
                            Map<String, Object> childConfig = parseJsonMap(childElement.Config_JSON__c);
                            if (isHiddenBehavior(childConfig) || childElement.Element_Type__c == 'hidden') {
                                continue;
                            }
                            String childLabel = String.isNotBlank(childElement.Label__c) ? childElement.Label__c : childElement.Field_Key__c;
                            Boolean childLabelBold = booleanValue(childConfig.get('labelBold'));
                            repeatHtml += '<div class="nf-field"><label' + (childLabelBold ? ' class="nf-label--bold"' : '') + '>' + escapeHtml(childLabel) + '</label></div>';
                        }
                    }
                    repeatHtml += '</div>';
                }
                repeatHtml += '</div></div></div>';
            }
            repeatHtml += '<div class="nf-repeat__rows" data-repeat-rows="' + escapeHtml(repeatGroupKey) + '"></div>';
            if (allowAddRows) {
                repeatHtml += '<div class="nf-repeat__actions"><button type="button" data-repeat-add="' + escapeHtml(repeatGroupKey) + '">Add Row</button></div>';
            }
            repeatHtml += '</div>';
            repeatHtml += '<template data-repeat-template="' + escapeHtml(repeatGroupKey) + '">';
            repeatHtml += '<div class="nf-repeat__row" data-repeat-row>';
            if (allowDeleteRows) {
                repeatHtml += '<div class="nf-repeat__row-delete"><button type="button" data-repeat-delete-row="' + escapeHtml(repeatGroupKey) + '" title="Delete row">&#x2715;</button></div>';
            }
            repeatHtml += '<div class="nf-repeat__row-body">';
            if (childElements != null) {
                repeatHtml += '<div class="nf-section__grid nf-section__grid--' + String.valueOf(columnCount) + '">';
                for (Integer columnIndex = 1; columnIndex <= columnCount; columnIndex++) {
                    repeatHtml += '<div class="nf-section__column">';
                    for (NF_Form_Element__c childElement : childElements) {
                        if (readSectionColumn(childElement.Config_JSON__c) == columnIndex) {
                            repeatHtml += renderRepeatGroupChildElement(childElement, repeatAlias, showLabelsOnEachRow);
                        }
                    }
                    repeatHtml += '</div>';
                }
                repeatHtml += '</div>';
            }
            repeatHtml += '</div>';
            repeatHtml += '</div></template>';
            return repeatHtml;
        }

        if (typeValue == 'group') {
            List<NF_Form_Element__c> childElements = childrenByParent != null && String.isNotBlank(elementRecord.Element_Id__c)
                ? childrenByParent.get(elementRecord.Element_Id__c)
                : null;
            Integer columnCount = safeSectionColumnCount(config);
            String groupHtml = '<div data-element-id="' + safeElementId + '"' + wrapperAttrs + '>';
            if (childElements != null && !childElements.isEmpty()) {
                if (columnCount <= 1) {
                    for (NF_Form_Element__c childElement : childElements) {
                        groupHtml += renderElement(childElement, childrenByParent);
                    }
                } else {
                    groupHtml += '<div class="nf-section__grid nf-section__grid--' + String.valueOf(columnCount) + '">';
                    for (Integer columnIndex = 1; columnIndex <= columnCount; columnIndex++) {
                        groupHtml += '<div class="nf-section__column">';
                        for (NF_Form_Element__c childElement : childElements) {
                            if (readSectionColumn(childElement.Config_JSON__c) == columnIndex) {
                                groupHtml += renderElement(childElement, childrenByParent);
                            }
                        }
                        groupHtml += '</div>';
                    }
                    groupHtml += '</div>';
                }
            }
            groupHtml += '</div>';
            return groupHtml;
        }

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
                sectionHtml += '<div class="nf-section__top"><h2>' + safeLabel + '</h2></div>';
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
            String controlHtml = '<textarea id="' + safeName + '" name="' + safeName + '"' + lockOnPrefillAttr + placeholderAttr + requiredAttr + patternAttr + '></textarea>';
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
            String controlHtml = '<select id="' + safeName + '" name="' + safeName + '"' + lockOnPrefillAttr + requiredAttr + '>' + optionsHtml + '</select>';
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
                    radiosHtml += '<input type="radio" id="' + escapeHtml(optionId) + '" name="' + safeName + '" value="' + escapeHtml(optionValue) + '"' + lockOnPrefillAttr + checkedAttr + requiredAttr + '>';
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
                return '<div class="nf-field nf-field--checkbox" data-element-id="' + safeElementId + '"' + wrapperAttrs + '><label><input type="checkbox" name="' + safeName + '"' + lockOnPrefillAttr + checkedAttr + requiredAttr + '></label></div>';
            }
            return '<div class="nf-field nf-field--checkbox nf-field--' + escapeHtml(labelPosition) + '" data-element-id="' + safeElementId + '"' + wrapperAttrs + '><label' + labelClassAttr + '><input type="checkbox" name="' + safeName + '"' + lockOnPrefillAttr + checkedAttr + requiredAttr + '> ' + safeLabel + '</label></div>';
        }
        if (typeValue == 'hidden') {
            return '<input type="hidden" data-element-id="' + safeElementId + '" name="' + safeName + '" value="' + escapeHtml(hiddenValue) + '">';
        }

        String htmlType = normalizeInputType(typeValue);
        String valueAttr = String.isNotBlank(defaultValue) ? ' value="' + escapeHtml(defaultValue) + '"' : '';
        String labelHtml = labelPosition == 'hidden' ? '' : '<label for="' + safeName + '"' + labelClassAttr + '>' + safeLabel + '</label>';
        String controlHtml = '<input type="' + escapeHtml(htmlType) + '" id="' + safeName + '" name="' + safeName + '"' + lockOnPrefillAttr + placeholderAttr + valueAttr + requiredAttr + minAttr + maxAttr + dateRangeAttrs + patternAttr + '>';
        return renderFieldWrapper(safeElementId, wrapperAttrs, labelPosition, labelHtml, controlHtml);
    }

    private static String renderRepeatGroupChildElement(NF_Form_Element__c elementRecord, String repeatAlias, Boolean showLabels) {
        Map<String, Object> config = parseJsonMap(elementRecord.Config_JSON__c);
        String typeValue = String.isBlank(elementRecord.Element_Type__c) ? 'text' : elementRecord.Element_Type__c;
        String fieldKey = String.isNotBlank(elementRecord.Field_Key__c) ? elementRecord.Field_Key__c : String.valueOf(elementRecord.Id);
        String sourceField = stringValue(config.get('prefillFieldPath'));
        if (stringValue(config.get('prefillAlias')) != repeatAlias) {
            sourceField = fieldKey;
        }
        sourceField = String.isBlank(sourceField) ? fieldKey : sourceField;
        String label = String.isNotBlank(elementRecord.Label__c) ? elementRecord.Label__c : fieldKey;
        String placeholder = stringValue(config.get('placeholder'));
        String labelPosition = showLabels ? normalizedLabelPosition(config) : 'hidden';
        String labelClassAttr = booleanValue(config.get('labelBold')) ? ' class="nf-label--bold"' : '';
        String repeatLabelClassAttr = labelPosition == 'hidden'
            ? ' class="nf-repeat-mobile-label' + (booleanValue(config.get('labelBold')) ? ' nf-label--bold' : '') + '"'
            : labelClassAttr;
        String sourceAttr = ' data-repeat-source-field="' + escapeHtml(sourceField) + '"';
        String keyAttr = ' data-repeat-field-key="' + escapeHtml(fieldKey) + '"';
        String lockOnPrefillAttr = lockOnPrefillDataAttr(config);
        String baseId = escapeHtml(fieldKey);
        Boolean hiddenByBehavior = isHiddenBehavior(config);

        if (typeValue == 'heading') {
            String richHtml = config.containsKey('html') ? String.valueOf(config.get('html')) : '<p>' + escapeHtml(label) + '</p>';
            return '<div class="nf-richtext">' + richHtml + '</div>';
        }

        if (typeValue == 'image') {
            return '';
        }

        if (typeValue == 'checkbox') {
            return '<div class="nf-field nf-field--checkbox nf-field--' + escapeHtml(labelPosition) + '"><label' + labelClassAttr + '><input type="checkbox" id="' + baseId + '"' + keyAttr + sourceAttr + lockOnPrefillAttr + '> ' + escapeHtml(label) + '</label></div>';
        }

        if (typeValue == 'textarea') {
            String labelHtml = '<label for="' + baseId + '"' + repeatLabelClassAttr + '>' + escapeHtml(label) + '</label>';
            String controlHtml = '<textarea id="' + baseId + '"' + keyAttr + sourceAttr + lockOnPrefillAttr + (String.isNotBlank(placeholder) ? ' placeholder="' + escapeHtml(placeholder) + '"' : '') + '></textarea>';
            return renderFieldWrapper('', '', labelPosition, labelHtml, controlHtml);
        }

        if (typeValue == 'select' && config.containsKey('options')) {
            String optionsHtml = '<option value="">Select...</option>';
            for (Object rawOption : (List<Object>) config.get('options')) {
                if (rawOption instanceof Map<String, Object>) {
                    Map<String, Object> option = (Map<String, Object>) rawOption;
                    optionsHtml += '<option value="' + escapeHtml(String.valueOf(option.get('value'))) + '">' + escapeHtml(String.valueOf(option.get('label'))) + '</option>';
                }
            }
            String labelHtml = '<label for="' + baseId + '"' + repeatLabelClassAttr + '>' + escapeHtml(label) + '</label>';
            String controlHtml = '<select id="' + baseId + '"' + keyAttr + sourceAttr + lockOnPrefillAttr + '>' + optionsHtml + '</select>';
            return renderFieldWrapper('', '', labelPosition, labelHtml, controlHtml);
        }

        if (typeValue == 'radio' && config.containsKey('options')) {
            String html = '<div class="nf-field nf-field--' + escapeHtml(labelPosition) + '">';
            html += '<label' + repeatLabelClassAttr + '>' + escapeHtml(label) + '</label>';
            html += '<div class="nf-field--radio-group">';
            Integer optionIndex = 0;
            for (Object rawOption : (List<Object>) config.get('options')) {
                if (rawOption instanceof Map<String, Object>) {
                    Map<String, Object> option = (Map<String, Object>) rawOption;
                    String optionId = baseId + '-' + String.valueOf(optionIndex);
                    html += '<label class="nf-radio-option" for="' + escapeHtml(optionId) + '">';
                    html += '<input type="radio" id="' + escapeHtml(optionId) + '" value="' + escapeHtml(String.valueOf(option.get('value'))) + '"' + keyAttr + sourceAttr + lockOnPrefillAttr + '>';
                    html += '<span>' + escapeHtml(String.valueOf(option.get('label'))) + '</span></label>';
                    optionIndex += 1;
                }
            }
            html += '</div></div>';
            return html;
        }

        if (typeValue == 'hidden' || hiddenByBehavior) {
            return '<input type="hidden" id="' + baseId + '"' + keyAttr + sourceAttr + '>';
        }

        String htmlType = normalizeInputType(typeValue);
        String labelHtml = '<label for="' + baseId + '"' + repeatLabelClassAttr + '>' + escapeHtml(label) + '</label>';
        String controlHtml = '<input type="' + escapeHtml(htmlType) + '" id="' + baseId + '"' + keyAttr + sourceAttr + lockOnPrefillAttr + (String.isNotBlank(placeholder) ? ' placeholder="' + escapeHtml(placeholder) + '"' : '') + '>';
        return renderFieldWrapper('', '', labelPosition, labelHtml, controlHtml);
    }

    private static String lockOnPrefillDataAttr(Map<String, Object> config) {
        if (config != null && stringValue(config.get('fieldBehavior')) == 'readonlyWhenPrefilled') {
            return ' data-lock-on-prefill="true"';
        }
        return '';
    }

    private static String repeatGroupIdFieldKey(List<NF_Form_Element__c> childElements) {
        if (childElements == null) {
            return null;
        }
        for (NF_Form_Element__c childElement : childElements) {
            Map<String, Object> config = parseJsonMap(childElement.Config_JSON__c);
            if (stringValue(config.get('submitFieldPath')) == 'Id' || stringValue(config.get('prefillFieldPath')) == 'Id') {
                return childElement.Field_Key__c;
            }
        }
        return null;
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

    private static Boolean isHiddenBehavior(Map<String, Object> config) {
        return config != null && stringValue(config.get('fieldBehavior')) == 'hidden';
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

    private static Map<String, Object> buildPublishedTheme(NF_Form_Version__c versionRecord) {
        Map<String, Object> fallbackTheme = parseJsonMap(versionRecord.Theme_JSON__c);
        if (versionRecord == null || versionRecord.Form__r == null || versionRecord.Form__r.Theme__r == null) {
            return fallbackTheme;
        }

        Map<String, Object> theme = new Map<String, Object>{
            'logoUrl' => versionRecord.Form__r.Theme__r.Logo_URL__c,
            'logoSizePx' => versionRecord.Form__r.Theme__r.Logo_Size_Px__c,
            'logoPosition' => versionRecord.Form__r.Theme__r.Logo_Position__c,
            'formWidth' => versionRecord.Form__r.Theme__r.Form_Width__c,
            'backgroundColor' => versionRecord.Form__r.Theme__r.Background_Color__c,
            'formBackgroundColor' => versionRecord.Form__r.Theme__r.Form_Background_Color__c,
            'formBorderColor' => versionRecord.Form__r.Theme__r.Form_Border_Color__c,
            'titleFont' => versionRecord.Form__r.Theme__r.Title_Font__c,
            'titleFontSizePx' => versionRecord.Form__r.Theme__r.Title_Font_Size_Px__c,
            'titleTextColor' => versionRecord.Form__r.Theme__r.Title_Text_Color__c,
            'sectionTitleFont' => versionRecord.Form__r.Theme__r.Section_Title_Font__c,
            'sectionTitleFontSizePx' => versionRecord.Form__r.Theme__r.Section_Title_Font_Size_Px__c,
            'sectionTitleTextColor' => versionRecord.Form__r.Theme__r.Section_Title_Text_Color__c,
            'mainFont' => versionRecord.Form__r.Theme__r.Main_Font__c,
            'mainTextSizePx' => versionRecord.Form__r.Theme__r.Main_Text_Size_Px__c,
            'mainTextColor' => versionRecord.Form__r.Theme__r.Main_Text_Color__c,
            'linkTextColor' => versionRecord.Form__r.Theme__r.Link_Text_Color__c,
            'hintTextColor' => versionRecord.Form__r.Theme__r.Hint_Text_Color__c,
            'errorColor' => versionRecord.Form__r.Theme__r.Error_Color__c,
            'inputBorderRadiusPx' => versionRecord.Form__r.Theme__r.Input_Border_Radius_Px__c,
            'inputBackgroundColor' => versionRecord.Form__r.Theme__r.Input_Background_Color__c,
            'inputBorderColor' => versionRecord.Form__r.Theme__r.Input_Border_Color__c,
            'buttonFont' => versionRecord.Form__r.Theme__r.Button_Font__c,
            'buttonFontSizePx' => versionRecord.Form__r.Theme__r.Button_Font_Size_Px__c,
            'buttonTextColor' => versionRecord.Form__r.Theme__r.Button_Text_Color__c,
            'buttonBackgroundColor' => versionRecord.Form__r.Theme__r.Button_Background_Color__c,
            'buttonHoverBackgroundColor' => versionRecord.Form__r.Theme__r.Button_Hover_Background_Color__c
        };

        if (fallbackTheme != null) {
            for (String key : fallbackTheme.keySet()) {
                if (!theme.containsKey(key) || theme.get(key) == null) {
                    theme.put(key, fallbackTheme.get(key));
                }
            }
        }

        return theme;
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
        if (String.isBlank(value)) {
            return fallbackValue;
        }
        String trimmed = value.trim();
        if (trimmed.endsWith('px') || trimmed.endsWith('rem') || trimmed.endsWith('em') || trimmed.endsWith('%')) {
            return escapeHtml(trimmed);
        }
        if (Pattern.matches('^-?\\d+(\\.\\d+)?$', trimmed)) {
            return escapeHtml(trimmed + 'px');
        }
        return escapeHtml(trimmed);
    }

    private static String cssFontFamily(Map<String, Object> source, String key, String fallbackValue) {
        String value = stringValue(source.get(key));
        return String.isNotBlank(value) ? escapeHtml(value) : fallbackValue;
    }

    private static String cssFormWidth(Map<String, Object> source, String key, String fallbackValue) {
        String value = stringValue(source.get(key)).toLowerCase();
        if (value == 'narrow') return '640px';
        if (value == 'standard') return '760px';
        if (value == 'wide') return '880px';
        if (value == 'full') return '100%';
        return fallbackValue;
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
