# Salesforce Security

## Purpose
Keep Codex aligned with Salesforce security-review, AppExchange, SAST, and DAST expectations for the TwinaForms package and AWS/Salesforce integration.

## Use When
Use for AppExchange Security Review preparation, Salesforce Code Analyzer, PMD/CodeScan/Checkmarx-style SAST, ZAP DAST, OAuth/token handling, Salesforce API calls from AWS, Apex callouts, CRUD/FLS/security concerns, or any feature that reads/writes subscriber Salesforce data.

## NativeForms Rules
- Treat `TwinaForms User` as the counted customer seat. System Admin access is setup/admin capability and is not counted unless that admin is explicitly assigned `TwinaForms User`.
- For Salesforce Code Analyzer `Validate CRUD permission before SOQL/DML operation or enforce user mode` findings, prefer a package-wide, consistent Apex user-mode pattern:
  - Add `WITH USER_MODE` to static SOQL that reads subscriber data.
  - Use `insert/update/delete/upsert as user` for DML that should respect the running user's object and field access.
  - Make the customer-facing permission set grant the object and field permissions needed by those user-mode operations. User-mode Apex will fail at runtime if the permission set does not match the data the code reads or writes.
  - Do not update raw queried sObjects when they include required/master-detail relationship fields or fields the running user cannot update. Build a minimal update sObject with only `Id` and the fields that should change, then run `update as user`.
  - For tests, assign the relevant permission set in test setup and run the exercised code under `System.runAs(...)` so the permission assignment is active. Keep assertions focused on durable behavior, not exact low-level platform or AWS error wording.
  - Narrow documented exception: `NativeFormsBootstrapV2Signer` and the encrypted-key persistence methods in `NativeFormsSubmissionLogsController` intentionally use system-context access for package-controlled secret storage. Their `PMD.ApexCRUDViolation` suppression is justified in `AWS/documentation/Technical and specs/Security Protocols.md`; do not extend that exception to customer form or submission data.
  - After fixes, verify with Salesforce Code Analyzer on `force-app` and confirm `ApexCRUDViolation` is zero before packaging.
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
  - direct HTTPS endpoint is covered by a packaged Remote Site Setting
  - Bootstrap V2 HMAC signing is applied where the endpoint changes tenant/package state or reads protected tenant data
  - no browser-visible signing secret
  - handled/customer-safe errors
  - no package-visible DTO binding fragility at LWC-to-Apex boundaries
- Bootstrap V2 ISV review story:
  - Salesforce OAuth is the first trust anchor and AWS verifies the OAuth-returned org id before saving a connection.
  - The per-org HMAC signing secret is generated in Apex and stored in protected package-managed storage.
  - AWS retrieves that secret server-to-server during OAuth-authenticated bootstrap, then verifies future package calls by org id, timestamp, nonce, body hash, and HMAC-SHA256 signature.
  - The intended package posture is Named-Credential-free and External-Credential-free; submission logs use a separate AWS endpoint but still authenticate with Bootstrap V2 HMAC.
  - Use `security-reports/isv/TwinaForms_Bootstrap_V2_ISV_Security_Explanation.md` as the ISV-facing explanation.
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
