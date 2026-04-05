public with sharing class NativeFormsSetupController {
    public class SetupContext {
        @AuraEnabled public String orgId { get; set; }
        @AuraEnabled public String orgName { get; set; }
        @AuraEnabled public String adminEmail { get; set; }
        @AuraEnabled public String loginBaseUrl { get; set; }
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
}
