public with sharing class NativeFormsFeatureFlags {
    public static Boolean isProConditionLogicEnabled() {
        return NativeFormsTenantEntitlements.isFeatureEnabled('enableProConditionLogic');
    }

    public static Boolean isProRepeatGroupsEnabled() {
        return NativeFormsTenantEntitlements.isFeatureEnabled('enableProRepeatGroups');
    }

    public static Boolean isProPrefillAliasReferencesEnabled() {
        return NativeFormsTenantEntitlements.isFeatureEnabled('enableProPrefillAliasReferences');
    }

    public static Boolean isProAdvancedSubmitModesEnabled() {
        return NativeFormsTenantEntitlements.isFeatureEnabled('enableProAdvancedSubmitModes');
    }

    public static Boolean isProFormulaFieldsEnabled() {
        return NativeFormsTenantEntitlements.isFeatureEnabled('enableProFormulaFields');
    }

    public static Boolean isProPostSubmitAutoLinkEnabled() {
        return NativeFormsTenantEntitlements.isFeatureEnabled('enableProPostSubmitAutoLink');
    }

    public static Boolean isProSfSecretCodeAuthEnabled() {
        return NativeFormsTenantEntitlements.isFeatureEnabled('enableProSfSecretCodeAuth');
    }

    public static Boolean isProLoadFileEnabled() {
        return NativeFormsTenantEntitlements.isFeatureEnabled('enableProLoadFile');
    }
}
