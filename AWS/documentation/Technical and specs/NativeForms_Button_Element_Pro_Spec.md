# TwinaForms Pro Button Element V1

## Purpose
`Button` is a persisted Pro-only canvas element for portal navigation in a published TwinaForms form. It is an action/display element and never creates submitted field data.

## Entitlement And Storage
- Feature flag: `enableProButtonElements`.
- Starter/free default: `false`. Trial/Pro default: `true`.
- Salesforce type: `NF_Form_Element__c.Element_Type__c = "button"`.
- Authored values live in `Label__c` and `Config_JSON__c`; `Field_Key__c` is not required.
- A draft containing an active Button cannot publish without the feature entitlement.

## Authored Configuration
```json
{
  "destinationType": "form",
  "targetFormId": "",
  "externalUrlMode": "template",
  "externalUrlTemplate": "",
  "externalUrlFormula": "",
  "queryParameters": [
    {
      "name": "contactId",
      "valueMode": "template",
      "valueTemplate": "{{field.contactId}}",
      "valueFormula": ""
    }
  ],
  "submitBeforeNavigation": false,
  "conditionalEnabled": false,
  "conditionalConditions": [],
  "conditionalExpression": ""
}
```

## Destination Rules
- `form` targets select a currently published form in the subscriber org. At publish time Salesforce replaces `targetFormId` with that target's current public URL in generated HTML.
- `external` targets use either a URL template or formula. Resolved navigation must be an absolute `http://` or `https://` URL.
- Configured query parameters apply to either destination. Blank resolved values are omitted; names and values are appended through URL encoding.
- External destinations may already include their own query string.

## Runtime Rules
- Buttons may be placed top-level, in Sections, in Groups, or inside Records List rows.
- Top-level tokens use `{{field.email}}` for templates and `{email}` for formulas.
- A Records List Button may additionally use `{{row.contactId}}` and `{row.contactId}` for the clicked row only.
- Navigation remains in the same browser tab.
- When `submitBeforeNavigation` is false, clicking a Button navigates without required-field validation, CAPTCHA, secret verification, or submission.
- When `submitBeforeNavigation` is true, the normal whole-form submit pipeline runs. Only after success does the Button destination override the form-level post-submit redirect.
- Buttons in Records Lists cannot submit the form in V1.
- Runtime never forwards publish tokens, Salesforce credentials, verification tokens, or AWS identifiers as automatic navigation variables.

## Designer And Packaging
- The Designer lists `Button` under `Input Field` as a Pro-gated action element and uses a localized new-element label such as `Continue`; do not append `(Pro)` to its customer-facing element name.
- A newly created Button defaults to `Another TwinaForms Form`; admins then choose a published target form.
- Button properties provide destination, URL mode, query rows, submit-before-navigation, and normal conditional visibility controls.
- Query-parameter values are configured as either `Field` or `Formula`. `Field` presents eligible form values in a picklist and stores the corresponding safe template token internally. `Formula` opens the standard guided formula editor with field insertion and a formulas-help link.
- The AWS admin console exposes `Portal Buttons` in plan feature controls.
- Before package version creation, confirm `button` remains present in the unrestricted `Element_Type__c` metadata value set.
