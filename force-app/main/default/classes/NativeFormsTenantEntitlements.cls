public with sharing class NativeFormsTenantEntitlements {
    private static final Integer TIMEOUT_MS = 120000;
    private static EntitlementSnapshot cachedSnapshot;

    public class EntitlementSnapshot {
        public Boolean loadedSuccessfully { get; set; }
        public String orgId { get; set; }
        public String planCode { get; set; }
        public Map<String, Object> effectiveFeatureFlags { get; set; }
        public Map<String, Object> effectiveLimits { get; set; }
        public String errorMessage { get; set; }
    }

    public static EntitlementSnapshot getCurrentOrgEntitlements() {
        if (cachedSnapshot == null) {
            cachedSnapshot = loadCurrentOrgEntitlements();
        }
        return cachedSnapshot;
    }

    public static Boolean isFeatureEnabled(String featureKey) {
        EntitlementSnapshot snapshot = getCurrentOrgEntitlements();
        if (snapshot == null || snapshot.effectiveFeatureFlags == null || String.isBlank(featureKey)) {
            return false;
        }

        Object rawValue = snapshot.effectiveFeatureFlags.get(featureKey);
        if (rawValue == null) {
            return false;
        }
        if (rawValue instanceof Boolean) {
            return (Boolean) rawValue;
        }
        return String.valueOf(rawValue).toLowerCase() == 'true';
    }

    @TestVisible
    static void resetCache() {
        cachedSnapshot = null;
    }

    @TestVisible
    static void setCachedSnapshot(EntitlementSnapshot snapshot) {
        cachedSnapshot = snapshot;
    }

    private static EntitlementSnapshot loadCurrentOrgEntitlements() {
        EntitlementSnapshot snapshot = new EntitlementSnapshot();
        snapshot.loadedSuccessfully = false;
        snapshot.orgId = currentOrgId();
        snapshot.planCode = null;
        snapshot.effectiveFeatureFlags = new Map<String, Object>();
        snapshot.effectiveLimits = new Map<String, Object>();
        snapshot.errorMessage = null;

        try {
            HttpRequest request = new HttpRequest();
            request.setMethod('GET');
            request.setEndpoint(
                'callout:' + NativeFormsAwsClient.namedCredentialName()
                + '/tenant/entitlements?orgId='
                + EncodingUtil.urlEncode(snapshot.orgId, 'UTF-8')
            );
            request.setTimeout(TIMEOUT_MS);

            HttpResponse response = new Http().send(request);
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                snapshot.errorMessage = extractErrorMessage(responseBody, 'Unable to load NativeForms entitlements.');
                return snapshot;
            }
            if (responseBody == null || !booleanValue(responseBody, 'success')) {
                snapshot.errorMessage = extractErrorMessage(responseBody, 'Unable to load NativeForms entitlements.');
                return snapshot;
            }

            snapshot.loadedSuccessfully = true;
            snapshot.orgId = stringValue(responseBody, 'orgId');
            snapshot.planCode = stringValue(responseBody, 'planCode');
            snapshot.effectiveFeatureFlags = mapValue(responseBody.get('effectiveFeatureFlags'));
            snapshot.effectiveLimits = mapValue(responseBody.get('effectiveLimits'));
            return snapshot;
        } catch (Exception e) {
            snapshot.errorMessage = e.getMessage();
            return snapshot;
        }
    }

    private static String currentOrgId() {
        return UserInfo.getOrganizationId().substring(0, 15);
    }

    private static Boolean booleanValue(Map<String, Object> source, String key) {
        if (source == null || !source.containsKey(key) || source.get(key) == null) {
            return false;
        }

        Object value = source.get(key);
        if (value instanceof Boolean) {
            return (Boolean) value;
        }
        return String.valueOf(value).toLowerCase() == 'true';
    }

    private static String stringValue(Map<String, Object> source, String key) {
        if (source == null || !source.containsKey(key) || source.get(key) == null) {
            return null;
        }
        return String.valueOf(source.get(key));
    }

    private static Map<String, Object> mapValue(Object value) {
        if (value instanceof Map<String, Object>) {
            return (Map<String, Object>) value;
        }
        return new Map<String, Object>();
    }

    private static String extractErrorMessage(Map<String, Object> source, String fallbackMessage) {
        String errorMessage = stringValue(source, 'error');
        return String.isBlank(errorMessage) ? fallbackMessage : errorMessage;
    }
}
