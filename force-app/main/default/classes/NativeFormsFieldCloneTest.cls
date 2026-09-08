@IsTest
private class NativeFormsFieldCloneTest {
    @TestSetup
    static void setupPermissions() {
        NativeFormsTestDataFactory.assignTwinaFormsUserPermissionSet();
        NativeFormsBootstrapV2Signer.getOrCreateSigningSecretB64();
    }

    private static Id draftVersion() {
        return NativeFormsTestDataFactory.createDraftVersion(
            NativeFormsTestDataFactory.createForm('Clone field test').Id
        ).Id;
    }

    private static void enableProFeatures() {
        NativeFormsTenantEntitlements.EntitlementSnapshot snapshot = new NativeFormsTenantEntitlements.EntitlementSnapshot();
        snapshot.loadedSuccessfully = true;
        snapshot.orgId = UserInfo.getOrganizationId().substring(0, 15);
        snapshot.planCode = 'pro';
        snapshot.effectiveFeatureFlags = new Map<String, Object>{
            'enableProRepeatGroups' => true, 'enableProElectronicSignature' => true,
            'enableProSubmissionPdf' => true, 'enableProFormulaFields' => true,
            'enableProConditionLogic' => true
        };
        snapshot.effectiveLimits = new Map<String, Object>{'maxForms' => 1000, 'maxSfUsers' => 5};
        NativeFormsTenantEntitlements.setCachedSnapshot(snapshot);
    }

    private static String input(NF_Form_Element__c source, String config) {
        return JSON.serialize(new Map<String, Object>{
            'id' => source.Id, 'label' => source.Label__c,
            'fieldKey' => source.Field_Key__c, 'elementType' => source.Element_Type__c,
            'configJson' => config
        });
    }

    private static void assertRejected(NF_Form_Element__c source) {
        Integer beforeCount = [SELECT COUNT() FROM NF_Form_Element__c];
        Boolean rejected = false;
        try {
            NativeFormsDesignerController.cloneField(input(source, source.Config_JSON__c));
        } catch (AuraHandledException expected) {
            rejected = true;
        }
        System.assert(rejected, 'Unsupported clone must be rejected.');
        System.assertEquals(beforeCount, [SELECT COUNT() FROM NF_Form_Element__c],
            'Rejected clone must not leave a partial field.');
    }

    @IsTest
    static void preservesCurrentSnapshotAndReferences() {
        enableProFeatures();
        Id versionId = draftVersion();
        NF_Form_Element__c source = NativeFormsTestDataFactory.createElement(
            versionId, 'text', 'Original', 'sourceKey', 1, 10, '{}', null);
        NF_Form_Element__c next = NativeFormsTestDataFactory.createElement(
            versionId, 'text', 'Next', 'text3', 2, 20, '{}', null);
        String config = '{ "required": true, "isFormula":true,"formulaExpression":"{sourceKey} & {otherKey}",'
            + ' "prefillEnabled":true,"prefillAlias":"contacts","prefillFieldPath":"Name",'
            + ' "submitEnabled":true,"submitActionKey":"saveContact","submitFieldPath":"LastName",'
            + ' "conditionalEnabled":true,"conditionalConditions":[{"fieldKey":"otherKey","operator":"equals","value":"True"}],'
            + ' "futureAttribute":{"nested":[1,true,"kept"]} }';
        source.Label__c = 'Latest unsaved label';
        Test.startTest();
        NativeFormsDesignerController.ElementRecord result = NativeFormsDesignerController.cloneField(input(source, config));
        Test.stopTest();
        NF_Form_Element__c cloned = [SELECT Id, Element_Id__c, Field_Key__c, Element_Index__c,
            Label__c, Config_JSON__c, Parent_Element_Id__c, Order__c FROM NF_Form_Element__c WHERE Id = :result.id];
        System.assertNotEquals(source.Id, cloned.Id);
        System.assertNotEquals(source.Element_Id__c, cloned.Element_Id__c);
        System.assertNotEquals(source.Field_Key__c, cloned.Field_Key__c);
        System.assertNotEquals(next.Field_Key__c, cloned.Field_Key__c, 'Customized keys must not collide.');
        System.assert(cloned.Element_Index__c > next.Element_Index__c);
        System.assertEquals(source.Label__c, cloned.Label__c);
        System.assertEquals(config, cloned.Config_JSON__c, 'Preserve all configuration and formula references exactly.');
        System.assertEquals(null, cloned.Parent_Element_Id__c);
        List<NF_Form_Element__c> ordered = [SELECT Id FROM NF_Form_Element__c WHERE Form_Version__c = :versionId ORDER BY Order__c];
        System.assertEquals(source.Id, ordered[0].Id);
        System.assertEquals(cloned.Id, ordered[1].Id);
        System.assertEquals(next.Id, ordered[2].Id);
    }

    @IsTest
    static void staysInSameRecordsListColumn() {
        enableProFeatures();
        Id versionId = draftVersion();
        NF_Form_Element__c parent = NativeFormsTestDataFactory.createElement(
            versionId, 'repeatGroup', 'Rows', 'rows', 1, 10, '{"columns":2}', null);
        NF_Form_Element__c source = NativeFormsTestDataFactory.createElement(
            versionId, 'text', 'Source', 'source', 2, 10, '{"sectionColumn":2}', parent.Element_Id__c);
        NF_Form_Element__c otherColumn = NativeFormsTestDataFactory.createElement(
            versionId, 'text', 'Other column', 'other', 3, 20, '{"sectionColumn":1}', parent.Element_Id__c);
        NF_Form_Element__c next = NativeFormsTestDataFactory.createElement(
            versionId, 'text', 'Next', 'next', 4, 30, '{"sectionColumn":2}', parent.Element_Id__c);
        Test.startTest();
        NativeFormsDesignerController.ElementRecord result = NativeFormsDesignerController.cloneField(input(source, source.Config_JSON__c));
        Test.stopTest();
        NF_Form_Element__c cloned = [SELECT Parent_Element_Id__c, Config_JSON__c, Order__c FROM NF_Form_Element__c WHERE Id = :result.id];
        System.assertEquals(parent.Element_Id__c, cloned.Parent_Element_Id__c);
        System.assertEquals(source.Config_JSON__c, cloned.Config_JSON__c);
        List<NF_Form_Element__c> ordered = [SELECT Id FROM NF_Form_Element__c
            WHERE Parent_Element_Id__c = :parent.Element_Id__c ORDER BY Order__c];
        System.assertEquals(source.Id, ordered[0].Id);
        System.assertEquals(result.id, ordered[1].Id);
        System.assertEquals(otherColumn.Id, ordered[2].Id);
        System.assertEquals(next.Id, ordered[3].Id);
    }

    @IsTest
    static void rejectsContainersAndDisplayElements() {
        Id versionId = draftVersion();
        for (String kind : new List<String>{'section', 'group', 'repeatGroup', 'heading', 'image', 'button', 'spacer'}) {
            assertRejected(NativeFormsTestDataFactory.createElement(versionId, kind, kind, null, null, null, '{}', null));
        }
    }

    @IsTest
    static void rejectsPublishedVersion() {
        Id versionId = NativeFormsTestDataFactory.createVersion(
            NativeFormsTestDataFactory.createForm('Published clone test').Id,
            1, 'Published', 'Published', '{}').Id;
        assertRejected(NativeFormsTestDataFactory.createElement(versionId, 'text', 'Field', 'field1', 1, 10, '{}', null));
    }

    @IsTest
    static void rejectsSecondRecordsListSignature() {
        enableProFeatures();
        Id versionId = draftVersion();
        NF_Form_Element__c parent = NativeFormsTestDataFactory.createElement(
            versionId, 'repeatGroup', 'Rows', 'rows', 1, 10, '{"columns":1}', null);
        assertRejected(NativeFormsTestDataFactory.createElement(
            versionId, 'signature', 'Sign', 'signature2', 2, 10, '{"sectionColumn":1}', parent.Element_Id__c));
    }

    @IsTest
    static void rejectsFormulaAfterDowngrade() {
        NativeFormsTenantEntitlements.EntitlementSnapshot snapshot = new NativeFormsTenantEntitlements.EntitlementSnapshot();
        snapshot.loadedSuccessfully = true;
        snapshot.orgId = UserInfo.getOrganizationId().substring(0, 15);
        snapshot.planCode = 'starter';
        snapshot.effectiveFeatureFlags = new Map<String, Object>{'enableProFormulaFields' => false};
        snapshot.effectiveLimits = new Map<String, Object>{'maxForms' => 1000, 'maxSfUsers' => 5};
        NativeFormsTenantEntitlements.setCachedSnapshot(snapshot);
        assertRejected(NativeFormsTestDataFactory.createElement(draftVersion(), 'text', 'Formula', 'formula1', 1, 10,
            '{"isFormula":true,"formulaExpression":"1 + 2"}', null));
    }
}
