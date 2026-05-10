public with sharing class NativeFormsAwsClient {
    private static final Integer TIMEOUT_MS = 120000;
    private static final String BACKEND_BASE_URL = 'https://f4apx2tkemgn5i2vagzhboeyjm0nnnjh.lambda-url.eu-north-1.on.aws';

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

    public static String backendBaseUrl() {
        return BACKEND_BASE_URL;
    }

    public static String backendEndpoint(String path) {
        String normalizedPath = String.isBlank(path) ? '/' : path.trim();
        if (!normalizedPath.startsWith('/')) {
            normalizedPath = '/' + normalizedPath;
        }
        return BACKEND_BASE_URL + normalizedPath;
    }

    public static PresignResponse presignHtml(PresignRequest requestBody) {
        String path = '/forms/publish/presign';
        String body = JSON.serialize(requestBody);
        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint(backendEndpoint(path));
        request.setHeader('Content-Type', 'application/json');
        applyBootstrapV2Signature(request, 'POST', path, body);
        request.setTimeout(TIMEOUT_MS);
        request.setBody(body);

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
        String path = '/forms/register';
        String body = JSON.serialize(requestBody);
        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint(backendEndpoint(path));
        request.setHeader('Content-Type', 'application/json');
        applyBootstrapV2Signature(request, 'POST', path, body);
        request.setTimeout(TIMEOUT_MS);
        request.setBody(body);

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new CalloutException('Register API error: ' + response.getStatusCode() + ' ' + response.getStatus() + ' ' + response.getBody());
        }

        return (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
    }

    public static Map<String, Object> unpublishForm(Map<String, Object> requestBody) {
        String path = '/forms/unpublish';
        String body = JSON.serialize(requestBody);
        HttpRequest request = new HttpRequest();
        request.setMethod('POST');
        request.setEndpoint(backendEndpoint(path));
        request.setHeader('Content-Type', 'application/json');
        applyBootstrapV2Signature(request, 'POST', path, body);
        request.setTimeout(TIMEOUT_MS);
        request.setBody(body);

        HttpResponse response = new Http().send(request);
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new CalloutException('Unpublish API error: ' + response.getStatusCode() + ' ' + response.getStatus() + ' ' + response.getBody());
        }

        return (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
    }

    public static void applyBootstrapV2Signature(HttpRequest request, String method, String path, String body) {
        Map<String, String> headers = NativeFormsBootstrapV2Signer.buildSignedHeaders(method, path, body);
        for (String headerName : headers.keySet()) {
            request.setHeader(headerName, headers.get(headerName));
        }
    }
}
