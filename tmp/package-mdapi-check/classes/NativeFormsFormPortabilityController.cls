public with sharing class NativeFormsFormPortabilityController {
    private static final String SCHEMA_VERSION_V1 = 'linked-env-portable-form-v1';
    private static final String SCHEMA_VERSION_V2 = 'linked-env-portable-form-v2';
    private static final String CURRENT_SCHEMA_VERSION = SCHEMA_VERSION_V2;
    private static final String PACKAGE_TYPE = 'twinaformsFormDefinition';
    private static final Integer MAX_EMBEDDED_IMAGE_BYTES = 70656;

    @AuraEnabled
    public static String exportForm(Id formId, Id versionId) {
        if (formId == null) {
            throw new AuraHandledException('Select a form to export.');
        }

        NF_Form__c formRecord = [
            SELECT Id, Description__c, NF_Key__c, Project__c, Project__r.Name, Status__c,
                   Current_Draft_Version__c, Current_Published_Version__c,
                   Theme__c, Theme__r.Name, Theme__r.Description__c, Theme__r.Logo_URL__c,
                   Theme__r.Logo_Content_Document_Id__c, Theme__r.Logo_Size_Px__c, Theme__r.Logo_Position__c,
                   Theme__r.Form_Width__c, Theme__r.Background_Color__c, Theme__r.Background_Gradient_Color__c, Theme__r.Form_Background_Color__c,
                   Theme__r.Form_Border_Color__c, Theme__r.Title_Font__c, Theme__r.Title_Font_Size_Px__c,
                   Theme__r.Title_Text_Color__c, Theme__r.Section_Title_Font__c,
                   Theme__r.Section_Title_Font_Size_Px__c, Theme__r.Section_Title_Text_Color__c,
                   Theme__r.Main_Font__c, Theme__r.Main_Text_Size_Px__c, Theme__r.Main_Text_Color__c,
                   Theme__r.Link_Text_Color__c, Theme__r.Hint_Text_Color__c, Theme__r.Error_Color__c,
                   Theme__r.Input_Border_Radius_Px__c, Theme__r.Input_Background_Color__c,
                   Theme__r.Input_Border_Color__c, Theme__r.Button_Font__c, Theme__r.Button_Font_Size_Px__c,
                   Theme__r.Button_Text_Color__c, Theme__r.Button_Background_Color__c,
                   Theme__r.Button_Hover_Background_Color__c
            FROM NF_Form__c
            WHERE Id = :formId
            WITH USER_MODE
            LIMIT 1
        ];
        if (String.isBlank(formRecord.NF_Key__c)) {
            throw new AuraHandledException('This form cannot be exported because it does not have a TwinaForms form number.');
        }

        Id effectiveVersionId = versionId == null ? formRecord.Current_Draft_Version__c : versionId;
        if (effectiveVersionId == null) {
            throw new AuraHandledException('Select a form version to export.');
        }

        NF_Form_Version__c versionRecord = [
            SELECT Id, Form__c, Name, Version_Number__c, Version_Status__c, Publish_Status__c,
                   Security_Mode__c, Rate_Limit_Profile__c, Custom_CSS__c, Custom_JS__c,
                   Theme_JSON__c, UI_Settings_JSON__c, Prefill_Params_JSON__c
            FROM NF_Form_Version__c
            WHERE Id = :effectiveVersionId
            WITH USER_MODE
            LIMIT 1
        ];
        if (versionRecord.Form__c != formRecord.Id) {
            throw new AuraHandledException('The selected version does not belong to this form.');
        }

        List<NF_Form_Element__c> elementRows = [
            SELECT Element_Id__c, Element_Type__c, Field_Key__c, Label__c,
                   Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :versionRecord.Id
            WITH USER_MODE
            ORDER BY Order__c ASC, CreatedDate ASC
        ];
        List<NF_Form_Action__c> actionRows = [
            SELECT Action_Scope__c, Command_Key__c, Command_Type__c, Object_Api_Name__c,
                   Store_Result_As__c, Config_JSON__c, Order__c
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :versionRecord.Id
            WITH USER_MODE
            ORDER BY Order__c ASC, CreatedDate ASC
        ];

        Map<String, Object> packageMap = new Map<String, Object>();
        packageMap.put('schemaVersion', CURRENT_SCHEMA_VERSION);
        packageMap.put('packageType', PACKAGE_TYPE);
        packageMap.put('exportedAt', System.now().formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
        packageMap.put('sourceOrgId', UserInfo.getOrganizationId());
        packageMap.put('sourceEnvironmentType', null);
        packageMap.put('sourcePackageVersion', null);
        packageMap.put('sourcePublishedUrl', null);
        packageMap.put('globalFormKey', formRecord.NF_Key__c);
        packageMap.put('form', serializeForm(formRecord));
        Map<String, Object> themeMap = serializeTheme(formRecord, versionRecord);
        ExportAssetContext assetContext = buildExportAssetContext(formRecord, elementRows, themeMap);
        packageMap.put('version', serializeVersion(versionRecord));
        packageMap.put('elements', serializeElements(elementRows, assetContext));
        packageMap.put('actions', serializeActions(actionRows));
        packageMap.put('theme', themeMap);
        packageMap.put('assets', assetContext.assets);
        packageMap.put('manifest', buildManifest(versionRecord, elementRows, actionRows, themeMap, assetContext));
        packageMap.put('stripped', buildStrippedSummary());
        return JSON.serializePretty(packageMap);
    }

    @AuraEnabled
    public static String inspectImport(String packageJson) {
        ImportPackage parsed = parseAndValidatePackage(packageJson);
        Map<String, Object> preview = buildPreview(parsed);
        return JSON.serializePretty(preview);
    }

    @AuraEnabled
    public static String importForm(String packageJson, String optionsJson) {
        ImportPackage parsed = parseAndValidatePackage(packageJson);
        Map<String, Object> preview = buildPreview(parsed);
        List<String> blockingErrors = stringList(preview.get('blockingErrors'));
        if (!blockingErrors.isEmpty()) {
            throw new AuraHandledException('Import blocked: ' + blockingErrors[0]);
        }

        Savepoint sp = Database.setSavepoint();
        try {
            ImportOptions options = parseOptions(optionsJson);
            List<NF_Form__c> existingForms = queryFormsByKey(parsed.globalFormKey);
            NF_Form__c targetForm;
            Boolean createdForm = false;
            if (existingForms.isEmpty()) {
                Id targetProjectId = options.projectId == null
                    ? NativeFormsProjectService.resolveProjectId(null, null)
                    : options.projectId;
                targetForm = new NF_Form__c(
                    NF_Key__c = parsed.globalFormKey,
                    Description__c = parsed.formDescription,
                    Status__c = 'Draft',
                    Project__c = targetProjectId
                );
                insert as user targetForm;
                createdForm = true;
            } else {
                targetForm = existingForms[0];
            }

            Id targetThemeId = resolveImportedTheme(parsed, options, targetForm);
            if (targetThemeId != null) {
                targetForm.Theme__c = targetThemeId;
            }

            Decimal nextVersionNumber = nextVersionNumber(targetForm.Id);
            NF_Form_Version__c importedVersion = new NF_Form_Version__c(
                Form__c = targetForm.Id,
                Version_Number__c = nextVersionNumber,
                Version_Status__c = 'Draft',
                Publish_Status__c = 'Never Published',
                Security_Mode__c = parsed.securityMode,
                Rate_Limit_Profile__c = parsed.rateLimitProfile,
                Custom_CSS__c = parsed.customCss,
                Custom_JS__c = parsed.customJs,
                Theme_JSON__c = parsed.themeJson,
                UI_Settings_JSON__c = parsed.uiSettingsJson,
                Prefill_Params_JSON__c = parsed.prefillParamsJson
            );
            insert as user importedVersion;

            Map<String, Map<String, Object>> importedAssetReferences = importAssets(parsed, importedVersion.Id, targetThemeId);

            List<NF_Form_Element__c> elementsToInsert = new List<NF_Form_Element__c>();
            for (Map<String, Object> elementMap : parsed.elements) {
                elementsToInsert.add(new NF_Form_Element__c(
                    Form_Version__c = importedVersion.Id,
                    Element_Id__c = stringValue(elementMap.get('elementId')),
                    Element_Type__c = stringValue(elementMap.get('elementType')),
                    Field_Key__c = stringValue(elementMap.get('fieldKey')),
                    Label__c = stringValue(elementMap.get('label')),
                    Config_JSON__c = rewriteElementConfigForImportedAssets(elementMap, importedAssetReferences),
                    Parent_Element_Id__c = stringValue(elementMap.get('parentElementId')),
                    Order__c = decimalValue(elementMap.get('order'))
                ));
            }
            if (!elementsToInsert.isEmpty()) {
                insert as user elementsToInsert;
            }

            List<NF_Form_Action__c> actionsToInsert = new List<NF_Form_Action__c>();
            for (Map<String, Object> actionMap : parsed.actions) {
                actionsToInsert.add(new NF_Form_Action__c(
                    Form_Version__c = importedVersion.Id,
                    Action_Scope__c = stringValue(actionMap.get('actionScope')),
                    Command_Key__c = stringValue(actionMap.get('commandKey')),
                    Command_Type__c = stringValue(actionMap.get('commandType')),
                    Object_Api_Name__c = stringValue(actionMap.get('objectApiName')),
                    Store_Result_As__c = stringValue(actionMap.get('storeResultAs')),
                    Config_JSON__c = defaultJsonObject(stringValue(actionMap.get('configJson'))),
                    Order__c = decimalValue(actionMap.get('order'))
                ));
            }
            if (!actionsToInsert.isEmpty()) {
                insert as user actionsToInsert;
            }

            update as user new NF_Form__c(
                Id = targetForm.Id,
                Theme__c = targetForm.Theme__c,
                Status__c = 'Draft',
                Current_Draft_Version__c = importedVersion.Id
            );

            Map<String, Object> result = new Map<String, Object>();
            result.put('success', true);
            result.put('targetAction', createdForm ? 'createForm' : 'createVersion');
            result.put('formId', targetForm.Id);
            result.put('versionId', importedVersion.Id);
            result.put('projectId', targetForm.Project__c);
            result.put('globalFormKey', parsed.globalFormKey);
            result.put('warnings', preview.get('warnings'));
            return JSON.serializePretty(result);
        } catch (Exception ex) {
            Database.rollback(sp);
            throw new AuraHandledException(normalizeImportException(ex));
        }
    }

    private static Map<String, Object> serializeForm(NF_Form__c formRecord) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('description', formRecord.Description__c);
        result.put('status', formRecord.Status__c);
        result.put('projectName', formRecord.Project__r == null ? null : formRecord.Project__r.Name);
        return result;
    }

    private static Map<String, Object> serializeVersion(NF_Form_Version__c versionRecord) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('versionNumber', versionRecord.Version_Number__c);
        result.put('versionLabel', versionRecord.Name);
        result.put('versionStatus', versionRecord.Version_Status__c);
        result.put('publishStatus', versionRecord.Publish_Status__c);
        result.put('securityMode', versionRecord.Security_Mode__c);
        result.put('rateLimitProfile', versionRecord.Rate_Limit_Profile__c);
        result.put('customCss', versionRecord.Custom_CSS__c);
        result.put('customJs', versionRecord.Custom_JS__c);
        result.put('themeJson', versionRecord.Theme_JSON__c);
        result.put('uiSettingsJson', sanitizeUiSettingsForExport(versionRecord.UI_Settings_JSON__c));
        result.put('prefillParamsJson', versionRecord.Prefill_Params_JSON__c);
        return result;
    }

    private static String sanitizeUiSettingsForExport(String uiSettingsJson) {
        Map<String, Object> uiSettings = mapValue(parseUntypedOrNull(uiSettingsJson));
        if (uiSettings == null) {
            return uiSettingsJson;
        }
        if (booleanValue(uiSettings.get('postSubmitAutoLinkEnabled')) == false) {
            uiSettings.remove('postSubmitUrlTemplate');
        }
        return JSON.serializePretty(uiSettings);
    }

    private static Map<String, Object> serializeTheme(NF_Form__c formRecord, NF_Form_Version__c versionRecord) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('versionThemeJson', versionRecord.Theme_JSON__c);
        if (formRecord.Theme__c == null || formRecord.Theme__r == null) {
            return result;
        }

        Map<String, Object> tokens = new Map<String, Object>();
        tokens.put('formWidth', formRecord.Theme__r.Form_Width__c);
        tokens.put('backgroundColor', formRecord.Theme__r.Background_Color__c);
        tokens.put('backgroundGradientColor', formRecord.Theme__r.Background_Gradient_Color__c);
        tokens.put('formBackgroundColor', formRecord.Theme__r.Form_Background_Color__c);
        tokens.put('formBorderColor', formRecord.Theme__r.Form_Border_Color__c);
        tokens.put('titleFont', formRecord.Theme__r.Title_Font__c);
        tokens.put('titleFontSizePx', formRecord.Theme__r.Title_Font_Size_Px__c);
        tokens.put('titleTextColor', formRecord.Theme__r.Title_Text_Color__c);
        tokens.put('sectionTitleFont', formRecord.Theme__r.Section_Title_Font__c);
        tokens.put('sectionTitleFontSizePx', formRecord.Theme__r.Section_Title_Font_Size_Px__c);
        tokens.put('sectionTitleTextColor', formRecord.Theme__r.Section_Title_Text_Color__c);
        tokens.put('mainFont', formRecord.Theme__r.Main_Font__c);
        tokens.put('mainTextSizePx', formRecord.Theme__r.Main_Text_Size_Px__c);
        tokens.put('mainTextColor', formRecord.Theme__r.Main_Text_Color__c);
        tokens.put('linkTextColor', formRecord.Theme__r.Link_Text_Color__c);
        tokens.put('hintTextColor', formRecord.Theme__r.Hint_Text_Color__c);
        tokens.put('errorColor', formRecord.Theme__r.Error_Color__c);
        tokens.put('inputBorderRadiusPx', formRecord.Theme__r.Input_Border_Radius_Px__c);
        tokens.put('inputBackgroundColor', formRecord.Theme__r.Input_Background_Color__c);
        tokens.put('inputBorderColor', formRecord.Theme__r.Input_Border_Color__c);
        tokens.put('buttonFont', formRecord.Theme__r.Button_Font__c);
        tokens.put('buttonFontSizePx', formRecord.Theme__r.Button_Font_Size_Px__c);
        tokens.put('buttonTextColor', formRecord.Theme__r.Button_Text_Color__c);
        tokens.put('buttonBackgroundColor', formRecord.Theme__r.Button_Background_Color__c);
        tokens.put('buttonHoverBackgroundColor', formRecord.Theme__r.Button_Hover_Background_Color__c);

        result.put('sourceThemeId', String.valueOf(formRecord.Theme__c));
        result.put('portableThemeKey', buildPortableThemeKey(formRecord.Theme__r.Name));
        result.put('name', formRecord.Theme__r.Name);
        result.put('description', formRecord.Theme__r.Description__c);
        result.put('tokens', tokens);
        result.put('logoUrl', null);
        result.put('logoContentDocumentId', null);
        result.put('logoSizePx', formRecord.Theme__r.Logo_Size_Px__c);
        result.put('logoPosition', formRecord.Theme__r.Logo_Position__c);
        return result;
    }

    private static ExportAssetContext buildExportAssetContext(
        NF_Form__c formRecord,
        List<NF_Form_Element__c> elementRows,
        Map<String, Object> themeMap
    ) {
        ExportAssetContext context = new ExportAssetContext();
        Set<Id> contentVersionIds = new Set<Id>();
        Set<Id> contentDocumentIds = new Set<Id>();
        Map<String, String> assetKeyByElementId = new Map<String, String>();

        String logoDocumentIdText = formRecord.Theme__r == null ? null : stringValue(formRecord.Theme__r.Logo_Content_Document_Id__c);
        Id logoDocumentId = idValue(logoDocumentIdText);
        if (logoDocumentId != null) {
            contentDocumentIds.add(logoDocumentId);
        }

        for (NF_Form_Element__c row : elementRows) {
            if (row.Element_Type__c != 'image') {
                continue;
            }
            Map<String, Object> config = mapValue(parseUntypedOrNull(row.Config_JSON__c));
            if (config == null) {
                continue;
            }
            Id contentVersionId = idValue(stringValue(config.get('contentVersionId')));
            Id contentDocumentId = idValue(stringValue(config.get('contentDocumentId')));
            if (contentVersionId != null) {
                contentVersionIds.add(contentVersionId);
                assetKeyByElementId.put(row.Element_Id__c, 'image-' + row.Element_Id__c);
            } else if (contentDocumentId != null) {
                contentDocumentIds.add(contentDocumentId);
                assetKeyByElementId.put(row.Element_Id__c, 'image-' + row.Element_Id__c);
            } else if (isExternalUrl(stringValue(config.get('imageUrl')))) {
                context.exportWarnings.add('External image URL was removed from image element "' + row.Label__c + '".');
            }
        }

        Map<Id, ContentVersion> versionById = queryContentVersionsById(contentVersionIds);
        Map<Id, ContentVersion> versionByDocumentId = queryLatestContentVersionsByDocumentId(contentDocumentIds);

        if (logoDocumentId != null && versionByDocumentId.containsKey(logoDocumentId)) {
            String assetKey = 'theme-logo';
            ContentVersion logoVersion = versionByDocumentId.get(logoDocumentId);
            Map<String, Object> logoAsset = buildAssetMap(assetKey, 'logo', logoVersion, null, null);
            if (logoAsset != null) {
                context.assets.add(logoAsset);
                context.assetBytes += integerValue(logoAsset.get('sizeBytes'));
                themeMap.put('logoAssetKey', assetKey);
            }
        }

        for (NF_Form_Element__c row : elementRows) {
            String assetKey = assetKeyByElementId.get(row.Element_Id__c);
            if (String.isBlank(assetKey)) {
                continue;
            }
            Map<String, Object> config = mapValue(parseUntypedOrNull(row.Config_JSON__c));
            Id contentVersionId = idValue(stringValue(config == null ? null : config.get('contentVersionId')));
            Id contentDocumentId = idValue(stringValue(config == null ? null : config.get('contentDocumentId')));
            ContentVersion fileVersion = contentVersionId == null ? null : versionById.get(contentVersionId);
            if (fileVersion == null && contentDocumentId != null) {
                fileVersion = versionByDocumentId.get(contentDocumentId);
            }
            Map<String, Object> asset = buildAssetMap(assetKey, 'imageElement', fileVersion, row.Element_Id__c, stringValue(config == null ? null : config.get('fileName')));
            if (asset != null) {
                context.assets.add(asset);
                context.assetBytes += integerValue(asset.get('sizeBytes'));
                context.assetKeyByElementId.put(row.Element_Id__c, assetKey);
            } else {
                context.exportWarnings.add('Image content could not be embedded for element "' + row.Label__c + '".');
            }
        }
        return context;
    }

    private static Map<Id, ContentVersion> queryContentVersionsById(Set<Id> contentVersionIds) {
        Map<Id, ContentVersion> results = new Map<Id, ContentVersion>();
        if (contentVersionIds.isEmpty()) {
            return results;
        }
        for (ContentVersion row : [
            SELECT Id, ContentDocumentId, Title, PathOnClient, FileExtension, VersionData
            FROM ContentVersion
            WHERE Id IN :contentVersionIds
            WITH USER_MODE
        ]) {
            results.put(row.Id, row);
        }
        return results;
    }

    private static Map<Id, ContentVersion> queryLatestContentVersionsByDocumentId(Set<Id> contentDocumentIds) {
        Map<Id, ContentVersion> results = new Map<Id, ContentVersion>();
        if (contentDocumentIds.isEmpty()) {
            return results;
        }
        for (ContentVersion row : [
            SELECT Id, ContentDocumentId, Title, PathOnClient, FileExtension, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds
            AND IsLatest = true
            WITH USER_MODE
        ]) {
            results.put(row.ContentDocumentId, row);
        }
        return results;
    }

    private static Map<String, Object> buildAssetMap(
        String assetKey,
        String usage,
        ContentVersion fileVersion,
        String elementId,
        String fallbackFileName
    ) {
        if (String.isBlank(assetKey) || fileVersion == null || fileVersion.VersionData == null) {
            return null;
        }
        Integer sizeBytes = fileVersion.VersionData.size();
        if (sizeBytes > MAX_EMBEDDED_IMAGE_BYTES) {
            return null;
        }
        String fileName = String.isBlank(fileVersion.PathOnClient) ? fallbackFileName : fileVersion.PathOnClient;
        if (String.isBlank(fileName)) {
            fileName = String.isBlank(fileVersion.Title) ? assetKey : fileVersion.Title;
        }
        Map<String, Object> asset = new Map<String, Object>();
        asset.put('assetKey', assetKey);
        asset.put('usage', usage);
        asset.put('elementId', elementId);
        asset.put('fileName', fileName);
        asset.put('contentType', mimeTypeFromFileName(fileName));
        asset.put('sourceUrl', null);
        asset.put('base64', EncodingUtil.base64Encode(fileVersion.VersionData));
        asset.put('sizeBytes', sizeBytes);
        return asset;
    }

    private static String exportElementConfigJson(NF_Form_Element__c row, ExportAssetContext assetContext) {
        if (row.Element_Type__c != 'image') {
            return row.Config_JSON__c;
        }
        Map<String, Object> config = mapValue(parseUntypedOrNull(row.Config_JSON__c));
        if (config == null) {
            return defaultJsonObject(row.Config_JSON__c);
        }
        String assetKey = assetContext == null ? null : assetContext.assetKeyByElementId.get(row.Element_Id__c);
        if (String.isNotBlank(assetKey)) {
            config.put('imageAssetKey', assetKey);
            config.put('imageUrl', '');
        } else if (isExternalUrl(stringValue(config.get('imageUrl')))) {
            config.put('imageUrl', '');
        }
        config.remove('contentVersionId');
        config.remove('contentDocumentId');
        config.remove('publishedAssetUrl');
        return JSON.serializePretty(config);
    }

    private static List<Object> serializeElements(List<NF_Form_Element__c> elementRows, ExportAssetContext assetContext) {
        List<Object> results = new List<Object>();
        for (NF_Form_Element__c row : elementRows) {
            Map<String, Object> item = new Map<String, Object>();
            item.put('elementId', row.Element_Id__c);
            item.put('elementType', row.Element_Type__c);
            item.put('fieldKey', row.Field_Key__c);
            item.put('label', row.Label__c);
            item.put('configJson', exportElementConfigJson(row, assetContext));
            item.put('parentElementId', row.Parent_Element_Id__c);
            item.put('order', row.Order__c);
            results.add(item);
        }
        return results;
    }

    private static List<Object> serializeActions(List<NF_Form_Action__c> actionRows) {
        List<Object> results = new List<Object>();
        for (NF_Form_Action__c row : actionRows) {
            Map<String, Object> item = new Map<String, Object>();
            item.put('actionScope', row.Action_Scope__c);
            item.put('commandKey', row.Command_Key__c);
            item.put('commandType', row.Command_Type__c);
            item.put('objectApiName', row.Object_Api_Name__c);
            item.put('storeResultAs', row.Store_Result_As__c);
            item.put('configJson', row.Config_JSON__c);
            item.put('order', row.Order__c);
            results.add(item);
        }
        return results;
    }

    private static Map<String, Object> buildManifest(
        NF_Form_Version__c versionRecord,
        List<NF_Form_Element__c> elementRows,
        List<NF_Form_Action__c> actionRows,
        Map<String, Object> themeMap,
        ExportAssetContext assetContext
    ) {
        Set<String> objects = new Set<String>();
        Set<String> fields = new Set<String>();
        Map<String, String> objectByActionKey = new Map<String, String>();
        Map<String, String> objectByStoreAlias = new Map<String, String>();
        for (NF_Form_Action__c actionRow : actionRows) {
            String actionObject = normalizeApiName(actionRow.Object_Api_Name__c);
            if (String.isNotBlank(actionObject)) {
                objects.add(actionObject);
                if (String.isNotBlank(actionRow.Command_Key__c)) {
                    objectByActionKey.put(actionRow.Command_Key__c, actionObject);
                }
                if (String.isNotBlank(actionRow.Store_Result_As__c)) {
                    objectByStoreAlias.put(actionRow.Store_Result_As__c, actionObject);
                }
            }
            collectMetadataReferences(actionRow.Config_JSON__c, objects, fields);
            collectActionConfigReferences(actionRow.Config_JSON__c, actionObject, objects, fields);
        }
        for (NF_Form_Element__c elementRow : elementRows) {
            collectMetadataReferences(elementRow.Config_JSON__c, objects, fields);
            collectElementConfigReferences(elementRow.Config_JSON__c, objectByActionKey, objectByStoreAlias, objects, fields);
        }
        collectMetadataReferences(versionRecord.UI_Settings_JSON__c, objects, fields);
        collectMetadataReferences(versionRecord.Prefill_Params_JSON__c, objects, fields);

        Map<String, Object> manifest = new Map<String, Object>();
        manifest.put('objects', sortedStrings(objects));
        manifest.put('fields', sortedStrings(fields));
        manifest.put('themes', buildThemeManifest(themeMap));
        manifest.put('assets', buildAssetManifest(assetContext));
        manifest.put('features', detectFeatures(versionRecord, elementRows, actionRows));
        manifest.put('limits', buildLimitManifest(elementRows, actionRows, assetContext));
        return manifest;
    }

    private static List<Object> buildThemeManifest(Map<String, Object> themeMap) {
        List<Object> themes = new List<Object>();
        String themeKey = themeMap == null ? null : stringValue(themeMap.get('portableThemeKey'));
        if (String.isNotBlank(themeKey)) {
            themes.add(themeKey);
        }
        return themes;
    }

    private static List<Object> buildAssetManifest(ExportAssetContext assetContext) {
        List<Object> assetKeys = new List<Object>();
        if (assetContext == null) {
            return assetKeys;
        }
        for (Object assetValue : assetContext.assets) {
            Map<String, Object> asset = mapValue(assetValue);
            String assetKey = asset == null ? null : stringValue(asset.get('assetKey'));
            if (String.isNotBlank(assetKey)) {
                assetKeys.add(assetKey);
            }
        }
        return assetKeys;
    }

    private static List<Object> detectFeatures(
        NF_Form_Version__c versionRecord,
        List<NF_Form_Element__c> elementRows,
        List<NF_Form_Action__c> actionRows
    ) {
        Set<String> features = new Set<String>();
        if (String.isNotBlank(versionRecord.Prefill_Params_JSON__c) && versionRecord.Prefill_Params_JSON__c != '[]') {
            features.add('prefill');
        }
        if (String.isNotBlank(versionRecord.Custom_JS__c)) {
            features.add('customJavaScript');
        }
        Map<String, Object> uiSettings = mapValue(parseUntypedOrNull(versionRecord.UI_Settings_JSON__c));
        if (uiSettings != null && booleanValue(uiSettings.get('userVerificationEnabled')) == true) {
            features.add('userVerification');
        }
        for (NF_Form_Action__c actionRow : actionRows) {
            String scope = stringValue(actionRow.Action_Scope__c);
            if (scope != null && scope.toLowerCase() == 'prefill') {
                features.add('prefill');
            }
            if (scope != null && scope.toLowerCase() == 'submit') {
                features.add('submit');
            }
        }
        for (NF_Form_Element__c elementRow : elementRows) {
            String typeValue = stringValue(elementRow.Element_Type__c);
            if (typeValue == 'lookup') {
                features.add('lookup');
            } else if (typeValue == 'fileUpload') {
                features.add('fileUpload');
            } else if (typeValue == 'image') {
                features.add('imageElement');
            } else if (typeValue == 'button') {
                features.add('buttonNavigation');
            }
        }
        List<Object> result = new List<Object>();
        for (String feature : sortedStrings(features)) {
            result.add(feature);
        }
        return result;
    }

    private static Map<String, Object> buildLimitManifest(
        List<NF_Form_Element__c> elementRows,
        List<NF_Form_Action__c> actionRows,
        ExportAssetContext assetContext
    ) {
        return new Map<String, Object>{
            'elementCount' => elementRows == null ? 0 : elementRows.size(),
            'actionCount' => actionRows == null ? 0 : actionRows.size(),
            'assetCount' => assetContext == null ? 0 : assetContext.assets.size(),
            'assetBytes' => assetContext == null ? 0 : assetContext.assetBytes,
            'maxEmbeddedImageBytes' => MAX_EMBEDDED_IMAGE_BYTES
        };
    }

    private static void collectActionConfigReferences(String jsonText, String actionObject, Set<String> objects, Set<String> fields) {
        Map<String, Object> config = mapValue(parseUntypedOrNull(jsonText));
        if (config == null || String.isBlank(actionObject)) {
            return;
        }
        for (Object conditionValue : listValue(config.get('conditions'))) {
            Map<String, Object> condition = mapValue(conditionValue);
            addQualifiedField(actionObject, stringValue(condition == null ? null : condition.get('fieldApiName')), fields);
        }
    }

    private static void collectElementConfigReferences(
        String jsonText,
        Map<String, String> objectByActionKey,
        Map<String, String> objectByStoreAlias,
        Set<String> objects,
        Set<String> fields
    ) {
        Map<String, Object> config = mapValue(parseUntypedOrNull(jsonText));
        if (config == null) {
            return;
        }

        String prefillObject = objectByStoreAlias.get(stringValue(config.get('prefillAlias')));
        addQualifiedField(prefillObject, stringValue(config.get('prefillFieldPath')), fields);

        String submitObject = objectByActionKey.get(stringValue(config.get('submitActionKey')));
        addQualifiedField(submitObject, stringValue(config.get('submitFieldPath')), fields);
        addQualifiedField(submitObject, stringValue(config.get('sourcePicklistFieldApiName')), fields);

        String lookupTargetObject = normalizeApiName(stringValue(config.get('lookupTargetObject')));
        if (String.isNotBlank(lookupTargetObject)) {
            objects.add(lookupTargetObject);
            for (Object fieldValue : listValue(config.get('lookupSearchFields'))) {
                addQualifiedField(lookupTargetObject, stringValue(fieldValue), fields);
            }
            for (Object fieldValue : listValue(config.get('lookupDisplayFields'))) {
                addQualifiedField(lookupTargetObject, stringValue(fieldValue), fields);
            }
        }
    }

    private static void addQualifiedField(String objectApiName, String fieldApiName, Set<String> fields) {
        String normalizedObject = normalizeApiName(objectApiName);
        String normalizedField = normalizeFieldPath(fieldApiName);
        if (String.isBlank(normalizedObject) || String.isBlank(normalizedField)) {
            return;
        }
        if (normalizedField.contains('.')) {
            fields.add(normalizedField);
        } else {
            fields.add(normalizedObject + '.' + normalizedField);
        }
    }

    private static Map<String, Object> buildStrippedSummary() {
        return new Map<String, Object>{
            'recordIds' => true,
            'publishTokens' => true,
            'publicationState' => true,
            'runtimeUrls' => true,
            'ownerAuditIds' => true
        };
    }

    private static ImportPackage parseAndValidatePackage(String packageJson) {
        if (String.isBlank(packageJson)) {
            throw new AuraHandledException('Select a TwinaForms export file to import.');
        }
        Object raw;
        try {
            raw = JSON.deserializeUntyped(packageJson);
        } catch (Exception ex) {
            throw new AuraHandledException('This file is not valid JSON.');
        }
        if (!(raw instanceof Map<String, Object>)) {
            throw new AuraHandledException('This file is not a TwinaForms form export.');
        }
        Map<String, Object> packageMap = (Map<String, Object>) raw;
        ImportPackage parsed = new ImportPackage();
        parsed.rawJson = packageJson;
        parsed.packageMap = packageMap;
        parsed.schemaVersion = stringValue(packageMap.get('schemaVersion'));
        parsed.packageType = stringValue(packageMap.get('packageType'));
        parsed.globalFormKey = stringValue(packageMap.get('globalFormKey'));
        parsed.sourceOrgId = stringValue(packageMap.get('sourceOrgId'));
        parsed.sourceEnvironmentType = stringValue(packageMap.get('sourceEnvironmentType'));
        parsed.sourcePublishedUrl = stringValue(packageMap.get('sourcePublishedUrl'));

        if (parsed.schemaVersion != SCHEMA_VERSION_V1 && parsed.schemaVersion != SCHEMA_VERSION_V2) {
            throw new AuraHandledException('This export uses an unsupported TwinaForms schema.');
        }
        if (parsed.packageType != PACKAGE_TYPE) {
            throw new AuraHandledException('This file is not a TwinaForms form definition export.');
        }
        if (String.isBlank(parsed.globalFormKey)) {
            throw new AuraHandledException('This file cannot be imported because it does not include a TwinaForms form number.');
        }

        parsed.form = mapValue(packageMap.get('form'));
        parsed.version = mapValue(packageMap.get('version'));
        parsed.elements = mapListValue(packageMap.get('elements'));
        parsed.actions = mapListValue(packageMap.get('actions'));
        parsed.manifest = mapValue(packageMap.get('manifest'));
        parsed.theme = mapValue(packageMap.get('theme'));
        parsed.assets = listValue(packageMap.get('assets'));
        if (parsed.form == null || parsed.version == null || parsed.manifest == null) {
            throw new AuraHandledException('This export is missing required form, version, or manifest data.');
        }
        parsed.formDescription = stringValue(parsed.form.get('description'));
        parsed.securityMode = defaultSecurityMode(stringValue(parsed.version.get('securityMode')));
        parsed.rateLimitProfile = stringValue(parsed.version.get('rateLimitProfile'));
        parsed.customCss = stringValue(parsed.version.get('customCss'));
        parsed.customJs = stringValue(parsed.version.get('customJs'));
        parsed.themeJson = stringValue(parsed.version.get('themeJson'));
        parsed.uiSettingsJson = defaultJsonObject(stringValue(parsed.version.get('uiSettingsJson')));
        parsed.prefillParamsJson = defaultJsonArray(stringValue(parsed.version.get('prefillParamsJson')));
        return parsed;
    }

    private static Map<String, Object> buildPreview(ImportPackage parsed) {
        List<String> blockingErrors = new List<String>();
        List<String> warnings = new List<String>();
        List<String> missingObjects = new List<String>();
        List<String> missingFields = new List<String>();

        List<NF_Form__c> forms = queryFormsByKey(parsed.globalFormKey);
        if (forms.size() > 1) {
            blockingErrors.add('More than one local form uses this TwinaForms form number.');
        }
        String targetAction = forms.isEmpty() ? 'createForm' : 'createVersion';
        Id targetFormId = forms.isEmpty() ? null : forms[0].Id;
        String targetFormName = forms.isEmpty() ? null : forms[0].Description__c;
        if (!forms.isEmpty() && !sameText(forms[0].Description__c, parsed.formDescription)) {
            warnings.add('A form with this number already exists, but its description differs from the import file.');
        }
        if (String.isNotBlank(parsed.sourcePublishedUrl)) {
            warnings.add('The source published link is informational only and will not be copied.');
        }

        validateManifest(parsed.manifest, missingObjects, missingFields);
        for (String objectName : missingObjects) {
            blockingErrors.add('Missing target object: ' + objectName);
        }
        for (String fieldName : missingFields) {
            blockingErrors.add('Missing target field: ' + fieldName);
        }
        warnings.addAll(scanHiddenSourceReferences(parsed.rawJson));

        Map<String, Object> preview = new Map<String, Object>();
        preview.put('globalFormKey', parsed.globalFormKey);
        preview.put('schemaVersion', parsed.schemaVersion);
        preview.put('sourceOrgId', parsed.sourceOrgId);
        preview.put('sourceEnvironmentType', parsed.sourceEnvironmentType);
        preview.put('sourcePublishedUrl', parsed.sourcePublishedUrl);
        preview.put('targetAction', targetAction);
        preview.put('targetFormId', targetFormId);
        preview.put('targetFormName', targetFormName);
        preview.put('blockingErrors', blockingErrors);
        preview.put('warnings', warnings);
        preview.put('missingObjects', missingObjects);
        preview.put('missingFields', missingFields);
        Map<String, Object> themePreview = buildThemePreview(parsed);
        preview.put('themeAction', themePreview.get('action'));
        preview.put('imageAction', 'deferred');
        preview.put('themePreview', themePreview);
        preview.put('assetPreview', buildAssetPreview(parsed));
        preview.put('featurePreview', buildFeaturePreview(parsed));
        preview.put('limitPreview', buildLimitPreview(parsed));
        preview.put('targetProjectAction', forms.isEmpty() ? 'defaultGeneral' : 'keepExisting');
        preview.put('buttonTargetActions', new List<Object>());
        return preview;
    }

    private static Map<String, Object> buildThemePreview(ImportPackage parsed) {
        Map<String, Object> result = new Map<String, Object>();
        List<Object> messages = new List<Object>();
        List<Object> warnings = new List<Object>();
        String themeName = parsed.theme == null ? null : stringValue(parsed.theme.get('name'));
        String portableThemeKey = parsed.theme == null ? null : stringValue(parsed.theme.get('portableThemeKey'));
        if (!hasPortableTheme(parsed)) {
            result.put('action', 'useDefault');
            messages.add('No portable theme is included. The imported draft will use the target form default theme.');
        } else {
            NF_Theme__c matchingTheme = findThemeByPortableKey(portableThemeKey, themeName);
            if (matchingTheme == null) {
                result.put('action', 'createTheme');
                messages.add('Theme will be imported as a reusable Salesforce theme.');
            } else if (themeTokensMatch(matchingTheme, parsed.theme == null ? null : mapValue(parsed.theme.get('tokens')))) {
                result.put('action', 'reuseExisting');
                result.put('targetThemeId', matchingTheme.Id);
                result.put('targetThemeName', matchingTheme.Name);
                messages.add('Matching theme exists and will be reused.');
            } else {
                result.put('action', 'askAdmin');
                result.put('requiresAdminChoice', true);
                result.put('targetThemeId', matchingTheme.Id);
                result.put('targetThemeName', matchingTheme.Name);
                warnings.add('A theme with the same name exists but has different values.');
                messages.add('Choose whether to reuse the existing theme or create an imported copy.');
            }
        }
        result.put('name', themeName);
        result.put('portableThemeKey', portableThemeKey);
        result.put('messages', messages);
        result.put('blockingErrors', new List<Object>());
        result.put('warnings', warnings);
        return result;
    }

    private static Map<String, Object> buildAssetPreview(ImportPackage parsed) {
        List<Object> warnings = new List<Object>();
        List<Object> blockingErrors = new List<Object>();
        List<Object> messages = new List<Object>();
        List<Object> items = new List<Object>();
        Integer assetBytes = 0;
        Integer emptyImageCount = countEmptyImageElements(parsed);
        for (Object assetValue : parsed.assets) {
            Map<String, Object> asset = mapValue(assetValue);
            if (asset == null) {
                continue;
            }
            Integer sizeBytes = integerValue(asset.get('sizeBytes'));
            assetBytes += sizeBytes == null ? 0 : sizeBytes;
            String fileName = stringValue(asset.get('fileName'));
            String usage = stringValue(asset.get('usage'));
            items.add(String.isBlank(fileName) ? stringValue(asset.get('assetKey')) : fileName);
            String sourceUrl = stringValue(asset.get('sourceUrl'));
            if (isExternalUrl(sourceUrl)) {
                warnings.add('External images are not supported and will not be imported.');
            }
            if (sizeBytes != null && sizeBytes > MAX_EMBEDDED_IMAGE_BYTES) {
                warnings.add((String.isBlank(fileName) ? 'An image' : fileName) + ' is larger than the current 69 KB image limit.');
            }
        }
        if (parsed.assets.isEmpty()) {
            messages.add(emptyImageCount > 0
                ? 'No image files will be imported. Empty image placeholders will remain empty.'
                : 'No images or logos will be imported.');
        } else {
            messages.add(String.valueOf(parsed.assets.size()) + ' image/logo file' + (parsed.assets.size() == 1 ? '' : 's') + ' will be imported.');
        }
        if (emptyImageCount > 0) {
            messages.add(String.valueOf(emptyImageCount) + ' empty image placeholder' + (emptyImageCount == 1 ? '' : 's') + ' will remain empty.');
        }
        Map<String, Object> result = new Map<String, Object>();
        result.put('action', parsed.assets.isEmpty() ? 'none' : 'deferred');
        result.put('assetCount', parsed.assets.size());
        result.put('emptyImageCount', emptyImageCount);
        result.put('totalBytes', assetBytes);
        result.put('maxEmbeddedImageBytes', MAX_EMBEDDED_IMAGE_BYTES);
        result.put('messages', messages);
        result.put('items', items);
        result.put('warnings', warnings);
        result.put('blockingErrors', blockingErrors);
        return result;
    }

    private static Map<String, Object> buildFeaturePreview(ImportPackage parsed) {
        List<Object> features = listValue(parsed.manifest == null ? null : parsed.manifest.get('features'));
        List<Object> labels = new List<Object>();
        for (Object featureValue : features) {
            labels.add(featureLabel(stringValue(featureValue)));
        }
        List<Object> messages = new List<Object>();
        if (labels.isEmpty()) {
            messages.add('No special TwinaForms features were detected.');
        } else {
            messages.add('This form uses ' + String.valueOf(labels.size()) + ' TwinaForms feature' + (labels.size() == 1 ? '' : 's') + '.');
            messages.add('Import will create a Draft version. Review these settings before publishing.');
        }
        Map<String, Object> result = new Map<String, Object>();
        result.put('features', features);
        result.put('featureLabels', labels);
        result.put('messages', messages);
        result.put('warnings', new List<Object>());
        result.put('blockingErrors', new List<Object>());
        result.put('policy', 'warnOnly');
        return result;
    }

    private static Integer countEmptyImageElements(ImportPackage parsed) {
        Integer countValue = 0;
        for (Map<String, Object> elementMap : parsed.elements) {
            if (stringValue(elementMap.get('elementType')) != 'image') {
                continue;
            }
            Map<String, Object> config = mapValue(parseUntypedOrNull(stringValue(elementMap.get('configJson'))));
            if (config == null
                || (String.isBlank(stringValue(config.get('imageAssetKey')))
                    && String.isBlank(stringValue(config.get('contentVersionId')))
                    && String.isBlank(stringValue(config.get('contentDocumentId')))
                    && String.isBlank(stringValue(config.get('imageUrl'))))) {
                countValue++;
            }
        }
        return countValue;
    }

    private static String featureLabel(String feature) {
        if (feature == 'prefill') {
            return 'Prefill';
        }
        if (feature == 'submit') {
            return 'Submit';
        }
        if (feature == 'lookup') {
            return 'Lookup';
        }
        if (feature == 'userVerification') {
            return 'User Verification';
        }
        if (feature == 'imageElement') {
            return 'Image Elements';
        }
        if (feature == 'fileUpload') {
            return 'File Upload';
        }
        if (feature == 'buttonNavigation') {
            return 'Button Navigation';
        }
        if (feature == 'customJavaScript') {
            return 'Custom JavaScript';
        }
        return String.isBlank(feature) ? 'Unknown Feature' : feature;
    }

    private static Map<String, Object> buildLimitPreview(ImportPackage parsed) {
        Map<String, Object> limits = mapValue(parsed.manifest == null ? null : parsed.manifest.get('limits'));
        Integer elementCount = limits == null ? parsed.elements.size() : integerValue(limits.get('elementCount'));
        Integer actionCount = limits == null ? parsed.actions.size() : integerValue(limits.get('actionCount'));
        Integer assetCount = limits == null ? parsed.assets.size() : integerValue(limits.get('assetCount'));
        Integer assetBytes = limits == null ? 0 : integerValue(limits.get('assetBytes'));
        Map<String, Object> result = new Map<String, Object>();
        result.put('estimatedRecords', 2 + (elementCount == null ? 0 : elementCount) + (actionCount == null ? 0 : actionCount));
        result.put('elementCount', elementCount);
        result.put('actionCount', actionCount);
        result.put('assetCount', assetCount);
        result.put('assetBytes', assetBytes);
        result.put('warnings', new List<Object>());
        return result;
    }

    private static Id resolveImportedTheme(ImportPackage parsed, ImportOptions options, NF_Form__c targetForm) {
        String themeName = parsed.theme == null ? null : stringValue(parsed.theme.get('name'));
        if (!hasPortableTheme(parsed)) {
            return targetForm == null ? null : targetForm.Theme__c;
        }
        String portableThemeKey = parsed.theme == null ? null : stringValue(parsed.theme.get('portableThemeKey'));
        NF_Theme__c matchingTheme = findThemeByPortableKey(portableThemeKey, themeName);
        if (matchingTheme == null) {
            return createThemeFromPackage(parsed, false);
        }
        if (themeTokensMatch(matchingTheme, parsed.theme == null ? null : mapValue(parsed.theme.get('tokens')))) {
            return matchingTheme.Id;
        }
        if (options.themeConflictChoice == 'reuseExisting') {
            return matchingTheme.Id;
        }
        if (options.themeConflictChoice == 'createCopy') {
            return createThemeFromPackage(parsed, true);
        }
        throw new AuraHandledException('Choose how to handle the theme conflict before importing.');
    }

    private static Boolean hasPortableTheme(ImportPackage parsed) {
        if (parsed == null || parsed.schemaVersion != SCHEMA_VERSION_V2 || parsed.theme == null) {
            return false;
        }
        return String.isNotBlank(stringValue(parsed.theme.get('name')))
            || mapValue(parsed.theme.get('tokens')) != null;
    }

    private static NF_Theme__c findThemeByPortableKey(String portableThemeKey, String themeName) {
        String keyToMatch = String.isBlank(portableThemeKey) ? buildPortableThemeKey(themeName) : portableThemeKey;
        if (String.isBlank(keyToMatch)) {
            return null;
        }
        for (NF_Theme__c row : queryThemeRows()) {
            if (buildPortableThemeKey(row.Name) == keyToMatch) {
                return row;
            }
        }
        return null;
    }

    private static List<NF_Theme__c> queryThemeRows() {
        return [
            SELECT Id, Name, Description__c, Logo_URL__c, Logo_Content_Document_Id__c, Logo_Size_Px__c, Logo_Position__c,
                   Form_Width__c, Background_Color__c, Background_Gradient_Color__c, Form_Background_Color__c, Form_Border_Color__c,
                   Title_Font__c, Title_Font_Size_Px__c, Title_Text_Color__c,
                   Section_Title_Font__c, Section_Title_Font_Size_Px__c, Section_Title_Text_Color__c,
                   Main_Font__c, Main_Text_Size_Px__c, Main_Text_Color__c, Link_Text_Color__c, Hint_Text_Color__c, Error_Color__c,
                   Input_Border_Radius_Px__c, Input_Background_Color__c, Input_Border_Color__c,
                   Button_Font__c, Button_Font_Size_Px__c, Button_Text_Color__c, Button_Background_Color__c, Button_Hover_Background_Color__c
            FROM NF_Theme__c
            WITH USER_MODE
            ORDER BY CreatedDate ASC
            LIMIT 2000
        ];
    }

    private static Id createThemeFromPackage(ImportPackage parsed, Boolean importedCopy) {
        Map<String, Object> tokens = parsed.theme == null ? null : mapValue(parsed.theme.get('tokens'));
        NF_Theme__c row = new NF_Theme__c();
        String themeName = parsed.theme == null ? null : stringValue(parsed.theme.get('name'));
        row.Name = String.isBlank(themeName) ? 'Imported Theme' : themeName + (importedCopy ? ' (Imported Copy)' : '');
        row.Description__c = parsed.theme == null ? null : stringValue(parsed.theme.get('description'));
        row.Logo_Size_Px__c = decimalValue(parsed.theme == null ? null : parsed.theme.get('logoSizePx'));
        row.Logo_Position__c = stringValue(parsed.theme == null ? null : parsed.theme.get('logoPosition'));
        applyThemeTokens(row, tokens);
        insert as user row;
        return row.Id;
    }

    private static void applyThemeTokens(NF_Theme__c row, Map<String, Object> tokens) {
        if (tokens == null) {
            return;
        }
        row.Form_Width__c = stringValue(tokens.get('formWidth'));
        row.Background_Color__c = stringValue(tokens.get('backgroundColor'));
        row.Background_Gradient_Color__c = stringValue(tokens.get('backgroundGradientColor'));
        row.Form_Background_Color__c = stringValue(tokens.get('formBackgroundColor'));
        row.Form_Border_Color__c = stringValue(tokens.get('formBorderColor'));
        row.Title_Font__c = stringValue(tokens.get('titleFont'));
        row.Title_Font_Size_Px__c = decimalValue(tokens.get('titleFontSizePx'));
        row.Title_Text_Color__c = stringValue(tokens.get('titleTextColor'));
        row.Section_Title_Font__c = stringValue(tokens.get('sectionTitleFont'));
        row.Section_Title_Font_Size_Px__c = decimalValue(tokens.get('sectionTitleFontSizePx'));
        row.Section_Title_Text_Color__c = stringValue(tokens.get('sectionTitleTextColor'));
        row.Main_Font__c = stringValue(tokens.get('mainFont'));
        row.Main_Text_Size_Px__c = decimalValue(tokens.get('mainTextSizePx'));
        row.Main_Text_Color__c = stringValue(tokens.get('mainTextColor'));
        row.Link_Text_Color__c = stringValue(tokens.get('linkTextColor'));
        row.Hint_Text_Color__c = stringValue(tokens.get('hintTextColor'));
        row.Error_Color__c = stringValue(tokens.get('errorColor'));
        row.Input_Border_Radius_Px__c = decimalValue(tokens.get('inputBorderRadiusPx'));
        row.Input_Background_Color__c = stringValue(tokens.get('inputBackgroundColor'));
        row.Input_Border_Color__c = stringValue(tokens.get('inputBorderColor'));
        row.Button_Font__c = stringValue(tokens.get('buttonFont'));
        row.Button_Font_Size_Px__c = decimalValue(tokens.get('buttonFontSizePx'));
        row.Button_Text_Color__c = stringValue(tokens.get('buttonTextColor'));
        row.Button_Background_Color__c = stringValue(tokens.get('buttonBackgroundColor'));
        row.Button_Hover_Background_Color__c = stringValue(tokens.get('buttonHoverBackgroundColor'));
    }

    private static Boolean themeTokensMatch(NF_Theme__c themeRow, Map<String, Object> tokens) {
        if (themeRow == null || tokens == null) {
            return false;
        }
        return sameScalar(themeRow.Form_Width__c, tokens.get('formWidth'))
            && sameScalar(themeRow.Background_Color__c, tokens.get('backgroundColor'))
            && sameScalar(themeRow.Background_Gradient_Color__c, tokens.get('backgroundGradientColor'))
            && sameScalar(themeRow.Form_Background_Color__c, tokens.get('formBackgroundColor'))
            && sameScalar(themeRow.Form_Border_Color__c, tokens.get('formBorderColor'))
            && sameScalar(themeRow.Title_Font__c, tokens.get('titleFont'))
            && sameScalar(themeRow.Title_Font_Size_Px__c, tokens.get('titleFontSizePx'))
            && sameScalar(themeRow.Title_Text_Color__c, tokens.get('titleTextColor'))
            && sameScalar(themeRow.Section_Title_Font__c, tokens.get('sectionTitleFont'))
            && sameScalar(themeRow.Section_Title_Font_Size_Px__c, tokens.get('sectionTitleFontSizePx'))
            && sameScalar(themeRow.Section_Title_Text_Color__c, tokens.get('sectionTitleTextColor'))
            && sameScalar(themeRow.Main_Font__c, tokens.get('mainFont'))
            && sameScalar(themeRow.Main_Text_Size_Px__c, tokens.get('mainTextSizePx'))
            && sameScalar(themeRow.Main_Text_Color__c, tokens.get('mainTextColor'))
            && sameScalar(themeRow.Link_Text_Color__c, tokens.get('linkTextColor'))
            && sameScalar(themeRow.Hint_Text_Color__c, tokens.get('hintTextColor'))
            && sameScalar(themeRow.Error_Color__c, tokens.get('errorColor'))
            && sameScalar(themeRow.Input_Border_Radius_Px__c, tokens.get('inputBorderRadiusPx'))
            && sameScalar(themeRow.Input_Background_Color__c, tokens.get('inputBackgroundColor'))
            && sameScalar(themeRow.Input_Border_Color__c, tokens.get('inputBorderColor'))
            && sameScalar(themeRow.Button_Font__c, tokens.get('buttonFont'))
            && sameScalar(themeRow.Button_Font_Size_Px__c, tokens.get('buttonFontSizePx'))
            && sameScalar(themeRow.Button_Text_Color__c, tokens.get('buttonTextColor'))
            && sameScalar(themeRow.Button_Background_Color__c, tokens.get('buttonBackgroundColor'))
            && sameScalar(themeRow.Button_Hover_Background_Color__c, tokens.get('buttonHoverBackgroundColor'));
    }

    private static Boolean sameScalar(Object leftValue, Object rightValue) {
        if (leftValue == null && rightValue == null) {
            return true;
        }
        if (leftValue == null || rightValue == null) {
            return false;
        }
        Decimal leftDecimal = decimalValue(leftValue);
        Decimal rightDecimal = decimalValue(rightValue);
        if (leftDecimal != null && rightDecimal != null) {
            return leftDecimal == rightDecimal;
        }
        return String.valueOf(leftValue).trim() == String.valueOf(rightValue).trim();
    }

    private static Map<String, Map<String, Object>> importAssets(ImportPackage parsed, Id versionId, Id themeId) {
        Map<String, Map<String, Object>> referencesByAssetKey = new Map<String, Map<String, Object>>();
        List<NF_Theme__c> themesToUpdate = new List<NF_Theme__c>();
        for (Object assetValue : parsed.assets) {
            Map<String, Object> asset = mapValue(assetValue);
            if (asset == null) {
                continue;
            }
            String assetKey = stringValue(asset.get('assetKey'));
            String base64Value = stringValue(asset.get('base64'));
            if (String.isBlank(assetKey) || String.isBlank(base64Value)) {
                continue;
            }
            Blob assetBlob = EncodingUtil.base64Decode(base64Value);
            if (assetBlob.size() > MAX_EMBEDDED_IMAGE_BYTES) {
                throw new AuraHandledException('Image is larger than the current embedded image upload limit.');
            }
            String usage = stringValue(asset.get('usage'));
            Id publishLocationId = usage == 'logo' && themeId != null ? themeId : versionId;
            ContentVersion versionRecord = new ContentVersion(
                Title = titleFromFileName(stringValue(asset.get('fileName'))),
                PathOnClient = blankToDefault(stringValue(asset.get('fileName')), assetKey + '.png'),
                VersionData = assetBlob,
                FirstPublishLocationId = publishLocationId
            );
            insert as user versionRecord;
            versionRecord = [
                SELECT Id, ContentDocumentId
                FROM ContentVersion
                WHERE Id = :versionRecord.Id
                WITH USER_MODE
                LIMIT 1
            ];
            Map<String, Object> reference = new Map<String, Object>();
            reference.put('contentVersionId', String.valueOf(versionRecord.Id));
            reference.put('contentDocumentId', String.valueOf(versionRecord.ContentDocumentId));
            reference.put('imageUrl', buildContentVersionUrl(versionRecord.Id));
            reference.put('fileName', stringValue(asset.get('fileName')));
            referencesByAssetKey.put(assetKey, reference);
            if (usage == 'logo' && themeId != null) {
                themesToUpdate.add(new NF_Theme__c(
                    Id = themeId,
                    Logo_Content_Document_Id__c = String.valueOf(versionRecord.ContentDocumentId),
                    Logo_URL__c = buildContentVersionUrl(versionRecord.Id)
                ));
            }
        }
        if (!themesToUpdate.isEmpty()) {
            update as user themesToUpdate;
        }
        return referencesByAssetKey;
    }

    private static String rewriteElementConfigForImportedAssets(
        Map<String, Object> elementMap,
        Map<String, Map<String, Object>> importedAssetReferences
    ) {
        Map<String, Object> config = mapValue(parseUntypedOrNull(stringValue(elementMap.get('configJson'))));
        if (config == null) {
            return defaultJsonObject(stringValue(elementMap.get('configJson')));
        }
        String assetKey = stringValue(config.get('imageAssetKey'));
        Map<String, Object> reference = importedAssetReferences.get(assetKey);
        if (reference != null) {
            config.put('contentVersionId', reference.get('contentVersionId'));
            config.put('contentDocumentId', reference.get('contentDocumentId'));
            config.put('imageUrl', reference.get('imageUrl'));
            if (String.isBlank(stringValue(config.get('fileName')))) {
                config.put('fileName', reference.get('fileName'));
            }
            config.remove('imageAssetKey');
        } else if (isExternalUrl(stringValue(config.get('imageUrl')))) {
            config.put('imageUrl', '');
            config.remove('contentVersionId');
            config.remove('contentDocumentId');
            config.remove('publishedAssetUrl');
        }
        return JSON.serializePretty(config);
    }

    private static List<NF_Form__c> queryFormsByKey(String globalFormKey) {
        return [
            SELECT Id, Description__c, NF_Key__c, Project__c, Theme__c, Current_Draft_Version__c, Current_Published_Version__c
            FROM NF_Form__c
            WHERE NF_Key__c = :globalFormKey
            WITH USER_MODE
            ORDER BY CreatedDate ASC
            LIMIT 2
        ];
    }

    private static Decimal nextVersionNumber(Id formId) {
        AggregateResult versionAggregate = [
            SELECT MAX(Version_Number__c) maxVersion
            FROM NF_Form_Version__c
            WHERE Form__c = :formId
            WITH USER_MODE
        ];
        Decimal maxVersion = (Decimal) versionAggregate.get('maxVersion');
        return maxVersion == null ? 1 : maxVersion + 1;
    }

    private static void validateManifest(Map<String, Object> manifest, List<String> missingObjects, List<String> missingFields) {
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        for (String objectName : objectManifestValues(manifest.get('objects'))) {
            if (!globalDescribe.containsKey(objectName)) {
                missingObjects.add(objectName);
            }
        }
        for (String fieldRef : objectManifestValues(manifest.get('fields'))) {
            Integer dotIndex = fieldRef == null ? -1 : fieldRef.indexOf('.');
            if (dotIndex <= 0 || dotIndex >= fieldRef.length() - 1) {
                missingFields.add(fieldRef);
                continue;
            }
            String objectName = fieldRef.substring(0, dotIndex);
            String fieldName = fieldRef.substring(dotIndex + 1);
            if (!globalDescribe.containsKey(objectName)) {
                missingFields.add(fieldRef);
                continue;
            }
            Map<String, Schema.SObjectField> fields = globalDescribe.get(objectName).getDescribe().fields.getMap();
            if (!fields.containsKey(fieldName)) {
                missingFields.add(fieldRef);
            }
        }
    }

    private static void collectMetadataReferences(String jsonText, Set<String> objects, Set<String> fields) {
        Object raw = parseUntypedOrNull(jsonText);
        collectMetadataReferencesFromValue(raw, objects, fields);
    }

    private static void collectMetadataReferencesFromValue(Object value, Set<String> objects, Set<String> fields) {
        if (value instanceof Map<String, Object>) {
            Map<String, Object> valueMap = (Map<String, Object>) value;
            for (String key : valueMap.keySet()) {
                Object child = valueMap.get(key);
                String childText = stringValue(child);
                String lowerKey = key == null ? '' : key.toLowerCase();
                if (String.isNotBlank(childText)) {
                    if ((lowerKey.contains('object') || lowerKey == 'sobject') && isApiName(childText)) {
                        objects.add(childText);
                    }
                    if ((lowerKey.contains('field') || lowerKey.contains('api')) && childText.contains('.')) {
                        fields.add(childText);
                    }
                }
                collectMetadataReferencesFromValue(child, objects, fields);
            }
        } else if (value instanceof List<Object>) {
            for (Object child : (List<Object>) value) {
                collectMetadataReferencesFromValue(child, objects, fields);
            }
        }
    }

    private static List<String> scanHiddenSourceReferences(String text) {
        List<String> warnings = new List<String>();
        if (String.isBlank(text)) {
            return warnings;
        }
        if (text.contains('/sfc/servlet.shepherd')) {
            warnings.add('The import contains source Salesforce file URLs that need target-org review.');
        }
        if (text.contains('.my.salesforce.com') || text.contains('.lightning.force.com')) {
            warnings.add('The import contains Salesforce org URLs that may be environment-specific.');
        }
        if (text.contains('forms.twinaforms.com') || text.contains('s3.amazonaws.com')) {
            warnings.add('The import contains published/runtime URLs that are informational only.');
        }
        return warnings;
    }

    private static Boolean isExternalUrl(String value) {
        String text = stringValue(value);
        if (String.isBlank(text)) {
            return false;
        }
        text = text.toLowerCase();
        return text.startsWith('http://') || text.startsWith('https://');
    }

    private static String buildPortableThemeKey(String themeName) {
        String normalized = stringValue(themeName);
        if (String.isBlank(normalized)) {
            return null;
        }
        normalized = normalized.trim().toLowerCase();
        normalized = normalized.replaceAll('[^a-z0-9]+', '-');
        normalized = normalized.replaceAll('^-+', '').replaceAll('-+$', '');
        return String.isBlank(normalized) ? null : normalized;
    }

    private static String normalizeImportException(Exception ex) {
        String message = ex == null ? '' : ex.getMessage();
        String lowerMessage = message == null ? '' : message.toLowerCase();
        if (lowerMessage.contains('storage limit exceeded')) {
            return 'Salesforce Data Storage is full. Import cannot create the draft until data records are deleted or storage is increased.';
        }
        if (String.isBlank(message)) {
            return 'Import failed. Please review the file and try again.';
        }
        return message;
    }

    private static ImportOptions parseOptions(String optionsJson) {
        ImportOptions options = new ImportOptions();
        if (String.isBlank(optionsJson)) {
            return options;
        }
        Object raw = parseUntypedOrNull(optionsJson);
        if (!(raw instanceof Map<String, Object>)) {
            return options;
        }
        Map<String, Object> optionsMap = (Map<String, Object>) raw;
        String projectIdText = stringValue(optionsMap.get('projectId'));
        if (String.isNotBlank(projectIdText)) {
            options.projectId = (Id) projectIdText;
        }
        options.themeConflictChoice = stringValue(optionsMap.get('themeConflictChoice'));
        return options;
    }

    private static Object parseUntypedOrNull(String jsonText) {
        if (String.isBlank(jsonText)) {
            return null;
        }
        try {
            return JSON.deserializeUntyped(jsonText);
        } catch (Exception ex) {
            return null;
        }
    }

    private static List<String> objectManifestValues(Object value) {
        List<String> results = new List<String>();
        if (value instanceof List<Object>) {
            for (Object item : (List<Object>) value) {
                String text = stringValue(item);
                if (String.isNotBlank(text)) {
                    results.add(text.trim());
                }
            }
        }
        return results;
    }

    private static Map<String, Object> mapValue(Object value) {
        return value instanceof Map<String, Object> ? (Map<String, Object>) value : null;
    }

    private static List<Object> listValue(Object value) {
        return value instanceof List<Object> ? (List<Object>) value : new List<Object>();
    }

    private static List<Map<String, Object>> mapListValue(Object value) {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        if (!(value instanceof List<Object>)) {
            return results;
        }
        for (Object item : (List<Object>) value) {
            if (item instanceof Map<String, Object>) {
                results.add((Map<String, Object>) item);
            }
        }
        return results;
    }

    private static List<String> sortedStrings(Set<String> values) {
        List<String> results = new List<String>();
        for (String value : values) {
            if (String.isNotBlank(value)) {
                results.add(value);
            }
        }
        results.sort();
        return results;
    }

    private static List<String> stringList(Object value) {
        List<String> results = new List<String>();
        if (value instanceof List<String>) {
            return (List<String>) value;
        }
        if (value instanceof List<Object>) {
            for (Object item : (List<Object>) value) {
                results.add(stringValue(item));
            }
        }
        return results;
    }

    private static String stringValue(Object value) {
        if (value == null) {
            return null;
        }
        String text = String.valueOf(value);
        return String.isBlank(text) ? null : text;
    }

    private static Boolean sameText(String leftValue, String rightValue) {
        return String.valueOf(leftValue).trim() == String.valueOf(rightValue).trim();
    }

    private static Boolean isApiName(String value) {
        return String.isNotBlank(value) && Pattern.compile('[A-Za-z_][A-Za-z0-9_]*(?:__[a-zA-Z])?').matcher(value).matches();
    }

    private static Id idValue(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return (Id) value;
        } catch (Exception ex) {
            return null;
        }
    }

    private static String normalizeApiName(String value) {
        String normalized = stringValue(value);
        return isApiName(normalized) ? normalized.trim() : null;
    }

    private static String normalizeFieldPath(String value) {
        String normalized = stringValue(value);
        if (String.isBlank(normalized)) {
            return null;
        }
        normalized = normalized.trim();
        if (normalized == 'Id') {
            return normalized;
        }
        if (normalized.contains('.')) {
            List<String> parts = normalized.split('\\.');
            return parts.size() == 2 && isApiName(parts[0]) && isApiName(parts[1]) ? normalized : null;
        }
        return isApiName(normalized) ? normalized : null;
    }

    private static Integer integerValue(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Integer) {
            return (Integer) value;
        }
        if (value instanceof Decimal) {
            return ((Decimal) value).intValue();
        }
        try {
            return Integer.valueOf(String.valueOf(value));
        } catch (Exception ex) {
            return null;
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

    private static Decimal decimalValue(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof Decimal) {
            return (Decimal) value;
        }
        try {
            return Decimal.valueOf(String.valueOf(value));
        } catch (Exception ex) {
            return null;
        }
    }

    private static String defaultSecurityMode(String value) {
        return String.isBlank(value) ? 'secure-edit' : value;
    }

    private static String defaultJsonObject(String value) {
        return String.isBlank(value) ? '{}' : value;
    }

    private static String defaultJsonArray(String value) {
        return String.isBlank(value) ? '[]' : value;
    }

    private static String blankToDefault(String value, String defaultValue) {
        return String.isBlank(value) ? defaultValue : value;
    }

    private static String buildContentVersionUrl(Id contentVersionId) {
        return '/sfc/servlet.shepherd/version/download/' + String.valueOf(contentVersionId);
    }

    private static String titleFromFileName(String fileName) {
        String source = stringValue(fileName);
        if (String.isBlank(source)) {
            return 'TwinaForms Image';
        }
        Integer slashIndex = Math.max(source.lastIndexOf('/'), source.lastIndexOf('\\'));
        if (slashIndex >= 0 && slashIndex < source.length() - 1) {
            source = source.substring(slashIndex + 1);
        }
        Integer dotIndex = source.lastIndexOf('.');
        return dotIndex > 0 ? source.substring(0, dotIndex) : source;
    }

    private static String mimeTypeFromFileName(String fileName) {
        String source = stringValue(fileName);
        String lowerName = source == null ? '' : source.toLowerCase();
        if (lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')) {
            return 'image/jpeg';
        }
        if (lowerName.endsWith('.webp')) {
            return 'image/webp';
        }
        if (lowerName.endsWith('.gif')) {
            return 'image/gif';
        }
        if (lowerName.endsWith('.svg')) {
            return 'image/svg+xml';
        }
        return 'image/png';
    }

    private class ExportAssetContext {
        List<Object> assets = new List<Object>();
        Map<String, String> assetKeyByElementId = new Map<String, String>();
        Integer assetBytes = 0;
        List<String> exportWarnings = new List<String>();
    }

    private class ImportPackage {
        String rawJson;
        Map<String, Object> packageMap;
        String schemaVersion;
        String packageType;
        String globalFormKey;
        String sourceOrgId;
        String sourceEnvironmentType;
        String sourcePublishedUrl;
        Map<String, Object> form;
        Map<String, Object> version;
        List<Map<String, Object>> elements;
        List<Map<String, Object>> actions;
        Map<String, Object> manifest;
        Map<String, Object> theme;
        List<Object> assets;
        String formDescription;
        String securityMode;
        String rateLimitProfile;
        String customCss;
        String customJs;
        String themeJson;
        String uiSettingsJson;
        String prefillParamsJson;
    }

    private class ImportOptions {
        Id projectId;
        String themeConflictChoice;
    }
}
