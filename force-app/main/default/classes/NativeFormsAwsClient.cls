public with sharing class NativeFormsAwsClient {
    private static final Integer TIMEOUT_MS = 120000;
    private static final String BASE_NC_NAME = 'NativeForms';
    private static String cachedNc;

    public class PresignRequest {
        public String orgId;
        public String formId;
        public String formSlug;
        public String versionId;
        public String fileName;
        public String contentType;
        public Integer expires;
    }

    public class PresignResponse {
        public Boolean success;
        public String putUrl;
        public String publicUrl;
        public String key;
        public String companySlug;
        public String formSlug;
        public Long expiresAt;
        public String error;
    }

    @TestVisible
    public static String namedCredentialName() {
        if (cachedNc != null) {
            return cachedNc;
        }

        String fullName = NativeFormsSetupController.class.getName();
        Integer dot = fullName.indexOf('.');
        String ns = dot > 0 ? fullName.substring(0, dot) : null;

        cachedNc = String.isBlank(ns)
            ? BASE_NC_NAME
            : ns + '__' + BASE_NC_NAME;

        return cachedNc;
    }

    @TestVisible
    static void resetNamedCredentialCache() {
        cachedNc = null;
    }

    public static PresignResponse presignHtml(PresignRequest requestBody) {
        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint('callout:' + namedCredentialName() + '/forms/publish/presign');
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(TIMEOUT_MS);
        request.setBody(JSON.serialize(requestBody));

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new CalloutException('Presign API error: ' + response.getStatusCode() + ' ' + response.getStatus() + ' ' + response.getBody());
        }

        PresignResponse parsed = (PresignResponse) JSON.deserialize(response.getBody(), PresignResponse.class);
        if (parsed == null || String.isBlank(parsed.putUrl) || String.isBlank(parsed.publicUrl) || String.isBlank(parsed.key)) {
            throw new CalloutException('Presign response missing one of putUrl, publicUrl, or key.');
        }

        return parsed;
    }

    public static void uploadHtml(String putUrl, String htmlBody) {
        HttpRequest request = new HttpRequest();
        request.setMethod('PUT');
        request.setEndpoint(putUrl);
        request.setHeader('Content-Type', 'text/html; charset=utf-8');
        request.setBody(htmlBody);
        request.setTimeout(TIMEOUT_MS);

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new CalloutException('HTML upload failed: ' + response.getStatusCode() + ' ' + response.getStatus() + ' ' + response.getBody());
        }
    }

    public static Map<String, Object> registerForm(Map<String, Object> requestBody) {
        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint('callout:' + namedCredentialName() + '/forms/register');
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(TIMEOUT_MS);
        request.setBody(JSON.serialize(requestBody));

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new CalloutException('Register API error: ' + response.getStatusCode() + ' ' + response.getStatus() + ' ' + response.getBody());
        }

        return (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
    }
}
