public with sharing class NativeFormsAdminController {
    public class FeatureSettings {
        @AuraEnabled public Boolean enableProConditionLogic { get; set; }
        @AuraEnabled public Boolean enableProRepeatGroups { get; set; }
        @AuraEnabled public Boolean enableProPrefillAliasReferences { get; set; }
        @AuraEnabled public Boolean enableProAdvancedSubmitModes { get; set; }
        @AuraEnabled public Boolean enableProFormulaFields { get; set; }
        @AuraEnabled public Boolean enableProPostSubmitAutoLink { get; set; }
        @AuraEnabled public Boolean enableProSfSecretCodeAuth { get; set; }
        @AuraEnabled public Boolean enableProLoadFile { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static FeatureSettings getFeatureSettings() {
        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        FeatureSettings settings = new FeatureSettings();
        settings.enableProConditionLogic = config != null && config.Enable_Pro_Condition_Logic__c;
        settings.enableProRepeatGroups = config != null && config.Enable_Pro_Repeat_Groups__c;
        settings.enableProPrefillAliasReferences = config != null && config.Enable_Pro_Prefill_Alias_References__c;
        settings.enableProAdvancedSubmitModes = config != null && config.Enable_Pro_Advanced_Submit_Modes__c;
        settings.enableProFormulaFields = config != null && config.Enable_Pro_Formula_Fields__c;
        settings.enableProPostSubmitAutoLink = config != null && config.Enable_Pro_Post_Submit_Auto_Link__c;
        settings.enableProSfSecretCodeAuth = config != null && config.Enable_Pro_SF_Secret_Code_Auth__c;
        settings.enableProLoadFile = config != null && config.Enable_Pro_Load_File__c;
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
        config.Enable_Pro_Repeat_Groups__c = inputValue != null && inputValue.enableProRepeatGroups;
        config.Enable_Pro_Prefill_Alias_References__c = inputValue != null && inputValue.enableProPrefillAliasReferences;
        config.Enable_Pro_Advanced_Submit_Modes__c = inputValue != null && inputValue.enableProAdvancedSubmitModes;
        config.Enable_Pro_Formula_Fields__c = inputValue != null && inputValue.enableProFormulaFields;
        config.Enable_Pro_Post_Submit_Auto_Link__c = inputValue != null && inputValue.enableProPostSubmitAutoLink;
        config.Enable_Pro_SF_Secret_Code_Auth__c = inputValue != null && inputValue.enableProSfSecretCodeAuth;
        config.Enable_Pro_Load_File__c = inputValue != null && inputValue.enableProLoadFile;
        if (config.Id == null) {
            insert config;
        } else {
            update config;
        }
        return getFeatureSettings();
    }
}
