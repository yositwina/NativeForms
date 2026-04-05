public with sharing class NativeFormsPublisher {
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

        String html = buildHtml(versionRecord, elements);
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
                'prefillPolicy' => buildPolicy(filterActions(actions, 'Prefill')),
                'submitPolicy' => buildPolicy(filterActions(actions, 'Submit')),
                'prefillDefinition' => buildDefinition(filterActions(actions, 'Prefill'), true),
                'submitDefinition' => buildDefinition(filterActions(actions, 'Submit'), false)
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
            NF_Form_Publication__c failureRecord = new NF_Form_Publication__c(
                Form__c = versionRecord.Form__c,
                Form_Version__c = versionRecord.Id,
                Publication_Status__c = 'Failed',
                Publication_Type__c = 'Publish',
                Published_At__c = System.now(),
                Published_By__c = UserInfo.getUserId(),
                Published_Form_Id__c = formId,
                Error_Message__c = e.getMessage()
            );
            insert failureRecord;

            versionRecord.Publish_Status__c = 'Publish Failed';
            versionRecord.Last_Publish_Error__c = e.getMessage();
            update versionRecord;

            result.success = false;
            result.publicationId = failureRecord.Id;
            result.message = e.getMessage();
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

    private static Map<String, Object> buildPolicy(List<NF_Form_Action__c> actions) {
        Set<String> commands = new Set<String>();
        Set<String> objects = new Set<String>();

        for (NF_Form_Action__c actionRecord : actions) {
            if (String.isNotBlank(actionRecord.Command_Type__c)) {
                commands.add(actionRecord.Command_Type__c);
            }
            if (String.isNotBlank(actionRecord.Object_Api_Name__c)) {
                objects.add(actionRecord.Object_Api_Name__c);
            }
        }

        return new Map<String, Object>{
            'allowedCommands' => new List<String>(commands),
            'allowedObjects' => new List<String>(objects)
        };
    }

    private static Map<String, Object> buildDefinition(List<NF_Form_Action__c> actions, Boolean isPrefill) {
        List<Object> commands = new List<Object>();
        Map<String, Object> response = new Map<String, Object>();

        for (NF_Form_Action__c actionRecord : actions) {
            Map<String, Object> commandConfig = parseJsonMap(actionRecord.Config_JSON__c);
            commandConfig.put('type', actionRecord.Command_Type__c);

            if (String.isNotBlank(actionRecord.Command_Key__c)) {
                commandConfig.put('commandKey', actionRecord.Command_Key__c);
            }
            if (String.isNotBlank(actionRecord.Object_Api_Name__c)) {
                commandConfig.put('objectApiName', actionRecord.Object_Api_Name__c);
            }
            if (String.isNotBlank(actionRecord.Store_Result_As__c)) {
                commandConfig.put('storeResultAs', actionRecord.Store_Result_As__c);
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

    private static String buildHtml(NF_Form_Version__c versionRecord, List<NF_Form_Element__c> elements) {
        String html = '';
        html += '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">';
        html += '<meta name="viewport" content="width=device-width, initial-scale=1.0">';
        html += '<title>' + escapeHtml(versionRecord.Form_Id__c) + '</title>';
        html += '<style>';
        html += 'body{font-family:Arial,sans-serif;background:#f4f7fb;color:#16325c;margin:0;padding:24px;}';
        html += '.nf-shell{max-width:880px;margin:0 auto;background:#fff;border:1px solid #d8dde6;border-radius:16px;padding:24px;box-shadow:0 8px 24px rgba(22,50,92,.08);}';
        html += '.nf-grid{display:grid;gap:16px;}';
        html += '.nf-field label{display:block;font-weight:600;margin-bottom:6px;}';
        html += '.nf-field input,.nf-field textarea,.nf-field select{width:100%;padding:10px 12px;border:1px solid #c9d3df;border-radius:10px;font:inherit;box-sizing:border-box;}';
        html += '.nf-actions{margin-top:24px;display:flex;justify-content:flex-end;}';
        html += '.nf-actions button{background:#0f6cbd;color:#fff;border:0;border-radius:999px;padding:12px 20px;font-weight:700;cursor:pointer;}';
        if (String.isNotBlank(versionRecord.Custom_CSS__c)) {
            html += versionRecord.Custom_CSS__c;
        }
        html += '</style></head><body>';
        html += '<div class="nf-shell">';
        html += '<h1>' + escapeHtml(String.isNotBlank(versionRecord.Form_Id__c) ? versionRecord.Form_Id__c : 'NativeForms Form') + '</h1>';
        html += '<form class="nf-grid" data-nativeforms-version="' + escapeHtml(String.valueOf(versionRecord.Id)) + '">';

        for (NF_Form_Element__c elementRecord : elements) {
            html += renderElement(elementRecord);
        }

        html += '<div class="nf-actions"><button type="submit">Submit</button></div>';
        html += '</form></div>';
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

        if (typeValue == 'textarea') {
            return '<div class="nf-field"><label for="' + safeName + '">' + safeLabel + '</label><textarea id="' + safeName + '" name="' + safeName + '"' + placeholderAttr + requiredAttr + '></textarea></div>';
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
            return '<div class="nf-field"><label for="' + safeName + '">' + safeLabel + '</label><select id="' + safeName + '" name="' + safeName + '"' + requiredAttr + '>' + optionsHtml + '</select></div>';
        }
        if (typeValue == 'checkbox') {
            return '<div class="nf-field"><label><input type="checkbox" name="' + safeName + '"' + requiredAttr + '> ' + safeLabel + '</label></div>';
        }

        String htmlType = normalizeInputType(typeValue);
        return '<div class="nf-field"><label for="' + safeName + '">' + safeLabel + '</label><input type="' + escapeHtml(htmlType) + '" id="' + safeName + '" name="' + safeName + '"' + placeholderAttr + requiredAttr + '></div>';
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
}
