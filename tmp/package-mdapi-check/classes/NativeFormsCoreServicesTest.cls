@IsTest
private class NativeFormsCoreServicesTest {
    @TestSetup
    static void setupPermissions() {
        NativeFormsTestDataFactory.assignTwinaFormsUserPermissionSet();
        NativeFormsBootstrapV2Signer.getOrCreateSigningSecretB64();
    }

    @IsTest
    static void formTriggerAssignsDefaultsAndTrimsDescriptions() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        NF_Form__c formRecord = new NF_Form__c(
            Description__c = '  Intake form  '
        );

        insert formRecord;

        NF_Form__c savedForm = [
            SELECT Description__c, NF_Key__c, Project__c, Project__r.Name
            FROM NF_Form__c
            WHERE Id = :formRecord.Id
        ];

        System.assertEquals('Intake form', savedForm.Description__c);
        System.assertNotEquals(null, savedForm.Project__c);
        System.assertEquals(NativeFormsProjectService.DEFAULT_PROJECT_NAME, savedForm.Project__r.Name);
        System.assert(savedForm.NF_Key__c != null && savedForm.NF_Key__c.startsWith('form'));

        savedForm.Description__c = '  Updated intake form  ';
        update savedForm;

        savedForm = [
            SELECT Description__c
            FROM NF_Form__c
            WHERE Id = :savedForm.Id
        ];
        System.assertEquals('Updated intake form', savedForm.Description__c);
        }
    }

    @IsTest
    static void formTriggerRejectsBlankDescription() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        try {
            insert new NF_Form__c(
                Description__c = '   '
            );
            System.assert(false, 'Blank descriptions should be rejected.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Description is required.'));
        }
        }
    }

    @IsTest
    static void formTriggerContinuesAutoKeySequenceFromExistingRecords() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        NF_Form__c existingForm = NativeFormsTestDataFactory.createForm('Existing form', null, 'form7');
        NF_Form__c newForm = NativeFormsTestDataFactory.createForm('New form');

        System.assertEquals('form7', existingForm.NF_Key__c);
        System.assertEquals('form8', newForm.NF_Key__c);
        }
    }

    @IsTest
    static void projectServiceCreatesSystemProjectsBackfillsFormsAndBlocksDelete() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        Id defaultProjectId = NativeFormsProjectService.ensureDefaultProjectId();
        Id archiveProjectId = NativeFormsProjectService.ensureArchiveProjectId();

        System.assertNotEquals(null, defaultProjectId);
        System.assertNotEquals(null, archiveProjectId);
        System.assertNotEquals(defaultProjectId, archiveProjectId);
        System.assertEquals(defaultProjectId, NativeFormsProjectService.ensureProjectByName(NativeFormsProjectService.DEFAULT_PROJECT_NAME));
        System.assertEquals(archiveProjectId, NativeFormsProjectService.ensureProjectByName(NativeFormsProjectService.ARCHIVE_PROJECT_NAME));

        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Needs backfill');
        update new NF_Form__c(
            Id = formRecord.Id,
            Project__c = null
        );

        Test.startTest();
        Id backfilledProjectId = NativeFormsProjectService.ensureDefaultProjectAndBackfillForms();
        Test.stopTest();

        formRecord = [
            SELECT Project__c
            FROM NF_Form__c
            WHERE Id = :formRecord.Id
        ];
        System.assertEquals(defaultProjectId, backfilledProjectId);
        System.assertEquals(defaultProjectId, formRecord.Project__c);

        NF_Project__c deleteBlockedProject = NativeFormsTestDataFactory.createProject('Customer Intake');
        NativeFormsTestDataFactory.createForm('Delete blocked form', deleteBlockedProject.Id);

        try {
            delete deleteBlockedProject;
            System.assert(false, 'Projects with linked forms should be blocked from deletion.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Reassign or remove the forms in this project before deleting it.'));
        }
        }
    }

    @IsTest
    static void projectTriggerTrimsNamesAndRejectsDuplicates() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        NF_Project__c trimmedProject = new NF_Project__c(
            Name = '  Sales Operations  '
        );
        insert trimmedProject;

        trimmedProject = [
            SELECT Name
            FROM NF_Project__c
            WHERE Id = :trimmedProject.Id
        ];
        System.assertEquals('Sales Operations', trimmedProject.Name);

        try {
            insert new NF_Project__c(
                Name = ' sales operations '
            );
            System.assert(false, 'Duplicate project names should be rejected.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('A project with this name already exists.'));
        }

        try {
            insert new NF_Project__c(
                Name = '   '
            );
            System.assert(false, 'Blank project names should be rejected.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Project name is required.'));
        }
        }
    }

    @IsTest
    static void projectServiceResolvesExistingNewAndDefaultProjects() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        Id defaultProjectId = NativeFormsProjectService.resolveProjectId(null, null);
        NF_Project__c existingProject = NativeFormsTestDataFactory.createProject('Operations');

        System.assertEquals(defaultProjectId, NativeFormsProjectService.ensureDefaultProjectId());
        System.assertEquals(existingProject.Id, NativeFormsProjectService.resolveProjectId(existingProject.Id, null));

        Id newProjectId = NativeFormsProjectService.resolveProjectId(null, '  Customer Success  ');
        NF_Project__c newProject = [
            SELECT Name
            FROM NF_Project__c
            WHERE Id = :newProjectId
        ];
        System.assertEquals('Customer Success', newProject.Name);
        System.assertEquals('Ops', NativeFormsProjectService.normalizeProjectName(' Ops '));
        System.assertEquals(null, NativeFormsProjectService.normalizeProjectName('   '));

        try {
            NativeFormsProjectService.resolveProjectId(null, 'Customer Success');
            System.assert(false, 'Duplicate project names should throw an AuraHandledException.');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e);
        }
        }
    }

    @IsTest
    static void awsClientSupportsDirectSignedHappyPathCallouts() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        NativeFormsAwsClient.PresignRequest requestBody = new NativeFormsAwsClient.PresignRequest();
        requestBody.orgId = UserInfo.getOrganizationId().substring(0, 15);
        requestBody.formId = 'a01xx0000000001';
        requestBody.formSlug = 'contact-form';
        requestBody.versionId = 'a02xx0000000001';
        requestBody.fileName = 'contact-form.html';
        requestBody.contentType = 'text/html';
        requestBody.expires = 900;

        NativeFormsAwsMockFactory.RoutingMock mock = new NativeFormsAwsMockFactory.RoutingMock()
            .addJsonResponse(
                '/forms/publish/presign',
                200,
                new Map<String, Object>{
                    'success' => true,
                    'putUrl' => 'https://upload.example.com/nativeforms/contact-form.html',
                    'publicUrl' => 'https://forms.twinaforms.com/contact-form',
                    'key' => 'company/contact-form.html'
                }
            )
            .addJsonResponse(
                'https://upload.example.com/nativeforms/contact-form.html',
                200,
                new Map<String, Object>{
                    'success' => true
                }
            )
            .addJsonResponse(
                '/forms/register',
                200,
                new Map<String, Object>{
                    'success' => true,
                    'formSlug' => 'contact-form'
                }
            )
            .addJsonResponse(
                '/salesforce/layouts',
                200,
                new Map<String, Object>{
                    'success' => true,
                    'defaultLayoutKey' => 'assigned:012000000000000AAA',
                    'layouts' => new List<Object>{
                        new Map<String, Object>{
                            'label' => 'Contact assigned layout',
                            'value' => 'assigned:012000000000000AAA'
                        }
                    }
                }
            )
            .addJsonResponse(
                '/connected-orgs/connect/start',
                200,
                new Map<String, Object>{
                    'success' => true,
                    'connectUrl' => 'https://login.salesforce.com/services/oauth2/authorize'
                }
            )
            .addJsonResponse(
                '/connected-orgs',
                200,
                new Map<String, Object>{
                    'success' => true,
                    'groupId' => 'group_test',
                    'orgs' => new List<Object>()
                }
            )
            .addJsonResponse(
                '/portable-snapshots/latest',
                200,
                new Map<String, Object>{
                    'success' => true,
                    'snapshotId' => '00Dxx0000000000#form35'
                }
            )
            .addJsonResponse(
                '/portable-snapshots/00Dxx000000001',
                200,
                new Map<String, Object>{
                    'success' => true,
                    'portableJson' => '{"packageType":"twinaformsFormDefinition"}'
                }
            )
            .addJsonResponse(
                '/portable-snapshots',
                200,
                new Map<String, Object>{
                    'success' => true,
                    'snapshots' => new List<Object>()
                }
            );

        Test.setMock(HttpCalloutMock.class, mock);
        NativeFormsBootstrapV2Signer.getOrCreateSigningSecretB64();

        Test.startTest();
        NativeFormsAwsClient.PresignResponse presignResponse = NativeFormsAwsClient.presignHtml(requestBody);
        NativeFormsAwsClient.uploadHtml(presignResponse.putUrl, '<html>test</html>');
        Map<String, Object> registerResponse = NativeFormsAwsClient.registerForm(new Map<String, Object>{
            'orgId' => requestBody.orgId,
            'formSlug' => requestBody.formSlug
        });
        Map<String, Object> layoutResponse = NativeFormsAwsClient.getSalesforceLayouts(new Map<String, Object>{
            'orgId' => requestBody.orgId,
            'objectApiName' => 'Contact'
        });
        Map<String, Object> connectResponse = NativeFormsAwsClient.startConnectedOrg(new Map<String, Object>{
            'orgId' => requestBody.orgId,
            'loginBaseUrl' => 'https://login.salesforce.com'
        });
        Map<String, Object> connectedOrgResponse = NativeFormsAwsClient.listConnectedOrgs(requestBody.orgId);
        Map<String, Object> snapshotSaveResponse = NativeFormsAwsClient.savePortableSnapshot(new Map<String, Object>{
            'sourceOrgId' => requestBody.orgId,
            'globalFormKey' => 'form35',
            'portableJson' => '{}'
        });
        Map<String, Object> snapshotListResponse = NativeFormsAwsClient.listPortableSnapshots(requestBody.orgId);
        Map<String, Object> snapshotGetResponse = NativeFormsAwsClient.getPortableSnapshot(requestBody.orgId, '00Dxx000000001', 'form35');
        Test.stopTest();

        System.assertEquals('https://upload.example.com/nativeforms/contact-form.html', presignResponse.putUrl);
        System.assertEquals('https://forms.twinaforms.com/contact-form', presignResponse.publicUrl);
        System.assertEquals('company/contact-form.html', presignResponse.key);
        System.assertEquals(true, registerResponse.get('success'));
        System.assertEquals('contact-form', String.valueOf(registerResponse.get('formSlug')));
        System.assertEquals('assigned:012000000000000AAA', String.valueOf(layoutResponse.get('defaultLayoutKey')));
        System.assertEquals(true, connectResponse.get('success'));
        System.assertEquals('group_test', String.valueOf(connectedOrgResponse.get('groupId')));
        System.assertEquals(true, snapshotSaveResponse.get('success'));
        System.assertEquals(true, snapshotListResponse.get('success'));
        System.assertEquals('{"packageType":"twinaformsFormDefinition"}', String.valueOf(snapshotGetResponse.get('portableJson')));
        }
    }

    @IsTest
    static void awsClientThrowsOnFailedOrIncompleteResponses() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        NativeFormsAwsClient.PresignRequest requestBody = new NativeFormsAwsClient.PresignRequest();
        requestBody.orgId = UserInfo.getOrganizationId().substring(0, 15);

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock().addJsonResponse(
                '/forms/publish/presign',
                500,
                new Map<String, Object>{ 'error' => 'Presign down' }
            )
        );
        try {
            NativeFormsAwsClient.presignHtml(requestBody);
            System.assert(false, 'A failed presign response should throw.');
        } catch (CalloutException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock().addJsonResponse(
                '/forms/publish/presign',
                200,
                new Map<String, Object>{
                    'success' => true,
                    'putUrl' => 'https://upload.example.com/nativeforms/contact-form.html'
                }
            )
        );
        try {
            NativeFormsAwsClient.presignHtml(requestBody);
            System.assert(false, 'A partial presign response should throw.');
        } catch (CalloutException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock().addJsonResponse(
                'https://upload.example.com/nativeforms/contact-form.html',
                500,
                new Map<String, Object>{ 'error' => 'Upload down' }
            )
        );
        try {
            NativeFormsAwsClient.uploadHtml('https://upload.example.com/nativeforms/contact-form.html', '<html>test</html>');
            System.assert(false, 'A failed HTML upload should throw.');
        } catch (CalloutException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock().addJsonResponse(
                '/forms/register',
                500,
                new Map<String, Object>{ 'error' => 'Register down' }
            )
        );
        try {
            NativeFormsAwsClient.registerForm(new Map<String, Object>{ 'formSlug' => 'contact-form' });
            System.assert(false, 'A failed register response should throw.');
        } catch (CalloutException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock().addJsonResponse(
                '/salesforce/layouts',
                500,
                new Map<String, Object>{ 'error' => 'Layouts down' }
            )
        );
        try {
            NativeFormsAwsClient.getSalesforceLayouts(new Map<String, Object>{ 'objectApiName' => 'Contact' });
            System.assert(false, 'A failed Salesforce layout response should throw.');
        } catch (CalloutException e) {
            System.assert(String.isNotBlank(e.getMessage()));
        }
        }
    }

    @IsTest
    static void tenantEntitlementsLoadSuccessfullyAndFeatureFlagsFollowTheSnapshot() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        NativeFormsTenantEntitlements.resetCache();

        Map<String, Object> featureFlags = new Map<String, Object>{
            'enableProConditionLogic' => true,
            'enableProRepeatGroups' => false,
            'enableProPrefillAliasReferences' => 'true',
            'enableProAdvancedSubmitModes' => true,
            'enableProPageLayoutClone' => true,
            'enableProFormulaFields' => true,
            'enableProPostSubmitAutoLink' => 'true',
            'enableProUserVerification' => true,
            'enableProLoadFile' => true,
            'enableProCustomJs' => true
        };
        Map<String, Object> limits = new Map<String, Object>{
            'maxSfUsers' => 5,
            'maxForms' => 1000
        };

        Test.setMock(HttpCalloutMock.class, NativeFormsAwsMockFactory.entitlementsSuccess(featureFlags, limits, 'pro'));
        NativeFormsBootstrapV2Signer.getOrCreateSigningSecretB64();

        Test.startTest();
        NativeFormsTenantEntitlements.EntitlementSnapshot snapshot = NativeFormsTenantEntitlements.getCurrentOrgEntitlements();
        Boolean conditionLogic = NativeFormsFeatureFlags.isProConditionLogicEnabled();
        Boolean repeatGroups = NativeFormsFeatureFlags.isProRepeatGroupsEnabled();
        Boolean prefillAliases = NativeFormsFeatureFlags.isProPrefillAliasReferencesEnabled();
        Boolean advancedSubmit = NativeFormsFeatureFlags.isProAdvancedSubmitModesEnabled();
        Boolean pageLayoutClone = NativeFormsFeatureFlags.isProPageLayoutCloneEnabled();
        Boolean formulaFields = NativeFormsFeatureFlags.isProFormulaFieldsEnabled();
        Boolean autoLink = NativeFormsFeatureFlags.isProPostSubmitAutoLinkEnabled();
        Boolean userVerification = NativeFormsFeatureFlags.isProSfUserVerificationAuthEnabled();
        Boolean loadFile = NativeFormsFeatureFlags.isProLoadFileEnabled();
        Boolean customJs = NativeFormsFeatureFlags.isProCustomJsEnabled();
        Test.stopTest();

        System.assertEquals(true, snapshot.loadedSuccessfully);
        System.assertEquals('pro', snapshot.planCode);
        System.assertEquals(5, (Integer) snapshot.effectiveLimits.get('maxSfUsers'));
        System.assertEquals(true, conditionLogic);
        System.assertEquals(false, repeatGroups);
        System.assertEquals(true, prefillAliases);
        System.assertEquals(true, advancedSubmit);
        System.assertEquals(true, pageLayoutClone);
        System.assertEquals(true, formulaFields);
        System.assertEquals(true, autoLink);
        System.assertEquals(true, userVerification);
        System.assertEquals(true, loadFile);
        System.assertEquals(true, customJs);
        }
    }

    @IsTest
    static void tenantEntitlementsHandleHttpFailuresGracefully() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        NativeFormsTenantEntitlements.resetCache();
        Test.setMock(HttpCalloutMock.class, NativeFormsAwsMockFactory.entitlementsFailure(503, 'Service unavailable'));
        NativeFormsBootstrapV2Signer.getOrCreateSigningSecretB64();

        Test.startTest();
        NativeFormsTenantEntitlements.EntitlementSnapshot failedSnapshot = NativeFormsTenantEntitlements.getCurrentOrgEntitlements();
        Test.stopTest();

        System.assertEquals(false, failedSnapshot.loadedSuccessfully);
        System.assertEquals('Service unavailable', failedSnapshot.errorMessage);
        System.assertEquals(false, NativeFormsTenantEntitlements.isFeatureEnabled('missingFlag'));
        System.assertEquals(false, NativeFormsTenantEntitlements.isFeatureEnabled(null));
        }
    }

    @IsTest
    static void tenantEntitlementsHandleThrownCalloutExceptionsGracefully() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        NativeFormsTenantEntitlements.resetCache();
        Test.setMock(HttpCalloutMock.class, NativeFormsAwsMockFactory.throwingCallout('Synthetic callout failure.'));
        NativeFormsBootstrapV2Signer.getOrCreateSigningSecretB64();

        Test.startTest();
        NativeFormsTenantEntitlements.EntitlementSnapshot exceptionSnapshot = NativeFormsTenantEntitlements.getCurrentOrgEntitlements();
        Test.stopTest();

        System.assertEquals(false, exceptionSnapshot.loadedSuccessfully);
        System.assert(exceptionSnapshot.errorMessage.contains('Synthetic callout failure.'));
        }
    }

    @IsTest
    static void runtimeI18nAndFormulaBundleProvideExpectedFallbacks() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        System.assertEquals('he', NativeFormsRuntimeI18n.normalizeLanguageCode(' HE '));
        System.assertEquals('fr', NativeFormsRuntimeI18n.normalizeLanguageCode('fr'));
        System.assertEquals('de', NativeFormsRuntimeI18n.normalizeLanguageCode(' DE '));
        System.assertEquals('en', NativeFormsRuntimeI18n.normalizeLanguageCode('it'));
        System.assertEquals('Listo', NativeFormsRuntimeI18n.text('es', 'fileReady', 'fallback'));
        System.assertEquals('Checking file safety...', NativeFormsRuntimeI18n.text('en', 'fileSafetyScanning', 'fallback'));
        System.assert(NativeFormsRuntimeI18n.text('he', 'fileSafetyNotice', 'fallback').contains('Salesforce'));
        System.assertNotEquals('fallback', NativeFormsRuntimeI18n.text('he', 'timeInvalid', 'fallback'));
        System.assert(NativeFormsRuntimeI18n.text('he', 'timeInvalid', 'fallback').contains('{format}'));
        System.assertEquals('Ajouter une ligne', NativeFormsRuntimeI18n.text('fr', 'repeatAddRow', 'fallback'));
        System.assertEquals('Zeile hinzufügen', NativeFormsRuntimeI18n.text('de', 'repeatAddRow', 'fallback'));
        System.assertEquals('fallback', NativeFormsRuntimeI18n.text('en', 'missingKey', 'fallback'));
        System.assertEquals(true, NativeFormsRuntimeI18n.matchesAnyLanguageValue('fileReady', 'Listo'));
        System.assertEquals(true, NativeFormsRuntimeI18n.matchesAnyLanguageValue('fileReady', 'Bereit'));
        System.assertEquals(true, NativeFormsRuntimeI18n.matchesAnyLanguageValue('fileReady', 'Prêt'));
        System.assertEquals(true, NativeFormsRuntimeI18n.matchesAnyLanguageValue('fileReady', 'Ready'));
        System.assertEquals(false, NativeFormsRuntimeI18n.matchesAnyLanguageValue('fileReady', ''));
        System.assertEquals(false, NativeFormsRuntimeI18n.matchesAnyLanguageValue(null, 'Ready'));

        String browserBundle = NativeFormsFormulaExprEval.browserBundle();
        System.assert(String.isNotBlank(browserBundle));
        System.assert(browserBundle.contains('exprEval'));
        System.assert(browserBundle.contains('Parser'));
        System.assert(browserBundle.length() > 10000);
        }
    }
}
