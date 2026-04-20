@RestResource(urlMapping='/nativeforms/secret-code')
global with sharing class NativeFormsSecretCodeApi {
    private static final Integer DEFAULT_EXPIRY_MINUTES = 10;
    private static final Integer DEFAULT_MAX_ATTEMPTS = 5;
    private static final String TEMPLATE_DEVELOPER_NAME = 'NativeForms_Secret_Code_Default';

    global class RequestPayload {
        public String action;
        public Id publishedVersionId;
        public String email;
        public String code;
        public Integer expiryMinutes;
        public Integer maxAttempts;
    }

    global class ResponsePayload {
        public Boolean success;
        public Boolean approved;
        public Boolean emailSent;
        public Boolean verificationRequired;
        public Boolean lockedOut;
        public Boolean expired;
        public String message;
        public String normalizedEmail;
    }

    @HttpPost
    global static ResponsePayload handlePost() {
        try {
            RequestPayload payload = (RequestPayload) JSON.deserialize(
                RestContext.request.requestBody == null ? '{}' : RestContext.request.requestBody.toString(),
                RequestPayload.class
            );
            if (payload == null || String.isBlank(payload.action)) {
                throw buildHandledException('Missing required field: action', 400);
            }

            if (payload.action == 'sendCode') {
                return startVerification(payload);
            }
            if (payload.action == 'verifyCode') {
                return verifyCode(payload);
            }

            throw buildHandledException('Unsupported action: ' + payload.action, 400);
        } catch (Exception unexpected) {
            RestContext.response.statusCode = RestContext.response.statusCode == 0
                ? 500
                : RestContext.response.statusCode;
            return errorResponse(unexpected.getMessage());
        }
    }

    private static ResponsePayload startVerification(RequestPayload payload) {
        NormalizedRequest normalized = normalizeRequest(payload);
        ResponsePayload response = baseResponse();
        response.verificationRequired = true;
        response.normalizedEmail = normalized.email;
        response.message = 'If we found a matching contact, a code was sent.';

        Contact target = findExactlyOneContactByEmail(normalized.email);
        if (target == null) {
            return response;
        }

        String code = generateSixDigitCode();
        Datetime expiresAt = System.now().addMinutes(normalized.expiryMinutes);
        target.NativeForms_Secret_Code__c = code;
        target.NativeForms_Secret_Code_Expires_At__c = expiresAt;
        target.NativeForms_Secret_Code_Attempts__c = 0;
        target.NativeForms_Secret_Code_Verified_At__c = null;
        update target;

        sendSecretCodeEmail(target);

        response.emailSent = true;
        return response;
    }

    private static ResponsePayload verifyCode(RequestPayload payload) {
        NormalizedRequest normalized = normalizeRequest(payload);
        ResponsePayload response = baseResponse();
        response.verificationRequired = true;
        response.normalizedEmail = normalized.email;
        response.message = 'The verification code is invalid.';

        Contact target = findExactlyOneContactByEmail(normalized.email);
        if (target == null) {
            return response;
        }

        Integer attempts = target.NativeForms_Secret_Code_Attempts__c == null
            ? 0
            : Integer.valueOf(target.NativeForms_Secret_Code_Attempts__c);
        if (attempts >= normalized.maxAttempts) {
            response.lockedOut = true;
            response.message = 'Too many attempts. Request a new code and try again.';
            return response;
        }

        if (target.NativeForms_Secret_Code_Expires_At__c == null || target.NativeForms_Secret_Code_Expires_At__c < System.now()) {
            response.expired = true;
            response.message = 'The verification code expired. Request a new code and try again.';
            return response;
        }

        if (String.isBlank(normalized.code) || target.NativeForms_Secret_Code__c != normalized.code) {
            target.NativeForms_Secret_Code_Attempts__c = attempts + 1;
            update target;
            if ((attempts + 1) >= normalized.maxAttempts) {
                response.lockedOut = true;
                response.message = 'Too many attempts. Request a new code and try again.';
            }
            return response;
        }

        target.NativeForms_Secret_Code_Verified_At__c = System.now();
        update target;

        response.approved = true;
        response.verificationRequired = false;
        response.message = 'Code verified successfully.';
        return response;
    }

    private class NormalizedRequest {
        public Id publishedVersionId;
        public String email;
        public String code;
        public Integer expiryMinutes;
        public Integer maxAttempts;
    }

    private static NormalizedRequest normalizeRequest(RequestPayload payload) {
        if (payload == null || payload.publishedVersionId == null) {
            throw buildHandledException('Missing required field: publishedVersionId', 400);
        }
        if (String.isBlank(payload.email)) {
            throw buildHandledException('Missing required field: email', 400);
        }

        NormalizedRequest normalized = new NormalizedRequest();
        normalized.publishedVersionId = payload.publishedVersionId;
        normalized.email = payload.email.trim().toLowerCase();
        normalized.code = String.isBlank(payload.code) ? '' : payload.code.trim();
        normalized.expiryMinutes = normalizePositiveInt(payload.expiryMinutes, DEFAULT_EXPIRY_MINUTES);
        normalized.maxAttempts = normalizePositiveInt(payload.maxAttempts, DEFAULT_MAX_ATTEMPTS);

        Map<String, Object> uiSettings = loadUiSettings(normalized.publishedVersionId);
        if (!booleanValue(uiSettings.get('secretCodeVerificationEnabled'))) {
            throw buildHandledException('Secret code verification is not enabled for this form.', 403);
        }

        return normalized;
    }

    private static Map<String, Object> loadUiSettings(Id versionId) {
        NF_Form_Version__c versionRecord = [
            SELECT Id, UI_Settings_JSON__c
            FROM NF_Form_Version__c
            WHERE Id = :versionId
            LIMIT 1
        ];
        if (String.isBlank(versionRecord.UI_Settings_JSON__c)) {
            return new Map<String, Object>();
        }
        try {
            Object parsed = JSON.deserializeUntyped(versionRecord.UI_Settings_JSON__c);
            return parsed instanceof Map<String, Object> ? (Map<String, Object>) parsed : new Map<String, Object>();
        } catch (Exception ex) {
            return new Map<String, Object>();
        }
    }

    private static Contact findExactlyOneContactByEmail(String email) {
        if (String.isBlank(email)) {
            return null;
        }
        List<Contact> rows = [
            SELECT Id,
                   FirstName,
                   LastName,
                   Email,
                   NativeForms_Secret_Code__c,
                   NativeForms_Secret_Code_Expires_At__c,
                   NativeForms_Secret_Code_Attempts__c,
                   NativeForms_Secret_Code_Verified_At__c
            FROM Contact
            WHERE Email = :email
            ORDER BY LastModifiedDate DESC
            LIMIT 2
        ];
        return rows.size() == 1 ? rows[0] : null;
    }

    private static void sendSecretCodeEmail(Contact target) {
        EmailTemplate templateRow = [
            SELECT Id
            FROM EmailTemplate
            WHERE DeveloperName = :TEMPLATE_DEVELOPER_NAME
            LIMIT 1
        ];

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTargetObjectId(target.Id);
        email.setSaveAsActivity(false);
        email.setTemplateId(templateRow.Id);

        Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email }, false);
        if (results == null || results.isEmpty() || !results[0].isSuccess()) {
            String message = 'Failed to send verification email.';
            if (results != null && !results.isEmpty() && results[0].getErrors() != null && !results[0].getErrors().isEmpty()) {
                message = results[0].getErrors()[0].getMessage();
            }
            throw buildHandledException(message, 500);
        }
    }

    private static ResponsePayload baseResponse() {
        ResponsePayload response = new ResponsePayload();
        response.success = true;
        response.approved = false;
        response.emailSent = false;
        response.verificationRequired = false;
        response.lockedOut = false;
        response.expired = false;
        response.message = '';
        response.normalizedEmail = null;
        return response;
    }

    private static ResponsePayload errorResponse(String message) {
        ResponsePayload response = baseResponse();
        response.success = false;
        response.message = String.isBlank(message) ? 'Secret code verification failed.' : message;
        return response;
    }

    private static String generateSixDigitCode() {
        Integer value = Math.mod(Math.abs(Crypto.getRandomInteger()), 1000000);
        return String.valueOf(value).leftPad(6, '0');
    }

    private static Integer normalizePositiveInt(Integer value, Integer fallbackValue) {
        if (value == null || value <= 0) {
            return fallbackValue;
        }
        return value;
    }

    private static Boolean booleanValue(Object value) {
        if (value == null) {
            return false;
        }
        if (value instanceof Boolean) {
            return (Boolean) value;
        }
        return String.valueOf(value).toLowerCase() == 'true';
    }

    private static AuraHandledException buildHandledException(String message, Integer statusCode) {
        RestContext.response.statusCode = statusCode;
        return new AuraHandledException(message);
    }
}
