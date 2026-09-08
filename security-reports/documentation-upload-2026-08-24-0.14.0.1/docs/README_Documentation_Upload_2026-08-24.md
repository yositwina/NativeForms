# TwinaForms 0.14 Documentation Upload Folder

Date: 2026-08-24

Use this folder for the 0.14 AppExchange Security Review documentation upload.

## Package Identity

- Package name: `TwinaForms`
- AppExchange / Subscriber Package ID: `033gL0000009ZbFQAU`
- 2GP Package ID: `0HogL0000002CUvSAM`
- Subscriber Package Version ID: `04tgL000000OO9FQAW`
- Package version: `0.14.0.1`

## Primary Documentation

- `docs/TwinaForms_Describe_Your_Solution_2026-08-24.md`
- `docs/TwinaForms_Data_Flow_Authentication_Encryption_and_Usage_2026-08-24.md`
- `docs/TwinaForms_Sample_API_Callouts_2026-08-24.md`
- `docs/TwinaForms_Test_Environment_API_OAuth_SAML_Access_2026-08-24.md`
- `docs/TwinaForms_Test_Environment_Username_Password_Access_2026-08-24.md`

## Scanner Evidence

Source Scanner / Checkmarx:

- `source-scanner/report_phxcxmanwp001_39670.html`
- `source-scanner/TwinaForms_Checkmarx_False_Positive_Explanation_2026-08-20.md`
- `source-scanner/README_Source_Scanner_Upload_2026-08-24.md`

ZAP:

- `zap/official-reports/01-published-form-page.html`
- `zap/official-reports/02-prefill-lambda.html`
- `zap/official-reports/03-submit-lambda.html`
- `zap/official-reports/04-salesforce-backend-lambda.html`
- `zap/official-reports/05-submission-logs-lambda.html`
- `zap/official-reports/06-admin-api-cognito.html`
- `zap/official-reports/07-portable-snapshots-import-export.html`
- `zap/responses/TwinaForms_ZAP_ISV_Response_2026-08-20.md`
- `zap/responses/TwinaForms_ZAP_Scope_Note_2026-08-20.md`
- `zap/README_ZAP_Upload_2026-08-24.md`

## New 0.14 Feature Coverage

- Connected-org import/export through protected portable snapshot routes.
- Agentforce-compatible Apex action for creating Draft forms from Salesforce page layouts.

## AgentExchange Questionnaire

- `agentexchange/TwinaForms_AgentExchange_Solution_Intake_Questionnaire_Answers_2026-08-31.pdf`
- `agentexchange/TwinaForms_AgentExchange_Solution_Intake_Questionnaire_Answers_2026-08-31.md`

## Pre-Submission Note

Do not upload the older June 2026 documents for the final 0.14 submission unless they are clearly marked as historical. The June documents reference package `0.10.0.5`, version id `04tgL000000GburQAC`, and ZAP reports 01-06 only.
