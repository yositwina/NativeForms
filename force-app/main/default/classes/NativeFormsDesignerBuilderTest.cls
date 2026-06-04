@IsTest
private class NativeFormsDesignerBuilderTest {
    @TestSetup
    static void setupPermissions() {
        NativeFormsTestDataFactory.assignTwinaFormsUserPermissionSet();
        NativeFormsBootstrapV2Signer.getOrCreateSigningSecretB64();
    }

    private static NativeFormsTenantEntitlements.EntitlementSnapshot buildEntitlementsSnapshot(
        Boolean enableRepeatGroups,
        Boolean enableLoadFile,
        Boolean enableFormulaFields,
        Boolean enableConditionLogic,
        Boolean enablePostSubmitAutoLink,
        Boolean enableUserVerification,
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
            'enableProUserVerification' => enableUserVerification == true,
            'enableProPrefillAliasReferences' => enablePrefillAliasReferences == true,
            'enableProAdvancedSubmitModes' => enableAdvancedSubmitModes == true,
            'enableProPageLayoutClone' => enableAdvancedSubmitModes == true,
            'enableProElectronicSignature' => enableLoadFile == true,
            'enableProSubmissionPdf' => enableLoadFile == true,
            'enableProSurveyFields' => enableLoadFile == true,
            'enableProCustomJs' => enableCustomJs == true,
            'enableProButtonElements' => enableLoadFile == true,
            'enableProMergedDocument' => enableLoadFile == true
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

    private static void setPageLayoutMock() {
        NativeFormsDesignerController.pageLayoutImportMetadataMock = new Map<String, Object>{
            'success' => true,
            'objectApiName' => 'Contact',
            'objectLabel' => '\u05D0\u05D9\u05E9 \u05E7\u05E9\u05E8',
            'defaultLayoutKey' => 'assigned:012000000000000AAA',
            'layouts' => new List<Object>{
                new Map<String, Object>{
                    'label' => '\u05E4\u05E8\u05D9\u05E1\u05EA \u05D0\u05D9\u05E9 \u05E7\u05E9\u05E8',
                    'value' => 'assigned:012000000000000AAA'
                }
            },
            'layout' => new Map<String, Object>{
                'layoutKey' => 'assigned:012000000000000AAA',
                'layoutLabel' => '\u05E4\u05E8\u05D9\u05E1\u05EA \u05D0\u05D9\u05E9 \u05E7\u05E9\u05E8',
                'objectApiName' => 'Contact',
                'objectLabel' => '\u05D0\u05D9\u05E9 \u05E7\u05E9\u05E8',
                'sections' => new List<Object>{
                    new Map<String, Object>{
                        'heading' => '\u05E4\u05E8\u05D8\u05D9 \u05D0\u05D9\u05E9 \u05E7\u05E9\u05E8',
                        'fields' => new List<Object>{
                            new Map<String, Object>{
                                'apiName' => 'FirstName',
                                'label' => '\u05E9\u05DD \u05E4\u05E8\u05D8\u05D9',
                                'required' => false,
                                'editableForNew' => true,
                                'editableForUpdate' => true
                            },
                            new Map<String, Object>{
                                'apiName' => 'Email',
                                'label' => '\u05D0\u05D9\u05DE\u05D9\u05D9\u05DC',
                                'required' => false,
                                'editableForNew' => true,
                                'editableForUpdate' => true
                            },
                            new Map<String, Object>{
                                'apiName' => 'AccountId',
                                'label' => '\u05D7\u05E9\u05D1\u05D5\u05DF',
                                'required' => false,
                                'editableForNew' => true,
                                'editableForUpdate' => false
                            },
                            new Map<String, Object>{
                                'apiName' => 'Salutation',
                                'label' => '\u05E4\u05E0\u05D9\u05D9\u05D4',
                                'required' => false,
                                'editableForNew' => true,
                                'editableForUpdate' => true,
                                'picklistValues' => new List<Object>{
                                    new Map<String, Object>{ 'label' => '\u05DE\u05E8', 'value' => 'Mr.' },
                                    new Map<String, Object>{ 'label' => '\u05D2\u05D1\u05E8\u05EA', 'value' => 'Ms.' }
                                }
                            }
                        }
                    },
                    new Map<String, Object>{
                        'heading' => '\u05DE\u05D9\u05D3\u05E2 \u05E0\u05D5\u05E1\u05E3',
                        'fields' => new List<Object>{
                            new Map<String, Object>{
                                'apiName' => 'Description',
                                'label' => '\u05EA\u05D9\u05D0\u05D5\u05E8',
                                'required' => false,
                                'editableForNew' => true,
                                'editableForUpdate' => true
                            },
                            new Map<String, Object>{
                                'apiName' => 'OwnerId',
                                'label' => '\u05D1\u05E2\u05DC\u05D9\u05DD',
                                'required' => false,
                                'editableForNew' => true,
                                'editableForUpdate' => true
                            },
                            new Map<String, Object>{
                                'apiName' => 'CreatedById',
                                'label' => '\u05E0\u05D5\u05E6\u05E8 \u05E2\u05DC \u05D9\u05D3\u05D9',
                                'required' => false,
                                'editableForNew' => false,
                                'editableForUpdate' => false
                            }
                        }
                    }
                },
                'warnings' => new List<Object>()
            }
        };
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
        System.runAs(new User(Id = UserInfo.getUserId())) {
        setAllProFlagsEnabled();

        List<NativeFormsDesignerController.SelectOption> objectOptions = NativeFormsDesignerController.getObjectOptions();
        List<NativeFormsDesignerController.SelectOption> picklistFieldOptions = NativeFormsDesignerController.getPicklistFieldOptions('Case', 'Picklist');
        List<NativeFormsDesignerController.SelectOption> multiPicklistFieldOptions = NativeFormsDesignerController.getPicklistFieldOptions('Case', 'MultiPicklist');
        List<NativeFormsDesignerController.SelectOption> picklistValueOptions = NativeFormsDesignerController.getPicklistValueOptions('Case', 'Origin');

        System.assert(containsDesignerOptionValue(objectOptions, 'Case'));
        System.assertEquals(0, NativeFormsDesignerController.getPicklistFieldOptions(null, 'Picklist').size());
        System.assert(containsDesignerOptionValue(picklistFieldOptions, 'Origin'));
        System.assertEquals(false, containsDesignerOptionValue(multiPicklistFieldOptions, 'Origin'), 'Multi Checkbox field picker should not show normal picklist fields.');
        System.assert(picklistValueOptions.size() > 0);
        System.assertEquals(0, NativeFormsDesignerController.getPicklistValueOptions('Case', null).size());
        }
    }

    @IsTest
    static void designerCreateWorkspaceAndFormSettingsBehaveAsExpected() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
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
            SELECT Id, Description__c, NF_Key__c, Theme__c, Project__c, Project__r.Name, Current_Draft_Version__c, Current_Published_Version__c
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
        System.assertEquals(true, workspace.enableProAdvancedSubmitModes);
        System.assertEquals(true, workspace.enableProPageLayoutClone);
        System.assertEquals(true, workspace.enableProCustomJs);
        System.assertEquals(true, workspace.enableProButtonElements);
        System.assertEquals(true, workspace.enableProMergedDocument);
        System.assertEquals(1000, workspace.maxForms);
        System.assertEquals(false, workspace.formLimitReached);
        System.assert(String.isNotBlank(workspace.upgradeUrl));
        System.assertEquals(themeRecord.Id, workspace.selectedTheme.id);

        NativeFormsDesignerController.NewFormResult cloneResult = NativeFormsDesignerController.cloneFormWithDraftVersion(
            createResult.formId,
            publishedVersion.Id,
            '  Intake Demo Copy  ',
            createResult.projectId,
            null
        );
        NF_Form__c clonedForm = [
            SELECT Id, Description__c, NF_Key__c, Project__c, Theme__c, Current_Draft_Version__c, Current_Published_Version__c
            FROM NF_Form__c
            WHERE Id = :cloneResult.formId
        ];
        NF_Form_Version__c clonedVersion = [
            SELECT Id, Form__c, Version_Number__c, Version_Status__c, Publish_Status__c, Security_Mode__c, UI_Settings_JSON__c
            FROM NF_Form_Version__c
            WHERE Id = :cloneResult.versionId
        ];
        System.assertEquals('Intake Demo Copy', clonedForm.Description__c);
        System.assertEquals(createResult.projectId, clonedForm.Project__c);
        System.assertEquals(themeRecord.Id, clonedForm.Theme__c);
        System.assertEquals(cloneResult.versionId, clonedForm.Current_Draft_Version__c);
        System.assertEquals(null, clonedForm.Current_Published_Version__c);
        System.assertNotEquals(createdForm.NF_Key__c, clonedForm.NF_Key__c);
        System.assertEquals(clonedForm.Id, clonedVersion.Form__c);
        System.assertEquals(1, clonedVersion.Version_Number__c);
        System.assertEquals('Draft', clonedVersion.Version_Status__c);
        System.assertEquals('Never Published', clonedVersion.Publish_Status__c);
        System.assertEquals(publishedVersion.Security_Mode__c, clonedVersion.Security_Mode__c);
        System.assertEquals(1, [
            SELECT COUNT()
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :cloneResult.versionId
        ]);
        System.assertEquals(2, [
            SELECT COUNT()
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :cloneResult.versionId
        ]);

        NativeFormsTestDataFactory.createElement(
            createResult.versionId,
            'text',
            'Damaged Draft Field',
            'damagedField',
            2,
            20,
            NativeFormsTestConfigFactory.textFieldConfigJson(),
            null
        );
        NativeFormsDesignerController.NewFormResult restoreResult =
            NativeFormsDesignerController.restoreDraftFromPublished(createResult.formId, publishedVersion.Id);
        NF_Form__c restoredForm = [
            SELECT Current_Draft_Version__c, Current_Published_Version__c
            FROM NF_Form__c
            WHERE Id = :createResult.formId
        ];
        NF_Form_Version__c restoredVersion = [
            SELECT Id, Form__c, Version_Number__c, Version_Status__c, Publish_Status__c, Security_Mode__c, UI_Settings_JSON__c
            FROM NF_Form_Version__c
            WHERE Id = :restoreResult.versionId
        ];
        System.assertEquals(createResult.formId, restoreResult.formId);
        System.assertEquals(createResult.projectId, restoreResult.projectId);
        System.assertEquals(restoredVersion.Id, restoredForm.Current_Draft_Version__c);
        System.assertEquals(publishedVersion.Id, restoredForm.Current_Published_Version__c);
        System.assertEquals(createResult.formId, restoredVersion.Form__c);
        System.assertEquals(3, restoredVersion.Version_Number__c);
        System.assertEquals('Draft', restoredVersion.Version_Status__c);
        System.assertEquals('Never Published', restoredVersion.Publish_Status__c);
        System.assertEquals(publishedVersion.Security_Mode__c, restoredVersion.Security_Mode__c);
        System.assertEquals(1, [
            SELECT COUNT()
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :restoreResult.versionId
        ]);
        System.assertEquals(0, [
            SELECT COUNT()
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :restoreResult.versionId
              AND Label__c = 'Damaged Draft Field'
        ]);
        System.assertEquals(2, [
            SELECT COUNT()
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :restoreResult.versionId
        ]);
        try {
            NativeFormsDesignerController.restoreDraftFromPublished(createResult.formId, createResult.versionId);
            System.assert(false, 'Restore should require selecting a published version.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        NativeFormsDesignerController.ElementSnapshotRecord undoSnapshot = new NativeFormsDesignerController.ElementSnapshotRecord();
        undoSnapshot.elementId = 'restoredText1';
        undoSnapshot.elementType = 'text';
        undoSnapshot.fieldKey = 'restoredText1';
        undoSnapshot.elementIndex = 99;
        undoSnapshot.label = 'Undo Restored Field';
        undoSnapshot.configJson = NativeFormsTestConfigFactory.textFieldConfigJson();
        undoSnapshot.orderValue = 10;
        NativeFormsDesignerController.restoreVersionElementsSnapshot(
            createResult.versionId,
            JSON.serialize(new List<NativeFormsDesignerController.ElementSnapshotRecord>{ undoSnapshot })
        );
        List<NF_Form_Element__c> undoRestoredElements = [
            SELECT Element_Id__c, Label__c, Element_Type__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :createResult.versionId
        ];
        System.assertEquals(1, undoRestoredElements.size());
        System.assertEquals('restoredText1', undoRestoredElements[0].Element_Id__c);
        System.assertEquals('Undo Restored Field', undoRestoredElements[0].Label__c);

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
        NativeFormsDesignerController.updateUserVerificationSessionMode(
            createResult.formId,
            createResult.versionId,
            'sameTabUntilMidnight'
        );
        NativeFormsDesignerController.updateVersionPostSubmitRedirectSettings(
            createResult.formId,
            createResult.versionId,
            true,
            'formula',
            'https://example.com/thanks?id={email1}',
            'IF({email1} != "", CONCAT("https://example.com/thanks?email=", URLENCODE({email1})), "")',
            '',
            5
        );
        NativeFormsDesignerController.updateVersionSubmissionPdfSettings(
            createResult.formId,
            createResult.versionId,
            true,
            true,
            'submit1',
            'Submitted Response',
            true
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
        System.assertEquals('formula', String.valueOf(updatedUiSettings.get('postSubmitUrlMode')));
        System.assertEquals('https://example.com/thanks?id={email1}', String.valueOf(updatedUiSettings.get('postSubmitUrlTemplate')));
        System.assertEquals('IF({email1} != "", CONCAT("https://example.com/thanks?email=", URLENCODE({email1})), "")', String.valueOf(updatedUiSettings.get('postSubmitUrlFormula')));
        System.assertEquals(true, updatedUiSettings.get('submitConditionalEnabled'));
        System.assertEquals(false, updatedUiSettings.get('userVerificationAllowResend'));
        System.assertEquals('sameTabUntilMidnight', String.valueOf(updatedUiSettings.get('userVerificationSessionMode')));
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
        System.assertEquals('formula', updatedWorkspace.selectedVersionPostSubmitUrlMode);
        System.assertEquals('https://example.com/thanks?id={email1}', updatedWorkspace.selectedVersionPostSubmitUrlTemplate);
        System.assertEquals('IF({email1} != "", CONCAT("https://example.com/thanks?email=", URLENCODE({email1})), "")', updatedWorkspace.selectedVersionPostSubmitUrlFormula);
        System.assertEquals('sameTabUntilMidnight', updatedWorkspace.selectedVersionUserVerificationSessionMode);
        System.assertEquals(true, updatedWorkspace.selectedVersionSubmitConditionalEnabled);
        System.assertEquals('email1', updatedWorkspace.selectedVersionSubmitConditionalFieldKey);
        System.assertEquals('window.TwinaForms.setValue("text6","+972");', updatedWorkspace.selectedVersionCustomJs);
        }
    }

    @IsTest
    static void pageLayoutImportCreatesSecureContactVerifiedDraft() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        setAllProFlagsEnabled();
        setPageLayoutMock();

        List<NativeFormsDesignerController.SelectOption> layoutOptions = NativeFormsDesignerController.getPageLayoutImportOptions('Contact', 'he');
        System.assertEquals(1, layoutOptions.size());
        System.assertEquals('assigned:012000000000000AAA', layoutOptions[0].value);
        System.assertEquals('\u05E4\u05E8\u05D9\u05E1\u05EA \u05D0\u05D9\u05E9 \u05E7\u05E9\u05E8', layoutOptions[0].label);

        NativeFormsDesignerController.PageLayoutImportPreview preview = NativeFormsDesignerController.previewPageLayoutImport(
            'Contact',
            layoutOptions[0].value,
            'secureUpdateOrCreate',
            'he'
        );
        System.assertEquals('Contact', preview.objectApiName);
        System.assertEquals('\u05D0\u05D9\u05E9 \u05E7\u05E9\u05E8', preview.objectLabel);
        System.assertEquals(5, preview.supportedFieldCount);
        System.assertEquals(1, preview.createOnlyFieldCount);
        System.assert(preview.warnings.size() > 0);

        NativeFormsDesignerController.NewFormResult result = NativeFormsDesignerController.createFormFromPageLayout(
            '  Contact Layout Form  ',
            null,
            null,
            null,
            'Contact',
            layoutOptions[0].value,
            'secureUpdateOrCreate',
            'he'
        );

        NF_Form_Version__c versionRecord = [
            SELECT Id, Form__c, Security_Mode__c, Prefill_Params_JSON__c, UI_Settings_JSON__c
            FROM NF_Form_Version__c
            WHERE Id = :result.versionId
        ];
        Map<String, Object> uiSettings = jsonMap(versionRecord.UI_Settings_JSON__c);
        System.assertEquals('he', String.valueOf(uiSettings.get('languageCode')));
        System.assertEquals(true, uiSettings.get('rtlEnabled'));
        System.assertEquals(true, uiSettings.get('userVerificationEnabled'));
        System.assertEquals('Email', String.valueOf(uiSettings.get('userVerificationMatchField')));
        System.assert(versionRecord.Prefill_Params_JSON__c.contains('recordId'));
        System.assertEquals(result.versionId, [
            SELECT Current_Draft_Version__c
            FROM NF_Form__c
            WHERE Id = :result.formId
        ].Current_Draft_Version__c);

        NF_Form_Action__c prefillAction = [
            SELECT Command_Key__c, Store_Result_As__c, Object_Api_Name__c
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :result.versionId
              AND Action_Scope__c = 'Prefill'
            LIMIT 1
        ];
        System.assertEquals('Prefill_Contact', prefillAction.Command_Key__c);
        System.assertEquals('Prefill_Contact', prefillAction.Store_Result_As__c);
        System.assertEquals('Contact', prefillAction.Object_Api_Name__c);

        NF_Form_Action__c submitAction = [
            SELECT Command_Key__c, Store_Result_As__c, Command_Type__c, Config_JSON__c
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :result.versionId
              AND Action_Scope__c = 'Submit'
            LIMIT 1
        ];
        Map<String, Object> submitConfig = jsonMap(submitAction.Config_JSON__c);
        System.assertEquals('Submit_Contact', submitAction.Command_Key__c);
        System.assertEquals('Submit_Contact', submitAction.Store_Result_As__c);
        System.assertEquals('updateById', submitAction.Command_Type__c);
        System.assertEquals('create', String.valueOf(submitConfig.get('onNotFound')));
        System.assertEquals('{input.recordId}', String.valueOf(submitConfig.get('recordIdSource')));

        System.assertEquals(1, [
            SELECT COUNT()
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :result.versionId
              AND Element_Type__c = 'hidden'
              AND Field_Key__c = 'recordId'
        ]);
        System.assert([
            SELECT COUNT()
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :result.versionId
              AND Parent_Element_Id__c IN ('layout-section-1', 'layout-section-2')
        ] > 0);
        NF_Form_Element__c firstNameElement = [
            SELECT Config_JSON__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :result.versionId
              AND Label__c = '\u05E9\u05DD \u05E4\u05E8\u05D8\u05D9'
            LIMIT 1
        ];
        NF_Form_Element__c emailElement = [
            SELECT Config_JSON__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :result.versionId
              AND Label__c = '\u05D0\u05D9\u05DE\u05D9\u05D9\u05DC'
            LIMIT 1
        ];
        NF_Form_Element__c accountElement = [
            SELECT Element_Type__c, Config_JSON__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :result.versionId
              AND Label__c = '\u05D7\u05E9\u05D1\u05D5\u05DF'
            LIMIT 1
        ];
        NF_Form_Element__c salutationElement = [
            SELECT Element_Type__c, Config_JSON__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :result.versionId
              AND Label__c = '\u05E4\u05E0\u05D9\u05D9\u05D4'
            LIMIT 1
        ];
        System.assertEquals(2, (Integer) jsonMap(firstNameElement.Config_JSON__c).get('sectionColumn'));
        System.assertEquals(1, (Integer) jsonMap(emailElement.Config_JSON__c).get('sectionColumn'));
        Map<String, Object> firstNameConfig = jsonMap(firstNameElement.Config_JSON__c);
        System.assertEquals('Prefill_Contact', String.valueOf(firstNameConfig.get('prefillAlias')));
        System.assertEquals('Submit_Contact', String.valueOf(firstNameConfig.get('submitActionKey')));
        Map<String, Object> accountConfig = jsonMap(accountElement.Config_JSON__c);
        System.assertEquals('lookup', accountElement.Element_Type__c);
        System.assertEquals('Account', String.valueOf(accountConfig.get('lookupTargetObject')));
        System.assertEquals('readonlyWhenPrefilled', String.valueOf(accountConfig.get('fieldBehavior')));
        System.assertEquals('create', String.valueOf(accountConfig.get('submitWhen')));
        System.assertEquals(false, accountConfig.get('required'));
        Map<String, Object> salutationConfig = jsonMap(salutationElement.Config_JSON__c);
        List<Object> salutationOptions = (List<Object>) salutationConfig.get('options');
        System.assertEquals('select', salutationElement.Element_Type__c);
        System.assertEquals('Contact', String.valueOf(salutationConfig.get('sourceObjectApiName')));
        System.assertEquals('Salutation', String.valueOf(salutationConfig.get('sourcePicklistFieldApiName')));
        System.assertEquals('\u05DE\u05E8', String.valueOf(((Map<String, Object>) salutationOptions[0]).get('label')));
        System.assertEquals('Mr.', String.valueOf(((Map<String, Object>) salutationOptions[0]).get('value')));
        System.assertEquals(5, result.importedFieldCount);
        System.assert(result.importDiagnosticsJson.contains('"createOnlyFieldCount"'));
        }
    }

    @IsTest
    static void designerCreateFormEnforcesPlanLimit() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
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
    }

    @IsTest
    static void designerDeleteUnpublishedFormRemovesDesignerRecords() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
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
    }

    @IsTest
    static void designerDeletePublishedFormUnpublishesRuntimeFirst() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
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
    }

    @IsTest
    static void designerDeletePublishedFormBlocksWhenUnpublishFails() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
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
    }

    @IsTest
    static void designerDefaultElementLabelsFollowSelectedLanguage() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        setAllProFlagsEnabled();

        NF_Form__c hebrewForm = NativeFormsTestDataFactory.createForm('Hebrew Label Defaults');
        NF_Form_Version__c hebrewVersion = NativeFormsTestDataFactory.createDraftVersion(hebrewForm.Id);
        hebrewVersion.UI_Settings_JSON__c = JSON.serialize(new Map<String, Object>{ 'languageCode' => 'he' });
        update hebrewVersion;

        System.assertEquals(
            '\u05EA\u05D0\u05E8\u05D9\u05DA',
            NativeFormsDesignerController.addElement(hebrewVersion.Id, 'date').label
        );
        System.assertEquals(
            '\u05DE\u05E1\u05E4\u05E8',
            NativeFormsDesignerController.addElement(hebrewVersion.Id, 'number').label
        );
        System.assertEquals(
            '\u05D8\u05DC\u05E4\u05D5\u05DF',
            NativeFormsDesignerController.addElement(hebrewVersion.Id, 'tel').label
        );
        NativeFormsDesignerController.ElementRecord textareaRecord = NativeFormsDesignerController.addElement(hebrewVersion.Id, 'textarea');
        System.assertEquals(254, (Integer) jsonMap(textareaRecord.configJson).get('maxLength'), 'Textarea should default to a safe regular Salesforce Text length.');
        System.assertEquals(
            '\u05E8\u05E9\u05D9\u05DE\u05EA \u05D1\u05D7\u05D9\u05E8\u05D4',
            NativeFormsDesignerController.addElement(hebrewVersion.Id, 'select').label
        );
        NativeFormsDesignerController.ElementRecord multiCheckboxRecord = NativeFormsDesignerController.addElement(hebrewVersion.Id, 'multiCheckbox');
        System.assertEquals('\u05D1\u05D7\u05D9\u05E8\u05D4 \u05DE\u05E8\u05D5\u05D1\u05D4', multiCheckboxRecord.label);
        System.assertEquals('multiCheckbox', multiCheckboxRecord.elementType);
        System.assert(multiCheckboxRecord.fieldKey.startsWith('multiPicklist'));
        System.assert(jsonMap(multiCheckboxRecord.configJson).containsKey('options'), 'Multi Checkbox should start with option config for canvas preview.');
        NativeFormsDesignerController.ElementRecord buttonRecord = NativeFormsDesignerController.addElement(hebrewVersion.Id, 'button');
        System.assertEquals('\u05D4\u05DE\u05E9\u05DA', buttonRecord.label, 'Button should receive the localized Continue label.');
        System.assertEquals(null, buttonRecord.fieldKey, 'Button is an action control and should not create submitted field data.');
        System.assertEquals(false, jsonMap(buttonRecord.configJson).get('submitBeforeNavigation'), 'Button should default to navigation without submit.');

        Map<String, String> expectedDateLabels = new Map<String, String>{
            'en' => 'Date',
            'es' => 'Fecha',
            'de' => 'Datum',
            'fr' => 'Date'
        };
        for (String languageCode : expectedDateLabels.keySet()) {
            NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Label Defaults ' + languageCode);
            NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createDraftVersion(formRecord.Id);
            versionRecord.UI_Settings_JSON__c = JSON.serialize(new Map<String, Object>{ 'languageCode' => languageCode });
            update versionRecord;
            System.assertEquals(
                expectedDateLabels.get(languageCode),
                NativeFormsDesignerController.addElement(versionRecord.Id, 'date').label,
                'Date label should follow language ' + languageCode
            );
        }
        }
    }

    @IsTest
    static void designerElementPlacementUploadAndDeleteBehaviorsWork() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        setAllProFlagsEnabled();

        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Designer Element Test');
        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createDraftVersion(formRecord.Id);
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, versionRecord.Id, null);

        NativeFormsDesignerController.ElementRecord sectionRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'section');
        NativeFormsDesignerController.ElementRecord textRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'text');
        NativeFormsDesignerController.ElementRecord timeRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'time');
        NativeFormsDesignerController.ElementRecord emailRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'email');
        NativeFormsDesignerController.ElementRecord imageRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'image');
        NativeFormsDesignerController.ElementRecord numberRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'number');
        NativeFormsDesignerController.ElementRecord dateRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'date');

        NativeFormsDesignerController.placeElementInSection(textRecord.id, sectionRecord.id, 10);
        NativeFormsDesignerController.moveElement(versionRecord.Id, numberRecord.id, sectionRecord.id, 1, 0);
        NativeFormsDesignerController.moveElement(versionRecord.Id, dateRecord.id, sectionRecord.id, 1, 1);
        NativeFormsDesignerController.moveElement(versionRecord.Id, dateRecord.id, sectionRecord.id, 1, 0);
        NativeFormsDesignerController.moveElement(versionRecord.Id, numberRecord.id, sectionRecord.id, 2, 0);
        NativeFormsDesignerController.insertElementAfter(emailRecord.id, textRecord.id);
        NativeFormsDesignerController.reorderElement(versionRecord.Id, emailRecord.id, 0);
        NativeFormsDesignerController.ElementRecord updatedSection = NativeFormsDesignerController.updateSectionColumns(sectionRecord.id, 10);

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
        NF_Form_Element__c movedNumber = [
            SELECT Id, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Id = :numberRecord.id
        ];
        NF_Form_Element__c movedDate = [
            SELECT Id, Config_JSON__c, Parent_Element_Id__c, Order__c
            FROM NF_Form_Element__c
            WHERE Id = :dateRecord.id
        ];
        NF_Form_Element__c updatedImage = [
            SELECT Id, Config_JSON__c
            FROM NF_Form_Element__c
            WHERE Id = :imageRecord.id
        ];

        System.assertEquals(sectionRecord.elementId, placedText.Parent_Element_Id__c);
        System.assertEquals(10, (Integer) jsonMap(placedText.Config_JSON__c).get('sectionColumn'));
        System.assertEquals(sectionRecord.elementId, movedDate.Parent_Element_Id__c);
        System.assertEquals(1, (Integer) jsonMap(movedDate.Config_JSON__c).get('sectionColumn'));
        System.assertEquals(2, (Integer) jsonMap(movedNumber.Config_JSON__c).get('sectionColumn'));
        System.assertEquals('Time', timeRecord.label);
        System.assertEquals('time', timeRecord.elementType);
        System.assert(String.valueOf(timeRecord.fieldKey).startsWith('time'));
        System.assertEquals('19:00', String.valueOf(jsonMap(timeRecord.configJson).get('placeholder')));
        System.assertEquals('24h', String.valueOf(jsonMap(timeRecord.configJson).get('timeFormat')));
        System.assertEquals(null, reorderedEmail.Parent_Element_Id__c);
        System.assertEquals(10, Integer.valueOf(String.valueOf(reorderedEmail.Order__c)));
        System.assertEquals(10, (Integer) jsonMap(updatedSection.configJson).get('columns'));
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
    }

    @IsTest
    static void designerPlanAndContainerGuardsWork() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
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
        try {
            NativeFormsDesignerController.addElement(versionRecord.Id, 'signature');
            System.assert(false, 'Signature fields should be blocked when the feature is disabled.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }
        try {
            NativeFormsDesignerController.addElement(versionRecord.Id, 'button');
            System.assert(false, 'Portal Buttons should be blocked when the feature is disabled.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }
        try {
            NativeFormsDesignerController.addElement(versionRecord.Id, 'mergedDocument');
            System.assert(false, 'Merged Document should be blocked when the feature is disabled.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        setFeatureFlags(true, true, true);
        NativeFormsDesignerController.ElementRecord repeatGroupRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'repeatGroup');
        NativeFormsDesignerController.ElementRecord fileUploadRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'fileUpload');
        NativeFormsDesignerController.ElementRecord signatureRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'signature');
        NativeFormsDesignerController.ElementRecord buttonRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'button');
        NativeFormsDesignerController.ElementRecord mergedDocumentRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'mergedDocument');
        NativeFormsDesignerController.ElementRecord sectionRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'section');
        NativeFormsDesignerController.ElementRecord groupRecord = NativeFormsDesignerController.addElement(versionRecord.Id, 'group');
        System.assertEquals('mergedDocument', mergedDocumentRecord.elementType);
        System.assertEquals('Merged Document', mergedDocumentRecord.label);

        try {
            NativeFormsDesignerController.placeElementInSection(fileUploadRecord.id, repeatGroupRecord.id, 1);
            System.assert(false, 'File uploads inside records lists should be rejected.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }
        NativeFormsDesignerController.placeElementInSection(signatureRecord.id, repeatGroupRecord.id, 1);
        NF_Form_Element__c placedSignature = [
            SELECT Parent_Element_Id__c
            FROM NF_Form_Element__c
            WHERE Id = :signatureRecord.id
        ];
        System.assertEquals(repeatGroupRecord.elementId, placedSignature.Parent_Element_Id__c, 'A Signature may be placed in a Records List.');
        NF_Form_Version__c signatureVersion = [SELECT UI_Settings_JSON__c FROM NF_Form_Version__c WHERE Id = :versionRecord.Id];
        System.assertEquals(true, jsonMap(signatureVersion.UI_Settings_JSON__c).get('submissionPdfEnabled'), 'A row Signature enables Submission PDF.');
        NativeFormsDesignerController.ElementRecord secondSignature = NativeFormsDesignerController.addElement(versionRecord.Id, 'signature');
        try {
            NativeFormsDesignerController.placeElementInSection(secondSignature.id, repeatGroupRecord.id, 1);
            System.assert(false, 'A second Signature inside one Records List should be rejected.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }
        NativeFormsDesignerController.placeElementInSection(buttonRecord.id, repeatGroupRecord.id, 1);
        NF_Form_Element__c placedButton = [
            SELECT Parent_Element_Id__c, Field_Key__c, Config_JSON__c
            FROM NF_Form_Element__c
            WHERE Id = :buttonRecord.id
        ];
        System.assertEquals(repeatGroupRecord.elementId, placedButton.Parent_Element_Id__c, 'Navigation Buttons may be placed in Records Lists.');
        System.assertEquals(null, placedButton.Field_Key__c, 'A row Button still has no submitted value.');
        System.assertEquals(false, jsonMap(placedButton.Config_JSON__c).get('submitBeforeNavigation'), 'A row Button must remain navigation-only.');

        try {
            NativeFormsDesignerController.placeElementInSection(groupRecord.id, sectionRecord.id, 1);
            System.assert(false, 'Groups cannot be nested inside another container.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        NativeFormsDesignerController.ElementRecord updatedRepeatGroup = NativeFormsDesignerController.updateSectionColumns(repeatGroupRecord.id, 10);
        System.assertEquals(10, (Integer) jsonMap(updatedRepeatGroup.configJson).get('columns'));

        try {
            NativeFormsDesignerController.updateSectionColumns(sectionRecord.id, 11);
            System.assert(false, 'Column counts above 10 should be rejected.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }
        try {
            NativeFormsDesignerController.placeElementInSection(fileUploadRecord.id, sectionRecord.id, 11);
            System.assert(false, 'Section placement above column 10 should be rejected.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }
        }
    }

    @IsTest
    static void builderWorkspaceCrudAndMoveBehaviorsWork() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
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
    }

    @IsTest
    static void builderValidationGuardsWork() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
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

        NativeFormsBuilderController.ElementUpsertInput signatureWithoutTarget = new NativeFormsBuilderController.ElementUpsertInput();
        signatureWithoutTarget.id = checkboxRecord.Id;
        signatureWithoutTarget.label = 'Signature';
        signatureWithoutTarget.fieldKey = 'signature1';
        signatureWithoutTarget.elementType = 'signature';
        signatureWithoutTarget.configJson = NativeFormsTestConfigFactory.signatureConfigJson(null);
        NativeFormsBuilderController.ElementRecord savedSignature = NativeFormsBuilderController.updateElement(JSON.serialize(signatureWithoutTarget));

        System.assertEquals('signature', savedSignature.elementType);
        System.assertEquals('Signature', savedSignature.label);

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
}
