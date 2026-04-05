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

    public class RegistrationResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String tenantSecret { get; set; }
        @AuraEnabled public String connectUrl { get; set; }
        @AuraEnabled public String rawResponse { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static SetupContext getSetupContext() {
        SetupContext context = new SetupContext();

        context.orgId = UserInfo.getOrganizationId();
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
