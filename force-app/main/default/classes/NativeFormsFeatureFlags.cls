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

    public static Boolean isProPageLayoutCloneEnabled() {
        return NativeFormsTenantEntitlements.isFeatureEnabled('enableProPageLayoutClone');
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

    public static Boolean isProElectronicSignatureEnabled() {
        return NativeFormsTenantEntitlements.isFeatureEnabled('enableProElectronicSignature');
    }

    public static Boolean isProSubmissionPdfEnabled() {
        return NativeFormsTenantEntitlements.isFeatureEnabled('enableProSubmissionPdf');
    }

    public static Boolean isProMergedDocumentEnabled() {
        return NativeFormsTenantEntitlements.isFeatureEnabled('enableProMergedDocument');
    }

    public static Boolean isProSurveyFieldsEnabled() {
        return NativeFormsTenantEntitlements.isFeatureEnabled('enableProSurveyFields');
    }

    public static Boolean isProLocationFieldsEnabled() {
        return NativeFormsTenantEntitlements.isFeatureEnabled('enableProLocationFields');
    }

    public static Boolean isProCustomJsEnabled() {
        return NativeFormsTenantEntitlements.isFeatureEnabled('enableProCustomJs');
    }

    public static Boolean isProButtonElementsEnabled() {
        return NativeFormsTenantEntitlements.isFeatureEnabled('enableProButtonElements');
    }
}
