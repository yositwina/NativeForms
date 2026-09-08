public with sharing class NativeFormsPortableSnapshotSyncJob implements Queueable, Database.AllowsCallouts {
    private Id formId;
    private Id versionId;

    public NativeFormsPortableSnapshotSyncJob(Id formIdValue, Id versionIdValue) {
        formId = formIdValue;
        versionId = versionIdValue;
    }

    public void execute(QueueableContext context) {
        if (formId == null || versionId == null) {
            return;
        }

        try {
            NF_Form_Version__c versionRecord = [
                SELECT Id,
                       Form__c,
                       Form__r.NF_Key__c,
                       Form__r.Name,
                       Version_Number__c,
                       Last_Published_At__c,
                       Version_Status__c
                FROM NF_Form_Version__c
                WHERE Id = :versionId
                WITH USER_MODE LIMIT 1
            ];

            if (versionRecord.Version_Status__c != 'Published') {
                return;
            }

            String packageJson = NativeFormsFormPortabilityController.exportForm(formId, versionId);
            NativeFormsAwsClient.savePortableSnapshot(new Map<String, Object>{
                'sourceOrgId' => UserInfo.getOrganizationId().substring(0, 15),
                'globalFormKey' => versionRecord.Form__r.NF_Key__c,
                'publishedVersionNumber' => versionRecord.Version_Number__c,
                'publishedAt' => versionRecord.Last_Published_At__c == null
                    ? null
                    : versionRecord.Last_Published_At__c.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''),
                'portableJson' => packageJson
            });
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Connected-org snapshot sync failed: ' + e.getMessage());
        }
    }
}
