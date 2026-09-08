public with sharing class NativeFormsFormKeyService {
    private static final Pattern AUTO_KEY_PATTERN = Pattern.compile('^form([0-9]+)$');

    public static void validateDescriptions(List<NF_Form__c> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        for (NF_Form__c record : records) {
            if (record == null) {
                continue;
            }
            if (String.isBlank(record.Description__c)) {
                record.Description__c.addError('Description is required.');
                continue;
            }
            record.Description__c = record.Description__c.trim();
        }
    }

    public static void ensureProjects(List<NF_Form__c> records, Boolean isInsert) {
        if (records == null || records.isEmpty()) {
            return;
        }

        Id defaultProjectId = null;
        for (NF_Form__c record : records) {
            if (record == null) {
                continue;
            }
            if (record.Project__c == null && isInsert == true) {
                if (defaultProjectId == null) {
                    defaultProjectId = NativeFormsProjectService.ensureDefaultProjectId();
                }
                record.Project__c = defaultProjectId;
            }
        }
    }

    public static void assignAutoKeys(List<NF_Form__c> newRecords) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        List<NF_Form__c> recordsNeedingKeys = new List<NF_Form__c>();
        Integer maxExistingSuffix = 0;

        for (NF_Form__c record : newRecords) {
            if (record == null) {
                continue;
            }

            if (String.isBlank(record.NF_Key__c)) {
                recordsNeedingKeys.add(record);
                continue;
            }

            maxExistingSuffix = Math.max(maxExistingSuffix, readAutoKeySuffix(record.NF_Key__c));
        }

        if (recordsNeedingKeys.isEmpty()) {
            return;
        }

        NF_Admin__c adminRecord = getLockedAdminRecord(maxExistingSuffix);
        Integer nextNumber = readSequenceFromScope(adminRecord.Scope__c);
        for (NF_Form__c record : recordsNeedingKeys) {
            nextNumber += 1;
            record.NF_Key__c = 'form' + String.valueOf(nextNumber);
        }
        adminRecord.Scope__c = sequenceScope(nextNumber);
        update as user adminRecord;
    }

    public static void reserveImportedKey(String formKey) {
        Integer importedSuffix = readAutoKeySuffix(formKey);
        if (importedSuffix <= 0) {
            return;
        }

        NF_Admin__c adminRecord = getLockedAdminRecord(0);
        Integer currentNumber = readSequenceFromScope(adminRecord.Scope__c);
        if (importedSuffix > currentNumber) {
            adminRecord.Scope__c = sequenceScope(importedSuffix);
            update as user adminRecord;
        }
    }

    private static NF_Admin__c getLockedAdminRecord(Integer minimumNumber) {
        List<NF_Admin__c> adminRecords = [
            SELECT Id, Scope__c
            FROM NF_Admin__c
            WHERE Scope__c LIKE 'ORG%'
            WITH USER_MODE
            LIMIT 1
            FOR UPDATE
        ];
        if (!adminRecords.isEmpty()) {
            NF_Admin__c existing = adminRecords[0];
            Integer currentNumber = readSequenceFromScope(existing.Scope__c);
            if (minimumNumber > currentNumber) {
                existing.Scope__c = sequenceScope(minimumNumber);
                update as user existing;
            } else if (existing.Scope__c == 'ORG') {
                existing.Scope__c = sequenceScope(currentNumber);
                update as user existing;
            }
            return existing;
        }

        Integer highestNumber = minimumNumber;
        for (NF_Form__c record : [
            SELECT NF_Key__c
            FROM NF_Form__c
            WHERE NF_Key__c LIKE 'form%'
            WITH USER_MODE
        ]) {
            highestNumber = Math.max(highestNumber, readAutoKeySuffix(record.NF_Key__c));
        }

        NF_Admin__c created = new NF_Admin__c(
            Scope__c = sequenceScope(highestNumber)
        );
        insert as user created;
        return created;
    }

    private static String sequenceScope(Integer value) {
        return 'ORG|' + String.valueOf(value == null ? 0 : value);
    }

    private static Integer readSequenceFromScope(String scope) {
        if (String.isBlank(scope)) {
            return 0;
        }
        String value = scope.startsWith('ORG|') ? scope.substringAfter('ORG|') : '0';
        try {
            return Integer.valueOf(value);
        } catch (Exception e) {
            return 0;
        }
    }

    private static Integer readAutoKeySuffix(String value) {
        if (String.isBlank(value)) {
            return 0;
        }

        Matcher matcher = AUTO_KEY_PATTERN.matcher(value.trim());
        if (!matcher.matches()) {
            return 0;
        }

        try {
            return Integer.valueOf(matcher.group(1));
        } catch (Exception e) {
            return 0;
        }
    }
}
