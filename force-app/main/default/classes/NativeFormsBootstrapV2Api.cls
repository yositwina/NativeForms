@RestResource(urlMapping='/nativeforms/bootstrap-v2/signing-secret')
global with sharing class NativeFormsBootstrapV2Api {
    global class RequestPayload {
        public String orgId;
        public String purpose;
    }

    global class ResponsePayload {
        public Boolean success;
        public Boolean experimental;
        public String orgId;
        public String signingSecretB64;
        public String algorithm;
        public String message;
    }

    private class BootstrapV2HandledException extends Exception {}

    @HttpPost
    global static ResponsePayload handlePost() {
        try {
            RequestPayload payload = parsePayload();
            String currentOrgId = normalizeOrgId(UserInfo.getOrganizationId());
            String requestedOrgId = normalizeOrgId(payload == null ? null : payload.orgId);
            if (String.isBlank(requestedOrgId)) {
                throw buildHandledException('Missing required field: orgId', 400);
            }
            if (requestedOrgId != currentOrgId) {
                throw buildHandledException('Requested org does not match the authenticated org.', 403);
            }

            ResponsePayload response = new ResponsePayload();
            response.success = true;
            response.experimental = true;
            response.orgId = currentOrgId;
            response.signingSecretB64 = NativeFormsBootstrapV2Signer.getOrCreateSigningSecretForBootstrapV2();
            response.algorithm = NativeFormsBootstrapV2Signer.SIGNATURE_ALGORITHM;
            response.message = 'Bootstrap V2 signing secret returned for experimental OAuth bootstrap.';
            return response;
        } catch (BootstrapV2HandledException expected) {
            return errorResponse(expected.getMessage());
        } catch (Exception unexpected) {
            RestContext.response.statusCode = RestContext.response.statusCode == 0
                ? 500
                : RestContext.response.statusCode;
            return errorResponse('Bootstrap V2 signing secret could not be returned.');
        }
    }

    private static RequestPayload parsePayload() {
        String rawBody = RestContext.request == null || RestContext.request.requestBody == null
            ? '{}'
            : RestContext.request.requestBody.toString();
        return (RequestPayload) JSON.deserialize(rawBody, RequestPayload.class);
    }

    private static BootstrapV2HandledException buildHandledException(String message, Integer statusCode) {
        RestContext.response.statusCode = statusCode == null ? 400 : statusCode;
        return new BootstrapV2HandledException(message);
    }

    private static ResponsePayload errorResponse(String message) {
        ResponsePayload response = new ResponsePayload();
        response.success = false;
        response.experimental = true;
        response.message = message;
        return response;
    }

    private static String normalizeOrgId(String orgId) {
        String trimmed = String.isBlank(orgId) ? '' : orgId.trim();
        return trimmed.length() >= 15 ? trimmed.substring(0, 15) : trimmed;
    }
}
