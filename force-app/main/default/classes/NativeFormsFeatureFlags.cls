public with sharing class NativeFormsFeatureFlags {
    public static Boolean isProConditionLogicEnabled() {
        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        return config != null && config.Enable_Pro_Condition_Logic__c;
    }

    public static Boolean isProRepeatGroupsEnabled() {
        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        return config != null && config.Enable_Pro_Repeat_Groups__c;
    }

    public static Boolean isProPrefillAliasReferencesEnabled() {
        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        return config != null && config.Enable_Pro_Prefill_Alias_References__c;
    }

    public static Boolean isProAdvancedSubmitModesEnabled() {
        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        return config != null && config.Enable_Pro_Advanced_Submit_Modes__c;
    }

    public static Boolean isProFormulaFieldsEnabled() {
        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        return config != null && config.Enable_Pro_Formula_Fields__c;
    }

    public static Boolean isProPostSubmitAutoLinkEnabled() {
        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        return config != null && config.Enable_Pro_Post_Submit_Auto_Link__c;
    }
}
