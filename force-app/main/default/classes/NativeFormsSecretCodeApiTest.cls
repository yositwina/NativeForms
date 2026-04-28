@IsTest
private class NativeFormsSecretCodeApiTest {
    @IsTest
    static void requestValidationAndDisabledFormFailuresWork() {
        NF_Form_Version__c secretDisabledVersion = createVersionWithSecretCode(false, NativeFormsTestConfigFactory.basicUiSettingsJson());

        NativeFormsSecretCodeApi.ResponsePayload missingAction = invoke(new Map<String, Object>{
            'publishedVersionId' => secretDisabledVersion.Id,
            'email' => 'user@example.com'
        });
        System.assertEquals(false, missingAction.success, 'Missing action should return an error response.');
        System.assertEquals('Missing required field: action', missingAction.message, 'Missing action should surface a clear validation message.');
        System.assertEquals(400, RestContext.response.statusCode, 'Missing action should set a 400 status code.');

        NativeFormsSecretCodeApi.ResponsePayload unsupportedAction = invoke(new Map<String, Object>{
            'action' => 'mystery',
            'publishedVersionId' => secretDisabledVersion.Id,
            'email' => 'user@example.com'
        });
        System.assertEquals(false, unsupportedAction.success, 'Unsupported actions should return an error response.');
        System.assertEquals('Unsupported action: mystery', unsupportedAction.message, 'Unsupported action should surface the unsupported value.');
        System.assertEquals(400, RestContext.response.statusCode, 'Unsupported action should set a 400 status code.');

        NativeFormsSecretCodeApi.ResponsePayload missingVersion = invoke(new Map<String, Object>{
            'action' => 'sendCode',
            'email' => 'user@example.com'
        });
        System.assertEquals(false, missingVersion.success, 'Missing publishedVersionId should return an error response.');
        System.assertEquals('Missing required field: publishedVersionId', missingVersion.message, 'Missing publishedVersionId should surface a validation message.');
        System.assertEquals(400, RestContext.response.statusCode, 'Missing publishedVersionId should set a 400 status code.');

        NativeFormsSecretCodeApi.ResponsePayload missingEmail = invoke(new Map<String, Object>{
            'action' => 'sendCode',
            'publishedVersionId' => secretDisabledVersion.Id
        });
        System.assertEquals(false, missingEmail.success, 'Missing email should return an error response.');
        System.assertEquals('Missing required field: email', missingEmail.message, 'Missing email should surface a validation message.');
        System.assertEquals(400, RestContext.response.statusCode, 'Missing email should set a 400 status code.');

        NativeFormsSecretCodeApi.ResponsePayload disabledResponse = invoke(new Map<String, Object>{
            'action' => 'sendCode',
            'publishedVersionId' => secretDisabledVersion.Id,
            'email' => 'user@example.com'
        });
        System.assertEquals(false, disabledResponse.success, 'Secret-code-disabled forms should return an error response.');
        System.assertEquals('Secret code verification is not enabled for this form.', disabledResponse.message, 'Disabled forms should return the feature-disabled message.');
        System.assertEquals(403, RestContext.response.statusCode, 'Disabled forms should set a 403 status code.');
    }

    @IsTest
    static void sendCodeHandlesMissingContactsSafely() {
        NF_Form_Version__c enabledVersion = createVersionWithSecretCode(true, secretEnabledUiSettingsJson());

        NativeFormsSecretCodeApi.ResponsePayload noMatchResponse = invoke(new Map<String, Object>{
            'action' => 'sendCode',
            'publishedVersionId' => enabledVersion.Id,
            'email' => 'missing@example.com'
        });
        System.assertEquals(true, noMatchResponse.success, 'No-contact sendCode requests should still return success.');
        System.assertEquals(true, noMatchResponse.verificationRequired, 'No-contact sendCode should still require verification.');
        System.assertEquals(false, noMatchResponse.emailSent, 'No-contact sendCode should not send an email.');
        System.assertEquals('missing@example.com', noMatchResponse.normalizedEmail, 'No-contact sendCode should normalize the email to lowercase.');
        System.assertEquals('If we found a matching contact, a code was sent.', noMatchResponse.message, 'No-contact sendCode should keep the privacy-safe message.');
    }

    @IsTest
    static void sendCodeReturnsExplicitEmailFailureMessage() {
        NF_Form_Version__c enabledVersion = createVersionWithSecretCode(true, secretEnabledUiSettingsJson());
        createContact('mail.failure@example.com');

        NativeFormsSecretCodeApi.forcedEmailFailureMessageForTest = 'TwinaForms could not send the verification email right now.';
        try {
            NativeFormsSecretCodeApi.ResponsePayload failureResponse = invoke(new Map<String, Object>{
                'action' => 'sendCode',
                'publishedVersionId' => enabledVersion.Id,
                'email' => 'mail.failure@example.com'
            });
            System.assertEquals(false, failureResponse.success, 'Forced email failures should return an error response.');
            System.assertEquals('TwinaForms could not send the verification email right now.', failureResponse.message, 'Forced email failures should surface the real email-send message.');
            System.assertEquals(500, RestContext.response.statusCode, 'Forced email failures should set a 500 status code.');
        } finally {
            NativeFormsSecretCodeApi.forcedEmailFailureMessageForTest = null;
        }
    }

    @IsTest
    static void sendCodeStoresSecretAndVerifyHandlesSuccessInvalidExpiredAndLockout() {
        NF_Form_Version__c enabledVersion = createVersionWithSecretCode(true, secretEnabledUiSettingsJson());
        Contact target = createContact('qa.secret@example.com');

        NativeFormsSecretCodeApi.ResponsePayload sendResponse = invoke(new Map<String, Object>{
            'action' => 'sendCode',
            'publishedVersionId' => enabledVersion.Id,
            'email' => 'QA.SECRET@example.com',
            'expiryMinutes' => 15,
            'maxAttempts' => 3
        });
        System.assertEquals(true, sendResponse.success, 'Matching-contact sendCode should succeed.');
        System.assertEquals(true, sendResponse.verificationRequired, 'Matching-contact sendCode should require verification.');
        System.assertEquals(true, sendResponse.emailSent, 'Matching-contact sendCode should send an email.');
        System.assertEquals('qa.secret@example.com', sendResponse.normalizedEmail, 'Matching-contact sendCode should normalize the email.');

        target = [
            SELECT NativeForms_Secret_Code__c,
                   NativeForms_Secret_Code_Expires_At__c,
                   NativeForms_Secret_Code_Attempts__c,
                   NativeForms_Secret_Code_Verified_At__c
            FROM Contact
            WHERE Id = :target.Id
        ];
        System.assertEquals(6, String.valueOf(target.NativeForms_Secret_Code__c).length(), 'sendCode should store a six-digit secret code.');
        System.assert(target.NativeForms_Secret_Code_Expires_At__c > System.now(), 'sendCode should store a future expiry timestamp.');
        System.assertEquals(0, Integer.valueOf(target.NativeForms_Secret_Code_Attempts__c), 'sendCode should reset attempts to zero.');
        System.assertEquals(null, target.NativeForms_Secret_Code_Verified_At__c, 'sendCode should clear any previous verified timestamp.');

        NativeFormsSecretCodeApi.ResponsePayload invalidResponse = invoke(new Map<String, Object>{
            'action' => 'verifyCode',
            'publishedVersionId' => enabledVersion.Id,
            'email' => 'qa.secret@example.com',
            'code' => '999999',
            'maxAttempts' => 3
        });
        System.assertEquals(true, invalidResponse.success, 'Invalid code responses should still be successful API responses.');
        System.assertEquals(false, invalidResponse.approved, 'Invalid code should not be approved.');
        System.assertEquals(true, invalidResponse.verificationRequired, 'Invalid code should keep verification required.');
        System.assertEquals('The verification code is invalid.', invalidResponse.message, 'Invalid code should return the invalid-code message.');

        target = [SELECT NativeForms_Secret_Code_Attempts__c FROM Contact WHERE Id = :target.Id];
        System.assertEquals(1, Integer.valueOf(target.NativeForms_Secret_Code_Attempts__c), 'Invalid code should increment attempts.');

        target = [
            SELECT NativeForms_Secret_Code__c
            FROM Contact
            WHERE Id = :target.Id
        ];
        NativeFormsSecretCodeApi.ResponsePayload approvedResponse = invoke(new Map<String, Object>{
            'action' => 'verifyCode',
            'publishedVersionId' => enabledVersion.Id,
            'email' => 'qa.secret@example.com',
            'code' => target.NativeForms_Secret_Code__c,
            'maxAttempts' => 3
        });
        System.assertEquals(true, approvedResponse.success, 'Correct code should succeed.');
        System.assertEquals(true, approvedResponse.approved, 'Correct code should be approved.');
        System.assertEquals(false, approvedResponse.verificationRequired, 'Correct code should clear verification required.');
        System.assertEquals('Code verified successfully.', approvedResponse.message, 'Correct code should return the approved message.');

        target = [
            SELECT NativeForms_Secret_Code_Verified_At__c
            FROM Contact
            WHERE Id = :target.Id
        ];
        System.assertNotEquals(null, target.NativeForms_Secret_Code_Verified_At__c, 'Correct code should stamp the verified timestamp.');

        Contact expiredTarget = createContact('expired.secret@example.com');
        update new Contact(
            Id = expiredTarget.Id,
            NativeForms_Secret_Code__c = '123456',
            NativeForms_Secret_Code_Expires_At__c = System.now().addMinutes(-5),
            NativeForms_Secret_Code_Attempts__c = 0
        );

        NativeFormsSecretCodeApi.ResponsePayload expiredResponse = invoke(new Map<String, Object>{
            'action' => 'verifyCode',
            'publishedVersionId' => enabledVersion.Id,
            'email' => 'expired.secret@example.com',
            'code' => '123456',
            'maxAttempts' => 3
        });
        System.assertEquals(true, expiredResponse.success, 'Expired-code responses should still be successful API responses.');
        System.assertEquals(true, expiredResponse.expired, 'Expired code should mark the response as expired.');
        System.assertEquals('The verification code expired. Request a new code and try again.', expiredResponse.message, 'Expired code should return the expired-code message.');

        Contact lockedTarget = createContact('locked.secret@example.com');
        update new Contact(
            Id = lockedTarget.Id,
            NativeForms_Secret_Code__c = '654321',
            NativeForms_Secret_Code_Expires_At__c = System.now().addMinutes(5),
            NativeForms_Secret_Code_Attempts__c = 2
        );

        NativeFormsSecretCodeApi.ResponsePayload lockoutOnAttempt = invoke(new Map<String, Object>{
            'action' => 'verifyCode',
            'publishedVersionId' => enabledVersion.Id,
            'email' => 'locked.secret@example.com',
            'code' => '000000',
            'maxAttempts' => 3
        });
        System.assertEquals(true, lockoutOnAttempt.success, 'Lockout-on-attempt should still be a successful API response.');
        System.assertEquals(true, lockoutOnAttempt.lockedOut, 'Hitting the max attempts should lock out the contact.');
        System.assertEquals('Too many attempts. Request a new code and try again.', lockoutOnAttempt.message, 'Lockout-on-attempt should return the lockout message.');

        lockedTarget = [SELECT NativeForms_Secret_Code_Attempts__c FROM Contact WHERE Id = :lockedTarget.Id];
        System.assertEquals(3, Integer.valueOf(lockedTarget.NativeForms_Secret_Code_Attempts__c), 'Lockout-on-attempt should persist the incremented attempt count.');

        update new Contact(
            Id = lockedTarget.Id,
            NativeForms_Secret_Code_Attempts__c = 3
        );
        NativeFormsSecretCodeApi.ResponsePayload alreadyLockedResponse = invoke(new Map<String, Object>{
            'action' => 'verifyCode',
            'publishedVersionId' => enabledVersion.Id,
            'email' => 'locked.secret@example.com',
            'code' => '654321',
            'maxAttempts' => 3
        });
        System.assertEquals(true, alreadyLockedResponse.success, 'Already-locked responses should still be successful API responses.');
        System.assertEquals(true, alreadyLockedResponse.lockedOut, 'Already-locked contacts should stay locked.');
        System.assertEquals('Too many attempts. Request a new code and try again.', alreadyLockedResponse.message, 'Already-locked contacts should return the lockout message.');
    }

    private static NativeFormsSecretCodeApi.ResponsePayload invoke(Map<String, Object> payload) {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/nativeforms/secret-code';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf(JSON.serialize(payload == null ? new Map<String, Object>() : payload));

        RestContext.request = request;
        RestContext.response = new RestResponse();

        return NativeFormsSecretCodeApi.handlePost();
    }

    private static NF_Form_Version__c createVersionWithSecretCode(Boolean enabled, String uiSettingsJson) {
        NF_Form__c formRecord = NativeFormsTestDataFactory.createForm('Secret Code Form', null, 'secret-code-form');
        NF_Form_Version__c versionRecord = NativeFormsTestDataFactory.createVersion(
            formRecord.Id,
            1,
            'Draft',
            'Never Published',
            String.isBlank(uiSettingsJson) ? secretEnabledUiSettingsJson() : uiSettingsJson
        );
        NativeFormsTestDataFactory.assignCurrentVersions(formRecord.Id, versionRecord.Id, null);

        if (enabled != true) {
            update new NF_Form_Version__c(
                Id = versionRecord.Id,
                UI_Settings_JSON__c = JSON.serialize(new Map<String, Object>{
                    'languageCode' => 'en',
                    'secretCodeVerificationEnabled' => false
                })
            );
        }

        return [
            SELECT Id, UI_Settings_JSON__c
            FROM NF_Form_Version__c
            WHERE Id = :versionRecord.Id
        ];
    }

    private static Contact createContact(String emailValue) {
        Contact contactRecord = new Contact(
            FirstName = 'Secret',
            LastName = 'Tester ' + emailValue,
            Email = emailValue
        );
        insert contactRecord;
        return [
            SELECT Id, Email
            FROM Contact
            WHERE Id = :contactRecord.Id
        ];
    }

    private static String secretEnabledUiSettingsJson() {
        return JSON.serialize(new Map<String, Object>{
            'languageCode' => 'en',
            'secretCodeVerificationEnabled' => true,
            'secretCodeMatchField' => 'Email',
            'secretCodeIntroText' => 'Enter your email and continue.'
        });
    }
}
