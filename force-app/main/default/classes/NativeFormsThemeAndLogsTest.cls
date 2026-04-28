@IsTest
private class NativeFormsThemeAndLogsTest {
    private static final String SUBMISSION_FORM_KEY = 'formSubmissionLogs';

    @TestSetup
    static void setupLogFixtures() {
        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Submission Form', null, SUBMISSION_FORM_KEY);
        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createVersion(
            formRecord.Id,
            1,
            'Published',
            'Published',
            NativeFormsTestConfigFactory.basicUiSettingsJson()
        );
        NativeFormsTestDataFactory.createElement(
            versionRecord.Id,
            'text',
            'Email Address',
            'email1',
            1,
            10,
            NativeFormsTestConfigFactory.textFieldConfigJson(),
            null
        );
        NativeFormsTestDataFactory.createElement(
            versionRecord.Id,
            'repeatGroup',
            'Case List',
            'records1',
            2,
            20,
            NativeFormsTestConfigFactory.repeatGroupConfigJson(),
            null
        );

        insert new NF_Submission_Log_Key__c(
            Name = UserInfo.getOrganizationId().substring(0, 15),
            Public_Key__c = base64Value('setup-public-key'),
            Private_Key__c = base64Value('setup-private-key'),
            Key_Version__c = 'v2'
        );

        Blob key = Crypto.generateAesKey(256);
        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        if (config == null) {
            config = new NativeForms_Config__c(SetupOwnerId = UserInfo.getOrganizationId());
            insert config;
        }
        config.Submission_Log_Key__c = EncodingUtil.base64Encode(key);
        upsert config;
    }

    private static String base64Value(String value) {
        return EncodingUtil.base64Encode(Blob.valueOf(value));
    }

    private static NF_Form__c getSubmissionForm() {
        return [
            SELECT Id, Description__c, NF_Key__c
            FROM NF_Form__c
            WHERE NF_Key__c = :SUBMISSION_FORM_KEY
            LIMIT 1
        ];
    }

    private static NF_Form_Version__c getSubmissionVersion(Id formId) {
        return [
            SELECT Id, Form__c
            FROM NF_Form_Version__c
            WHERE Form__c = :formId
            LIMIT 1
        ];
    }

    private static void assertAuraHandled(AuraHandledException e, String expectedFragment) {
        System.assertNotEquals(null, e);
        System.assert(String.isNotBlank(e.getMessage()));
        if (String.isNotBlank(expectedFragment)) {
            System.assert(e.getMessage().contains(expectedFragment));
        }
    }

    private static Map<String, Object> statusPayload(Boolean successValue) {
        return new Map<String, Object>{
            'success' => successValue == true,
            'planCode' => 'starter',
            'retentionDays' => 30,
            'detailedLogsIncludedByPlan' => false,
            'effectiveDetailMode' => 'summary_only',
            'encryptionStatus' => 'active',
            'keyVersion' => 'v2',
            'publicKeySyncedAt' => '2026-04-22T10:30:00Z'
        };
    }

    private static Map<String, Object> syncPayload(Boolean successValue) {
        return new Map<String, Object>{
            'success' => successValue == true,
            'orgId' => UserInfo.getOrganizationId().substring(0, 15),
            'planCode' => 'pro',
            'retentionDays' => 90,
            'detailedLogsIncludedByPlan' => true,
            'effectiveDetailMode' => 'encrypted_detail',
            'encryptionStatus' => 'active',
            'keyVersion' => 'v2',
            'publicKeyConfigured' => true,
            'publicKeySyncedAt' => '2026-04-22T10:45:00Z'
        };
    }

    @IsTest
    static void themesWorkspaceCrudAndEnsureSamplesWork() {
        NativeFormsThemesController.ThemeWorkspace emptyWorkspace =
            NativeFormsThemesController.getWorkspace(null);
        System.assertEquals(0, emptyWorkspace.themes.size());
        System.assertEquals(null, emptyWorkspace.selectedThemeId);
        System.assertEquals(null, emptyWorkspace.selectedTheme);

        NativeFormsThemesController.ThemeRecord createdTheme =
            NativeFormsThemesController.createTheme();
        System.assertNotEquals(null, createdTheme.id);
        System.assertEquals('New Theme', createdTheme.name);
        System.assertEquals('wide', createdTheme.formWidth);

        NativeFormsThemesController.ThemeWorkspace populatedWorkspace =
            NativeFormsThemesController.getWorkspace(null);
        System.assertEquals(createdTheme.id, populatedWorkspace.selectedThemeId);
        System.assert(populatedWorkspace.themes.size() >= 1);

        NativeFormsThemesController.ThemeRecord cloneTheme =
            NativeFormsThemesController.cloneTheme(createdTheme.id);
        System.assert(cloneTheme.name.contains('Copy'));

        NativeFormsThemesController.ThemeRecord updateInput =
            new NativeFormsThemesController.ThemeRecord();
        updateInput.id = createdTheme.id;
        updateInput.name = '  Customer Theme  ';
        updateInput.description = 'Updated test theme';
        updateInput.logoUrl = 'https://example.com/logo.png';
        updateInput.logoContentDocumentId = '069000000000001';
        updateInput.logoSizePx = 140;
        updateInput.logoPosition = 'center';
        updateInput.formWidth = 'narrow';
        updateInput.backgroundColor = '#FFFFFF';
        updateInput.formBackgroundColor = '#FAFAFA';
        updateInput.formBorderColor = '#CCCCCC';
        updateInput.titleFont = 'Georgia';
        updateInput.titleFontSizePx = 20;
        updateInput.titleTextColor = '#111111';
        updateInput.sectionTitleFont = 'Georgia';
        updateInput.sectionTitleFontSizePx = 14;
        updateInput.sectionTitleTextColor = '#222222';
        updateInput.mainFont = 'Inter';
        updateInput.mainTextSizePx = 13;
        updateInput.mainTextColor = '#333333';
        updateInput.linkTextColor = '#444444';
        updateInput.hintTextColor = '#555555';
        updateInput.errorColor = '#666666';
        updateInput.inputBorderRadiusPx = 12;
        updateInput.inputBackgroundColor = '#F0F0F0';
        updateInput.inputBorderColor = '#DDDDDD';
        updateInput.buttonFont = 'Inter';
        updateInput.buttonFontSizePx = 14;
        updateInput.buttonTextColor = '#FFFFFF';
        updateInput.buttonBackgroundColor = '#123456';
        updateInput.buttonHoverBackgroundColor = '#234567';

        NativeFormsThemesController.ThemeRecord savedTheme =
            NativeFormsThemesController.saveTheme(JSON.serialize(updateInput));
        System.assertEquals('Customer Theme', savedTheme.name);
        System.assertEquals('https://example.com/logo.png', savedTheme.logoUrl);
        System.assertEquals('narrow', savedTheme.formWidth);

        NativeFormsThemesController.ensureSampleThemes();
        Set<String> expectedNames = new Set<String>{ 'Ocean Blue', 'ColorFull', 'Official' };
        Set<String> actualNames = new Set<String>();
        for (NF_Theme__c themeRow : [
            SELECT Name
            FROM NF_Theme__c
            WHERE Name IN :expectedNames
        ]) {
            actualNames.add(themeRow.Name);
        }
        System.assertEquals(expectedNames, actualNames);

        NativeFormsThemesController.deleteTheme(cloneTheme.id);
        System.assertEquals(0, [SELECT COUNT() FROM NF_Theme__c WHERE Id = :cloneTheme.id]);
    }

    @IsTest
    static void themesUploadAndValidationGuardsWork() {
        NF_Theme__c themeRecord = NativeFormsTestDataFactory.createTheme('Logo Theme');

        try {
            NativeFormsThemesController.cloneTheme(null);
            System.assert(false, 'Cloning without a theme id should fail.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e, null);
        }

        try {
            NativeFormsThemesController.saveTheme(null);
            System.assert(false, 'Saving without input should fail.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e, null);
        }

        try {
            NativeFormsThemesController.uploadLogo(null, 'logo.png', base64Value('pngdata'));
            System.assert(false, 'Uploading without a theme id should fail.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e, null);
        }

        try {
            NativeFormsThemesController.uploadLogo(themeRecord.Id, null, null);
            System.assert(false, 'Uploading without a file should fail.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e, null);
        }

        NativeFormsThemesController.UploadedLogoResult uploadResult =
            NativeFormsThemesController.uploadLogo(
                themeRecord.Id,
                'company-logo.png',
                base64Value('pngdata')
            );

        System.assertNotEquals(null, uploadResult.contentDocumentId);
        System.assertNotEquals(null, uploadResult.contentVersionId);
        System.assert(uploadResult.previewUrl.contains('/sfc/servlet.shepherd/version/download/'));
        System.assertEquals(uploadResult.previewUrl, uploadResult.theme.logoUrl);

        NF_Theme__c persistedTheme = [
            SELECT Logo_URL__c, Logo_Content_Document_Id__c
            FROM NF_Theme__c
            WHERE Id = :themeRecord.Id
        ];
        System.assertEquals(uploadResult.previewUrl, persistedTheme.Logo_URL__c);
        System.assertEquals(String.valueOf(uploadResult.contentDocumentId), persistedTheme.Logo_Content_Document_Id__c);
    }

    @IsTest
    static void submissionLogStatusAndSaveKeyPairWork() {
        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock()
                .addJsonResponse('/submission-log-config/status', 200, statusPayload(true))
        );

        Test.startTest();
        NativeFormsSubmissionLogsController.SubmissionLogStatus initialStatus =
            NativeFormsSubmissionLogsController.getSubmissionLogStatus();
        Test.stopTest();
        System.assertEquals(true, initialStatus.success);
        System.assertEquals(true, initialStatus.hasPublicKey);
        System.assertEquals(true, initialStatus.hasPrivateKey);
        System.assertEquals('starter', initialStatus.planCode);

        try {
            NativeFormsSubmissionLogsController.saveSubmissionLogKeyPair('%%%bad', 'also bad', 'v2');
            System.assert(false, 'Invalid base64 should be rejected.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e, null);
        }

        NativeFormsSubmissionLogsController.SubmissionLogStatus savedStatus =
            NativeFormsSubmissionLogsController.saveSubmissionLogKeyPair(
                base64Value('public-key'),
                base64Value('private-key'),
                'v2'
            );
        System.assertEquals(true, savedStatus.success);
        System.assertEquals(true, savedStatus.hasPublicKey);
        System.assertEquals(true, savedStatus.hasPrivateKey);
        System.assertEquals('v2', savedStatus.keyVersion);

        NF_Submission_Log_Key__c savedKeyRecord = [
            SELECT Public_Key__c, Private_Key__c, Key_Version__c
            FROM NF_Submission_Log_Key__c
            WHERE Name = :UserInfo.getOrganizationId().substring(0, 15)
            LIMIT 1
        ];
        System.assertEquals(base64Value('public-key'), savedKeyRecord.Public_Key__c);
        System.assertEquals(base64Value('private-key'), savedKeyRecord.Private_Key__c);
        System.assertEquals('v2', savedKeyRecord.Key_Version__c);
    }

    @IsTest
    static void submissionLogSyncAndStatusFailureFlowsWork() {
        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock()
                .addJsonResponse('/submission-log-config/status', 200, statusPayload(true))
                .addJsonResponse('/submission-log-config/sync', 200, syncPayload(true))
        );

        Test.startTest();
        NativeFormsSubmissionLogsController.SyncResult syncResult =
            NativeFormsSubmissionLogsController.syncSubmissionLogConfig();
        Test.stopTest();
        System.assertEquals(true, syncResult.success);
        System.assertEquals(UserInfo.getOrganizationId().substring(0, 15), syncResult.orgId);
        System.assertEquals('encrypted_detail', syncResult.effectiveDetailMode);
        System.assertEquals(true, syncResult.publicKeyConfigured);
    }

    @IsTest
    static void submissionLogStatusFailureFlowsWork() {
        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock()
                .addJsonResponse(
                    '/submission-log-config/status',
                    500,
                    new Map<String, Object>{ 'success' => false, 'error' => 'Status unavailable' }
                )
                .addJsonResponse(
                    '/submission-log-config/sync',
                    500,
                    new Map<String, Object>{ 'success' => false, 'error' => 'Sync unavailable' }
                )
        );

        Test.startTest();
        NativeFormsSubmissionLogsController.SubmissionLogStatus failedStatus =
            NativeFormsSubmissionLogsController.getSubmissionLogStatus();
        NativeFormsSubmissionLogsController.SyncResult failedSync =
            NativeFormsSubmissionLogsController.syncSubmissionLogConfig();
        Test.stopTest();
        System.assertEquals(false, failedStatus.success);
        System.assertEquals('Status unavailable', failedStatus.errorMessage);
        System.assertEquals(false, failedSync.success);
        System.assertEquals('Sync unavailable', failedSync.errorMessage);
    }

    @IsTest
    static void submissionLogListAndDetailHydrationWork() {
        NF_Form__c formRecord = getSubmissionForm();
        NF_Form_Version__c versionRecord = getSubmissionVersion(formRecord.Id);

        String submissionId = 'sub-001';
        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock()
                .addJsonResponse(
                    '/submission-logs?',
                    200,
                    new Map<String, Object>{
                        'success' => true,
                        'nextToken' => 'page-2',
                        'logs' => new List<Object>{
                            new Map<String, Object>{
                                'tenantId' => 'tenant-1',
                                'submissionId' => submissionId,
                                'submissionRef' => 'SUB-001',
                                'formId' => String.valueOf(formRecord.Id),
                                'formVersionId' => String.valueOf(versionRecord.Id),
                                'submittedAt' => '2026-04-22T12:00:00Z',
                                'outcome' => 'success',
                                'detailMode' => 'summary_only',
                                'recordId' => '003000000000001'
                            }
                        }
                    }
                )
                .addJsonResponse(
                    '/submission-logs/' + submissionId,
                    200,
                    new Map<String, Object>{
                        'success' => true,
                        'log' => new Map<String, Object>{
                            'tenantId' => 'tenant-1',
                            'submissionId' => submissionId,
                            'submissionRef' => 'SUB-001',
                            'formId' => String.valueOf(formRecord.Id),
                            'formVersionId' => String.valueOf(versionRecord.Id),
                            'submittedAt' => '2026-04-22T12:00:00Z',
                            'outcome' => 'failed',
                            'failureStage' => 'submit',
                            'detailMode' => 'encrypted_detail',
                            'recordId' => '003000000000001',
                            'encryptedDetail' => new Map<String, Object>{
                                'detailEncryptedKeyB64' => base64Value('encrypted-key'),
                                'detailCiphertextB64' => base64Value('ciphertext'),
                                'detailIvB64' => base64Value('1234567890123456')
                            }
                        }
                    }
                )
        );

        Test.startTest();
        NativeFormsSubmissionLogsController.LogListResult listResult =
            NativeFormsSubmissionLogsController.listLogs(
                String.valueOf(formRecord.Id),
                'success',
                'SUB-001',
                '2026-04-20',
                '2026-04-22',
                25,
                null
            );
        System.assertEquals(true, listResult.success);
        System.assertEquals('page-2', listResult.nextToken);
        System.assertEquals(1, listResult.logs.size());
        System.assertEquals('Submission Form', listResult.logs[0].formDescription);

        NativeFormsSubmissionLogsController.LogDetailResult detailResult =
            NativeFormsSubmissionLogsController.getLogDetail(submissionId);
        Test.stopTest();
        System.assertEquals(true, detailResult.success);
        System.assertEquals('Submission Form', detailResult.log.formDescription);
        System.assertEquals(1, detailResult.fieldLabels.size());
        System.assertEquals(1, detailResult.repeatGroupLabels.size());
        System.assertEquals('Case List', detailResult.repeatGroupLabels[0].label);
        System.assertNotEquals(null, detailResult.clientEncryptedDetailJson);
        System.assertEquals(base64Value('setup-private-key'), detailResult.privateKeyPkcs8B64);
        System.assertEquals(null, detailResult.detailAccessMessage);
    }

    @IsTest
    static void submissionLogListAndDetailFailuresReturnMessages() {
        String submissionId = 'sub-001';

        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.RoutingMock()
                .addJsonResponse(
                    '/submission-logs?',
                    500,
                    new Map<String, Object>{ 'success' => false, 'error' => 'List unavailable' }
                )
                .addJsonResponse(
                    '/submission-logs/' + submissionId,
                    500,
                    new Map<String, Object>{ 'success' => false, 'error' => 'Detail unavailable' }
                )
        );

        Test.startTest();
        NativeFormsSubmissionLogsController.LogListResult failedList =
            NativeFormsSubmissionLogsController.listLogs(null, null, null, null, null, null, null);
        NativeFormsSubmissionLogsController.LogDetailResult failedDetail =
            NativeFormsSubmissionLogsController.getLogDetail(submissionId);
        Test.stopTest();
        System.assertEquals(false, failedList.success);
        System.assertEquals('List unavailable', failedList.errorMessage);
        System.assertEquals(false, failedDetail.success);
        System.assertEquals('Detail unavailable', failedDetail.errorMessage);
    }

    @IsTest
    static void submissionLogDecryptAndMissingKeyGuardsWork() {
        NativeFormsSubmissionLogsController.LogDetailResult missingIdResult =
            NativeFormsSubmissionLogsController.getLogDetail(null);
        System.assertEquals(false, missingIdResult.success);
        System.assert(String.isNotBlank(missingIdResult.errorMessage));

        try {
            NativeFormsSubmissionLogsController.decryptEncryptedDetail(null, null);
            System.assert(false, 'Missing key config should be blocked.');
        } catch (AuraHandledException e) {
            assertAuraHandled(e, null);
        }

        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        Blob key = EncodingUtil.base64Decode(config.Submission_Log_Key__c);
        Blob iv = Blob.valueOf('1234567890123456');
        Blob plaintext = Blob.valueOf('{"ok":true}');
        Blob ciphertext = Crypto.encrypt('AES256', key, iv, plaintext);

        String decrypted =
            NativeFormsSubmissionLogsController.decryptEncryptedDetail(
                EncodingUtil.base64Encode(ciphertext),
                EncodingUtil.base64Encode(iv)
            );
        System.assertEquals('{"ok":true}', decrypted);
    }

    @IsTest
    static void submissionLogThrowingMocksReturnFailureMessages() {
        Test.setMock(
            HttpCalloutMock.class,
            new NativeFormsAwsMockFactory.ThrowingMock('Submission logs down')
        );
        Test.startTest();
        NativeFormsSubmissionLogsController.LogListResult throwingList =
            NativeFormsSubmissionLogsController.listLogs(null, null, null, null, null, null, null);
        NativeFormsSubmissionLogsController.SubmissionLogStatus throwingStatus =
            NativeFormsSubmissionLogsController.getSubmissionLogStatus();
        Test.stopTest();
        System.assertEquals(false, throwingList.success);
        System.assert(String.isNotBlank(throwingList.errorMessage));
        System.assertEquals(false, throwingStatus.success);
        System.assert(String.isNotBlank(throwingStatus.errorMessage));
    }
}
