public with sharing class NativeFormsSubmissionLogsController {
    private static final Integer TIMEOUT_MS = 120000;
    private static final String BASE_LOGS_NC_NAME = 'NativeForms_SubmissionLogs';
    private static String cachedLogsNc;

    public class SyncResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String orgId { get; set; }
        @AuraEnabled public String planCode { get; set; }
        @AuraEnabled public Integer retentionDays { get; set; }
        @AuraEnabled public Boolean detailedLogsIncludedByPlan { get; set; }
        @AuraEnabled public String effectiveDetailMode { get; set; }
        @AuraEnabled public String encryptionStatus { get; set; }
        @AuraEnabled public String keyVersion { get; set; }
        @AuraEnabled public Boolean publicKeyConfigured { get; set; }
        @AuraEnabled public String publicKeySyncedAt { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    public class SubmissionLogStatus {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String orgId { get; set; }
        @AuraEnabled public String planCode { get; set; }
        @AuraEnabled public Integer retentionDays { get; set; }
        @AuraEnabled public Boolean detailedLogsIncludedByPlan { get; set; }
        @AuraEnabled public String effectiveDetailMode { get; set; }
        @AuraEnabled public String encryptionStatus { get; set; }
        @AuraEnabled public String keyVersion { get; set; }
        @AuraEnabled public Boolean hasPublicKey { get; set; }
        @AuraEnabled public Boolean hasPrivateKey { get; set; }
        @AuraEnabled public String publicKeySyncedAt { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    public class SubmissionLogSummary {
        @AuraEnabled public String tenantId { get; set; }
        @AuraEnabled public String submissionId { get; set; }
        @AuraEnabled public String submissionRef { get; set; }
        @AuraEnabled public String formId { get; set; }
        @AuraEnabled public String formVersionId { get; set; }
        @AuraEnabled public String formDescription { get; set; }
        @AuraEnabled public String submittedAt { get; set; }
        @AuraEnabled public String outcome { get; set; }
        @AuraEnabled public String failureStage { get; set; }
        @AuraEnabled public String detailMode { get; set; }
        @AuraEnabled public String recordId { get; set; }
        @AuraEnabled public Long expiresAt { get; set; }
    }

    public class LogListResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public List<SubmissionLogSummary> logs { get; set; }
        @AuraEnabled public String nextToken { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    public class LogDetailResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public SubmissionLogSummary log { get; set; }
        @AuraEnabled public String decryptedDetailJson { get; set; }
        @AuraEnabled public String clientEncryptedDetailJson { get; set; }
        @AuraEnabled public String privateKeyPkcs8B64 { get; set; }
        @AuraEnabled public String detailAccessMessage { get; set; }
        @AuraEnabled public String formTitle { get; set; }
        @AuraEnabled public List<FieldLabelEntry> fieldLabels { get; set; }
        @AuraEnabled public List<RepeatGroupLabelEntry> repeatGroupLabels { get; set; }
        @AuraEnabled public String errorMessage { get; set; }
    }

    public class FieldLabelEntry {
        @AuraEnabled public String fieldKey { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String elementType { get; set; }
    }

    public class RepeatGroupLabelEntry {
        @AuraEnabled public String groupKey { get; set; }
        @AuraEnabled public String label { get; set; }
    }

    private class SubmissionLogKeyRecord {
        public Id recordId { get; set; }
        public String publicKeyB64 { get; set; }
        public String privateKeyB64 { get; set; }
        public String keyVersion { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static SubmissionLogStatus getSubmissionLogStatus() {
        SubmissionLogStatus result = new SubmissionLogStatus();
        SubmissionLogKeyRecord keyRecord = getSubmissionLogKeyRecord();
        result.orgId = currentOrgId();
        result.keyVersion = keyRecord == null || String.isBlank(keyRecord.keyVersion)
            ? 'v2'
            : keyRecord.keyVersion;
        result.hasPublicKey = keyRecord != null && !String.isBlank(keyRecord.publicKeyB64);
        result.hasPrivateKey = keyRecord != null && !String.isBlank(keyRecord.privateKeyB64);

        try {
            HttpRequest request = new HttpRequest();
            request.setMethod('GET');
            request.setEndpoint(
                'callout:' + namedCredentialName()
                + '/submission-log-config/status?orgId='
                + EncodingUtil.urlEncode(result.orgId, 'UTF-8')
            );
            request.setTimeout(TIMEOUT_MS);

            HttpResponse response = new Http().send(request);
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                result.success = false;
                result.errorMessage = responseBody != null && responseBody.containsKey('error')
                    ? String.valueOf(responseBody.get('error'))
                    : 'Unable to load submission log status.';
                return result;
            }

            result.success = responseBody != null && responseBody.containsKey('success')
                ? (Boolean) responseBody.get('success')
                : false;
            result.planCode = stringValue(responseBody, 'planCode');
            result.retentionDays = integerValue(responseBody, 'retentionDays');
            result.detailedLogsIncludedByPlan = booleanValue(responseBody, 'detailedLogsIncludedByPlan');
            result.effectiveDetailMode = stringValue(responseBody, 'effectiveDetailMode');
            result.encryptionStatus = stringValue(responseBody, 'encryptionStatus');
            result.keyVersion = stringValue(responseBody, 'keyVersion') == null
                ? result.keyVersion
                : stringValue(responseBody, 'keyVersion');
            result.publicKeySyncedAt = stringValue(responseBody, 'publicKeySyncedAt');
            result.errorMessage = result.success ? null : stringValue(responseBody, 'error');
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
        }

        return result;
    }

    @AuraEnabled
    public static SubmissionLogStatus saveSubmissionLogKeyPair(String publicKeyB64, String privateKeyPkcs8B64, String keyVersion) {
        if (String.isBlank(publicKeyB64) || String.isBlank(privateKeyPkcs8B64)) {
            throw new AuraHandledException('Submission log keypair is incomplete.');
        }

        validateBase64(publicKeyB64, 'Submission log public key');
        validateBase64(privateKeyPkcs8B64, 'Submission log private key');

        SubmissionLogKeyRecord existingRecord = getSubmissionLogKeyRecord();
        NF_Submission_Log_Key__c keyRecord = existingRecord == null
            ? new NF_Submission_Log_Key__c(Name = currentOrgId())
            : new NF_Submission_Log_Key__c(Id = existingRecord.recordId);

        keyRecord.Public_Key__c = publicKeyB64.trim();
        keyRecord.Private_Key__c = privateKeyPkcs8B64.trim();
        keyRecord.Key_Version__c = String.isBlank(keyVersion) ? 'v2' : keyVersion.trim();

        if (existingRecord == null) {
            insert keyRecord;
        } else {
            update keyRecord;
        }

        return getSubmissionLogStatus();
    }

    @AuraEnabled
    public static SyncResult syncSubmissionLogConfig() {
        SyncResult result = new SyncResult();

        try {
            SubmissionLogKeyRecord keyRecord = getSubmissionLogKeyRecord();
            if (keyRecord == null || String.isBlank(keyRecord.publicKeyB64)) {
                throw new AuraHandledException('Submission log public key is not ready in Salesforce yet.');
            }

            HttpRequest request = new HttpRequest();
            request.setMethod('POST');
            request.setEndpoint('callout:' + namedCredentialName() + '/submission-log-config/sync');
            request.setHeader('Content-Type', 'application/json');
            request.setTimeout(TIMEOUT_MS);
            request.setBody(JSON.serialize(new Map<String, Object>{
                'orgId' => currentOrgId(),
                'submissionLogPublicKey' => keyRecord.publicKeyB64,
                'submissionLogKeyVersion' => String.isBlank(keyRecord.keyVersion)
                    ? 'v2'
                    : keyRecord.keyVersion
            }));

            HttpResponse response = new Http().send(request);
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());

            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                result.success = false;
                result.errorMessage = responseBody != null && responseBody.containsKey('error')
                    ? String.valueOf(responseBody.get('error'))
                    : 'Submission log config sync failed.';
                return result;
            }

            result.success = responseBody != null && responseBody.containsKey('success')
                ? (Boolean) responseBody.get('success')
                : false;
            result.orgId = stringValue(responseBody, 'orgId');
            result.planCode = stringValue(responseBody, 'planCode');
            result.retentionDays = integerValue(responseBody, 'retentionDays');
            result.detailedLogsIncludedByPlan = booleanValue(responseBody, 'detailedLogsIncludedByPlan');
            result.effectiveDetailMode = stringValue(responseBody, 'effectiveDetailMode');
            result.encryptionStatus = stringValue(responseBody, 'encryptionStatus');
            result.keyVersion = stringValue(responseBody, 'keyVersion');
            result.publicKeyConfigured = booleanValue(responseBody, 'publicKeyConfigured');
            result.publicKeySyncedAt = stringValue(responseBody, 'publicKeySyncedAt');
            result.errorMessage = result.success ? null : stringValue(responseBody, 'error');
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static LogListResult listLogs(String formId, String outcome, String submissionRef, String dateFrom, String dateTo, Integer pageSize, String nextToken) {
        LogListResult result = new LogListResult();
        result.logs = new List<SubmissionLogSummary>();

        try {
            List<String> parts = new List<String>{
                'orgId=' + EncodingUtil.urlEncode(currentOrgId(), 'UTF-8')
            };
            if (String.isNotBlank(formId)) {
                parts.add('formId=' + EncodingUtil.urlEncode(formId.trim(), 'UTF-8'));
            }
            if (String.isNotBlank(outcome)) {
                parts.add('outcome=' + EncodingUtil.urlEncode(outcome.trim(), 'UTF-8'));
            }
            if (String.isNotBlank(submissionRef)) {
                parts.add('submissionRef=' + EncodingUtil.urlEncode(submissionRef.trim(), 'UTF-8'));
            }
            if (String.isNotBlank(dateFrom)) {
                parts.add('dateFrom=' + EncodingUtil.urlEncode(dateFrom.trim(), 'UTF-8'));
            }
            if (String.isNotBlank(dateTo)) {
                parts.add('dateTo=' + EncodingUtil.urlEncode(dateTo.trim(), 'UTF-8'));
            }
            if (pageSize != null) {
                parts.add('pageSize=' + String.valueOf(pageSize));
            }
            if (String.isNotBlank(nextToken)) {
                parts.add('nextToken=' + EncodingUtil.urlEncode(nextToken, 'UTF-8'));
            }

            HttpRequest request = new HttpRequest();
            request.setMethod('GET');
            request.setEndpoint('callout:' + namedCredentialName() + '/submission-logs?' + String.join(parts, '&'));
            request.setTimeout(TIMEOUT_MS);

            HttpResponse response = new Http().send(request);
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                result.success = false;
                result.errorMessage = responseBody != null && responseBody.containsKey('error')
                    ? String.valueOf(responseBody.get('error'))
                    : 'Unable to load submission logs.';
                return result;
            }

            result.success = responseBody != null && responseBody.containsKey('success')
                ? (Boolean) responseBody.get('success')
                : false;
            result.nextToken = stringValue(responseBody, 'nextToken');
            if (responseBody != null && responseBody.containsKey('logs')) {
                for (Object entry : (List<Object>) responseBody.get('logs')) {
                    result.logs.add(toSummary((Map<String, Object>) entry));
                }
            }
            hydrateSummaryDescriptions(result.logs);
            result.errorMessage = result.success ? null : stringValue(responseBody, 'error');
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static LogDetailResult getLogDetail(String submissionId) {
        LogDetailResult result = new LogDetailResult();
        result.fieldLabels = new List<FieldLabelEntry>();
        result.repeatGroupLabels = new List<RepeatGroupLabelEntry>();

        try {
            if (String.isBlank(submissionId)) {
                throw new AuraHandledException('Missing required field: submissionId');
            }

            HttpRequest request = new HttpRequest();
            request.setMethod('GET');
            request.setEndpoint(
                'callout:' + namedCredentialName()
                + '/submission-logs/' + EncodingUtil.urlEncode(submissionId, 'UTF-8')
                + '?orgId=' + EncodingUtil.urlEncode(currentOrgId(), 'UTF-8')
            );
            request.setTimeout(TIMEOUT_MS);

            HttpResponse response = new Http().send(request);
            Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                result.success = false;
                result.errorMessage = responseBody != null && responseBody.containsKey('error')
                    ? String.valueOf(responseBody.get('error'))
                    : 'Unable to load submission log detail.';
                return result;
            }

            Map<String, Object> logData = responseBody == null
                ? null
                : (Map<String, Object>) responseBody.get('log');
            result.success = true;
            result.log = toSummary(logData);
            hydrateFormMetadata(result, result.log == null ? null : result.log.formVersionId);

            if (logData != null && logData.containsKey('encryptedDetail') && result.log != null && result.log.detailMode == 'encrypted_detail') {
                Map<String, Object> encryptedDetail = (Map<String, Object>) logData.get('encryptedDetail');
                if (String.isNotBlank(stringValue(encryptedDetail, 'detailEncryptedKeyB64'))) {
                    SubmissionLogKeyRecord keyRecord = getSubmissionLogKeyRecord();
                    result.clientEncryptedDetailJson = JSON.serialize(encryptedDetail);
                    result.privateKeyPkcs8B64 = keyRecord == null ? null : keyRecord.privateKeyB64;
                    if (String.isBlank(result.privateKeyPkcs8B64)) {
                        result.detailAccessMessage = 'This org has encrypted detail for this log, but the private log key is not ready in Salesforce yet.';
                    }
                } else {
                    result.decryptedDetailJson = decryptLegacyEncryptedDetail(
                        stringValue(encryptedDetail, 'detailCiphertextB64'),
                        stringValue(encryptedDetail, 'detailIvB64')
                    );
                }
            }
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = e.getMessage();
        }

        return result;
    }

    @AuraEnabled
    public static String decryptEncryptedDetail(String detailCiphertextB64, String detailIvB64) {
        return decryptLegacyEncryptedDetail(detailCiphertextB64, detailIvB64);
    }

    private static String decryptLegacyEncryptedDetail(String detailCiphertextB64, String detailIvB64) {
        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        if (config == null || String.isBlank(config.Submission_Log_Key__c)) {
            throw new AuraHandledException('Legacy submission log key is not configured for this org.');
        }
        if (String.isBlank(detailCiphertextB64) || String.isBlank(detailIvB64)) {
            throw new AuraHandledException('Encrypted detail payload is incomplete.');
        }

        Blob key = EncodingUtil.base64Decode(config.Submission_Log_Key__c);
        Blob iv = EncodingUtil.base64Decode(detailIvB64);
        Blob ciphertext = EncodingUtil.base64Decode(detailCiphertextB64);
        Blob plaintext = Crypto.decrypt('AES256', key, iv, ciphertext);
        return plaintext.toString();
    }

    private static SubmissionLogKeyRecord getSubmissionLogKeyRecord() {
        List<NF_Submission_Log_Key__c> records = [
            SELECT Id, Name, Public_Key__c, Private_Key__c, Key_Version__c
            FROM NF_Submission_Log_Key__c
            WHERE Name = :currentOrgId()
            LIMIT 1
        ];
        if (records.isEmpty()) {
            return null;
        }

        NF_Submission_Log_Key__c recordValue = records[0];
        SubmissionLogKeyRecord output = new SubmissionLogKeyRecord();
        output.recordId = recordValue.Id;
        output.publicKeyB64 = recordValue.Public_Key__c;
        output.privateKeyB64 = recordValue.Private_Key__c;
        output.keyVersion = recordValue.Key_Version__c;
        return output;
    }

    private static void validateBase64(String value, String fieldLabel) {
        try {
            EncodingUtil.base64Decode(value.trim());
        } catch (Exception e) {
            throw new AuraHandledException(fieldLabel + ' must be valid base64.');
        }
    }

    private static Boolean booleanValue(Map<String, Object> source, String key) {
        if (source == null || !source.containsKey(key) || source.get(key) == null) {
            return false;
        }
        return (Boolean) source.get(key);
    }

    private static SubmissionLogSummary toSummary(Map<String, Object> source) {
        if (source == null) {
            return null;
        }

        SubmissionLogSummary summary = new SubmissionLogSummary();
        summary.tenantId = stringValue(source, 'tenantId');
        summary.submissionId = stringValue(source, 'submissionId');
        summary.submissionRef = stringValue(source, 'submissionRef');
        summary.formId = stringValue(source, 'formId');
        summary.formVersionId = stringValue(source, 'formVersionId');
        summary.submittedAt = stringValue(source, 'submittedAt');
        summary.outcome = stringValue(source, 'outcome');
        summary.failureStage = stringValue(source, 'failureStage');
        summary.detailMode = stringValue(source, 'detailMode');
        summary.recordId = stringValue(source, 'recordId');
        summary.expiresAt = longValue(source, 'expiresAt');
        return summary;
    }

    private static Integer integerValue(Map<String, Object> source, String key) {
        if (source == null || !source.containsKey(key) || source.get(key) == null) {
            return null;
        }
        return Integer.valueOf(String.valueOf(source.get(key)));
    }

    private static Long longValue(Map<String, Object> source, String key) {
        if (source == null || !source.containsKey(key) || source.get(key) == null) {
            return null;
        }
        return Long.valueOf(String.valueOf(source.get(key)));
    }

    private static String stringValue(Map<String, Object> source, String key) {
        if (source == null || !source.containsKey(key) || source.get(key) == null) {
            return null;
        }
        return String.valueOf(source.get(key));
    }

    private static String currentOrgId() {
        return UserInfo.getOrganizationId().substring(0, 15);
    }

    private static String namedCredentialName() {
        if (cachedLogsNc != null) {
            return cachedLogsNc;
        }

        String fullName = NativeFormsSetupController.class.getName();
        Integer dot = fullName.indexOf('.');
        String ns = dot > 0 ? fullName.substring(0, dot) : null;

        cachedLogsNc = String.isBlank(ns)
            ? BASE_LOGS_NC_NAME
            : ns + '__' + BASE_LOGS_NC_NAME;

        return cachedLogsNc;
    }

    private static void hydrateSummaryDescriptions(List<SubmissionLogSummary> logs) {
        if (logs == null || logs.isEmpty()) {
            return;
        }
        Set<Id> versionIds = new Set<Id>();
        for (SubmissionLogSummary summary : logs) {
            if (summary == null || String.isBlank(summary.formVersionId)) {
                continue;
            }
            try {
                versionIds.add((Id) summary.formVersionId);
            } catch (Exception e) {
                // ignore non-Id values
            }
        }
        if (versionIds.isEmpty()) {
            return;
        }
        Map<Id, NF_Form_Version__c> byId = new Map<Id, NF_Form_Version__c>([
            SELECT Id, Form__r.Description__c
            FROM NF_Form_Version__c
            WHERE Id IN :versionIds
        ]);
        for (SubmissionLogSummary summary : logs) {
            if (summary == null || String.isBlank(summary.formVersionId)) {
                continue;
            }
            NF_Form_Version__c versionRecord;
            try {
                versionRecord = byId.get((Id) summary.formVersionId);
            } catch (Exception e) {
                continue;
            }
            if (versionRecord == null) {
                continue;
            }
            summary.formDescription = versionRecord.Form__r.Description__c;
        }
    }

    private static void hydrateFormMetadata(LogDetailResult result, String formVersionId) {
        if (result == null || String.isBlank(formVersionId)) {
            return;
        }

        try {
            NF_Form_Version__c versionRecord = [
                SELECT Id, Name, Form__r.Name, Form__r.Description__c
                FROM NF_Form_Version__c
                WHERE Id = :formVersionId
                LIMIT 1
            ];
            result.formTitle = String.isNotBlank(versionRecord.Form__r.Name)
                ? versionRecord.Form__r.Name
                : versionRecord.Name;
            if (result.log != null) {
                result.log.formDescription = versionRecord.Form__r.Description__c;
            }
        } catch (Exception e) {
            result.formTitle = null;
        }

        Set<String> seenFieldKeys = new Set<String>();
        Set<String> seenRepeatKeys = new Set<String>();
        for (NF_Form_Element__c elementRecord : [
            SELECT Field_Key__c, Label__c, Element_Type__c, Order__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :formVersionId
            ORDER BY Order__c ASC, CreatedDate ASC
        ]) {
            String fieldKey = elementRecord.Field_Key__c;
            if (String.isBlank(fieldKey)) {
                continue;
            }

            String normalizedFieldKey = fieldKey.trim();
            String label = String.isBlank(elementRecord.Label__c)
                ? normalizedFieldKey
                : elementRecord.Label__c.trim();

            if (elementRecord.Element_Type__c == 'repeatGroup') {
                if (seenRepeatKeys.contains(normalizedFieldKey)) {
                    continue;
                }
                seenRepeatKeys.add(normalizedFieldKey);

                RepeatGroupLabelEntry repeatEntry = new RepeatGroupLabelEntry();
                repeatEntry.groupKey = normalizedFieldKey;
                repeatEntry.label = label;
                result.repeatGroupLabels.add(repeatEntry);
                continue;
            }

            if (seenFieldKeys.contains(normalizedFieldKey)) {
                continue;
            }
            seenFieldKeys.add(normalizedFieldKey);

            FieldLabelEntry fieldEntry = new FieldLabelEntry();
            fieldEntry.fieldKey = normalizedFieldKey;
            fieldEntry.label = label;
            fieldEntry.elementType = elementRecord.Element_Type__c;
            result.fieldLabels.add(fieldEntry);
        }
    }
}
