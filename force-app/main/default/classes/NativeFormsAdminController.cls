public with sharing class NativeFormsAdminController {
    public class FeatureSettings {
        @AuraEnabled public Boolean enableProConditionLogic { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static FeatureSettings getFeatureSettings() {
        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        FeatureSettings settings = new FeatureSettings();
        settings.enableProConditionLogic = config != null && config.Enable_Pro_Condition_Logic__c;
        return settings;
    }

    @AuraEnabled
    public static FeatureSettings saveFeatureSettings(FeatureSettings inputValue) {
        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        if (config == null) {
            config = new NativeForms_Config__c(
                SetupOwnerId = UserInfo.getOrganizationId()
            );
        }
        config.Enable_Pro_Condition_Logic__c = inputValue != null && inputValue.enableProConditionLogic;
        if (config.Id == null) {
            insert config;
        } else {
            update config;
        }
        return getFeatureSettings();
    }
}
