public with sharing class NativeFormsDemoDataService {
    public static final String DEMO_DATA_VERSION = '2.1';
    private static final String CONTACT_UPDATE_FORM_LABEL = 'Contact details update demo';
    private static final String CASE_UPDATE_FORM_LABEL = 'Prefill multi record demo';

    public class HomeSnapshot {
        @AuraEnabled public Boolean demoDataInstalled { get; set; }
        @AuraEnabled public Datetime demoDataInstalledAt { get; set; }
        @AuraEnabled public String demoDataVersion { get; set; }
        @AuraEnabled public String lastMessage { get; set; }
        @AuraEnabled public Integer installedThemeCount { get; set; }
        @AuraEnabled public Integer installedContactCount { get; set; }
        @AuraEnabled public Integer installedCaseCount { get; set; }
        @AuraEnabled public Integer installedFormCount { get; set; }
        @AuraEnabled public Integer targetThemeCount { get; set; }
        @AuraEnabled public Integer targetContactCount { get; set; }
        @AuraEnabled public Integer targetCaseCount { get; set; }
        @AuraEnabled public Integer targetFormCount { get; set; }
    }

    public class InstallSummary {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public Boolean alreadyInstalled { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Datetime installedAt { get; set; }
        @AuraEnabled public String version { get; set; }
        @AuraEnabled public Integer themeCount { get; set; }
        @AuraEnabled public Integer contactCount { get; set; }
        @AuraEnabled public Integer caseCount { get; set; }
        @AuraEnabled public Integer formCount { get; set; }
    }

    private class DemoTracker {
        public List<Id> themeIds = new List<Id>();
        public List<Id> contactIds = new List<Id>();
        public List<Id> caseIds = new List<Id>();
        public List<Id> formIds = new List<Id>();
        public List<Id> versionIds = new List<Id>();
        public List<Id> elementIds = new List<Id>();
        public List<Id> actionIds = new List<Id>();
    }

    private class DemoFormContext {
        public NF_Form__c formRecord;
        public NF_Form_Version__c versionRecord;
    }

    private class DemoFormKeyBundle {
        public String contactUpdateKey;
        public String caseUpdateKey;
    }

    public static HomeSnapshot getHomeSnapshot() {
        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        DemoTracker tracker = collectExistingDemoTracker();
        HomeSnapshot snapshot = new HomeSnapshot();
        snapshot.demoDataInstalled = isDemoDataComplete(tracker);
        snapshot.demoDataInstalledAt = config != null ? config.Demo_Data_Installed_At__c : null;
        snapshot.demoDataVersion = config != null ? config.Demo_Data_Version__c : null;
        snapshot.lastMessage = config != null ? config.Demo_Data_Last_Message__c : null;
        snapshot.installedThemeCount = tracker.themeIds.size();
        snapshot.installedContactCount = tracker.contactIds.size();
        snapshot.installedCaseCount = tracker.caseIds.size();
        snapshot.installedFormCount = tracker.formIds.size();
        snapshot.targetThemeCount = 4;
        snapshot.targetContactCount = 2;
        snapshot.targetCaseCount = 4;
        snapshot.targetFormCount = 2;
        return snapshot;
    }

    public static InstallSummary installDemoData() {
        NativeForms_Config__c config = getOrCreateConfig();
        DemoTracker existingTracker = collectExistingDemoTracker();
        if (config.Demo_Data_Installed__c && config.Demo_Data_Version__c == DEMO_DATA_VERSION && isDemoDataComplete(existingTracker)) {
            return buildSummary(true, true, firstNonBlank(config.Demo_Data_Last_Message__c, 'Demo data is already installed.'), config.Demo_Data_Installed_At__c, existingTracker);
        }

        DemoTracker tracker = new DemoTracker();
        Map<String, NF_Theme__c> themesByName = ensureThemes(tracker);
        Map<String, Contact> contactsByEmail = ensureContacts(tracker);
        ensureCases(contactsByEmail, tracker);
        ensureDemoForms(themesByName, tracker);

        config.Demo_Data_Installed__c = true;
        config.Demo_Data_Installed_At__c = Datetime.now();
        config.Demo_Data_Version__c = DEMO_DATA_VERSION;
        config.Demo_Data_Last_Message__c = 'Demo data installed successfully.';
        config.Demo_Data_Record_Ids__c = serializeTracker(tracker);

        if (config.Id == null) {
            insert config;
        } else {
            update config;
        }
        return buildSummary(true, false, config.Demo_Data_Last_Message__c, config.Demo_Data_Installed_At__c, tracker);
    }

    private static InstallSummary buildSummary(Boolean success, Boolean alreadyInstalled, String message, Datetime installedAt, DemoTracker tracker) {
        InstallSummary summary = new InstallSummary();
        summary.success = success;
        summary.alreadyInstalled = alreadyInstalled;
        summary.message = message;
        summary.installedAt = installedAt;
        summary.version = DEMO_DATA_VERSION;
        summary.themeCount = tracker.themeIds.size();
        summary.contactCount = tracker.contactIds.size();
        summary.caseCount = tracker.caseIds.size();
        summary.formCount = tracker.formIds.size();
        return summary;
    }

    private static NativeForms_Config__c getOrCreateConfig() {
        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        if (config == null) {
            config = new NativeForms_Config__c(SetupOwnerId = UserInfo.getOrganizationId());
        }
        return config;
    }

    private static DemoTracker parseTracker(String rawTrackerJson) {
        DemoTracker tracker = new DemoTracker();
        if (String.isBlank(rawTrackerJson)) {
            return tracker;
        }
        try {
            if (rawTrackerJson.trim().startsWith('{')) {
                Map<String, Object> trackerMap = (Map<String, Object>) JSON.deserializeUntyped(rawTrackerJson);
                tracker.themeIds = toIdList(trackerMap.get('themeIds'));
                tracker.contactIds = toIdList(trackerMap.get('contactIds'));
                tracker.caseIds = toIdList(trackerMap.get('caseIds'));
                tracker.formIds = toIdList(trackerMap.get('formIds'));
            } else {
                for (String token : rawTrackerJson.split(';')) {
                    if (token.startsWith('T=')) tracker.themeIds = toIdList(token.substring(2).split(','));
                    if (token.startsWith('C=')) tracker.contactIds = toIdList(token.substring(2).split(','));
                    if (token.startsWith('S=')) tracker.caseIds = toIdList(token.substring(2).split(','));
                    if (token.startsWith('F=')) tracker.formIds = toIdList(token.substring(2).split(','));
                }
            }
        } catch (Exception e) {
            return new DemoTracker();
        }
        return tracker;
    }

    private static String serializeTracker(DemoTracker tracker) {
        return 'T=' + String.join(toStrings(tracker.themeIds), ',')
            + ';C=' + String.join(toStrings(tracker.contactIds), ',')
            + ';S=' + String.join(toStrings(tracker.caseIds), ',')
            + ';F=' + String.join(toStrings(tracker.formIds), ',');
    }

    private static List<Id> toIdList(Object rawValue) {
        List<Id> values = new List<Id>();
        if (!(rawValue instanceof List<Object>)) {
            return values;
        }
        for (Object entry : (List<Object>) rawValue) {
            if (entry != null && String.isNotBlank(String.valueOf(entry))) {
                values.add((Id) String.valueOf(entry));
            }
        }
        return values;
    }

    private static List<Id> toIdList(List<String> rawValues) {
        List<Id> values = new List<Id>();
        if (rawValues == null) {
            return values;
        }
        for (String rawValue : rawValues) {
            if (String.isNotBlank(rawValue)) {
                values.add((Id) rawValue);
            }
        }
        return values;
    }

    private static List<String> toStrings(List<Id> values) {
        List<String> output = new List<String>();
        for (Id value : values) {
            output.add(String.valueOf(value));
        }
        return output;
    }

    private static DemoTracker collectExistingDemoTracker() {
        DemoTracker tracker = new DemoTracker();
        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        DemoTracker trackedIds = config == null ? new DemoTracker() : parseTracker(config.Demo_Data_Record_Ids__c);

        for (NF_Theme__c row : [
            SELECT Id
            FROM NF_Theme__c
            WHERE Name IN ('Ocean Blue', 'Deep Blue', 'Clean Light', 'Business Dark')
        ]) {
            tracker.themeIds.add(row.Id);
        }

        Map<String, Contact> contactsByEmail = new Map<String, Contact>();
        for (Contact row : [
            SELECT Id, Email
            FROM Contact
            WHERE Email IN ('ava.reynolds@example.com', 'liam.carter@example.com')
        ]) {
            tracker.contactIds.add(row.Id);
            contactsByEmail.put(row.Email, row);
        }

        Set<Id> trackedFormIds = new Set<Id>();
        trackedFormIds.addAll(trackedIds.formIds);
        if (!trackedFormIds.isEmpty()) {
            for (NF_Form__c row : [
                SELECT Id, NF_Key__c, Description__c
                FROM NF_Form__c
                WHERE NF_Key__c LIKE 'form%'
                   OR Id IN :trackedFormIds
            ]) {
                if (row.Description__c == CONTACT_UPDATE_FORM_LABEL || row.Description__c == CASE_UPDATE_FORM_LABEL) {
                    tracker.formIds.add(row.Id);
                }
            }
        } else {
            for (NF_Form__c row : [
                SELECT Id, NF_Key__c, Description__c
                FROM NF_Form__c
                WHERE NF_Key__c LIKE 'form%'
            ]) {
                if (row.Description__c == CONTACT_UPDATE_FORM_LABEL || row.Description__c == CASE_UPDATE_FORM_LABEL) {
                    tracker.formIds.add(row.Id);
                }
            }
        }

        Set<Id> contactIds = new Set<Id>();
        contactIds.addAll(tracker.contactIds);
        if (!contactIds.isEmpty()) {
            for (Case row : [
                SELECT Id
                FROM Case
                WHERE ContactId IN :contactIds
                  AND Subject IN ('Laptop VPN issue', 'Benefits enrollment question', 'Software installation request', 'Monitor replacement')
            ]) {
                tracker.caseIds.add(row.Id);
            }
        }

        return tracker;
    }

    private static Boolean isDemoDataComplete(DemoTracker tracker) {
        return tracker != null
            && tracker.themeIds.size() >= 4
            && tracker.contactIds.size() >= 2
            && tracker.caseIds.size() >= 4
            && tracker.formIds.size() >= 2;
    }

    private static Map<String, NF_Theme__c> ensureThemes(DemoTracker tracker) {
        List<NF_Theme__c> themes = new List<NF_Theme__c>{
            theme('Ocean Blue', 'Balanced blue theme for general business forms.', 'standard', 'left', 120, '#EAF4FF', '#FFFFFF', '#B9D7F5', 'Roboto Slab', 23.04, '#17324D', 'Roboto Slab', 14.40, '#17324D', 'Open Sans', 14.40, '#17324D', '#1D4ED8', '#5F6F89', '#B42318', 14, '#FFFFFF', '#7DB2E8', 'Open Sans', 14, '#FFFFFF', '#1D4ED8', '#173EA6'),
            theme('Deep Blue', 'Stronger enterprise blue with bold contrast.', 'standard', 'left', 120, '#DCEBFA', '#FFFFFF', '#7DA8D8', 'Montserrat', 23.04, '#0F2D52', 'Montserrat', 14.40, '#0F2D52', 'Lato', 14.40, '#16324A', '#0F6CBD', '#5F6F89', '#B42318', 14, '#FFFFFF', '#6FA3E2', 'Lato', 14, '#FFFFFF', '#0F6CBD', '#0C5EA6'),
            theme('Clean Light', 'Minimal neutral theme for simple forms.', 'narrow', 'center', 110, '#F8F9FB', '#FFFFFF', '#D9DEE7', 'Merriweather', 22, '#2B2B2B', 'Merriweather', 14, '#2B2B2B', 'Source Sans Pro', 14, '#3F3F46', '#475569', '#6B7280', '#B42318', 12, '#FFFFFF', '#C7D0DD', 'Source Sans Pro', 14, '#FFFFFF', '#475569', '#334155'),
            theme('Business Dark', 'High-contrast theme for premium workflows.', 'wide', 'left', 120, '#16324A', '#203A52', '#2E5978', 'Playfair Display', 23.04, '#E5EEF8', 'Playfair Display', 14.40, '#E5EEF8', 'Inter', 14.40, '#D5DFEA', '#0EA5E9', '#B6C2CF', '#F87171', 14, '#F8FAFC', '#7EA6C6', 'Inter', 14, '#FFFFFF', '#0EA5E9', '#0284C7')
        };

        Set<String> names = new Set<String>();
        for (NF_Theme__c row : themes) {
            names.add(row.Name);
        }

        Map<String, NF_Theme__c> existingByName = new Map<String, NF_Theme__c>();
        for (NF_Theme__c row : [SELECT Id, Name FROM NF_Theme__c WHERE Name IN :names]) {
            existingByName.put(row.Name, row);
        }

        List<NF_Theme__c> toSave = new List<NF_Theme__c>();
        for (NF_Theme__c seededTheme : themes) {
            if (existingByName.containsKey(seededTheme.Name)) {
                seededTheme.Id = existingByName.get(seededTheme.Name).Id;
            }
            toSave.add(seededTheme);
        }
        upsert toSave;

        Map<String, NF_Theme__c> themesByName = new Map<String, NF_Theme__c>();
        for (NF_Theme__c row : [SELECT Id, Name FROM NF_Theme__c WHERE Name IN :names]) {
            themesByName.put(row.Name, row);
            tracker.themeIds.add(row.Id);
        }
        return themesByName;
    }

    private static Map<String, Contact> ensureContacts(DemoTracker tracker) {
        List<Contact> contacts = new List<Contact>{
            new Contact(FirstName = 'Ava', LastName = 'Reynolds', Email = 'ava.reynolds@example.com', Phone = '415-555-0101'),
            new Contact(FirstName = 'Liam', LastName = 'Carter', Email = 'liam.carter@example.com', Phone = '415-555-0102')
        };

        Set<String> emails = new Set<String>();
        for (Contact row : contacts) {
            emails.add(row.Email);
        }

        Map<String, Contact> existingByEmail = new Map<String, Contact>();
        for (Contact row : [SELECT Id, FirstName, LastName, Email, Phone, Name FROM Contact WHERE Email IN :emails]) {
            existingByEmail.put(row.Email, row);
        }

        List<Contact> toSave = new List<Contact>();
        for (Contact seededContact : contacts) {
            if (existingByEmail.containsKey(seededContact.Email)) {
                seededContact.Id = existingByEmail.get(seededContact.Email).Id;
            }
            toSave.add(seededContact);
        }
        upsert toSave;

        Map<String, Contact> contactsByEmail = new Map<String, Contact>();
        for (Contact row : [SELECT Id, FirstName, LastName, Email, Phone, Name FROM Contact WHERE Email IN :emails]) {
            contactsByEmail.put(row.Email, row);
            tracker.contactIds.add(row.Id);
        }
        return contactsByEmail;
    }

    private static void ensureCases(Map<String, Contact> contactsByEmail, DemoTracker tracker) {
        List<Case> seededCases = new List<Case>{
            new Case(ContactId = contactsByEmail.get('ava.reynolds@example.com').Id, Subject = 'Laptop VPN issue', Priority = pickPreferredPicklistValue(Case.Priority, new List<String>{ 'High', 'Medium', 'Low' }), Status = pickPreferredPicklistValue(Case.Status, new List<String>{ 'New', 'Working', 'Escalated' }), Origin = pickPreferredPicklistValue(Case.Origin, new List<String>{ 'Web', 'Email', 'Phone' }), Description = 'User cannot connect to VPN after password reset.'),
            new Case(ContactId = contactsByEmail.get('ava.reynolds@example.com').Id, Subject = 'Benefits enrollment question', Priority = pickPreferredPicklistValue(Case.Priority, new List<String>{ 'Medium', 'High', 'Low' }), Status = pickPreferredPicklistValue(Case.Status, new List<String>{ 'Working', 'New', 'Escalated' }), Origin = pickPreferredPicklistValue(Case.Origin, new List<String>{ 'Email', 'Web', 'Phone' }), Description = 'Needs help understanding medical coverage options.'),
            new Case(ContactId = contactsByEmail.get('liam.carter@example.com').Id, Subject = 'Software installation request', Priority = pickPreferredPicklistValue(Case.Priority, new List<String>{ 'Low', 'Medium', 'High' }), Status = pickPreferredPicklistValue(Case.Status, new List<String>{ 'New', 'Working', 'Escalated' }), Origin = pickPreferredPicklistValue(Case.Origin, new List<String>{ 'Phone', 'Web', 'Email' }), Description = 'Requests Adobe Acrobat installation on new laptop.'),
            new Case(ContactId = contactsByEmail.get('liam.carter@example.com').Id, Subject = 'Monitor replacement', Priority = pickPreferredPicklistValue(Case.Priority, new List<String>{ 'High', 'Medium', 'Low' }), Status = pickPreferredPicklistValue(Case.Status, new List<String>{ 'Escalated', 'Working', 'New' }), Origin = pickPreferredPicklistValue(Case.Origin, new List<String>{ 'Web', 'Email', 'Phone' }), Description = 'Second monitor intermittently disconnects during workday.')
        };

        Map<String, Case> existingByKey = new Map<String, Case>();
        Set<Id> contactIds = new Set<Id>();
        Set<String> subjects = new Set<String>();
        for (Case row : seededCases) {
            contactIds.add(row.ContactId);
            subjects.add(row.Subject);
        }
        for (Case row : [SELECT Id, ContactId, Subject FROM Case WHERE ContactId IN :contactIds AND Subject IN :subjects]) {
            existingByKey.put(buildCaseKey(row.ContactId, row.Subject), row);
        }

        List<Case> toSave = new List<Case>();
        for (Case seededCase : seededCases) {
            String caseKey = buildCaseKey(seededCase.ContactId, seededCase.Subject);
            if (existingByKey.containsKey(caseKey)) {
                seededCase.Id = existingByKey.get(caseKey).Id;
            }
            toSave.add(seededCase);
        }
        upsert toSave;

        for (Case row : [SELECT Id FROM Case WHERE ContactId IN :contactIds AND Subject IN :subjects]) {
            tracker.caseIds.add(row.Id);
        }
    }

    private static String firstNonBlank(String value, String fallbackValue) {
        return String.isBlank(value) ? fallbackValue : value;
    }

    private static void ensureDemoForms(Map<String, NF_Theme__c> themesByName, DemoTracker tracker) {
        DemoFormKeyBundle formKeys = resolveDemoFormKeys();
        DemoFormContext contactUpdate = ensureFormRecord(
            formKeys.contactUpdateKey,
            CONTACT_UPDATE_FORM_LABEL,
            'Starter demo with contact prefill by URL parameter and find-or-create contact submit.',
            themesByName.get('Clean Light'),
            true,
            'email'
        );
        clearVersionArtifacts(contactUpdate.versionRecord.Id);
        insertContactUpdateArtifacts(contactUpdate, tracker);

        DemoFormContext caseUpdate = ensureFormRecord(
            formKeys.caseUpdateKey,
            CASE_UPDATE_FORM_LABEL,
            'Starter demo with contact prefill and repeat-group case editing.',
            themesByName.get('Ocean Blue'),
            true,
            'email'
        );
        clearVersionArtifacts(caseUpdate.versionRecord.Id);
        insertCaseUpdateArtifacts(caseUpdate, tracker);
    }

    private static DemoFormContext ensureFormRecord(
        String formKey,
        String displayName,
        String description,
        NF_Theme__c themeRecord,
        Boolean captchaEnabled,
        String prefillParamKey
    ) {
        NF_Form__c formRecord;
        List<NF_Form__c> forms = [
            SELECT Id, Theme__c, Description__c, Status__c, Current_Draft_Version__c, Enable_Captcha__c, NF_Key__c
            FROM NF_Form__c
            WHERE NF_Key__c = :formKey
            ORDER BY LastModifiedDate DESC
            LIMIT 1
        ];
        if (forms.isEmpty()) {
            formRecord = new NF_Form__c(
                NF_Key__c = formKey,
                Description__c = displayName,
                Status__c = 'Draft',
                Theme__c = themeRecord != null ? themeRecord.Id : null,
                Enable_Captcha__c = captchaEnabled == true
            );
            insert formRecord;
        } else {
            formRecord = forms[0];
            formRecord.NF_Key__c = formKey;
            formRecord.Description__c = displayName;
            formRecord.Status__c = 'Draft';
            formRecord.Theme__c = themeRecord != null ? themeRecord.Id : null;
            formRecord.Enable_Captcha__c = captchaEnabled == true;
            update formRecord;
        }

        NF_Form_Version__c versionRecord;
        List<NF_Form_Version__c> versions = [SELECT Id, Form__c FROM NF_Form_Version__c WHERE Form__c = :formRecord.Id AND Version_Number__c = 1 LIMIT 1];
        if (versions.isEmpty()) {
            versionRecord = new NF_Form_Version__c(
                Form__c = formRecord.Id,
                Version_Number__c = 1,
                Version_Status__c = 'Draft',
                Publish_Status__c = 'Never Published',
                Security_Mode__c = pickPreferredPicklistValue(NF_Form_Version__c.Security_Mode__c, new List<String>{ 'secure-edit', 'public-prefill', 'public-create' }),
                Prefill_Params_JSON__c = '[{\"key\":\"' + escapeJsonValue(prefillParamKey) + '\",\"label\":\"Email\",\"required\":true}]'
            );
            insert versionRecord;
        } else {
            versionRecord = versions[0];
            versionRecord.Version_Status__c = 'Draft';
            versionRecord.Publish_Status__c = 'Never Published';
            versionRecord.Security_Mode__c = pickPreferredPicklistValue(NF_Form_Version__c.Security_Mode__c, new List<String>{ 'secure-edit', 'public-prefill', 'public-create' });
            versionRecord.Prefill_Params_JSON__c = '[{\"key\":\"' + escapeJsonValue(prefillParamKey) + '\",\"label\":\"Email\",\"required\":true}]';
            update versionRecord;
        }

        formRecord.Current_Draft_Version__c = versionRecord.Id;
        update formRecord;

        DemoFormContext context = new DemoFormContext();
        context.formRecord = formRecord;
        context.versionRecord = versionRecord;
        return context;
    }

    private static void clearVersionArtifacts(Id versionId) {
        List<NF_Form_Action__c> actions = [SELECT Id FROM NF_Form_Action__c WHERE Form_Version__c = :versionId];
        if (!actions.isEmpty()) {
            delete actions;
        }
        List<NF_Form_Element__c> elements = [SELECT Id FROM NF_Form_Element__c WHERE Form_Version__c = :versionId];
        if (!elements.isEmpty()) {
            delete elements;
        }
    }

    private static void insertContactUpdateArtifacts(DemoFormContext context, DemoTracker tracker) {
        List<NF_Form_Action__c> actions = new List<NF_Form_Action__c>{
            new NF_Form_Action__c(Form_Version__c = context.versionRecord.Id, Action_Scope__c = 'Prefill', Command_Key__c = 'prefillAction1', Command_Type__c = 'findOne', Object_Api_Name__c = 'Contact', Store_Result_As__c = 'PrefilContact', Order__c = 10, Config_JSON__c = JSON.serializePretty(new Map<String, Object>{
                'where' => 'Email = {params.email}',
                'conditions' => new List<Object>{
                    new Map<String, Object>{
                        'fieldApiName' => 'Email',
                        'operator' => 'eq',
                        'valueSource' => 'param',
                        'valueText' => 'email'
                    }
                },
                'conditionLogic' => '1',
                'conditionExpression' => '1',
                'onNotFound' => 'ignore'
            })),
            new NF_Form_Action__c(Form_Version__c = context.versionRecord.Id, Action_Scope__c = 'Submit', Command_Key__c = 'submitAction1', Command_Type__c = 'findAndUpdate', Object_Api_Name__c = 'Contact', Store_Result_As__c = 'SubmitContact', Order__c = 20, Config_JSON__c = JSON.serializePretty(new Map<String, Object>{
                'targetBy' => 'where',
                'where' => 'Email = {input.email}',
                'onNotFound' => 'create',
                'conditions' => new List<Object>{
                    new Map<String, Object>{
                        'fieldApiName' => 'Email',
                        'operator' => 'eq',
                        'valueSource' => 'field',
                        'valueText' => 'email'
                    }
                },
                'conditionLogic' => '1',
                'conditionExpression' => '1'
            }))
        };
        insert actions;

        List<NF_Form_Element__c> elements = new List<NF_Form_Element__c>{
            element(context.versionRecord.Id, 'contact_details_section', 'section', 'contactDetailsSection', 'Contact details', 10, sectionConfig(2, true, true, ''), null),
            element(context.versionRecord.Id, 'contact_first_name', 'text', 'firstName', 'First Name', 20, withSectionColumn(fieldConfig('', 'above', 'editable', false, true, 'PrefilContact', 'FirstName', true, 'submitAction1', 'FirstName'), 1), 'contact_details_section'),
            element(context.versionRecord.Id, 'contact_last_name', 'text', 'lastName', 'Last Name', 30, withSectionColumn(fieldConfig('', 'above', 'editable', true, true, 'PrefilContact', 'LastName', true, 'submitAction1', 'LastName'), 2), 'contact_details_section'),
            element(context.versionRecord.Id, 'contact_email', 'email', 'email', 'Email', 40, withSectionColumn(fieldConfig('', 'above', 'editable', false, true, 'PrefilContact', 'Email', true, 'submitAction1', 'Email'), 1), 'contact_details_section'),
            element(context.versionRecord.Id, 'contact_phone', 'tel', 'phone', 'Phone', 50, withSectionColumn(fieldConfig('', 'above', 'editable', false, true, 'PrefilContact', 'Phone', true, 'submitAction1', 'Phone'), 2), 'contact_details_section'),
            element(context.versionRecord.Id, 'contact_email_opt_in', 'checkbox', 'acceptEmails', 'I agree to accept emails', 60, withSectionColumn(checkboxConfig(false, false, false, null, null, false, null, null), 1), 'contact_details_section')
        };
        insert elements;

        tracker.formIds.add(context.formRecord.Id);
        tracker.versionIds.add(context.versionRecord.Id);
        for (NF_Form_Action__c row : actions) tracker.actionIds.add(row.Id);
        for (NF_Form_Element__c row : elements) tracker.elementIds.add(row.Id);
    }

    private static void insertCaseUpdateArtifacts(DemoFormContext context, DemoTracker tracker) {
        List<NF_Form_Action__c> actions = new List<NF_Form_Action__c>{
            new NF_Form_Action__c(Form_Version__c = context.versionRecord.Id, Action_Scope__c = 'Prefill', Command_Key__c = 'prefillAction1', Command_Type__c = 'findOne', Object_Api_Name__c = 'Contact', Store_Result_As__c = 'PrefilContact', Order__c = 10, Config_JSON__c = JSON.serializePretty(new Map<String, Object>{
                'where' => 'Email = {params.email}',
                'conditions' => new List<Object>{
                    new Map<String, Object>{
                        'fieldApiName' => 'Email',
                        'operator' => 'eq',
                        'valueSource' => 'param',
                        'valueText' => 'email'
                    }
                },
                'conditionLogic' => '1',
                'conditionExpression' => '1',
                'onNotFound' => 'ignore'
            })),
            new NF_Form_Action__c(Form_Version__c = context.versionRecord.Id, Action_Scope__c = 'Prefill', Command_Key__c = 'prefillAction2', Command_Type__c = 'findMany', Object_Api_Name__c = 'Case', Store_Result_As__c = 'PrefilCase', Order__c = 20, Config_JSON__c = JSON.serializePretty(new Map<String, Object>{
                'where' => 'ContactId = {PrefilContact.Id}',
                'conditions' => new List<Object>{
                    new Map<String, Object>{
                        'fieldApiName' => 'ContactId',
                        'operator' => 'eq',
                        'valueSource' => 'alias',
                        'valueText' => 'PrefilContact.Id'
                    }
                },
                'conditionLogic' => '1',
                'conditionExpression' => '1',
                'onNotFound' => 'ignore',
                'orderBy' => 'CreatedDate DESC',
                'limit' => 25
            })),
            new NF_Form_Action__c(Form_Version__c = context.versionRecord.Id, Action_Scope__c = 'Submit', Command_Key__c = 'submitAction1', Command_Type__c = 'findAndUpdate', Object_Api_Name__c = 'Contact', Store_Result_As__c = 'SubmitContact', Order__c = 30, Config_JSON__c = JSON.serializePretty(new Map<String, Object>{
                'targetBy' => 'where',
                'where' => 'Email = {input.email}',
                'onNotFound' => 'create',
                'conditions' => new List<Object>{
                    new Map<String, Object>{
                        'fieldApiName' => 'Email',
                        'operator' => 'eq',
                        'valueSource' => 'field',
                        'valueText' => 'email'
                    }
                },
                'conditionLogic' => '1',
                'conditionExpression' => '1'
            })),
            new NF_Form_Action__c(Form_Version__c = context.versionRecord.Id, Action_Scope__c = 'Submit', Command_Key__c = 'submitAction2', Command_Type__c = 'upsertMany', Object_Api_Name__c = 'Case', Store_Result_As__c = 'SubmitCase', Order__c = 40, Config_JSON__c = JSON.serializePretty(new Map<String, Object>{
                'repeatGroupKey' => 'caseRecords',
                'relationshipField' => 'ContactId',
                'relationshipValueSource' => 'alias',
                'relationshipValueText' => 'firstNotBlank(SubmitContact.Id, PrefilContact.Id)',
                'allowDelete' => false
            }))
        };
        insert actions;

        List<Object> priorityOptions = new List<Object>();
        for (String priorityValue : getPicklistValues(Case.Priority)) {
            priorityOptions.add(new Map<String, Object>{ 'label' => priorityValue, 'value' => priorityValue });
        }
        if (priorityOptions.isEmpty()) {
            priorityOptions.add(new Map<String, Object>{ 'label' => 'Medium', 'value' => 'Medium' });
        }

        List<NF_Form_Element__c> elements = new List<NF_Form_Element__c>{
            element(context.versionRecord.Id, 'multi_contact_section', 'section', 'contactDetailsSection', 'Contact details', 10, sectionConfig(2, true, true, ''), null),
            element(context.versionRecord.Id, 'multi_contact_first_name', 'text', 'firstName', 'First Name', 20, withSectionColumn(fieldConfig('', 'above', 'editable', false, true, 'PrefilContact', 'FirstName', true, 'submitAction1', 'FirstName'), 1), 'multi_contact_section'),
            element(context.versionRecord.Id, 'multi_contact_last_name', 'text', 'lastName', 'Last Name', 30, withSectionColumn(fieldConfig('', 'above', 'editable', true, true, 'PrefilContact', 'LastName', true, 'submitAction1', 'LastName'), 2), 'multi_contact_section'),
            element(context.versionRecord.Id, 'multi_contact_email', 'email', 'email', 'Email', 40, withSectionColumn(fieldConfig('', 'above', 'editable', false, true, 'PrefilContact', 'Email', true, 'submitAction1', 'Email'), 1), 'multi_contact_section'),
            element(context.versionRecord.Id, 'multi_contact_phone', 'tel', 'phone', 'Phone', 50, withSectionColumn(fieldConfig('', 'above', 'editable', false, true, 'PrefilContact', 'Phone', true, 'submitAction1', 'Phone'), 2), 'multi_contact_section'),
            element(context.versionRecord.Id, 'case_records_group', 'repeatGroup', 'caseRecords', 'Related Cases', 60, JSON.serializePretty(new Map<String, Object>{ 'showTitle' => true, 'boxed' => true, 'columns' => 2, 'repeatSourceAlias' => 'PrefilCase', 'allowAddRows' => true, 'allowDeleteRows' => false }), null),
            element(context.versionRecord.Id, 'case_row_subject', 'text', 'subject', 'Subject', 70, withSectionColumn(fieldConfig('', 'above', 'editable', false, true, 'PrefilCase', 'Subject', true, 'submitAction2', 'Subject'), 1), 'case_records_group'),
            element(context.versionRecord.Id, 'case_row_priority', 'select', 'priority', 'Priority', 80, withSectionColumn(selectConfig(priorityOptions, false, true, 'PrefilCase', 'Priority', true, 'submitAction2', 'Priority'), 2), 'case_records_group'),
            element(context.versionRecord.Id, 'case_row_id', 'text', 'caseId', 'Case Id', 90, withSectionColumn(fieldConfig('', 'above', 'hidden', false, true, 'PrefilCase', 'Id', true, 'submitAction2', 'Id'), 2), 'case_records_group')
        };
        insert elements;

        tracker.formIds.add(context.formRecord.Id);
        tracker.versionIds.add(context.versionRecord.Id);
        for (NF_Form_Action__c row : actions) tracker.actionIds.add(row.Id);
        for (NF_Form_Element__c row : elements) tracker.elementIds.add(row.Id);
    }

    private static NF_Form_Element__c element(Id versionId, String elementId, String elementType, String fieldKey, String label, Integer orderValue, String configJson, String parentElementId) {
        return new NF_Form_Element__c(Form_Version__c = versionId, Element_Id__c = elementId, Element_Type__c = elementType, Field_Key__c = fieldKey, Label__c = label, Config_JSON__c = configJson, Order__c = orderValue, Parent_Element_Id__c = parentElementId);
    }

    private static String sectionConfig(Integer columns, Boolean showTitle, Boolean boxed, String text) {
        return JSON.serializePretty(new Map<String, Object>{
            'columns' => columns,
            'showTitle' => showTitle,
            'boxed' => boxed,
            'text' => text
        });
    }

    private static String fieldConfig(
        String defaultValue,
        String labelPosition,
        String fieldBehavior,
        Boolean required,
        Boolean prefillEnabled,
        String prefillAlias,
        String prefillFieldPath,
        Boolean submitEnabled,
        String submitActionKey,
        String submitFieldPath
    ) {
        Map<String, Object> config = new Map<String, Object>{
            'defaultValue' => defaultValue,
            'labelPosition' => labelPosition,
            'fieldBehavior' => fieldBehavior,
            'required' => required == true
        };
        if (prefillEnabled) {
            config.put('prefillEnabled', true);
            config.put('prefillAlias', prefillAlias);
            config.put('prefillFieldPath', prefillFieldPath);
        }
        if (submitEnabled) {
            config.put('submitEnabled', true);
            config.put('submitActionKey', submitActionKey);
            config.put('submitFieldPath', submitFieldPath);
        }
        return JSON.serializePretty(config);
    }

    private static String checkboxConfig(Boolean checked, Boolean required, Boolean prefillEnabled, String prefillAlias, String prefillFieldPath, Boolean submitEnabled, String submitActionKey, String submitFieldPath) {
        Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped(fieldConfig(
            checked == true ? 'true' : 'false',
            'inline',
            'editable',
            required,
            prefillEnabled,
            prefillAlias,
            prefillFieldPath,
            submitEnabled,
            submitActionKey,
            submitFieldPath
        ));
        config.put('checked', checked == true);
        return JSON.serializePretty(config);
    }

    private static String withSectionColumn(String rawConfig, Integer sectionColumn) {
        Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped(String.isBlank(rawConfig) ? '{}' : rawConfig);
        if (sectionColumn == null || sectionColumn < 1) {
            config.remove('sectionColumn');
        } else {
            config.put('sectionColumn', sectionColumn);
        }
        return JSON.serializePretty(config);
    }

    private static String textAreaConfig(Integer rows, Boolean required, Boolean prefillEnabled, String prefillAlias, String prefillFieldPath, Boolean submitEnabled, String submitActionKey, String submitFieldPath) {
        Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped(fieldConfig('', 'above', 'editable', required, prefillEnabled, prefillAlias, prefillFieldPath, submitEnabled, submitActionKey, submitFieldPath));
        config.put('rows', rows);
        return JSON.serializePretty(config);
    }

    private static String selectConfig(List<Object> options, Boolean required, Boolean prefillEnabled, String prefillAlias, String prefillFieldPath, Boolean submitEnabled, String submitActionKey, String submitFieldPath) {
        Map<String, Object> config = (Map<String, Object>) JSON.deserializeUntyped(fieldConfig('', 'above', 'editable', required, prefillEnabled, prefillAlias, prefillFieldPath, submitEnabled, submitActionKey, submitFieldPath));
        config.put('options', options);
        if (!options.isEmpty()) {
            config.put('defaultValue', String.valueOf(((Map<String, Object>) options[0]).get('value')));
        }
        return JSON.serializePretty(config);
    }

    private static NF_Theme__c theme(String name, String description, String formWidth, String logoPosition, Decimal logoSizePx, String backgroundColor, String formBackgroundColor, String formBorderColor, String titleFont, Decimal titleFontSizePx, String titleTextColor, String sectionTitleFont, Decimal sectionTitleFontSizePx, String sectionTitleTextColor, String mainFont, Decimal mainTextSizePx, String mainTextColor, String linkTextColor, String hintTextColor, String errorColor, Decimal inputBorderRadiusPx, String inputBackgroundColor, String inputBorderColor, String buttonFont, Decimal buttonFontSizePx, String buttonTextColor, String buttonBackgroundColor, String buttonHoverBackgroundColor) {
        return new NF_Theme__c(
            Name = name,
            Description__c = description,
            Form_Width__c = pickPreferredPicklistValue(NF_Theme__c.Form_Width__c, new List<String>{ formWidth, 'wide', 'standard', 'narrow' }),
            Logo_Position__c = pickPreferredPicklistValue(NF_Theme__c.Logo_Position__c, new List<String>{ logoPosition, 'left', 'center' }),
            Logo_Size_Px__c = logoSizePx,
            Background_Color__c = backgroundColor,
            Form_Background_Color__c = formBackgroundColor,
            Form_Border_Color__c = formBorderColor,
            Title_Font__c = titleFont,
            Title_Font_Size_Px__c = titleFontSizePx,
            Title_Text_Color__c = titleTextColor,
            Section_Title_Font__c = sectionTitleFont,
            Section_Title_Font_Size_Px__c = sectionTitleFontSizePx,
            Section_Title_Text_Color__c = sectionTitleTextColor,
            Main_Font__c = mainFont,
            Main_Text_Size_Px__c = mainTextSizePx,
            Main_Text_Color__c = mainTextColor,
            Link_Text_Color__c = linkTextColor,
            Hint_Text_Color__c = hintTextColor,
            Error_Color__c = errorColor,
            Input_Border_Radius_Px__c = inputBorderRadiusPx,
            Input_Background_Color__c = inputBackgroundColor,
            Input_Border_Color__c = inputBorderColor,
            Button_Font__c = buttonFont,
            Button_Font_Size_Px__c = buttonFontSizePx,
            Button_Text_Color__c = buttonTextColor,
            Button_Background_Color__c = buttonBackgroundColor,
            Button_Hover_Background_Color__c = buttonHoverBackgroundColor
        );
    }

    private static String buildCaseKey(Id contactId, String subject) {
        return String.valueOf(contactId) + '::' + firstNonBlank(subject, '');
    }

    private static DemoFormKeyBundle resolveDemoFormKeys() {
        DemoFormKeyBundle keys = new DemoFormKeyBundle();
        Integer maxSuffix = 0;

        for (NF_Form__c row : [
            SELECT NF_Key__c
            FROM NF_Form__c
            WHERE NF_Key__c LIKE 'form%'
        ]) {
            maxSuffix = Math.max(maxSuffix, readAutoKeySuffix(row.NF_Key__c));
        }

        List<NF_Form__c> existingDemoForms = [SELECT Id, NF_Key__c, Description__c FROM NF_Form__c WHERE NF_Key__c LIKE 'form%' ORDER BY CreatedDate ASC];

        for (NF_Form__c formRecord : existingDemoForms) {
            if (String.isBlank(keys.contactUpdateKey) && formRecord.Description__c == CONTACT_UPDATE_FORM_LABEL) {
                keys.contactUpdateKey = normalizeOrAssignDemoFormKey(formRecord.NF_Key__c, maxSuffix + 1);
                maxSuffix = Math.max(maxSuffix, readAutoKeySuffix(keys.contactUpdateKey));
            } else if (String.isBlank(keys.caseUpdateKey) && formRecord.Description__c == CASE_UPDATE_FORM_LABEL) {
                keys.caseUpdateKey = normalizeOrAssignDemoFormKey(formRecord.NF_Key__c, maxSuffix + 1);
                maxSuffix = Math.max(maxSuffix, readAutoKeySuffix(keys.caseUpdateKey));
            }
        }

        if (String.isBlank(keys.contactUpdateKey)) {
            maxSuffix += 1;
            keys.contactUpdateKey = 'form' + String.valueOf(maxSuffix);
        }
        if (String.isBlank(keys.caseUpdateKey)) {
            maxSuffix += 1;
            keys.caseUpdateKey = 'form' + String.valueOf(maxSuffix);
        }

        return keys;
    }

    private static String normalizeOrAssignDemoFormKey(String rawValue, Integer fallbackSuffix) {
        Integer suffix = readAutoKeySuffix(rawValue);
        if (suffix > 0) {
            return 'form' + String.valueOf(suffix);
        }
        return 'form' + String.valueOf(fallbackSuffix == null || fallbackSuffix < 1 ? 1 : fallbackSuffix);
    }

    private static Integer readAutoKeySuffix(String value) {
        if (String.isBlank(value)) {
            return 0;
        }

        Matcher matcher = Pattern.compile('^form([0-9]+)$').matcher(value.trim().toLowerCase());
        if (!matcher.matches()) {
            return 0;
        }

        try {
            return Integer.valueOf(matcher.group(1));
        } catch (Exception e) {
            return 0;
        }
    }

    private static String escapeJsonValue(String value) {
        return String.isBlank(value) ? '' : value.replace('\\', '\\\\').replace('"', '\\"');
    }

    private static List<String> getPicklistValues(Schema.SObjectField fieldToken) {
        List<String> values = new List<String>();
        if (fieldToken == null) {
            return values;
        }
        for (Schema.PicklistEntry entry : fieldToken.getDescribe().getPicklistValues()) {
            if (entry.isActive()) {
                values.add(entry.getValue());
            }
        }
        return values;
    }

    private static String pickPreferredPicklistValue(Schema.SObjectField fieldToken, List<String> preferences) {
        List<String> activeValues = getPicklistValues(fieldToken);
        for (String preferredValue : preferences) {
            if (String.isNotBlank(preferredValue) && activeValues.contains(preferredValue)) {
                return preferredValue;
            }
        }
        return activeValues.isEmpty() ? null : activeValues[0];
    }
}
