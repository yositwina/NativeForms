@IsTest
private class NativeFormsDesignerBuilderTest {
    private static NativeFormsTenantEntitlements.EntitlementSnapshot buildEntitlementsSnapshot(
        Boolean enableRepeatGroups,
        Boolean enableLoadFile,
        Boolean enableFormulaFields,
        Boolean enableConditionLogic,
        Boolean enablePostSubmitAutoLink,
        Boolean enableSecretCode,
        Boolean enablePrefillAliasReferences,
        Boolean enableAdvancedSubmitModes,
        Boolean enableCustomJs
    ) {
        NativeFormsTenantEntitlements.EntitlementSnapshot snapshot = new NativeFormsTenantEntitlements.EntitlementSnapshot();
        snapshot.loadedSuccessfully = true;
        snapshot.orgId = UserInfo.getOrganizationId().substring(0, 15);
        snapshot.planCode = 'pro';
        snapshot.errorMessage = null;
        snapshot.effectiveFeatureFlags = new Map<String, Object>{
            'enableProRepeatGroups' => enableRepeatGroups == true,
            'enableProLoadFile' => enableLoadFile == true,
            'enableProFormulaFields' => enableFormulaFields == true,
            'enableProConditionLogic' => enableConditionLogic == true,
            'enableProPostSubmitAutoLink' => enablePostSubmitAutoLink == true,
            'enableProSfSecretCodeAuth' => enableSecretCode == true,
            'enableProPrefillAliasReferences' => enablePrefillAliasReferences == true,
            'enableProAdvancedSubmitModes' => enableAdvancedSubmitModes == true,
            'enableProCustomJs' => enableCustomJs == true
        };
        snapshot.effectiveLimits = new Map<String, Object>{
            'maxForms' => 1000,
            'maxSfUsers' => 5
        };
        return snapshot;
    }

    private static void setAllProFlagsEnabled() {
        NativeFormsTenantEntitlements.setCachedSnapshot(
            buildEntitlementsSnapshot(true, true, true, true, true, true, true, true, true)
        );
    }

    private static void setAllProFlagsEnabledWithMaxForms(Integer maxForms) {
        NativeFormsTenantEntitlements.EntitlementSnapshot snapshot = buildEntitlementsSnapshot(
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true,
            true
        );
        snapshot.effectiveLimits.put('maxForms', maxForms);
        NativeFormsTenantEntitlements.setCachedSnapshot(snapshot);
    }

    private static void setFeatureFlags(
        Boolean enableRepeatGroups,
        Boolean enableLoadFile,
        Boolean enableFormulaFields
    ) {
        NativeFormsTenantEntitlements.setCachedSnapshot(
            buildEntitlementsSnapshot(
                enableRepeatGroups,
                enableLoadFile,
                enableFormulaFields,
                true,
                true,
                true,
                true,
                true,
                true
            )
        );
    }

    private static Map<String, Object> jsonMap(String rawJson) {
        return (Map<String, Object>) JSON.deserializeUntyped(String.isBlank(rawJson) ? '{}' : rawJson);
    }

    private static Boolean containsDesignerOptionValue(
        List<NativeFormsDesignerController.SelectOption> options,
        String expectedValue
    ) {
        for (NativeFormsDesignerController.SelectOption optionValue : options) {
            if (optionValue != null && optionValue.value == expectedValue) {
                return true;
            }
        }
        return false;
    }

    private static void assertAuraHandled(AuraHandledException e) {
        System.assertNotEquals(null, e);
        System.assert(String.isNotBlank(e.getMessage()));
    }

    @IsTest
    static void designerMetadataMethodsReturnExpectedOptions() {
        setAllProFlagsEnabled();

        List<NativeFormsDesignerController.SelectOption> objectOptions = NativeFormsDesignerController.getObjectOptions();
        List<NativeFormsDesignerController.SelectOption> picklistFieldOptions = NativeFormsDesignerController.getPicklistFieldOptions('Case');
        List<NativeFormsDesignerController.SelectOption> picklistValueOptions = NativeFormsDesignerController.getPicklistValueOptions('Case', 'Origin');

        System.assert(containsDesignerOptionValue(objectOptions, 'Case'));
        System.assertEquals(0, NativeFormsDesignerController.getPicklistFieldOptions(null).size());
        System.assert(containsDesignerOptionValue(picklistFieldOptions, 'Origin'));
        System.assert(picklistValueOptions.size() > 0);
        System.assertEquals(0, NativeFormsDesignerController.getPicklistValueOptions('Case', null).size());
    }

    @IsTest
    static void designerCreateWorkspaceAndFormSettingsBehaveAsExpected() {
        setAllProFlagsEnabled();

        try {
            NativeFormsDesignerController.createFormWithDraftVersion('   ', null, null, null);
            System.assert(false, 'Blank descriptions should be rejected.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        NF_Theme__c themeRecord = NativeFormsTestDataFactory.createTheme('Builder Theme');
        NativeFormsDesignerController.NewFormResult createResult = NativeFormsDesignerController.createFormWithDraftVersion(
            '  Intake Demo  ',
            null,
            '  Customer Onboarding  ',
            themeRecord.Id
        );

        NF_Form__c createdForm = [
            SELECT Id, Description__c, Theme__c, Project__c, Project__r.Name, Current_Draft_Version__c, Current_Published_Version__c
            FROM NF_Form__c
            WHERE Id = :createResult.formId
        ];
        NF_Form_Version__c publishedVersion = NativeFormsTestDataFactory.createVersion(
            createdForm.Id,
            2,
            'Published',
            'Published',
            NativeFormsTestConfigFactory.basicUiSettingsJson()
        );
        NativeFormsTestDataFactory.assignCurrentVersions(createdForm.Id, createResult.versionId, publishedVersion.Id);

        NativeFormsTestDataFactory.createElement(
            publishedVersion.Id,
            'text',
            'Email',
            'email1',
            1,
            10,
            NativeFormsTestConfigFactory.textFieldConfigJson(),
            null
        );
        NativeFormsTestDataFactory.createAction(
            publishedVersion.Id,
            'Prefill',
            'Contact',
            'prefillContact',
            'contactAlias',
            'findOne',
            10,
            '{}'
        );
        NativeFormsTestDataFactory.createAction(
            publishedVersion.Id,
            'Submit',
            'Contact',
            'submitContact',
            'savedContact',
            'create',
            20,
            '{}'
        );
        NativeFormsTestDataFactory.createPublication(
            createdForm.Id,
            publishedVersion.Id,
            'Success',
            'https://forms.twinaforms.com/intake-demo'
        );

        NativeFormsDesignerController.DesignerWorkspace workspace = NativeFormsDesignerController.getWorkspace(
            createResult.projectId,
            createResult.formId,
            null
        );

        System.assertEquals(createResult.projectId, workspace.selectedProjectId);
        System.assertEquals(createResult.formId, workspace.selectedFormId);
        System.assertEquals(publishedVersion.Id, workspace.selectedVersionId);
        System.assertEquals('Customer Onboarding', workspace.selectedProjectName);
        System.assertEquals('Intake Demo', workspace.selectedFormName);
        System.assertEquals('Published', workspace.selectedVersionStatus);
        System.assertEquals('https://forms.twinaforms.com/intake-demo', workspace.selectedPublishedUrl);
        System.assertEquals(1, workspace.elements.size());
        System.assertEquals(1, workspace.prefillAliases.size());
        System.assertEquals(1, workspace.submitActions.size());
        System.assertEquals(true, workspace.enableProRepeatGroups);
        System.assertEquals(true, workspace.enableProLoadFile);
        System.assertEquals(true, workspace.enableProFormulaFields);
        System.assertEquals(true, workspace.enableProCustomJs);
        System.assertEquals(1000, workspace.maxForms);
        System.assertEquals(false, workspace.formLimitReached);
        System.assert(String.isNotBlank(workspace.upgradeUrl));
        System.assertEquals(themeRecord.Id, workspace.selectedTheme.id);

        List<Object> conditionalConditions = new List<Object>{
            new Map<String, Object>{
                'fieldKey' => 'email1',
                'operator' => 'equals',
                'value' => 'person@example.com'
            }
        };
        NativeFormsDesignerController.updateFormSettings(
            createResult.formId,
            createResult.versionId,
            '  Intake Demo Updated  ',
            null,
            themeRecord.Id,
            true,
            'es',
            '',
            true,
            true,
            'https://example.com/thanks?id={email1}',
            '',
            5,
            true,
            'Email',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            25,
            6,
            false,
            '',
            true,
            'email1',
            'equals',
            'person@example.com',
            JSON.serialize(conditionalConditions),
            ''
        );
        NativeFormsDesignerController.updateVersionCustomJs(
            createResult.formId,
            createResult.versionId,
            'window.TwinaForms.setValue("text6","+972");'
        );

        NF_Form__c updatedForm = [
            SELECT Id, Description__c, Project__c, Theme__c, Enable_Captcha__c
            FROM NF_Form__c
            WHERE Id = :createResult.formId
        ];
        NF_Form_Version__c updatedVersion = [
            SELECT Id, UI_Settings_JSON__c, Custom_JS__c
            FROM NF_Form_Version__c
            WHERE Id = :createResult.versionId
        ];
        Map<String, Object> updatedUiSettings = jsonMap(updatedVersion.UI_Settings_JSON__c);

        System.assertEquals('Intake Demo Updated', updatedForm.Description__c);
        System.assertNotEquals(null, updatedForm.Project__c);
        System.assertEquals(themeRecord.Id, updatedForm.Theme__c);
        System.assertEquals(true, updatedForm.Enable_Captcha__c);
        System.assertEquals('es', String.valueOf(updatedUiSettings.get('languageCode')));
        System.assertEquals(true, updatedUiSettings.get('rtlEnabled'));
        System.assertEquals(true, updatedUiSettings.get('postSubmitAutoLinkEnabled'));
        System.assertEquals('https://example.com/thanks?id={email1}', String.valueOf(updatedUiSettings.get('postSubmitUrlTemplate')));
        System.assertEquals(true, updatedUiSettings.get('submitConditionalEnabled'));
        System.assertEquals(false, updatedUiSettings.get('secretCodeAllowResend'));
        System.assertEquals('window.TwinaForms.setValue("text6","+972");', updatedVersion.Custom_JS__c);

        NativeFormsDesignerController.DesignerWorkspace updatedWorkspace = NativeFormsDesignerController.getWorkspace(
            updatedForm.Project__c,
            createResult.formId,
            createResult.versionId
        );
        System.assertEquals('es', updatedWorkspace.selectedVersionLanguageCode);
        System.assertEquals('Enviar', updatedWorkspace.selectedVersionSubmitLabel);
        System.assertEquals('Continuar', updatedWorkspace.selectedVersionPostSubmitButtonLabel);
        System.assertEquals(true, updatedWorkspace.selectedVersionRtlEnabled);
        System.assertEquals(true, updatedWorkspace.selectedVersionPostSubmitAutoLinkEnabled);
        System.assertEquals('https://example.com/thanks?id={email1}', updatedWorkspace.selectedVersionPostSubmitUrlTemplate);
        System.assertEquals(true, updatedWorkspace.selectedVersionSubmitConditionalEnabled);
        System.assertEquals('email1', updatedWorkspace.selectedVersionSubmitConditionalFieldKey);
        System.assertEquals('window.TwinaForms.setValue("text6","+972");', updatedWorkspace.selectedVersionCustomJs);
    }

    @IsTest
    static void designerCreateFormEnforcesPlanLimit() {
        setAllProFlagsEnabled();

        NativeFormsDesignerController.NewFormResult firstResult = NativeFormsDesignerController.createFormWithDraftVersion(
            'First Limited Form',
            null,
            null,
            null
        );
        System.assertNotEquals(null, firstResult.formId);

        Integer currentCount = [SELECT COUNT() FROM NF_Form__c];
        setAllProFlagsEnabledWithMaxForms(currentCount);

        NativeFormsDesignerController.DesignerWorkspace workspace = NativeFormsDesignerController.getWorkspace(
            firstResult.projectId,
            firstResult.formId,
            firstResult.versionId
        );
        System.assertEquals(currentCount, workspace.currentFormCount);
        System.assertEquals(currentCount, workspace.maxForms);
        System.assertEquals(true, workspace.formLimitReached);
        System.assert(workspace.formLimitMessage.contains('plan limit for forms'));
        System.assert(workspace.upgradeUrl.contains('salesforce-designer'));

        try {
            NativeFormsDesignerController.createFormWithDraftVersion('Blocked Form', firstResult.projectId, null, null);
            System.assert(false, 'Creating a form at the plan limit should be blocked.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }
    }

    @IsTest
    static void designerDeleteUnpublishedFormRemovesDesignerRecords() {
        setAllProFlagsEnabled();

        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Delete Draft Form');
        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createDraftVersion(formRecord.Id);
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, versionRecord.Id, null);
        NativeFormsTestDataFactory.createElement(
            versionRecord.Id,
            'text',
            'Name',
            'text1',
            1,
            10,
            NativeFormsTestConfigFactory.textFieldConfigJson(),
            null
        );
        NativeFormsTestDataFactory.createAction(
            versionRecord.Id,
            'Submit',
            'Contact',
            'submitContact',
            'savedContact',
            'create',
            20,
            '{}'
        );
        NativeFormsTestDataFactory.createPublication(
            formRecord.Id,
            versionRecord.Id,
            'Failed',
            'https://forms.twinaforms.com/delete-draft-form'
        );

        NativeFormsDesignerController.deleteForm(formRecord.Id, 'Delete Draft Form');

        System.assertEquals(0, [SELECT COUNT() FROM NF_Form__c WHERE Id = :formRecord.Id]);
        System.assertEquals(0, [SELECT COUNT() FROM NF_Form_Version__c WHERE Form__c = :formRecord.Id]);
        System.assertEquals(0, [SELECT COUNT() FROM NF_Form_Element__c WHERE Form_Version__c = :versionRecord.Id]);
        System.assertEquals(0, [SELECT COUNT() FROM NF_Form_Action__c WHERE Form_Version__c = :versionRecord.Id]);
        System.assertEquals(0, [SELECT COUNT() FROM NF_Form_Publication__c WHERE Form__c = :formRecord.Id]);
    }

    @IsTest
    static void designerDeletePublishedFormUnpublishesRuntimeFirst() {
        setAllProFlagsEnabled();

        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Delete Published Form', null, 'delete-published-form');
        NF_Form_Version__c publishedVersion = NativeFormsTestDataFactory.createVersion(
            formRecord.Id,
            1,
            'Published',
            'Published',
            NativeFormsTestConfigFactory.basicUiSettingsJson()
        );
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, null, publishedVersion.Id);
        NativeFormsTestDataFactory.createPublication(
            formRecord.Id,
            publishedVersion.Id,
            'Success',
            'https://forms.twinaforms.com/harmony/delete-published-form',
            'runtime-delete-form'
        );

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock().addJsonResponse(
                '/forms/unpublish',
                200,
                new Map<String, Object>{ 'success' => true, 'unpublished' => true }
            )
        );

        Test.startTest();
        NativeFormsDesignerController.deleteForm(formRecord.Id, 'delete-published-form');
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM NF_Form__c WHERE Id = :formRecord.Id]);
        System.assertEquals(0, [SELECT COUNT() FROM NF_Form_Publication__c WHERE Form__c = :formRecord.Id]);
    }

    @IsTest
    static void designerDeletePublishedFormBlocksWhenUnpublishFails() {
        setAllProFlagsEnabled();

        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Blocked Delete Form');
        NF_Form_Version__c publishedVersion = NativeFormsTestDataFactory.createVersion(
            formRecord.Id,
            1,
            'Published',
            'Published',
            NativeFormsTestConfigFactory.basicUiSettingsJson()
        );
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, null, publishedVersion.Id);
        NativeFormsTestDataFactory.createPublication(
            formRecord.Id,
            publishedVersion.Id,
            'Success',
            'https://forms.twinaforms.com/harmony/blocked-delete-form',
            'runtime-blocked-delete-form'
        );

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock().addJsonResponse(
                '/forms/unpublish',
                500,
                new Map<String, Object>{ 'success' => false, 'error' => 'Synthetic unpublish failure.' }
            )
        );

        Test.startTest();
        try {
            NativeFormsDesignerController.deleteForm(formRecord.Id, 'Blocked Delete Form');
            System.assert(false, 'Delete should be blocked when runtime unpublish fails.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM NF_Form__c WHERE Id = :formRecord.Id]);
        System.assertEquals(1, [SELECT COUNT() FROM NF_Form_Publication__c WHERE Form__c = :formRecord.Id]);
    }

    @IsTest
    static void designerElementPlacementUploadAndDeleteBehaviorsWork() {
        setAllProFlagsEnabled();

        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Designer Element Test');
        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createDraftVersion(formRecord.Id);
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, versionRecord.Id, null);

        NativeFormsDesignerController.ElementRecord sectionRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'section');
        NativeFormsDesignerController.ElementRecord textRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'text');
        NativeFormsDesignerController.ElementRecord timeRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'time');
        NativeFormsDesignerController.ElementRecord emailRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'email');
        NativeFormsDesignerController.ElementRecord imageRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'image');

        NativeFormsDesignerController.placeElementInSection(textRecord.id, sectionRecord.id, 2);
        NativeFormsDesignerController.insertElementAfter(emailRecord.id, textRecord.id);
        NativeFormsDesignerController.reorderElement(versionRecord.Id, emailRecord.id, 0);
        NativeFormsDesignerController.ElementRecord updatedSection = NativeFormsDesignerController.updateSectionColumns(sectionRecord.id, 3);

        String encodedFile = EncodingUtil.base64Encode(Blob.valueOf('pngdata'));
        NativeFormsDesignerController.UploadedImageResult uploadedImage = NativeFormsDesignerController.uploadImageFile(
            imageRecord.id,
            versionRecord.Id,
            'logo.png',
            'image/png',
            encodedFile
        );

        NF_Form_Element__c placedText = [
            SELECT Id, Config_JSON__c, Parent_Element_Id__c
            FROM NF_Form_Element__c
            WHERE Id = :textRecord.id
        ];
        NF_Form_Element__c reorderedEmail = [
            SELECT Id, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Id = :emailRecord.id
        ];
        NF_Form_Element__c updatedImage = [
            SELECT Id, Config_JSON__c
            FROM NF_Form_Element__c
            WHERE Id = :imageRecord.id
        ];

        System.assertEquals(sectionRecord.elementId, placedText.Parent_Element_Id__c);
        System.assertEquals(2, (Integer) jsonMap(placedText.Config_JSON__c).get('sectionColumn'));
        System.assertEquals('Time', timeRecord.label);
        System.assertEquals('time', timeRecord.elementType);
        System.assert(String.valueOf(timeRecord.fieldKey).startsWith('time'));
        System.assertEquals('19:00', String.valueOf(jsonMap(timeRecord.configJson).get('placeholder')));
        System.assertEquals('24h', String.valueOf(jsonMap(timeRecord.configJson).get('timeFormat')));
        System.assertEquals(null, reorderedEmail.Parent_Element_Id__c);
        System.assertEquals(10, Integer.valueOf(String.valueOf(reorderedEmail.Order__c)));
        System.assertEquals(3, (Integer) jsonMap(updatedSection.configJson).get('columns'));
        System.assertNotEquals(null, uploadedImage.contentVersionId);
        System.assert(uploadedImage.previewUrl.contains('/sfc/servlet.shepherd/version/download/'));
        System.assert(jsonMap(updatedImage.Config_JSON__c).containsKey('contentVersionId'));

        NativeFormsDesignerController.deleteElement(sectionRecord.id);

        System.assertEquals(
            0,
            [SELECT count() FROM NF_Form_Element__c WHERE Id IN :new Set<Id>{ sectionRecord.id, textRecord.id }]
        );
        System.assertEquals(
            1,
            [SELECT count() FROM NF_Form_Element__c WHERE Id = :emailRecord.id]
        );
    }

    @IsTest
    static void designerPlanAndContainerGuardsWork() {
        setFeatureFlags(false, false, true);

        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Designer Guard Test');
        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createDraftVersion(formRecord.Id);

        try {
            NativeFormsDesignerController.addElement(versionRecord.Id, 'repeatGroup');
            System.assert(false, 'Repeat groups should be blocked when the feature is disabled.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        try {
            NativeFormsDesignerController.addElement(versionRecord.Id, 'fileUpload');
            System.assert(false, 'File uploads should be blocked when the feature is disabled.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        setFeatureFlags(true, true, true);
        NativeFormsDesignerController.ElementRecord repeatGroupRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'repeatGroup');
        NativeFormsDesignerController.ElementRecord fileUploadRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'fileUpload');
        NativeFormsDesignerController.ElementRecord sectionRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'section');
        NativeFormsDesignerController.ElementRecord groupRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'group');

        try {
            NativeFormsDesignerController.placeElementInSection(fileUploadRecord.id, repeatGroupRecord.id, 1);
            System.assert(false, 'File uploads inside records lists should be rejected.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        try {
            NativeFormsDesignerController.placeElementInSection(groupRecord.id, sectionRecord.id, 1);
            System.assert(false, 'Groups cannot be nested inside another container.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        try {
            NativeFormsDesignerController.updateSectionColumns(repeatGroupRecord.id, 2);
            System.assert(false, 'Only sections and groups should support explicit column counts.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }
    }

    @IsTest
    static void builderWorkspaceCrudAndMoveBehaviorsWork() {
        setAllProFlagsEnabled();

        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Builder Workspace Test');
        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createDraftVersion(formRecord.Id);
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, versionRecord.Id, null);

        NF_Form_Element__c textRecord = NativeFormsTestDataFactory.createElement(
            versionRecord.Id,
            'text',
            'First Name',
            'text1',
            1,
            25,
            NativeFormsTestConfigFactory.textFieldConfigJson(),
            null
        );
        NF_Form_Element__c checkboxRecord = NativeFormsTestDataFactory.createElement(
            versionRecord.Id,
            'checkbox',
            'Opt In',
            'checkbox1',
            2,
            90,
            NativeFormsTestConfigFactory.checkboxConfigJson(false),
            null
        );
        NativeFormsTestDataFactory.createAction(
            versionRecord.Id,
            'Prefill',
            'Contact',
            'prefillContact',
            'contactAlias',
            'findOne',
            10,
            '{}'
        );
        NativeFormsTestDataFactory.createAction(
            versionRecord.Id,
            'Submit',
            'Contact',
            'submitContact',
            'savedContact',
            'create',
            20,
            '{}'
        );

        NativeFormsBuilderController.BuilderWorkspace workspace = NativeFormsBuilderController.getWorkspace(versionRecord.Id);
        System.assertEquals(versionRecord.Id, workspace.selectedVersionId);
        System.assertEquals(2, workspace.elements.size());
        System.assertEquals(1, workspace.prefillAliases.size());
        System.assertEquals(1, workspace.submitActions.size());

        NativeFormsBuilderController.ElementRecord addedElement = NativeFormsBuilderController.addElement(versionRecord.Id, 'checkbox');
        System.assertEquals('checkbox', addedElement.elementType);
        System.assertEquals(false, jsonMap(addedElement.configJson).get('checked'));
        NativeFormsBuilderController.ElementRecord addedTimeElement = NativeFormsBuilderController.addElement(versionRecord.Id, 'time');
        System.assertEquals('time', addedTimeElement.elementType);
        System.assertEquals('19:00', String.valueOf(jsonMap(addedTimeElement.configJson).get('placeholder')));
        System.assertEquals('24h', String.valueOf(jsonMap(addedTimeElement.configJson).get('timeFormat')));

        NativeFormsBuilderController.ElementUpsertInput updateInput = new NativeFormsBuilderController.ElementUpsertInput();
        updateInput.id = addedElement.id;
        updateInput.label = 'Marketing Consent';
        updateInput.fieldKey = 'checkboxConsent';
        updateInput.elementType = 'checkbox';
        updateInput.configJson = NativeFormsTestConfigFactory.checkboxConfigJson(true);
        NativeFormsBuilderController.ElementRecord updatedElement = NativeFormsBuilderController.updateElement(JSON.serialize(updateInput));

        NativeFormsBuilderController.moveElement(checkboxRecord.Id, 'up');
        NativeFormsBuilderController.deleteElement(textRecord.Id);

        NF_Form_Element__c movedCheckbox = [
            SELECT Id, Order__c
            FROM NF_Form_Element__c
            WHERE Id = :checkboxRecord.Id
        ];
        NF_Form_Element__c persistedUpdatedElement = [
            SELECT Id, Label__c, Field_Key__c, Config_JSON__c
            FROM NF_Form_Element__c
            WHERE Id = :addedElement.id
        ];

        System.assertEquals('Marketing Consent', updatedElement.label);
        System.assertEquals('Marketing Consent', persistedUpdatedElement.Label__c);
        System.assertEquals('checkboxConsent', persistedUpdatedElement.Field_Key__c);
        System.assertEquals(true, jsonMap(persistedUpdatedElement.Config_JSON__c).get('checked'));
        System.assertEquals(10, Integer.valueOf(String.valueOf(movedCheckbox.Order__c)));
        System.assertEquals(0, [SELECT count() FROM NF_Form_Element__c WHERE Id = :textRecord.Id]);
    }

    @IsTest
    static void builderValidationGuardsWork() {
        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Builder Guard Test');
        NF_Form_Version__c draftVersion = NativeFormsTestDataFactory.createDraftVersion(formRecord.Id);
        NF_Form_Version__c publishedVersion = NativeFormsTestDataFactory.createVersion(
            formRecord.Id,
            2,
            'Published',
            'Published',
            NativeFormsTestConfigFactory.basicUiSettingsJson()
        );
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, draftVersion.Id, publishedVersion.Id);

        try {
            NativeFormsBuilderController.addElement(publishedVersion.Id, 'text');
            System.assert(false, 'Published versions should remain read-only.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        NF_Form_Element__c textRecord = NativeFormsTestDataFactory.createElement(
            draftVersion.Id,
            'text',
            'Calculated Text',
            'textFormula',
            1,
            10,
            NativeFormsTestConfigFactory.textFieldConfigJson(),
            null
        );
        NF_Form_Element__c checkboxRecord = NativeFormsTestDataFactory.createElement(
            draftVersion.Id,
            'checkbox',
            'Flag',
            'checkboxFormula',
            2,
            20,
            NativeFormsTestConfigFactory.checkboxConfigJson(false),
            null
        );
        NF_Form_Element__c repeatGroupRecord = NativeFormsTestDataFactory.createElement(
            draftVersion.Id,
            'repeatGroup',
            'Records List',
            'repeatGroup1',
            3,
            30,
            NativeFormsTestConfigFactory.repeatGroupConfigJson(),
            null
        );
        NF_Form_Element__c repeatChildText = NativeFormsTestDataFactory.createElement(
            draftVersion.Id,
            'text',
            'Child Formula',
            'textChild',
            4,
            40,
            NativeFormsTestConfigFactory.textFieldConfigJson(),
            repeatGroupRecord.Element_Id__c
        );
        NF_Form_Element__c repeatChildCheckbox = NativeFormsTestDataFactory.createElement(
            draftVersion.Id,
            'checkbox',
            'Child Upload',
            'checkboxChild',
            5,
            50,
            NativeFormsTestConfigFactory.checkboxConfigJson(false),
            repeatGroupRecord.Element_Id__c
        );

        setFeatureFlags(true, false, false);

        NativeFormsBuilderController.ElementUpsertInput blockedFormulaInput = new NativeFormsBuilderController.ElementUpsertInput();
        blockedFormulaInput.id = textRecord.Id;
        blockedFormulaInput.label = 'Calculated Text';
        blockedFormulaInput.fieldKey = 'textFormula';
        blockedFormulaInput.elementType = 'text';
        blockedFormulaInput.configJson = NativeFormsTestConfigFactory.formulaFieldConfigJson('1 + 1');
        try {
            NativeFormsBuilderController.updateElement(JSON.serialize(blockedFormulaInput));
            System.assert(false, 'Formula fields should be plan-gated.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        setFeatureFlags(true, true, true);

        NativeFormsBuilderController.ElementUpsertInput checkboxFormulaInput = new NativeFormsBuilderController.ElementUpsertInput();
        checkboxFormulaInput.id = checkboxRecord.Id;
        checkboxFormulaInput.label = 'Flag';
        checkboxFormulaInput.fieldKey = 'checkboxFormula';
        checkboxFormulaInput.elementType = 'checkbox';
        checkboxFormulaInput.configJson = NativeFormsTestConfigFactory.formulaFieldConfigJson('1 + 1');
        try {
            NativeFormsBuilderController.updateElement(JSON.serialize(checkboxFormulaInput));
            System.assert(false, 'Only text and number fields should accept formulas.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        NativeFormsBuilderController.ElementUpsertInput repeatFormulaInput = new NativeFormsBuilderController.ElementUpsertInput();
        repeatFormulaInput.id = repeatChildText.Id;
        repeatFormulaInput.label = 'Child Formula';
        repeatFormulaInput.fieldKey = 'textChild';
        repeatFormulaInput.elementType = 'text';
        repeatFormulaInput.configJson = NativeFormsTestConfigFactory.formulaFieldConfigJson('1 + 1');
        try {
            NativeFormsBuilderController.updateElement(JSON.serialize(repeatFormulaInput));
            System.assert(false, 'Formula fields inside records lists should be rejected.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        NativeFormsBuilderController.ElementUpsertInput fileUploadWithoutTarget = new NativeFormsBuilderController.ElementUpsertInput();
        fileUploadWithoutTarget.id = checkboxRecord.Id;
        fileUploadWithoutTarget.label = 'Upload';
        fileUploadWithoutTarget.fieldKey = 'checkboxFormula';
        fileUploadWithoutTarget.elementType = 'fileUpload';
        fileUploadWithoutTarget.configJson = NativeFormsTestConfigFactory.fileUploadConfigJson(null);
        try {
            NativeFormsBuilderController.updateElement(JSON.serialize(fileUploadWithoutTarget));
            System.assert(false, 'File uploads require a target submit action.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        NativeFormsBuilderController.ElementUpsertInput repeatFileUpload = new NativeFormsBuilderController.ElementUpsertInput();
        repeatFileUpload.id = repeatChildCheckbox.Id;
        repeatFileUpload.label = 'Upload in list';
        repeatFileUpload.fieldKey = 'checkboxChild';
        repeatFileUpload.elementType = 'fileUpload';
        repeatFileUpload.configJson = NativeFormsTestConfigFactory.fileUploadConfigJson('submitContact');
        try {
            NativeFormsBuilderController.updateElement(JSON.serialize(repeatFileUpload));
            System.assert(false, 'File uploads inside repeat groups should be rejected.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        NativeFormsBuilderController.ElementUpsertInput validFileUpload = new NativeFormsBuilderController.ElementUpsertInput();
        validFileUpload.id = checkboxRecord.Id;
        validFileUpload.label = 'Upload Field';
        validFileUpload.fieldKey = 'checkboxFormula';
        validFileUpload.elementType = 'fileUpload';
        validFileUpload.configJson = NativeFormsTestConfigFactory.fileUploadConfigJson('submitContact');
        NativeFormsBuilderController.ElementRecord savedFileUpload = NativeFormsBuilderController.updateElement(JSON.serialize(validFileUpload));

        System.assertEquals('fileUpload', savedFileUpload.elementType);
        System.assertEquals('Upload Field', savedFileUpload.label);
    }
}
