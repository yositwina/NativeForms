public with sharing class NativeFormsPublisher {
    private static final String SHARED_CAPTCHA_SITE_KEY = '6LcclLgsAAAAAF3Te6PKyPqNhges_8IJkXBJtsru';
    private static final String PUBLISHED_FORMS_BASE_URL = 'https://forms.twinaforms.com';
    private static final String TEMP_PREFILL_URL = 'https://a2guxusajjhwzakf3tg6ispb640pgsno.lambda-url.eu-north-1.on.aws/';
    private static final String TEMP_SUBMIT_URL = 'https://hfkuwm6emqiaz2drmuip6zqn5m0agbyp.lambda-url.eu-north-1.on.aws/';
    private static final String TEMP_UPLOAD_INIT_URL = 'https://f4apx2tkemgn5i2vagzhboeyjm0nnnjh.lambda-url.eu-north-1.on.aws/forms/upload/init';
    private static final Pattern FRIENDLY_FORM_SLUG_PATTERN = Pattern.compile('^[a-z0-9]+(?:-[a-z0-9]+)*$');

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
                   Form__r.Enable_Captcha__c,
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
        String formSlug = normalizePublishedFormSlug(versionRecord.Form__r.NF_Key__c);
        if (String.isBlank(formSlug)) {
            versionRecord.Publish_Status__c = 'Publish Failed';
            versionRecord.Last_Publish_Error__c = 'Friendly published URLs require NF Key before publish. Fill NF Key with lowercase letters, numbers, and hyphens, then publish again.';
            update versionRecord;
            result.success = false;
            result.message = versionRecord.Last_Publish_Error__c;
            return result;
        }

        String formId = String.isNotBlank(versionRecord.Form_Id__c)
            ? versionRecord.Form_Id__c
            : buildInternalFormId(orgId, versionRecord.Form__c);
        versionRecord.Form_Id__c = formId;

        String publishToken = String.isNotBlank(versionRecord.Publish_Token__c)
            ? versionRecord.Publish_Token__c
            : EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(String.valueOf(versionRecord.Id) + ':' + String.valueOf(Datetime.now().getTime())))).substring(0, 32);

        NativeForms_Config__c orgConfig = NativeForms_Config__c.getOrgDefaults();
        Map<String, Object> captchaConfig = buildPublishedCaptchaConfig(versionRecord.Form__r.Enable_Captcha__c, orgConfig);
        List<NF_Form_Element__c> publishElements = prepareElementsForPublish(elements);
        String html = buildHtml(versionRecord, publishElements, formId, publishToken, captchaConfig);
        String fileName = 'index.html';

        try {
            NativeFormsAwsClient.PresignRequest presignRequest = new NativeFormsAwsClient.PresignRequest();
            presignRequest.orgId = orgId;
            presignRequest.formId = formId;
            presignRequest.formSlug = formSlug;
            presignRequest.versionId = 'current';
            presignRequest.fileName = fileName;
            presignRequest.contentType = 'text/html; charset=utf-8';
            presignRequest.expires = 900;

            NativeFormsAwsClient.PresignResponse presignResponse = NativeFormsAwsClient.presignHtml(presignRequest);
            NativeFormsAwsClient.uploadHtml(presignResponse.putUrl, html);
            String publishedPublicUrl = normalizePublishedPublicUrl(presignResponse.publicUrl, presignResponse.key);

            Map<String, Object> registerPayload = new Map<String, Object>{
                'orgId' => orgId,
                'formId' => formId,
                'publishedVersionId' => (String) versionRecord.Id,
                'publishToken' => publishToken,
                'status' => 'published',
                'securityMode' => determineSecurityMode(versionRecord.Security_Mode__c, actions, publishElements),
                'rateLimitProfile' => String.isNotBlank(versionRecord.Rate_Limit_Profile__c) ? versionRecord.Rate_Limit_Profile__c : 'standard',
                'generatedHtmlRef' => presignResponse.key,
                'publicUrl' => publishedPublicUrl,
                'companySlug' => presignResponse.companySlug,
                'formSlug' => formSlug,
                'captcha' => captchaConfig,
                'uploadFields' => buildPublishedUploadFields(publishElements),
                'secretCodeConfig' => buildPublishedSecretCodeConfig(
                    parseJsonMap(versionRecord.UI_Settings_JSON__c),
                    NativeFormsRuntimeI18n.normalizeLanguageCode(
                        stringValue(parseJsonMap(versionRecord.UI_Settings_JSON__c).get('languageCode'))
                    )
                ),
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
                Generated_HTML_Ref__c = publishedPublicUrl,
                AWS_Response_JSON__c = JSON.serialize(registerResponse),
                Error_Message__c = null
            );
            insert publicationRecord;

            versionRecord.Publish_Token__c = publishToken;
            versionRecord.Form_Id__c = formId;
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
            result.publicUrl = publishedPublicUrl;
            result.key = presignResponse.key;
            result.publicationId = publicationRecord.Id;
            result.message = successorDraft == null
                ? 'Published successfully.'
                : 'Published successfully. A new draft version was created.';
            return result;
        } catch (Exception e) {
            String detailedError = formatException(e);
            String friendlyError = friendlyPublishErrorMessage(e);
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
            versionRecord.Last_Publish_Error__c = friendlyError;
            update versionRecord;

            result.success = false;
            result.publicationId = failureRecord.Id;
            result.message = friendlyError;
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

        return [
            SELECT Id, Name, Form__c, Form_Id__c, Version_Number__c, Version_Status__c, Publish_Status__c, Publish_Token__c
            FROM NF_Form_Version__c
            WHERE Id = :draftVersion.Id
            LIMIT 1
        ];
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
            if (updateCommand.containsKey('fields')) {
                commands.add(updateCommand);
            }

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
                if (createCommand.containsKey('fields')) {
                    commands.add(createCommand);
                }
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
        if ((normalizedType == 'create' || normalizedType == 'update') && !commandConfig.containsKey('fields')) {
            return commands;
        }
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
            String paramName = normalizeParamName(valueText);
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
        normalized = normalizeParamTokensInText(normalized);
        return normalized;
    }

    private static String normalizeParamName(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }

        String paramName = rawValue.trim();
        if (paramName.startsWith('{params.') && paramName.endsWith('}')) {
            paramName = paramName.substring(8, paramName.length() - 1);
        } else if (paramName.toLowerCase().startsWith('params.')) {
            paramName = paramName.substring(7);
        }

        paramName = paramName.trim().toLowerCase();
        return String.isBlank(paramName) ? null : paramName;
    }

    private static String normalizeParamTokensInText(String rawValue) {
        if (String.isBlank(rawValue)) {
            return rawValue;
        }

        Matcher matcher = Pattern.compile('\\{params\\.([A-Za-z0-9_\\.]+)\\}').matcher(rawValue);
        String normalized = rawValue;
        while (matcher.find()) {
            String token = matcher.group(0);
            String paramName = matcher.group(1);
            if (String.isNotBlank(paramName)) {
                normalized = normalized.replace(token, '{params.' + paramName.toLowerCase() + '}');
            }
        }
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

    private static String buildHtml(NF_Form_Version__c versionRecord, List<NF_Form_Element__c> elements, String formId, String publishToken, Map<String, Object> captchaConfig) {
        Map<String, Object> theme = buildPublishedTheme(versionRecord);
        Map<String, Object> uiSettings = parseJsonMap(versionRecord.UI_Settings_JSON__c);
        String languageCode = NativeFormsRuntimeI18n.normalizeLanguageCode(stringValue(uiSettings.get('languageCode')));
        Map<String, Object> runtimeText = NativeFormsRuntimeI18n.runtimeText(languageCode);
        Boolean captchaEnabled = captchaConfig != null && booleanValue(captchaConfig.get('enabled'));
        String captchaSiteKey = captchaEnabled ? stringValue(captchaConfig.get('siteKey')) : '';
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
        String submitLabel = localizedFormUiSettingValue(
            uiSettings,
            'submitLabel',
            languageCode,
            'Submit'
        );
        String submitSuccessMessage = localizedFormUiSettingValue(
            uiSettings,
            'submitSuccessMessage',
            languageCode,
            'Your form was submitted successfully.'
        );
        String postSubmitButtonLabel = localizedFormUiSettingValue(
            uiSettings,
            'postSubmitButtonLabel',
            languageCode,
            'Continue'
        );
        Boolean rtlEnabled = booleanValue(uiSettings.get('rtlEnabled'));
        Map<String, Object> secretCodeConfig = buildPublishedSecretCodeConfig(uiSettings, languageCode);
        Boolean secretCodeEnabled = booleanValue(secretCodeConfig.get('enabled'));
        Map<String, Object> submitButtonConfig = new Map<String, Object>{
            'conditionalEnabled' => booleanValue(uiSettings.get('submitConditionalEnabled')),
            'conditionalFieldKey' => stringValue(uiSettings.get('submitConditionalFieldKey')),
            'conditionalOperator' => stringValue(uiSettings.get('submitConditionalOperator')),
            'conditionalValue' => stringValue(uiSettings.get('submitConditionalValue')),
            'conditionalConditions' => uiSettings.get('submitConditionalConditions'),
            'conditionalExpression' => stringValue(uiSettings.get('submitConditionalExpression'))
        };
        String submitButtonWrapperAttrs = conditionalDataAttrs(submitButtonConfig);
        if (booleanValue(uiSettings.get('submitConditionalEnabled')) && normalizedConditionalConditions(submitButtonConfig).isEmpty()) {
            submitButtonWrapperAttrs += ' style="display:none;"';
        }

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
        html += '--nf-button-bg:' + cssColor(theme, 'buttonBackgroundColor', '#0f6cbd') + ';';
        html += '--nf-button-text:' + cssColor(theme, 'buttonTextColor', '#ffffff') + ';';
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
        html += '.nf-shell--result-only{min-height:0;background:transparent;border:0;box-shadow:none;padding:0;}';
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
        html += '.nf-required-marker{color:#b42318;margin-left:4px;font-weight:700;}';
        html += '.nf-field label.nf-label--bold{font-weight:700;}';
        html += '.nf-field label.nf-label--italic{font-style:italic;}';
        html += '.nf-field label.nf-label--underline{text-decoration:underline;}';
        html += '.nf-field--above{grid-template-columns:minmax(0,1fr);}';
        html += '.nf-field--left{grid-template-columns:140px minmax(0,1fr);column-gap:12px;}';
        html += '.nf-field--left label{padding-top:12px;word-break:break-word;}';
        html += '.nf-field--right{grid-template-columns:minmax(0,1fr) auto;column-gap:12px;align-items:center;}';
        html += '.nf-field--right label{word-break:break-word;text-align:left;}';
        html += '.nf-field--hidden > label{display:none;}';
        html += '.nf-field input,.nf-field textarea,.nf-field select{width:100%;padding:12px 14px;border:1px solid var(--nf-input-border);border-radius:var(--nf-field-radius);font:inherit;box-sizing:border-box;background:var(--nf-input-bg);color:var(--nf-text);box-shadow:none;}';
        html += '.nf-field textarea{min-height:120px;resize:vertical;}';
        html += '.nf-field--checkbox label{display:flex;gap:10px;align-items:center;font-weight:400;}';
        html += '.nf-field--checkbox input{width:auto;}';
        html += '.nf-upload{display:grid;gap:10px;}';
        html += '.nf-upload__input{position:absolute;width:1px;height:1px;opacity:0;pointer-events:none;}';
        html += '.nf-upload__surface{display:grid;justify-items:start;gap:8px;padding:18px 20px;border:1px dashed color-mix(in srgb,var(--nf-input-border) 88%,#b6d4f3 12%);border-radius:calc(var(--nf-field-radius) + 4px);background:linear-gradient(180deg,color-mix(in srgb,var(--nf-input-bg) 92%,#ffffff 8%),#f8fbff);cursor:pointer;text-align:left;transition:border-color 120ms ease,box-shadow 120ms ease,background 120ms ease;}';
        html += '.nf-upload__surface:hover{border-color:color-mix(in srgb,var(--nf-button-bg) 55%,var(--nf-input-border) 45%);box-shadow:0 0 0 3px rgba(15,108,189,0.08);}';
        html += '.nf-upload__title{font-weight:700;color:var(--nf-text);}';
        html += '.nf-upload__action{display:inline-flex;align-items:center;justify-content:center;padding:8px 14px;border-radius:999px;background:var(--nf-button-bg);color:var(--nf-button-text);font-weight:700;box-shadow:0 10px 20px rgba(15,108,189,0.14);}';
        html += '.nf-upload__meta,.nf-upload__feedback{font-size:0.92em;line-height:1.4;color:var(--nf-hint);}';
        html += '.nf-upload__feedback:empty,.nf-upload__list:empty{display:none;}';
        html += '.nf-upload__list{display:grid;gap:8px;}';
        html += '.nf-upload__file{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:10px 12px;border:1px solid color-mix(in srgb,var(--nf-input-border) 88%,#dbe5ef 12%);border-radius:calc(var(--nf-field-radius) - 2px);background:color-mix(in srgb,var(--nf-input-bg) 96%,#f7fbff 4%);}';
        html += '.nf-upload__file-name{min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:var(--nf-text);}';
        html += '.nf-upload__file-status{flex:0 0 auto;padding:4px 8px;border-radius:999px;background:rgba(22,91,51,0.08);color:#165b33;font-size:0.82em;font-weight:700;}';
        html += '.nf-field button[data-file-upload-clear]{justify-self:start;margin-top:2px;border:1px solid var(--nf-input-border);background:#fff;color:var(--nf-text);border-radius:999px;padding:8px 12px;font:inherit;cursor:pointer;}';
        html += '.nf-field--radio-group{display:grid;gap:10px;}';
        html += '.nf-radio-option{display:flex;gap:16px;align-items:center;padding:12px 14px;border:1px solid var(--nf-input-border);border-radius:var(--nf-field-radius);background:var(--nf-input-bg);color:var(--nf-text);box-sizing:border-box;font:inherit;}';
        html += '.nf-radio-option input{width:auto;margin:0;flex:0 0 auto;}';
        html += '.nf-radio-option span{flex:1 1 auto;margin-left:8px;}';
        html += '.nf-status{margin-top:16px;padding:12px 14px;border-radius:12px;display:none;}';
        html += '.nf-status--success{display:block;background:#e8f6ee;color:#165b33;border:1px solid #b8e0c7;}';
        html += '.nf-status--error{display:block;background:#fde7e9;color:#7f1d1d;border:1px solid #f5c2c7;}';
        html += '.nf-result{margin-top:18px;}';
        html += '.nf-result[hidden]{display:none !important;}';
        html += '.nf-result__panel{padding:18px 20px;border-radius:18px;border:1px solid #d8e4f4;box-shadow:0 10px 24px rgba(15,35,65,.06);}';
        html += '.nf-result__panel--success{background:#e8f6ee;border-color:#b8e0c7;color:#165b33;}';
        html += '.nf-result__panel--error{background:#fff4f5;border-color:#f2c0c0;color:#7f1d1d;}';
        html += '.nf-result__title{margin:0;font-size:24px;line-height:1.15;}';
        html += '.nf-result__subtitle{margin:10px 0 0;font-weight:700;}';
        html += '.nf-result__message{margin:10px 0 0;line-height:1.6;}';
        html += '.nf-result__meta{margin:10px 0 0;font-size:14px;font-weight:600;opacity:.95;}';
        html += '.nf-result__actions{margin-top:16px;display:flex;justify-content:flex-start;}';
        html += '.nf-result__actions button{background:var(--nf-accent);color:var(--nf-accent-contrast);border:0;border-radius:999px;padding:12px 20px;font-weight:700;cursor:pointer;box-shadow:0 10px 20px rgba(15,108,189,.18);}';
        html += '.nf-result__details{margin-top:14px;}';
        html += '.nf-result__details summary{cursor:pointer;font-weight:700;}';
        html += '.nf-result__details pre{margin:12px 0 0;padding:14px;border-radius:12px;background:rgba(9,30,66,.06);color:#16325c;font:12px/1.5 ui-monospace,SFMono-Regular,Consolas,monospace;white-space:pre-wrap;word-break:break-word;overflow:auto;}';
        html += '.nf-captcha{margin-top:22px;display:flex;justify-content:flex-start;}';
        html += '.nf-actions{margin-top:28px;display:flex;justify-content:flex-end;}';
        html += '.nf-actions button{background:var(--nf-accent);color:var(--nf-accent-contrast);border:0;border-radius:999px;padding:12px 20px;font-weight:700;cursor:pointer;box-shadow:0 10px 20px rgba(15,108,189,.18);}';
        html += '.nf-actions button[disabled]{opacity:.72;cursor:wait;}';
        html += '.nf-secret-gated[hidden]{display:none !important;}';
        html += '.nf-secret-verify{display:grid;gap:14px;padding:18px 20px;border:1px solid #d8e4f4;border-radius:18px;background:linear-gradient(180deg,#fbfdff 0%,#f4f8fc 100%);box-shadow:0 10px 24px rgba(15,35,65,.04);}';
        html += '.nf-secret-verify__badge{display:inline-flex;align-items:center;justify-content:center;width:fit-content;padding:4px 10px;border-radius:999px;background:rgba(15,108,189,.08);color:#0f6cbd;font-size:12px;font-weight:700;text-transform:uppercase;}';
        html += '.nf-secret-verify__title{margin:0;font-size:20px;line-height:1.2;color:var(--nf-title-color);}';
        html += '.nf-secret-verify__copy,.nf-secret-verify__message{margin:0;color:var(--nf-muted);line-height:1.5;}';
        html += '.nf-secret-verify__label{margin:0;font-size:14px;font-weight:700;color:var(--nf-text);}';
        html += '.nf-secret-verify__label--muted{color:var(--nf-muted);}';
        html += '.nf-secret-verify__message--success{color:#165b33;font-weight:700;}';
        html += '.nf-secret-verify__message--error{color:#b42318;font-weight:700;}';
        html += '.nf-secret-verify__row{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:12px;align-items:end;}';
        html += '.nf-secret-verify__row--ghost{opacity:.55;}';
        html += '.nf-secret-verify__row input{width:100%;padding:12px 14px;border:1px solid var(--nf-input-border);border-radius:var(--nf-field-radius);font:inherit;box-sizing:border-box;background:var(--nf-input-bg);color:var(--nf-text);box-shadow:none;}';
        html += '.nf-secret-verify__row button,.nf-secret-verify__resend{background:var(--nf-accent);color:var(--nf-accent-contrast);border:0;border-radius:999px;padding:12px 20px;font:inherit;font-weight:700;cursor:pointer;box-shadow:0 10px 20px rgba(15,108,189,.18);}';
        html += '.nf-secret-verify__row button[disabled],.nf-secret-verify__resend[disabled]{opacity:.6;cursor:not-allowed;}';
        html += '.nf-secret-verify__resend{justify-self:start;background:#fff;color:var(--nf-text);border:1px solid var(--nf-input-border);box-shadow:none;}';
        html += '.nf-secret-verify__code-step[hidden],.nf-secret-verify__resend-wrap[hidden]{display:none !important;}';
        html += '.nf-meta{display:none;}';
        html += '.nf-logo-wrap{display:flex;margin-bottom:20px;}';
        html += '.nf-logo-wrap--left{justify-content:flex-start;}';
        html += '.nf-logo-wrap--center{justify-content:center;}';
        html += '.nf-logo-wrap--right{justify-content:flex-end;}';
        html += '.nf-logo{display:block;max-width:100%;}';
        html += '.nf-title{margin:0;color:var(--nf-title-color);font-family:var(--nf-title-font);font-size:var(--nf-title-size);}';
        html += '.nf-intro{margin:8px 0 0;color:var(--nf-muted);}';
        html += '.nf-shell[dir="rtl"] .nf-header,.nf-shell[dir="rtl"] .nf-copy,.nf-shell[dir="rtl"] .nf-richtext,.nf-shell[dir="rtl"] .nf-status,.nf-shell[dir="rtl"] .nf-result__panel,.nf-shell[dir="rtl"] .nf-result__details summary,.nf-shell[dir="rtl"] .nf-section__top h2,.nf-shell[dir="rtl"] .nf-field label{text-align:right;}';
        html += '.nf-shell[dir="rtl"] .nf-section__top{left:auto;right:1.1rem;}';
        html += '.nf-shell[dir="rtl"] .nf-required-marker{margin-left:0;margin-right:6px;}';
        html += '.nf-shell[dir="rtl"] .nf-section__grid{direction:rtl;}';
        html += '.nf-shell[dir="rtl"] .nf-repeat__meta,.nf-shell[dir="rtl"] .nf-repeat__header-row{direction:rtl;}';
        html += '.nf-shell[dir="rtl"] .nf-field--left{display:flex;align-items:center;justify-content:flex-start;gap:12px;}';
        html += '.nf-shell[dir="rtl"] .nf-field--left label{order:2;flex:0 0 140px;direction:ltr;margin:0;white-space:normal;max-width:100%;text-align:right;}';
        html += '.nf-shell[dir="rtl"] .nf-field--left input,.nf-shell[dir="rtl"] .nf-field--left textarea,.nf-shell[dir="rtl"] .nf-field--left select,.nf-shell[dir="rtl"] .nf-field--left .nf-field--radio-group{order:1;flex:1 1 auto;min-width:0;}';
        html += '.nf-shell[dir="rtl"] .nf-field--right{grid-template-columns:140px minmax(0,1fr);column-gap:12px;align-items:start;}';
        html += '.nf-shell[dir="rtl"] .nf-field--right label{margin:0;white-space:normal;overflow-wrap:anywhere;text-align:right;line-height:1.35;padding-top:12px;}';
        html += '.nf-shell[dir="rtl"] .nf-field--right input,.nf-shell[dir="rtl"] .nf-field--right textarea,.nf-shell[dir="rtl"] .nf-field--right select,.nf-shell[dir="rtl"] .nf-field--right .nf-field--radio-group{grid-column:2;grid-row:1;}';
        html += '.nf-shell[dir="rtl"] .nf-field--checkbox label,.nf-shell[dir="rtl"] .nf-radio-option{flex-direction:row-reverse;justify-content:flex-end;}';
        html += '.nf-shell[dir="rtl"] .nf-radio-option span{margin-left:0;margin-right:8px;}';
        html += '.nf-shell[dir="rtl"] .nf-captcha,.nf-shell[dir="rtl"] .nf-actions,.nf-shell[dir="rtl"] .nf-repeat__actions{direction:rtl;justify-content:flex-start;}';
        html += '.nf-shell[dir="rtl"] input.nf-control--ltr,.nf-shell[dir="rtl"] textarea.nf-control--ltr,.nf-shell[dir="rtl"] select.nf-control--ltr{direction:ltr;text-align:left;}';
        html += '.nf-shell[dir="rtl"] .nf-field--left input:not(.nf-control--ltr),.nf-shell[dir="rtl"] .nf-field--left textarea:not(.nf-control--ltr),.nf-shell[dir="rtl"] .nf-field--left select:not(.nf-control--ltr),.nf-shell[dir="rtl"] .nf-field--right input:not(.nf-control--ltr),.nf-shell[dir="rtl"] .nf-field--right textarea:not(.nf-control--ltr),.nf-shell[dir="rtl"] .nf-field--right select:not(.nf-control--ltr),.nf-shell[dir="rtl"] .nf-field--above input:not(.nf-control--ltr),.nf-shell[dir="rtl"] .nf-field--above textarea:not(.nf-control--ltr),.nf-shell[dir="rtl"] .nf-field--above select:not(.nf-control--ltr){text-align:right;padding-right:18px;padding-left:14px;}';
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
        html += '.nf-shell[dir="rtl"] .nf-section__top{left:auto;right:0.85rem;}';
        html += '.nf-shell[dir="rtl"] .nf-field--left label,.nf-shell[dir="rtl"] .nf-field--right label{text-align:right;}';
        html += '}';
        if (String.isNotBlank(versionRecord.Custom_CSS__c)) {
            html += versionRecord.Custom_CSS__c;
        }
        html += '</style></head><body>';
        html += '<div class="nf-shell" dir="' + (rtlEnabled ? 'rtl' : 'ltr') + '"><div class="nf-runtime" data-nativeforms-runtime>';
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

        if (secretCodeEnabled) {
            html += renderSecretCodeVerificationBlock(secretCodeConfig);
            html += '<div class="nf-secret-gated" data-secret-gated hidden>';
        }

        for (NF_Form_Element__c elementRecord : topLevelElements) {
            html += renderElement(elementRecord, childrenByParent, rtlEnabled, languageCode);
        }

        if (captchaEnabled) {
            html += '<div class="nf-captcha"><div class="g-recaptcha" data-sitekey="' + escapeHtml(captchaSiteKey) + '"></div></div>';
        }
        html += '<div class="nf-actions"' + submitButtonWrapperAttrs + '><button type="submit">' + escapeHtml(submitLabel) + '</button></div>';
        if (secretCodeEnabled) {
            html += '</div>';
        }
        html += '<div class="nf-status" data-nativeforms-status></div>';
        html += '</form><div class="nf-result" data-nativeforms-result hidden></div></div></div>';
        if (captchaEnabled) {
            html += '<script src="https://www.google.com/recaptcha/api.js" async defer></script>';
        }
        Map<String, Object> publicCaptchaConfig = captchaEnabled
            ? new Map<String, Object>{
                'enabled' => true,
                'provider' => stringValue(captchaConfig.get('provider')),
                'siteKey' => captchaSiteKey
            }
            : new Map<String, Object>{
                'enabled' => false,
                'provider' => stringValue(captchaConfig.get('provider'))
            };
        Map<String, Object> publishedUiSettings = new Map<String, Object>(uiSettings);
        publishedUiSettings.put('submitLabel', submitLabel);
        publishedUiSettings.put('submitSuccessMessage', submitSuccessMessage);
        publishedUiSettings.put('postSubmitButtonLabel', postSubmitButtonLabel);
        String publishedCustomJs = NativeFormsFeatureFlags.isProCustomJsEnabled()
            ? versionRecord.Custom_JS__c
            : null;
        html += '<script>window.NativeFormsConfig=' + JSON.serialize(new Map<String, Object>{
            'versionId' => (String) versionRecord.Id,
            'formId' => formId,
            'publishToken' => publishToken,
            'languageCode' => languageCode,
            'runtimeText' => runtimeText,
            'prefillUrl' => TEMP_PREFILL_URL,
            'submitUrl' => TEMP_SUBMIT_URL,
            'uploadInitUrl' => TEMP_UPLOAD_INIT_URL,
            'captcha' => publicCaptchaConfig,
            'secretCode' => secretCodeConfig,
            'theme' => theme,
            'uiSettings' => publishedUiSettings
        }) + ';</script>';
        html += '<script>' + NativeFormsFormulaExprEval.browserBundle() + ';(function(){';
        html += 'const config=window.NativeFormsConfig||{};';
        html += 'const form=document.querySelector("form[data-nativeforms-version]");';
        html += 'const shellEl=document.querySelector(".nf-shell");';
        html += 'const runtimeEl=document.querySelector("[data-nativeforms-runtime]");';
        html += 'const resultEl=document.querySelector("[data-nativeforms-result]");';
        html += 'const statusEl=document.querySelector("[data-nativeforms-status]");';
        html += 'if(!form||!config.submitUrl||!runtimeEl||!resultEl){return;}';
        html += 'const twinaFormsHandlers={};';
        html += 'const manualVisibilityState={};';
        html += 'function emitTwinaFormsEvent(name,detail){const payload=detail&&typeof detail==="object"?detail:{};const handlers=(twinaFormsHandlers[name]||[]).slice();handlers.forEach(function(handler){try{handler(payload);}catch(error){console.error("TwinaForms event handler error",name,error);}});try{window.dispatchEvent(new CustomEvent("twinaforms:"+name,{detail:payload}));}catch(error){}}';
        html += 'const runtimeText=(config.runtimeText&&typeof config.runtimeText==="object")?config.runtimeText:{};';
        html += 'function t(key,fallback){const value=runtimeText[key];return typeof value==="string"&&value!==""?value:fallback;}';
        html += 'function interpolate(template,replacements){let output=String(template==null?"":template);const values=replacements||{};Object.keys(values).forEach(function(key){output=output.replace(new RegExp("\\\\{"+key+"\\\\}","g"),String(values[key]));});return output;}';
        html += 'const FORMULA_SOURCE_REGEX=/\\{([A-Za-z0-9_]+)\\}/g;';
        html += 'function formulaFieldControls(){return Array.from(form.querySelectorAll("[data-formula-target=\'true\']"));}';
        html += 'function formulaSafeVarName(fieldKey){return "field_"+String(fieldKey||"").replace(/[^A-Za-z0-9_]/g,"_");}';
        html += 'function normalizeFormulaExpression(expression){return String(expression||"").replace(/\\bAND\\b/g,"and").replace(/\\bOR\\b/g,"or").replace(/\\bTRUE\\b/g,"true").replace(/\\bFALSE\\b/g,"false").trim();}';
        html += 'function formulaIsBlank(value){return value===null||value===undefined||String(value)==="";}';
        html += 'function formulaToText(value){return formulaIsBlank(value)?"":String(value);}';
        html += 'function formulaToNumber(value){if(value===null||value===undefined||value===""){return null;}const parsed=Number(value);return Number.isFinite(parsed)?parsed:null;}';
        html += 'function formulaNormalizeComparable(value){if(typeof value==="string"){const trimmed=value.trim().toLowerCase();if(trimmed==="true"){return true;}if(trimmed==="false"){return false;}}return value;}';
        html += 'function formulaPad2(value){return String(value).padStart(2,"0");}';
        html += 'function formulaIsoLocalDate(dateValue){return dateValue.getFullYear()+"-"+formulaPad2(dateValue.getMonth()+1)+"-"+formulaPad2(dateValue.getDate());}';
        html += 'function formulaIsoLocalDateTime(dateValue){return formulaIsoLocalDate(dateValue)+"T"+formulaPad2(dateValue.getHours())+":"+formulaPad2(dateValue.getMinutes())+":"+formulaPad2(dateValue.getSeconds());}';
        html += 'function formulaParseIsoDateLike(rawValue){const value=String(rawValue||"").trim();if(!value){return null;}const parsed=new Date(value);return Number.isNaN(parsed.getTime())?null:parsed;}';
        html += 'function createFormulaParser(){if(!(window.exprEval&&window.exprEval.Parser)){return null;}const parser=new window.exprEval.Parser({operators:{add:true,subtract:true,multiply:true,divide:true,remainder:false,power:false,factorial:false,comparison:true,logical:true,conditional:true,concatenate:false,assignment:false,array:false,fndef:false,in:false},allowMemberAccess:false});parser.unaryOps={"-":function(value){return-Number(value);},"+":Number,not:function(value){return!value;}};parser.binaryOps={"+":function(left,right){return Number(left)+Number(right);},"-":function(left,right){return Number(left)-Number(right);},"*":function(left,right){return Number(left)*Number(right);},"/":function(left,right){return Number(left)/Number(right);},"==":function(left,right){return formulaNormalizeComparable(left)===formulaNormalizeComparable(right);},"!=":function(left,right){return formulaNormalizeComparable(left)!==formulaNormalizeComparable(right);},">":function(left,right){return left>right;},"<":function(left,right){return left<right;},">=":function(left,right){return left>=right;},"<=":function(left,right){return left<=right;},and:function(left,right){return Boolean(left&&right);},or:function(left,right){return Boolean(left||right);}};parser.ternaryOps={"?":function(conditionValue,trueValue,falseValue){return conditionValue?trueValue:falseValue;}};parser.functions={CONCAT:function(){return Array.prototype.slice.call(arguments).map(formulaToText).join("");},IF:function(conditionValue,trueValue,falseValue){return conditionValue?trueValue:falseValue;},COALESCE:function(){for(let index=0;index<arguments.length;index+=1){if(!formulaIsBlank(arguments[index])){return arguments[index];}}return null;},ISBLANK:function(value){return formulaIsBlank(value);},VALUE:function(value){return formulaToNumber(value);},TEXT:function(value){return formulaToText(value);},ROUND:function(value,digits){const numericValue=formulaToNumber(value);const numericDigits=Number.isFinite(Number(digits))?Number(digits):0;if(numericValue===null){return null;}const factor=Math.pow(10,numericDigits);return Math.round(numericValue*factor)/factor;},ABS:function(value){const numericValue=formulaToNumber(value);return numericValue===null?null:Math.abs(numericValue);},MIN:function(){const values=Array.prototype.slice.call(arguments).map(formulaToNumber).filter(function(item){return item!==null;});return values.length?Math.min.apply(Math,values):null;},MAX:function(){const values=Array.prototype.slice.call(arguments).map(formulaToNumber).filter(function(item){return item!==null;});return values.length?Math.max.apply(Math,values):null;},TODAY:function(){return formulaIsoLocalDate(new Date());},NOW:function(){return formulaIsoLocalDateTime(new Date());},YEAR:function(value){const parsed=formulaParseIsoDateLike(value);return parsed?parsed.getFullYear():null;},MONTH:function(value){const parsed=formulaParseIsoDateLike(value);return parsed?parsed.getMonth()+1:null;},DAY:function(value){const parsed=formulaParseIsoDateLike(value);return parsed?parsed.getDate():null;}};parser.consts={true:true,false:false};return parser;}';
        html += 'const formulaParser=createFormulaParser();';
        html += 'function formulaFieldKeySet(){return new Set(formulaFieldControls().map(function(control){return String(control.name||control.dataset.formulaFieldKey||"");}).filter(function(value){return !!value;}));}';
        html += 'function readRuntimeFieldValue(fieldKey){const fields=form.querySelectorAll("[name=\'"+fieldKey+"\']");if(!fields.length){return "";}const first=fields[0];if(first.type==="checkbox"){return !!first.checked;}if(first.type==="radio"){const checked=form.querySelector("[name=\'"+fieldKey+"\']:checked");return checked?checked.value:"";}if(first.dataset.nativeformsDate==="true"){const parsed=parseDateValue(first.value||"",first.dataset.dateFormat||"us");return parsed?parsed.iso:(first.value||"");}if(first.dataset.nativeformsTime==="true"){const parsed=parseTimeValue(first.value||"",first.dataset.timeFormat||"24h");return parsed||String(first.value||"");}return first.value||"";}';
        html += 'function normalizeFormulaResult(targetType,value){if(targetType==="number"){return formulaToNumber(value);}if(value===null||value===undefined){return "";}return String(value);}';
        html += 'function evaluateFormulaControl(control){if(!control||!formulaParser){return;}const expression=normalizeFormulaExpression(control.dataset.formulaExpression||"");if(!expression){control.value="";return;}const variableMap={};let normalizedExpression=expression.replace(FORMULA_SOURCE_REGEX,function(_,fieldKey){const safeName=formulaSafeVarName(fieldKey);variableMap[fieldKey]=safeName;return safeName;});const parserValues={};Object.keys(variableMap).forEach(function(fieldKey){parserValues[variableMap[fieldKey]]=readRuntimeFieldValue(fieldKey);});try{const compiled=formulaParser.parse(normalizedExpression);const rawValue=compiled.evaluate(parserValues);const normalizedValue=normalizeFormulaResult(control.dataset.formulaType||"text",rawValue);control.value=normalizedValue===null||normalizedValue===undefined?"":String(normalizedValue);}catch(error){control.value="";}}';
        html += 'function evaluateAllFormulaFields(){formulaFieldControls().forEach(function(control){evaluateFormulaControl(control);});}';
        html += 'const captchaConfig=config.captcha||{};';
        html += 'const captchaEnabled=!!captchaConfig.enabled;';
        html += 'const defaultSubmitLabel=(form.querySelector("button[type=\'submit\']")||{}).textContent||"Submit";';
        html += 'const submitSuccessMessage=((config.uiSettings&&config.uiSettings.submitSuccessMessage)||"Your form was submitted successfully.");';
        html += 'const secretCodeConfig=config.secretCode||{};';
        html += 'const secretCodeEnabled=!!secretCodeConfig.enabled;';
        html += 'const postSubmitAutoLinkEnabled=!!(config.uiSettings&&config.uiSettings.postSubmitAutoLinkEnabled);';
        html += 'const postSubmitUrlTemplate=String((config.uiSettings&&config.uiSettings.postSubmitUrlTemplate)||"").trim();';
        html += 'const postSubmitButtonLabel=String((config.uiSettings&&config.uiSettings.postSubmitButtonLabel)||"' + escapeJsString(postSubmitButtonLabel) + '").trim()||"' + escapeJsString(postSubmitButtonLabel) + '";';
        html += 'const postSubmitDelaySeconds=Math.max(0,parseInt((config.uiSettings&&config.uiSettings.postSubmitDelaySeconds)!=null?config.uiSettings.postSubmitDelaySeconds:3,10)||0);';
        html += 'let postSubmitRedirectTimer=null;let postSubmitRedirectCountdownTimer=null;let activePostSubmitRedirectUrl="";';
        html += 'const secretVerifyEl=document.querySelector("[data-secret-verification]");';
        html += 'const secretGatedEl=document.querySelector("[data-secret-gated]");';
        html += 'let secretVerificationToken="";let secretVerificationApproved=!secretCodeEnabled;let secretVerifiedEmail="";let secretVerificationSessionId=(window.crypto&&window.crypto.randomUUID)?window.crypto.randomUUID():("nf-"+Math.random().toString(36).slice(2)+"-"+Date.now());';
        html += 'let fileUploadSessionId=(window.crypto&&window.crypto.randomUUID)?window.crypto.randomUUID():("nf-upload-"+Math.random().toString(36).slice(2)+"-"+Date.now());const uploadedFilesByField={};const fileUploadStateByField={};';
        html += 'function setStatus(kind,message){if(!statusEl){return;}statusEl.className="nf-status nf-status--"+kind;statusEl.textContent=message||"";}';
        html += 'function clearStatus(){if(!statusEl){return;}statusEl.className="nf-status";statusEl.textContent="";}';
        html += 'function escapeHtml(value){return String(value==null?"":value).replace(/[&<>"\']/g,function(ch){return({"&":"&amp;","<":"&lt;",">":"&gt;","\\"":"&quot;","\'":"&#39;"})[ch]||ch;});}';
        html += 'function fileUploadControls(){return Array.from(form.querySelectorAll("input[data-nativeforms-file=\'true\']"));}';
        html += 'function fileUploadFieldKey(control){return control&&control.name?String(control.name):"";}';
        html += 'function fileUploadElements(control){const fieldWrap=control?control.closest(".nf-field"):null;return{feedback:fieldWrap?fieldWrap.querySelector("[data-file-upload-feedback]"):null,list:fieldWrap?fieldWrap.querySelector("[data-file-upload-list]"):null};}';
        html += 'function renderFileUploadState(control){if(!control){return;}const fieldKey=fileUploadFieldKey(control);const refs=uploadedFilesByField[fieldKey]||[];const state=fileUploadStateByField[fieldKey]||{};const targets=fileUploadElements(control);if(targets.feedback){const message=state.error||state.message||"";targets.feedback.textContent=message;targets.feedback.style.color=state.error?"#b42318":"";}if(targets.list){if(!refs.length){targets.list.innerHTML="";return;}const items=refs.map(function(item){return \'<div class="nf-upload__file"><span class="nf-upload__file-name">\'+escapeHtml(item.fileName||t("fileUploadedFallbackName","Uploaded file"))+\'</span><span class="nf-upload__file-status">\'+escapeHtml(t("fileReady","Ready"))+\'</span></div>\';}).join("");const clearLabel=refs.length===1?t("fileRemoveSingle","Remove file"):t("fileRemoveMultiple","Remove files");const clearButton=\'<button type="button" data-file-upload-clear="\'+escapeHtml(fieldKey)+\'">\'+escapeHtml(clearLabel)+\'</button>\';targets.list.innerHTML=items+clearButton;}}';
        html += 'function clearFileUploadField(fieldKey){uploadedFilesByField[fieldKey]=[];fileUploadStateByField[fieldKey]={message:"",error:""};const control=fileUploadControls().find(function(item){return fileUploadFieldKey(item)===fieldKey;});if(control){control.value="";renderFileUploadState(control);}}';
        html += 'async function uploadSelectedFiles(control){const fieldKey=fileUploadFieldKey(control);const files=Array.from((control&&control.files)||[]);if(!fieldKey){return;}if(!files.length){clearFileUploadField(fieldKey);return;}if(!config.uploadInitUrl){throw new Error(t("fileUploadsConfigMissing","File Uploads are not configured for this published form."));}uploadedFilesByField[fieldKey]=[];fileUploadStateByField[fieldKey]={uploading:true,message:t("fileUploading","Uploading files..."),error:""};renderFileUploadState(control);try{const uploaded=[];for(let index=0;index<files.length;index+=1){const file=files[index];const initResponse=await fetch(config.uploadInitUrl,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({formId:config.formId,publishToken:config.publishToken,fieldKey:fieldKey,fileName:file.name,contentType:file.type||"application/octet-stream",fileSize:file.size,sessionId:fileUploadSessionId})});const initData=await initResponse.json();if(!initResponse.ok||initData.success===false){throw new Error(initData.error||t("fileUploadFailed","We could not upload this file. Please try again."));}const uploadResponse=await fetch(initData.uploadUrl,{method:"PUT",headers:{"Content-Type":initData.contentType||file.type||"application/octet-stream"},body:file});if(!uploadResponse.ok){throw new Error(t("fileUploadFailed","We could not upload this file. Please try again."));}uploaded.push({uploadToken:initData.uploadToken,fileName:initData.fileName||file.name,contentType:initData.contentType||file.type||"application/octet-stream",fileSize:initData.fileSize||file.size});}uploadedFilesByField[fieldKey]=uploaded;fileUploadStateByField[fieldKey]={uploading:false,message:uploaded.length?interpolate(t("fileReadyCount","{count} file(s) ready."),{count:String(uploaded.length)}):"",error:""};renderFileUploadState(control);}catch(error){uploadedFilesByField[fieldKey]=[];fileUploadStateByField[fieldKey]={uploading:false,message:"",error:error&&error.message?error.message:t("fileUploadFailed","We could not upload this file. Please try again.")};renderFileUploadState(control);throw error;}}';
        html += 'function validateUploadedFiles(){const controls=fileUploadControls();for(let index=0;index<controls.length;index+=1){const control=controls[index];const fieldKey=fileUploadFieldKey(control);const state=fileUploadStateByField[fieldKey]||{};const refs=uploadedFilesByField[fieldKey]||[];if(state.uploading){return{valid:false,message:t("fileUploadPleaseWait","Please wait for file uploads to finish.")};}if(control.required&&refs.length===0){return{valid:false,message:t("fileUploadRequired","Please upload the required file before submitting.")};}}return{valid:true,message:""};}';
        html += 'function clearAllUploadedFiles(){fileUploadControls().forEach(function(control){clearFileUploadField(fileUploadFieldKey(control));});}';
        html += 'function setSecretVerificationMessage(message,kind){if(!secretVerifyEl){return;}const target=secretVerifyEl.querySelector("[data-secret-message]");if(!target){return;}target.className="nf-secret-verify__message"+(kind==="success"?" nf-secret-verify__message--success":kind==="error"?" nf-secret-verify__message--error":"");target.textContent=message||"";}';
        html += 'function setSecretGatedState(unlocked){if(secretGatedEl){secretGatedEl.hidden=!unlocked;secretGatedEl.querySelectorAll("input,textarea,select,button").forEach(function(control){control.disabled=!unlocked;});}secretVerificationApproved=!!unlocked;}';
        html += 'function setSecretCodeStepVisible(visible){if(!secretVerifyEl){return;}const codeStep=secretVerifyEl.querySelector("[data-secret-code-step]");const resendWrap=secretVerifyEl.querySelector("[data-secret-resend-wrap]");if(codeStep){codeStep.hidden=!visible;}if(resendWrap){resendWrap.hidden=!visible;}}';
        html += 'function setSecretVerificationSectionVisible(visible){if(secretVerifyEl){secretVerifyEl.hidden=!visible;secretVerifyEl.style.display=visible?"":"none";}}';
        html += 'function readSecretVerificationEmail(){const input=secretVerifyEl?secretVerifyEl.querySelector("[data-secret-email]"):null;return input?String(input.value||"").trim().toLowerCase():"";}';
        html += 'function readSecretVerificationCode(){const input=secretVerifyEl?secretVerifyEl.querySelector("[data-secret-code]"):null;return input?String(input.value||"").trim():"";}';
        html += 'async function runPrefillWithParams(params){if(!config.prefillUrl||!params||Object.keys(params).length===0){return;}emitTwinaFormsEvent("prefill:before",{params:params});const response=await fetch(config.prefillUrl,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({publishToken:config.publishToken,request:{formId:config.formId,params:params}})});const data=await response.json();if(!response.ok||data.success===false){const errorMessage=(data.error&&data.error.message)||data.error||"Prefill failed";emitTwinaFormsEvent("prefill:error",{params:params,message:errorMessage,response:data});throw new Error(errorMessage);}applyPrefillPayload(data);emitTwinaFormsEvent("prefill:after",{params:params,payload:data});}';
        html += 'async function sendSecretCodeRequest(action,payload){const response=await fetch(config.submitUrl,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(Object.assign({action:action,formId:config.formId,publishToken:config.publishToken,publishedVersionId:config.versionId},payload||{}))});const data=await response.json();if(!response.ok||data.success===false){throw new Error((data.error&&data.error.message)||data.error||"Secret code request failed");}return data;}';
        html += 'function clearPostSubmitRedirect(){if(postSubmitRedirectTimer){window.clearTimeout(postSubmitRedirectTimer);postSubmitRedirectTimer=null;}if(postSubmitRedirectCountdownTimer){window.clearInterval(postSubmitRedirectCountdownTimer);postSubmitRedirectCountdownTimer=null;}activePostSubmitRedirectUrl="";}';
        html += 'function clearResult(){if(!resultEl){return;}clearPostSubmitRedirect();resultEl.hidden=true;resultEl.innerHTML="";form.hidden=false;form.style.display="";if(shellEl){shellEl.classList.remove("nf-shell--result-only");}}';
        html += 'function setSubmitting(isSubmitting){const submitButton=form.querySelector("button[type=\'submit\']");if(!submitButton){return;}submitButton.disabled=!!isSubmitting;submitButton.textContent=isSubmitting?t("submitting","Submitting..."):defaultSubmitLabel;}';
        html += 'function failureBucket(errorPayload){const message=String((errorPayload&&errorPayload.message)||errorPayload||"").toLowerCase();const commandType=String((errorPayload&&errorPayload.commandType)||"").toLowerCase();const isConfigIssue=message.includes("mapping")||message.includes("definition")||message.includes("not allowed")||message.includes("not configured")||message.includes("missing required field")||message.includes("invalid publish token")||message.includes("form is not published")||message.includes("prefill policy")||message.includes("submit policy")||message.includes("unauthorized");const isSalesforceIssue=message.includes("create failed")||message.includes("update failed")||message.includes("delete failed")||message.includes("query failed")||message.includes("describe failed")||message.includes("status:")||["create","update","delete","findone","findmany","getbyid"].includes(commandType);if(isSalesforceIssue&&!isConfigIssue){return{label:"Salesforce rejected the request",detail:"Salesforce could not accept this submission. Check required fields, validation rules, or object permissions."};}return{label:"Form logic/configuration issue",detail:"This submit could not complete because of a form or runtime configuration issue."};}';
        html += 'function readPathValue(source,path){if(!source||!path){return source;}return String(path).split(".").reduce(function(current,segment){if(current==null){return undefined;}return current[segment];},source);}';
        html += 'function isAbsoluteHttpUrl(value){try{const parsed=new URL(value);return parsed.protocol==="http:"||parsed.protocol==="https:";}catch(error){return false;}}';
        html += 'function resolvePostSubmitUrl(template,fieldValues,prefillPayload){const sourceTemplate=String(template||"").trim();if(!sourceTemplate){return "";}const aliases=(prefillPayload&&prefillPayload.aliases&&typeof prefillPayload.aliases==="object")?prefillPayload.aliases:{};const resolved=sourceTemplate.replace(/\\{\\{\\s*(field|prefill)\\.([^}]+?)\\s*\\}\\}/g,function(_,kind,path){let rawValue="";if(kind==="field"){rawValue=fieldValues&&Object.prototype.hasOwnProperty.call(fieldValues,path)?fieldValues[path]:"";}else{const pieces=String(path||"").split(".");const aliasName=pieces.shift();rawValue=readPathValue(aliases[aliasName],pieces.join("."));}if(rawValue===undefined||rawValue===null){return "";}if(typeof rawValue==="object"){try{return encodeURIComponent(JSON.stringify(rawValue));}catch(error){return "";}}return encodeURIComponent(String(rawValue));});return isAbsoluteHttpUrl(resolved)?resolved:"";}';
        html += 'function startPostSubmitRedirect(url,delaySeconds){clearPostSubmitRedirect();activePostSubmitRedirectUrl=url||"";if(!activePostSubmitRedirectUrl){return;}const continueButton=resultEl.querySelector("[data-post-submit-continue]");if(continueButton){continueButton.addEventListener("click",function(){if(activePostSubmitRedirectUrl){window.location.assign(activePostSubmitRedirectUrl);}});}const countdownEl=resultEl.querySelector("[data-post-submit-countdown]");let remaining=Math.max(0,Number(delaySeconds)||0);if(countdownEl){countdownEl.textContent=String(remaining);}if(remaining<=0){window.location.assign(activePostSubmitRedirectUrl);return;}postSubmitRedirectTimer=window.setTimeout(function(){if(activePostSubmitRedirectUrl){window.location.assign(activePostSubmitRedirectUrl);}},remaining*1000);if(countdownEl){postSubmitRedirectCountdownTimer=window.setInterval(function(){remaining=Math.max(remaining-1,0);countdownEl.textContent=String(remaining);if(remaining<=0&&postSubmitRedirectCountdownTimer){window.clearInterval(postSubmitRedirectCountdownTimer);postSubmitRedirectCountdownTimer=null;}},1000);}}';
        html += 'function renderResult(kind,options){if(!resultEl){return;}const opts=options||{};clearPostSubmitRedirect();if(kind==="success"){const hasRedirect=!!opts.redirectUrl;const countdownLabel=interpolate(t("postSubmitContinuingIn","Continuing in {seconds} seconds..."),{seconds:String(Math.max(0,Number(opts.redirectDelaySeconds)||0))});const countdownText=hasRedirect?\'<p class="nf-result__meta">\'+escapeHtml(countdownLabel).replace(escapeHtml(String(Math.max(0,Number(opts.redirectDelaySeconds)||0))),\'<span data-post-submit-countdown>\'+escapeHtml(String(Math.max(0,Number(opts.redirectDelaySeconds)||0)))+\'</span>\')+\'</p>\':"";const actionText=hasRedirect?\'<div class="nf-result__actions"><button type="button" data-post-submit-continue>\'+escapeHtml(opts.redirectButtonLabel||postSubmitButtonLabel)+\'</button></div>\':"";resultEl.innerHTML=\'<div class="nf-result__panel nf-result__panel--success"><h2 class="nf-result__title">\'+escapeHtml(t("submitSuccessTitle","Submitted successfully"))+\'</h2><p class="nf-result__message">\'+escapeHtml(opts.message||submitSuccessMessage)+\'</p>\'+countdownText+actionText+\'</div>\';form.hidden=true;form.style.display="none";if(shellEl){shellEl.classList.add("nf-shell--result-only");}if(hasRedirect){startPostSubmitRedirect(opts.redirectUrl,opts.redirectDelaySeconds);}}else if(kind==="error"){const bucket=opts.bucket||failureBucket(opts.errorPayload);const detailsText=opts.detailsText?\'<details class="nf-result__details"><summary>Technical details</summary><pre>\'+escapeHtml(opts.detailsText)+\'</pre></details>\':"";resultEl.innerHTML=\'<div class="nf-result__panel nf-result__panel--error"><h2 class="nf-result__title">\'+escapeHtml(t("submitErrorTitle","Submit failed"))+\'</h2><p class="nf-result__message">\'+escapeHtml(bucket.detail)+\'</p><p class="nf-result__subtitle">\'+escapeHtml(bucket.label)+\'</p>\'+detailsText+\'</div>\';form.hidden=false;form.style.display="";if(shellEl){shellEl.classList.remove("nf-shell--result-only");}}resultEl.hidden=false;}';
        html += 'function getCaptchaToken(){const responseField=form.querySelector("textarea[name=\'g-recaptcha-response\'],input[name=\'g-recaptcha-response\']");return responseField?responseField.value||"":"";}';
        html += 'function resetCaptcha(){const responseField=form.querySelector("textarea[name=\'g-recaptcha-response\'],input[name=\'g-recaptcha-response\']");if(responseField){responseField.value="";}if(window.grecaptcha&&typeof window.grecaptcha.reset==="function"){try{window.grecaptcha.reset();}catch(e){}}}';
        html += 'function dateFormatHint(format){return format==="eu"?"DD/MM/YYYY":"MM/DD/YYYY";}';
        html += 'function isValidDateParts(year,month,day){const test=new Date(Date.UTC(year,month-1,day));return test.getUTCFullYear()===year&&test.getUTCMonth()+1===month&&test.getUTCDate()===day;}';
        html += 'function parseDateValue(value,format){const raw=String(value||"").trim();if(!raw){return null;}let match=raw.match(/^(\\d{4})-(\\d{2})-(\\d{2})$/);if(match){const year=Number(match[1]);const month=Number(match[2]);const day=Number(match[3]);if(!isValidDateParts(year,month,day)){return null;}return{year:year,month:month,day:day,iso:match[1]+"-"+match[2]+"-"+match[3]};}const normalized=raw.replace(/[.\\-]/g,"/");match=normalized.match(/^(\\d{1,2})\\/(\\d{1,2})\\/(\\d{4})$/);if(!match){return null;}const first=Number(match[1]);const second=Number(match[2]);const year=Number(match[3]);const month=format==="eu"?second:first;const day=format==="eu"?first:second;if(!isValidDateParts(year,month,day)){return null;}const monthText=String(month).padStart(2,"0");const dayText=String(day).padStart(2,"0");return{year:year,month:month,day:day,iso:String(year).padStart(4,"0")+"-"+monthText+"-"+dayText};}';
        html += 'function formatParsedDate(parsed,format){if(!parsed){return "";}const day=String(parsed.day).padStart(2,"0");const month=String(parsed.month).padStart(2,"0");const year=String(parsed.year).padStart(4,"0");return format==="eu"?day+"/"+month+"/"+year:month+"/"+day+"/"+year;}';
        html += 'function formatDateForField(value,field){const format=field&&field.dataset&&field.dataset.dateFormat?field.dataset.dateFormat:"us";const parsed=parseDateValue(value,format)||parseDateValue(value,"us")||parseDateValue(value,"eu");return parsed?formatParsedDate(parsed,format):value==null?"":String(value);}';
        html += 'function validateDateField(el,showMessage){if(!el||el.dataset.nativeformsDate!=="true"){return true;}const format=el.dataset.dateFormat||"us";const raw=String(el.value||"").trim();if(!raw){el.setCustomValidity("");if(showMessage&&typeof el.reportValidity==="function"){el.reportValidity();}return true;}const parsed=parseDateValue(raw,format);if(!parsed){el.setCustomValidity(interpolate(t("dateInvalid","Please enter a valid date in {format} format."),{format:dateFormatHint(format)}));if(showMessage&&typeof el.reportValidity==="function"){el.reportValidity();}return false;}const minDate=el.dataset.effectiveMinDate||"";const maxDate=el.dataset.effectiveMaxDate||"";if(minDate&&parsed.iso<minDate){el.setCustomValidity(interpolate(t("dateMin","Please enter a date on or after {date}."),{date:formatDateForField(minDate,el)}));if(showMessage&&typeof el.reportValidity==="function"){el.reportValidity();}return false;}if(maxDate&&parsed.iso>maxDate){el.setCustomValidity(interpolate(t("dateMax","Please enter a date on or before {date}."),{date:formatDateForField(maxDate,el)}));if(showMessage&&typeof el.reportValidity==="function"){el.reportValidity();}return false;}el.setCustomValidity("");if(showMessage&&typeof el.reportValidity==="function"){el.reportValidity();}return true;}';
        html += 'function timeFormatHint(format){return format==="12h"?"h:mm AM/PM":"HH:mm";}';
        html += 'function parseTimeValue(value,format){const raw=String(value||"").trim();if(!raw){return null;}let match;if(format==="12h"){match=raw.match(/^(\\d{1,2}):(\\d{2})\\s*([AaPp][Mm])$/);if(!match){return null;}let hours=Number(match[1]);const minutes=Number(match[2]);if(!Number.isInteger(hours)||!Number.isInteger(minutes)||hours<1||hours>12||minutes<0||minutes>59){return null;}const meridiem=match[3].toUpperCase();if(meridiem==="AM"&&hours===12){hours=0;}else if(meridiem==="PM"&&hours<12){hours+=12;}return String(hours).padStart(2,"0")+":"+String(minutes).padStart(2,"0");}match=raw.match(/^(\\d{1,2}):(\\d{2})$/);if(!match){return null;}const hours=Number(match[1]);const minutes=Number(match[2]);if(!Number.isInteger(hours)||!Number.isInteger(minutes)||hours<0||hours>23||minutes<0||minutes>59){return null;}return String(hours).padStart(2,"0")+":"+String(minutes).padStart(2,"0");}';
        html += 'function formatTimeForField(value,field){const format=field&&field.dataset&&field.dataset.timeFormat?field.dataset.timeFormat:"24h";const parsed=parseTimeValue(value,"24h")||parseTimeValue(value,"12h");if(!parsed){return value==null?"":String(value);}if(format!=="12h"){return parsed;}const parts=parsed.split(":");const hour24=Number(parts[0]);const meridiem=hour24>=12?"PM":"AM";const hour12=hour24%12||12;return String(hour12)+":"+parts[1]+" "+meridiem;}';
        html += 'function validateTimeField(el,showMessage){if(!el||el.dataset.nativeformsTime!=="true"){return true;}const format=el.dataset.timeFormat||"24h";const raw=String(el.value||"").trim();if(!raw){el.setCustomValidity("");if(showMessage&&typeof el.reportValidity==="function"){el.reportValidity();}return true;}const parsed=parseTimeValue(raw,format);if(!parsed){el.setCustomValidity(interpolate(t("timeInvalid","Please enter a valid time in {format} format."),{format:timeFormatHint(format)}));if(showMessage&&typeof el.reportValidity==="function"){el.reportValidity();}return false;}el.setCustomValidity("");if(showMessage&&typeof el.reportValidity==="function"){el.reportValidity();}return true;}';
        html += 'function readFieldValue(fieldKey){const fields=form.querySelectorAll("[name=\'"+fieldKey+"\']");if(!fields.length){return "";}const first=fields[0];if(first.type==="checkbox"){return !!first.checked;}if(first.type==="radio"){const checked=form.querySelector("[name=\'"+fieldKey+"\']:checked");return checked?checked.value:"";}return first.value||"";}';
        html += 'function evaluateSingleCondition(condition){if(!condition||!condition.fieldKey||!condition.operator){return true;}const actual=readFieldValue(condition.fieldKey);const compare=condition.value||"";if(condition.operator==="equals"){return String(actual)===compare;}if(condition.operator==="notEquals"){return String(actual)!==compare;}if(condition.operator==="isTrue"){return actual===true||String(actual).toLowerCase()==="true";}if(condition.operator==="isFalse"){return actual===false||String(actual).toLowerCase()==="false"||String(actual)==="";}if(condition.operator==="isBlank"){return String(actual)==="";}if(condition.operator==="isNotBlank"){return String(actual)!=="";}return true;}';
        html += 'function evaluateConditionExpression(results,expression){if(!results.length){return true;}if(results.length===1){return results[0];}const normalized=((expression||"").trim()||results.map(function(_,index){return String(index+1);}).join(" AND ")).replace(/\\(/g," ( ").replace(/\\)/g," ) ").replace(/\\s+/g," ").trim();const tokens=normalized?normalized.split(" "):[];const values=[];const operators=[];function applyOperator(){if(values.length<2||!operators.length){return;}const operator=operators.pop();const right=values.pop();const left=values.pop();values.push(operator==="AND"?(left&&right):(left||right));}function precedence(operator){return operator==="AND"?2:1;}for(let index=0;index<tokens.length;index+=1){const token=tokens[index];if(!token){continue;}if(token==="("){operators.push(token);continue;}if(token===")"){while(operators.length&&operators[operators.length-1]!=="("){applyOperator();}if(operators.length&&operators[operators.length-1]==="("){operators.pop();}continue;}if(token==="AND"||token==="OR"){while(operators.length&&operators[operators.length-1]!=="("&&precedence(operators[operators.length-1])>=precedence(token)){applyOperator();}operators.push(token);continue;}if(/^\\d+$/.test(token)){const refIndex=Number(token)-1;values.push(refIndex>=0&&refIndex<results.length?results[refIndex]:false);}}while(operators.length){applyOperator();}return values.length?!!values[0]:false;}';
        html += 'function evaluateElementConditions(el){let conditions=[];try{conditions=JSON.parse(el.dataset.conditions||"[]")||[];}catch(error){conditions=[];}if(!conditions.length&&el.dataset.conditionSource){conditions=[{fieldKey:el.dataset.conditionSource,operator:el.dataset.conditionOperator,value:el.dataset.conditionValue||""}];}if(!conditions.length){return true;}const results=conditions.map(function(condition){return evaluateSingleCondition(condition);});return evaluateConditionExpression(results,el.dataset.conditionExpression||"");}';
        html += 'function setFieldValue(fieldKey,value){if(formulaFieldKeySet().has(String(fieldKey||""))){return;}const fields=form.querySelectorAll("[name=\'"+fieldKey+"\']");if(!fields.length){return;}fields.forEach(function(el){if(el.type==="checkbox"){el.checked=!!value;}else if(el.type==="radio"){el.checked=String(el.value)===String(value);}else if(el.dataset.nativeformsDate==="true"){el.value=formatDateForField(value,el);validateDateField(el,false);}else if(el.dataset.nativeformsTime==="true"){el.value=formatTimeForField(value,el);validateTimeField(el,false);}else{el.value=value==null?"":value;}});}';
        html += 'function readAllFieldValues(){const values={};form.querySelectorAll("[name]").forEach(function(control){const fieldKey=String(control.name||"");if(!fieldKey||Object.prototype.hasOwnProperty.call(values,fieldKey)){return;}values[fieldKey]=readRuntimeFieldValue(fieldKey);});return values;}';
        html += 'const repeatDeleteState={};';
        html += 'let lastPrefillPayload=null;';
        html += 'function readRepeatFieldValueByKey(rowEl,fieldKey){const fields=rowEl.querySelectorAll("[data-repeat-field-key=\'"+fieldKey+"\']");if(!fields.length){return "";}const first=fields[0];if(first.type==="checkbox"){return !!first.checked;}if(first.type==="radio"){const checked=Array.from(fields).find(function(el){return el.checked;});return checked?checked.value:"";}if(first.dataset.nativeformsDate==="true"){const parsed=parseDateValue(first.value||"",first.dataset.dateFormat||"us");return parsed?parsed.iso:(first.value||"");}if(first.dataset.nativeformsTime==="true"){const parsed=parseTimeValue(first.value||"",first.dataset.timeFormat||"24h");return parsed||String(first.value||"");}return first.value||"";}';
        html += 'function setRepeatFieldValue(field,value){if(!field){return;}if(field.type==="checkbox"){field.checked=!!value;return;}if(field.type==="radio"){field.checked=String(field.value)===String(value==null?"":value);return;}if(field.dataset.nativeformsDate==="true"){field.value=formatDateForField(value,field);validateDateField(field,false);return;}if(field.dataset.nativeformsTime==="true"){field.value=formatTimeForField(value,field);validateTimeField(field,false);return;}field.value=value==null?"":value;}';
        html += 'function setupRepeatRow(groupKey,rowEl,rowData,rowIndex){rowEl.dataset.repeatRowIndex=String(rowIndex);rowEl.querySelectorAll("[data-repeat-field-key]").forEach(function(field){const fieldKey=field.dataset.repeatFieldKey;const sourceField=field.dataset.repeatSourceField||fieldKey;const value=rowData&&Object.prototype.hasOwnProperty.call(rowData,sourceField)?rowData[sourceField]:"";if(field.id){field.id=groupKey+"-"+rowIndex+"-"+field.id;}if(field.type==="radio"){field.name=groupKey+"-"+rowIndex+"-"+fieldKey;}else if(field.name){field.removeAttribute("name");}setRepeatFieldValue(field,value);});rowEl.querySelectorAll("label[for]").forEach(function(label,index){const target=rowEl.querySelectorAll("[data-repeat-field-key]")[index];if(target&&target.id){label.setAttribute("for",target.id);}});}';
        html += 'function renderRepeatGroup(groupKey,groupPayload){const rowsHost=form.querySelector("[data-repeat-rows=\'"+groupKey+"\']");const template=form.querySelector("template[data-repeat-template=\'"+groupKey+"\']");if(!rowsHost||!template){return;}repeatDeleteState[groupKey]=[];rowsHost.innerHTML="";const rows=(groupPayload&&Array.isArray(groupPayload.rows))?groupPayload.rows:[];rows.forEach(function(rowData,rowIndex){const fragment=template.content.cloneNode(true);const rowEl=fragment.querySelector("[data-repeat-row]");setupRepeatRow(groupKey,rowEl,rowData||{},rowIndex);rowsHost.appendChild(fragment);});}';
        html += 'function clearRepeatGroups(){form.querySelectorAll("[data-repeat-rows]").forEach(function(host){host.innerHTML="";});Object.keys(repeatDeleteState).forEach(function(key){repeatDeleteState[key]=[];});}';
        html += 'function addRepeatRow(groupKey){const rowsHost=form.querySelector("[data-repeat-rows=\'"+groupKey+"\']");const template=form.querySelector("template[data-repeat-template=\'"+groupKey+"\']");if(!rowsHost||!template){return;}const fragment=template.content.cloneNode(true);const rowEl=fragment.querySelector("[data-repeat-row]");setupRepeatRow(groupKey,rowEl,{},rowsHost.children.length);rowsHost.appendChild(fragment);}';
        html += 'function collectRepeatGroups(){const groups={};form.querySelectorAll("[data-repeat-group]").forEach(function(groupEl){const groupKey=groupEl.dataset.repeatGroup;const rows=[];groupEl.querySelectorAll("[data-repeat-row]").forEach(function(rowEl){const row={};const seen={};rowEl.querySelectorAll("[data-repeat-field-key]").forEach(function(field){const fieldKey=field.dataset.repeatFieldKey;if(seen[fieldKey]){return;}row[fieldKey]=readRepeatFieldValueByKey(rowEl,fieldKey);seen[fieldKey]=true;});rows.push(row);});groups[groupKey]={rows:rows,deletedIds:repeatDeleteState[groupKey]||[]};});return groups;}';
        html += 'form.addEventListener("click",function(event){const addButton=event.target.closest("[data-repeat-add]");if(addButton){event.preventDefault();addRepeatRow(addButton.dataset.repeatAdd);return;}const deleteButton=event.target.closest("[data-repeat-delete-row]");if(deleteButton){event.preventDefault();const rowEl=deleteButton.closest("[data-repeat-row]");const groupEl=deleteButton.closest("[data-repeat-group]");if(!rowEl||!groupEl){return;}const groupKey=groupEl.dataset.repeatGroup;const idFieldKey=groupEl.dataset.repeatIdField;const existingId=idFieldKey?readRepeatFieldValueByKey(rowEl,idFieldKey):"";if(existingId){repeatDeleteState[groupKey]=repeatDeleteState[groupKey]||[];repeatDeleteState[groupKey].push(existingId);}rowEl.remove();}});';
        html += 'function applyLockState(control){if(!control||control.dataset.lockOnPrefill!=="true"){return;}let hasValue=false;if(control.type==="checkbox"||control.type==="radio"){hasValue=!!control.checked;}else{hasValue=String(control.value==null?"":control.value).trim()!=="";}if(control.tagName==="SELECT"||control.type==="checkbox"||control.type==="radio"){control.disabled=hasValue;}else{control.readOnly=hasValue;}}';
        html += 'function applyLockedFields(){form.querySelectorAll("[data-lock-on-prefill=\'true\']").forEach(function(control){applyLockState(control);});}';
        html += 'function applyPrefillPayload(payload){if(!payload){return;}lastPrefillPayload=payload;const input=payload.input||{};const hidden=payload.hidden||{};const repeatGroups=payload.repeatGroups||{};Object.keys(input).forEach(function(key){setFieldValue(key,input[key]);});Object.keys(hidden).forEach(function(key){setFieldValue(key,hidden[key]);});clearRepeatGroups();Object.keys(repeatGroups).forEach(function(groupKey){renderRepeatGroup(groupKey,repeatGroups[groupKey]);});evaluateAllFormulaFields();applyLockedFields();evaluateConditions();}';
        html += 'async function runPrefill(){const params={};new URLSearchParams(window.location.search).forEach(function(value,key){params[key]=value;});if(Object.keys(params).length===0){return;}await runPrefillWithParams(params);}';
        html += 'function isoDate(value){return value.toISOString().split("T")[0];}';
        html += 'function applyDateConstraints(){form.querySelectorAll("[data-nativeforms-date=\'true\']").forEach(function(el){const now=new Date();let minDate=el.dataset.minDate?new Date(el.dataset.minDate+"T00:00:00Z"):null;let maxDate=el.dataset.maxDate?new Date(el.dataset.maxDate+"T00:00:00Z"):null;const pastYears=Number(el.dataset.pastYears||0);const pastMonths=Number(el.dataset.pastMonths||0);const futureYears=Number(el.dataset.futureYears||0);const futureMonths=Number(el.dataset.futureMonths||0);if(pastYears||pastMonths){minDate=new Date(now);minDate.setFullYear(minDate.getFullYear()-pastYears);minDate.setMonth(minDate.getMonth()-pastMonths);}if(futureYears||futureMonths){maxDate=new Date(now);maxDate.setFullYear(maxDate.getFullYear()+futureYears);maxDate.setMonth(maxDate.getMonth()+futureMonths);}if(minDate){el.dataset.effectiveMinDate=isoDate(minDate);}else{el.removeAttribute("data-effective-min-date");}if(maxDate){el.dataset.effectiveMaxDate=isoDate(maxDate);}else{el.removeAttribute("data-effective-max-date");}if(el.value){const parsed=parseDateValue(el.value,el.dataset.dateFormat||"us")||parseDateValue(el.value,"us")||parseDateValue(el.value,"eu");if(parsed){el.value=formatParsedDate(parsed,el.dataset.dateFormat||"us");}}validateDateField(el,false);});}';
        html += 'function validateField(el){if(!el||el.type==="hidden"){return true;}if(el.dataset.nativeformsDate==="true"){const valid=validateDateField(el,true);if(valid&&el.value){const parsed=parseDateValue(el.value,el.dataset.dateFormat||"us");if(parsed){el.value=formatParsedDate(parsed,el.dataset.dateFormat||"us");}}return valid;}if(el.dataset.nativeformsTime==="true"){const valid=validateTimeField(el,true);if(valid&&el.value){el.value=formatTimeForField(el.value,el);}return valid;}const valid=el.checkValidity();if(!valid){el.reportValidity();}return valid;}';
        html += 'function wireLiveValidation(){form.querySelectorAll("input,textarea,select").forEach(function(el){if(el.type==="hidden"){return;}const events=(el.dataset.nativeformsDate==="true"||el.dataset.nativeformsTime==="true")?["change","blur"]:["input","change","blur"];events.forEach(function(evt){el.addEventListener(evt,function(){validateField(el);});});});}';
        html += 'function collectNormalizedDateValues(){const values={};const dateFields=form.querySelectorAll("[data-nativeforms-date=\'true\']");for(let index=0;index<dateFields.length;index+=1){const el=dateFields[index];if(!validateDateField(el,true)){return{success:false,message:el.validationMessage||t("dateReview","Please review the date fields and try again."),values:{}};}const parsed=parseDateValue(el.value||"",el.dataset.dateFormat||"us");if(parsed&&el.name){values[el.name]=parsed.iso;}}return{success:true,message:"",values:values};}';
        html += 'function collectNormalizedTimeValues(){const values={};const timeFields=form.querySelectorAll("[data-nativeforms-time=\'true\']");for(let index=0;index<timeFields.length;index+=1){const el=timeFields[index];if(!validateTimeField(el,true)){return{success:false,message:el.validationMessage||t("timeReview","Please review the time fields and try again."),values:{}};}const parsed=parseTimeValue(el.value||"",el.dataset.timeFormat||"24h");if(parsed&&el.name){values[el.name]=parsed;el.value=formatTimeForField(parsed,el);}}return{success:true,message:"",values:values};}';
        html += 'function setElementVisibilityState(elementId,visible){const key=String(elementId||"");if(!key){return;}manualVisibilityState[key]=visible!==false;evaluateConditions();}';
        html += 'function evaluateConditions(){form.querySelectorAll("[data-conditions],[data-condition-source],[data-element-id]").forEach(function(el){const elementId=String(el.dataset.elementId||"");const conditionVisible=evaluateElementConditions(el);const manualVisible=elementId&&Object.prototype.hasOwnProperty.call(manualVisibilityState,elementId)?manualVisibilityState[elementId]:true;const visible=conditionVisible&&manualVisible;el.hidden=!visible;el.style.display=visible?"":"none";});}';
        html += 'const twinaFormsApi={getValue:function(fieldKey){return readRuntimeFieldValue(String(fieldKey||""));},setValue:function(fieldKey,value){const safeFieldKey=String(fieldKey||"");setFieldValue(safeFieldKey,value);handleRuntimeStateChange();emitTwinaFormsEvent("change",{fieldKey:safeFieldKey,value:readRuntimeFieldValue(safeFieldKey),source:"api"});},getAll:function(){return readAllFieldValues();},showElement:function(elementId){setElementVisibilityState(elementId,true);},hideElement:function(elementId){setElementVisibilityState(elementId,false);},on:function(eventName,handler){const name=String(eventName||"");if(!name||typeof handler!=="function"){return function(){};}twinaFormsHandlers[name]=twinaFormsHandlers[name]||[];twinaFormsHandlers[name].push(handler);return function(){twinaFormsApi.off(name,handler);};},off:function(eventName,handler){const name=String(eventName||"");const handlers=twinaFormsHandlers[name]||[];if(typeof handler!=="function"){delete twinaFormsHandlers[name];return;}twinaFormsHandlers[name]=handlers.filter(function(candidate){return candidate!==handler;});}};';
        html += 'window.TwinaForms=twinaFormsApi;window.NativeForms=window.TwinaForms;';
        html += 'function runGuardedCustomJs(){const customJsSource="' + escapeJsString(publishedCustomJs) + '";if(!String(customJsSource||"").trim()){return;}try{const runner=new Function("TwinaForms",customJsSource);runner(window.TwinaForms);}catch(error){console.error("TwinaForms custom JavaScript error",error);emitTwinaFormsEvent("customjs:error",{message:error&&error.message?error.message:"Custom JavaScript failed",source:"customjs"});}}';
        html += 'applyDateConstraints();';
        html += 'wireLiveValidation();';
        html += 'fileUploadControls().forEach(function(control){renderFileUploadState(control);control.addEventListener("change",function(){uploadSelectedFiles(control).catch(function(error){setStatus("error",error&&error.message?error.message:t("fileUploadFailed","We could not upload this file. Please try again."));});});});';
        html += 'form.addEventListener("click",function(event){const clearButton=event.target.closest("[data-file-upload-clear]");if(!clearButton){return;}event.preventDefault();clearFileUploadField(clearButton.getAttribute("data-file-upload-clear"));});';
        html += 'runGuardedCustomJs();';
        html += 'emitTwinaFormsEvent("form:init",{versionId:config.versionId,formId:config.formId});';
        html += 'function handleRuntimeStateChange(event){evaluateAllFormulaFields();evaluateConditions();const fieldKey=event&&event.target&&event.target.name?String(event.target.name):"";if(fieldKey){emitTwinaFormsEvent("change",{fieldKey:fieldKey,value:readRuntimeFieldValue(fieldKey),source:"user"});}}';
        html += 'form.addEventListener("input",handleRuntimeStateChange);';
        html += 'form.addEventListener("change",handleRuntimeStateChange);';
        html += 'evaluateAllFormulaFields();';
        html += 'evaluateConditions();';
        html += 'setSecretGatedState(!secretCodeEnabled);';
        html += 'setSecretCodeStepVisible(false);';
        html += 'emitTwinaFormsEvent("form:ready",{versionId:config.versionId,formId:config.formId});';
        html += 'if(secretCodeEnabled&&secretVerifyEl){const sendButton=secretVerifyEl.querySelector("[data-secret-send]");const verifyButton=secretVerifyEl.querySelector("[data-secret-verify]");const resendButton=secretVerifyEl.querySelector("[data-secret-resend]");if(sendButton){sendButton.addEventListener("click",async function(){const email=readSecretVerificationEmail();if(!email){setSecretVerificationMessage(t("secretCodeEnterEmailFirst","Enter your email first."),"error");return;}sendButton.disabled=true;try{await sendSecretCodeRequest("sendCode",{email:email,expiryMinutes:secretCodeConfig.expiryMinutes,maxAttempts:secretCodeConfig.maxAttempts});setSecretCodeStepVisible(true);setSecretVerificationMessage(secretCodeConfig.sentMessage||t("secretCodeSentMessage","If we found a matching contact, we sent a 6-digit code to that email."),"");const codeInput=secretVerifyEl.querySelector("[data-secret-code]");if(codeInput){window.setTimeout(function(){codeInput.focus();},0);}}catch(error){setSecretVerificationMessage(error&&error.message?error.message:t("secretCodeSendFailed","We could not send the code right now."),"error");}finally{sendButton.disabled=false;}});}if(verifyButton){verifyButton.addEventListener("click",async function(){const email=readSecretVerificationEmail();const code=readSecretVerificationCode();if(!email||!code){setSecretVerificationMessage(t("secretCodeEnterEmailAndCodeFirst","Enter your email and code first."),"error");return;}verifyButton.disabled=true;try{const data=await sendSecretCodeRequest("verifyCode",{email:email,code:code,expiryMinutes:secretCodeConfig.expiryMinutes,maxAttempts:secretCodeConfig.maxAttempts,sessionId:secretVerificationSessionId});if(data.approved){secretVerificationToken=data.verificationToken||"";secretVerifiedEmail=data.normalizedEmail||email;setSecretCodeStepVisible(true);setSecretVerificationMessage(secretCodeConfig.verifiedMessage||t("secretCodeVerifiedMessage","Code verified. You can continue with the form now."),"success");setSecretGatedState(true);setSecretVerificationSectionVisible(false);runPrefillWithParams({email:secretVerifiedEmail}).catch(function(){setStatus("error",t("prefillLoadFailed","We could not load prefill data for this form."));});}else{setSecretCodeStepVisible(true);setSecretVerificationMessage((data&&data.message)||secretCodeConfig.invalidMessage||t("secretCodeInvalidMessage","The code is invalid or expired. Try again or request a new code."),"error");}}catch(error){setSecretCodeStepVisible(true);setSecretVerificationMessage(error&&error.message?error.message:t("secretCodeVerifyFailed","We could not verify the code right now."),"error");}finally{verifyButton.disabled=false;}});}if(resendButton){resendButton.addEventListener("click",async function(){const email=readSecretVerificationEmail();if(!email){setSecretVerificationMessage(t("secretCodeEnterEmailFirst","Enter your email first."),"error");return;}resendButton.disabled=true;try{await sendSecretCodeRequest("sendCode",{email:email,expiryMinutes:secretCodeConfig.expiryMinutes,maxAttempts:secretCodeConfig.maxAttempts});setSecretCodeStepVisible(true);setSecretVerificationMessage(secretCodeConfig.sentMessage||t("secretCodeSentMessage","If we found a matching contact, we sent a 6-digit code to that email."),"");const codeInput=secretVerifyEl.querySelector("[data-secret-code]");if(codeInput){window.setTimeout(function(){codeInput.focus();},0);}}catch(error){setSecretVerificationMessage(error&&error.message?error.message:t("secretCodeSendFailed","We could not send the code right now."),"error");}finally{resendButton.disabled=false;}});}}';
        html += 'runPrefill().catch(function(error){emitTwinaFormsEvent("prefill:error",{message:error&&error.message?error.message:t("prefillLoadFailed","We could not load prefill data for this form.")});setStatus("error",t("prefillLoadFailed","We could not load prefill data for this form."));});';
        html += 'form.addEventListener("submit",async function(event){event.preventDefault();clearStatus();';
        html += 'clearResult();';
        html += 'if(secretCodeEnabled&&!secretVerificationApproved){setStatus("error",secretCodeConfig.invalidMessage||t("secretVerifyRequiredBeforeSubmit","Verify the secret code before continuing."));return;}';
        html += 'if(!form.reportValidity()){return;}';
        html += 'const uploadValidation=validateUploadedFiles();if(!uploadValidation.valid){setStatus("error",uploadValidation.message||t("fileUploadReview","Please review the uploaded files and try again."));return;}';
        html += 'if(captchaEnabled&&!getCaptchaToken()){setStatus("error",t("captchaRequired","Please complete the CAPTCHA."));return;}';
        html += 'setSubmitting(true);';
        html += 'try{evaluateAllFormulaFields();const normalizedDates=collectNormalizedDateValues();if(!normalizedDates.success){setStatus("error",normalizedDates.message);return;}const normalizedTimes=collectNormalizedTimeValues();if(!normalizedTimes.success){setStatus("error",normalizedTimes.message);return;}const formData=new FormData(form);const input={};for(const [key,value] of formData.entries()){if(value instanceof File){continue;}input[key]=value;}';
        html += 'form.querySelectorAll("input[type=\'checkbox\'][name]").forEach(function(el){input[el.name]=!!el.checked;});';
        html += 'Object.keys(normalizedDates.values).forEach(function(key){input[key]=normalizedDates.values[key];});';
        html += 'Object.keys(normalizedTimes.values).forEach(function(key){input[key]=normalizedTimes.values[key];});';
        html += 'const uploadedFieldKeys=Object.keys(uploadedFilesByField).filter(function(key){return Array.isArray(uploadedFilesByField[key])&&uploadedFilesByField[key].length;});if(uploadedFieldKeys.length){input.fileUploads={};uploadedFieldKeys.forEach(function(key){input.fileUploads[key]=uploadedFilesByField[key];});input.fileUploadSessionId=fileUploadSessionId;}';
        html += 'if(secretCodeEnabled){input.secretVerificationToken=secretVerificationToken;input.secretVerificationSessionId=secretVerificationSessionId;input.secretVerificationEmail=secretVerifiedEmail;}';
        html += 'if(captchaEnabled){input.captchaToken=getCaptchaToken();}';
        html += 'input.repeatGroups=collectRepeatGroups();';
        html += 'emitTwinaFormsEvent("submit:before",{input:input,prefillSnapshot:lastPrefillPayload});const response=await fetch(config.submitUrl,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({formId:config.formId,publishToken:config.publishToken,input:input,prefillSnapshot:lastPrefillPayload})});';
        html += 'const data=await response.json();';
        html += 'if(!response.ok||data.success===false){emitTwinaFormsEvent("submit:error",{response:data,error:data&&data.error?data.error:null});renderResult("error",{errorPayload:data.error,submissionRef:data&&data.submissionRef?data.submissionRef:"",detailsText:JSON.stringify(data,null,2)});if(captchaEnabled){resetCaptcha();}return;}';
        html += 'const resolvedPostSubmitUrl=postSubmitAutoLinkEnabled?resolvePostSubmitUrl(postSubmitUrlTemplate,input,lastPrefillPayload):"";';
        html += 'emitTwinaFormsEvent("submit:after",{response:data,submissionRef:data&&data.submissionRef?data.submissionRef:""});form.dataset.submitCompleted="true";form.reset();clearRepeatGroups();clearAllUploadedFiles();lastPrefillPayload=null;resetCaptcha();if(resolvedPostSubmitUrl){window.location.assign(resolvedPostSubmitUrl);return;}renderResult("success",{message:submitSuccessMessage,submissionRef:data&&data.submissionRef?data.submissionRef:""});';
        html += '}catch(error){emitTwinaFormsEvent("submit:error",{error:{message:error&&error.message?error.message:"Submit failed"}});renderResult("error",{errorPayload:{message:"' + escapeJsString(localizedFormUiDefault('submitFailedMessage', languageCode, 'We could not submit this form right now. Please try again.')) + '"},detailsText:JSON.stringify({success:false,error:{message:error&&error.message?error.message:"Submit failed"}},null,2)});if(captchaEnabled){resetCaptcha();}}finally{setSubmitting(false);}';
        html += '});';
        html += '})();</script>';
        html += '</body></html>';
        return html;
    }

    private static String renderElement(NF_Form_Element__c elementRecord, Map<String, List<NF_Form_Element__c>> childrenByParent, Boolean rtlEnabled, String languageCode) {
        Map<String, Object> config = parseJsonMap(elementRecord.Config_JSON__c);
        String typeValue = String.isBlank(elementRecord.Element_Type__c) ? 'text' : elementRecord.Element_Type__c;
        String fieldName = String.isNotBlank(elementRecord.Field_Key__c) ? elementRecord.Field_Key__c : String.valueOf(elementRecord.Id);
        String label = String.isNotBlank(elementRecord.Label__c) ? elementRecord.Label__c : fieldName;
        String placeholder = config.containsKey('placeholder') ? String.valueOf(config.get('placeholder')) : '';
        Boolean required = config.containsKey('required') ? Boolean.valueOf(String.valueOf(config.get('required'))) : false;
        String rawDefaultValue = config.containsKey('defaultValue') ? String.valueOf(config.get('defaultValue')) : '';
        String defaultValue = normalizeLegacySeedDefaultValue(
            typeValue,
            rawDefaultValue
        );
        Boolean isFormula = booleanValue(config.get('isFormula')) && (typeValue == 'text' || typeValue == 'number');
        if (isFormula) {
            defaultValue = '';
            placeholder = '';
        }
        if (String.isBlank(placeholder) && isLegacySeedDefaultValue(typeValue, rawDefaultValue)) {
            placeholder = localizedPlaceholderForType(typeValue, languageCode, config);
        }
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
        String safeLabelWithRequired = appendRequiredMarker(safeLabel, required);
        String safeElementId = escapeHtml(String.isNotBlank(elementRecord.Element_Id__c) ? elementRecord.Element_Id__c : String.valueOf(elementRecord.Id));
        String wrapperAttrs = conditionalDataAttrs(config) + hiddenBehaviorStyle(config);
        String formulaAttrs = isFormula ? formulaDataAttrs(fieldName, typeValue, config) : '';
        String lockOnPrefillAttr = lockOnPrefillDataAttr(config);
        if (String.isNotBlank(lockOnPrefillAttr)) {
            wrapperAttrs += lockOnPrefillAttr;
        }
        String labelPosition = normalizedLabelPosition(config);
        String labelClassAttr = labelClassAttr(config);
        Boolean hiddenByBehavior = isHiddenBehavior(config);

        if (hiddenByBehavior && typeValue != 'repeatGroup' && typeValue != 'group' && typeValue != 'section' && typeValue != 'sectionBreak') {
            String hiddenDefaultValue = String.isNotBlank(hiddenValue) ? hiddenValue : defaultValue;
            return '<input type="hidden" data-element-id="' + safeElementId + '" name="' + safeName + '" value="' + escapeHtml(hiddenDefaultValue) + '"' + lockOnPrefillAttr + formulaAttrs + '>';
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
                            Boolean childRequired = booleanValue(childConfig.get('required'));
                            repeatHtml += '<div class="nf-field"><label' + labelClassAttr(childConfig) + '>' + appendRequiredMarker(escapeHtml(childLabel), childRequired) + '</label></div>';
                        }
                    }
                    repeatHtml += '</div>';
                }
                repeatHtml += '</div></div></div>';
            }
            repeatHtml += '<div class="nf-repeat__rows" data-repeat-rows="' + escapeHtml(repeatGroupKey) + '"></div>';
            if (allowAddRows) {
                repeatHtml += '<div class="nf-repeat__actions"><button type="button" data-repeat-add="' + escapeHtml(repeatGroupKey) + '">' + escapeHtml(runtimeTextValue(languageCode, 'repeatAddRow', 'Add Row')) + '</button></div>';
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
                            repeatHtml += renderRepeatGroupChildElement(childElement, repeatAlias, showLabelsOnEachRow, rtlEnabled, languageCode);
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
                        groupHtml += renderElement(childElement, childrenByParent, rtlEnabled, languageCode);
                    }
                } else {
                    groupHtml += '<div class="nf-section__grid nf-section__grid--' + String.valueOf(columnCount) + '">';
                    for (Integer columnIndex = 1; columnIndex <= columnCount; columnIndex++) {
                        groupHtml += '<div class="nf-section__column">';
                        for (NF_Form_Element__c childElement : childElements) {
                            if (readSectionColumn(childElement.Config_JSON__c) == columnIndex) {
                                groupHtml += renderElement(childElement, childrenByParent, rtlEnabled, languageCode);
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
                            sectionHtml += renderElement(childElement, childrenByParent, rtlEnabled, languageCode);
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
            String labelHtml = labelPosition == 'hidden' ? '' : '<label for="' + safeName + '"' + labelClassAttr + '>' + safeLabelWithRequired + '</label>';
            String controlHtml = '<textarea id="' + safeName + '" name="' + safeName + '"' + lockOnPrefillAttr + placeholderAttr + requiredAttr + patternAttr + '></textarea>';
            return renderFieldWrapper(safeElementId, wrapperAttrs, labelPosition, labelHtml, controlHtml, rtlEnabled);
        }
        if (typeValue == 'select' && config.containsKey('options')) {
            String optionsHtml = '<option value="">' + escapeHtml(runtimeTextValue(languageCode, 'selectPlaceholder', 'Select...')) + '</option>';
            for (Object rawOption : (List<Object>) config.get('options')) {
                if (rawOption instanceof Map<String, Object>) {
                    Map<String, Object> option = (Map<String, Object>) rawOption;
                    String optionValue = escapeHtml(String.valueOf(option.get('value')));
                    String optionLabel = escapeHtml(String.valueOf(option.get('label')));
                    String selectedAttr = String.valueOf(option.get('value')) == defaultValue ? ' selected' : '';
                    optionsHtml += '<option value="' + optionValue + '"' + selectedAttr + '>' + optionLabel + '</option>';
                }
            }
            String labelHtml = labelPosition == 'hidden' ? '' : '<label for="' + safeName + '"' + labelClassAttr + '>' + safeLabelWithRequired + '</label>';
            String controlHtml = '<select id="' + safeName + '" name="' + safeName + '"' + lockOnPrefillAttr + requiredAttr + '>' + optionsHtml + '</select>';
            return renderFieldWrapper(safeElementId, wrapperAttrs, labelPosition, labelHtml, controlHtml, rtlEnabled);
        }
        if (typeValue == 'radio' && config.containsKey('options')) {
            String radiosHtml = '<div class="nf-field nf-field--' + escapeHtml(labelPosition) + '" data-element-id="' + safeElementId + '"' + wrapperAttrs + '>';
            if (labelPosition != 'hidden') {
                radiosHtml += '<label' + labelClassAttr + '>' + safeLabelWithRequired + '</label>';
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
            return '<div class="nf-field nf-field--checkbox nf-field--' + escapeHtml(labelPosition) + '" data-element-id="' + safeElementId + '"' + wrapperAttrs + '><label' + labelClassAttr + '><input type="checkbox" name="' + safeName + '"' + lockOnPrefillAttr + checkedAttr + requiredAttr + '> ' + safeLabelWithRequired + '</label></div>';
        }
        if (typeValue == 'hidden') {
            return '<input type="hidden" data-element-id="' + safeElementId + '" name="' + safeName + '" value="' + escapeHtml(hiddenValue) + '">';
        }

        if (typeValue == 'date') {
            String displayValue = formatDateDefaultValue(defaultValue, config);
            String datePlaceholder = String.isNotBlank(placeholder) ? placeholder : datePlaceholder(config);
            String dateValueAttr = String.isNotBlank(displayValue) ? ' value="' + escapeHtml(displayValue) + '"' : '';
            String labelHtml = labelPosition == 'hidden' ? '' : '<label for="' + safeName + '"' + labelClassAttr + '>' + safeLabelWithRequired + '</label>';
            String controlHtml = '<input class="nf-control--ltr" type="text" id="' + safeName + '" name="' + safeName + '" inputmode="numeric" autocomplete="off" data-nativeforms-date="true"' + dateRangeAttrs + lockOnPrefillAttr + ' placeholder="' + escapeHtml(datePlaceholder) + '"' + dateValueAttr + requiredAttr + '>';
            return renderFieldWrapper(safeElementId, wrapperAttrs, labelPosition, labelHtml, controlHtml, rtlEnabled);
        }

        if (typeValue == 'time') {
            String timeFormat = normalizedTimeFormat(config);
            String displayValue = formatTimeDefaultValue(defaultValue, timeFormat);
            String timePlaceholder = String.isNotBlank(placeholder) ? placeholder : timePlaceholder(timeFormat);
            String timeValueAttr = String.isNotBlank(displayValue) ? ' value="' + escapeHtml(displayValue) + '"' : '';
            String labelHtml = labelPosition == 'hidden' ? '' : '<label for="' + safeName + '"' + labelClassAttr + '>' + safeLabelWithRequired + '</label>';
            String controlHtml = '<input class="nf-control--ltr" type="text" id="' + safeName + '" name="' + safeName + '" inputmode="text" autocomplete="off" data-nativeforms-time="true" data-time-format="' + escapeHtml(timeFormat) + '"' + lockOnPrefillAttr + ' placeholder="' + escapeHtml(timePlaceholder) + '"' + timeValueAttr + requiredAttr + '>';
            return renderFieldWrapper(safeElementId, wrapperAttrs, labelPosition, labelHtml, controlHtml, rtlEnabled);
        }

        if (typeValue == 'fileUpload') {
            String labelHtml = labelPosition == 'hidden' ? '' : '<label for="' + safeName + '"' + labelClassAttr + '>' + safeLabelWithRequired + '</label>';
            String acceptAttr = fileAcceptAttr(config);
            String multipleAttr = booleanValue(config.get('allowMultiple')) ? ' multiple' : '';
            String helpText = fileUploadHelpText(config, languageCode);
            String browseLabel = booleanValue(config.get('allowMultiple'))
                ? runtimeTextValue(languageCode, 'fileBrowseMultiple', 'Browse files')
                : runtimeTextValue(languageCode, 'fileBrowseSingle', 'Browse file');
            String controlHtml = '<div class="nf-upload">';
            controlHtml += '<input class="nf-upload__input" type="file" id="' + safeName + '" name="' + safeName + '" data-nativeforms-file="true"' + acceptAttr + multipleAttr + requiredAttr + '>';
            controlHtml += '<label class="nf-upload__surface" for="' + safeName + '">';
            controlHtml += '<span class="nf-upload__action">' + escapeHtml(browseLabel) + '</span>';
            controlHtml += '</label>';
            if (String.isNotBlank(helpText)) {
                controlHtml += '<div class="nf-upload__meta">' + escapeHtml(helpText) + '</div>';
            }
            controlHtml += '<div class="nf-upload__feedback" data-file-upload-feedback></div>';
            controlHtml += '<div class="nf-upload__list" data-file-upload-list></div>';
            controlHtml += '</div>';
            return renderFieldWrapper(safeElementId, wrapperAttrs, labelPosition, labelHtml, controlHtml, rtlEnabled);
        }

        String htmlType = normalizeInputType(typeValue);
        String valueAttr = String.isNotBlank(defaultValue) ? ' value="' + escapeHtml(defaultValue) + '"' : '';
        String labelHtml = labelPosition == 'hidden' ? '' : '<label for="' + safeName + '"' + labelClassAttr + '>' + safeLabelWithRequired + '</label>';
        String formulaReadonlyAttr = isFormula ? ' readonly' : '';
        String controlHtml = '<input' + inputDirectionClassAttr(typeValue) + ' type="' + escapeHtml(htmlType) + '" id="' + safeName + '" name="' + safeName + '"' + lockOnPrefillAttr + formulaAttrs + formulaReadonlyAttr + placeholderAttr + valueAttr + requiredAttr + minAttr + maxAttr + dateRangeAttrs + patternAttr + '>';
        return renderFieldWrapper(safeElementId, wrapperAttrs, labelPosition, labelHtml, controlHtml, rtlEnabled);
    }

    private static String renderRepeatGroupChildElement(NF_Form_Element__c elementRecord, String repeatAlias, Boolean showLabels, Boolean rtlEnabled, String languageCode) {
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
        String rawDefaultValue = stringValue(config.get('defaultValue'));
        if (String.isBlank(placeholder) && isLegacySeedDefaultValue(typeValue, rawDefaultValue)) {
            placeholder = localizedPlaceholderForType(typeValue, languageCode, config);
        }
        String labelPosition = showLabels ? normalizedLabelPosition(config) : 'hidden';
        String labelClassAttr = labelClassAttr(config);
        String repeatLabelClassAttr = labelPosition == 'hidden'
            ? repeatMobileLabelClassAttr(config)
            : labelClassAttr;
        String sourceAttr = ' data-repeat-source-field="' + escapeHtml(sourceField) + '"';
        String keyAttr = ' data-repeat-field-key="' + escapeHtml(fieldKey) + '"';
        String lockOnPrefillAttr = lockOnPrefillDataAttr(config);
        Boolean required = booleanValue(config.get('required'));
        String requiredAttr = required ? ' required' : '';
        String safeLabelWithRequired = appendRequiredMarker(escapeHtml(label), required);
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
            return '<div class="nf-field nf-field--checkbox nf-field--' + escapeHtml(labelPosition) + '"><label' + labelClassAttr + '><input type="checkbox" id="' + baseId + '"' + keyAttr + sourceAttr + lockOnPrefillAttr + requiredAttr + '> ' + safeLabelWithRequired + '</label></div>';
        }

        if (typeValue == 'textarea') {
            String labelHtml = '<label for="' + baseId + '"' + repeatLabelClassAttr + '>' + safeLabelWithRequired + '</label>';
            String controlHtml = '<textarea id="' + baseId + '"' + keyAttr + sourceAttr + lockOnPrefillAttr + (String.isNotBlank(placeholder) ? ' placeholder="' + escapeHtml(placeholder) + '"' : '') + requiredAttr + '></textarea>';
            return renderFieldWrapper('', '', labelPosition, labelHtml, controlHtml, rtlEnabled);
        }

        if (typeValue == 'select' && config.containsKey('options')) {
            String optionsHtml = '<option value="">' + escapeHtml(runtimeTextValue(languageCode, 'selectPlaceholder', 'Select...')) + '</option>';
            for (Object rawOption : (List<Object>) config.get('options')) {
                if (rawOption instanceof Map<String, Object>) {
                    Map<String, Object> option = (Map<String, Object>) rawOption;
                    optionsHtml += '<option value="' + escapeHtml(String.valueOf(option.get('value'))) + '">' + escapeHtml(String.valueOf(option.get('label'))) + '</option>';
                }
            }
            String labelHtml = '<label for="' + baseId + '"' + repeatLabelClassAttr + '>' + safeLabelWithRequired + '</label>';
            String controlHtml = '<select id="' + baseId + '"' + keyAttr + sourceAttr + lockOnPrefillAttr + requiredAttr + '>' + optionsHtml + '</select>';
            return renderFieldWrapper('', '', labelPosition, labelHtml, controlHtml, rtlEnabled);
        }

        if (typeValue == 'radio' && config.containsKey('options')) {
            String html = '<div class="nf-field nf-field--' + escapeHtml(labelPosition) + '">';
            html += '<label' + repeatLabelClassAttr + '>' + safeLabelWithRequired + '</label>';
            html += '<div class="nf-field--radio-group">';
            Integer optionIndex = 0;
            for (Object rawOption : (List<Object>) config.get('options')) {
                if (rawOption instanceof Map<String, Object>) {
                    Map<String, Object> option = (Map<String, Object>) rawOption;
                    String optionId = baseId + '-' + String.valueOf(optionIndex);
                    html += '<label class="nf-radio-option" for="' + escapeHtml(optionId) + '">';
                    html += '<input type="radio" id="' + escapeHtml(optionId) + '" value="' + escapeHtml(String.valueOf(option.get('value'))) + '"' + keyAttr + sourceAttr + lockOnPrefillAttr + requiredAttr + '>';
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

        if (typeValue == 'date') {
            String displayValue = formatDateDefaultValue(stringValue(config.get('defaultValue')), config);
            String datePlaceholder = String.isNotBlank(placeholder) ? placeholder : datePlaceholder(config);
            String valueAttr = String.isNotBlank(displayValue) ? ' value="' + escapeHtml(displayValue) + '"' : '';
            String labelHtml = '<label for="' + baseId + '"' + repeatLabelClassAttr + '>' + safeLabelWithRequired + '</label>';
            String controlHtml = '<input class="nf-control--ltr" type="text" id="' + baseId + '" inputmode="numeric" autocomplete="off" data-nativeforms-date="true"' + keyAttr + sourceAttr + dateRangeDataAttrs(config) + lockOnPrefillAttr + ' placeholder="' + escapeHtml(datePlaceholder) + '"' + valueAttr + requiredAttr + '>';
            return renderFieldWrapper('', '', labelPosition, labelHtml, controlHtml, rtlEnabled);
        }

        if (typeValue == 'time') {
            String timeFormat = normalizedTimeFormat(config);
            String displayValue = formatTimeDefaultValue(stringValue(config.get('defaultValue')), timeFormat);
            String timePlaceholder = String.isNotBlank(placeholder) ? placeholder : timePlaceholder(timeFormat);
            String valueAttr = String.isNotBlank(displayValue) ? ' value="' + escapeHtml(displayValue) + '"' : '';
            String labelHtml = '<label for="' + baseId + '"' + repeatLabelClassAttr + '>' + safeLabelWithRequired + '</label>';
            String controlHtml = '<input class="nf-control--ltr" type="text" id="' + baseId + '" inputmode="text" autocomplete="off" data-nativeforms-time="true" data-time-format="' + escapeHtml(timeFormat) + '"' + keyAttr + sourceAttr + lockOnPrefillAttr + ' placeholder="' + escapeHtml(timePlaceholder) + '"' + valueAttr + requiredAttr + '>';
            return renderFieldWrapper('', '', labelPosition, labelHtml, controlHtml, rtlEnabled);
        }

        if (typeValue == 'fileUpload') {
            String labelHtml = '<label for="' + baseId + '"' + repeatLabelClassAttr + '>' + safeLabelWithRequired + '</label>';
            String acceptAttr = fileAcceptAttr(config);
            String multipleAttr = booleanValue(config.get('allowMultiple')) ? ' multiple' : '';
            String helpText = fileUploadHelpText(config, languageCode);
            String browseLabel = booleanValue(config.get('allowMultiple'))
                ? runtimeTextValue(languageCode, 'fileBrowseMultiple', 'Browse files')
                : runtimeTextValue(languageCode, 'fileBrowseSingle', 'Browse file');
            String controlHtml = '<div class="nf-upload">';
            controlHtml += '<input class="nf-upload__input" type="file" id="' + baseId + '"' + keyAttr + sourceAttr + ' data-nativeforms-file="true"' + acceptAttr + multipleAttr + requiredAttr + '>';
            controlHtml += '<label class="nf-upload__surface" for="' + baseId + '">';
            controlHtml += '<span class="nf-upload__action">' + escapeHtml(browseLabel) + '</span>';
            controlHtml += '</label>';
            if (String.isNotBlank(helpText)) {
                controlHtml += '<div class="nf-upload__meta">' + escapeHtml(helpText) + '</div>';
            }
            controlHtml += '<div class="nf-upload__feedback" data-file-upload-feedback></div>';
            controlHtml += '<div class="nf-upload__list" data-file-upload-list></div>';
            controlHtml += '</div>';
            return renderFieldWrapper('', '', labelPosition, labelHtml, controlHtml, rtlEnabled);
        }

        String htmlType = normalizeInputType(typeValue);
        String labelHtml = '<label for="' + baseId + '"' + repeatLabelClassAttr + '>' + safeLabelWithRequired + '</label>';
        String controlHtml = '<input' + inputDirectionClassAttr(typeValue) + ' type="' + escapeHtml(htmlType) + '" id="' + baseId + '"' + keyAttr + sourceAttr + lockOnPrefillAttr + (String.isNotBlank(placeholder) ? ' placeholder="' + escapeHtml(placeholder) + '"' : '') + requiredAttr + '>';
        return renderFieldWrapper('', '', labelPosition, labelHtml, controlHtml, rtlEnabled);
    }

    private static String appendRequiredMarker(String safeLabel, Boolean required) {
        return required ? safeLabel + '<span class="nf-required-marker">*</span>' : safeLabel;
    }

    private static String inputDirectionClassAttr(String typeValue) {
        return isLtrInputType(typeValue) ? ' class="nf-control--ltr"' : '';
    }

    private static Boolean isLtrInputType(String typeValue) {
        return typeValue == 'number' || typeValue == 'email' || typeValue == 'tel' || typeValue == 'url' || typeValue == 'date' || typeValue == 'time';
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

    private static String renderFieldWrapper(String safeElementId, String wrapperAttrs, String labelPosition, String labelHtml, String controlHtml, Boolean rtlEnabled) {
        String normalizedPosition = String.isBlank(labelPosition) ? 'above' : labelPosition;
        String html = '<div class="nf-field nf-field--' + escapeHtml(normalizedPosition) + '" data-element-id="' + safeElementId + '"' + wrapperAttrs + '>';
        Boolean renderLabelAfterControl = normalizedPosition == 'right';
        if (rtlEnabled == true) {
            if (normalizedPosition == 'left') {
                renderLabelAfterControl = false;
            } else if (normalizedPosition == 'right') {
                renderLabelAfterControl = true;
            }
        }
        if (renderLabelAfterControl) {
            html += controlHtml;
            html += labelHtml;
        } else {
            html += labelHtml;
            html += controlHtml;
        }
        html += '</div>';
        return html;
    }

    private static String runtimeTextValue(String languageCode, String key, String fallback) {
        Map<String, Object> runtimeText = NativeFormsRuntimeI18n.runtimeText(languageCode);
        if (runtimeText == null || !runtimeText.containsKey(key)) {
            return fallback;
        }
        String value = stringValue(runtimeText.get(key));
        return String.isBlank(value) ? fallback : value;
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

    private static String fileAcceptAttr(Map<String, Object> config) {
        if (config == null) {
            return '';
        }
        List<String> tokens = new List<String>();
        Object rawAllowedExtensions = config.get('allowedExtensions');
        if (rawAllowedExtensions instanceof List<Object>) {
            for (Object rawValue : (List<Object>) rawAllowedExtensions) {
                String normalizedValue = stringValue(rawValue);
                if (String.isBlank(normalizedValue)) {
                    continue;
                }
                normalizedValue = normalizedValue.trim().toLowerCase();
                if (!normalizedValue.startsWith('.')) {
                    normalizedValue = '.' + normalizedValue;
                }
                tokens.add(normalizedValue);
            }
        }
        return tokens.isEmpty() ? '' : ' accept="' + escapeHtml(String.join(tokens, ',')) + '"';
    }

    private static String fileUploadHelpText(Map<String, Object> config, String languageCode) {
        if (config == null) {
            return '';
        }
        List<String> parts = new List<String>();
        Object rawAllowedExtensions = config.get('allowedExtensions');
        if (rawAllowedExtensions instanceof List<Object>) {
            List<String> extensions = new List<String>();
            for (Object rawValue : (List<Object>) rawAllowedExtensions) {
                String normalizedValue = stringValue(rawValue);
                if (String.isBlank(normalizedValue)) {
                    continue;
                }
                normalizedValue = normalizedValue.trim().toLowerCase();
                if (normalizedValue.startsWith('.')) {
                    normalizedValue = normalizedValue.substring(1);
                }
                extensions.add(normalizedValue);
            }
            if (!extensions.isEmpty()) {
                parts.add(
                    runtimeTextValue(languageCode, 'fileAllowedTypes', 'Allowed: {types}')
                        .replace('{types}', String.join(extensions, ', '))
                );
            }
        }
        Integer maxFileSizeMb = integerValue(config.get('maxFileSizeMb'));
        if (maxFileSizeMb != null && maxFileSizeMb > 0) {
            parts.add(
                runtimeTextValue(languageCode, 'fileMaxSize', 'Max size: {size} MB')
                    .replace('{size}', String.valueOf(maxFileSizeMb))
            );
        }
        if (booleanValue(config.get('allowMultiple'))) {
            parts.add(runtimeTextValue(languageCode, 'fileMultipleAllowed', 'Multiple files allowed'));
        }
        return String.join(parts, ' | ');
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
        List<Object> conditions = normalizedConditionalConditions(config);
        if (conditions.isEmpty()) {
            return '';
        }
        String attrs = ' data-conditions="' + escapeHtml(JSON.serialize(conditions)) + '"';
        attrs += ' data-condition-expression="' + escapeHtml(defaultConditionalExpression(stringValue(config.get('conditionalExpression')), conditions.size())) + '"';
        return attrs;
    }

    private static String labelCssClasses(Map<String, Object> config) {
        if (config == null) {
            return '';
        }
        List<String> classes = new List<String>();
        if (booleanValue(config.get('labelBold'))) {
            classes.add('nf-label--bold');
        }
        if (booleanValue(config.get('labelItalic'))) {
            classes.add('nf-label--italic');
        }
        if (booleanValue(config.get('labelUnderline'))) {
            classes.add('nf-label--underline');
        }
        return String.join(classes, ' ');
    }

    private static String labelClassAttr(Map<String, Object> config) {
        String classes = labelCssClasses(config);
        return String.isBlank(classes) ? '' : ' class="' + classes + '"';
    }

    private static String repeatMobileLabelClassAttr(Map<String, Object> config) {
        String classes = labelCssClasses(config);
        classes = String.isBlank(classes) ? 'nf-repeat-mobile-label' : 'nf-repeat-mobile-label ' + classes;
        return ' class="' + classes + '"';
    }

    private static String formulaDataAttrs(String fieldKey, String typeValue, Map<String, Object> config) {
        if (String.isBlank(fieldKey) || config == null || !booleanValue(config.get('isFormula'))) {
            return '';
        }
        String expression = stringValue(config.get('formulaExpression'));
        if (String.isBlank(expression)) {
            return '';
        }
        return ' data-formula-target="true"'
            + ' data-formula-field-key="' + escapeHtml(fieldKey) + '"'
            + ' data-formula-type="' + escapeHtml(typeValue) + '"'
            + ' data-formula-expression="' + escapeHtml(expression) + '"'
            + ' data-formula-sources="' + escapeHtml(String.join(extractFormulaReferences(expression), ',')) + '"';
    }

    private static List<String> extractFormulaReferences(String expression) {
        List<String> references = new List<String>();
        if (String.isBlank(expression)) {
            return references;
        }
        Set<String> seen = new Set<String>();
        Matcher matcher = Pattern.compile('\\{([A-Za-z0-9_]+)\\}').matcher(expression);
        while (matcher.find()) {
            String fieldKey = matcher.group(1);
            if (String.isBlank(fieldKey) || seen.contains(fieldKey)) {
                continue;
            }
            seen.add(fieldKey);
            references.add(fieldKey);
        }
        return references;
    }

    private static List<Object> buildPublishedUploadFields(List<NF_Form_Element__c> elements) {
        List<Object> uploadFields = new List<Object>();
        if (elements == null) {
            return uploadFields;
        }

        for (NF_Form_Element__c elementRecord : elements) {
            if (elementRecord == null || elementRecord.Element_Type__c != 'fileUpload') {
                continue;
            }

            Map<String, Object> config = parseJsonMap(elementRecord.Config_JSON__c);
            List<String> allowedExtensions = new List<String>();
            Object rawAllowedExtensions = config.get('allowedExtensions');
            if (rawAllowedExtensions instanceof List<Object>) {
                for (Object rawValue : (List<Object>) rawAllowedExtensions) {
                    String normalizedValue = stringValue(rawValue);
                    if (String.isBlank(normalizedValue)) {
                        continue;
                    }
                    normalizedValue = normalizedValue.trim().toLowerCase();
                    if (normalizedValue.startsWith('.')) {
                        normalizedValue = normalizedValue.substring(1);
                    }
                    if (String.isNotBlank(normalizedValue)) {
                        allowedExtensions.add(normalizedValue);
                    }
                }
            }

            uploadFields.add(new Map<String, Object>{
                'elementId' => elementRecord.Element_Id__c,
                'fieldKey' => elementRecord.Field_Key__c,
                'label' => elementRecord.Label__c,
                'required' => booleanValue(config.get('required')),
                'allowMultiple' => booleanValue(config.get('allowMultiple')),
                'allowedExtensions' => allowedExtensions,
                'maxFileSizeMb' => integerValue(config.get('maxFileSizeMb')),
                'targetSubmitActionKey' => stringValue(config.get('targetSubmitActionKey'))
            });
        }

        return uploadFields;
    }

    private static Map<String, Object> buildPublishedSecretCodeConfig(Map<String, Object> uiSettings, String languageCode) {
        uiSettings = uiSettings == null ? new Map<String, Object>() : uiSettings;
        String normalizedLanguageCode = NativeFormsRuntimeI18n.normalizeLanguageCode(languageCode);
        return new Map<String, Object>{
            'enabled' => booleanValue(uiSettings.get('secretCodeVerificationEnabled')),
            'matchField' => 'Email',
            'introText' => localizedSecretCodeConfigValue(uiSettings, 'secretCodeIntroText', normalizedLanguageCode, 'Enter your email and click Enter. We will send you a 6-digit code before you can continue.'),
            'sentMessage' => localizedSecretCodeConfigValue(uiSettings, 'secretCodeSentMessage', normalizedLanguageCode, 'If we found a matching contact, we sent a 6-digit code to that email.'),
            'invalidMessage' => localizedSecretCodeConfigValue(uiSettings, 'secretCodeInvalidMessage', normalizedLanguageCode, 'The code is invalid or expired. Try again or request a new code.'),
            'verifiedMessage' => localizedSecretCodeConfigValue(uiSettings, 'secretCodeVerifiedMessage', normalizedLanguageCode, 'Code verified. You can continue with the form now.'),
            'sendButtonLabel' => localizedSecretCodeConfigValue(uiSettings, 'secretCodeSendButtonLabel', normalizedLanguageCode, 'Enter'),
            'verifyButtonLabel' => localizedSecretCodeConfigValue(uiSettings, 'secretCodeVerifyButtonLabel', normalizedLanguageCode, 'Verify'),
            'resendButtonLabel' => localizedSecretCodeConfigValue(uiSettings, 'secretCodeResendButtonLabel', normalizedLanguageCode, 'Resend Code'),
            'expiryMinutes' => integerValue(uiSettings.get('secretCodeExpiryMinutes')) == null ? 10 : Math.max(1, integerValue(uiSettings.get('secretCodeExpiryMinutes'))),
            'maxAttempts' => integerValue(uiSettings.get('secretCodeMaxAttempts')) == null ? 5 : Math.max(1, integerValue(uiSettings.get('secretCodeMaxAttempts'))),
            'allowResend' => uiSettings.containsKey('secretCodeAllowResend') ? booleanValue(uiSettings.get('secretCodeAllowResend')) : true
        };
    }

    private static String localizedSecretCodeConfigValue(Map<String, Object> uiSettings, String key, String languageCode, String fallback) {
        String rawValue = stringValue(uiSettings.get(key));
        if (String.isBlank(rawValue) || NativeFormsRuntimeI18n.matchesAnyLanguageValue(key, rawValue)) {
            return NativeFormsRuntimeI18n.text(languageCode, key, fallback);
        }
        return rawValue;
    }

    private static String localizedFormUiSettingValue(Map<String, Object> uiSettings, String key, String languageCode, String fallback) {
        String rawValue = stringValue(uiSettings.get(key));
        if (String.isBlank(rawValue) || matchesLocalizedFormUiDefault(key, rawValue)) {
            return localizedFormUiDefault(key, languageCode, fallback);
        }
        return rawValue;
    }

    private static Boolean matchesLocalizedFormUiDefault(String key, String candidate) {
        String trimmedCandidate = String.isBlank(candidate) ? '' : candidate.trim();
        if (String.isBlank(trimmedCandidate)) {
            return false;
        }
        for (String languageCode : new List<String>{ 'en', 'he', 'es' }) {
            if (localizedFormUiDefault(key, languageCode, '') == trimmedCandidate) {
                return true;
            }
        }
        return false;
    }

    private static String localizedFormUiDefault(String key, String languageCode, String fallback) {
        String normalizedLanguageCode = NativeFormsRuntimeI18n.normalizeLanguageCode(languageCode);
        if (key == 'submitLabel') {
            if (normalizedLanguageCode == 'he') return 'שלח';
            if (normalizedLanguageCode == 'es') return 'Enviar';
            return 'Submit';
        }
        if (key == 'submitSuccessMessage') {
            if (normalizedLanguageCode == 'he') return 'הטופס נשלח בהצלחה.';
            if (normalizedLanguageCode == 'es') return 'Tu formulario se envió correctamente.';
            return 'Your form was submitted successfully.';
        }
        if (key == 'postSubmitButtonLabel') {
            if (normalizedLanguageCode == 'he') return 'המשך';
            if (normalizedLanguageCode == 'es') return 'Continuar';
            return 'Continue';
        }
        if (key == 'submitFailedMessage') {
            if (normalizedLanguageCode == 'he') return 'לא הצלחנו לשלוח את הטופס כרגע. נסו שוב.';
            if (normalizedLanguageCode == 'es') return 'No pudimos enviar este formulario ahora mismo. Inténtalo de nuevo.';
            return 'We could not submit this form right now. Please try again.';
        }
        return fallback;
    }

    private static String renderSecretCodeVerificationBlock(Map<String, Object> config) {
        if (config == null || !booleanValue(config.get('enabled'))) {
            return '';
        }
        String html = '';
        html += '<section class="nf-secret-verify" data-secret-verification>';
        html += '<p class="nf-secret-verify__copy">' + escapeHtml(stringValue(config.get('introText'))) + '</p>';
        html += '<div class="nf-secret-verify__row"><input type="email" data-secret-email autocomplete="email"><button type="button" data-secret-send>' + escapeHtml(stringValue(config.get('sendButtonLabel'))) + '</button></div>';
        html += '<div class="nf-secret-verify__code-step" data-secret-code-step hidden>';
        html += '<div class="nf-secret-verify__row"><input type="text" data-secret-code inputmode="numeric" maxlength="6"><button type="button" data-secret-verify>' + escapeHtml(stringValue(config.get('verifyButtonLabel'))) + '</button></div>';
        html += '</div>';
        if (booleanValue(config.get('allowResend'))) {
            html += '<div class="nf-secret-verify__resend-wrap" data-secret-resend-wrap hidden><button type="button" class="nf-secret-verify__resend" data-secret-resend>' + escapeHtml(stringValue(config.get('resendButtonLabel'))) + '</button></div>';
        }
        html += '<p class="nf-secret-verify__message" data-secret-message></p>';
        html += '</section>';
        return html;
    }

    private static List<Object> normalizedConditionalConditions(Map<String, Object> config) {
        List<Object> normalized = new List<Object>();
        if (config == null) {
            return normalized;
        }
        Object rawConditions = config.get('conditionalConditions');
        if (rawConditions instanceof List<Object>) {
            for (Object rawCondition : (List<Object>) rawConditions) {
                if (!(rawCondition instanceof Map<String, Object>)) {
                    continue;
                }
                Map<String, Object> condition = (Map<String, Object>) rawCondition;
                String fieldKey = stringValue(condition.get('fieldKey'));
                String operator = normalizedConditionalOperator(stringValue(condition.get('operator')));
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
        if (normalized.isEmpty()) {
            String fieldKey = stringValue(config.get('conditionalFieldKey'));
            String operator = normalizedConditionalOperator(stringValue(config.get('conditionalOperator')));
            if (String.isNotBlank(fieldKey) && String.isNotBlank(operator)) {
                normalized.add(new Map<String, Object>{
                    'fieldKey' => fieldKey,
                    'operator' => operator,
                    'value' => stringValue(config.get('conditionalValue'))
                });
            }
        }
        return normalized;
    }

    private static String normalizedConditionalOperator(String rawValue) {
        String value = String.isBlank(rawValue) ? 'equals' : rawValue.trim();
        Set<String> allowed = new Set<String>{ 'equals', 'notEquals', 'isTrue', 'isFalse', 'isBlank', 'isNotBlank' };
        return allowed.contains(value) ? value : null;
    }

    private static String defaultConditionalExpression(String rawValue, Integer conditionCount) {
        if (conditionCount == null || conditionCount < 1) {
            return '';
        }
        if (String.isNotBlank(rawValue)) {
            return rawValue.trim();
        }
        List<String> tokens = new List<String>();
        for (Integer index = 1; index <= conditionCount; index += 1) {
            tokens.add(String.valueOf(index));
        }
        return String.join(tokens, ' AND ');
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
        attrs.add(' data-date-format="' + escapeHtml(normalizedDateDisplayFormat(config)) + '"');
        attrs.add(' data-date-gmt-offset="' + escapeHtml(normalizedDateGmtOffset(config)) + '"');
        if (config.containsKey('minValue') && String.isNotBlank(String.valueOf(config.get('minValue')))) {
            attrs.add(' data-min-date="' + escapeHtml(String.valueOf(config.get('minValue'))) + '"');
        }
        if (config.containsKey('maxValue') && String.isNotBlank(String.valueOf(config.get('maxValue')))) {
            attrs.add(' data-max-date="' + escapeHtml(String.valueOf(config.get('maxValue'))) + '"');
        }
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

    private static String normalizedDateDisplayFormat(Map<String, Object> config) {
        String value = stringValue(config == null ? null : config.get('dateDisplayFormat'));
        return value == 'eu' ? 'eu' : 'us';
    }

    private static String normalizedDateGmtOffset(Map<String, Object> config) {
        String value = stringValue(config == null ? null : config.get('dateGmtOffset'));
        return String.isNotBlank(value) ? value : '+00:00';
    }

    private static String datePlaceholder(Map<String, Object> config) {
        return normalizedDateDisplayFormat(config) == 'eu' ? 'dd/mm/yyyy' : 'mm/dd/yyyy';
    }

    private static String normalizedTimeFormat(Map<String, Object> config) {
        return stringValue(config.get('timeFormat')) == '12h' ? '12h' : '24h';
    }

    private static String timePlaceholder(String timeFormat) {
        return timeFormat == '12h' ? '8:00 PM' : '19:00';
    }

    private static Boolean isLegacySeedDefaultValue(String typeValue, String defaultValue) {
        String trimmedValue = String.isBlank(defaultValue) ? '' : defaultValue.trim();
        if (String.isBlank(trimmedValue)) {
            return false;
        }
        Map<String, String> legacySeedDefaults = new Map<String, String>{
            'text' => 'Enter text',
            'textarea' => 'Enter longer text',
            'number' => 'Enter number',
            'email' => 'name@example.com',
            'tel' => 'Phone number',
            'url' => 'https://example.com'
        };
        return legacySeedDefaults.containsKey(typeValue) && legacySeedDefaults.get(typeValue) == trimmedValue;
    }

    private static String localizedPlaceholderForType(String typeValue, String languageCode, Map<String, Object> config) {
        if (typeValue == 'date') {
            return datePlaceholder(config);
        }
        if (typeValue == 'time') {
            return timePlaceholder(normalizedTimeFormat(config));
        }
        Map<String, String> placeholderKeys = new Map<String, String>{
            'text' => 'placeholderText',
            'textarea' => 'placeholderTextarea',
            'number' => 'placeholderNumber',
            'email' => 'placeholderEmail',
            'tel' => 'placeholderPhone',
            'url' => 'placeholderUrl'
        };
        Map<String, String> fallbackValues = new Map<String, String>{
            'text' => 'Enter text',
            'textarea' => 'Enter longer text',
            'number' => 'Enter number',
            'email' => 'name@example.com',
            'tel' => 'Phone number',
            'url' => 'https://example.com'
        };
        if (!placeholderKeys.containsKey(typeValue)) {
            return '';
        }
        return runtimeTextValue(languageCode, placeholderKeys.get(typeValue), fallbackValues.get(typeValue));
    }

    private static String normalizeLegacySeedDefaultValue(String typeValue, String defaultValue) {
        return isLegacySeedDefaultValue(typeValue, defaultValue) ? '' : defaultValue;
    }

    private static String formatDateDefaultValue(String value, Map<String, Object> config) {
        if (String.isBlank(value)) {
            return '';
        }
        String trimmed = value.trim();
        if (trimmed.length() >= 10 && trimmed.substring(4, 5) == '-' && trimmed.substring(7, 8) == '-') {
            String year = trimmed.substring(0, 4);
            String month = trimmed.substring(5, 7);
            String day = trimmed.substring(8, 10);
            return normalizedDateDisplayFormat(config) == 'eu'
                ? day + '/' + month + '/' + year
                : month + '/' + day + '/' + year;
        }
        return trimmed;
    }

    private static String formatTimeDefaultValue(String value, String timeFormat) {
        if (String.isBlank(value)) {
            return '';
        }
        String trimmed = value.trim();
        if (!Pattern.matches('^\\d{1,2}:\\d{2}$', trimmed)) {
            return trimmed;
        }
        List<String> parts = trimmed.split(':');
        Integer hours = Integer.valueOf(parts[0]);
        Integer minutes = Integer.valueOf(parts[1]);
        if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
            return trimmed;
        }
        if (timeFormat != '12h') {
            return String.valueOf(hours).leftPad(2, '0') + ':' + String.valueOf(minutes).leftPad(2, '0');
        }
        String meridiem = hours >= 12 ? 'PM' : 'AM';
        Integer hour12 = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours);
        return String.valueOf(hour12) + ':' + String.valueOf(minutes).leftPad(2, '0') + ' ' + meridiem;
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

    private static String escapeJsString(String value) {
        if (value == null) {
            return '';
        }

        return value
            .replace('\\', '\\\\')
            .replace('"', '\\"')
            .replace('<', '\\u003C')
            .replace('>', '\\u003E')
            .replace('&', '\\u0026')
            .replace('\r', '\\r')
            .replace('\n', '\\n');
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

    private static Map<String, Object> buildPublishedCaptchaConfig(Boolean enableCaptcha, NativeForms_Config__c orgConfig) {
        Map<String, Object> captcha = new Map<String, Object>{
            'enabled' => false,
            'provider' => 'google-recaptcha-v2'
        };

        if (enableCaptcha != true) {
            return captcha;
        }

        String siteKey = SHARED_CAPTCHA_SITE_KEY;
        if (String.isBlank(siteKey)) {
            throw new AuraHandledException('CAPTCHA is enabled for this form, but the shared TwinaForms CAPTCHA site key is not configured in the package.');
        }

        captcha.put('enabled', true);
        captcha.put('siteKey', siteKey.trim());
        return captcha;
    }

    public static Boolean hasSharedCaptchaSiteKey() {
        return String.isNotBlank(SHARED_CAPTCHA_SITE_KEY);
    }

    public static String getSharedCaptchaSiteKey() {
        return SHARED_CAPTCHA_SITE_KEY;
    }

    @TestVisible
    private static String buildInternalFormId(String orgId, Id formId) {
        return 'nf-' + orgId + '-' + String.valueOf(formId);
    }

    @TestVisible
    private static String normalizePublishedFormSlug(String rawValue) {
        if (String.isBlank(rawValue)) {
            return null;
        }

        String normalized = rawValue.trim().toLowerCase();
        Matcher matcher = FRIENDLY_FORM_SLUG_PATTERN.matcher(normalized);
        return matcher.matches() ? normalized : null;
    }

    private static String normalizePublishedPublicUrl(String publicUrl, String key) {
        String trimmedBaseUrl = PUBLISHED_FORMS_BASE_URL == null ? null : PUBLISHED_FORMS_BASE_URL.trim();
        String trimmedKey = key == null ? null : key.trim();
        if (String.isNotBlank(trimmedBaseUrl) && String.isNotBlank(trimmedKey)) {
            return trimmedBaseUrl.replaceAll('/+$', '') + '/' + trimmedKey.replaceAll('^/+', '');
        }
        return publicUrl;
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
        String rawValue = stringValue(source.get(key));
        String value = String.isBlank(rawValue) ? '' : rawValue.toLowerCase();
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

    private static String friendlyPublishErrorMessage(Exception e) {
        String message = e == null ? '' : String.valueOf(e.getMessage());
        String normalized = String.isBlank(message) ? '' : message.trim().toLowerCase();

        if (normalized.contains('captcha') && normalized.contains('site key')) {
            return 'CAPTCHA is enabled for this form, but the shared TwinaForms CAPTCHA key is not configured yet.';
        }

        return 'TwinaForms could not publish this form right now. Review the form setup and try again.';
    }
}
