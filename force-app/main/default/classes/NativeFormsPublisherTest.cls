@IsTest
private class NativeFormsPublisherTest {
    private class PublisherCalloutMock implements HttpCalloutMock {
        Boolean failPresign;
        Boolean failRegister;
        Integer presignCalls = 0;
        Integer uploadCalls = 0;
        Integer registerCalls = 0;
        String uploadedHtml;
        String registerBody;

        public HttpResponse respond(HttpRequest request) {
            String endpoint = request == null ? '' : request.getEndpoint();
            HttpResponse response = new HttpResponse();

            if (endpoint.contains('/forms/publish/presign')) {
                presignCalls += 1;
                response.setHeader('Content-Type', 'application/json');
                if (failPresign == true) {
                    response.setStatusCode(500);
                    response.setStatus('ERROR');
                    response.setBody('{"success":false,"error":"Presign exploded."}');
                    return response;
                }
                response.setStatusCode(200);
                response.setStatus('OK');
                response.setBody(JSON.serialize(new Map<String, Object>{
                    'success' => true,
                    'putUrl' => 'https://upload.example.com/forms/current/index.html',
                    'publicUrl' => 'https://forms.twinaforms.com/acme/forms/rich-published-form',
                    'key' => 'acme/forms/current/index.html',
                    'companySlug' => 'acme',
                    'formSlug' => 'rich-published-form',
                    'expiresAt' => Datetime.now().addMinutes(15).getTime()
                }));
                return response;
            }

            if (endpoint == 'https://upload.example.com/forms/current/index.html') {
                uploadCalls += 1;
                uploadedHtml = request.getBody();
                response.setStatusCode(200);
                response.setStatus('OK');
                response.setBody('{}');
                return response;
            }

            if (endpoint.contains('/forms/register')) {
                registerCalls += 1;
                registerBody = request.getBody();
                response.setHeader('Content-Type', 'application/json');
                if (failRegister == true) {
                    response.setStatusCode(500);
                    response.setStatus('ERROR');
                    response.setBody('{"success":false,"error":"Register exploded."}');
                    return response;
                }
                response.setStatusCode(200);
                response.setStatus('OK');
                response.setBody(JSON.serialize(new Map<String, Object>{
                    'success' => true,
                    'status' => 'published'
                }));
                return response;
            }

            response.setStatusCode(500);
            response.setStatus('NO MOCK');
            response.setBody('{"success":false,"error":"Unexpected endpoint: ' + String.escapeSingleQuotes(endpoint) + '"}');
            return response;
        }
    }

    private static NativeFormsTenantEntitlements.EntitlementSnapshot buildProEntitlementsSnapshot() {
        NativeFormsTenantEntitlements.EntitlementSnapshot snapshot = new NativeFormsTenantEntitlements.EntitlementSnapshot();
        snapshot.loadedSuccessfully = true;
        snapshot.orgId = UserInfo.getOrganizationId().substring(0, 15);
        snapshot.planCode = 'pro';
        snapshot.errorMessage = null;
        snapshot.effectiveFeatureFlags = new Map<String, Object>{
            'enableProConditionLogic' => true,
            'enableProRepeatGroups' => true,
            'enableProPrefillAliasReferences' => true,
            'enableProAdvancedSubmitModes' => true,
            'enableProFormulaFields' => true,
            'enableProPostSubmitAutoLink' => true,
            'enableProSfSecretCodeAuth' => true,
            'enableProLoadFile' => true,
            'enableProCustomJs' => true
        };
        snapshot.effectiveLimits = new Map<String, Object>{
            'maxForms' => 1000,
            'maxSfUsers' => 5
        };
        return snapshot;
    }

    private static void setAllProFlagsEnabled() {
        NativeFormsTenantEntitlements.setCachedSnapshot(buildProEntitlementsSnapshot());
    }

    @IsTest
    static void publisherValidationGuardsWork() {
        setAllProFlagsEnabled();
        NF_Form_Version__c readonlyVersion = createBaseVersion(
            'Readonly Published Form',
            'readonly-published-form',
            'Published',
            'Published',
            false,
            NativeFormsTestConfigFactory.basicUiSettingsJson()
        );

        NativeFormsPublisher.PublishResult readonlyResult = NativeFormsPublisher.publishVersion(readonlyVersion.Id);
        System.assertEquals(false, readonlyResult.success, 'Published versions should be blocked from republishing directly.');
        System.assertEquals(
            'Published versions are read-only. Open the latest draft version to continue editing.',
            readonlyResult.message,
            'Readonly guard message should stay customer-safe.'
        );

        NF_Form_Version__c invalidSlugVersion = createBaseVersion(
            'Invalid Slug Form',
            'Bad Key',
            'Draft',
            'Never Published',
            false,
            NativeFormsTestConfigFactory.basicUiSettingsJson()
        );

        NativeFormsPublisher.PublishResult invalidSlugResult = NativeFormsPublisher.publishVersion(invalidSlugVersion.Id);
        System.assertEquals(false, invalidSlugResult.success, 'Invalid friendly slugs should fail before callout.');
        System.assert(invalidSlugResult.message.contains('Friendly published URLs require NF Key before publish'), 'Friendly slug failure should explain the NF Key requirement.');

        invalidSlugVersion = [
            SELECT Publish_Status__c, Last_Publish_Error__c
            FROM NF_Form_Version__c
            WHERE Id = :invalidSlugVersion.Id
        ];
        System.assertEquals('Publish Failed', invalidSlugVersion.Publish_Status__c, 'Invalid slug should mark publish as failed.');
        System.assert(invalidSlugVersion.Last_Publish_Error__c.contains('Friendly published URLs require NF Key before publish'), 'Invalid slug should persist the friendly failure message.');

        System.assertEquals(true, NativeFormsPublisher.hasSharedCaptchaSiteKey(), 'Shared CAPTCHA key helper should report the packaged key as present.');
        System.assert(String.isNotBlank(NativeFormsPublisher.getSharedCaptchaSiteKey()), 'Shared CAPTCHA key helper should return the packaged key value.');
        System.assertEquals('my-friendly-form', NativeFormsPublisher.normalizePublishedFormSlug('my-friendly-form'), 'Slug helper should preserve already valid slugs.');
        System.assertEquals(null, NativeFormsPublisher.normalizePublishedFormSlug('Bad_Key'), 'Slug helper should reject underscores.');
        System.assert(
            NativeFormsPublisher.buildInternalFormId(UserInfo.getOrganizationId().substring(0, 15), readonlyVersion.Form__c).startsWith('nf-'),
            'Internal form ids should use the native publish prefix.'
        );
    }

    @IsTest
    static void publishSuccessCreatesPublicationRegisterPayloadAndSuccessorDraft() {
        setAllProFlagsEnabled();
        PublisherCalloutMock mock = new PublisherCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        NF_Form_Version__c richVersion = createRichPublishVersion('rich-published-form');

        Test.startTest();
        NativeFormsPublisher.PublishResult result = NativeFormsPublisher.publishVersion(richVersion.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Publish should succeed for the rich draft version.');
        System.assertEquals('Published successfully. A new draft version was created.', result.message, 'Successful publish should mention the successor draft.');
        System.assertEquals('https://forms.twinaforms.com/acme/forms/current/index.html', result.publicUrl, 'Public URL should normalize to the packaged forms domain plus key.');
        System.assertEquals('acme/forms/current/index.html', result.key, 'Result key should come from the presign response.');
        System.assertNotEquals(null, result.publicationId, 'Successful publish should create a publication record.');
        System.assertNotEquals(null, result.newDraftVersionId, 'Successful publish should create a successor draft.');
        System.assert(String.isNotBlank(result.newDraftVersionName), 'Successor draft should expose its generated version name.');

        System.assertEquals(1, mock.presignCalls, 'Publish should presign exactly once.');
        System.assertEquals(1, mock.uploadCalls, 'Publish should upload the generated HTML exactly once.');
        System.assertEquals(1, mock.registerCalls, 'Publish should register the published form exactly once.');
        System.assert(String.isNotBlank(mock.uploadedHtml), 'Successful publish should upload generated HTML.');
        System.assert(mock.uploadedHtml.contains('nf-secret-verify'), 'Generated HTML should include the secret-code verification section when enabled.');
        System.assert(mock.uploadedHtml.contains('data-formula-target="true"'), 'Generated HTML should include formula metadata for formula fields.');
        System.assert(mock.uploadedHtml.contains('data-nativeforms-time="true"'), 'Generated HTML should render Time fields as TwinaForms-controlled text inputs.');
        System.assert(mock.uploadedHtml.contains('data-time-format="24h"'), 'Generated HTML should include the configured Time display format.');
        System.assert(mock.uploadedHtml.contains('value="09:30"'), 'Generated HTML should keep plain HH:mm default values for Time fields.');
        System.assert(mock.uploadedHtml.contains('https://example.com/theme-logo.png'), 'Generated HTML should include the theme logo URL.');
        System.assert(mock.uploadedHtml.contains('https://twinaforms.com/help/formulas'), 'Generated HTML should preserve rich text links.');
        System.assert(mock.uploadedHtml.contains('data:image/png;base64,'), 'Generated HTML should inline image assets when contentVersionId is present.');
        System.assert(mock.uploadedHtml.contains('window.TwinaForms=twinaFormsApi'), 'Generated HTML should expose the TwinaForms runtime API.');
        System.assert(mock.uploadedHtml.contains('window.NativeForms=window.TwinaForms'), 'Generated HTML should keep the NativeForms compatibility alias.');
        System.assert(mock.uploadedHtml.contains('new Function("TwinaForms",customJsSource)'), 'Generated HTML should run custom JavaScript through the guarded runner.');
        System.assert(mock.uploadedHtml.contains('runGuardedCustomJs();'), 'Generated HTML should execute custom JavaScript through the guarded helper.');
        System.assertEquals(false, mock.uploadedHtml.contains('</script><script>TwinaForms.on('), 'Custom JavaScript should no longer be appended as a raw trailing script tag.');

        Map<String, Object> registerPayload = (Map<String, Object>) JSON.deserializeUntyped(mock.registerBody);
        System.assertEquals('published', String.valueOf(registerPayload.get('status')), 'Register payload should mark the form as published.');
        System.assertEquals('secure-edit', String.valueOf(registerPayload.get('securityMode')), 'Register payload should preserve the configured security mode.');
        System.assertEquals('standard', String.valueOf(registerPayload.get('rateLimitProfile')), 'Register payload should default the rate-limit profile.');
        System.assertEquals('acme/forms/current/index.html', String.valueOf(registerPayload.get('generatedHtmlRef')), 'Register payload should carry the generated HTML key.');
        System.assertEquals('rich-published-form', String.valueOf(registerPayload.get('formSlug')), 'Register payload should use the normalized friendly slug.');

        Map<String, Object> captcha = (Map<String, Object>) registerPayload.get('captcha');
        System.assertEquals(true, captcha.get('enabled'), 'Register payload should enable CAPTCHA when the form requires it.');
        System.assert(String.isNotBlank(String.valueOf(captcha.get('siteKey'))), 'Register payload should include the shared CAPTCHA site key.');

        Map<String, Object> secretCodeConfig = (Map<String, Object>) registerPayload.get('secretCodeConfig');
        System.assertEquals(true, secretCodeConfig.get('enabled'), 'Register payload should include secret-code settings when enabled.');
        System.assertEquals('Email', String.valueOf(secretCodeConfig.get('matchField')), 'Register payload should preserve the configured secret-code match field.');

        List<Object> uploadFields = (List<Object>) registerPayload.get('uploadFields');
        System.assertEquals(1, uploadFields.size(), 'Register payload should expose upload field metadata for file-upload controls.');

        Map<String, Object> prefillDefinition = (Map<String, Object>) registerPayload.get('prefillDefinition');
        System.assertEquals(1, ((List<Object>) prefillDefinition.get('commands')).size(), 'Prefill definition should include the configured prefill command.');

        Map<String, Object> submitDefinition = (Map<String, Object>) registerPayload.get('submitDefinition');
        System.assertEquals(4, ((List<Object>) submitDefinition.get('commands')).size(), 'Submit definition should expand find-and-update and records-list commands.');

        NF_Form_Version__c publishedVersion = [
            SELECT Version_Status__c, Publish_Status__c, Publish_Token__c, Form_Id__c, Last_Published_At__c, Last_Publish_Error__c
            FROM NF_Form_Version__c
            WHERE Id = :richVersion.Id
        ];
        System.assertEquals('Published', publishedVersion.Version_Status__c, 'Successful publish should mark the source version as published.');
        System.assertEquals('Published', publishedVersion.Publish_Status__c, 'Successful publish should mark publish status as Published.');
        System.assert(String.isNotBlank(publishedVersion.Publish_Token__c), 'Successful publish should persist a publish token.');
        System.assert(String.isNotBlank(publishedVersion.Form_Id__c), 'Successful publish should persist the internal form id.');
        System.assertNotEquals(null, publishedVersion.Last_Published_At__c, 'Successful publish should stamp the publish timestamp.');
        System.assertEquals(null, publishedVersion.Last_Publish_Error__c, 'Successful publish should clear any previous publish error.');

        NF_Form__c publishedForm = [
            SELECT Status__c, Current_Published_Version__c
            FROM NF_Form__c
            WHERE Id = :richVersion.Form__c
        ];
        System.assertEquals('Active', publishedForm.Status__c, 'Successful publish should activate the form.');
        System.assertEquals(richVersion.Id, publishedForm.Current_Published_Version__c, 'Successful publish should point the form at the published version.');

        NF_Form_Publication__c publication = [
            SELECT Publication_Status__c, Publication_Type__c, Generated_HTML_Ref__c, Error_Message__c
            FROM NF_Form_Publication__c
            WHERE Id = :result.publicationId
        ];
        System.assertEquals('Success', publication.Publication_Status__c, 'Successful publish should create a success publication row.');
        System.assertEquals('Publish', publication.Publication_Type__c, 'First publish should record Publication Type as Publish.');
        System.assertEquals('https://forms.twinaforms.com/acme/forms/current/index.html', publication.Generated_HTML_Ref__c, 'Publication row should keep the normalized public URL.');
        System.assertEquals(null, publication.Error_Message__c, 'Success publication should not keep an error message.');

        NF_Form_Version__c successorDraft = [
            SELECT Id, Version_Number__c, Version_Status__c, Publish_Status__c, Publish_Token__c, Form_Id__c, Custom_JS__c
            FROM NF_Form_Version__c
            WHERE Id = :result.newDraftVersionId
        ];
        System.assertEquals(2, Integer.valueOf(successorDraft.Version_Number__c), 'Successor draft should increment the version number.');
        System.assertEquals('Draft', successorDraft.Version_Status__c, 'Successor should be a draft version.');
        System.assertEquals('Never Published', successorDraft.Publish_Status__c, 'Successor draft should start unpublished.');
        System.assertEquals(null, successorDraft.Publish_Token__c, 'Successor draft should not reuse the publish token.');
        System.assertEquals(publishedVersion.Form_Id__c, successorDraft.Form_Id__c, 'Successor draft should keep the generated internal form id.');
        System.assertEquals('TwinaForms.on("change", function () { TwinaForms.setValue("textCode", "+972"); });', successorDraft.Custom_JS__c, 'Successor draft should carry Custom JavaScript forward.');

        Integer successorElementCount = [
            SELECT Count()
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :successorDraft.Id
        ];
        Integer successorActionCount = [
            SELECT Count()
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :successorDraft.Id
        ];
        System.assertEquals(19, successorElementCount, 'Successor draft should clone all publishable elements.');
        System.assertEquals(3, successorActionCount, 'Successor draft should clone all configured actions.');
    }

    @IsTest
    static void publishFailureCreatesFailurePublicationAndFriendlyMessage() {
        setAllProFlagsEnabled();
        PublisherCalloutMock mock = new PublisherCalloutMock();
        mock.failRegister = true;
        Test.setMock(HttpCalloutMock.class, mock);

        NF_Form_Version__c version = createBaseVersion(
            'Failure Publish Form',
            'failure-publish-form',
            'Draft',
            'Never Published',
            false,
            NativeFormsTestConfigFactory.basicUiSettingsJson()
        );
        NativeFormsTestDataFactory.createElement(
            version.Id,
            'text',
            'Email',
            'email1',
            1,
            10,
            NativeFormsTestConfigFactory.textFieldConfigJson(),
            null
        );

        Test.startTest();
        NativeFormsPublisher.PublishResult result = NativeFormsPublisher.publishVersion(version.Id);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Register failure should return a failed publish result.');
        System.assertEquals('TwinaForms could not publish this form right now. Review the form setup and try again.', result.message, 'Register failure should return the friendly publish error.');
        System.assertNotEquals(null, result.publicationId, 'Register failure should still create a failure publication row.');
        System.assertEquals(null, result.newDraftVersionId, 'Failed publish should not create a successor draft.');
        System.assertEquals(1, mock.presignCalls, 'Failure path should still presign once.');
        System.assertEquals(1, mock.uploadCalls, 'Failure path should still upload the HTML before register fails.');
        System.assertEquals(1, mock.registerCalls, 'Failure path should fail on register.');

        version = [
            SELECT Publish_Status__c, Last_Publish_Error__c, Version_Status__c
            FROM NF_Form_Version__c
            WHERE Id = :version.Id
        ];
        System.assertEquals('Publish Failed', version.Publish_Status__c, 'Failed publish should mark publish status as failed.');
        System.assertEquals('Draft', version.Version_Status__c, 'Failed publish should keep the version editable.');
        System.assertEquals('TwinaForms could not publish this form right now. Review the form setup and try again.', version.Last_Publish_Error__c, 'Failed publish should persist the friendly publish error.');

        NF_Form_Publication__c publication = [
            SELECT Publication_Status__c, Publication_Type__c, Error_Message__c
            FROM NF_Form_Publication__c
            WHERE Id = :result.publicationId
        ];
        System.assertEquals('Failed', publication.Publication_Status__c, 'Failure path should create a failed publication row.');
        System.assertEquals('Publish', publication.Publication_Type__c, 'Failure row should still record publication type.');
        System.assert(String.isNotBlank(publication.Error_Message__c), 'Failure row should keep the detailed error message.');
    }

    private static NF_Form_Version__c createBaseVersion(
        String descriptionValue,
        String formKey,
        String versionStatus,
        String publishStatus,
        Boolean enableCaptcha,
        String uiSettingsJson
    ) {
        NF_Theme__c themeRecord = NativeFormsTestDataFactory.createTheme('Publisher Theme ' + formKey);
        update new NF_Theme__c(
            Id = themeRecord.Id,
            Logo_URL__c = 'https://example.com/theme-logo.png'
        );

        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm(descriptionValue, null, formKey);
        update new NF_Form__c(
            Id = formRecord.Id,
            Theme__c = themeRecord.Id,
            Enable_Captcha__c = enableCaptcha == true
        );

        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createVersion(
            formRecord.Id,
            1,
            versionStatus,
            publishStatus,
            uiSettingsJson
        );
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, versionRecord.Id, null);
        return [
            SELECT Id, Form__c, Version_Number__c, Version_Status__c, Publish_Status__c, Custom_JS__c
            FROM NF_Form_Version__c
            WHERE Id = :versionRecord.Id
        ];
    }

    private static NF_Form_Version__c createRichPublishVersion(String formKey) {
        Map<String, Object> uiSettings = new Map<String, Object>{
            'languageCode' => 'en',
            'submitLabel' => 'Send',
            'submitSuccessMessage' => 'Published successfully.',
            'secretCodeVerificationEnabled' => true,
            'secretCodeMatchField' => 'Email',
            'secretCodeIntroText' => 'Enter your email to continue.',
            'secretCodeSentMessage' => 'We sent a code.',
            'secretCodeInvalidMessage' => 'Invalid code.',
            'secretCodeVerifiedMessage' => 'Code verified.',
            'secretCodeSendButtonLabel' => 'Send Code',
            'secretCodeVerifyButtonLabel' => 'Verify Code',
            'secretCodeResendButtonLabel' => 'Resend Code'
        };
        NF_Form_Version__c versionRecord = createBaseVersion(
            'Rich Publish Form',
            formKey,
            'Draft',
            'Never Published',
            true,
            JSON.serialize(uiSettings)
        );
        update new NF_Form_Version__c(
            Id = versionRecord.Id,
            Custom_JS__c = 'TwinaForms.on("change", function () { TwinaForms.setValue("textCode", "+972"); });'
        );
        versionRecord = [
            SELECT Id, Form__c, Version_Number__c, Version_Status__c, Publish_Status__c, Custom_JS__c
            FROM NF_Form_Version__c
            WHERE Id = :versionRecord.Id
        ];

        ContentVersion imageVersion = new ContentVersion(
            Title = 'publisher-inline-image',
            PathOnClient = 'publisher-inline-image.png',
            VersionData = Blob.valueOf('png')
        );
        insert imageVersion;
        imageVersion = [
            SELECT Id
            FROM ContentVersion
            WHERE Id = :imageVersion.Id
        ];

        NativeFormsTestDataFactory.createAction(
            versionRecord.Id,
            'Prefill',
            'Contact',
            'prefillAction1',
            'PrefilContact',
            'findOne',
            10,
            json(new Map<String, Object>{
                'conditions' => new List<Object>{
                    new Map<String, Object>{
                        'fieldApiName' => 'Email',
                        'operator' => 'eq',
                        'valueSource' => 'param',
                        'valueText' => 'email'
                    }
                },
                'conditionLogic' => '1',
                'conditionExpression' => '1',
                'onNotFound' => 'ignore'
            })
        );
        NativeFormsTestDataFactory.createAction(
            versionRecord.Id,
            'Submit',
            'Contact',
            'submitAction1',
            'SubmitContact',
            'findAndUpdate',
            20,
            json(new Map<String, Object>{
                'conditions' => new List<Object>{
                    new Map<String, Object>{
                        'fieldApiName' => 'Email',
                        'operator' => 'eq',
                        'valueSource' => 'field',
                        'valueText' => 'email1'
                    }
                },
                'conditionLogic' => '1',
                'conditionExpression' => '1',
                'onNotFound' => 'create'
            })
        );
        NativeFormsTestDataFactory.createAction(
            versionRecord.Id,
            'Submit',
            'Case',
            'submitAction2',
            'SubmitCase',
            'upsertMany',
            30,
            json(new Map<String, Object>{
                'repeatGroupKey' => 'recordsList',
                'relationshipField' => 'ContactId',
                'relationshipValueSource' => 'alias',
                'relationshipValueText' => 'SubmitContact.Id',
                'allowDelete' => true
            })
        );

        NF_Form_Element__c section = NativeFormsTestDataFactory.createElement(
            versionRecord.Id,
            'section',
            'Main Section',
            'mainSection',
            1,
            10,
            json(new Map<String, Object>{
                'columns' => 2,
                'showTitle' => true,
                'boxed' => true,
                'text' => 'Section intro'
            }),
            null
        );
        NF_Form_Element__c groupElement = NativeFormsTestDataFactory.createElement(
            versionRecord.Id,
            'group',
            'Nested Group',
            'nestedGroup',
            2,
            20,
            json(new Map<String, Object>{
                'columns' => 1
            }),
            section.Element_Id__c
        );

        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'heading', 'Display Text', 'displayText1', 3, 30, withSectionColumn(json(new Map<String, Object>{ 'html' => '<p><a href="https://twinaforms.com/help/formulas">Learn more</a></p>' }), 1), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'image', 'Hero Image', 'image1', 4, 40, withSectionColumn(json(new Map<String, Object>{ 'contentVersionId' => String.valueOf(imageVersion.Id), 'altText' => 'Hero image', 'imageFit' => 'center', 'imageWidthPercent' => 50 }), 2), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'email', 'Email', 'email1', 5, 50, withSectionColumn(fieldConfig('above', false, true, 'PrefilContact', 'Email', true, 'submitAction1', 'Email'), 1), groupElement.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'tel', 'Phone', 'phone1', 6, 60, withSectionColumn(fieldConfig('above', false, false, null, null, true, 'submitAction1', 'Phone'), 1), groupElement.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'date', 'Start Date', 'date1', 7, 70, withSectionColumn(json(new Map<String, Object>{ 'labelPosition' => 'above', 'fieldBehavior' => 'editable', 'dateFormat' => 'us', 'minDate' => '2026-01-01', 'maxDate' => '2026-12-31' }), 2), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'time', 'Start Time', 'time1', 19, 75, withSectionColumn(json(new Map<String, Object>{ 'labelPosition' => 'above', 'fieldBehavior' => 'editable', 'defaultValue' => '09:30', 'placeholder' => '19:00', 'timeFormat' => '24h' }), 2), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'checkbox', 'Accept Terms', 'checkbox1', 8, 80, withSectionColumn(NativeFormsTestConfigFactory.checkboxConfigJson(false), 1), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'text', 'Formula Text', 'formulaText1', 9, 90, withSectionColumn(NativeFormsTestConfigFactory.formulaFieldConfigJson('IF({checkbox1} == true, "Yes", "No")'), 2), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'textarea', 'Notes', 'notes1', 10, 100, withSectionColumn(json(new Map<String, Object>{ 'labelPosition' => 'above', 'fieldBehavior' => 'editable', 'rows' => 4 }), 1), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'url', 'Website', 'website1', 11, 110, withSectionColumn(json(new Map<String, Object>{ 'labelPosition' => 'above', 'fieldBehavior' => 'editable', 'placeholderText' => 'https://example.com' }), 2), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'select', 'Priority', 'priority1', 12, 120, withSectionColumn(optionFieldConfig('above', selectOptions()), 1), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'radio', 'Title', 'title1', 13, 130, withSectionColumn(optionFieldConfig('above', radioOptions()), 2), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'fileUpload', 'Attachment', 'file1', 14, 140, withSectionColumn(json(new Map<String, Object>{ 'labelPosition' => 'above', 'allowMultiple' => true, 'allowedExtensions' => 'pdf,png', 'maxFileSizeMb' => 10, 'targetSubmitActionKey' => 'submitAction1' }), 1), section.Element_Id__c);

        NF_Form_Element__c repeatGroup = NativeFormsTestDataFactory.createElement(
            versionRecord.Id,
            'repeatGroup',
            'Records List',
            'recordsList',
            15,
            150,
            json(new Map<String, Object>{
                'boxed' => true,
                'columns' => 2,
                'repeatSourceAlias' => 'PrefilCase',
                'allowAddRows' => true,
                'allowDeleteRows' => true
            }),
            null
        );
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'text', 'Case Subject', 'subject', 16, 160, withSectionColumn(fieldConfig('above', false, true, 'PrefilCase', 'Subject', true, 'submitAction2', 'Subject'), 1), repeatGroup.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'select', 'Case Priority', 'casePriority', 17, 170, withSectionColumn(json(new Map<String, Object>{
            'labelPosition' => 'above',
            'options' => selectOptions(),
            'defaultValue' => 'medium',
            'prefillEnabled' => true,
            'prefillAlias' => 'PrefilCase',
            'prefillFieldPath' => 'Priority',
            'submitEnabled' => true,
            'submitActionKey' => 'submitAction2',
            'submitFieldPath' => 'Priority'
        }), 2), repeatGroup.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'text', 'Case Id', 'caseId', 18, 180, withSectionColumn(json(new Map<String, Object>{
            'labelPosition' => 'above',
            'fieldBehavior' => 'hidden',
            'prefillEnabled' => true,
            'prefillAlias' => 'PrefilCase',
            'prefillFieldPath' => 'Id',
            'submitEnabled' => true,
            'submitActionKey' => 'submitAction2',
            'submitFieldPath' => 'Id'
        }), 2), repeatGroup.Element_Id__c);

        return versionRecord;
    }

    private static String fieldConfig(
        String labelPosition,
        Boolean required,
        Boolean prefillEnabled,
        String prefillAlias,
        String prefillFieldPath,
        Boolean submitEnabled,
        String submitActionKey,
        String submitFieldPath
    ) {
        Map<String, Object> config = new Map<String, Object>{
            'labelPosition' => labelPosition,
            'fieldBehavior' => 'editable',
            'required' => required == true
        };
        if (prefillEnabled == true) {
            config.put('prefillEnabled', true);
            config.put('prefillAlias', prefillAlias);
            config.put('prefillFieldPath', prefillFieldPath);
        }
        if (submitEnabled == true) {
            config.put('submitEnabled', true);
            config.put('submitActionKey', submitActionKey);
            config.put('submitFieldPath', submitFieldPath);
        }
        return json(config);
    }

    private static String optionFieldConfig(String labelPosition, List<Object> options) {
        return json(new Map<String, Object>{
            'labelPosition' => labelPosition,
            'fieldBehavior' => 'editable',
            'options' => options,
            'defaultValue' => 'medium'
        });
    }

    private static String withSectionColumn(String rawConfig, Integer sectionColumn) {
        Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped(String.isBlank(rawConfig) ? '{}' : rawConfig);
        config.put('sectionColumn', sectionColumn);
        return json(config);
    }

    private static String json(Map<String, Object> value) {
        return JSON.serialize(value == null ? new Map<String, Object>() : value);
    }

    private static List<Object> selectOptions() {
        return new List<Object>{
            new Map<String, Object>{ 'label' => 'Medium', 'value' => 'medium' },
            new Map<String, Object>{ 'label' => 'High', 'value' => 'high' }
        };
    }

    private static List<Object> radioOptions() {
        return new List<Object>{
            new Map<String, Object>{ 'label' => 'Mr.', 'value' => 'mr' },
            new Map<String, Object>{ 'label' => 'Ms.', 'value' => 'ms' }
        };
    }
}
