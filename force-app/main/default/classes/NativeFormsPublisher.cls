public with sharing class NativeFormsPublisher {
    private static final String TEMP_SUBMIT_URL = 'https://hfkuwm6emqiaz2drmuip6zqn5m0agbyp.lambda-url.eu-north-1.on.aws/';

    public class PublishResult {
        @AuraEnabled public Boolean success { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public String publicUrl { get; set; }
        @AuraEnabled public String key { get; set; }
        @AuraEnabled public Id publicationId { get; set; }
    }

    @AuraEnabled
    public static PublishResult publishVersion(Id versionId) {
        PublishResult result = new PublishResult();

        NF_Form_Version__c versionRecord = [
            SELECT Id,
                   Name,
                   Form__c,
                   Form__r.Id,
                   Form__r.NF_Key__c,
                   Form__r.Status__c,
                   Form_Id__c,
                   Version_Number__c,
                   Publish_Token__c,
                   Publish_Status__c,
                   Security_Mode__c,
                   Rate_Limit_Profile__c,
                   Custom_CSS__c,
                   Custom_JS__c,
                   Theme_JSON__c,
                   UI_Settings_JSON__c
            FROM NF_Form_Version__c
            WHERE Id = :versionId
            LIMIT 1
        ];

        List<NF_Form_Element__c> elements = [
            SELECT Id,
                   Element_Id__c,
                   Element_Type__c,
                   Field_Key__c,
                   Label__c,
                   Config_JSON__c,
                   Parent_Element_Id__c,
                   Order__c
            FROM NF_Form_Element__c
            WHERE Form_Version__c = :versionId
            ORDER BY Order__c ASC, CreatedDate ASC
        ];

        List<NF_Form_Action__c> actions = [
            SELECT Id,
                   Action_Scope__c,
                   Command_Key__c,
                   Command_Type__c,
                   Object_Api_Name__c,
                   Store_Result_As__c,
                   Config_JSON__c,
                   Order__c
            FROM NF_Form_Action__c
            WHERE Form_Version__c = :versionId
            ORDER BY Order__c ASC, CreatedDate ASC
        ];

        String orgId = UserInfo.getOrganizationId().substring(0, 15);
        String formId = String.isNotBlank(versionRecord.Form_Id__c)
            ? versionRecord.Form_Id__c
            : String.isNotBlank(versionRecord.Form__r.NF_Key__c)
                ? versionRecord.Form__r.NF_Key__c
                : 'nativeforms-' + String.valueOf(versionRecord.Id).substring(0, 8);

        String publishToken = String.isNotBlank(versionRecord.Publish_Token__c)
            ? versionRecord.Publish_Token__c
            : EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(String.valueOf(versionRecord.Id) + ':' + String.valueOf(Datetime.now().getTime())))).substring(0, 32);

        String html = buildHtml(versionRecord, elements, formId, publishToken);
        String fileName = 'index.v' + String.valueOf(Datetime.now().getTime()) + '.html';

        try {
            NativeFormsAwsClient.PresignRequest presignRequest = new NativeFormsAwsClient.PresignRequest();
            presignRequest.orgId = orgId;
            presignRequest.formId = formId;
            presignRequest.versionId = (String) versionRecord.Id;
            presignRequest.fileName = fileName;
            presignRequest.contentType = 'text/html; charset=utf-8';
            presignRequest.expires = 900;

            NativeFormsAwsClient.PresignResponse presignResponse = NativeFormsAwsClient.presignHtml(presignRequest);
            NativeFormsAwsClient.uploadHtml(presignResponse.putUrl, html);

            Map<String, Object> registerPayload = new Map<String, Object>{
                'orgId' => orgId,
                'formId' => formId,
                'publishedVersionId' => (String) versionRecord.Id,
                'publishToken' => publishToken,
                'status' => 'published',
                'securityMode' => String.isNotBlank(versionRecord.Security_Mode__c) ? versionRecord.Security_Mode__c : 'public-create',
                'rateLimitProfile' => String.isNotBlank(versionRecord.Rate_Limit_Profile__c) ? versionRecord.Rate_Limit_Profile__c : 'standard',
                'generatedHtmlRef' => presignResponse.key,
                'publicUrl' => presignResponse.publicUrl,
                'prefillPolicy' => buildPolicy(filterActions(actions, 'Prefill'), elements, true),
                'submitPolicy' => buildPolicy(filterActions(actions, 'Submit'), elements, false),
                'prefillDefinition' => buildDefinition(filterActions(actions, 'Prefill'), true, elements),
                'submitDefinition' => buildDefinition(filterActions(actions, 'Submit'), false, elements)
            };

            Map<String, Object> registerResponse = NativeFormsAwsClient.registerForm(registerPayload);
            String publicationType = versionRecord.Publish_Status__c == 'Published' ? 'Republish' : 'Publish';

            NF_Form_Publication__c publicationRecord = new NF_Form_Publication__c(
                Form__c = versionRecord.Form__c,
                Form_Version__c = versionRecord.Id,
                Publication_Status__c = 'Success',
                Publication_Type__c = publicationType,
                Published_At__c = System.now(),
                Published_By__c = UserInfo.getUserId(),
                Published_Form_Id__c = formId,
                Generated_HTML_Ref__c = presignResponse.publicUrl,
                AWS_Response_JSON__c = JSON.serialize(registerResponse),
                Error_Message__c = null
            );
            insert publicationRecord;

            versionRecord.Publish_Token__c = publishToken;
            versionRecord.Publish_Status__c = 'Published';
            versionRecord.Last_Published_At__c = System.now();
            versionRecord.Last_Published_By__c = UserInfo.getUserId();
            versionRecord.Last_Publish_Error__c = null;
            update versionRecord;

            update new NF_Form__c(
                Id = versionRecord.Form__c,
                Current_Published_Version__c = versionRecord.Id,
                Status__c = 'Active'
            );

            result.success = true;
            result.publicUrl = presignResponse.publicUrl;
            result.key = presignResponse.key;
            result.publicationId = publicationRecord.Id;
            result.message = 'Published successfully.';
            return result;
        } catch (Exception e) {
            String detailedError = formatException(e);
            NF_Form_Publication__c failureRecord = new NF_Form_Publication__c(
                Form__c = versionRecord.Form__c,
                Form_Version__c = versionRecord.Id,
                Publication_Status__c = 'Failed',
                Publication_Type__c = 'Publish',
                Published_At__c = System.now(),
                Published_By__c = UserInfo.getUserId(),
                Published_Form_Id__c = formId,
                Error_Message__c = detailedError
            );
            insert failureRecord;

            versionRecord.Publish_Status__c = 'Publish Failed';
            versionRecord.Last_Publish_Error__c = detailedError;
            update versionRecord;

            result.success = false;
            result.publicationId = failureRecord.Id;
            result.message = detailedError;
            return result;
        }
    }

    private static List<NF_Form_Action__c> filterActions(List<NF_Form_Action__c> actions, String scope) {
        List<NF_Form_Action__c> filtered = new List<NF_Form_Action__c>();
        for (NF_Form_Action__c actionRecord : actions) {
            if (actionRecord.Action_Scope__c == scope) {
                filtered.add(actionRecord);
            }
        }
        return filtered;
    }

    private static Map<String, Object> buildPolicy(List<NF_Form_Action__c> actions, List<NF_Form_Element__c> elements, Boolean isPrefill) {
        Set<String> commands = new Set<String>();
        Set<String> objects = new Set<String>();
        Map<String, Set<String>> allowedWriteFields = new Map<String, Set<String>>();

        for (NF_Form_Action__c actionRecord : actions) {
            String canonicalObject = canonicalObjectApiName(actionRecord.Object_Api_Name__c);
            String normalizedType = normalizeCommandType(actionRecord.Command_Type__c, parseJsonMap(actionRecord.Config_JSON__c));

            if (String.isNotBlank(normalizedType)) {
                commands.add(normalizedType);
            }
            if (String.isNotBlank(canonicalObject)) {
                objects.add(canonicalObject);
            }

            if (!isPrefill && String.isNotBlank(actionRecord.Command_Key__c) && String.isNotBlank(canonicalObject)) {
                if (!allowedWriteFields.containsKey(canonicalObject)) {
                    allowedWriteFields.put(canonicalObject, new Set<String>());
                }
                collectAllowedWriteFields(allowedWriteFields.get(canonicalObject), actionRecord.Command_Key__c, canonicalObject, elements);
            }
        }

        Map<String, Object> policy = new Map<String, Object>{
            'allowedCommands' => new List<String>(commands),
            'allowedObjects' => new List<String>(objects)
        };
        if (!isPrefill) {
            Map<String, Object> writeFieldsOut = new Map<String, Object>();
            for (String objectApiName : allowedWriteFields.keySet()) {
                writeFieldsOut.put(objectApiName, new List<String>(allowedWriteFields.get(objectApiName)));
            }
            policy.put('allowedWriteFields', writeFieldsOut);
        }

        return policy;
    }

    private static Map<String, Object> buildDefinition(List<NF_Form_Action__c> actions, Boolean isPrefill, List<NF_Form_Element__c> elements) {
        List<Object> commands = new List<Object>();
        Map<String, Object> response = new Map<String, Object>();

        for (NF_Form_Action__c actionRecord : actions) {
            Map<String, Object> commandConfig = parseJsonMap(actionRecord.Config_JSON__c);
            String normalizedType = normalizeCommandType(actionRecord.Command_Type__c, commandConfig);
            if (String.isBlank(normalizedType)) {
                continue;
            }
            commandConfig.put('type', normalizedType);

            if (String.isNotBlank(actionRecord.Command_Key__c)) {
                commandConfig.put('commandKey', actionRecord.Command_Key__c);
            }
            String canonicalObject = canonicalObjectApiName(actionRecord.Object_Api_Name__c);
            if (String.isNotBlank(canonicalObject)) {
                commandConfig.put('objectApiName', canonicalObject);
            }
            if (String.isNotBlank(actionRecord.Store_Result_As__c)) {
                commandConfig.put('storeResultAs', actionRecord.Store_Result_As__c);
            }
            if (!isPrefill) {
                applySubmitFieldMappings(commandConfig, actionRecord, elements);
            }

            commands.add(commandConfig);
        }

        if (isPrefill) {
            return new Map<String, Object>{
                'onNotFound' => 'ignore',
                'commands' => commands,
                'responseMapping' => response
            };
        }

        return new Map<String, Object>{
            'commands' => commands
        };
    }

    private static void applySubmitFieldMappings(
        Map<String, Object> commandConfig,
        NF_Form_Action__c actionRecord,
        List<NF_Form_Element__c> elements
    ) {
        if (commandConfig == null || actionRecord == null || elements == null || elements.isEmpty()) {
            return;
        }

        Map<String, Object> fields = new Map<String, Object>();
        String actionKey = actionRecord.Command_Key__c;
        if (String.isBlank(actionKey)) {
            return;
        }

        for (NF_Form_Element__c elementRecord : elements) {
            if (elementRecord == null || String.isBlank(elementRecord.Field_Key__c) || String.isBlank(elementRecord.Config_JSON__c)) {
                continue;
            }

            Map<String, Object> elementConfig = parseJsonMap(elementRecord.Config_JSON__c);
            String submitActionKey = stringValue(elementConfig.get('submitActionKey'));
            String submitFieldPath = stringValue(elementConfig.get('submitFieldPath'));
            Boolean submitEnabled = booleanValue(elementConfig.get('submitEnabled'));

            if (!submitEnabled || String.isBlank(submitActionKey) || String.isBlank(submitFieldPath)) {
                continue;
            }
            if (submitActionKey != actionKey) {
                continue;
            }

            submitFieldPath = canonicalFieldApiName(actionRecord.Object_Api_Name__c, submitFieldPath);
            if (String.isBlank(submitFieldPath)) {
                continue;
            }

            String inputExpression = '{input.' + elementRecord.Field_Key__c + '}';
            if (String.isBlank(submitFieldPath) || String.isBlank(inputExpression)) {
                continue;
            }

            fields.put(String.valueOf(submitFieldPath), inputExpression);
        }

        if (!fields.isEmpty()) {
            commandConfig.put('fields', fields);
        }

        String normalizedType = stringValue(commandConfig.get('type'));
        if (normalizedType == 'update') {
            String recordIdSource = stringValue(commandConfig.get('recordIdSource'));
            if (String.isNotBlank(recordIdSource)) {
                commandConfig.put('id', recordIdSource);
            }
        }
    }

    private static String normalizeCommandType(String commandType, Map<String, Object> config) {
        if (String.isBlank(commandType)) {
            return null;
        }
        if (commandType == 'updateById') {
            return 'update';
        }
        if (commandType == 'findAndUpdate') {
            String whereClause = stringValue(config.get('where'));
            if (String.isBlank(whereClause)) {
                return null;
            }
            return null;
        }
        return commandType;
    }

    private static void collectAllowedWriteFields(
        Set<String> fieldNames,
        String actionKey,
        String objectApiName,
        List<NF_Form_Element__c> elements
    ) {
        if (fieldNames == null || String.isBlank(actionKey) || String.isBlank(objectApiName) || elements == null) {
            return;
        }

        for (NF_Form_Element__c elementRecord : elements) {
            if (elementRecord == null || String.isBlank(elementRecord.Config_JSON__c)) {
                continue;
            }
            Map<String, Object> elementConfig = parseJsonMap(elementRecord.Config_JSON__c);
            String submitActionKey = stringValue(elementConfig.get('submitActionKey'));
            String submitFieldPath = canonicalFieldApiName(objectApiName, stringValue(elementConfig.get('submitFieldPath')));
            Boolean submitEnabled = booleanValue(elementConfig.get('submitEnabled'));

            if (!submitEnabled || String.isBlank(submitActionKey) || String.isBlank(submitFieldPath)) {
                continue;
            }
            if (submitActionKey != actionKey) {
                continue;
            }

            fieldNames.add(submitFieldPath);
        }
    }

    private static Map<String, Object> parseJsonMap(String rawJson) {
        if (String.isBlank(rawJson)) {
            return new Map<String, Object>();
        }

        try {
            return (Map<String, Object>) JSON.deserializeUntyped(rawJson);
        } catch (Exception ignored) {
            return new Map<String, Object>();
        }
    }

    private static String buildHtml(NF_Form_Version__c versionRecord, List<NF_Form_Element__c> elements, String formId, String publishToken) {
        Map<String, Object> theme = parseJsonMap(versionRecord.Theme_JSON__c);
        Map<String, Object> uiSettings = parseJsonMap(versionRecord.UI_Settings_JSON__c);
        String titleText = firstNonBlank(
            stringValue(uiSettings.get('title')),
            stringValue(uiSettings.get('formTitle')),
            versionRecord.Form_Id__c,
            'NativeForms Form'
        );
        String introText = firstNonBlank(
            stringValue(uiSettings.get('description')),
            stringValue(uiSettings.get('introText')),
            ''
        );
        String submitLabel = firstNonBlank(
            stringValue(uiSettings.get('submitLabel')),
            'Submit'
        );

        String html = '';
        html += '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">';
        html += '<meta name="viewport" content="width=device-width, initial-scale=1.0">';
        html += '<title>' + escapeHtml(titleText) + '</title>';
        html += '<style>';
        html += ':root{';
        html += '--nf-bg:' + cssColor(theme, 'pageBackground', '#f4f7fb') + ';';
        html += '--nf-surface:' + cssColor(theme, 'cardBackground', '#ffffff') + ';';
        html += '--nf-text:' + cssColor(theme, 'textColor', '#16325c') + ';';
        html += '--nf-border:' + cssColor(theme, 'borderColor', '#d8dde6') + ';';
        html += '--nf-muted:' + cssColor(theme, 'mutedTextColor', '#5f6f89') + ';';
        html += '--nf-accent:' + cssColor(theme, 'primaryColor', '#0f6cbd') + ';';
        html += '--nf-accent-contrast:' + cssColor(theme, 'primaryTextColor', '#ffffff') + ';';
        html += '--nf-radius:' + cssLength(theme, 'borderRadius', '16px') + ';';
        html += '--nf-field-radius:' + cssLength(theme, 'fieldBorderRadius', '10px') + ';';
        html += '--nf-font:' + cssFontFamily(theme, 'fontFamily', '\'Segoe UI\', Arial, sans-serif') + ';';
        html += '}';
        html += 'body{font-family:var(--nf-font);background:linear-gradient(180deg,var(--nf-bg),#edf2f8);color:var(--nf-text);margin:0;padding:24px;}';
        html += '.nf-shell{max-width:880px;margin:0 auto;background:var(--nf-surface);border:1px solid var(--nf-border);border-radius:var(--nf-radius);padding:32px;box-shadow:0 16px 44px rgba(22,50,92,.10);}';
        html += '.nf-header{margin-bottom:24px;}';
        html += '.nf-eyebrow{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--nf-muted);font-weight:700;margin:0 0 8px;}';
        html += '.nf-header h1{margin:0;font-size:32px;line-height:1.15;}';
        html += '.nf-header p{margin:12px 0 0;color:var(--nf-muted);font-size:16px;line-height:1.6;}';
        html += '.nf-grid{display:grid;gap:16px;}';
        html += '.nf-section{padding:18px 20px;border:1px solid var(--nf-border);border-radius:calc(var(--nf-radius) - 4px);background:rgba(255,255,255,.65);}';
        html += '.nf-section h2{margin:0 0 8px;font-size:20px;}';
        html += '.nf-copy{margin:0;color:var(--nf-muted);line-height:1.6;}';
        html += '.nf-field{display:grid;gap:6px;}';
        html += '.nf-field label{display:block;font-weight:600;}';
        html += '.nf-field input,.nf-field textarea,.nf-field select{width:100%;padding:12px 14px;border:1px solid #c9d3df;border-radius:var(--nf-field-radius);font:inherit;box-sizing:border-box;background:#fff;color:var(--nf-text);}';
        html += '.nf-field textarea{min-height:120px;resize:vertical;}';
        html += '.nf-field--checkbox label{display:flex;gap:10px;align-items:center;font-weight:600;}';
        html += '.nf-field--checkbox input{width:auto;}';
        html += '.nf-status{margin-top:16px;padding:12px 14px;border-radius:12px;display:none;}';
        html += '.nf-status--success{display:block;background:#e8f6ee;color:#165b33;border:1px solid #b8e0c7;}';
        html += '.nf-status--error{display:block;background:#fde7e9;color:#7f1d1d;border:1px solid #f5c2c7;}';
        html += '.nf-actions{margin-top:28px;display:flex;justify-content:flex-end;}';
        html += '.nf-actions button{background:var(--nf-accent);color:var(--nf-accent-contrast);border:0;border-radius:999px;padding:12px 20px;font-weight:700;cursor:pointer;box-shadow:0 10px 20px rgba(15,108,189,.18);}';
        html += '.nf-meta{display:none;}';
        if (String.isNotBlank(versionRecord.Custom_CSS__c)) {
            html += versionRecord.Custom_CSS__c;
        }
        html += '</style></head><body>';
        html += '<div class="nf-shell">';
        html += '<div class="nf-header">';
        html += '<p class="nf-eyebrow">NativeForms</p>';
        html += '<h1>' + escapeHtml(titleText) + '</h1>';
        if (String.isNotBlank(introText)) {
            html += '<p>' + escapeHtml(introText) + '</p>';
        }
        html += '</div>';
        html += '<form class="nf-grid" data-nativeforms-version="' + escapeHtml(String.valueOf(versionRecord.Id)) + '">';
        html += '<input class="nf-meta" type="hidden" name="nativeformsVersionId" value="' + escapeHtml(String.valueOf(versionRecord.Id)) + '">';

        for (NF_Form_Element__c elementRecord : elements) {
            html += renderElement(elementRecord);
        }

        html += '<div class="nf-actions"><button type="submit">' + escapeHtml(submitLabel) + '</button></div>';
        html += '<div class="nf-status" data-nativeforms-status></div>';
        html += '</form></div>';
        html += '<script>window.NativeFormsConfig=' + JSON.serialize(new Map<String, Object>{
            'versionId' => (String) versionRecord.Id,
            'formId' => formId,
            'publishToken' => publishToken,
            'submitUrl' => TEMP_SUBMIT_URL,
            'theme' => theme,
            'uiSettings' => uiSettings
        }) + ';</script>';
        html += '<script>(function(){';
        html += 'const config=window.NativeFormsConfig||{};';
        html += 'const form=document.querySelector("form[data-nativeforms-version]");';
        html += 'const statusEl=document.querySelector("[data-nativeforms-status]");';
        html += 'if(!form||!config.submitUrl){return;}';
        html += 'function setStatus(kind,message){if(!statusEl){return;}statusEl.className="nf-status nf-status--"+kind;statusEl.textContent=message||"";}';
        html += 'function clearStatus(){if(!statusEl){return;}statusEl.className="nf-status";statusEl.textContent="";}';
        html += 'form.addEventListener("submit",async function(event){event.preventDefault();clearStatus();';
        html += 'const submitButton=form.querySelector("button[type=\'submit\']");if(submitButton){submitButton.disabled=true;}';
        html += 'try{const formData=new FormData(form);const input={};for(const [key,value] of formData.entries()){input[key]=value;}';
        html += 'form.querySelectorAll("input[type=\'checkbox\'][name]").forEach(function(el){input[el.name]=!!el.checked;});';
        html += 'const response=await fetch(config.submitUrl,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({formId:config.formId,publishToken:config.publishToken,input:input})});';
        html += 'const data=await response.json();';
        html += 'if(!response.ok||data.success===false){throw new Error((data.error&&data.error.message)||data.error||"Submit failed");}';
        html += 'setStatus("success","Form submitted successfully.");form.reset();';
        html += '}catch(error){setStatus("error",error&&error.message?error.message:"Submit failed.");}finally{if(submitButton){submitButton.disabled=false;}}';
        html += '});';
        html += '})();</script>';
        if (String.isNotBlank(versionRecord.Custom_JS__c)) {
            html += '<script>' + versionRecord.Custom_JS__c + '</script>';
        }
        html += '</body></html>';
        return html;
    }

    private static String renderElement(NF_Form_Element__c elementRecord) {
        Map<String, Object> config = parseJsonMap(elementRecord.Config_JSON__c);
        String typeValue = String.isBlank(elementRecord.Element_Type__c) ? 'text' : elementRecord.Element_Type__c;
        String fieldName = String.isNotBlank(elementRecord.Field_Key__c) ? elementRecord.Field_Key__c : String.valueOf(elementRecord.Id);
        String label = String.isNotBlank(elementRecord.Label__c) ? elementRecord.Label__c : fieldName;
        String placeholder = config.containsKey('placeholder') ? String.valueOf(config.get('placeholder')) : '';
        Boolean required = config.containsKey('required') ? Boolean.valueOf(String.valueOf(config.get('required'))) : false;
        String requiredAttr = required ? ' required' : '';
        String placeholderAttr = String.isNotBlank(placeholder) ? ' placeholder="' + escapeHtml(placeholder) + '"' : '';
        String safeName = escapeHtml(fieldName);
        String safeLabel = escapeHtml(label);
        String safeElementId = escapeHtml(String.isNotBlank(elementRecord.Element_Id__c) ? elementRecord.Element_Id__c : String.valueOf(elementRecord.Id));

        if (typeValue == 'section' || typeValue == 'sectionBreak') {
            String bodyText = config.containsKey('text') ? escapeHtml(String.valueOf(config.get('text'))) : '';
            String sectionHtml = '<div class="nf-section" data-element-id="' + safeElementId + '"><h2>' + safeLabel + '</h2>';
            if (String.isNotBlank(bodyText)) {
                sectionHtml += '<p class="nf-copy">' + bodyText + '</p>';
            }
            sectionHtml += '</div>';
            return sectionHtml;
        }

        if (typeValue == 'heading') {
            return '<div class="nf-section" data-element-id="' + safeElementId + '"><h2>' + safeLabel + '</h2></div>';
        }

        if (typeValue == 'paragraph' || typeValue == 'richText') {
            String bodyText = config.containsKey('text') ? escapeHtml(String.valueOf(config.get('text'))) : safeLabel;
            return '<p class="nf-copy" data-element-id="' + safeElementId + '">' + bodyText + '</p>';
        }

        if (typeValue == 'textarea') {
            return '<div class="nf-field" data-element-id="' + safeElementId + '"><label for="' + safeName + '">' + safeLabel + '</label><textarea id="' + safeName + '" name="' + safeName + '"' + placeholderAttr + requiredAttr + '></textarea></div>';
        }
        if (typeValue == 'select' && config.containsKey('options')) {
            String optionsHtml = '<option value="">Select...</option>';
            for (Object rawOption : (List<Object>) config.get('options')) {
                if (rawOption instanceof Map<String, Object>) {
                    Map<String, Object> option = (Map<String, Object>) rawOption;
                    String optionValue = escapeHtml(String.valueOf(option.get('value')));
                    String optionLabel = escapeHtml(String.valueOf(option.get('label')));
                    optionsHtml += '<option value="' + optionValue + '">' + optionLabel + '</option>';
                }
            }
            return '<div class="nf-field" data-element-id="' + safeElementId + '"><label for="' + safeName + '">' + safeLabel + '</label><select id="' + safeName + '" name="' + safeName + '"' + requiredAttr + '>' + optionsHtml + '</select></div>';
        }
        if (typeValue == 'checkbox') {
            return '<div class="nf-field nf-field--checkbox" data-element-id="' + safeElementId + '"><label><input type="checkbox" name="' + safeName + '"' + requiredAttr + '> ' + safeLabel + '</label></div>';
        }

        String htmlType = normalizeInputType(typeValue);
        return '<div class="nf-field" data-element-id="' + safeElementId + '"><label for="' + safeName + '">' + safeLabel + '</label><input type="' + escapeHtml(htmlType) + '" id="' + safeName + '" name="' + safeName + '"' + placeholderAttr + requiredAttr + '></div>';
    }

    private static String normalizeInputType(String typeValue) {
        Set<String> allowed = new Set<String>{ 'text', 'email', 'number', 'date', 'datetime-local', 'tel', 'url', 'hidden' };
        return allowed.contains(typeValue) ? typeValue : 'text';
    }

    private static String escapeHtml(String value) {
        if (value == null) {
            return '';
        }

        return value
            .replace('&', '&amp;')
            .replace('<', '&lt;')
            .replace('>', '&gt;')
            .replace('"', '&quot;')
            .replace('\'', '&#39;');
    }

    private static String stringValue(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    private static Boolean booleanValue(Object value) {
        if (value == null) {
            return false;
        }
        if (value instanceof Boolean) {
            return (Boolean) value;
        }
        String stringValue = String.valueOf(value);
        return String.isNotBlank(stringValue) && stringValue.toLowerCase() == 'true';
    }

    private static String canonicalFieldApiName(String objectApiName, String requestedFieldName) {
        if (String.isBlank(objectApiName) || String.isBlank(requestedFieldName)) {
            return requestedFieldName;
        }
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        String canonicalObjectName = canonicalObjectApiName(objectApiName);
        if (String.isBlank(canonicalObjectName) || !globalDescribe.containsKey(canonicalObjectName)) {
            return requestedFieldName;
        }

        Map<String, Schema.SObjectField> fieldsMap = globalDescribe.get(canonicalObjectName).getDescribe().fields.getMap();
        if (!fieldsMap.containsKey(requestedFieldName)) {
            return requestedFieldName;
        }

        return fieldsMap.get(requestedFieldName).getDescribe().getName();
    }

    private static String canonicalObjectApiName(String requestedObjectName) {
        if (String.isBlank(requestedObjectName)) {
            return requestedObjectName;
        }
        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (globalDescribe.containsKey(requestedObjectName)) {
            return globalDescribe.get(requestedObjectName).getDescribe().getName();
        }
        for (String apiName : globalDescribe.keySet()) {
            if (apiName != null && apiName.toLowerCase() == requestedObjectName.toLowerCase()) {
                return globalDescribe.get(apiName).getDescribe().getName();
            }
        }
        return requestedObjectName;
    }

    private static String firstNonBlank(String firstValue, String secondValue, String thirdValue, String fallbackValue) {
        List<String> candidates = new List<String>{ firstValue, secondValue, thirdValue, fallbackValue };
        for (String candidate : candidates) {
            if (String.isNotBlank(candidate)) {
                return candidate;
            }
        }
        return fallbackValue;
    }

    private static String firstNonBlank(String firstValue, String fallbackValue) {
        return String.isNotBlank(firstValue) ? firstValue : fallbackValue;
    }

    private static String firstNonBlank(String firstValue, String secondValue, String fallbackValue) {
        List<String> candidates = new List<String>{ firstValue, secondValue, fallbackValue };
        for (String candidate : candidates) {
            if (String.isNotBlank(candidate)) {
                return candidate;
            }
        }
        return fallbackValue;
    }

    private static String cssColor(Map<String, Object> source, String key, String fallbackValue) {
        String value = stringValue(source.get(key));
        return String.isNotBlank(value) ? escapeHtml(value) : fallbackValue;
    }

    private static String cssLength(Map<String, Object> source, String key, String fallbackValue) {
        String value = stringValue(source.get(key));
        return String.isNotBlank(value) ? escapeHtml(value) : fallbackValue;
    }

    private static String cssFontFamily(Map<String, Object> source, String key, String fallbackValue) {
        String value = stringValue(source.get(key));
        return String.isNotBlank(value) ? escapeHtml(value) : fallbackValue;
    }

    private static String formatException(Exception e) {
        if (e == null) {
            return 'Unknown publish error';
        }

        String message = e.getTypeName() + ': ' + e.getMessage();
        String stackTrace = e.getStackTraceString();
        if (String.isBlank(stackTrace)) {
            return message;
        }

        List<String> lines = stackTrace.split('\n');
        if (lines.isEmpty()) {
            return message;
        }

        return message + ' @ ' + lines[0].trim();
    }
}
