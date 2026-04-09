public with sharing class NativeFormsFeatureFlags {
    public static Boolean isProConditionLogicEnabled() {
        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        return config != null && config.Enable_Pro_Condition_Logic__c;
    }
}
