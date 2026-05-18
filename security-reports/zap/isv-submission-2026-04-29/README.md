# TwinaForms ZAP ISV Submission Pack

Generated: April 29, 2026

Tool: ZAP 2.17.0 by Checkmarx

Scan style: Passive ZAP Automation Framework requestor reports. These reports do not run active attack scans and do not include real tenant bearer secrets or Cognito tokens.

## Folder Contents

`official-reports/`

Official ZAP HTML reports and their supporting asset folders.

`automation-plans/`

The YAML automation plans used to generate each ZAP report.

`responses/`

TwinaForms response documents explaining scope, expected behavior, false positives, and accepted hardening items.

## Official Reports

1. `official-reports/01-published-form-page.html`
   Public published form page on `forms.twinaforms.com`.

2. `official-reports/02-prefill-lambda.html`
   Public prefill Lambda, including a valid public publish-token request and rejection cases for missing, invalid, and unexpected parameters.

3. `official-reports/03-submit-lambda.html`
   Public submit Lambda rejection cases. The report does not create Salesforce records.

4. `official-reports/04-salesforce-backend-lambda.html`
   Salesforce-to-AWS backend Lambda. Protected routes are scanned with missing bearer tokens so tenant secrets are not exposed in the report.

5. `official-reports/05-submission-logs-lambda.html`
   Submission logs Lambda. Protected routes are scanned with missing bearer tokens so tenant secrets are not exposed in the report.

6. `official-reports/06-admin-api-cognito.html`
   Admin API protected by Cognito. Routes are scanned without Cognito tokens to verify unauthenticated rejection.

## Response Documents

Primary response document:

`responses/TwinaForms_ZAP_ISV_Response_2026-04-29.md`

Scope note:

`responses/TwinaForms_ZAP_Scope_Note_2026-04-29.md`
