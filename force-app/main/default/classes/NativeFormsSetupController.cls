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
                result.errorMessage = 'Registration failed: ' + response.getStatusCode() + ' ' + response.getStatus() + ' ' + response.getBody();
                return result;
            }

            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            result.success = responseBody.containsKey('success') ? (Boolean) responseBody.get('success') : false;
            result.tenantSecret = (String) responseBody.get('tenantSecret');
            result.connectUrl = (String) responseBody.get('connectUrl');

            if (!result.success && String.isBlank(result.errorMessage)) {
                Object errorValue = responseBody.get('error');
                result.errorMessage = errorValue == null ? 'NativeForms registration failed.' : String.valueOf(errorValue);
            }
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
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
                result.errorMessage = 'Saving client credentials failed: '
                    + response.getStatusCode() + ' ' + response.getStatus() + ' ' + response.getBody();
                return result;
            }

            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            result.success = responseBody.containsKey('success') ? (Boolean) responseBody.get('success') : false;
            result.connectUrl = (String) responseBody.get('connectUrl');

            if (!result.success && String.isBlank(result.errorMessage)) {
                Object errorValue = responseBody.get('error');
                result.errorMessage = errorValue == null ? 'Saving client credentials failed.' : String.valueOf(errorValue);
            }
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
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
                result.errorMessage = 'Unable to load NativeForms connection status: '
                    + response.getStatusCode() + ' ' + response.getStatus();

                String responseBody = response.getBody();
                if (!String.isBlank(responseBody)) {
                    result.errorMessage += ' ' + responseBody;
                }
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
            result.errorMessage = result.success ? null : String.valueOf(responseBody.get('error'));

            TenantAuthStatus tenantAuth = verifyTenantAuth(effectiveOrgId);
            result.tenantAuthVerified = tenantAuth.verified;
            result.tenantAuthStatus = tenantAuth.status;
            result.tenantAuthErrorMessage = tenantAuth.errorMessage;
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
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
                result.errorMessage = 'Unable to disconnect NativeForms: '
                    + response.getStatusCode() + ' ' + response.getStatus();

                String responseBody = response.getBody();
                if (!String.isBlank(responseBody)) {
                    result.errorMessage += ' ' + responseBody;
                }
                return result;
            }

            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            result.success = responseBody.containsKey('success') ? (Boolean) responseBody.get('success') : false;
            result.connectUrl = (String) responseBody.get('connectUrl');
            result.errorMessage = result.success ? null : String.valueOf(responseBody.get('error'));
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
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
            result.errorMessage = 'Tenant secret auth check failed: '
                + response.getStatusCode() + ' ' + response.getStatus();

            String responseBody = response.getBody();
            if (!String.isBlank(responseBody)) {
                result.errorMessage += ' ' + responseBody;
            }
        } catch (Exception e) {
            result.status = 'not_verified';
            result.errorMessage = e.getMessage();
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
}
