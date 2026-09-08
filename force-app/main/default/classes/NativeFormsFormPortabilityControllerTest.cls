@IsTest
private class NativeFormsFormPortabilityControllerTest {
    @TestSetup
    static void setupPermissions() {
        assignTwinaFormsUserPermissionSet();
    }

    @IsTest
    static void exportIncludesPortableContractAndStripsRuntimeArtifacts() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Portable Contact Form', null, 'form22');
        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createVersion(
            formRecord.Id,
            1,
            'Draft',
            'Never Published',
            NativeFormsTestConfigFactory.basicUiSettingsJson()
        );
        update new NF_Form_Version__c(
            Id = versionRecord.Id,
            Form_Id__c = 'runtime-form-22',
            Publish_Token__c = 'secret-token-22',
            Custom_JS__c = 'console.log("00Q000000000001AAA");',
            UI_Settings_JSON__c = '{"userVerificationEnabled":true}'
        );
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, versionRecord.Id, null);
        NativeFormsTestDataFactory.createElement(
            versionRecord.Id,
            'text',
            'Last Name',
            'lastName',
            1,
            10,
            '{"prefillAlias":"Prefill_Contact","prefillFieldPath":"LastName","prefillEnabled":true,"submitActionKey":"submitContact","submitFieldPath":"LastName","submitEnabled":true}',
            null
        );
        NativeFormsTestDataFactory.createElement(
            versionRecord.Id,
            'lookup',
            'Account Name',
            'accountId',
            2,
            20,
            '{"lookupTargetObject":"Account","lookupSearchFields":["Name"],"lookupDisplayFields":["Name"],"submitActionKey":"submitContact","submitFieldPath":"AccountId"}',
            null
        );
        NativeFormsTestDataFactory.createAction(
            versionRecord.Id,
            'Prefill',
            'Contact',
            'prefillContact',
            'Prefill_Contact',
            'findOne',
            5,
            '{"conditions":[{"fieldApiName":"Id","valueSource":"param","valueText":"recordId","operator":"eq"}]}'
        );
        NativeFormsTestDataFactory.createAction(
            versionRecord.Id,
            'Submit',
            'Contact',
            'submitContact',
            'ContactResult',
            'create',
            10,
            '{"fieldMappings":[{"targetField":"Contact.LastName","sourceFieldKey":"lastName"}]}'
        );

        Test.startTest();
        String packageJson = NativeFormsFormPortabilityController.exportForm(formRecord.Id, versionRecord.Id);
        Test.stopTest();

        Map<String, Object> packageMap = (Map<String, Object>) JSON.deserializeUntyped(packageJson);
        System.assertEquals('linked-env-portable-form-v2', packageMap.get('schemaVersion'));
        System.assertEquals('twinaformsFormDefinition', packageMap.get('packageType'));
        System.assertEquals('form22', packageMap.get('globalFormKey'));
        System.assert(!packageJson.contains('runtime-form-22'), 'Runtime form id must not export.');
        System.assert(!packageJson.contains('secret-token-22'), 'Publish token must not export.');
        System.assert(packageJson.contains('Contact.LastName'), 'Portable field reference should export.');
        Map<String, Object> manifest = (Map<String, Object>) packageMap.get('manifest');
        List<Object> manifestObjects = (List<Object>) manifest.get('objects');
        List<Object> manifestFields = (List<Object>) manifest.get('fields');
        System.assert(manifestObjects.contains('Contact'), 'Contact object dependency should export.');
        System.assert(manifestObjects.contains('Account'), 'Lookup object dependency should export.');
        System.assert(manifestFields.contains('Contact.Id'), 'Prefill condition field should export.');
        System.assert(manifestFields.contains('Contact.LastName'), 'Prefill/submit field should export.');
        System.assert(manifestFields.contains('Contact.AccountId'), 'Lookup submit field should export.');
        System.assert(manifestFields.contains('Account.Name'), 'Lookup display/search field should export.');
        List<Object> features = (List<Object>) manifest.get('features');
        System.assert(features.contains('lookup'), 'Lookup feature should export.');
        System.assert(features.contains('prefill'), 'Prefill feature should export.');
        System.assert(features.contains('submit'), 'Submit feature should export.');
        System.assert(features.contains('userVerification'), 'User Verification feature should export.');
        System.assert(features.contains('customJavaScript'), 'Custom JavaScript feature should export.');
        Map<String, Object> limits = (Map<String, Object>) manifest.get('limits');
        System.assertEquals(2, limits.get('elementCount'));
        System.assertEquals(2, limits.get('actionCount'));
        System.assertEquals(70656, limits.get('maxEmbeddedImageBytes'));
        }
    }

    @IsTest
    static void exportIncludesReusableThemeFoundation() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        NF_Theme__c themeRecord = NativeFormsTestDataFactory.createTheme('Portable Theme');
        update new NF_Theme__c(
            Id = themeRecord.Id,
            Logo_URL__c = '/sfc/servlet.shepherd/version/download/068000000000001',
            Logo_Content_Document_Id__c = '069000000000001',
            Background_Image_URL__c = '/sfc/servlet.shepherd/version/download/068000000000002',
            Background_Image_Content_Document_Id__c = '069000000000002',
            Footer_Image_URL__c = '/sfc/servlet.shepherd/version/download/068000000000003',
            Footer_Image_Content_Document_Id__c = '069000000000003',
            Button_Background_Color__c = '#117ACA'
        );
        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Themed Portable Form', null, 'form23');
        update new NF_Form__c(
            Id = formRecord.Id,
            Theme__c = themeRecord.Id
        );
        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createVersion(
            formRecord.Id,
            1,
            'Draft',
            'Never Published',
            NativeFormsTestConfigFactory.basicUiSettingsJson()
        );
        update new NF_Form_Version__c(
            Id = versionRecord.Id,
            Theme_JSON__c = '{"legacyTheme":true}'
        );
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, versionRecord.Id, null);

        Test.startTest();
        String packageJson = NativeFormsFormPortabilityController.exportForm(formRecord.Id, versionRecord.Id);
        Test.stopTest();

        Map<String, Object> packageMap = (Map<String, Object>) JSON.deserializeUntyped(packageJson);
        Map<String, Object> theme = (Map<String, Object>) packageMap.get('theme');
        System.assertEquals('Portable Theme', theme.get('name'));
        System.assertEquals('portable-theme', theme.get('portableThemeKey'));
        System.assertEquals('{"legacyTheme":true}', theme.get('versionThemeJson'));
        System.assertEquals(null, theme.get('logoUrl'), 'Source org logo URLs should not export as runtime references.');
        System.assertEquals(null, theme.get('logoContentDocumentId'), 'Source org logo file ids should not export as target references.');
        System.assertEquals(null, theme.get('backgroundImageUrl'), 'Source org background image URLs should not export as runtime references.');
        System.assertEquals(null, theme.get('backgroundImageContentDocumentId'), 'Source org background image file ids should not export as target references.');
        System.assertEquals(null, theme.get('footerImageUrl'), 'Source org footer image URLs should not export as runtime references.');
        System.assertEquals(null, theme.get('footerImageContentDocumentId'), 'Source org footer image file ids should not export as target references.');
        Map<String, Object> tokens = (Map<String, Object>) theme.get('tokens');
        System.assertEquals('#117ACA', tokens.get('buttonBackgroundColor'));
        Map<String, Object> manifest = (Map<String, Object>) packageMap.get('manifest');
        System.assert(((List<Object>) manifest.get('themes')).contains('portable-theme'));
        }
    }

    @IsTest
    static void exportRemovesInactivePostSubmitUrlTemplate() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Inactive Redirect Form', null, 'form25');
        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createVersion(
            formRecord.Id,
            1,
            'Draft',
            'Never Published',
            '{"postSubmitAutoLinkEnabled":false,"postSubmitUrlTemplate":"https://forms.twinaforms.com/formX/?param1=","submitLabel":"Submit"}'
        );
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, versionRecord.Id, null);

        Test.startTest();
        String packageJson = NativeFormsFormPortabilityController.exportForm(formRecord.Id, versionRecord.Id);
        Test.stopTest();

        Map<String, Object> packageMap = (Map<String, Object>) JSON.deserializeUntyped(packageJson);
        Map<String, Object> versionMap = (Map<String, Object>) packageMap.get('version');
        Map<String, Object> uiSettings = (Map<String, Object>) JSON.deserializeUntyped((String) versionMap.get('uiSettingsJson'));
        System.assertEquals(false, uiSettings.get('postSubmitAutoLinkEnabled'));
        System.assertEquals(null, uiSettings.get('postSubmitUrlTemplate'));
        System.assert(!packageJson.contains('https://forms.twinaforms.com/formX/?param1='));
        }
    }

    @IsTest
    static void exportKeepsActivePostSubmitUrlTemplate() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Active Redirect Form', null, 'form26');
        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createVersion(
            formRecord.Id,
            1,
            'Draft',
            'Never Published',
            '{"postSubmitAutoLinkEnabled":true,"postSubmitUrlTemplate":"https://forms.twinaforms.com/formX/?param1=","submitLabel":"Submit"}'
        );
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, versionRecord.Id, null);

        Test.startTest();
        String packageJson = NativeFormsFormPortabilityController.exportForm(formRecord.Id, versionRecord.Id);
        Test.stopTest();

        Map<String, Object> packageMap = (Map<String, Object>) JSON.deserializeUntyped(packageJson);
        Map<String, Object> versionMap = (Map<String, Object>) packageMap.get('version');
        Map<String, Object> uiSettings = (Map<String, Object>) JSON.deserializeUntyped((String) versionMap.get('uiSettingsJson'));
        System.assertEquals(true, uiSettings.get('postSubmitAutoLinkEnabled'));
        System.assertEquals('https://forms.twinaforms.com/formX/?param1=', uiSettings.get('postSubmitUrlTemplate'));
        }
    }

    @IsTest
    static void exportEmbedsUploadedImageElementAsAsset() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Image Portable Form', null, 'form24');
        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createVersion(
            formRecord.Id,
            1,
            'Draft',
            'Never Published',
            NativeFormsTestConfigFactory.basicUiSettingsJson()
        );
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, versionRecord.Id, null);
        ContentVersion imageVersion = new ContentVersion(
            Title = 'signature1',
            PathOnClient = 'signature1.png',
            VersionData = Blob.valueOf('pngdata'),
            FirstPublishLocationId = versionRecord.Id
        );
        insert imageVersion;
        imageVersion = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :imageVersion.Id
            LIMIT 1
        ];
        NativeFormsTestDataFactory.createElement(
            versionRecord.Id,
            'image',
            'Image',
            'image1',
            1,
            10,
            JSON.serialize(new Map<String, Object>{
                'fileName' => 'signature1.png',
                'contentVersionId' => String.valueOf(imageVersion.Id),
                'contentDocumentId' => String.valueOf(imageVersion.ContentDocumentId),
                'imageUrl' => '/sfc/servlet.shepherd/version/download/' + String.valueOf(imageVersion.Id),
                'altText' => 'Signature'
            }),
            null
        );

        Test.startTest();
        String packageJson = NativeFormsFormPortabilityController.exportForm(formRecord.Id, versionRecord.Id);
        Test.stopTest();

        Map<String, Object> packageMap = (Map<String, Object>) JSON.deserializeUntyped(packageJson);
        List<Object> assets = (List<Object>) packageMap.get('assets');
        System.assertEquals(1, assets.size(), 'Uploaded image should become a portable asset.');
        Map<String, Object> asset = (Map<String, Object>) assets[0];
        System.assertEquals('imageElement', asset.get('usage'));
        System.assertEquals('signature1.png', asset.get('fileName'));
        System.assertEquals(EncodingUtil.base64Encode(Blob.valueOf('pngdata')), asset.get('base64'));
        Map<String, Object> manifest = (Map<String, Object>) packageMap.get('manifest');
        Map<String, Object> limits = (Map<String, Object>) manifest.get('limits');
        System.assertEquals(1, limits.get('assetCount'));
        List<Object> elements = (List<Object>) packageMap.get('elements');
        Map<String, Object> exportedElement = (Map<String, Object>) elements[0];
        Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped((String) exportedElement.get('configJson'));
        System.assertEquals(asset.get('assetKey'), config.get('imageAssetKey'));
        System.assertEquals(null, config.get('contentVersionId'));
        System.assertEquals(null, config.get('contentDocumentId'));
        System.assertEquals('', config.get('imageUrl'));
        }
    }

    @IsTest
    static void importCreatesSalesforceFileForPortableImageAsset() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        String packageJson = buildMinimalPackage('form52', 'Imported Image Asset Form');
        Map<String, Object> packageMap = (Map<String, Object>) JSON.deserializeUntyped(packageJson);
        packageMap.put('schemaVersion', 'linked-env-portable-form-v2');
        List<Object> elements = (List<Object>) packageMap.get('elements');
        Map<String, Object> imageElement = new Map<String, Object>{
            'elementId' => 'image-1',
            'elementType' => 'image',
            'fieldKey' => 'image1',
            'label' => 'Image',
            'configJson' => '{"imageAssetKey":"image-image-1","imageUrl":"","altText":"Signature"}',
            'parentElementId' => null,
            'order' => 20
        };
        elements.add(imageElement);
        packageMap.put('assets', new List<Object>{
            new Map<String, Object>{
                'assetKey' => 'image-image-1',
                'usage' => 'imageElement',
                'elementId' => 'image-1',
                'fileName' => 'signature1.png',
                'contentType' => 'image/png',
                'base64' => EncodingUtil.base64Encode(Blob.valueOf('pngdata')),
                'sizeBytes' => 7
            }
        });
        Map<String, Object> manifest = (Map<String, Object>) packageMap.get('manifest');
        manifest.put('features', new List<Object>{ 'submit', 'imageElement' });
        manifest.put('assets', new List<Object>{ 'image-image-1' });
        manifest.put('limits', new Map<String, Object>{
            'elementCount' => 2,
            'actionCount' => 1,
            'assetCount' => 1,
            'assetBytes' => 7
        });
        packageJson = JSON.serialize(packageMap);

        Test.startTest();
        String resultJson = NativeFormsFormPortabilityController.importForm(packageJson, null);
        Test.stopTest();

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(resultJson);
        Id importedVersionId = (Id) String.valueOf(result.get('versionId'));
        NF_Form_Element__c importedImage = [
            SELECT Config_JSON__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :importedVersionId
            AND Element_Type__c = 'image'
            LIMIT 1
        ];
        Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped(importedImage.Config_JSON__c);
        System.assertNotEquals(null, config.get('contentVersionId'));
        System.assertNotEquals(null, config.get('contentDocumentId'));
        System.assert(String.valueOf(config.get('imageUrl')).contains('/sfc/servlet.shepherd/version/download/'));
        System.assertEquals(null, config.get('imageAssetKey'));
        }
    }

    @IsTest
    static void importCreatesReusableThemeFromPortableThemeBlock() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        String packageJson = buildMinimalPackage('form53', 'Imported Theme Form');
        Map<String, Object> packageMap = (Map<String, Object>) JSON.deserializeUntyped(packageJson);
        packageMap.put('schemaVersion', 'linked-env-portable-form-v2');
        packageMap.put('theme', new Map<String, Object>{
            'name' => 'Portable Green',
            'portableThemeKey' => 'portable-green',
            'description' => 'Imported theme test',
            'tokens' => new Map<String, Object>{
                'backgroundColor' => '#EAF8EA',
                'backgroundGradientColor' => '#EAF8EA',
                'buttonBackgroundColor' => '#008000',
                'buttonTextColor' => '#FFFFFF',
                'mainTextColor' => '#123456'
            }
        });
        Map<String, Object> manifest = (Map<String, Object>) packageMap.get('manifest');
        manifest.put('themes', new List<Object>{ 'portable-green' });
        packageJson = JSON.serialize(packageMap);

        Test.startTest();
        NativeFormsFormPortabilityController.importForm(packageJson, null);
        Test.stopTest();

        NF_Form__c importedForm = [
            SELECT Theme__c, Theme__r.Name, Theme__r.Background_Color__c, Theme__r.Background_Gradient_Color__c, Theme__r.Button_Background_Color__c
            FROM NF_Form__c
            WHERE NF_Key__c = 'form53'
            LIMIT 1
        ];
        System.assertNotEquals(null, importedForm.Theme__c);
        System.assertEquals('Portable Green', importedForm.Theme__r.Name);
        System.assertEquals('#EAF8EA', importedForm.Theme__r.Background_Color__c);
        System.assertEquals('#EAF8EA', importedForm.Theme__r.Background_Gradient_Color__c);
        System.assertEquals('#008000', importedForm.Theme__r.Button_Background_Color__c);
        }
    }

    @IsTest
    static void inspectReturnsCreateFormAndBlocksMissingMetadata() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        String packageJson = buildMinimalPackage('form99', 'Missing Metadata Form');
        Map<String, Object> packageMap = (Map<String, Object>) JSON.deserializeUntyped(packageJson);
        Map<String, Object> manifest = (Map<String, Object>) packageMap.get('manifest');
        manifest.put('objects', new List<Object>{ 'Definitely_Missing__c' });
        manifest.put('fields', new List<Object>{ 'Contact.Definitely_Missing__c' });
        packageJson = JSON.serialize(packageMap);

        Test.startTest();
        String previewJson = NativeFormsFormPortabilityController.inspectImport(packageJson);
        Test.stopTest();

        Map<String, Object> preview = (Map<String, Object>) JSON.deserializeUntyped(previewJson);
        System.assertEquals('createForm', preview.get('targetAction'));
        System.assert(!((List<Object>) preview.get('blockingErrors')).isEmpty(), 'Missing metadata must block.');
        System.assert(((List<Object>) preview.get('missingObjects')).contains('Definitely_Missing__c'));
        System.assert(((List<Object>) preview.get('missingFields')).contains('Contact.Definitely_Missing__c'));
        }
    }

    @IsTest
    static void importCreatesMissingFormWithDraftRows() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        String packageJson = buildMinimalPackage('form50', 'Imported Form');

        Test.startTest();
        String resultJson = NativeFormsFormPortabilityController.importForm(packageJson, null);
        Test.stopTest();

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(resultJson);
        System.assertEquals('createForm', result.get('targetAction'));
        NF_Form__c importedForm = [
            SELECT Id, Description__c, NF_Key__c, Project__r.Name, Current_Draft_Version__c, Current_Published_Version__c
            FROM NF_Form__c
            WHERE NF_Key__c = 'form50'
            LIMIT 1
        ];
        System.assertEquals('Imported Form', importedForm.Description__c);
        System.assertEquals('General', importedForm.Project__r.Name);
        System.assertNotEquals(null, importedForm.Current_Draft_Version__c);
        System.assertEquals(null, importedForm.Current_Published_Version__c);
        System.assertEquals(1, [SELECT COUNT() FROM NF_Form_Element__c WHERE Form_Version__c = :importedForm.Current_Draft_Version__c]);
        System.assertEquals(1, [SELECT COUNT() FROM NF_Form_Action__c WHERE Form_Version__c = :importedForm.Current_Draft_Version__c]);
        }
    }

    @IsTest
    static void importExistingFormCreatesNewDraftWithoutChangingPublished() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Existing Form', null, 'form77');
        NF_Form_Version__c publishedVersion = NativeFormsTestDataFactory.createVersion(
            formRecord.Id,
            1,
            'Published',
            'Published',
            NativeFormsTestConfigFactory.basicUiSettingsJson()
        );
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, null, publishedVersion.Id);
        String packageJson = buildMinimalPackage('form77', 'Existing Form');

        Test.startTest();
        String resultJson = NativeFormsFormPortabilityController.importForm(
            packageJson,
            JSON.serialize(new Map<String, Object>{ 'importMode' => 'updateExisting' })
        );
        Test.stopTest();

        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(resultJson);
        System.assertEquals('createVersion', result.get('targetAction'));
        NF_Form__c updatedForm = [
            SELECT Id, Current_Draft_Version__c, Current_Published_Version__c
            FROM NF_Form__c
            WHERE Id = :formRecord.Id
            LIMIT 1
        ];
        System.assertEquals(publishedVersion.Id, updatedForm.Current_Published_Version__c);
        System.assertNotEquals(null, updatedForm.Current_Draft_Version__c);
        System.assertNotEquals(publishedVersion.Id, updatedForm.Current_Draft_Version__c);
        NF_Form_Version__c draftVersion = [
            SELECT Version_Number__c, Version_Status__c, Publish_Status__c
            FROM NF_Form_Version__c
            WHERE Id = :updatedForm.Current_Draft_Version__c
        ];
        System.assertEquals(2, draftVersion.Version_Number__c);
        System.assertEquals('Draft', draftVersion.Version_Status__c);
        System.assertEquals('Never Published', draftVersion.Publish_Status__c);
        }
    }

    @IsTest
    static void importExistingFormRequiresExplicitDecisionAndCanCreateNewKey() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Existing Form', null, 'form89');
        String packageJson = buildMinimalPackage('form89', 'Existing Form');

        Map<String, Object> preview = (Map<String, Object>) JSON.deserializeUntyped(
            NativeFormsFormPortabilityController.inspectImport(packageJson)
        );
        System.assertEquals(true, preview.get('importDecisionRequired'));

        Boolean rejectedWithoutDecision = false;
        try {
            NativeFormsFormPortabilityController.importForm(packageJson, null);
        } catch (AuraHandledException expected) {
            rejectedWithoutDecision = true;
        }
        System.assertEquals(true, rejectedWithoutDecision, 'An existing-key import should require an explicit decision.');

        String resultJson = NativeFormsFormPortabilityController.importForm(
            packageJson,
            JSON.serialize(new Map<String, Object>{ 'importMode' => 'createNew' })
        );
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(resultJson);
        System.assertEquals('createForm', result.get('targetAction'));
        System.assertNotEquals('form89', result.get('globalFormKey'));
        NF_Form__c createdForm = [
            SELECT Id, NF_Key__c
            FROM NF_Form__c
            WHERE Id = :((Id) String.valueOf(result.get('formId')))
            LIMIT 1
        ];
        System.assertNotEquals(formRecord.Id, createdForm.Id);
        System.assertNotEquals('form89', createdForm.NF_Key__c);
        }
    }

    @IsTest
    static void inspectReportsHiddenSourceReferenceWarnings() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        String packageJson = buildMinimalPackage('form88', 'Hidden Reference Form');
        Map<String, Object> packageMap = (Map<String, Object>) JSON.deserializeUntyped(packageJson);
        List<Object> elements = (List<Object>) packageMap.get('elements');
        Map<String, Object> elementMap = (Map<String, Object>) elements[0];
        elementMap.put('configJson', '{"help":"https://example.my.salesforce.com/sfc/servlet.shepherd/version/download/068000000000001AAA"}');
        packageJson = JSON.serialize(packageMap);

        Test.startTest();
        String previewJson = NativeFormsFormPortabilityController.inspectImport(packageJson);
        Test.stopTest();

        Map<String, Object> preview = (Map<String, Object>) JSON.deserializeUntyped(previewJson);
        List<Object> warnings = (List<Object>) preview.get('warnings');
        System.assert(!warnings.isEmpty(), 'Source references should produce warnings.');
        }
    }

    @IsTest
    static void inspectSupportsV2PreviewFoundations() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        String packageJson = buildMinimalPackage('form89', 'V2 Preview Form');
        Map<String, Object> packageMap = (Map<String, Object>) JSON.deserializeUntyped(packageJson);
        packageMap.put('schemaVersion', 'linked-env-portable-form-v2');
        packageMap.put('theme', new Map<String, Object>{
            'name' => 'Imported Blue',
            'portableThemeKey' => 'imported-blue',
            'tokens' => new Map<String, Object>{ 'buttonBackgroundColor' => '#117ACA' }
        });
        packageMap.put('assets', new List<Object>{
            new Map<String, Object>{
                'assetKey' => 'logo-main',
                'usage' => 'logo',
                'sourceUrl' => 'https://example.com/logo.png',
                'sizeBytes' => 70657
            }
        });
        Map<String, Object> manifest = (Map<String, Object>) packageMap.get('manifest');
        manifest.put('features', new List<Object>{ 'submit', 'customJavaScript' });
        manifest.put('limits', new Map<String, Object>{
            'elementCount' => 1,
            'actionCount' => 1,
            'assetCount' => 1,
            'assetBytes' => 70657
        });
        packageJson = JSON.serialize(packageMap);

        Test.startTest();
        String previewJson = NativeFormsFormPortabilityController.inspectImport(packageJson);
        Test.stopTest();

        Map<String, Object> preview = (Map<String, Object>) JSON.deserializeUntyped(previewJson);
        System.assertEquals('linked-env-portable-form-v2', preview.get('schemaVersion'));
        System.assert(preview.containsKey('themePreview'), 'V2 preview should include theme details.');
        System.assert(preview.containsKey('assetPreview'), 'V2 preview should include asset details.');
        System.assert(preview.containsKey('featurePreview'), 'V2 preview should include feature details.');
        System.assert(preview.containsKey('limitPreview'), 'V2 preview should include limit details.');
        Map<String, Object> assetPreview = (Map<String, Object>) preview.get('assetPreview');
        System.assertEquals(1, assetPreview.get('assetCount'));
        System.assert(!((List<Object>) assetPreview.get('warnings')).isEmpty(), 'External/oversized asset should warn.');
        System.assert(!((List<Object>) assetPreview.get('messages')).isEmpty(), 'Asset preview should include admin messages.');
        System.assert(((List<Object>) assetPreview.get('items')).contains('logo-main'), 'Asset preview should include asset names or keys.');
        Map<String, Object> featurePreview = (Map<String, Object>) preview.get('featurePreview');
        System.assertEquals('warnOnly', featurePreview.get('policy'));
        System.assert(((List<Object>) featurePreview.get('featureLabels')).contains('Submit'));
        System.assert(((List<Object>) featurePreview.get('featureLabels')).contains('Custom JavaScript'));
        System.assert(!((List<Object>) featurePreview.get('messages')).isEmpty(), 'Feature preview should include admin messages.');
        Map<String, Object> limitPreview = (Map<String, Object>) preview.get('limitPreview');
        System.assertEquals(4, limitPreview.get('estimatedRecords'));
        }
    }

    private static String buildMinimalPackage(String formKey, String descriptionValue) {
        Map<String, Object> packageMap = new Map<String, Object>();
        packageMap.put('schemaVersion', 'linked-env-portable-form-v1');
        packageMap.put('packageType', 'twinaformsFormDefinition');
        packageMap.put('exportedAt', '2026-08-03T10:00:00Z');
        packageMap.put('sourceOrgId', '00D000000000001');
        packageMap.put('sourceEnvironmentType', 'sandbox');
        packageMap.put('sourcePublishedUrl', null);
        packageMap.put('globalFormKey', formKey);
        packageMap.put('form', new Map<String, Object>{
            'description' => descriptionValue,
            'projectName' => 'Source Project',
            'status' => 'Draft'
        });
        packageMap.put('version', new Map<String, Object>{
            'versionNumber' => 1,
            'versionLabel' => 'Version 1',
            'versionStatus' => 'Draft',
            'publishStatus' => 'Never Published',
            'securityMode' => 'secure-edit',
            'prefillParamsJson' => '[]',
            'uiSettingsJson' => NativeFormsTestConfigFactory.basicUiSettingsJson()
        });
        packageMap.put('elements', new List<Object>{
            new Map<String, Object>{
                'elementId' => 'text-1',
                'elementType' => 'text',
                'fieldKey' => 'lastName',
                'elementIndex' => 1,
                'label' => 'Last Name',
                'configJson' => '{"fieldApiName":"Contact.LastName"}',
                'parentElementId' => null,
                'order' => 10
            }
        });
        packageMap.put('actions', new List<Object>{
            new Map<String, Object>{
                'actionScope' => 'Submit',
                'commandKey' => 'submitContact',
                'commandType' => 'create',
                'objectApiName' => 'Contact',
                'storeResultAs' => 'ContactResult',
                'configJson' => '{"fieldMappings":[{"targetField":"Contact.LastName","sourceFieldKey":"lastName"}]}',
                'order' => 10
            }
        });
        packageMap.put('theme', new Map<String, Object>());
        packageMap.put('assets', new List<Object>());
        packageMap.put('manifest', new Map<String, Object>{
            'objects' => new List<Object>{ 'Contact' },
            'fields' => new List<Object>{ 'Contact.LastName' }
        });
        packageMap.put('stripped', new Map<String, Object>());
        return JSON.serialize(packageMap);
    }

    private static void assignTwinaFormsUserPermissionSet() {
        List<PermissionSet> permissionSets = [
            SELECT Id
            FROM PermissionSet
            WHERE Label = 'TwinaForms User'
            LIMIT 1
        ];
        if (permissionSets.isEmpty()) {
            return;
        }

        List<PermissionSetAssignment> existingAssignments = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
            AND PermissionSetId = :permissionSets[0].Id
            LIMIT 1
        ];
        if (!existingAssignments.isEmpty()) {
            return;
        }

        insert new PermissionSetAssignment(
            AssigneeId = UserInfo.getUserId(),
            PermissionSetId = permissionSets[0].Id
        );
    }
}
