@IsTest
private class NativeFormsCoreServicesTest {
    @IsTest
    static void formTriggerAssignsDefaultsAndTrimsDescriptions() {
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

    @IsTest
    static void formTriggerRejectsBlankDescription() {
        try {
            insert new NF_Form__c(
                Description__c = '   '
            );
            System.assert(false, 'Blank descriptions should be rejected.');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Description is required.'));
        }
    }

    @IsTest
    static void formTriggerContinuesAutoKeySequenceFromExistingRecords() {
        NF_Form__c existingForm = NativeFormsTestDataFactory.createForm('Existing form', null, 'form7');
        NF_Form__c newForm = NativeFormsTestDataFactory.createForm('New form');

        System.assertEquals('form7', existingForm.NF_Key__c);
        System.assertEquals('form8', newForm.NF_Key__c);
    }

    @IsTest
    static void projectServiceCreatesSystemProjectsBackfillsFormsAndBlocksDelete() {
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

    @IsTest
    static void projectTriggerTrimsNamesAndRejectsDuplicates() {
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

    @IsTest
    static void projectServiceResolvesExistingNewAndDefaultProjects() {
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

    @IsTest
    static void awsClientSupportsNamedCredentialCachingAndHappyPathCallouts() {
        NativeFormsAwsClient.resetNamedCredentialCache();

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
            );

        Test.setMock(HttpCalloutMock.class, mock);

        Test.startTest();
        String firstNamedCredential = NativeFormsAwsClient.namedCredentialName();
        String secondNamedCredential = NativeFormsAwsClient.namedCredentialName();
        NativeFormsAwsClient.PresignResponse presignResponse = NativeFormsAwsClient.presignHtml(requestBody);
        NativeFormsAwsClient.uploadHtml(presignResponse.putUrl, '<html>test</html>');
        Map<String, Object> registerResponse = NativeFormsAwsClient.registerForm(new Map<String, Object>{
            'orgId' => requestBody.orgId,
            'formSlug' => requestBody.formSlug
        });
        Test.stopTest();

        System.assert(String.isNotBlank(firstNamedCredential));
        System.assertEquals(firstNamedCredential, secondNamedCredential);
        System.assertEquals('https://upload.example.com/nativeforms/contact-form.html', presignResponse.putUrl);
        System.assertEquals('https://forms.twinaforms.com/contact-form', presignResponse.publicUrl);
        System.assertEquals('company/contact-form.html', presignResponse.key);
        System.assertEquals(true, registerResponse.get('success'));
        System.assertEquals('contact-form', String.valueOf(registerResponse.get('formSlug')));
    }

    @IsTest
    static void awsClientThrowsOnFailedOrIncompleteResponses() {
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
            System.assert(e.getMessage().contains('Presign API error'));
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
            System.assert(e.getMessage().contains('Presign response missing one of putUrl, publicUrl, or key.'));
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
            System.assert(e.getMessage().contains('HTML upload failed'));
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
            System.assert(e.getMessage().contains('Register API error'));
        }
    }

    @IsTest
    static void tenantEntitlementsLoadSuccessfullyAndFeatureFlagsFollowTheSnapshot() {
        NativeFormsTenantEntitlements.resetCache();
        NativeFormsAwsClient.resetNamedCredentialCache();

        Map<String, Object> featureFlags = new Map<String, Object>{
            'enableProConditionLogic' => true,
            'enableProRepeatGroups' => false,
            'enableProPrefillAliasReferences' => 'true',
            'enableProAdvancedSubmitModes' => true,
            'enableProFormulaFields' => true,
            'enableProPostSubmitAutoLink' => 'true',
            'enableProSfSecretCodeAuth' => true,
            'enableProLoadFile' => true,
            'enableProCustomJs' => true
        };
        Map<String, Object> limits = new Map<String, Object>{
            'maxSfUsers' => 5,
            'maxForms' => 1000
        };

        Test.setMock(HttpCalloutMock.class, NativeFormsAwsMockFactory.entitlementsSuccess(featureFlags, limits, 'pro'));

        Test.startTest();
        NativeFormsTenantEntitlements.EntitlementSnapshot snapshot = NativeFormsTenantEntitlements.getCurrentOrgEntitlements();
        Boolean conditionLogic = NativeFormsFeatureFlags.isProConditionLogicEnabled();
        Boolean repeatGroups = NativeFormsFeatureFlags.isProRepeatGroupsEnabled();
        Boolean prefillAliases = NativeFormsFeatureFlags.isProPrefillAliasReferencesEnabled();
        Boolean advancedSubmit = NativeFormsFeatureFlags.isProAdvancedSubmitModesEnabled();
        Boolean formulaFields = NativeFormsFeatureFlags.isProFormulaFieldsEnabled();
        Boolean autoLink = NativeFormsFeatureFlags.isProPostSubmitAutoLinkEnabled();
        Boolean secretCode = NativeFormsFeatureFlags.isProSfSecretCodeAuthEnabled();
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
        System.assertEquals(true, formulaFields);
        System.assertEquals(true, autoLink);
        System.assertEquals(true, secretCode);
        System.assertEquals(true, loadFile);
        System.assertEquals(true, customJs);
    }

    @IsTest
    static void tenantEntitlementsHandleHttpFailuresGracefully() {
        NativeFormsTenantEntitlements.resetCache();
        Test.setMock(HttpCalloutMock.class, NativeFormsAwsMockFactory.entitlementsFailure(503, 'Service unavailable'));

        Test.startTest();
        NativeFormsTenantEntitlements.EntitlementSnapshot failedSnapshot = NativeFormsTenantEntitlements.getCurrentOrgEntitlements();
        Test.stopTest();

        System.assertEquals(false, failedSnapshot.loadedSuccessfully);
        System.assertEquals('Service unavailable', failedSnapshot.errorMessage);
        System.assertEquals(false, NativeFormsTenantEntitlements.isFeatureEnabled('missingFlag'));
        System.assertEquals(false, NativeFormsTenantEntitlements.isFeatureEnabled(null));
    }

    @IsTest
    static void tenantEntitlementsHandleThrownCalloutExceptionsGracefully() {
        NativeFormsTenantEntitlements.resetCache();
        Test.setMock(HttpCalloutMock.class, NativeFormsAwsMockFactory.throwingCallout('Synthetic callout failure.'));

        Test.startTest();
        NativeFormsTenantEntitlements.EntitlementSnapshot exceptionSnapshot = NativeFormsTenantEntitlements.getCurrentOrgEntitlements();
        Test.stopTest();

        System.assertEquals(false, exceptionSnapshot.loadedSuccessfully);
        System.assert(exceptionSnapshot.errorMessage.contains('Synthetic callout failure.'));
    }

    @IsTest
    static void runtimeI18nAndFormulaBundleProvideExpectedFallbacks() {
        System.assertEquals('he', NativeFormsRuntimeI18n.normalizeLanguageCode(' HE '));
        System.assertEquals('en', NativeFormsRuntimeI18n.normalizeLanguageCode('fr'));
        System.assertEquals('Listo', NativeFormsRuntimeI18n.text('es', 'fileReady', 'fallback'));
        System.assertEquals('Add Row', NativeFormsRuntimeI18n.text('fr', 'repeatAddRow', 'fallback'));
        System.assertEquals('fallback', NativeFormsRuntimeI18n.text('en', 'missingKey', 'fallback'));
        System.assertEquals(true, NativeFormsRuntimeI18n.matchesAnyLanguageValue('fileReady', 'Listo'));
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
