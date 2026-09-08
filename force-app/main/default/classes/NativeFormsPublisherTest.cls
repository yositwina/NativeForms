@IsTest
private class NativeFormsPublisherTest {
    @IsTest
    static void recordsListFieldsRetainVisibilityConditions() {
        Map<String, Object> config = new Map<String, Object>{
            'conditionalEnabled' => true,
            'conditionalConditions' => new List<Object>{new Map<String, Object>{
                'fieldKey' => 'activity', 'operator' => 'equals', 'value' => 'Travel'
            }},
            'required' => true,
            'options' => new List<Object>{new Map<String, Object>{'label' => 'One', 'value' => 'one'}}
        };
        for (String fieldType : new List<String>{'text', 'textarea', 'select', 'checkbox', 'radio', 'multiCheckbox', 'date', 'time', 'lookup', 'signature', 'heading', 'spacer', 'button'}) {
            NF_Form_Element__c field = new NF_Form_Element__c(
                Element_Type__c = fieldType, Field_Key__c = 'description', Label__c = 'Description',
                Config_JSON__c = JSON.serialize(config)
            );
            String html = NativeFormsPublisher.renderRepeatGroupChildElement(field, 'activities', true, false, 'en');
            System.assert(html.contains('data-conditions='), fieldType + ' must retain row visibility conditions.');
            System.assert(html.contains('activity'), fieldType + ' must retain the controlling field key.');
            System.assert(html.contains('Travel'), fieldType + ' must retain the comparison value.');
            config.put('conditionalEnabled', false);
            field.Config_JSON__c = JSON.serialize(config);
            html = NativeFormsPublisher.renderRepeatGroupChildElement(field, 'activities', true, false, 'en');
            System.assert(!html.contains('data-conditions='), fieldType + ' must omit conditions when disabled.');
            config.put('conditionalEnabled', true);
        }
    }

    @IsTest
    static void recordsListFieldsCarryDefaultValue() {
        Map<String, Object> config = new Map<String, Object>{
            'defaultValue' => 'True',
            'placeholder' => 'Enter text',
            'options' => new List<Object>{new Map<String, Object>{'label' => 'True', 'value' => 'True'}}
        };
        for (String fieldType : new List<String>{'text', 'textarea', 'number', 'select', 'checkbox', 'radio', 'multiCheckbox', 'email', 'tel', 'url'}) {
            NF_Form_Element__c field = new NF_Form_Element__c(
                Element_Type__c = fieldType, Field_Key__c = 'condition', Label__c = 'Condition',
                Config_JSON__c = JSON.serialize(config)
            );
            String html = NativeFormsPublisher.renderRepeatGroupChildElement(field, 'cases', true, false, 'en');
            System.assert(
                html.contains('data-repeat-default="True"'),
                fieldType + ' must carry its default value into the row template.'
            );
        }

        NF_Form_Element__c blankDefault = new NF_Form_Element__c(
            Element_Type__c = 'text', Field_Key__c = 'condition', Label__c = 'Condition',
            Config_JSON__c = JSON.serialize(new Map<String, Object>{'defaultValue' => '', 'placeholder' => 'Enter text'})
        );
        System.assert(
            !NativeFormsPublisher.renderRepeatGroupChildElement(blankDefault, 'cases', true, false, 'en')
                .contains('data-repeat-default'),
            'A blank default must not emit the attribute.'
        );

        NF_Form_Element__c legacySeed = new NF_Form_Element__c(
            Element_Type__c = 'text', Field_Key__c = 'condition', Label__c = 'Condition',
            Config_JSON__c = JSON.serialize(new Map<String, Object>{'defaultValue' => 'Enter text'})
        );
        System.assert(
            !NativeFormsPublisher.renderRepeatGroupChildElement(legacySeed, 'cases', true, false, 'en')
                .contains('data-repeat-default'),
            'A legacy seed default must not leak into the row as a real value.'
        );

        NF_Form_Element__c formulaField = new NF_Form_Element__c(
            Element_Type__c = 'text', Field_Key__c = 'condition', Label__c = 'Condition',
            Config_JSON__c = JSON.serialize(new Map<String, Object>{
                'defaultValue' => 'True', 'isFormula' => true, 'formulaExpression' => '1+1'
            })
        );
        System.assert(
            !NativeFormsPublisher.renderRepeatGroupChildElement(formulaField, 'cases', true, false, 'en')
                .contains('data-repeat-default'),
            'A formula field must not carry a default value.'
        );
    }

    @TestSetup
    static void setupPermissions() {
        NativeFormsTestDataFactory.assignTwinaFormsUserPermissionSet();
        NativeFormsBootstrapV2Signer.getOrCreateSigningSecretB64();
    }

    private class PublisherCalloutMock implements HttpCalloutMock {
        Boolean failPresign;
        Boolean failRegister;
        Integer presignCalls = 0;
        Integer uploadCalls = 0;
        Integer registerCalls = 0;
        Integer snapshotCalls = 0;
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

            if (endpoint.contains('/portable-snapshots/latest')) {
                snapshotCalls += 1;
                response.setHeader('Content-Type', 'application/json');
                response.setStatusCode(200);
                response.setStatus('OK');
                response.setBody(JSON.serialize(new Map<String, Object>{
                    'success' => true,
                    'snapshotId' => '00Dxx0000000000#rich-published-form'
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
            'enableProPageLayoutClone' => true,
            'enableProFormulaFields' => true,
            'enableProPostSubmitAutoLink' => true,
            'enableProUserVerification' => true,
            'enableProLoadFile' => true,
            'enableProElectronicSignature' => true,
            'enableProSubmissionPdf' => true,
            'enableProSurveyFields' => true,
            'enableProCustomJs' => true,
            'enableProButtonElements' => true,
            'enableProMergedDocument' => true
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
        System.runAs(new User(Id = UserInfo.getUserId())) {
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

        NF_Form_Version__c blankSenderVersion = createBaseVersion(
            'Blank Sender Form',
            'blank-sender-form',
            'Draft',
            'Never Published',
            false,
            json(new Map<String, Object>{
                'languageCode' => 'en',
                'userVerificationEnabled' => true,
                'userVerificationSenderEmail' => ''
            })
        );
        NativeFormsPublisher.PublishResult blankSenderResult = NativeFormsPublisher.publishVersion(blankSenderVersion.Id);
        System.assertEquals(false, blankSenderResult.success, 'User Verification publish should fail when sender email is blank.');
        System.assertEquals(
            'User Verification requires a sender email. Enter a verified Org-Wide Email Address or authorized sender email.',
            blankSenderResult.message,
            'Blank sender failure should explain the required field.'
        );

        System.assertEquals(true, NativeFormsPublisher.hasSharedCaptchaSiteKey(), 'Shared CAPTCHA key helper should report the packaged key as present.');
        System.assert(String.isNotBlank(NativeFormsPublisher.getSharedCaptchaSiteKey()), 'Shared CAPTCHA key helper should return the packaged key value.');
        System.assertEquals('my-friendly-form', NativeFormsPublisher.normalizePublishedFormSlug('my-friendly-form'), 'Slug helper should preserve already valid slugs.');
        System.assertEquals(null, NativeFormsPublisher.normalizePublishedFormSlug('Bad_Key'), 'Slug helper should reject underscores.');
        System.assert(
            NativeFormsPublisher.buildInternalFormId(UserInfo.getOrganizationId().substring(0, 15), readonlyVersion.Form__c).startsWith('nf-'),
            'Internal form ids should use the native publish prefix.'
        );

        NativeFormsTenantEntitlements.EntitlementSnapshot starterSnapshot = buildProEntitlementsSnapshot();
        starterSnapshot.planCode = 'starter';
        starterSnapshot.effectiveFeatureFlags.put('enableProMergedDocument', false);
        NativeFormsTenantEntitlements.setCachedSnapshot(starterSnapshot);
        NF_Form_Version__c mergedDocumentBlockedVersion = createBaseVersion(
            'Blocked Merged Document Form',
            'blocked-merged-document-form',
            'Draft',
            'Never Published',
            false,
            NativeFormsTestConfigFactory.basicUiSettingsJson()
        );
        NativeFormsTestDataFactory.createElement(
            mergedDocumentBlockedVersion.Id,
            'mergedDocument',
            'Merged Document',
            'mergedDocument1',
            1,
            10,
            json(new Map<String, Object>{ 'html' => '<p>{{Contact.FirstName}}</p>' }),
            null
        );
        NativeFormsPublisher.PublishResult mergedDocumentBlockedResult = NativeFormsPublisher.publishVersion(mergedDocumentBlockedVersion.Id);
        System.assertEquals(false, mergedDocumentBlockedResult.success, 'Merged Document should be blocked when the plan flag is disabled.');
        System.assertEquals('Merged Document is not available on your current TwinaForms plan.', mergedDocumentBlockedResult.message);

        setAllProFlagsEnabled();
        NF_Form_Version__c brokenRowSignatureVersion = createBaseVersion(
            'Broken Row Signature Form',
            'broken-row-signature-form',
            'Draft',
            'Never Published',
            false,
            NativeFormsTestConfigFactory.basicUiSettingsJson()
        );
        NF_Form_Element__c brokenRecordsList = NativeFormsTestDataFactory.createElement(
            brokenRowSignatureVersion.Id,
            'repeatGroup',
            'Timesheets',
            'timesheets',
            1,
            10,
            json(new Map<String, Object>{
                'allowAddRows' => true,
                'columns' => 2
            }),
            null
        );
        NativeFormsTestDataFactory.createElement(
            brokenRowSignatureVersion.Id,
            'signature',
            'Row Signature',
            'rowSignature',
            2,
            20,
            json(new Map<String, Object>{
                'labelPosition' => 'above',
                'attachToRowRecord' => true
            }),
            brokenRecordsList.Element_Id__c
        );
        NativeFormsTestDataFactory.createAction(
            brokenRowSignatureVersion.Id,
            'Submit',
            'Contact',
            'submitContact',
            'savedContact',
            'findAndUpdate',
            10,
            json(new Map<String, Object>{
                'conditions' => new List<Object>{
                    new Map<String, Object>{
                        'fieldApiName' => 'Email',
                        'operator' => 'eq',
                        'valueSource' => 'fixed',
                        'valueText' => 'nobody@example.com'
                    }
                },
                'conditionLogic' => '1',
                'conditionExpression' => '1',
                'onNotFound' => 'error'
            })
        );

        NativeFormsPublisher.PublishResult brokenRowSignatureResult = NativeFormsPublisher.publishVersion(brokenRowSignatureVersion.Id);
        System.assertEquals(false, brokenRowSignatureResult.success, 'Row signature attachment should require a records-list save action.');
        System.assert(
            brokenRowSignatureResult.message.contains('Save records list'),
            'Guard message should explain that a Records List save action is required.'
        );
        }
    }

    @IsTest
    static void publishSuccessCreatesPublicationRegisterPayloadAndSuccessorDraft() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
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
        System.assert(mock.uploadedHtml.contains('nf-user-verification'), 'Generated HTML should include the User Verification section when enabled.');
        System.assert(mock.uploadedHtml.contains('data-formula-target="true"'), 'Generated HTML should include formula metadata for formula fields.');
        System.assert(mock.uploadedHtml.contains('data-repeat-field-key="caseSummary" data-repeat-source-field="caseSummary" data-formula-target="true"'), 'Records List formula targets should publish as collected row fields.');
        System.assert(mock.uploadedHtml.contains('data-formula-expression="CONCAT({email1}, &quot; - &quot;, {row.subject})"'), 'Records List formulas should support mixed top-level and same-row references.');
        System.assert(mock.uploadedHtml.contains('readFormulaSourceValue(fieldKey,rowEl)'), 'Formula runtime should resolve same-row formula values from the active Records List row.');
        System.assert(mock.uploadedHtml.contains('setRepeatFieldValue(field,value);applyLockState(field);'), 'Lookup field mapping must re-apply lock state to Records List row fields.');
        for (String formulaFunctionName : new List<String>{
            'LEFT:function', 'RIGHT:function', 'MID:function', 'LEN:function', 'TRIM:function',
            'UPPER:function', 'LOWER:function', 'SUBSTITUTE:function', 'CONTAINS:function', 'BEGINS:function',
            'WEEKDAY:function', 'DAYNAME:function', 'DATE:function', 'ADDMONTHS:function', 'DATEVALUE:function',
            'AND:function', 'OR:function', 'NOT:function',
            'MOD:function', 'CEILING:function', 'FLOOR:function', 'POWER:function', 'SQRT:function'
        }) {
            System.assert(
                mock.uploadedHtml.contains(formulaFunctionName),
                'Formula runtime should publish the ' + formulaFunctionName.replace(':function', '') + '() function.'
            );
        }
        System.assert(
            mock.uploadedHtml.contains('formulaReplaceOutsideStrings'),
            'Formula runtime should skip quoted string literals when folding AND/OR to operators.'
        );
        System.assert(
            mock.uploadedHtml.contains('\\bAND\\b(?!\\s*\\()'),
            'Uppercase AND( should stay callable as a function instead of being folded to the operator.'
        );
        System.assert(
            mock.uploadedHtml.contains('const dateOnly=value.match'),
            'Date-only formula values should be parsed as local midnight so WEEKDAY/DAY are timezone-stable.'
        );
        System.assert(mock.uploadedHtml.contains('uploadStatusUrl'), 'Generated HTML should publish the upload scan status endpoint.');
        System.assert(mock.uploadedHtml.contains('waitForSafeUpload'), 'Generated HTML should wait for malware scan completion before accepting uploaded files.');
        System.assert(mock.uploadedHtml.contains('Uploaded files are checked for safety'), 'Generated HTML should explain that uploaded files are checked before attachment.');
        System.assert(mock.uploadedHtml.contains('postSubmitUrlMode'), 'Generated HTML should include the post-submit redirect URL mode.');
        System.assert(mock.uploadedHtml.contains('postSubmitUrlFormula'), 'Generated HTML should include the post-submit redirect formula setting.');
        System.assert(mock.uploadedHtml.contains('resolveFormulaPostSubmitUrl'), 'Generated HTML should include formula redirect resolution.');
        System.assert(mock.uploadedHtml.contains('URLENCODE:function'), 'Generated HTML should expose URLENCODE in the shared formula runtime.');
        System.assert(mock.uploadedHtml.contains('data-nativeforms-time="true"'), 'Generated HTML should render Time fields as TwinaForms-controlled text inputs.');
        System.assert(mock.uploadedHtml.contains('nf-spacer--field-with-label'), 'Generated HTML should render the configured Blank Space with label space.');
        System.assert(mock.uploadedHtml.contains('data-nativeforms-date-picker="true"'), 'Generated HTML should wrap Date fields with the TwinaForms date picker control.');
        System.assert(mock.uploadedHtml.contains('data-date-picker-toggle'), 'Generated HTML should include a visible Date picker button.');
        System.assert(mock.uploadedHtml.contains('.nf-date-wrap{position:relative;display:block;min-width:0;}'), 'Date picker controls should share the date input width.');
        System.assert(mock.uploadedHtml.contains('@container (max-width:620px)'), 'Repeat rows should collapse dense column layouts based on their actual container width.');
        System.assert(mock.uploadedHtml.contains('@container (max-width:900px)'), 'Five-column repeat rows should step down to four columns when their container narrows.');
        System.assert(mock.uploadedHtml.contains('function renderDatePicker(input)'), 'Generated HTML should include the TwinaForms calendar renderer.');
        System.assert(mock.uploadedHtml.contains('function moveDatePickerMonth(input,delta)'), 'Generated HTML should support Date picker month navigation.');
        System.assert(mock.uploadedHtml.contains('target.closest("[data-date-nav]")'), 'Generated HTML should handle Date picker arrows through delegated form clicks.');
        System.assert(mock.uploadedHtml.contains('initDatePickers(rowsHost.lastElementChild)'), 'Dynamically added Records List rows should initialize Date picker controls.');
        System.assert(mock.uploadedHtml.contains('wireLiveValidation(rowsHost.lastElementChild)'), 'Dynamically added Records List rows should initialize live validation controls.');
        System.assert(mock.uploadedHtml.contains('data-validation-wired'), 'Live validation should guard against duplicate event binding.');
        System.assert(mock.uploadedHtml.contains('function validateAllFields()'), 'Generated HTML should expose submit-time field validation.');
        System.assert(mock.uploadedHtml.contains('invalidField.reportValidity();'), 'Submit should report only a visible invalid field.');
        System.assert(mock.uploadedHtml.contains('<form class="nf-grid" novalidate'), 'Published forms must validate visible fields in the submit handler instead of browser pre-validation.');
        System.assert(mock.uploadedHtml.contains('applyLockState(lookupEl)'), 'Prefill writes to Lookup controls should apply the existing lock behavior to that control.');
        System.assert(mock.uploadedHtml.contains('fields.forEach(function(el){if(el.type==="checkbox")'), 'Prefill writes should apply lock behavior to each written control.');
        System.assert(mock.uploadedHtml.contains('restoreUserVerificationSession();applyLockedFields();emitTwinaFormsEvent("form:ready"'), 'Published forms should apply lock behavior once during initialization for default values.');
        System.assert(mock.uploadedHtml.contains('data-time-format="24h"'), 'Generated HTML should include the configured Time display format.');
        System.assert(mock.uploadedHtml.contains('value="09:30"'), 'Generated HTML should keep plain HH:mm default values for Time fields.');
        System.assert(mock.uploadedHtml.contains('.nf-shell[dir="rtl"] input[data-nativeforms-time="true"]{direction:ltr;text-align:right;}'), 'RTL forms should right-align Time values without reversing the time string.');
        System.assert(mock.uploadedHtml.contains('salesforceTimeMatch'), 'Generated HTML should normalize Salesforce Time prefill values with seconds or milliseconds.');
        System.assert(mock.uploadedHtml.contains('clearStatus();}});});});}'), 'Generated HTML should clear stale time/date validation status after corrected input validates.');
        System.assert(!mock.uploadedHtml.contains('maxlength="254"'), 'Generated HTML should warn and validate textarea character limits without hard-blocking typing.');
        System.assert(mock.uploadedHtml.contains('data-character-limit="254"'), 'Generated HTML should include textarea character limit metadata.');
        System.assert(mock.uploadedHtml.contains('data-character-counter="true"'), 'Generated HTML should show a textarea character counter.');
        System.assert(mock.uploadedHtml.contains('data-element-id="group-'), 'Generated HTML should include Group containers as runtime elements.');
        System.assert(mock.uploadedHtml.contains('data-hidden-behavior="true" style="display:none;"'), 'Hidden Group containers should publish a static hidden marker on the full subtree wrapper.');
        System.assert(mock.uploadedHtml.contains('const staticHidden=el.dataset.hiddenBehavior==="true"'), 'Runtime condition evaluation should preserve hidden Group/Section containers.');
        System.assert(mock.uploadedHtml.contains('const visible=!staticHidden&&conditionVisible&&manualVisible'), 'Runtime visibility should never re-show statically hidden containers.');
        System.assert(mock.uploadedHtml.contains('data-nativeforms-multi-checkbox="true"'), 'Generated HTML should render Multi Checkbox options as checkbox controls.');
        System.assert(mock.uploadedHtml.contains('readMultiCheckboxValue'), 'Generated HTML should collect Multi Checkbox values as semicolon strings.');
        System.assert(mock.uploadedHtml.contains('validateMultiCheckboxGroups()'), 'Generated HTML should validate required Multi Checkbox groups before submit.');
        System.assert(mock.uploadedHtml.contains('<span>★★★★★</span>'), 'Generated HTML should render 1-5 Star Rating labels as star icons.');
        System.assert(!mock.uploadedHtml.contains('<span>stars 5</span>'), 'Generated HTML should not expose the stored star option text label.');
        System.assert(mock.uploadedHtml.contains('data-lookup-input="true"'), 'Generated HTML should render the visible Lookup input.');
        System.assert(mock.uploadedHtml.contains('.nf-shell[dir="rtl"] .nf-lookup input[data-lookup-input="true"],.nf-shell[dir="rtl"] .nf-lookup__option,.nf-shell[dir="rtl"] .nf-lookup__status{direction:rtl;text-align:right;}'), 'RTL forms should right-align Lookup text, result options, and status text.');
        System.assert(mock.uploadedHtml.contains('data-nativeforms-lookup="true" data-lookup-field-key="accountId" data-lookup-required="false" data-lookup-min-length="2"'), 'Locked Lookup fields should mark the compound lookup control.');
        System.assert(mock.uploadedHtml.contains('data-lock-on-prefill="true"'), 'Locked Lookup fields should mark the compound lookup control for runtime locking.');
        System.assert(mock.uploadedHtml.contains('data-nativeforms-lookup="true" data-lookup-repeat="true" data-lookup-field-key="caseAccountId"'), 'Records List lookup fields should render as row-scoped lookup controls.');
        System.assert(mock.uploadedHtml.contains('data-lookup-hidden="true" data-repeat-field-key="caseAccountId"'), 'Records List lookup fields should keep the selected record Id in the collected row value.');
        System.assert(mock.uploadedHtml.contains('data-lookup-set-fields="'), 'Generated HTML should include lookup field-copy mappings.');
        System.assert(mock.uploadedHtml.contains('&quot;sourceField&quot;:&quot;Phone&quot;'), 'Generated HTML should include top-level lookup source fields.');
        System.assert(mock.uploadedHtml.contains('&quot;targetFieldKey&quot;:&quot;subject&quot;'), 'Generated HTML should include row-scoped lookup target fields.');
        System.assert(mock.uploadedHtml.contains('lookupRecordFieldValue(fields,sourceField)'), 'Lookup mapping should resolve returned fields case-insensitively at runtime.');
        System.assert(mock.uploadedHtml.contains('applyLookupSetFields(lookupEl,record,false)'), 'Lookup selection should copy selected record fields into mapped form fields.');
        System.assert(mock.uploadedHtml.contains('lookupEl.dataset.lookupRepeat==="true"?lookupEl.closest("[data-repeat-row]")'), 'Records List lookup copies should stay within the active row.');
        System.assert(mock.uploadedHtml.contains('applyLookupSetFields(lookupEl,null,true)'), 'Clearing a lookup should clear mapped form fields.');
        System.assert(mock.uploadedHtml.contains('setLookupElementValue(lookupEl,button.dataset.lookupId'), 'Lookup selection should write to the active lookup element, not the first lookup with the same field key.');
        System.assert(mock.uploadedHtml.contains('initLookupControls(rowsHost.lastElementChild)'), 'Dynamically added Records List rows should initialize lookup controls.');
        System.assert(mock.uploadedHtml.contains('resolveLookupElementLabel(lookupEl,value)'), 'Prefilled Records List lookup Ids should resolve their visible labels per row.');
        System.assert(mock.uploadedHtml.contains('lookupEl.dataset.lookupLocked=hasLookupValue?"true":"false"'), 'Locked Lookup fields should lock the compound lookup control after prefill.');
        System.assert(mock.uploadedHtml.contains('input.readOnly=hasLookupValue'), 'Locked Lookup fields should make the visible lookup input read-only after prefill.');
        System.assert(mock.uploadedHtml.contains('clear.disabled=hasLookupValue'), 'Locked Lookup fields should disable the clear button after prefill.');
        System.assert(mock.uploadedHtml.contains('--nf-bg-gradient:'), 'Generated HTML should expose the theme background gradient color.');
        System.assert(mock.uploadedHtml.contains('linear-gradient(180deg,var(--nf-bg) 0%,var(--nf-bg-gradient) 100%)'), 'Generated HTML should keep theme start/end colors as the background fallback.');
        System.assert(mock.uploadedHtml.contains('https://example.com/theme-logo.png'), 'Generated HTML should include the theme logo URL.');
        System.assert(mock.uploadedHtml.contains('https://example.com/theme-background.png'), 'Generated HTML should include the theme background image URL.');
        System.assert(mock.uploadedHtml.contains('https://example.com/theme-footer.png'), 'Generated HTML should include the theme footer image URL.');
        System.assert(mock.uploadedHtml.contains('nf-footer-image'), 'Generated HTML should render the theme footer image inside the form shell.');
        System.assert(mock.uploadedHtml.contains('https://fonts.googleapis.com/css2?'), 'Generated HTML should load selected Google Fonts.');
        System.assert(mock.uploadedHtml.contains('family=Rubik:wght@400;500;600;700'), 'Generated HTML should include selected title font.');
        System.assert(mock.uploadedHtml.contains('family=Assistant:wght@400;500;600;700'), 'Generated HTML should include selected section font.');
        System.assert(mock.uploadedHtml.contains('family=Heebo:wght@400;500;600;700'), 'Generated HTML should include selected main font.');
        System.assert(mock.uploadedHtml.contains('family=Inter:wght@400;500;600;700'), 'Generated HTML should include selected button font.');
        System.assert(mock.uploadedHtml.contains('https://twinaforms.com/help/formulas'), 'Generated HTML should preserve rich text links.');
        System.assert(mock.uploadedHtml.contains('data:image/png;base64,'), 'Generated HTML should inline image assets when contentVersionId is present.');
        System.assert(mock.uploadedHtml.contains('window.TwinaForms=twinaFormsApi'), 'Generated HTML should expose the TwinaForms runtime API.');
        System.assert(mock.uploadedHtml.contains('window.NativeForms=window.TwinaForms'), 'Generated HTML should keep the NativeForms compatibility alias.');
        System.assert(mock.uploadedHtml.contains('new Function("TwinaForms",customJsSource)'), 'Generated HTML should run custom JavaScript through the guarded runner.');
        System.assert(mock.uploadedHtml.contains('runGuardedCustomJs();'), 'Generated HTML should execute custom JavaScript through the guarded helper.');
        System.assert(mock.uploadedHtml.contains('data-nativeforms-signature="true"'), 'Generated HTML should render signature pads.');
        System.assert(mock.uploadedHtml.contains('collectSignatures()'), 'Generated HTML should collect signature payloads before submit.');
        System.assert(mock.uploadedHtml.contains('data-nativeforms-row-signature="true"'), 'Generated HTML should render records-list row signature pads.');
        System.assert(mock.uploadedHtml.contains('validateRepeatRowSignatures()'), 'Generated HTML should validate required row signatures before submit.');
        System.assert(mock.uploadedHtml.contains('_rowSignature'), 'Generated HTML should collect row signature payloads per records-list row.');
        System.assert(mock.uploadedHtml.contains('data-nativeforms-button="true"'), 'Generated HTML should render Portal Buttons as action controls.');
        System.assert(mock.uploadedHtml.contains('activeButtonNavigationUrl'), 'Generated HTML should support submit-before-navigation destination precedence.');
        System.assert(mock.uploadedHtml.contains('{{row.caseId}}'), 'Records List Buttons should publish explicit row-scoped navigation tokens.');
        System.assert(mock.uploadedHtml.contains('data-merged-document-template'), 'Generated HTML should render Merged Document template metadata.');
        System.assert(mock.uploadedHtml.contains('resolveMergedDocumentHtml'), 'Generated HTML should include Merged Document runtime resolution.');
        System.assert(mock.uploadedHtml.contains('{{PrefilAccount.Name}}'), 'Generated HTML should preserve Merged Document alias tokens for runtime resolution.');
        System.assert(mock.uploadedHtml.contains('.nf-section__grid--10{grid-template-columns:repeat(10,minmax(0,1fr));}'), 'Generated HTML should support section grids up to 10 columns.');
        System.assert(mock.uploadedHtml.contains('nf-repeat--has-header'), 'Records List should support table-header label mode on desktop.');
        System.assert(mock.uploadedHtml.contains('nf-repeat-mobile-label'), 'Records List header mode should keep row labels available for mobile.');
        System.assertEquals(false, mock.uploadedHtml.contains('</script><script>TwinaForms.on('), 'Custom JavaScript should no longer be appended as a raw trailing script tag.');

        Map<String, Object> registerPayload = (Map<String, Object>) JSON.deserializeUntyped(mock.registerBody);
        System.assertEquals('published', String.valueOf(registerPayload.get('status')), 'Register payload should mark the form as published.');
        System.assertEquals('secure-edit', String.valueOf(registerPayload.get('securityMode')), 'Register payload should preserve the configured security mode.');
        System.assertEquals('standard', String.valueOf(registerPayload.get('rateLimitProfile')), 'Register payload should default the rate-limit profile.');
        System.assertEquals('acme/forms/current/index.html', String.valueOf(registerPayload.get('generatedHtmlRef')), 'Register payload should carry the generated HTML key.');
        System.assertEquals('rich-published-form', String.valueOf(registerPayload.get('formSlug')), 'Register payload should use the normalized friendly slug.');

        Map<String, Object> submitPolicy = (Map<String, Object>) registerPayload.get('submitPolicy');
        Map<String, Object> allowedWriteFields = (Map<String, Object>) submitPolicy.get('allowedWriteFields');
        List<Object> caseWriteFields = (List<Object>) allowedWriteFields.get('Case');
        System.assert(caseWriteFields.contains('ContactId'), 'Records List parent relationship fields must be allowed by the submit policy.');

        Map<String, Object> captcha = (Map<String, Object>) registerPayload.get('captcha');
        System.assertEquals(true, captcha.get('enabled'), 'Register payload should enable CAPTCHA when the form requires it.');
        System.assert(String.isNotBlank(String.valueOf(captcha.get('siteKey'))), 'Register payload should include the shared CAPTCHA site key.');

        Map<String, Object> lookupDefinition = (Map<String, Object>) registerPayload.get('lookupDefinition');
        Map<String, Object> lookupFields = (Map<String, Object>) lookupDefinition.get('fields');
        Map<String, Object> accountLookup = (Map<String, Object>) lookupFields.get('accountId');
        System.assert(listContainsIgnoreCase((List<Object>) accountLookup.get('returnFields'), 'Phone'), 'Lookup definition should include mapped source fields in the returned field list.');
        System.assertEquals('Phone', String.valueOf(((Map<String, Object>) ((List<Object>) accountLookup.get('setFields'))[0]).get('sourceField')), 'Lookup definition should publish canonical Salesforce API field names.');
        System.assertEquals('phone1', String.valueOf(((Map<String, Object>) ((List<Object>) accountLookup.get('setFields'))[0]).get('targetFieldKey')), 'Lookup definition should publish copy-to form field keys.');

        Map<String, Object> userVerificationConfig = (Map<String, Object>) registerPayload.get('userVerificationConfig');
        System.assertEquals(true, userVerificationConfig.get('enabled'), 'Register payload should include User Verification settings when enabled.');
        System.assertEquals('Email', String.valueOf(userVerificationConfig.get('matchField')), 'Register payload should preserve the configured User Verification match field.');
        System.assertEquals('short', String.valueOf(userVerificationConfig.get('sessionMode')), 'User Verification sessions should default to short mode.');
        System.assertEquals('sender@example.com', String.valueOf(userVerificationConfig.get('senderEmail')), 'Register payload should include the User Verification sender email.');
        Map<String, Object> submissionPdfConfig = (Map<String, Object>) registerPayload.get('submissionPdf');
        System.assertEquals(true, submissionPdfConfig.get('rtlEnabled'), 'Submission PDF config should preserve the form RTL setting.');
        List<Object> submissionPdfSchema = (List<Object>) submissionPdfConfig.get('schema');
        Boolean foundMultiCheckboxSchema = false;
        Boolean foundHiddenCaseIdSchema = false;
        Boolean foundMergedDocumentSchema = false;
        for (Object schemaValue : submissionPdfSchema) {
            Map<String, Object> schemaItem = (Map<String, Object>) schemaValue;
            if (String.valueOf(schemaItem.get('fieldKey')) == 'needs1') {
                foundMultiCheckboxSchema = true;
                System.assertEquals('multiCheckbox', String.valueOf(schemaItem.get('type')), 'Submission PDF schema should preserve Multi Checkbox type.');
                System.assertEquals(2, ((List<Object>) schemaItem.get('options')).size(), 'Submission PDF schema should include Multi Checkbox option labels.');
            }
            if (String.valueOf(schemaItem.get('type')) == 'mergedDocument') {
                foundMergedDocumentSchema = true;
                System.assert(String.valueOf(schemaItem.get('text')).contains('{{PrefilAccount.Name}}'), 'Submission PDF schema should preserve Merged Document token text for runtime resolution.');
            }
            if (String.valueOf(schemaItem.get('fieldKey')) == 'caseId') {
                foundHiddenCaseIdSchema = true;
            }
        }
        System.assertEquals(true, foundMultiCheckboxSchema, 'Submission PDF schema should include top-level Multi Checkbox fields.');
        System.assertEquals(true, foundMergedDocumentSchema, 'Submission PDF schema should include Merged Document fields.');
        System.assertEquals(false, foundHiddenCaseIdSchema, 'Submission PDF schema should exclude fields with hidden behavior.');

        List<Object> uploadFields = (List<Object>) registerPayload.get('uploadFields');
        System.assertEquals(1, uploadFields.size(), 'Register payload should expose upload field metadata for file-upload controls.');
        List<Object> signatureFields = (List<Object>) registerPayload.get('signatureFields');
        System.assertEquals(1, signatureFields.size(), 'Register payload should expose signature field metadata for signature controls.');
        List<Object> rowSignatureConfigs = (List<Object>) registerPayload.get('recordsListRowSignatures');
        System.assertEquals(1, rowSignatureConfigs.size(), 'Register payload should expose records-list row signature metadata.');
        Map<String, Object> rowSignatureConfig = (Map<String, Object>) rowSignatureConfigs[0];
        System.assertEquals('recordsList', String.valueOf(rowSignatureConfig.get('groupKey')), 'Row signature config should identify the records-list group key.');
        System.assertEquals(true, rowSignatureConfig.get('required'), 'Row signature config should preserve required mode.');
        System.assertEquals(true, rowSignatureConfig.get('attachToRowRecord'), 'Row signature config should preserve child-row file attachment mode.');

        Map<String, Object> prefillDefinition = (Map<String, Object>) registerPayload.get('prefillDefinition');
        List<Object> prefillCommands = (List<Object>) prefillDefinition.get('commands');
        System.assertEquals(2, prefillCommands.size(), 'Prefill definition should include field and Merged Document alias references.');
        Boolean foundMergedDocumentPrefillAlias = false;
        Boolean foundVerifiedEmailContactPrefill = false;
        for (Object prefillCommandValue : prefillCommands) {
            Map<String, Object> prefillCommand = (Map<String, Object>) prefillCommandValue;
            if (String.valueOf(prefillCommand.get('storeResultAs')) == 'PrefilAccount') {
                foundMergedDocumentPrefillAlias = true;
            }
            if (String.valueOf(prefillCommand.get('storeResultAs')) == 'PrefilContact') {
                foundVerifiedEmailContactPrefill = String.valueOf(prefillCommand.get('whereClause')).contains('{params.email}');
            }
        }
        System.assertEquals(true, foundMergedDocumentPrefillAlias, 'Merged Document tokens should keep their referenced prefill aliases.');
        System.assertEquals(true, foundVerifiedEmailContactPrefill, 'Verified Email prefill source should publish as the trusted verified email runtime parameter.');

        Map<String, Object> submitDefinition = (Map<String, Object>) registerPayload.get('submitDefinition');
        List<Object> submitCommands = (List<Object>) submitDefinition.get('commands');
        System.assertEquals(5, submitCommands.size(), 'Submit definition should include field-mapped commands plus the Submission PDF target action.');
        Map<String, Object> updateContactCommand;
        Map<String, Object> createContactCommand;
        Map<String, Object> upsertCasesCommand;
        Map<String, Object> pdfTargetFindCommand;
        for (Object commandValue : submitCommands) {
            Map<String, Object> command = (Map<String, Object>) commandValue;
            if (String.valueOf(command.get('commandKey')) == 'submitAction1') {
                updateContactCommand = command;
            }
            if (String.valueOf(command.get('commandKey')) == 'submitAction1_create') {
                createContactCommand = command;
            }
            if (String.valueOf(command.get('commandKey')) == 'submitAction2') {
                upsertCasesCommand = command;
            }
            if (String.valueOf(command.get('commandKey')) == 'submitAction3_find') {
                pdfTargetFindCommand = command;
            }
        }
        System.assertNotEquals(null, upsertCasesCommand, 'Records List submit commands should publish.');
        System.assertEquals('caseId', String.valueOf(upsertCasesCommand.get('idField')), 'Records List submit should use the prefilled row Id field to update existing rows.');
        System.assertEquals(false, ((Map<String, Object>) upsertCasesCommand.get('fields')).containsKey('Id'), 'Records List submit should not try to write Salesforce Id as a normal field.');
        System.assertNotEquals(null, pdfTargetFindCommand, 'Submission PDF target-only actions should publish their find command.');
        System.assertEquals('SubmitPdfContact', String.valueOf(pdfTargetFindCommand.get('storeResultAs')), 'PDF target find command should preserve its result alias.');
        Map<String, Object> updateFields = (Map<String, Object>) updateContactCommand.get('fields');
        Map<String, Object> updateCreateOnlyFields = (Map<String, Object>) updateContactCommand.get('createOnlyFields');
        Map<String, Object> createFields = (Map<String, Object>) createContactCommand.get('fields');
        System.assertEquals(false, updateFields.containsKey('AccountId'), 'Create-only mapped fields should not be sent to update.');
        System.assertEquals('{input.accountId}', String.valueOf(updateCreateOnlyFields.get('AccountId')), 'Update commands should carry create-only fields for fallback create.');
        System.assertEquals('{input.accountId}', String.valueOf(createFields.get('AccountId')), 'Create commands should submit create-only fields normally.');

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
        System.assertEquals(31, successorElementCount, 'Successor draft should clone all publishable elements including Blank Space, Merged Document, survey fields, Portal Buttons, row Lookup, row Formula, and row Signature.');
        System.assertEquals(5, successorActionCount, 'Successor draft should clone all configured actions.');
        }
    }

    @IsTest
    static void publishFailureCreatesFailurePublicationAndFriendlyMessage() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
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
    }

    @IsTest
    static void publishLocalizesDefaultSignatureLabel() {
        System.runAs(new User(Id = UserInfo.getUserId())) {
        setAllProFlagsEnabled();
        PublisherCalloutMock mock = new PublisherCalloutMock();
        Test.setMock(HttpCalloutMock.class, mock);

        NF_Form_Version__c version = createBaseVersion(
            'Hebrew Signature Form',
            'hebrew-signature-form',
            'Draft',
            'Never Published',
            false,
            NativeFormsTestConfigFactory.json(new Map<String, Object>{
                'languageCode' => 'he',
                'rtlEnabled' => true,
                'submitLabel' => '\u05E9\u05DC\u05D7',
                'submitSuccessMessage' => '\u05D4\u05D8\u05D5\u05E4\u05E1 \u05E0\u05E9\u05DC\u05D7 \u05D1\u05D4\u05E6\u05DC\u05D7\u05D4'
            })
        );
        NativeFormsTestDataFactory.createElement(
            version.Id,
            'signature',
            'Signature',
            'signature1',
            1,
            10,
            NativeFormsTestConfigFactory.signatureConfigJson(null),
            null
        );

        Test.startTest();
        NativeFormsPublisher.PublishResult result = NativeFormsPublisher.publishVersion(version.Id);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Publish should succeed for a Hebrew signature form.');
        System.assert(
            mock.uploadedHtml.contains('<label for="signature1-canvas">\u05D7\u05EA\u05D9\u05DE\u05D4</label>'),
            'Published HTML should localize the default Signature element label.'
        );
        }
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
            Logo_URL__c = 'https://example.com/theme-logo.png',
            Background_Image_URL__c = 'https://example.com/theme-background.png',
            Footer_Image_URL__c = 'https://example.com/theme-footer.png',
            Title_Font__c = 'Rubik',
            Section_Title_Font__c = 'Assistant',
            Main_Font__c = 'Heebo',
            Button_Font__c = 'Inter',
            Background_Color__c = '#229922',
            Background_Gradient_Color__c = '#229922'
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
            'postSubmitAutoLinkEnabled' => true,
            'postSubmitUrlMode' => 'formula',
            'postSubmitUrlFormula' => 'IF({email1} != "", CONCAT("https://example.com/thanks?email=", URLENCODE({email1})), "")',
            'userVerificationEnabled' => true,
            'userVerificationMatchField' => 'Email',
            'userVerificationIntroText' => 'Enter your email to continue.',
            'userVerificationSentMessage' => 'We sent a code.',
            'userVerificationInvalidMessage' => 'Invalid code.',
            'userVerificationVerifiedMessage' => 'Code verified.',
            'userVerificationSendButtonLabel' => 'Send Code',
            'userVerificationVerifyButtonLabel' => 'Verify Code',
            'userVerificationResendButtonLabel' => 'Resend Verification Number',
            'userVerificationSenderEmail' => 'sender@example.com',
            'submissionPdfEnabled' => true,
            'submissionPdfAttachToRecord' => true,
            'submissionPdfTargetSubmitActionKey' => 'submitAction3',
            'submissionPdfTitle' => 'Submitted Response',
            'submissionPdfIncludeEmptyFields' => true,
            'rtlEnabled' => true
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
                        'valueSource' => 'verifiedEmail',
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
            'Prefill',
            'Account',
            'prefillAction2',
            'PrefilAccount',
            'findOne',
            15,
            json(new Map<String, Object>{
                'conditions' => new List<Object>{
                    new Map<String, Object>{
                        'fieldApiName' => 'Id',
                        'operator' => 'eq',
                        'valueSource' => 'param',
                        'valueText' => 'accountId'
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
        NativeFormsTestDataFactory.createAction(
            versionRecord.Id,
            'Submit',
            'Contact',
            'submitAction3',
            'SubmitPdfContact',
            'findAndUpdate',
            35,
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
                'onNotFound' => 'error'
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
                'columns' => 10,
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
                'columns' => 1,
                'fieldBehavior' => 'hidden'
            }),
            section.Element_Id__c
        );

        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'heading', 'Display Text', 'displayText1', 3, 30, withSectionColumn(json(new Map<String, Object>{ 'html' => '<p><a href="https://twinaforms.com/help/formulas">Learn more</a></p>' }), 1), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'spacer', 'Blank Space', null, 30, 32, withSectionColumn(json(new Map<String, Object>{ 'spacerSize' => 'fieldWithLabel' }), 1), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'mergedDocument', 'Merged Document', 'mergedDocument1', 29, 35, withSectionColumn(json(new Map<String, Object>{ 'html' => '<p>I, {{PrefilContact.FirstName}} from {{PrefilAccount.Name}}, agree.</p>' }), 1), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'image', 'Hero Image', 'image1', 4, 40, withSectionColumn(json(new Map<String, Object>{ 'contentVersionId' => String.valueOf(imageVersion.Id), 'altText' => 'Hero image', 'imageFit' => 'center', 'imageWidthPercent' => 50 }), 2), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'email', 'Email', 'email1', 5, 50, withSectionColumn(fieldConfig('above', false, true, 'PrefilContact', 'Email', true, 'submitAction1', 'Email'), 1), groupElement.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'tel', 'Phone', 'phone1', 6, 60, withSectionColumn(fieldConfig('above', false, false, null, null, true, 'submitAction1', 'Phone'), 1), groupElement.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'lookup', 'Account', 'accountId', 22, 65, withSectionColumn(json(new Map<String, Object>{
            'labelPosition' => 'above',
            'fieldBehavior' => 'readonlyWhenPrefilled',
            'lookupTargetObject' => 'Account',
            'lookupDisplayFields' => new List<Object>{ 'Name' },
            'lookupSearchFields' => new List<Object>{ 'Name' },
            'lookupSetFields' => new List<Object>{
                new Map<String, Object>{ 'sourceField' => 'Phone', 'targetFieldKey' => 'phone1' }
            },
            'submitEnabled' => true,
            'submitActionKey' => 'submitAction1',
            'submitFieldPath' => 'AccountId',
            'submitWhen' => 'create'
        }), 1), groupElement.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'date', 'Start Date', 'date1', 7, 70, withSectionColumn(json(new Map<String, Object>{ 'labelPosition' => 'above', 'fieldBehavior' => 'editable', 'dateFormat' => 'us', 'minDate' => '2026-01-01', 'maxDate' => '2026-12-31' }), 2), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'time', 'Start Time', 'time1', 19, 75, withSectionColumn(json(new Map<String, Object>{ 'labelPosition' => 'above', 'fieldBehavior' => 'editable', 'defaultValue' => '09:30', 'placeholder' => '19:00', 'timeFormat' => '24h' }), 2), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'checkbox', 'Accept Terms', 'checkbox1', 8, 80, withSectionColumn(NativeFormsTestConfigFactory.checkboxConfigJson(false), 1), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'text', 'Formula Text', 'formulaText1', 9, 90, withSectionColumn(NativeFormsTestConfigFactory.formulaFieldConfigJson('IF({checkbox1} == true, "Yes", "No")'), 2), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'textarea', 'Notes', 'notes1', 10, 100, withSectionColumn(json(new Map<String, Object>{ 'labelPosition' => 'above', 'fieldBehavior' => 'editable', 'rows' => 4, 'maxLength' => 254 }), 1), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'url', 'Website', 'website1', 11, 110, withSectionColumn(json(new Map<String, Object>{ 'labelPosition' => 'above', 'fieldBehavior' => 'editable', 'placeholderText' => 'https://example.com' }), 2), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'select', 'Priority', 'priority1', 12, 120, withSectionColumn(optionFieldConfig('above', selectOptions()), 1), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'multiCheckbox', 'Needs', 'needs1', 23, 125, withSectionColumn(json(new Map<String, Object>{
            'labelPosition' => 'above',
            'fieldBehavior' => 'editable',
            'defaultValue' => 'low;high',
            'required' => true,
            'options' => selectOptions(),
            'prefillEnabled' => true,
            'prefillAlias' => 'PrefilContact',
            'prefillFieldPath' => 'Needs__c',
            'submitEnabled' => true,
            'submitActionKey' => 'submitAction1',
            'submitFieldPath' => 'Needs__c'
        }), 1), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'radio', 'Title', 'title1', 13, 130, withSectionColumn(optionFieldConfig('above', radioOptions()), 2), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'radio', 'Satisfaction', 'rating1', 28, 135, withSectionColumn(json(new Map<String, Object>{
            'labelPosition' => 'above',
            'fieldBehavior' => 'editable',
            'presentation' => 'stars',
            'options' => starRatingOptions(),
            'defaultValue' => '5'
        }), 2), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'fileUpload', 'Attachment', 'file1', 14, 140, withSectionColumn(json(new Map<String, Object>{ 'labelPosition' => 'above', 'allowMultiple' => true, 'allowedExtensions' => 'pdf,png', 'maxFileSizeMb' => 10, 'targetSubmitActionKey' => 'submitAction1' }), 1), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'signature', 'Signature', 'signature1', 21, 145, withSectionColumn(NativeFormsTestConfigFactory.signatureConfigJson('submitAction1'), 2), section.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'button', 'View Request', null, 25, 147, withSectionColumn(json(new Map<String, Object>{
            'destinationType' => 'external',
            'externalUrlMode' => 'template',
            'externalUrlTemplate' => 'https://portal.example.com/request',
            'externalUrlFormula' => '',
            'queryParameters' => new List<Object>{
                new Map<String, Object>{
                    'name' => 'email',
                    'valueMode' => 'template',
                    'valueTemplate' => '{{field.email1}}',
                    'valueFormula' => ''
                }
            },
            'submitBeforeNavigation' => true
        }), 1), section.Element_Id__c);

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
                'allowDeleteRows' => true,
                'showLabelsOnEachRow' => false
            }),
            null
        );
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'text', 'Case Subject', 'subject', 16, 160, withSectionColumn(fieldConfig('above', false, true, 'PrefilCase', 'Subject', true, 'submitAction2', 'Subject'), 1), repeatGroup.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'signature', 'Row Signature', 'rowSignature', 27, 165, withSectionColumn(json(new Map<String, Object>{
            'labelPosition' => 'above',
            'required' => true,
            'helpText' => '',
            'clearButtonLabel' => 'Clear',
            'targetSubmitActionKey' => '',
            'attachToRowRecord' => true
        }), 2), repeatGroup.Element_Id__c);
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
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'multiCheckbox', 'Case Needs', 'caseNeeds', 24, 175, withSectionColumn(json(new Map<String, Object>{
            'labelPosition' => 'above',
            'options' => selectOptions(),
            'prefillEnabled' => true,
            'prefillAlias' => 'PrefilCase',
            'prefillFieldPath' => 'Needs__c',
            'submitEnabled' => true,
            'submitActionKey' => 'submitAction2',
            'submitFieldPath' => 'Needs__c'
        }), 2), repeatGroup.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'lookup', 'Case Account', 'caseAccountId', 30, 176, withSectionColumn(json(new Map<String, Object>{
            'labelPosition' => 'above',
            'lookupTargetObject' => 'Account',
            'lookupDisplayFields' => new List<Object>{ 'Name' },
            'lookupSearchFields' => new List<Object>{ 'Name' },
            'lookupSetFields' => new List<Object>{
                new Map<String, Object>{ 'sourceField' => 'Name', 'targetFieldKey' => 'subject' }
            },
            'lookupMinSearchLength' => 2,
            'lookupLimit' => 10,
            'prefillEnabled' => true,
            'prefillAlias' => 'PrefilCase',
            'prefillFieldPath' => 'AccountId',
            'submitEnabled' => true,
            'submitActionKey' => 'submitAction2',
            'submitFieldPath' => 'AccountId'
        }), 1), repeatGroup.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'text', 'Case Summary', 'caseSummary', 31, 178, withSectionColumn(json(new Map<String, Object>{
            'labelPosition' => 'above',
            'isFormula' => true,
            'formulaExpression' => 'CONCAT({email1}, " - ", {row.subject})',
            'submitEnabled' => true,
            'submitActionKey' => 'submitAction2',
            'submitFieldPath' => 'Description'
        }), 1), repeatGroup.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'text', 'Case Id', 'caseId', 18, 180, withSectionColumn(json(new Map<String, Object>{
            'labelPosition' => 'above',
            'fieldBehavior' => 'hidden',
            'prefillEnabled' => true,
            'prefillAlias' => 'PrefilCase',
            'prefillFieldPath' => 'Id',
            'submitEnabled' => false,
            'submitActionKey' => 'submitAction2',
            'submitFieldPath' => 'Id'
        }), 2), repeatGroup.Element_Id__c);
        NativeFormsTestDataFactory.createElement(versionRecord.Id, 'button', 'Open Case', null, 26, 190, withSectionColumn(json(new Map<String, Object>{
            'destinationType' => 'external',
            'externalUrlMode' => 'template',
            'externalUrlTemplate' => 'https://portal.example.com/case',
            'externalUrlFormula' => '',
            'queryParameters' => new List<Object>{
                new Map<String, Object>{
                    'name' => 'caseId',
                    'valueMode' => 'template',
                    'valueTemplate' => '{{row.caseId}}',
                    'valueFormula' => ''
                }
            },
            'submitBeforeNavigation' => false
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

    private static Boolean listContainsIgnoreCase(List<Object> values, String expectedValue) {
        for (Object value : values) {
            if (String.valueOf(value).equalsIgnoreCase(expectedValue)) {
                return true;
            }
        }
        return false;
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

    private static List<Object> starRatingOptions() {
        return new List<Object>{
            new Map<String, Object>{ 'label' => 'star 1', 'value' => '1' },
            new Map<String, Object>{ 'label' => 'stars 2', 'value' => '2' },
            new Map<String, Object>{ 'label' => 'stars 3', 'value' => '3' },
            new Map<String, Object>{ 'label' => 'stars 4', 'value' => '4' },
            new Map<String, Object>{ 'label' => 'stars 5', 'value' => '5' }
        };
    }
}
