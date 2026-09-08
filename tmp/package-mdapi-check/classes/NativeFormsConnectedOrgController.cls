public with sharing class NativeFormsConnectedOrgController {
    private static final String DEFAULT_LOGIN_URL = 'https://login.salesforce.com';

    public class ConnectedImportView {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String orgId { get; set; }
        @AuraEnabled public String groupId { get; set; }
        @AuraEnabled public List<Object> orgs { get; set; }
        @AuraEnabled public List<Object> snapshots { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    public class ConnectedOrgStartResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String connectUrl { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    public class SnapshotPackageResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String portableJson { get; set; }
        @AuraEnabled public Object snapshot { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    @AuraEnabled
    public static ConnectedImportView getConnectedImportView() {
        ConnectedImportView view = new ConnectedImportView();
        view.orgId = currentOrgId();
        view.orgs = new List<Object>();
        view.snapshots = new List<Object>();

        try {
            Map<String, Object> orgResponse = NativeFormsAwsClient.listConnectedOrgs(view.orgId);
            Map<String, Object> snapshotResponse = NativeFormsAwsClient.listPortableSnapshots(view.orgId);
            view.success = true;
            view.groupId = (String) orgResponse.get('groupId');
            view.orgs = objectList(orgResponse.get('orgs'));
            view.snapshots = objectList(snapshotResponse.get('snapshots'));
        } catch (Exception e) {
            view.success = false;
            view.errorMessage = friendlyError(e);
        }

        return view;
    }

    @AuraEnabled
    public static ConnectedOrgStartResult startConnect(String loginBaseUrl, String returnUrl) {
        ConnectedOrgStartResult result = new ConnectedOrgStartResult();

        try {
            String orgId = currentOrgId();
            Map<String, Object> response = NativeFormsAwsClient.startConnectedOrg(new Map<String, Object>{
                'orgId' => orgId,
                'loginBaseUrl' => String.isBlank(loginBaseUrl) ? DEFAULT_LOGIN_URL : loginBaseUrl.trim(),
                'returnUrl' => String.isBlank(returnUrl) ? URL.getOrgDomainUrl().toExternalForm() : returnUrl
            });
            result.success = response.containsKey('success') ? (Boolean) response.get('success') : false;
            result.connectUrl = (String) response.get('connectUrl');
            result.errorMessage = result.success ? null : friendlyError(String.valueOf(response.get('error')));
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = friendlyError(e);
        }

        return result;
    }

    @AuraEnabled
    public static Boolean disconnectOrg(String targetOrgId) {
        if (String.isBlank(targetOrgId)) {
            throw new AuraHandledException('Select a connected org to disconnect.');
        }

        try {
            NativeFormsAwsClient.disconnectConnectedOrg(currentOrgId(), targetOrgId);
            return true;
        } catch (Exception e) {
            throw new AuraHandledException(friendlyError(e));
        }
    }

    @AuraEnabled
    public static SnapshotPackageResult getSnapshotPackage(String sourceOrgId, String globalFormKey) {
        SnapshotPackageResult result = new SnapshotPackageResult();

        try {
            if (String.isBlank(sourceOrgId) || String.isBlank(globalFormKey)) {
                throw new AuraHandledException('Select a connected form snapshot.');
            }

            Map<String, Object> response = NativeFormsAwsClient.getPortableSnapshot(
                currentOrgId(),
                sourceOrgId,
                globalFormKey
            );
            result.success = response.containsKey('success') ? (Boolean) response.get('success') : false;
            result.portableJson = (String) response.get('portableJson');
            result.snapshot = response.get('snapshot');
            result.errorMessage = result.success ? null : friendlyError(String.valueOf(response.get('error')));
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = friendlyError(e);
        }

        return result;
    }

    private static String currentOrgId() {
        return UserInfo.getOrganizationId().substring(0, 15);
    }

    private static List<Object> objectList(Object value) {
        if (value instanceof List<Object>) {
            return (List<Object>) value;
        }
        return new List<Object>();
    }

    private static String friendlyError(Exception e) {
        return friendlyError(e == null ? null : e.getMessage());
    }

    private static String friendlyError(String rawMessage) {
        String normalized = String.isBlank(rawMessage) ? '' : rawMessage.toLowerCase();
        if (normalized.contains('unauthorized') || normalized.contains('bootstrap')) {
            return 'TwinaForms secure service access is not ready. Reconnect TwinaForms, then try again.';
        }
        if (normalized.contains('snapshot')) {
            return 'TwinaForms could not load the connected form snapshot. Refresh and try again.';
        }
        return 'TwinaForms could not load connected org imports right now. Refresh and try again.';
    }
}
