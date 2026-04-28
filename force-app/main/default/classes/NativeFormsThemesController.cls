public with sharing class NativeFormsThemesController {
    public class ThemeOption {
        @AuraEnabled public Id value { get; set; }
        @AuraEnabled public String label { get; set; }
    }

    public class ThemeRecord {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public String logoUrl { get; set; }
        @AuraEnabled public String logoContentDocumentId { get; set; }
        @AuraEnabled public Decimal logoSizePx { get; set; }
        @AuraEnabled public String logoPosition { get; set; }
        @AuraEnabled public String formWidth { get; set; }
        @AuraEnabled public String backgroundColor { get; set; }
        @AuraEnabled public String formBackgroundColor { get; set; }
        @AuraEnabled public String formBorderColor { get; set; }
        @AuraEnabled public String titleFont { get; set; }
        @AuraEnabled public Decimal titleFontSizePx { get; set; }
        @AuraEnabled public String titleTextColor { get; set; }
        @AuraEnabled public String sectionTitleFont { get; set; }
        @AuraEnabled public Decimal sectionTitleFontSizePx { get; set; }
        @AuraEnabled public String sectionTitleTextColor { get; set; }
        @AuraEnabled public String mainFont { get; set; }
        @AuraEnabled public Decimal mainTextSizePx { get; set; }
        @AuraEnabled public String mainTextColor { get; set; }
        @AuraEnabled public String linkTextColor { get; set; }
        @AuraEnabled public String hintTextColor { get; set; }
        @AuraEnabled public String errorColor { get; set; }
        @AuraEnabled public Decimal inputBorderRadiusPx { get; set; }
        @AuraEnabled public String inputBackgroundColor { get; set; }
        @AuraEnabled public String inputBorderColor { get; set; }
        @AuraEnabled public String buttonFont { get; set; }
        @AuraEnabled public Decimal buttonFontSizePx { get; set; }
        @AuraEnabled public String buttonTextColor { get; set; }
        @AuraEnabled public String buttonBackgroundColor { get; set; }
        @AuraEnabled public String buttonHoverBackgroundColor { get; set; }
    }

    public class ThemeWorkspace {
        @AuraEnabled public List<ThemeOption> themes { get; set; }
        @AuraEnabled public Id selectedThemeId { get; set; }
        @AuraEnabled public ThemeRecord selectedTheme { get; set; }
    }

    public class UploadedLogoResult {
        @AuraEnabled public Id contentDocumentId { get; set; }
        @AuraEnabled public Id contentVersionId { get; set; }
        @AuraEnabled public String previewUrl { get; set; }
        @AuraEnabled public ThemeRecord theme { get; set; }
    }

    @AuraEnabled
    public static ThemeWorkspace getWorkspace(Id themeId) {
        ThemeWorkspace workspace = new ThemeWorkspace();
        workspace.themes = new List<ThemeOption>();

        List<NF_Theme__c> themeRows = [
            SELECT Id, Name
            FROM NF_Theme__c
            ORDER BY Name ASC, LastModifiedDate DESC
            LIMIT 200
        ];

        for (NF_Theme__c row : themeRows) {
            ThemeOption option = new ThemeOption();
            option.value = row.Id;
            option.label = row.Name;
            workspace.themes.add(option);
        }

        Id effectiveThemeId = themeId;
        if (effectiveThemeId == null && !themeRows.isEmpty()) {
            effectiveThemeId = themeRows[0].Id;
        }
        workspace.selectedThemeId = effectiveThemeId;
        if (effectiveThemeId != null) {
            workspace.selectedTheme = toThemeRecord([
                SELECT Id, Name, Description__c, Logo_URL__c, Logo_Content_Document_Id__c, Logo_Size_Px__c, Logo_Position__c,
                       Form_Width__c, Background_Color__c, Form_Background_Color__c, Form_Border_Color__c,
                       Title_Font__c, Title_Font_Size_Px__c, Title_Text_Color__c,
                       Section_Title_Font__c, Section_Title_Font_Size_Px__c, Section_Title_Text_Color__c,
                       Main_Font__c, Main_Text_Size_Px__c, Main_Text_Color__c, Link_Text_Color__c, Hint_Text_Color__c, Error_Color__c,
                       Input_Border_Radius_Px__c, Input_Background_Color__c, Input_Border_Color__c,
                       Button_Font__c, Button_Font_Size_Px__c, Button_Text_Color__c, Button_Background_Color__c, Button_Hover_Background_Color__c
                FROM NF_Theme__c
                WHERE Id = :effectiveThemeId
                LIMIT 1
            ]);
        }
        return workspace;
    }

    @AuraEnabled
    public static void ensureSampleThemes() {
        ensureStarterSampleThemes();
    }

    @AuraEnabled
    public static ThemeRecord createTheme() {
        NF_Theme__c row = new NF_Theme__c(
            Name = 'New Theme',
            Description__c = 'Starter reusable theme',
            Logo_Size_Px__c = 120,
            Logo_Position__c = 'left',
            Form_Width__c = 'wide',
            Background_Color__c = '#EEF3F8',
            Form_Background_Color__c = '#FFFFFF',
            Form_Border_Color__c = '#D5DFEA',
            Title_Font__c = 'Roboto Slab',
            Title_Font_Size_Px__c = 23.04,
            Title_Text_Color__c = '#17324D',
            Section_Title_Font__c = 'Roboto Slab',
            Section_Title_Font_Size_Px__c = 14.40,
            Section_Title_Text_Color__c = '#17324D',
            Main_Font__c = 'Inter',
            Main_Text_Size_Px__c = 14.40,
            Main_Text_Color__c = '#17324D',
            Link_Text_Color__c = '#0F6CBD',
            Hint_Text_Color__c = '#5F6F89',
            Error_Color__c = '#B42318',
            Input_Border_Radius_Px__c = 14,
            Input_Background_Color__c = '#F6FAFE',
            Input_Border_Color__c = '#C8D6E5',
            Button_Font__c = 'Inter',
            Button_Font_Size_Px__c = 14,
            Button_Text_Color__c = '#FFFFFF',
            Button_Background_Color__c = '#0F6CBD',
            Button_Hover_Background_Color__c = '#0C5EA6'
        );
        insert row;
        return getWorkspace(row.Id).selectedTheme;
    }

    @AuraEnabled
    public static ThemeRecord cloneTheme(Id themeId) {
        if (themeId == null) {
            throw new AuraHandledException('Select a theme to clone first.');
        }

        NF_Theme__c sourceRow = [
            SELECT Id, Name, Description__c, Logo_URL__c, Logo_Content_Document_Id__c, Logo_Size_Px__c, Logo_Position__c,
                   Form_Width__c, Background_Color__c, Form_Background_Color__c, Form_Border_Color__c,
                   Title_Font__c, Title_Font_Size_Px__c, Title_Text_Color__c,
                   Section_Title_Font__c, Section_Title_Font_Size_Px__c, Section_Title_Text_Color__c,
                   Main_Font__c, Main_Text_Size_Px__c, Main_Text_Color__c, Link_Text_Color__c, Hint_Text_Color__c, Error_Color__c,
                   Input_Border_Radius_Px__c, Input_Background_Color__c, Input_Border_Color__c,
                   Button_Font__c, Button_Font_Size_Px__c, Button_Text_Color__c, Button_Background_Color__c, Button_Hover_Background_Color__c
            FROM NF_Theme__c
            WHERE Id = :themeId
            LIMIT 1
        ];

        NF_Theme__c clonedRow = sourceRow.clone(false, true, false, false);
        clonedRow.Name = sourceRow.Name + ' Copy';
        insert clonedRow;
        return getWorkspace(clonedRow.Id).selectedTheme;
    }

    @AuraEnabled
    public static ThemeRecord saveTheme(String inputJson) {
        ThemeRecord inputValue = parseThemeRecord(inputJson);
        if (inputValue == null) {
            throw new AuraHandledException('Theme values are required.');
        }
        NF_Theme__c row = inputValue.id == null
            ? new NF_Theme__c()
            : [
                SELECT Id
                FROM NF_Theme__c
                WHERE Id = :inputValue.id
                LIMIT 1
            ];

        row.Name = blankToDefault(inputValue.name, 'New Theme');
        row.Description__c = inputValue.description;
        row.Logo_URL__c = inputValue.logoUrl;
        row.Logo_Content_Document_Id__c = inputValue.logoContentDocumentId;
        row.Logo_Size_Px__c = inputValue.logoSizePx;
        row.Logo_Position__c = inputValue.logoPosition;
        row.Form_Width__c = inputValue.formWidth;
        row.Background_Color__c = inputValue.backgroundColor;
        row.Form_Background_Color__c = inputValue.formBackgroundColor;
        row.Form_Border_Color__c = inputValue.formBorderColor;
        row.Title_Font__c = inputValue.titleFont;
        row.Title_Font_Size_Px__c = inputValue.titleFontSizePx;
        row.Title_Text_Color__c = inputValue.titleTextColor;
        row.Section_Title_Font__c = inputValue.sectionTitleFont;
        row.Section_Title_Font_Size_Px__c = inputValue.sectionTitleFontSizePx;
        row.Section_Title_Text_Color__c = inputValue.sectionTitleTextColor;
        row.Main_Font__c = inputValue.mainFont;
        row.Main_Text_Size_Px__c = inputValue.mainTextSizePx;
        row.Main_Text_Color__c = inputValue.mainTextColor;
        row.Link_Text_Color__c = inputValue.linkTextColor;
        row.Hint_Text_Color__c = inputValue.hintTextColor;
        row.Error_Color__c = inputValue.errorColor;
        row.Input_Border_Radius_Px__c = inputValue.inputBorderRadiusPx;
        row.Input_Background_Color__c = inputValue.inputBackgroundColor;
        row.Input_Border_Color__c = inputValue.inputBorderColor;
        row.Button_Font__c = inputValue.buttonFont;
        row.Button_Font_Size_Px__c = inputValue.buttonFontSizePx;
        row.Button_Text_Color__c = inputValue.buttonTextColor;
        row.Button_Background_Color__c = inputValue.buttonBackgroundColor;
        row.Button_Hover_Background_Color__c = inputValue.buttonHoverBackgroundColor;

        upsert row;
        return getWorkspace(row.Id).selectedTheme;
    }

    @AuraEnabled
    public static void deleteTheme(Id themeId) {
        if (themeId == null) {
            throw new AuraHandledException('Theme id is required.');
        }
        delete [
            SELECT Id
            FROM NF_Theme__c
            WHERE Id = :themeId
            LIMIT 1
        ];
    }

    @AuraEnabled
    public static UploadedLogoResult uploadLogo(Id themeId, String fileName, String base64Data) {
        if (themeId == null) {
            throw new AuraHandledException('Theme id is required before uploading a logo.');
        }
        if (String.isBlank(fileName) || String.isBlank(base64Data)) {
            throw new AuraHandledException('Choose an image file first.');
        }

        ContentVersion versionRecord = new ContentVersion(
            Title = titleFromFileName(fileName),
            PathOnClient = fileName,
            VersionData = EncodingUtil.base64Decode(base64Data),
            FirstPublishLocationId = themeId
        );
        insert versionRecord;

        versionRecord = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :versionRecord.Id
            LIMIT 1
        ];

        NF_Theme__c row = [
            SELECT Id
            FROM NF_Theme__c
            WHERE Id = :themeId
            LIMIT 1
        ];
        row.Logo_Content_Document_Id__c = String.valueOf(versionRecord.ContentDocumentId);
        row.Logo_URL__c = buildContentVersionUrl(versionRecord.Id);
        update row;

        UploadedLogoResult result = new UploadedLogoResult();
        result.contentDocumentId = versionRecord.ContentDocumentId;
        result.contentVersionId = versionRecord.Id;
        result.previewUrl = buildContentVersionUrl(versionRecord.Id);
        result.theme = getWorkspace(themeId).selectedTheme;
        return result;
    }

    private static ThemeRecord toThemeRecord(NF_Theme__c row) {
        ThemeRecord dto = new ThemeRecord();
        dto.id = row.Id;
        dto.name = row.Name;
        dto.description = row.Description__c;
        dto.logoUrl = row.Logo_URL__c;
        dto.logoContentDocumentId = row.Logo_Content_Document_Id__c;
        dto.logoSizePx = row.Logo_Size_Px__c;
        dto.logoPosition = row.Logo_Position__c;
        dto.formWidth = row.Form_Width__c;
        dto.backgroundColor = row.Background_Color__c;
        dto.formBackgroundColor = row.Form_Background_Color__c;
        dto.formBorderColor = row.Form_Border_Color__c;
        dto.titleFont = row.Title_Font__c;
        dto.titleFontSizePx = row.Title_Font_Size_Px__c;
        dto.titleTextColor = row.Title_Text_Color__c;
        dto.sectionTitleFont = row.Section_Title_Font__c;
        dto.sectionTitleFontSizePx = row.Section_Title_Font_Size_Px__c;
        dto.sectionTitleTextColor = row.Section_Title_Text_Color__c;
        dto.mainFont = row.Main_Font__c;
        dto.mainTextSizePx = row.Main_Text_Size_Px__c;
        dto.mainTextColor = row.Main_Text_Color__c;
        dto.linkTextColor = row.Link_Text_Color__c;
        dto.hintTextColor = row.Hint_Text_Color__c;
        dto.errorColor = row.Error_Color__c;
        dto.inputBorderRadiusPx = row.Input_Border_Radius_Px__c;
        dto.inputBackgroundColor = row.Input_Background_Color__c;
        dto.inputBorderColor = row.Input_Border_Color__c;
        dto.buttonFont = row.Button_Font__c;
        dto.buttonFontSizePx = row.Button_Font_Size_Px__c;
        dto.buttonTextColor = row.Button_Text_Color__c;
        dto.buttonBackgroundColor = row.Button_Background_Color__c;
        dto.buttonHoverBackgroundColor = row.Button_Hover_Background_Color__c;
        return dto;
    }

    private static String buildContentVersionUrl(Id contentVersionId) {
        return '/sfc/servlet.shepherd/version/download/' + String.valueOf(contentVersionId);
    }

    private static String titleFromFileName(String fileName) {
        if (String.isBlank(fileName)) {
            return 'TwinaForms Theme Logo';
        }
        Integer dotIndex = fileName.lastIndexOf('.');
        return dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    }

    private static String blankToDefault(String value, String fallbackValue) {
        return String.isBlank(value) ? fallbackValue : value;
    }

    private static ThemeRecord parseThemeRecord(String inputJson) {
        if (String.isBlank(inputJson)) {
            return null;
        }
        return (ThemeRecord) JSON.deserialize(inputJson, ThemeRecord.class);
    }

    private static void ensureStarterSampleThemes() {
        Set<String> expectedNames = new Set<String>{ 'Ocean Blue', 'ColorFull', 'Official' };
        Map<String, NF_Theme__c> existingByName = new Map<String, NF_Theme__c>();
        for (NF_Theme__c row : [
            SELECT Id, Name
            FROM NF_Theme__c
            WHERE Name IN :expectedNames
        ]) {
            existingByName.put(row.Name, row);
        }

        List<NF_Theme__c> toUpsert = new List<NF_Theme__c>();

        NF_Theme__c oceanBlueTheme = new NF_Theme__c(
            Name = 'Ocean Blue',
            Description__c = 'Clean blue starter theme with calm tones and rounded fields.',
            Logo_Size_Px__c = 120,
            Logo_Position__c = 'left',
            Form_Width__c = 'wide',
            Background_Color__c = '#0061C2',
            Form_Background_Color__c = '#FFFFFF',
            Form_Border_Color__c = '#D5DFEA',
            Title_Font__c = 'Roboto Slab',
            Title_Font_Size_Px__c = 23.04,
            Title_Text_Color__c = '#0061C2',
            Section_Title_Font__c = 'Roboto Slab',
            Section_Title_Font_Size_Px__c = 14.40,
            Section_Title_Text_Color__c = '#0061C2',
            Main_Font__c = 'Inter',
            Main_Text_Size_Px__c = 14.40,
            Main_Text_Color__c = '#0061C2',
            Link_Text_Color__c = '#0061C2',
            Hint_Text_Color__c = '#5F6F89',
            Error_Color__c = '#B42318',
            Input_Border_Radius_Px__c = 14,
            Input_Background_Color__c = '#F6FAFE',
            Input_Border_Color__c = '#C8D6E5',
            Button_Font__c = 'Inter',
            Button_Font_Size_Px__c = 14,
            Button_Text_Color__c = '#FFFFFF',
            Button_Background_Color__c = '#0F6CBD',
            Button_Hover_Background_Color__c = '#0C5EA6'
        );
        if (!existingByName.containsKey('Ocean Blue')) {
            toUpsert.add(oceanBlueTheme);
        } else {
            NF_Theme__c existingOceanBlue = existingByName.get('Ocean Blue');
            existingOceanBlue.Name = oceanBlueTheme.Name;
            existingOceanBlue.Description__c = oceanBlueTheme.Description__c;
            existingOceanBlue.Logo_Size_Px__c = oceanBlueTheme.Logo_Size_Px__c;
            existingOceanBlue.Logo_Position__c = oceanBlueTheme.Logo_Position__c;
            existingOceanBlue.Form_Width__c = oceanBlueTheme.Form_Width__c;
            existingOceanBlue.Background_Color__c = oceanBlueTheme.Background_Color__c;
            existingOceanBlue.Form_Background_Color__c = oceanBlueTheme.Form_Background_Color__c;
            existingOceanBlue.Form_Border_Color__c = oceanBlueTheme.Form_Border_Color__c;
            existingOceanBlue.Title_Font__c = oceanBlueTheme.Title_Font__c;
            existingOceanBlue.Title_Font_Size_Px__c = oceanBlueTheme.Title_Font_Size_Px__c;
            existingOceanBlue.Title_Text_Color__c = oceanBlueTheme.Title_Text_Color__c;
            existingOceanBlue.Section_Title_Font__c = oceanBlueTheme.Section_Title_Font__c;
            existingOceanBlue.Section_Title_Font_Size_Px__c = oceanBlueTheme.Section_Title_Font_Size_Px__c;
            existingOceanBlue.Section_Title_Text_Color__c = oceanBlueTheme.Section_Title_Text_Color__c;
            existingOceanBlue.Main_Font__c = oceanBlueTheme.Main_Font__c;
            existingOceanBlue.Main_Text_Size_Px__c = oceanBlueTheme.Main_Text_Size_Px__c;
            existingOceanBlue.Main_Text_Color__c = oceanBlueTheme.Main_Text_Color__c;
            existingOceanBlue.Link_Text_Color__c = oceanBlueTheme.Link_Text_Color__c;
            existingOceanBlue.Hint_Text_Color__c = oceanBlueTheme.Hint_Text_Color__c;
            existingOceanBlue.Error_Color__c = oceanBlueTheme.Error_Color__c;
            existingOceanBlue.Input_Border_Radius_Px__c = oceanBlueTheme.Input_Border_Radius_Px__c;
            existingOceanBlue.Input_Background_Color__c = oceanBlueTheme.Input_Background_Color__c;
            existingOceanBlue.Input_Border_Color__c = oceanBlueTheme.Input_Border_Color__c;
            existingOceanBlue.Button_Font__c = oceanBlueTheme.Button_Font__c;
            existingOceanBlue.Button_Font_Size_Px__c = oceanBlueTheme.Button_Font_Size_Px__c;
            existingOceanBlue.Button_Text_Color__c = oceanBlueTheme.Button_Text_Color__c;
            existingOceanBlue.Button_Background_Color__c = oceanBlueTheme.Button_Background_Color__c;
            existingOceanBlue.Button_Hover_Background_Color__c = oceanBlueTheme.Button_Hover_Background_Color__c;
            toUpsert.add(existingOceanBlue);
        }

        if (!existingByName.containsKey('ColorFull')) {
            toUpsert.add(new NF_Theme__c(
                Name = 'ColorFull',
                Description__c = 'Brighter theme with stronger section accents and playful button colors.',
                Logo_Size_Px__c = 120,
                Logo_Position__c = 'center',
                Form_Width__c = 'wide',
                Background_Color__c = '#FFF4E8',
                Form_Background_Color__c = '#FFFFFF',
                Form_Border_Color__c = '#F3C47E',
                Title_Font__c = 'Roboto Slab',
                Title_Font_Size_Px__c = 24,
                Title_Text_Color__c = '#8D3A00',
                Section_Title_Font__c = 'Roboto Slab',
                Section_Title_Font_Size_Px__c = 15,
                Section_Title_Text_Color__c = '#D94841',
                Main_Font__c = 'Inter',
                Main_Text_Size_Px__c = 14.40,
                Main_Text_Color__c = '#513C2C',
                Link_Text_Color__c = '#0061C2',
                Hint_Text_Color__c = '#7A6A5A',
                Error_Color__c = '#C81E1E',
                Input_Border_Radius_Px__c = 18,
                Input_Background_Color__c = '#FFF9F2',
                Input_Border_Color__c = '#F3C47E',
                Button_Font__c = 'Inter',
                Button_Font_Size_Px__c = 14,
                Button_Text_Color__c = '#FFFFFF',
                Button_Background_Color__c = '#FF7A00',
                Button_Hover_Background_Color__c = '#E96800'
            ));
        }

        if (!existingByName.containsKey('Official')) {
            toUpsert.add(new NF_Theme__c(
                Name = 'Official',
                Description__c = 'Conservative business theme for formal customer-facing forms.',
                Logo_Size_Px__c = 110,
                Logo_Position__c = 'left',
                Form_Width__c = 'standard',
                Background_Color__c = '#F5F7FA',
                Form_Background_Color__c = '#FFFFFF',
                Form_Border_Color__c = '#C9D3DF',
                Title_Font__c = 'Georgia',
                Title_Font_Size_Px__c = 22,
                Title_Text_Color__c = '#1D2B3A',
                Section_Title_Font__c = 'Georgia',
                Section_Title_Font_Size_Px__c = 14,
                Section_Title_Text_Color__c = '#1D2B3A',
                Main_Font__c = 'Inter',
                Main_Text_Size_Px__c = 14,
                Main_Text_Color__c = '#253548',
                Link_Text_Color__c = '#0F4C81',
                Hint_Text_Color__c = '#6B7888',
                Error_Color__c = '#A61B1B',
                Input_Border_Radius_Px__c = 10,
                Input_Background_Color__c = '#FFFFFF',
                Input_Border_Color__c = '#C9D3DF',
                Button_Font__c = 'Inter',
                Button_Font_Size_Px__c = 13.5,
                Button_Text_Color__c = '#FFFFFF',
                Button_Background_Color__c = '#17324D',
                Button_Hover_Background_Color__c = '#10263A'
            ));
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert;
        }
    }
}
