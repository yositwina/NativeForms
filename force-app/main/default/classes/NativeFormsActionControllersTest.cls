@IsTest
private class NativeFormsActionControllersTest {
    private static NativeFormsTenantEntitlements.EntitlementSnapshot buildEntitlementsSnapshot(
        Boolean enableConditionLogic,
        Boolean enableRepeatGroups,
        Boolean enablePrefillAliasReferences,
        Boolean enableAdvancedSubmitModes
    ) {
        NativeFormsTenantEntitlements.EntitlementSnapshot snapshot = new NativeFormsTenantEntitlements.EntitlementSnapshot();
        snapshot.loadedSuccessfully = true;
        snapshot.orgId = UserInfo.getOrganizationId().substring(0, 15);
        snapshot.planCode = 'pro';
        snapshot.errorMessage = null;
        snapshot.effectiveFeatureFlags = new Map<String, Object>{
            'enableProConditionLogic' => enableConditionLogic == true,
            'enableProRepeatGroups' => enableRepeatGroups == true,
            'enableProPrefillAliasReferences' => enablePrefillAliasReferences == true,
            'enableProAdvancedSubmitModes' => enableAdvancedSubmitModes == true,
            'enableProFormulaFields' => true,
            'enableProPostSubmitAutoLink' => true,
            'enableProSfSecretCodeAuth' => true,
            'enableProLoadFile' => true
        };
        snapshot.effectiveLimits = new Map<String, Object>{
            'maxForms' => 1000,
            'maxSfUsers' => 5
        };
        return snapshot;
    }

    private static void setAllActionFlagsEnabled() {
        NativeFormsTenantEntitlements.setCachedSnapshot(
            buildEntitlementsSnapshot(true, true, true, true)
        );
    }

    private static void setActionFlags(
        Boolean enableConditionLogic,
        Boolean enableRepeatGroups,
        Boolean enablePrefillAliasReferences,
        Boolean enableAdvancedSubmitModes
    ) {
        NativeFormsTenantEntitlements.setCachedSnapshot(
            buildEntitlementsSnapshot(
                enableConditionLogic,
                enableRepeatGroups,
                enablePrefillAliasReferences,
                enableAdvancedSubmitModes
            )
        );
    }

    private static String json(Map<String, Object> value) {
        return JSON.serialize(value == null ? new Map<String, Object>() : value);
    }

    private static String prefillMappingConfig(String aliasValue, String fieldPath) {
        return json(new Map<String, Object>{
            'prefillEnabled' => true,
            'prefillAlias' => aliasValue,
            'prefillFieldPath' => fieldPath
        });
    }

    private static String submitMappingConfig(String actionKey, String fieldPath) {
        return json(new Map<String, Object>{
            'submitEnabled' => true,
            'submitActionKey' => actionKey,
            'submitFieldPath' => fieldPath
        });
    }

    private static String prefillConditionsConfig(List<Object> conditions) {
        return json(new Map<String, Object>{
            'where' => '',
            'onNotFound' => 'ignore',
            'conditions' => conditions == null ? new List<Object>() : conditions
        });
    }

    private static String submitConfig(Map<String, Object> extraValues) {
        Map<String, Object> config = extraValues == null
            ? new Map<String, Object>()
            : new Map<String, Object>(extraValues);
        return json(config);
    }

    private static Boolean containsPrefillOptionValue(
        List<NativeFormsPrefillActionsController.SelectOption> options,
        String expectedValue
    ) {
        for (NativeFormsPrefillActionsController.SelectOption optionValue : options) {
            if (optionValue != null && optionValue.value == expectedValue) {
                return true;
            }
        }
        return false;
    }

    private static Boolean containsSubmitOptionValue(
        List<NativeFormsSubmitActionsController.SelectOption> options,
        String expectedValue
    ) {
        for (NativeFormsSubmitActionsController.SelectOption optionValue : options) {
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
    static void prefillWorkspaceExposesActionsAliasesMappingsAndFieldOptions() {
        setAllActionFlagsEnabled();

        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Prefill Workspace Test');
        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createDraftVersion(formRecord.Id);
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, versionRecord.Id, null);

        NativeFormsTestDataFactory.createAction(
            versionRecord.Id,
            'Prefill',
            'Contact',
            'prefillContact',
            'contactAlias',
            'findOne',
            10,
            prefillConditionsConfig(new List<Object>{
                new Map<String, Object>{
                    'fieldPath' => 'Email',
                    'operator' => 'equals',
                    'valueSource' => 'url',
                    'valueText' => 'email'
                }
            })
        );
        NativeFormsTestDataFactory.createElement(
            versionRecord.Id,
            'text',
            'Email',
            'email1',
            1,
            10,
            prefillMappingConfig('contactAlias', 'Email'),
            null
        );
        NativeFormsTestDataFactory.createElement(
            versionRecord.Id,
            'checkbox',
            'Consent',
            'checkbox1',
            2,
            20,
            NativeFormsTestConfigFactory.checkboxConfigJson(false),
            null
        );

        NativeFormsPrefillActionsController.PrefillWorkspace workspace =
            NativeFormsPrefillActionsController.getWorkspace(versionRecord.Id);

        System.assertEquals(versionRecord.Id, workspace.selectedVersionId);
        System.assertEquals('Draft', workspace.selectedVersionStatus);
        System.assertEquals('Prefill Workspace Test', workspace.selectedFormName);
        System.assertEquals(1, workspace.actions.size());
        System.assertEquals('contactAlias', workspace.actions[0].storeResultAs);
        System.assertEquals(1, workspace.prefillAliasDetails.size());
        System.assertEquals('contactAlias', workspace.prefillAliasDetails[0].alias);
        System.assert(containsPrefillOptionValue(workspace.objectOptions, 'Contact'));
        System.assert(containsPrefillOptionValue(workspace.formFieldOptions, 'email1'));
        System.assertEquals(1, workspace.mappings.size());
        System.assertEquals('contactAlias', workspace.mappings[0].aliasValue);
        System.assertEquals('Email', workspace.mappings[0].fieldPath);
        System.assertEquals(true, workspace.enableProConditionLogic);
        System.assertEquals(true, workspace.enableProPrefillAliasReferences);
    }

    @IsTest
    static void prefillAddSaveDeleteAndOptionLookupWork() {
        setAllActionFlagsEnabled();

        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Prefill CRUD Test');
        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createDraftVersion(formRecord.Id);
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, versionRecord.Id, null);

        NativeFormsTestDataFactory.createAction(
            versionRecord.Id,
            'Prefill',
            'Contact',
            'prefillAction1',
            'foundRecord1',
            'findOne',
            10,
            '{}'
        );

        NativeFormsPrefillActionsController.PrefillActionRecord addedAction =
            NativeFormsPrefillActionsController.addPrefillAction(versionRecord.Id);
        System.assertEquals('findOne', addedAction.commandType);
        System.assertEquals('Contact', addedAction.objectApiName);
        System.assertEquals('prefillAction2', addedAction.actionKey);
        System.assertEquals('foundRecord2', addedAction.storeResultAs);

        NativeFormsPrefillActionsController.PrefillActionInput inputValue =
            new NativeFormsPrefillActionsController.PrefillActionInput();
        inputValue.id = addedAction.id;
        inputValue.versionId = versionRecord.Id;
        inputValue.actionKey = '';
        inputValue.commandType = 'findMany';
        inputValue.objectApiName = 'contact';
        inputValue.storeResultAs = 'primaryContact';
        inputValue.configJson = prefillConditionsConfig(new List<Object>{
            new Map<String, Object>{
                'fieldPath' => 'Email',
                'operator' => 'equals',
                'valueSource' => 'url',
                'valueText' => 'email'
            }
        });

        NativeFormsPrefillActionsController.PrefillActionRecord savedAction =
            NativeFormsPrefillActionsController.savePrefillAction(JSON.serialize(inputValue));
        List<NativeFormsPrefillActionsController.SelectOption> fieldOptions =
            NativeFormsPrefillActionsController.getFieldOptions('contact');

        NF_Form_Action__c persistedAction = [
            SELECT Command_Key__c, Command_Type__c, Object_Api_Name__c, Store_Result_As__c
            FROM NF_Form_Action__c
            WHERE Id = :addedAction.id
        ];

        System.assertEquals('primaryContact', savedAction.actionKey);
        System.assertEquals('findMany', savedAction.commandType);
        System.assertEquals('contact', savedAction.objectApiName);
        System.assertEquals('primaryContact', savedAction.storeResultAs);
        System.assertEquals('primaryContact', persistedAction.Command_Key__c);
        System.assertEquals('contact', persistedAction.Object_Api_Name__c);
        System.assert(containsPrefillOptionValue(fieldOptions, 'Email'));

        NativeFormsPrefillActionsController.deletePrefillAction(addedAction.id);
        System.assertEquals(0, [SELECT count() FROM NF_Form_Action__c WHERE Id = :addedAction.id]);
    }

    @IsTest
    static void prefillEntitlementAndPublishedVersionGuardsWork() {
        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Prefill Guard Test');
        NF_Form_Version__c draftVersion = NativeFormsTestDataFactory.createDraftVersion(formRecord.Id);
        NF_Form_Version__c publishedVersion = NativeFormsTestDataFactory.createVersion(
            formRecord.Id,
            2,
            'Published',
            'Published',
            NativeFormsTestConfigFactory.basicUiSettingsJson()
        );
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, draftVersion.Id, publishedVersion.Id);

        NF_Form_Action__c draftAction = NativeFormsTestDataFactory.createAction(
            draftVersion.Id,
            'Prefill',
            'Contact',
            'prefillContact',
            'foundRecord',
            'findOne',
            10,
            '{}'
        );

        setActionFlags(false, true, false, true);

        NativeFormsPrefillActionsController.PrefillActionInput multiConditionInput =
            new NativeFormsPrefillActionsController.PrefillActionInput();
        multiConditionInput.id = draftAction.Id;
        multiConditionInput.versionId = draftVersion.Id;
        multiConditionInput.actionKey = 'prefillContact';
        multiConditionInput.commandType = 'findOne';
        multiConditionInput.objectApiName = 'Contact';
        multiConditionInput.storeResultAs = 'foundRecord';
        multiConditionInput.configJson = prefillConditionsConfig(new List<Object>{
            new Map<String, Object>{ 'fieldPath' => 'Email', 'valueSource' => 'url', 'valueText' => 'email' },
            new Map<String, Object>{ 'fieldPath' => 'LastName', 'valueSource' => 'url', 'valueText' => 'lastName' }
        });
        try {
            NativeFormsPrefillActionsController.savePrefillAction(JSON.serialize(multiConditionInput));
            System.assert(false, 'Multi-condition prefill should be gated.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        NativeFormsPrefillActionsController.PrefillActionInput aliasInput =
            new NativeFormsPrefillActionsController.PrefillActionInput();
        aliasInput.id = draftAction.Id;
        aliasInput.versionId = draftVersion.Id;
        aliasInput.actionKey = 'prefillContact';
        aliasInput.commandType = 'findOne';
        aliasInput.objectApiName = 'Contact';
        aliasInput.storeResultAs = 'foundRecord';
        aliasInput.configJson = prefillConditionsConfig(new List<Object>{
            new Map<String, Object>{ 'fieldPath' => 'Email', 'valueSource' => 'alias', 'valueText' => '{foundRecord.Email}' }
        });
        try {
            NativeFormsPrefillActionsController.savePrefillAction(JSON.serialize(aliasInput));
            System.assert(false, 'Alias-based prefill should be gated.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        try {
            NativeFormsPrefillActionsController.addPrefillAction(publishedVersion.Id);
            System.assert(false, 'Published versions should remain read-only.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }
    }

    @IsTest
    static void submitWorkspaceExposesActionsAliasesMappingsAndRepeatGroups() {
        setAllActionFlagsEnabled();

        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Submit Workspace Test');
        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createDraftVersion(formRecord.Id);
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, versionRecord.Id, null);

        NativeFormsTestDataFactory.createAction(
            versionRecord.Id,
            'Prefill',
            'Contact',
            'prefillContact',
            'foundContact',
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
        NativeFormsTestDataFactory.createElement(
            versionRecord.Id,
            'repeatGroup',
            'Cases',
            'records1',
            1,
            10,
            NativeFormsTestConfigFactory.repeatGroupConfigJson(),
            null
        );
        NativeFormsTestDataFactory.createElement(
            versionRecord.Id,
            'text',
            'Email',
            'email1',
            2,
            20,
            submitMappingConfig('submitContact', 'Email'),
            null
        );

        NativeFormsSubmitActionsController.SubmitWorkspace workspace =
            NativeFormsSubmitActionsController.getWorkspace(versionRecord.Id);

        System.assertEquals(versionRecord.Id, workspace.selectedVersionId);
        System.assertEquals('Submit Workspace Test', workspace.selectedFormName);
        System.assertEquals(1, workspace.actions.size());
        System.assertEquals('submitContact', workspace.actions[0].actionKey);
        System.assertEquals(2, workspace.prefillAliasDetails.size());
        System.assertEquals(true, workspace.enableProConditionLogic);
        System.assertEquals(true, workspace.enableProRepeatGroups);
        System.assertEquals(true, workspace.enableProPrefillAliasReferences);
        System.assertEquals(true, workspace.enableProAdvancedSubmitModes);
        System.assert(containsSubmitOptionValue(workspace.objectOptions, 'Contact'));
        System.assert(containsSubmitOptionValue(workspace.formFieldOptions, 'email1'));
        System.assert(containsSubmitOptionValue(workspace.repeatGroupOptions, 'records1'));
        System.assertEquals(1, workspace.mappings.size());
        System.assertEquals('submitContact', workspace.mappings[0].actionKey);
        System.assertEquals('Email', workspace.mappings[0].fieldPath);
    }

    @IsTest
    static void submitAddSaveDeleteAndFieldLookupWork() {
        setAllActionFlagsEnabled();

        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Submit CRUD Test');
        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createDraftVersion(formRecord.Id);
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, versionRecord.Id, null);

        NativeFormsTestDataFactory.createAction(
            versionRecord.Id,
            'Submit',
            'Contact',
            'submitAction1',
            'savedRecord1',
            'create',
            10,
            '{}'
        );

        NativeFormsSubmitActionsController.SubmitActionRecord addedAction =
            NativeFormsSubmitActionsController.addSubmitAction(versionRecord.Id);
        System.assertEquals('create', addedAction.commandType);
        System.assertEquals('Contact', addedAction.objectApiName);
        System.assertEquals('submitAction2', addedAction.actionKey);
        System.assertEquals('savedRecord2', addedAction.storeResultAs);

        NativeFormsSubmitActionsController.SubmitActionInput inputValue =
            new NativeFormsSubmitActionsController.SubmitActionInput();
        inputValue.id = addedAction.id;
        inputValue.versionId = versionRecord.Id;
        inputValue.actionKey = '';
        inputValue.commandType = 'updateById';
        inputValue.objectApiName = 'contact';
        inputValue.storeResultAs = 'savedPerson';
        inputValue.configJson = submitConfig(new Map<String, Object>{
            'recordIdSource' => '{input.contactId}'
        });

        NativeFormsSubmitActionsController.SubmitActionRecord savedAction =
            NativeFormsSubmitActionsController.saveSubmitAction(JSON.serialize(inputValue));
        List<NativeFormsSubmitActionsController.SelectOption> fieldOptions =
            NativeFormsSubmitActionsController.getFieldOptions('contact');

        NF_Form_Action__c persistedAction = [
            SELECT Command_Key__c, Command_Type__c, Object_Api_Name__c, Store_Result_As__c
            FROM NF_Form_Action__c
            WHERE Id = :addedAction.id
        ];

        System.assertEquals('updateByIdcontact', savedAction.actionKey);
        System.assertEquals('Contact', savedAction.objectApiName);
        System.assertEquals('updateByIdcontact', persistedAction.Command_Key__c);
        System.assertEquals('Contact', persistedAction.Object_Api_Name__c);
        System.assertEquals('savedPerson', persistedAction.Store_Result_As__c);
        System.assert(containsSubmitOptionValue(fieldOptions, 'Email'));

        NativeFormsSubmitActionsController.deleteSubmitAction(addedAction.id);
        System.assertEquals(0, [SELECT count() FROM NF_Form_Action__c WHERE Id = :addedAction.id]);
    }

    @IsTest
    static void submitEntitlementAndPublishedVersionGuardsWork() {
        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Submit Guard Test');
        NF_Form_Version__c draftVersion = NativeFormsTestDataFactory.createDraftVersion(formRecord.Id);
        NF_Form_Version__c publishedVersion = NativeFormsTestDataFactory.createVersion(
            formRecord.Id,
            2,
            'Published',
            'Published',
            NativeFormsTestConfigFactory.basicUiSettingsJson()
        );
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, draftVersion.Id, publishedVersion.Id);

        NF_Form_Action__c draftAction = NativeFormsTestDataFactory.createAction(
            draftVersion.Id,
            'Submit',
            'Contact',
            'submitContact',
            'savedContact',
            'create',
            10,
            '{}'
        );

        setActionFlags(false, false, false, false);

        NativeFormsSubmitActionsController.SubmitActionInput advancedModeInput =
            new NativeFormsSubmitActionsController.SubmitActionInput();
        advancedModeInput.id = draftAction.Id;
        advancedModeInput.versionId = draftVersion.Id;
        advancedModeInput.actionKey = 'submitContact';
        advancedModeInput.commandType = 'updateById';
        advancedModeInput.objectApiName = 'Contact';
        advancedModeInput.storeResultAs = 'savedContact';
        advancedModeInput.configJson = submitConfig(new Map<String, Object>{
            'recordIdSource' => '{input.contactId}'
        });
        try {
            NativeFormsSubmitActionsController.saveSubmitAction(JSON.serialize(advancedModeInput));
            System.assert(false, 'Advanced submit modes should be gated.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        NativeFormsSubmitActionsController.SubmitActionInput repeatGroupInput =
            new NativeFormsSubmitActionsController.SubmitActionInput();
        repeatGroupInput.id = draftAction.Id;
        repeatGroupInput.versionId = draftVersion.Id;
        repeatGroupInput.actionKey = 'submitContact';
        repeatGroupInput.commandType = 'upsertMany';
        repeatGroupInput.objectApiName = 'Case';
        repeatGroupInput.storeResultAs = 'savedCases';
        repeatGroupInput.configJson = submitConfig(new Map<String, Object>{
            'repeatGroupFieldKey' => 'records1'
        });
        try {
            NativeFormsSubmitActionsController.saveSubmitAction(JSON.serialize(repeatGroupInput));
            System.assert(false, 'Records-list submit mode should be gated.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        NativeFormsSubmitActionsController.SubmitActionInput conditionLogicInput =
            new NativeFormsSubmitActionsController.SubmitActionInput();
        conditionLogicInput.id = draftAction.Id;
        conditionLogicInput.versionId = draftVersion.Id;
        conditionLogicInput.actionKey = 'submitContact';
        conditionLogicInput.commandType = 'create';
        conditionLogicInput.objectApiName = 'Contact';
        conditionLogicInput.storeResultAs = 'savedContact';
        conditionLogicInput.configJson = submitConfig(new Map<String, Object>{
            'conditions' => new List<Object>{
                new Map<String, Object>{ 'fieldPath' => 'Email', 'valueSource' => 'field', 'valueText' => 'email1' },
                new Map<String, Object>{ 'fieldPath' => 'LastName', 'valueSource' => 'field', 'valueText' => 'lastName1' }
            }
        });
        try {
            NativeFormsSubmitActionsController.saveSubmitAction(JSON.serialize(conditionLogicInput));
            System.assert(false, 'Advanced condition logic should be gated.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        NativeFormsSubmitActionsController.SubmitActionInput aliasConditionInput =
            new NativeFormsSubmitActionsController.SubmitActionInput();
        aliasConditionInput.id = draftAction.Id;
        aliasConditionInput.versionId = draftVersion.Id;
        aliasConditionInput.actionKey = 'submitContact';
        aliasConditionInput.commandType = 'create';
        aliasConditionInput.objectApiName = 'Contact';
        aliasConditionInput.storeResultAs = 'savedContact';
        aliasConditionInput.configJson = submitConfig(new Map<String, Object>{
            'conditions' => new List<Object>{
                new Map<String, Object>{ 'fieldPath' => 'Email', 'valueSource' => 'alias', 'valueText' => '{foundContact.Email}' }
            }
        });
        try {
            NativeFormsSubmitActionsController.saveSubmitAction(JSON.serialize(aliasConditionInput));
            System.assert(false, 'Alias conditions should be gated.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        NativeFormsSubmitActionsController.SubmitActionInput aliasRelationshipInput =
            new NativeFormsSubmitActionsController.SubmitActionInput();
        aliasRelationshipInput.id = draftAction.Id;
        aliasRelationshipInput.versionId = draftVersion.Id;
        aliasRelationshipInput.actionKey = 'submitContact';
        aliasRelationshipInput.commandType = 'create';
        aliasRelationshipInput.objectApiName = 'Case';
        aliasRelationshipInput.storeResultAs = 'savedCase';
        aliasRelationshipInput.configJson = submitConfig(new Map<String, Object>{
            'relationshipValueSource' => 'alias',
            'relationshipValueText' => '{foundContact.Id}'
        });
        try {
            NativeFormsSubmitActionsController.saveSubmitAction(JSON.serialize(aliasRelationshipInput));
            System.assert(false, 'Alias relationship values should be gated.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        NativeFormsSubmitActionsController.SubmitActionInput aliasRecordIdInput =
            new NativeFormsSubmitActionsController.SubmitActionInput();
        aliasRecordIdInput.id = draftAction.Id;
        aliasRecordIdInput.versionId = draftVersion.Id;
        aliasRecordIdInput.actionKey = 'submitContact';
        aliasRecordIdInput.commandType = 'create';
        aliasRecordIdInput.objectApiName = 'Contact';
        aliasRecordIdInput.storeResultAs = 'savedContact';
        aliasRecordIdInput.configJson = submitConfig(new Map<String, Object>{
            'recordIdSource' => '{savedContact.Id}'
        });
        try {
            NativeFormsSubmitActionsController.saveSubmitAction(JSON.serialize(aliasRecordIdInput));
            System.assert(false, 'Alias record-id expressions should be gated.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }

        try {
            NativeFormsSubmitActionsController.addSubmitAction(publishedVersion.Id);
            System.assert(false, 'Published versions should remain read-only.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e);
        }
    }
}
