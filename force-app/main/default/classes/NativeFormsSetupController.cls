public with sharing class NativeFormsSetupController {
    private static final Integer TIMEOUT_MS = 120000;

    public class SetupContext {
        @AuraEnabled public String orgId { get; set; }
        @AuraEnabled public String orgName { get; set; }
        @AuraEnabled public String adminEmail { get; set; }
        @AuraEnabled public String loginBaseUrl { get; set; }
        @AuraEnabled public String country { get; set; }
        @AuraEnabled public String state { get; set; }
        @AuraEnabled public String city { get; set; }
    }

    public class RegistrationRequest {
        @AuraEnabled public String orgId { get; set; }
        @AuraEnabled public String adminEmail { get; set; }
        @AuraEnabled public String companyName { get; set; }
        @AuraEnabled public String loginBaseUrl { get; set; }
        @AuraEnabled public String subscriptionState { get; set; }
        @AuraEnabled public String subscriptionStartDate { get; set; }
        @AuraEnabled public String subscriptionEndDate { get; set; }
        @AuraEnabled public Boolean isActive { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String country { get; set; }
        @AuraEnabled public String state { get; set; }
        @AuraEnabled public String city { get; set; }
    }

    public class RegistrationResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String connectUrl { get; set; }
        @AuraEnabled public String rawResponse { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    public class ConnectionStatus {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public Boolean registered { get; set; }
        @AuraEnabled public Boolean connected { get; set; }
        @AuraEnabled public String setupState { get; set; }
        @AuraEnabled public String connectUrl { get; set; }
        @AuraEnabled public Boolean hasClientCredentials { get; set; }
        @AuraEnabled public Boolean tenantAuthVerified { get; set; }
        @AuraEnabled public String tenantAuthStatus { get; set; }
        @AuraEnabled public String tenantAuthErrorMessage { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    public class DisconnectResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String connectUrl { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static SetupContext getSetupContext() {
        SetupContext context = new SetupContext();

        context.orgId = UserInfo.getOrganizationId().substring(0, 15);
        context.adminEmail = UserInfo.getUserEmail();
        context.loginBaseUrl = URL.getOrgDomainUrl().toExternalForm();

        Organization orgRecord = [
            SELECT Name, City, State, Country
            FROM Organization
            WITH USER_MODE LIMIT 1
        ];
        context.orgName = orgRecord.Name;
        context.country = orgRecord.Country;
        context.state = orgRecord.State;
        context.city = orgRecord.City;

        return context;
    }

    @AuraEnabled
    public static RegistrationResult registerOrg(String requestJson) {
        RegistrationResult result = new RegistrationResult();

        try {
            RegistrationRequest requestBody = parseRegistrationRequest(requestJson);
            result.success = true;
            result.connectUrl = buildDirectConnectUrl(requestBody);
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = buildRegisterOrgExceptionMessage(e);
        }

        return result;
    }

    @AuraEnabled
    public static ConnectionStatus getConnectionStatus(String orgId, Boolean verifyTenantAuthNow) {
        ConnectionStatus result = new ConnectionStatus();

        try {
            String effectiveOrgId = String.isBlank(orgId)
                ? UserInfo.getOrganizationId().substring(0, 15)
                : orgId.trim();

            HttpRequest request = new HttpRequest();
            request.setMethod('GET');
            request.setEndpoint(NativeFormsAwsClient.backendEndpoint('/tenant/status') + '?orgId=' + EncodingUtil.urlEncode(effectiveOrgId, 'UTF-8'));
            request.setTimeout(TIMEOUT_MS);

            HttpResponse response = new Http().send(request);
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                result.success = false;
                result.errorMessage = buildConnectionStatusErrorMessage(response.getStatusCode(), response.getBody());
                return result;
            }

            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            result.success = responseBody.containsKey('success') ? (Boolean) responseBody.get('success') : false;
            result.registered = responseBody.containsKey('registered') ? (Boolean) responseBody.get('registered') : false;
            result.connected = responseBody.containsKey('connected') ? (Boolean) responseBody.get('connected') : false;
            result.setupState = (String) responseBody.get('setupState');
            result.connectUrl = (String) responseBody.get('connectUrl');
            result.hasClientCredentials = responseBody.containsKey('hasClientCredentials')
                ? (Boolean) responseBody.get('hasClientCredentials')
                : false;
            result.errorMessage = result.success
                ? null
                : buildConnectionStatusErrorMessage(null, String.valueOf(responseBody.get('error')));

            Boolean shouldVerifyTenantAuth = verifyTenantAuthNow == true && result.registered == true;
            if (shouldVerifyTenantAuth) {
                TenantAuthStatus tenantAuth = verifyTenantAuth(effectiveOrgId);
                result.tenantAuthVerified = tenantAuth.verified;
                result.tenantAuthStatus = tenantAuth.status;
                result.tenantAuthErrorMessage = tenantAuth.errorMessage;
            } else {
                result.tenantAuthVerified = false;
                result.tenantAuthStatus = 'not_checked';
                result.tenantAuthErrorMessage = null;
            }
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = buildConnectionStatusErrorMessage(null, e == null ? null : e.getMessage());
        }

        return result;
    }

    @AuraEnabled
    public static DisconnectResult disconnectOrg(String orgId) {
        DisconnectResult result = new DisconnectResult();

        try {
            String effectiveOrgId = String.isBlank(orgId)
                ? UserInfo.getOrganizationId().substring(0, 15)
                : orgId.trim();

            HttpRequest request = new HttpRequest();
            String path = '/tenant/disconnect';
            String body = JSON.serialize(new Map<String, Object>{
                'orgId' => effectiveOrgId
            });
            request.setMethod('POST');
            request.setEndpoint(NativeFormsAwsClient.backendEndpoint(path));
            request.setHeader('Content-Type', 'application/json');
            NativeFormsAwsClient.applyBootstrapV2Signature(request, 'POST', path, body);
            request.setTimeout(TIMEOUT_MS);
            request.setBody(body);

            HttpResponse response = new Http().send(request);
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                result.success = false;
                result.errorMessage = buildDisconnectErrorMessage(response.getStatusCode(), response.getBody());
                return result;
            }

            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            result.success = responseBody.containsKey('success') ? (Boolean) responseBody.get('success') : false;
            result.connectUrl = (String) responseBody.get('connectUrl');
            result.errorMessage = result.success
                ? null
                : buildDisconnectErrorMessage(null, String.valueOf(responseBody.get('error')));
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = 'TwinaForms could not disconnect this org right now. Try again in a moment.';
        }

        return result;
    }

    private class TenantAuthStatus {
        public Boolean verified { get; set; }
        public String status { get; set; }
        public String errorMessage { get; set; }
    }

    private static RegistrationRequest parseRegistrationRequest(String requestJson) {
        if (String.isBlank(requestJson)) {
            return new RegistrationRequest();
        }
        return (RegistrationRequest) JSON.deserialize(requestJson, RegistrationRequest.class);
    }

    private static TenantAuthStatus verifyTenantAuth(String orgId) {
        TenantAuthStatus result = new TenantAuthStatus();
        result.verified = false;
        result.status = 'not_checked';

        try {
            String path = '/tenant/auth-health';
            HttpRequest request = new HttpRequest();
            request.setMethod('GET');
            request.setEndpoint(NativeFormsAwsClient.backendEndpoint(path) + '?orgId=' + EncodingUtil.urlEncode(orgId, 'UTF-8'));
            NativeFormsAwsClient.applyBootstrapV2Signature(request, 'GET', path, '');
            request.setTimeout(TIMEOUT_MS);

            HttpResponse response = new Http().send(request);
            if (response.getStatusCode() >= 200 && response.getStatusCode() < 300) {
                result.verified = true;
                result.status = 'verified';
                return result;
            }

            result.status = 'not_verified';
            result.errorMessage = buildTenantAuthErrorMessage(response.getStatusCode(), response.getBody());
        } catch (Exception e) {
            result.status = 'not_verified';
            result.errorMessage = 'TwinaForms could not verify secure service access yet. Reconnect TwinaForms and try again.';
        }

        return result;
    }

    private static String buildDirectConnectUrl(RegistrationRequest requestBody) {
        if (requestBody == null) {
            throw new AuraHandledException('Missing setup request.');
        }
        String orgId = String.isBlank(requestBody.orgId)
            ? UserInfo.getOrganizationId().substring(0, 15)
            : requestBody.orgId.trim();
        if (String.isBlank(requestBody.loginBaseUrl)) {
            throw new AuraHandledException('Missing Salesforce login URL.');
        }

        List<String> parts = new List<String>{
            'orgId=' + EncodingUtil.urlEncode(orgId, 'UTF-8'),
            'loginBaseUrl=' + EncodingUtil.urlEncode(requestBody.loginBaseUrl, 'UTF-8')
        };
        addOptionalQueryPart(parts, 'adminEmail', requestBody.adminEmail);
        addOptionalQueryPart(parts, 'companyName', requestBody.companyName);
        addOptionalQueryPart(parts, 'country', requestBody.country);
        addOptionalQueryPart(parts, 'state', requestBody.state);
        addOptionalQueryPart(parts, 'city', requestBody.city);
        return NativeFormsAwsClient.backendEndpoint('/connect') + '?' + String.join(parts, '&');
    }

    private static void addOptionalQueryPart(List<String> parts, String name, String value) {
        if (parts == null || String.isBlank(name) || String.isBlank(value)) {
            return;
        }
        parts.add(name + '=' + EncodingUtil.urlEncode(value, 'UTF-8'));
    }

    private static String buildRegisterOrgExceptionMessage(Exception e) {
        return 'TwinaForms could not prepare the connection. Refresh and try again.';
    }

    private static String buildConnectionStatusErrorMessage(Integer statusCode, String rawBody) {
        return 'TwinaForms could not verify the current connection status. Refresh and try again.';
    }

    private static String buildDisconnectErrorMessage(Integer statusCode, String rawBody) {
        if (statusCode != null && statusCode == 401) {
            return 'TwinaForms could not disconnect this org because the current connection is no longer authorized.';
        }
        return 'TwinaForms could not disconnect this org right now. Try again in a moment.';
    }

    private static String buildTenantAuthErrorMessage(Integer statusCode, String rawBody) {
        String normalized = normalizeMessage(rawBody);
        if (normalized.contains('invalid tenant secret')
            || normalized.contains('bootstrap')
            || statusCode == 401) {
            return 'TwinaForms secure service access is not authorized yet. Reconnect TwinaForms and try again.';
        }
        return 'TwinaForms could not verify secure service access yet. Reconnect TwinaForms and try again.';
    }

    private static String normalizeMessage(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
    }
}
