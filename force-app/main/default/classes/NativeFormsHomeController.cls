public with sharing class NativeFormsHomeController {
    private static final Integer TIMEOUT_MS = 120000;
    private static final String BASE_BOOTSTRAP_NC_NAME = 'NativeForms_Bootstrap';
    private static String cachedBootstrapNc;

    public class ConnectionSummary {
        @AuraEnabled public Boolean ready { get; set; }
        @AuraEnabled public Boolean secretKeyConfigured { get; set; }
        @AuraEnabled public String secretKeyLabel { get; set; }
        @AuraEnabled public Boolean permissionSetConfigured { get; set; }
        @AuraEnabled public String permissionSetLabel { get; set; }
        @AuraEnabled public Boolean needsConnectAction { get; set; }
    }

    public class PlanSummary {
        @AuraEnabled public String code { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String storageMode { get; set; }
        @AuraEnabled public Integer retentionDays { get; set; }
        @AuraEnabled public String retentionLabel { get; set; }
        @AuraEnabled public Boolean detailedLogsIncluded { get; set; }
        @AuraEnabled public String detailedLogsLabel { get; set; }
        @AuraEnabled public Boolean advancedSecurityIncluded { get; set; }
        @AuraEnabled public String securityLabel { get; set; }
        @AuraEnabled public Integer maxForms { get; set; }
        @AuraEnabled public Boolean showUpgradeAction { get; set; }
    }

    public class UsageSummary {
        @AuraEnabled public Integer activeFormsCount { get; set; }
        @AuraEnabled public Integer maxForms { get; set; }
        @AuraEnabled public String formsUsageLabel { get; set; }
        @AuraEnabled public Integer submissionsMonth { get; set; }
        @AuraEnabled public Integer maxSubmissionsPerMonth { get; set; }
        @AuraEnabled public String submissionsUsageLabel { get; set; }
        @AuraEnabled public Integer activeUsersCount { get; set; }
        @AuraEnabled public Integer maxSfUsers { get; set; }
        @AuraEnabled public String activeUsersLabel { get; set; }
    }

    public class DemoSummary {
        @AuraEnabled public Boolean installed { get; set; }
        @AuraEnabled public String installedLabel { get; set; }
        @AuraEnabled public String versionValue { get; set; }
    }

    public class FeatureItem {
        @AuraEnabled public String key { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String detail { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String statusLabel { get; set; }
    }

    public class HomeView {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String orgId { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
        @AuraEnabled public ConnectionSummary connection { get; set; }
        @AuraEnabled public PlanSummary plan { get; set; }
        @AuraEnabled public UsageSummary usage { get; set; }
        @AuraEnabled public DemoSummary demo { get; set; }
        @AuraEnabled public List<FeatureItem> upgradeFeatures { get; set; }
        @AuraEnabled public String comparePlansUrl { get; set; }
        @AuraEnabled public String upgradeUrl { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static HomeView getHomeView() {
        HomeView view = new HomeView();
        view.success = true;
        view.orgId = currentOrgId();
        view.connection = new ConnectionSummary();
        view.plan = new PlanSummary();
        view.usage = new UsageSummary();
        view.demo = buildDemoSummary(NativeFormsDemoDataService.getHomeSnapshot());
        view.upgradeFeatures = new List<FeatureItem>();

        try {
            NativeFormsSetupController.ConnectionStatus connectionStatus =
                NativeFormsSetupController.getConnectionStatus(view.orgId);
            view.connection = buildConnectionSummary(connectionStatus);
        } catch (Exception e) {
            view.success = false;
            view.errorMessage = 'TwinaForms Home could not load the latest connection details.';
        }

        try {
            Map<String, Object> homeSummary = getAwsHomeSummary(view.orgId);
            applyAwsHomeSummary(view, homeSummary);
        } catch (Exception e) {
            view.success = false;
            view.errorMessage = appendError(view.errorMessage, 'Plan and usage details are temporarily unavailable.');
        }

        return view;
    }

    private static void applyAwsHomeSummary(HomeView view, Map<String, Object> payload) {
        if (view == null || payload == null) {
            return;
        }

        if (payload.containsKey('plan') && payload.get('plan') instanceof Map<String, Object>) {
            Map<String, Object> planMap = (Map<String, Object>) payload.get('plan');
            view.plan.code = stringValue(planMap, 'code');
            view.plan.label = stringValue(planMap, 'label');
            view.plan.description = stringValue(planMap, 'description');
            view.plan.storageMode = stringValue(planMap, 'storageMode');
            view.plan.retentionDays = integerValue(planMap, 'retentionDays');
            view.plan.retentionLabel = view.plan.retentionDays == null
                ? 'Not available'
                : String.valueOf(view.plan.retentionDays) + ' days';
            view.plan.detailedLogsIncluded = booleanValue(planMap, 'detailedLogsIncluded');
            view.plan.detailedLogsLabel = view.plan.detailedLogsIncluded
                ? 'Included'
                : 'Upgrade to unlock';
            view.plan.advancedSecurityIncluded = booleanValue(planMap, 'advancedSecurityIncluded');
            view.plan.securityLabel = view.plan.advancedSecurityIncluded
                ? 'Included'
                : 'Available on higher plans';

            if (planMap.containsKey('limits') && planMap.get('limits') instanceof Map<String, Object>) {
                Map<String, Object> limitsMap = (Map<String, Object>) planMap.get('limits');
                view.plan.maxForms = integerValue(limitsMap, 'maxForms');
            }

            view.plan.showUpgradeAction = isUpgradeablePlan(view.plan.code);
        }

        if (payload.containsKey('usage') && payload.get('usage') instanceof Map<String, Object>) {
            Map<String, Object> usageMap = (Map<String, Object>) payload.get('usage');
            view.usage.activeFormsCount = integerValue(usageMap, 'activeFormsCount');
            view.usage.maxForms = integerValue(usageMap, 'maxForms');
            view.usage.formsUsageLabel = buildUsageLabel(view.usage.activeFormsCount, view.usage.maxForms);
            view.usage.submissionsMonth = integerValue(usageMap, 'submissionsMonth');
            view.usage.maxSubmissionsPerMonth = integerValue(usageMap, 'maxSubmissionsPerMonth');
            view.usage.submissionsUsageLabel = buildUsageLabel(
                view.usage.submissionsMonth,
                view.usage.maxSubmissionsPerMonth
            );
            view.usage.activeUsersCount = integerValue(usageMap, 'activeUsersCount');
            view.usage.maxSfUsers = integerValue(usageMap, 'maxSfUsers');
            view.usage.activeUsersLabel = buildUsageLabel(view.usage.activeUsersCount, view.usage.maxSfUsers);

            if (view.plan.maxForms == null) {
                view.plan.maxForms = view.usage.maxForms;
            }
        }

        view.upgradeFeatures = buildFeatureList(payload.get('upgradeFeatures'), 'Upgrade');
        view.comparePlansUrl = stringValue(payload, 'comparePlansUrl');
        view.upgradeUrl = stringValue(payload, 'upgradeUrl');
    }

    private static ConnectionSummary buildConnectionSummary(NativeFormsSetupController.ConnectionStatus source) {
        ConnectionSummary summary = new ConnectionSummary();
        summary.secretKeyConfigured = source != null && source.tenantAuthVerified;
        summary.secretKeyLabel = summary.secretKeyConfigured ? 'Yes' : 'No';
        summary.permissionSetConfigured = source != null && source.success;
        summary.permissionSetLabel = summary.permissionSetConfigured ? 'Yes' : 'No';
        summary.ready = summary.secretKeyConfigured && summary.permissionSetConfigured;
        summary.needsConnectAction = !summary.ready;
        return summary;
    }

    private static DemoSummary buildDemoSummary(NativeFormsDemoDataService.HomeSnapshot source) {
        DemoSummary summary = new DemoSummary();
        summary.installed = source != null && source.demoDataInstalled;
        summary.installedLabel = summary.installed ? 'Yes' : 'No';
        summary.versionValue = source == null || String.isBlank(source.demoDataVersion)
            ? 'Not installed yet'
            : source.demoDataVersion;
        return summary;
    }

    private static List<FeatureItem> buildFeatureList(Object rawValue, String fallbackStatusLabel) {
        List<FeatureItem> items = new List<FeatureItem>();
        if (!(rawValue instanceof List<Object>)) {
            return items;
        }

        for (Object entry : (List<Object>) rawValue) {
            if (!(entry instanceof Map<String, Object>)) {
                continue;
            }

            Map<String, Object> source = (Map<String, Object>) entry;
            FeatureItem item = new FeatureItem();
            item.key = stringValue(source, 'key');
            item.label = stringValue(source, 'label');
            item.detail = stringValue(source, 'detail');
            item.status = stringValue(source, 'status');
            item.statusLabel = String.isBlank(item.status)
                ? fallbackStatusLabel
                : prettyLabel(item.status);
            items.add(item);
        }

        return items;
    }

    private static Map<String, Object> getAwsHomeSummary(String orgId) {
        HttpRequest request = new HttpRequest();
        request.setMethod('GET');
        request.setEndpoint(
            'callout:' + bootstrapNamedCredentialName()
            + '/tenant/home-summary?orgId='
            + EncodingUtil.urlEncode(orgId, 'UTF-8')
        );
        request.setTimeout(TIMEOUT_MS);

        HttpResponse response = new Http().send(request);
        Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new AuraHandledException('Plan and usage details are temporarily unavailable.');
        }

        if (responseBody == null || !booleanValue(responseBody, 'success')) {
            throw new AuraHandledException('Plan and usage details are temporarily unavailable.');
        }

        return responseBody;
    }

    private static String buildUsageLabel(Integer currentValue, Integer limitValue) {
        Integer used = currentValue == null ? 0 : currentValue;
        if (limitValue == null) {
            return String.valueOf(used) + ' / Unlimited';
        }
        return String.valueOf(used) + ' / ' + String.valueOf(limitValue);
    }

    private static Boolean isUpgradeablePlan(String planCode) {
        String normalized = String.isBlank(planCode) ? '' : planCode.trim().toLowerCase();
        return normalized == 'free' || normalized == 'starter';
    }

    private static Boolean booleanValue(Map<String, Object> source, String key) {
        if (source == null || !source.containsKey(key) || source.get(key) == null) {
            return false;
        }
        return (Boolean) source.get(key);
    }

    private static Integer integerValue(Map<String, Object> source, String key) {
        if (source == null || !source.containsKey(key) || source.get(key) == null) {
            return null;
        }
        return Integer.valueOf(String.valueOf(source.get(key)));
    }

    private static String stringValue(Map<String, Object> source, String key) {
        if (source == null || !source.containsKey(key) || source.get(key) == null) {
            return null;
        }
        return String.valueOf(source.get(key));
    }

    private static String appendError(String existingMessage, String nextMessage) {
        if (String.isBlank(existingMessage)) {
            return nextMessage;
        }
        if (String.isBlank(nextMessage)) {
            return existingMessage;
        }
        return existingMessage + ' | ' + nextMessage;
    }

    private static String prettyLabel(String value) {
        String normalized = String.valueOf(value == null ? '' : value)
            .replaceAll('([a-z])([A-Z])', '$1 $2')
            .replaceAll('[_-]+', ' ')
            .replaceAll('\\s+', ' ')
            .trim()
            .toLowerCase();
        if (String.isBlank(normalized)) {
            return '';
        }

        List<String> words = normalized.split(' ');
        List<String> prettyWords = new List<String>();
        for (String word : words) {
            if (String.isBlank(word)) {
                continue;
            }
            prettyWords.add(word.substring(0, 1).toUpperCase() + word.substring(1));
        }
        return String.join(prettyWords, ' ');
    }

    private static String currentOrgId() {
        return UserInfo.getOrganizationId().substring(0, 15);
    }

    private static String bootstrapNamedCredentialName() {
        if (cachedBootstrapNc != null) {
            return cachedBootstrapNc;
        }

        String fullName = NativeFormsHomeController.class.getName();
        Integer dot = fullName.indexOf('.');
        String ns = dot > 0 ? fullName.substring(0, dot) : null;

        cachedBootstrapNc = String.isBlank(ns)
            ? BASE_BOOTSTRAP_NC_NAME
            : ns + '__' + BASE_BOOTSTRAP_NC_NAME;

        return cachedBootstrapNc;
    }
}
