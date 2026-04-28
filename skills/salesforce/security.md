# Salesforce Security

## Purpose
Keep Codex aligned with Salesforce security-review, AppExchange, SAST, and DAST expectations for the TwinaForms package and AWS/Salesforce integration.

## Use When
Use for AppExchange Security Review preparation, Salesforce Code Analyzer, PMD/CodeScan/Checkmarx-style SAST, ZAP DAST, OAuth/token handling, Salesforce API calls from AWS, Apex callouts, CRUD/FLS/security concerns, or any feature that reads/writes subscriber Salesforce data.

## NativeForms Rules
- Treat `TwinaForms User` as the counted customer seat. System Admin access is setup/admin capability and is not counted unless that admin is explicitly assigned `TwinaForms User`.
- For AppExchange preparation, keep both SAST and DAST evidence:
  - SAST: Salesforce Code Analyzer AppExchange/security rules, PMD-style Apex checks, dependency/security scans where relevant.
  - DAST: ZAP or equivalent scan of the running AWS/public surfaces.
- DAST scope must include all public or semi-public endpoints that can lead to Salesforce data access:
  - OAuth connect/callback/status/disconnect endpoints in `AWS/NativeFormsBackend.mjs`.
  - tenant registration/auth-health endpoints called from Salesforce Connect.
  - published form prefill endpoint in `AWS/NativeForms-PrefillForm.mjs`.
  - published form submit endpoint in `AWS/NativeForms-SubmitForm.mjs`.
  - submission log endpoints in `AWS/NativeFormsSubmissionLogsApi.mjs`.
  - admin-console tenant/support endpoints only in an authenticated admin test profile.
- Any code path that calls Salesforce APIs from AWS must be reviewed for:
  - tenant isolation by `orgId`
  - refresh-token storage and use
  - instance URL and login URL validation
  - object and field allowlists
  - SOQL construction safety
  - Salesforce error leakage in public responses
  - file upload handling
  - rate limits and replay behavior
- Any Apex path that calls AWS must be reviewed for:
  - Named Credential namespace resolution
  - tenant-secret use only from Named/External Credential setup
  - no browser-visible tenant secret
  - handled/customer-safe errors
  - no package-visible DTO binding fragility at LWC-to-Apex boundaries
- For ZAP scans, save enough evidence for Security Review/support:
  - target URLs and environment
  - authenticated vs unauthenticated scan mode
  - excluded endpoints, if any
  - findings triage and false-positive notes
  - remediation notes or accepted-risk explanation

## Salesforce-Touching Code To Scan First
- `AWS/NativeFormsBackend.mjs`
  - OAuth authorize URL generation
  - `/oauth/callback`
  - `/tenant/register`
  - `/tenant/status`
  - `/tenant/auth-health`
  - `/tenant/disconnect`
- `AWS/NativeForms-PrefillForm.mjs`
  - Salesforce refresh-token exchange
  - SOQL query execution
  - record-by-id reads
- `AWS/NativeForms-SubmitForm.mjs`
  - Salesforce refresh-token exchange
  - Apex REST callout support
  - describe calls
  - SOQL query execution
  - create/update/delete/upsert/file-upload commands
- Salesforce Apex callouts to AWS:
  - `force-app/main/default/classes/NativeFormsAwsClient.cls`
  - `force-app/main/default/classes/NativeFormsSetupController.cls`
  - `force-app/main/default/classes/NativeFormsHomeController.cls`
  - `force-app/main/default/classes/NativeFormsSubmissionLogsController.cls`
  - `force-app/main/default/classes/NativeFormsTenantEntitlements.cls`

## Escalate When
- A DAST finding touches OAuth callback, tenant secret, refresh token, public prefill/submit, file upload, or Salesforce writeback.
- A public endpoint can produce raw Salesforce errors, stack traces, tokens, org secrets, or internal AWS identifiers.
- A Salesforce API path accepts object names, field names, SOQL fragments, record IDs, file metadata, or redirect URLs from user-controlled input.
- A scan needs authenticated production-like tenant data or any real customer org.

## Source Docs
- `AWS/documentation/Technical and specs/Security Protocols.md`
- `AWS/documentation/Technical and specs/Multi tenant and security approach.md`
- `AWS/documentation/Technical and specs/Salesforce_DAST_Security_Scan_Scope.md`
- `SalesforcePackage/Salesforce_Connected_App_Strategy.md`
- `skills/aws/auth.md`
