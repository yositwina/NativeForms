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

    public static void assignAutoKeys(List<NF_Form__c> newRecords) {
        if (newRecords == null || newRecords.isEmpty()) {
            return;
        }

        List<NF_Form__c> recordsNeedingKeys = new List<NF_Form__c>();
        Integer maxSuffix = 0;

        for (NF_Form__c record : [
            SELECT NF_Key__c
            FROM NF_Form__c
            WHERE NF_Key__c LIKE 'form%'
        ]) {
            maxSuffix = Math.max(maxSuffix, readAutoKeySuffix(record.NF_Key__c));
        }

        for (NF_Form__c record : newRecords) {
            if (record == null) {
                continue;
            }

            if (String.isBlank(record.NF_Key__c)) {
                recordsNeedingKeys.add(record);
                continue;
            }

            maxSuffix = Math.max(maxSuffix, readAutoKeySuffix(record.NF_Key__c));
        }

        for (NF_Form__c record : recordsNeedingKeys) {
            maxSuffix += 1;
            record.NF_Key__c = 'form' + String.valueOf(maxSuffix);
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
