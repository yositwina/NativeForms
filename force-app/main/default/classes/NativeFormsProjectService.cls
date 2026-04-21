public with sharing class NativeFormsProjectService {
    public static final String DEFAULT_PROJECT_NAME = 'General';
    public static final String ARCHIVE_PROJECT_NAME = 'Archive';
    private static Id defaultProjectIdCache;
    private static Id archiveProjectIdCache;

    public static void validateNames(List<NF_Project__c> records, Map<Id, NF_Project__c> oldMap) {
        if (records == null || records.isEmpty()) {
            return;
        }

        Set<String> normalizedNames = new Set<String>();
        Map<String, Id> existingByNormalized = new Map<String, Id>();
        for (NF_Project__c existingRecord : [
            SELECT Id, Name
            FROM NF_Project__c
            WHERE Name != null
        ]) {
            String normalized = normalizeProjectName(existingRecord.Name);
            if (normalized != null) {
                existingByNormalized.put(normalized.toLowerCase(), existingRecord.Id);
            }
        }

        for (NF_Project__c record : records) {
            if (record == null) {
                continue;
            }
            String normalized = normalizeProjectName(record.Name);
            if (normalized == null) {
                record.Name.addError('Project name is required.');
                continue;
            }
            record.Name = normalized;

            Id existingId = existingByNormalized.get(normalized.toLowerCase());
            if (existingId != null && existingId != record.Id) {
                record.Name.addError('A project with this name already exists.');
                continue;
            }
            if (normalizedNames.contains(normalized.toLowerCase())) {
                record.Name.addError('A project with this name already exists.');
                continue;
            }
            normalizedNames.add(normalized.toLowerCase());
        }
    }

    public static void blockDeleteWhenFormsExist(List<NF_Project__c> records) {
        if (records == null || records.isEmpty()) {
            return;
        }
        Set<Id> projectIds = new Set<Id>();
        for (NF_Project__c record : records) {
            if (record != null && record.Id != null) {
                projectIds.add(record.Id);
            }
        }
        if (projectIds.isEmpty()) {
            return;
        }

        Map<Id, Integer> formCounts = new Map<Id, Integer>();
        for (AggregateResult row : [
            SELECT Project__c projectId, COUNT(Id) formCount
            FROM NF_Form__c
            WHERE Project__c IN :projectIds
            GROUP BY Project__c
        ]) {
            formCounts.put((Id) row.get('projectId'), (Integer) row.get('formCount'));
        }

        for (NF_Project__c record : records) {
            Integer countValue = formCounts.get(record.Id);
            if (countValue != null && countValue > 0) {
                record.addError('Reassign or remove the forms in this project before deleting it.');
            }
        }
    }

    public static Id ensureDefaultProjectAndBackfillForms() {
        Id defaultProjectId = ensureDefaultProjectId();
        List<NF_Form__c> formsToUpdate = [
            SELECT Id
            FROM NF_Form__c
            WHERE Project__c = null
            LIMIT 1000
        ];
        if (!formsToUpdate.isEmpty()) {
            for (NF_Form__c row : formsToUpdate) {
                row.Project__c = defaultProjectId;
            }
            update formsToUpdate;
        }
        return defaultProjectId;
    }

    public static Id ensureDefaultProjectId() {
        ensureSystemProjects();
        return defaultProjectIdCache;
    }

    public static Id ensureArchiveProjectId() {
        ensureSystemProjects();
        return archiveProjectIdCache;
    }

    private static void ensureSystemProjects() {
        if (defaultProjectIdCache != null && archiveProjectIdCache != null) {
            return;
        }

        Map<String, Id> existingByName = new Map<String, Id>();
        for (NF_Project__c row : [
            SELECT Id, Name
            FROM NF_Project__c
            WHERE Name IN :new List<String>{ DEFAULT_PROJECT_NAME, ARCHIVE_PROJECT_NAME }
            ORDER BY CreatedDate ASC
        ]) {
            if (!existingByName.containsKey(row.Name)) {
                existingByName.put(row.Name, row.Id);
            }
        }

        if (existingByName.containsKey(DEFAULT_PROJECT_NAME)) {
            defaultProjectIdCache = existingByName.get(DEFAULT_PROJECT_NAME);
        }
        if (existingByName.containsKey(ARCHIVE_PROJECT_NAME)) {
            archiveProjectIdCache = existingByName.get(ARCHIVE_PROJECT_NAME);
        }

        List<NF_Project__c> projectsToInsert = new List<NF_Project__c>();
        if (defaultProjectIdCache == null) {
            projectsToInsert.add(new NF_Project__c(
                Name = DEFAULT_PROJECT_NAME,
                Description__c = 'Default project for existing and uncategorized forms.'
            ));
        }
        if (archiveProjectIdCache == null) {
            projectsToInsert.add(new NF_Project__c(
                Name = ARCHIVE_PROJECT_NAME,
                Description__c = 'Reserved project for archived or inactive forms.'
            ));
        }
        if (!projectsToInsert.isEmpty()) {
            insert projectsToInsert;
            for (NF_Project__c row : projectsToInsert) {
                if (row.Name == DEFAULT_PROJECT_NAME) {
                    defaultProjectIdCache = row.Id;
                } else if (row.Name == ARCHIVE_PROJECT_NAME) {
                    archiveProjectIdCache = row.Id;
                }
            }
        }
    }

    public static Id ensureProjectByName(String projectName) {
        ensureSystemProjects();
        if (projectName == DEFAULT_PROJECT_NAME) {
            return defaultProjectIdCache;
        }
        if (projectName == ARCHIVE_PROJECT_NAME) {
            return archiveProjectIdCache;
        }

        if (defaultProjectIdCache != null) {
            // continue to query non-system projects normally
        }
        List<NF_Project__c> matches = [
            SELECT Id
            FROM NF_Project__c
            WHERE Name = :projectName
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return matches.isEmpty() ? null : matches[0].Id;
    }

    public static Id resolveProjectId(Id projectId, String newProjectName) {
        if (String.isNotBlank(newProjectName)) {
            String normalized = normalizeProjectName(newProjectName);
            if (normalized == null) {
                throw new AuraHandledException('Project name is required.');
            }
            if (ensureProjectByName(normalized) != null) {
                throw new AuraHandledException('A project with this name already exists.');
            }
            NF_Project__c newProject = new NF_Project__c(Name = normalized);
            insert newProject;
            return newProject.Id;
        }

        if (projectId != null) {
            return projectId;
        }

        return ensureDefaultProjectId();
    }

    public static String normalizeProjectName(String value) {
        String normalized = String.isBlank(value) ? null : value.trim();
        return String.isBlank(normalized) ? null : normalized;
    }
}
