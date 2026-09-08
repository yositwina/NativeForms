@RestResource(urlMapping='/nativeforms/secret-code')
global with sharing class NativeFormsSecretCodeApi {
    @TestVisible private static String forcedEmailFailureMessageForTest;

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
        NativeFormsUserVerificationApi.ResponsePayload source = NativeFormsUserVerificationApi.handlePost();
        ResponsePayload response = new ResponsePayload();
        response.success = source.success;
        response.approved = source.approved;
        response.emailSent = source.emailSent;
        response.verificationRequired = source.verificationRequired;
        response.lockedOut = source.lockedOut;
        response.expired = source.expired;
        response.message = source.message;
        response.normalizedEmail = source.normalizedEmail;
        return response;
    }
}
