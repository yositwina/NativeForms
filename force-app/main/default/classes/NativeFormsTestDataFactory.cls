@IsTest
public class NativeFormsTestDataFactory {
    private static Integer sequence = 1;

    private static Integer nextSequence() {
        Integer current = sequence;
        sequence += 1;
        return current;
    }

    public static NF_Project__c buildProject(String name) {
        return new NF_Project__c(
            Name = name
        );
    }

    public static NF_Project__c createProject(String name) {
        NF_Project__c projectRecord = buildProject(name);
        insert projectRecord;
        return [
            SELECT Id, Name, Description__c
            FROM NF_Project__c
            WHERE Id = :projectRecord.Id
        ];
    }

    public static NF_Theme__c createTheme(String name) {
        Integer current = nextSequence();
        NF_Theme__c themeRecord = new NF_Theme__c(
            Name = String.isBlank(name) ? 'Test Theme ' + current : name
        );
        insert themeRecord;
        return [
            SELECT Id, Name, Logo_URL__c, Form_Width__c, Background_Color__c, Form_Background_Color__c, Form_Border_Color__c,
                   Title_Font__c, Title_Font_Size_Px__c, Title_Text_Color__c,
                   Section_Title_Font__c, Section_Title_Font_Size_Px__c, Section_Title_Text_Color__c,
                   Main_Font__c, Main_Text_Size_Px__c, Main_Text_Color__c, Hint_Text_Color__c,
                   Input_Border_Radius_Px__c, Input_Background_Color__c, Input_Border_Color__c,
                   Button_Font__c, Button_Font_Size_Px__c, Button_Text_Color__c, Button_Background_Color__c
            FROM NF_Theme__c
            WHERE Id = :themeRecord.Id
        ];
    }

    public static NF_Form__c buildForm(String descriptionValue) {
        return buildForm(descriptionValue, null, null);
    }

    public static NF_Form__c buildForm(String descriptionValue, Id projectId) {
        return buildForm(descriptionValue, projectId, null);
    }

    public static NF_Form__c buildForm(String descriptionValue, Id projectId, String formKey) {
        NF_Form__c formRecord = new NF_Form__c(
            Description__c = descriptionValue
        );
        if (projectId != null) {
            formRecord.Project__c = projectId;
        }
        if (String.isNotBlank(formKey)) {
            formRecord.NF_Key__c = formKey;
        }
        return formRecord;
    }

    public static NF_Form__c createForm(String descriptionValue) {
        return createForm(descriptionValue, null, null);
    }

    public static NF_Form__c createForm(String descriptionValue, Id projectId) {
        return createForm(descriptionValue, projectId, null);
    }

    public static NF_Form__c createForm(String descriptionValue, Id projectId, String formKey) {
        NF_Form__c formRecord = buildForm(descriptionValue, projectId, formKey);
        insert formRecord;
        return [
            SELECT Id, Description__c, NF_Key__c, Project__c, Project__r.Name, Theme__c,
                   Current_Draft_Version__c, Current_Published_Version__c
            FROM NF_Form__c
            WHERE Id = :formRecord.Id
        ];
    }

    public static NF_Form_Version__c createDraftVersion(Id formId) {
        return createVersion(formId, 1, 'Draft', 'Never Published', NativeFormsTestConfigFactory.basicUiSettingsJson());
    }

    public static NF_Form_Version__c createVersion(
        Id formId,
        Decimal versionNumber,
        String versionStatus,
        String publishStatus,
        String uiSettingsJson
    ) {
        NF_Form_Version__c versionRecord = new NF_Form_Version__c(
            Form__c = formId,
            Version_Number__c = versionNumber == null ? 1 : versionNumber,
            Version_Status__c = String.isBlank(versionStatus) ? 'Draft' : versionStatus,
            Publish_Status__c = String.isBlank(publishStatus) ? 'Never Published' : publishStatus,
            Security_Mode__c = 'secure-edit',
            Prefill_Params_JSON__c = '[]',
            UI_Settings_JSON__c = String.isBlank(uiSettingsJson) ? NativeFormsTestConfigFactory.basicUiSettingsJson() : uiSettingsJson
        );
        insert versionRecord;
        return [
            SELECT Id, Name, Form__c, Version_Number__c, Version_Status__c, Publish_Status__c,
                   Security_Mode__c, Prefill_Params_JSON__c, UI_Settings_JSON__c, Custom_JS__c
            FROM NF_Form_Version__c
            WHERE Id = :versionRecord.Id
        ];
    }

    public static NF_Form__c assignCurrentVersions(Id formId, Id currentDraftVersionId, Id currentPublishedVersionId) {
        update new NF_Form__c(
            Id = formId,
            Current_Draft_Version__c = currentDraftVersionId,
            Current_Published_Version__c = currentPublishedVersionId
        );
        return [
            SELECT Id, Description__c, NF_Key__c, Project__c, Project__r.Name, Theme__c,
                   Current_Draft_Version__c, Current_Published_Version__c
            FROM NF_Form__c
            WHERE Id = :formId
        ];
    }

    public static NF_Form_Element__c createElement(
        Id versionId,
        String elementType,
        String label,
        String fieldKey,
        Integer elementIndex,
        Integer orderValue,
        String configJson,
        String parentElementId
    ) {
        Integer current = nextSequence();
        NF_Form_Element__c elementRecord = new NF_Form_Element__c(
            Form_Version__c = versionId,
            Element_Id__c = String.valueOf(elementType).toLowerCase() + '-' + current,
            Element_Type__c = elementType,
            Label__c = String.isBlank(label) ? 'Element ' + current : label,
            Field_Key__c = fieldKey,
            Element_Index__c = elementIndex == null ? current : elementIndex,
            Order__c = orderValue == null ? current * 10 : orderValue,
            Config_JSON__c = String.isBlank(configJson) ? '{}' : configJson,
            Parent_Element_Id__c = parentElementId
        );
        insert elementRecord;
        return [
            SELECT Id, Element_Id__c, Element_Type__c, Label__c, Field_Key__c, Element_Index__c,
                   Order__c, Config_JSON__c, Parent_Element_Id__c
            FROM NF_Form_Element__c
            WHERE Id = :elementRecord.Id
        ];
    }

    public static NF_Form_Action__c createAction(
        Id versionId,
        String actionScope,
        String objectApiName,
        String commandKey,
        String storeResultAs,
        String commandType,
        Integer orderValue,
        String configJson
    ) {
        Integer current = nextSequence();
        NF_Form_Action__c actionRecord = new NF_Form_Action__c(
            Form_Version__c = versionId,
            Action_Scope__c = String.isBlank(actionScope) ? 'Prefill' : actionScope,
            Object_Api_Name__c = objectApiName,
            Command_Key__c = String.isBlank(commandKey) ? 'action' + current : commandKey,
            Store_Result_As__c = storeResultAs,
            Command_Type__c = commandType,
            Order__c = orderValue == null ? current * 10 : orderValue,
            Config_JSON__c = String.isBlank(configJson) ? '{}' : configJson
        );
        insert actionRecord;
        return [
            SELECT Id, Form_Version__c, Action_Scope__c, Object_Api_Name__c, Command_Key__c,
                   Store_Result_As__c, Command_Type__c, Order__c, Config_JSON__c
            FROM NF_Form_Action__c
            WHERE Id = :actionRecord.Id
        ];
    }

    public static NF_Form_Publication__c createPublication(
        Id formId,
        Id versionId,
        String publicationStatus,
        String generatedHtmlRef
    ) {
        return createPublication(formId, versionId, publicationStatus, generatedHtmlRef, null);
    }

    public static NF_Form_Publication__c createPublication(
        Id formId,
        Id versionId,
        String publicationStatus,
        String generatedHtmlRef,
        String publishedFormId
    ) {
        NF_Form_Publication__c publicationRecord = new NF_Form_Publication__c(
            Form__c = formId,
            Form_Version__c = versionId,
            Publication_Status__c = String.isBlank(publicationStatus) ? 'Success' : publicationStatus,
            Generated_HTML_Ref__c = generatedHtmlRef,
            Published_Form_Id__c = publishedFormId,
            Published_At__c = System.now()
        );
        insert publicationRecord;
        return [
            SELECT Id, Form__c, Form_Version__c, Publication_Status__c, Generated_HTML_Ref__c, Published_Form_Id__c, Published_At__c
            FROM NF_Form_Publication__c
            WHERE Id = :publicationRecord.Id
        ];
    }

    public static List<Contact> createContacts(Integer countValue) {
        Integer safeCount = countValue == null || countValue < 0 ? 0 : countValue;
        List<Contact> contacts = new List<Contact>();
        for (Integer indexValue = 0; indexValue < safeCount; indexValue += 1) {
            Integer current = nextSequence();
            contacts.add(new Contact(
                LastName = 'NativeForms Test Contact ' + current,
                Email = 'nativeforms-test-' + current + '@example.com'
            ));
        }
        if (!contacts.isEmpty()) {
            insert contacts;
        }
        return contacts;
    }

    public static User createActiveUser(String firstNameValue, String lastNameValue) {
        Integer current = nextSequence();
        String safeFirstName = String.isBlank(firstNameValue) ? 'NativeForms' : firstNameValue.trim();
        String safeLastName = String.isBlank(lastNameValue) ? 'Test User ' + current : lastNameValue.trim();
        String uniqueSuffix = String.valueOf(System.now().getTime()) + '-' + current;
        String emailLocalPart = 'nativeforms-user-' + current;

        User userRecord = new User(
            FirstName = safeFirstName,
            LastName = safeLastName,
            Alias = ('nf' + current).left(8),
            Email = emailLocalPart + '@example.com',
            Username = emailLocalPart + '+' + uniqueSuffix + '@example.com',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = UserInfo.getProfileId()
        );
        insert userRecord;
        return [
            SELECT Id, Name, Email, IsActive
            FROM User
            WHERE Id = :userRecord.Id
        ];
    }
}
