global with sharing class NativeFormsAgentforceActions {
    private static final String STATUS_CREATED = 'CREATED';
    private static final String STATUS_NEEDS_LAYOUT_SELECTION = 'NEEDS_LAYOUT_SELECTION';
    private static final String STATUS_ERROR = 'ERROR';
    private static final String DEFAULT_MODE = 'secureUpdateOrCreate';
    private static final String DEFAULT_LANGUAGE = 'en';

    global class PageLayoutFormRequest {
        @InvocableVariable(
            label='Salesforce Object API Name'
            description='The Salesforce object to use as the source for the TwinaForms form, for example Contact, Account, Case, or a custom object API name.'
            required=true
        )
        global String objectApiName;

        @InvocableVariable(
            label='Page Layout Name or Key'
            description='Optional. Use this when the user has selected a layout from a previous response. You can pass either the returned layout key or the exact layout label.'
        )
        global String layoutNameOrKey;

        @InvocableVariable(
            label='TwinaForms Form Name'
            description='Optional. Name for the draft TwinaForms form. If omitted, TwinaForms creates a clear name from the object and layout.'
        )
        global String formName;

        @InvocableVariable(
            label='Language Code'
            description='Optional. Language code for Salesforce translated layout labels, for example en or he. Defaults to en.'
        )
        global String languageCode;

        @InvocableVariable(
            label='Import Mode'
            description='Optional. Defaults to secureUpdateOrCreate so the draft supports verified edit links and create fallback. Use create only for a public create-only form.'
        )
        global String mode;

        @InvocableVariable(
            label='Project Id'
            description='Optional. Existing TwinaForms Project Id for the new draft form. Leave blank to use the General project.'
        )
        global String projectId;

        @InvocableVariable(
            label='New Project Name'
            description='Optional. Create this TwinaForms Project and place the draft form inside it. Leave blank to use Project Id or the General project.'
        )
        global String newProjectName;
    }

    global class PageLayoutFormResponse {
        @InvocableVariable(
            label='Status'
            description='CREATED when a draft form was created, NEEDS_LAYOUT_SELECTION when the user must choose a layout, or ERROR when TwinaForms could not complete the request.'
        )
        global String status;

        @InvocableVariable(
            label='Message'
            description='User-safe summary of what happened and what to do next.'
        )
        global String message;

        @InvocableVariable(
            label='Object API Name'
            description='The Salesforce object used for the layout import.'
        )
        global String objectApiName;

        @InvocableVariable(
            label='Selected Layout Key'
            description='The selected page layout key. If the status is NEEDS_LAYOUT_SELECTION, pass one of the returned layout keys into Page Layout Name or Key.'
        )
        global String layoutKey;

        @InvocableVariable(
            label='Selected Layout Label'
            description='Human-readable label for the selected layout when known.'
        )
        global String layoutLabel;

        @InvocableVariable(
            label='Layout Options'
            description='Plain-text list of available layout labels and keys for the user to choose from.'
        )
        global String layoutOptions;

        @InvocableVariable(
            label='Layout Options JSON'
            description='JSON array of available layouts. Each item has label and value properties.'
        )
        global String layoutOptionsJson;

        @InvocableVariable(
            label='TwinaForms Project Id'
            description='Project Id containing the draft form when status is CREATED.'
        )
        global String projectId;

        @InvocableVariable(
            label='TwinaForms Form Id'
            description='Draft form Id when status is CREATED.'
        )
        global String formId;

        @InvocableVariable(
            label='TwinaForms Version Id'
            description='Draft version Id when status is CREATED.'
        )
        global String versionId;

        @InvocableVariable(
            label='TwinaForms Form Name'
            description='Name of the draft form when status is CREATED.'
        )
        global String formName;

        @InvocableVariable(
            label='Designer URL'
            description='Relative Salesforce URL for opening the TwinaForms Designer tab.'
        )
        global String designerUrl;

        @InvocableVariable(
            label='Imported Field Count'
            description='Number of supported Salesforce layout fields imported into the draft form.'
        )
        global Integer importedFieldCount;

        @InvocableVariable(
            label='Skipped Field Count'
            description='Number of Salesforce layout fields skipped because they are unsupported or not editable for the selected mode.'
        )
        global Integer skippedFieldCount;

        @InvocableVariable(
            label='Warnings'
            description='Warnings from the TwinaForms page-layout import, if any.'
        )
        global String warnings;
    }

    @InvocableMethod(
        label='Create TwinaForms Form from Page Layout'
        description='Creates a draft TwinaForms form from a Salesforce object page layout. If more than one layout is available, returns layout choices so Agentforce can ask the user which layout to use before creating the draft.'
        category='TwinaForms'
    )
    global static List<PageLayoutFormResponse> createFormFromPageLayout(List<PageLayoutFormRequest> requests) {
        List<PageLayoutFormResponse> responses = new List<PageLayoutFormResponse>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        for (PageLayoutFormRequest request : requests) {
            responses.add(handleRequest(request));
        }
        return responses;
    }

    private static PageLayoutFormResponse handleRequest(PageLayoutFormRequest request) {
        PageLayoutFormResponse response = new PageLayoutFormResponse();
        response.status = STATUS_ERROR;

        try {
            if (request == null || String.isBlank(request.objectApiName)) {
                response.message = 'Tell TwinaForms which Salesforce object to use, for example Contact.';
                return response;
            }

            String objectApiName = request.objectApiName.trim();
            String languageCode = String.isBlank(request.languageCode) ? DEFAULT_LANGUAGE : request.languageCode.trim();
            String mode = String.isBlank(request.mode) ? DEFAULT_MODE : request.mode.trim();
            response.objectApiName = objectApiName;

            List<NativeFormsDesignerController.SelectOption> layouts =
                NativeFormsDesignerController.getPageLayoutImportOptions(objectApiName, languageCode);
            if (layouts.isEmpty()) {
                response.message = 'TwinaForms could not find a Salesforce page layout for ' + objectApiName + '.';
                return response;
            }

            response.layoutOptions = formatLayoutOptions(layouts);
            response.layoutOptionsJson = JSON.serialize(layouts);

            NativeFormsDesignerController.SelectOption selectedLayout =
                resolveSelectedLayout(layouts, request.layoutNameOrKey);
            if (selectedLayout == null && layouts.size() > 1) {
                response.status = STATUS_NEEDS_LAYOUT_SELECTION;
                response.message = 'I found more than one Salesforce page layout for ' + objectApiName + '. Ask the user to choose one of these layouts, then call this action again with the selected layout key.';
                return response;
            }
            if (selectedLayout == null) {
                selectedLayout = layouts[0];
            }

            response.layoutKey = selectedLayout.value;
            response.layoutLabel = selectedLayout.label;
            String formName = String.isBlank(request.formName)
                ? buildDefaultFormName(objectApiName, selectedLayout.label)
                : request.formName.trim();

            NativeFormsDesignerController.NewFormResult result =
                NativeFormsDesignerController.createFormFromPageLayout(
                    formName,
                    parseOptionalId(request.projectId, 'Project Id'),
                    request.newProjectName,
                    null,
                    objectApiName,
                    selectedLayout.value,
                    mode,
                    languageCode,
                    null
                );

            response.status = STATUS_CREATED;
            response.projectId = String.valueOf(result.projectId);
            response.formId = String.valueOf(result.formId);
            response.versionId = String.valueOf(result.versionId);
            response.formName = result.formName;
            response.importedFieldCount = result.importedFieldCount;
            response.skippedFieldCount = result.skippedFieldCount;
            response.warnings = joinWarnings(result.warnings);
            response.designerUrl = '/lightning/n/NativeForms_Designer';
            response.message = 'Created the draft TwinaForms form "' + result.formName + '" from the ' + selectedLayout.label + ' page layout. Open TwinaForms Designer to review it before publishing.';
        } catch (Exception e) {
            response.status = STATUS_ERROR;
            response.message = String.isBlank(e.getMessage())
                ? 'TwinaForms could not create the draft form from this Salesforce page layout.'
                : e.getMessage();
        }

        return response;
    }

    private static NativeFormsDesignerController.SelectOption resolveSelectedLayout(
        List<NativeFormsDesignerController.SelectOption> layouts,
        String layoutNameOrKey
    ) {
        if (layouts == null || layouts.isEmpty() || String.isBlank(layoutNameOrKey)) {
            return null;
        }
        String normalized = layoutNameOrKey.trim().toLowerCase();
        for (NativeFormsDesignerController.SelectOption option : layouts) {
            if (option == null) {
                continue;
            }
            if (String.isNotBlank(option.value) && option.value.trim().toLowerCase() == normalized) {
                return option;
            }
            if (String.isNotBlank(option.label) && option.label.trim().toLowerCase() == normalized) {
                return option;
            }
        }
        return null;
    }

    private static String formatLayoutOptions(List<NativeFormsDesignerController.SelectOption> layouts) {
        List<String> lines = new List<String>();
        for (NativeFormsDesignerController.SelectOption option : layouts) {
            if (option == null || String.isBlank(option.value)) {
                continue;
            }
            String label = String.isBlank(option.label) ? option.value : option.label;
            lines.add(label + ' | key: ' + option.value);
        }
        return String.join(lines, '\n');
    }

    private static String buildDefaultFormName(String objectApiName, String layoutLabel) {
        String source = String.isBlank(layoutLabel) ? objectApiName : layoutLabel;
        return 'TwinaForms ' + source + ' Form';
    }

    private static Id parseOptionalId(String value, String label) {
        if (String.isBlank(value)) {
            return null;
        }
        String normalized = value.trim();
        if (!Pattern.matches('^[a-zA-Z0-9]{15}(?:[a-zA-Z0-9]{3})?$', normalized)) {
            throw new AuraHandledException(label + ' must be a valid Salesforce Id.');
        }
        return (Id) normalized;
    }

    private static String joinWarnings(List<String> warnings) {
        return warnings == null || warnings.isEmpty() ? '' : String.join(warnings, '\n');
    }
}
