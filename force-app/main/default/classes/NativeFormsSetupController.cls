public with sharing class NativeFormsSetupController {
    private static final Integer TIMEOUT_MS = 120000;
    private static final String BASE_BOOTSTRAP_NC_NAME = 'NativeForms_Bootstrap';
    private static String cachedBootstrapNc;

    public class SetupContext {
        @AuraEnabled public String orgId { get; set; }
        @AuraEnabled public String orgName { get; set; }
        @AuraEnabled public String adminEmail { get; set; }
        @AuraEnabled public String loginBaseUrl { get; set; }
    }

    public class RegistrationRequest {
        @AuraEnabled public String orgId { get; set; }
        @AuraEnabled public String adminEmail { get; set; }
        @AuraEnabled public String companyName { get; set; }
        @AuraEnabled public String loginBaseUrl { get; set; }
        @AuraEnabled public String salesforceClientId { get; set; }
        @AuraEnabled public String salesforceClientSecret { get; set; }
        @AuraEnabled public String subscriptionState { get; set; }
        @AuraEnabled public String subscriptionStartDate { get; set; }
        @AuraEnabled public String subscriptionEndDate { get; set; }
        @AuraEnabled public Boolean isActive { get; set; }
        @AuraEnabled public String status { get; set; }
    }

    public class ClientCredentialsRequest {
        @AuraEnabled public String orgId { get; set; }
        @AuraEnabled public String adminEmail { get; set; }
        @AuraEnabled public String companyName { get; set; }
        @AuraEnabled public String loginBaseUrl { get; set; }
        @AuraEnabled public String salesforceClientId { get; set; }
        @AuraEnabled public String salesforceClientSecret { get; set; }
    }

    public class RegistrationResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String tenantSecret { get; set; }
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
            SELECT Name
            FROM Organization
            LIMIT 1
        ];
        context.orgName = orgRecord.Name;

        return context;
    }

    @AuraEnabled
    public static RegistrationResult registerOrg(RegistrationRequest requestBody) {
        RegistrationResult result = new RegistrationResult();

        try {
            HttpRequest request = new HttpRequest();
            request.setMethod('POST');
            request.setEndpoint('callout:' + bootstrapNamedCredentialName() + '/tenant/register');
            request.setHeader('Content-Type', 'application/json');
            request.setTimeout(TIMEOUT_MS);
            request.setBody(JSON.serialize(requestBody));

            HttpResponse response = new Http().send(request);
            result.rawResponse = response.getBody();

            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                result.success = false;
                result.errorMessage = buildRegisterOrgErrorMessage(response.getStatusCode(), response.getBody());
                return result;
            }

            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            result.success = responseBody.containsKey('success') ? (Boolean) responseBody.get('success') : false;
            result.tenantSecret = (String) responseBody.get('tenantSecret');
            result.connectUrl = (String) responseBody.get('connectUrl');

            if (!result.success && String.isBlank(result.errorMessage)) {
                result.errorMessage = buildRegisterOrgErrorMessage(null, String.valueOf(responseBody.get('error')));
            }
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = buildRegisterOrgExceptionMessage(e);
        }

        return result;
    }

    @AuraEnabled
    public static RegistrationResult saveClientCredentials(ClientCredentialsRequest requestBody) {
        RegistrationResult result = new RegistrationResult();

        try {
            HttpRequest request = new HttpRequest();
            request.setMethod('POST');
            request.setEndpoint('callout:' + bootstrapNamedCredentialName() + '/tenant/register');
            request.setHeader('Content-Type', 'application/json');
            request.setTimeout(TIMEOUT_MS);
            request.setBody(JSON.serialize(requestBody));

            HttpResponse response = new Http().send(request);
            result.rawResponse = response.getBody();

            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                result.success = false;
                result.errorMessage = buildSaveClientCredentialsErrorMessage(response.getStatusCode(), response.getBody());
                return result;
            }

            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            result.success = responseBody.containsKey('success') ? (Boolean) responseBody.get('success') : false;
            result.connectUrl = (String) responseBody.get('connectUrl');

            if (!result.success && String.isBlank(result.errorMessage)) {
                result.errorMessage = buildSaveClientCredentialsErrorMessage(null, String.valueOf(responseBody.get('error')));
            }
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = buildSaveClientCredentialsExceptionMessage(e);
        }

        return result;
    }

    @AuraEnabled
    public static ConnectionStatus getConnectionStatus(String orgId) {
        ConnectionStatus result = new ConnectionStatus();

        try {
            String effectiveOrgId = String.isBlank(orgId)
                ? UserInfo.getOrganizationId().substring(0, 15)
                : orgId.trim();

            HttpRequest request = new HttpRequest();
            request.setMethod('GET');
            request.setEndpoint('callout:' + bootstrapNamedCredentialName() + '/tenant/status?orgId=' + EncodingUtil.urlEncode(effectiveOrgId, 'UTF-8'));
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

            TenantAuthStatus tenantAuth = verifyTenantAuth(effectiveOrgId);
            result.tenantAuthVerified = tenantAuth.verified;
            result.tenantAuthStatus = tenantAuth.status;
            result.tenantAuthErrorMessage = tenantAuth.errorMessage;
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = 'TwinaForms could not verify the current connection status. Refresh and try again.';
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
            request.setMethod('POST');
            request.setEndpoint('callout:' + bootstrapNamedCredentialName() + '/tenant/disconnect');
            request.setHeader('Content-Type', 'application/json');
            request.setTimeout(TIMEOUT_MS);
            request.setBody(JSON.serialize(new Map<String, Object>{
                'orgId' => effectiveOrgId
            }));

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

    private static TenantAuthStatus verifyTenantAuth(String orgId) {
        TenantAuthStatus result = new TenantAuthStatus();
        result.verified = false;
        result.status = 'not_checked';

        try {
            HttpRequest request = new HttpRequest();
            request.setMethod('GET');
            request.setEndpoint('callout:' + NativeFormsAwsClient.namedCredentialName() + '/tenant/auth-health?orgId=' + EncodingUtil.urlEncode(orgId, 'UTF-8'));
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
            result.errorMessage = 'TwinaForms could not verify the tenant secret yet. Check the Named Credential secret and try again.';
        }

        return result;
    }

    private static String bootstrapNamedCredentialName() {
        if (cachedBootstrapNc != null) {
            return cachedBootstrapNc;
        }

        String fullName = NativeFormsSetupController.class.getName();
        Integer dot = fullName.indexOf('.');
        String ns = dot > 0 ? fullName.substring(0, dot) : null;

        cachedBootstrapNc = String.isBlank(ns)
            ? BASE_BOOTSTRAP_NC_NAME
            : ns + '__' + BASE_BOOTSTRAP_NC_NAME;

        return cachedBootstrapNc;
    }

    private static String buildRegisterOrgErrorMessage(Integer statusCode, String rawBody) {
        if (isPermissionSetAccessIssue(statusCode, rawBody)) {
            return 'TwinaForms could not generate the tenant secret yet because setup access is not complete. Check permission-set access and try again.';
        }
        return 'TwinaForms could not generate the tenant secret. Check setup access and try again.';
    }

    private static String buildRegisterOrgExceptionMessage(Exception e) {
        String message = e == null ? '' : String.valueOf(e.getMessage());
        if (isPermissionSetAccessIssue(null, message)) {
            return 'TwinaForms could not generate the tenant secret yet because setup access is not complete. Check permission-set access and try again.';
        }
        return 'TwinaForms could not generate the tenant secret. Check setup access and try again.';
    }

    private static String buildSaveClientCredentialsErrorMessage(Integer statusCode, String rawBody) {
        if (isPermissionSetAccessIssue(statusCode, rawBody)) {
            return 'TwinaForms could not save the Salesforce client credentials yet because setup access is not complete. Check permission-set access and try again.';
        }
        return 'TwinaForms could not save the Salesforce client credentials. Check the values and try again.';
    }

    private static String buildSaveClientCredentialsExceptionMessage(Exception e) {
        String message = e == null ? '' : String.valueOf(e.getMessage());
        if (isPermissionSetAccessIssue(null, message)) {
            return 'TwinaForms could not save the Salesforce client credentials yet because setup access is not complete. Check permission-set access and try again.';
        }
        return 'TwinaForms could not save the Salesforce client credentials. Check the values and try again.';
    }

    private static String buildConnectionStatusErrorMessage(Integer statusCode, String rawBody) {
        if (isPermissionSetAccessIssue(statusCode, rawBody)) {
            return 'TwinaForms could not verify the current connection status because setup access is not complete.';
        }
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
        if (normalized.contains('invalid tenant secret') || statusCode == 401) {
            return 'The tenant secret is incorrect. Update the Named Credential secret and try again.';
        }
        return 'TwinaForms could not verify the tenant secret yet. Check the Named Credential secret and try again.';
    }

    private static Boolean isPermissionSetAccessIssue(Integer statusCode, String rawBody) {
        String normalized = normalizeMessage(rawBody);
        if (normalized.contains('external credential')
            || normalized.contains('principal access')
            || normalized.contains('nativeforms_bootstrap')
            || normalized.contains('nativeformsbootstrap')
            || normalized.contains('nativeforms shared secret')
            || normalized.contains('permission-set access')
            || normalized.contains('permission set access')) {
            return true;
        }
        return statusCode == 401 && normalized.contains('credential');
    }

    private static String normalizeMessage(String value) {
        return String.isBlank(value) ? '' : value.trim().toLowerCase();
    }
}
