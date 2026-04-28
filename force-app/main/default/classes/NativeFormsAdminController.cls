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
        @AuraEnabled public String captchaSiteKey { get; set; }
        @AuraEnabled public String captchaSecretKey { get; set; }
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
        settings.captchaSiteKey = NativeFormsPublisher.getSharedCaptchaSiteKey();
        settings.captchaSecretKey = '';
        return settings;
    }

    @AuraEnabled
    public static FeatureSettings saveFeatureSettings(String inputJson) {
        FeatureSettings inputValue = parseFeatureSettings(inputJson);
        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        if (config == null) {
            config = new NativeForms_Config__c(
                SetupOwnerId = UserInfo.getOrganizationId()
            );
        }
        config.Enable_Pro_Condition_Logic__c = inputValue != null && inputValue.enableProConditionLogic == true;
        config.Enable_Pro_Repeat_Groups__c = inputValue != null && inputValue.enableProRepeatGroups == true;
        config.Enable_Pro_Prefill_Alias_References__c = inputValue != null && inputValue.enableProPrefillAliasReferences == true;
        config.Enable_Pro_Advanced_Submit_Modes__c = inputValue != null && inputValue.enableProAdvancedSubmitModes == true;
        config.Enable_Pro_Formula_Fields__c = inputValue != null && inputValue.enableProFormulaFields == true;
        config.Enable_Pro_Post_Submit_Auto_Link__c = inputValue != null && inputValue.enableProPostSubmitAutoLink == true;
        config.Enable_Pro_SF_Secret_Code_Auth__c = inputValue != null && inputValue.enableProSfSecretCodeAuth == true;
        config.Enable_Pro_Load_File__c = inputValue != null && inputValue.enableProLoadFile == true;
        if (config.Id == null) {
            insert config;
        } else {
            update config;
        }
        return getFeatureSettings();
    }

    private static FeatureSettings parseFeatureSettings(String inputJson) {
        if (String.isBlank(inputJson)) {
            return new FeatureSettings();
        }
        return (FeatureSettings) JSON.deserialize(inputJson, FeatureSettings.class);
    }

    private static String normalizeText(String value) {
        return String.isBlank(value) ? null : value.trim();
    }
}
