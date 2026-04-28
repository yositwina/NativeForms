@IsTest
private class NativeFormsDemoDataTest {
    private static final List<String> DEMO_THEME_NAMES = new List<String>{
        'Ocean Blue',
        'Deep Blue',
        'Clean Light',
        'Business Dark'
    };

    private static final List<String> DEMO_CONTACT_EMAILS = new List<String>{
        'ava.reynolds@example.com',
        'liam.carter@example.com'
    };

    private static final List<String> DEMO_CASE_SUBJECTS = new List<String>{
        'Laptop VPN issue',
        'Benefits enrollment question',
        'Software installation request',
        'Monitor replacement'
    };

    private static final List<String> DEMO_FORM_DESCRIPTIONS = new List<String>{
        'Contact details update demo',
        'Prefill multi record demo'
    };

    @IsTest
    static void homeSnapshotShowsEmptyBaselineBeforeInstall() {
        NativeFormsDemoDataService.HomeSnapshot serviceSnapshot = NativeFormsDemoDataService.getHomeSnapshot();
        NativeFormsDemoDataService.HomeSnapshot controllerSnapshot = NativeFormsDemoDataController.getHomeState();

        assertBaselineSnapshot(serviceSnapshot);
        assertBaselineSnapshot(controllerSnapshot);
    }

    @IsTest
    static void controllerFailureFormattingHelpersWork() {
        System.assertEquals('Unknown error', NativeFormsDemoDataController.formatExceptionForTest(null), 'Null exceptions should fall back to the unknown-error label.');

        String formatted = NativeFormsDemoDataController.formatExceptionForTest(new IllegalArgumentException('Example install failure'));
        System.assertEquals('Example install failure', formatted, 'Formatter should return the exception message when no distinct cause exists.');

        NativeFormsDemoDataController.forceInstallFailureForTest = true;
        try {
            NativeFormsDemoDataController.installDemoData();
            System.assert(false, 'Forced controller failure should throw AuraHandledException.');
        } catch (AuraHandledException e) {
            System.assert(String.isNotBlank(e.getMessage()), 'Controller should surface a handled exception message.');
        } finally {
            NativeFormsDemoDataController.forceInstallFailureForTest = false;
        }
    }

    @IsTest
    static void installCreatesExpectedArtifactsAndControllerState() {
        Test.startTest();
        NativeFormsDemoDataService.InstallSummary summary = NativeFormsDemoDataController.installDemoData();
        Test.stopTest();

        System.assertEquals(true, summary.success, 'Install should report success.');
        System.assertEquals(false, summary.alreadyInstalled, 'First install should not report already installed.');
        System.assertEquals(NativeFormsDemoDataService.DEMO_DATA_VERSION, summary.version, 'Install should stamp the current demo version.');
        System.assertEquals(4, summary.themeCount, 'Install should create the seeded themes.');
        System.assertEquals(2, summary.contactCount, 'Install should create the seeded contacts.');
        System.assertEquals(4, summary.caseCount, 'Install should create the seeded cases.');
        System.assertEquals(2, summary.formCount, 'Install should create the seeded forms.');
        System.assertNotEquals(null, summary.installedAt, 'Install should stamp an installed-at value.');
        System.assertEquals('Demo data installed successfully.', summary.message, 'Install should use the seeded success message.');

        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        System.assertEquals(true, config.Demo_Data_Installed__c, 'Org config should mark demo data as installed.');
        System.assertEquals(NativeFormsDemoDataService.DEMO_DATA_VERSION, config.Demo_Data_Version__c, 'Org config should store the installed version.');
        System.assertEquals('Demo data installed successfully.', config.Demo_Data_Last_Message__c, 'Org config should store the success message.');
        System.assert(String.isNotBlank(config.Demo_Data_Record_Ids__c), 'Org config should store the tracker payload.');
        System.assert(config.Demo_Data_Record_Ids__c.startsWith('T='), 'Tracker payload should use the serialized compact format.');

        System.assertEquals(4, [SELECT Count() FROM NF_Theme__c WHERE Name IN :DEMO_THEME_NAMES], 'Exactly four seeded themes should exist.');
        System.assertEquals(2, [SELECT Count() FROM Contact WHERE Email IN :DEMO_CONTACT_EMAILS], 'Exactly two seeded contacts should exist.');
        System.assertEquals(4, [SELECT Count() FROM Case WHERE Subject IN :DEMO_CASE_SUBJECTS], 'Exactly four seeded cases should exist.');
        List<NF_Form__c> demoForms = getDemoForms();
        System.assertEquals(2, demoForms.size(), 'Expected the two seeded demo forms.');
        Set<Id> demoFormIds = idsFromForms(demoForms);
        System.assertEquals(2, demoFormIds.size(), 'Exactly two seeded demo forms should exist.');
        System.assertEquals(2, [SELECT Count() FROM NF_Form_Version__c WHERE Form__c IN :demoFormIds], 'Exactly two version records should exist for the seeded forms.');
        System.assertEquals(6, [SELECT Count() FROM NF_Form_Action__c WHERE Form_Version__r.Form__c IN :demoFormIds], 'Seeded forms should create the expected action count.');
        System.assertEquals(15, [SELECT Count() FROM NF_Form_Element__c WHERE Form_Version__r.Form__c IN :demoFormIds], 'Seeded forms should create the expected element count.');

        System.assertEquals('form1', demoForms[0].NF_Key__c, 'The first demo form should get the first available auto key.');
        System.assertEquals('form2', demoForms[1].NF_Key__c, 'The second demo form should get the second available auto key.');
        for (NF_Form__c demoForm : demoForms) {
            System.assertEquals('Draft', demoForm.Status__c, 'Seeded demo forms should stay in Draft status.');
            System.assertNotEquals(null, demoForm.Theme__c, 'Each demo form should receive a seeded theme.');
            System.assertNotEquals(null, demoForm.Current_Draft_Version__c, 'Each demo form should point at its current draft version.');
        }

        NativeFormsDemoDataService.HomeSnapshot controllerSnapshot = NativeFormsDemoDataController.getHomeState();
        System.assertEquals(true, controllerSnapshot.demoDataInstalled, 'Controller home state should now report demo data as installed.');
        System.assertEquals(4, controllerSnapshot.installedThemeCount, 'Installed theme count should match seeded data.');
        System.assertEquals(2, controllerSnapshot.installedContactCount, 'Installed contact count should match seeded data.');
        System.assertEquals(4, controllerSnapshot.installedCaseCount, 'Installed case count should match seeded data.');
        System.assertEquals(2, controllerSnapshot.installedFormCount, 'Installed form count should match seeded data.');
    }

    @IsTest
    static void secondInstallReturnsAlreadyInstalledWithoutDuplicates() {
        NativeFormsDemoDataService.installDemoData();

        Test.startTest();
        NativeFormsDemoDataService.InstallSummary secondSummary = NativeFormsDemoDataService.installDemoData();
        Test.stopTest();

        System.assertEquals(true, secondSummary.success, 'Second install should still report success.');
        System.assertEquals(true, secondSummary.alreadyInstalled, 'Second install should short-circuit as already installed.');
        System.assertEquals(4, secondSummary.themeCount, 'Second install should report the seeded theme count.');
        System.assertEquals(2, secondSummary.contactCount, 'Second install should report the seeded contact count.');
        System.assertEquals(4, secondSummary.caseCount, 'Second install should report the seeded case count.');
        System.assertEquals(2, secondSummary.formCount, 'Second install should report the seeded form count.');

        System.assertEquals(4, [SELECT Count() FROM NF_Theme__c WHERE Name IN :DEMO_THEME_NAMES], 'Second install should not duplicate themes.');
        System.assertEquals(2, [SELECT Count() FROM Contact WHERE Email IN :DEMO_CONTACT_EMAILS], 'Second install should not duplicate contacts.');
        System.assertEquals(4, [SELECT Count() FROM Case WHERE Subject IN :DEMO_CASE_SUBJECTS], 'Second install should not duplicate cases.');
        Set<Id> demoFormIds = idsFromForms(getDemoForms());
        System.assertEquals(2, demoFormIds.size(), 'Second install should not duplicate forms.');
        System.assertEquals(6, [SELECT Count() FROM NF_Form_Action__c WHERE Form_Version__r.Form__c IN :demoFormIds], 'Second install should not duplicate actions.');
        System.assertEquals(15, [SELECT Count() FROM NF_Form_Element__c WHERE Form_Version__r.Form__c IN :demoFormIds], 'Second install should not duplicate elements.');
    }

    @IsTest
    static void reinstallRepairsArtifactsWhenVersionDrifts() {
        NativeFormsDemoDataService.installDemoData();

        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        config.Demo_Data_Version__c = '2.0';
        config.Demo_Data_Last_Message__c = 'Old message';
        update config;

        delete [SELECT Id FROM NF_Form_Element__c WHERE Element_Type__c = 'checkbox' LIMIT 1];
        delete [SELECT Id FROM NF_Form_Action__c WHERE Command_Key__c = 'submitAction2' LIMIT 1];

        Set<Id> demoFormIds = idsFromForms(getDemoForms());
        System.assertEquals(14, [SELECT Count() FROM NF_Form_Element__c WHERE Form_Version__r.Form__c IN :demoFormIds], 'Precondition should remove one demo element.');
        System.assertEquals(5, [SELECT Count() FROM NF_Form_Action__c WHERE Form_Version__r.Form__c IN :demoFormIds], 'Precondition should remove one demo action.');

        Test.startTest();
        NativeFormsDemoDataService.InstallSummary repairSummary = NativeFormsDemoDataService.installDemoData();
        Test.stopTest();

        System.assertEquals(true, repairSummary.success, 'Repair install should report success.');
        System.assertEquals(false, repairSummary.alreadyInstalled, 'Version drift should force reinstall rather than already-installed response.');
        System.assertEquals('Demo data installed successfully.', repairSummary.message, 'Repair install should restore the current success message.');

        config = NativeForms_Config__c.getOrgDefaults();
        System.assertEquals(NativeFormsDemoDataService.DEMO_DATA_VERSION, config.Demo_Data_Version__c, 'Repair install should stamp the current demo version again.');
        System.assertEquals('Demo data installed successfully.', config.Demo_Data_Last_Message__c, 'Repair install should refresh the stored success message.');
        demoFormIds = idsFromForms(getDemoForms());
        System.assertEquals(15, [SELECT Count() FROM NF_Form_Element__c WHERE Form_Version__r.Form__c IN :demoFormIds], 'Repair install should recreate missing demo elements.');
        System.assertEquals(6, [SELECT Count() FROM NF_Form_Action__c WHERE Form_Version__r.Form__c IN :demoFormIds], 'Repair install should recreate missing demo actions.');
        System.assertEquals(2, demoFormIds.size(), 'Repair install should reuse the seeded form rows instead of creating duplicates.');
        System.assertEquals(2, [SELECT Count() FROM NF_Form_Version__c WHERE Form__c IN :demoFormIds], 'Repair install should reuse the seeded form versions.');
    }

    @IsTest
    static void jsonTrackerSnapshotAndHigherExistingKeysAreHandled() {
        insert NativeFormsTestDataFactory.buildForm('Existing non-demo form', null, 'form9');

        NativeFormsDemoDataService.installDemoData();

        List<NF_Form__c> demoForms = getDemoForms();
        System.assertEquals('form10', demoForms[0].NF_Key__c, 'Demo install should respect the highest existing form auto key.');
        System.assertEquals('form11', demoForms[1].NF_Key__c, 'Demo install should allocate the next available form auto key.');

        List<Id> themeIds = new List<Id>();
        for (NF_Theme__c row : [SELECT Id FROM NF_Theme__c WHERE Name IN :DEMO_THEME_NAMES ORDER BY Name]) {
            themeIds.add(row.Id);
        }
        List<Id> contactIds = new List<Id>();
        for (Contact row : [SELECT Id FROM Contact WHERE Email IN :DEMO_CONTACT_EMAILS ORDER BY Email]) {
            contactIds.add(row.Id);
        }
        List<Id> caseIds = new List<Id>();
        for (Case row : [SELECT Id FROM Case WHERE Subject IN :DEMO_CASE_SUBJECTS ORDER BY Subject]) {
            caseIds.add(row.Id);
        }
        List<Id> formIds = new List<Id>();
        for (NF_Form__c row : demoForms) {
            formIds.add(row.Id);
        }

        NativeForms_Config__c config = NativeForms_Config__c.getOrgDefaults();
        config.Demo_Data_Record_Ids__c = JSON.serialize(new Map<String, Object>{
            'themeIds' => new List<String>(),
            'contactIds' => new List<String>(),
            'caseIds' => new List<String>(),
            'formIds' => idsToShortStrings(formIds)
        });
        update config;

        NativeFormsDemoDataService.HomeSnapshot snapshot = NativeFormsDemoDataService.getHomeSnapshot();
        System.assertEquals(true, snapshot.demoDataInstalled, 'JSON tracker payload should still resolve as a complete demo install.');
        System.assertEquals(4, snapshot.installedThemeCount, 'JSON tracker should still count the installed themes.');
        System.assertEquals(2, snapshot.installedContactCount, 'JSON tracker should still count the installed contacts.');
        System.assertEquals(4, snapshot.installedCaseCount, 'JSON tracker should still count the installed cases.');
        System.assertEquals(2, snapshot.installedFormCount, 'JSON tracker should still count the installed forms.');
    }

    private static void assertBaselineSnapshot(NativeFormsDemoDataService.HomeSnapshot snapshot) {
        System.assertEquals(false, snapshot.demoDataInstalled, 'Snapshot should start as not installed.');
        System.assertEquals(null, snapshot.demoDataInstalledAt, 'Snapshot should not have an install timestamp before install.');
        System.assertEquals(null, snapshot.demoDataVersion, 'Snapshot should not have a version before install.');
        System.assertEquals(null, snapshot.lastMessage, 'Snapshot should not have a message before install.');
        System.assertEquals(0, snapshot.installedThemeCount, 'No demo themes should exist yet.');
        System.assertEquals(0, snapshot.installedContactCount, 'No demo contacts should exist yet.');
        System.assertEquals(0, snapshot.installedCaseCount, 'No demo cases should exist yet.');
        System.assertEquals(0, snapshot.installedFormCount, 'No demo forms should exist yet.');
        System.assertEquals(4, snapshot.targetThemeCount, 'Theme target count should stay stable.');
        System.assertEquals(2, snapshot.targetContactCount, 'Contact target count should stay stable.');
        System.assertEquals(4, snapshot.targetCaseCount, 'Case target count should stay stable.');
        System.assertEquals(2, snapshot.targetFormCount, 'Form target count should stay stable.');
    }

    private static List<String> idsToStrings(List<Id> values) {
        List<String> results = new List<String>();
        for (Id value : values) {
            results.add(String.valueOf(value));
        }
        return results;
    }

    private static List<String> idsToShortStrings(List<Id> values) {
        List<String> results = new List<String>();
        for (Id value : values) {
            String rawValue = String.valueOf(value);
            results.add(rawValue.length() > 15 ? rawValue.substring(0, 15) : rawValue);
        }
        return results;
    }

    private static List<NF_Form__c> getDemoForms() {
        List<NF_Form__c> demoForms = new List<NF_Form__c>();
        for (NF_Form__c row : [
            SELECT Id, NF_Key__c, Description__c, Status__c, Theme__c, Enable_Captcha__c, Current_Draft_Version__c
            FROM NF_Form__c
            WHERE NF_Key__c LIKE 'form%'
            ORDER BY NF_Key__c
        ]) {
            if (DEMO_FORM_DESCRIPTIONS.contains(row.Description__c)) {
                demoForms.add(row);
            }
        }
        return demoForms;
    }

    private static Set<Id> idsFromForms(List<NF_Form__c> forms) {
        Set<Id> formIds = new Set<Id>();
        for (NF_Form__c formRecord : forms) {
            formIds.add(formRecord.Id);
        }
        return formIds;
    }
}
