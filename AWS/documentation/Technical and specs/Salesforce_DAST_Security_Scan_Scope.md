# Salesforce DAST Security Scan Scope

Date: 2026-04-28

## Purpose
Define the first ZAP / DAST scan scope for TwinaForms code that talks to Salesforce or can trigger Salesforce data access.

## Tooling
- Primary DAST tool used by Yosi: ZAP 2.17.0.
- Report branding may show `ZAP by Checkmarx`.
- DAST means Dynamic Application Security Testing: scan the running AWS/Salesforce-connected app behavior, not only source code.
- Keep SAST separate: Salesforce Code Analyzer / PMD / CodeScan / Checkmarx-style static scans are still needed for AppExchange preparation.

## Highest Priority Runtime Surfaces

### AWS/NativeFormsBackend.mjs
Salesforce OAuth and tenant setup.

Scan:
- `POST /tenant/register`
- tenant status path used by Connect
- tenant auth-health path used by Connect
- tenant disconnect path
- OAuth authorize/connect page path
- `GET /oauth/callback`

Review risks:
- open redirect or weak OAuth `state`
- callback replay
- leakage of access token, refresh token, client id/secret, org secret, or raw token response
- tenant/org mismatch
- unsafe `loginBaseUrl`
- verbose Salesforce/AWS errors shown to browser

### AWS/NativeForms-PrefillForm.mjs
Public prefill flow that refreshes Salesforce access and reads Salesforce data.

Scan:
- public prefill Lambda URL/API route

Review risks:
- bypassing `formId` + `publishToken`
- cross-tenant form access
- SOQL injection through params
- unauthorized object or field reads
- overly detailed Salesforce query errors
- rate-limit/replay behavior

### AWS/NativeForms-SubmitForm.mjs
Public submit flow that refreshes Salesforce access and writes Salesforce data.

Scan:
- public submit Lambda URL/API route
- file upload/finalization flow if enabled
- secret-code verification path if enabled

Review risks:
- bypassing `formId` + `publishToken`
- cross-tenant writes
- unauthorized object/field writes
- record ID tampering
- SOQL injection in find/update flows
- file upload token misuse
- unsafe Apex REST path/payload use
- leaking validation, permission, or stack details to public users

### AWS/NativeFormsSubmissionLogsApi.mjs
Salesforce-facing logs API.

Scan:
- log list/detail/sync/config endpoints reachable from Salesforce Named Credentials.

Review risks:
- missing tenant bearer secret
- log cross-tenant access
- leaking sensitive submitted values beyond intended admin access

### AWS/NativeFormsAdminApi.mjs
Internal admin/support API.

Scan only with authenticated admin profile.

Review risks:
- Cognito/admin auth bypass
- tenant mutation without authorization
- unsafe support flag changes
- exposure of Salesforce connection status or internal tenant state beyond support users

## Salesforce Apex Callout Surfaces
These are not DAST endpoints themselves, but they drive AWS calls and should be reviewed alongside DAST findings.

- `force-app/main/default/classes/NativeFormsAwsClient.cls`
  - publish presign
  - HTML upload URL use
  - form register/unpublish
- `force-app/main/default/classes/NativeFormsSetupController.cls`
  - tenant register/status/disconnect/auth-health
- `force-app/main/default/classes/NativeFormsHomeController.cls`
  - home summary/access management callouts
  - External Credential permission-set detection
- `force-app/main/default/classes/NativeFormsSubmissionLogsController.cls`
  - submission log API calls
- `force-app/main/default/classes/NativeFormsTenantEntitlements.cls`
  - entitlement/home-summary calls

Review risks:
- Named Credential namespace resolution
- tenant secret only via External Credential / Named Credential
- handled errors only
- no raw AWS response leakage into UI
- LWC-to-Apex methods use primitive/JSON-string boundaries where managed packages are sensitive

## ZAP Scan Notes
Recommended scan profiles:

- unauthenticated public scan:
  - prefill
  - submit
  - published form HTML
  - OAuth callback with invalid/malformed state/code
- Salesforce setup/admin scan:
  - Connect flow through Salesforce UI
  - tenant register/status/auth-health
  - logs page
- internal admin scan:
  - admin console only with authenticated support/admin identity

Record for each scan:
- environment URL
- package version
- AWS Lambda/API version or deployment date
- test org id
- auth mode
- endpoints included
- endpoints excluded
- high/medium findings
- false-positive rationale
- fixes or accepted risk

## Current First-Pass Inventory
Source grep on 2026-04-28 identified these main Salesforce API callers:

- `AWS/NativeFormsBackend.mjs`
  - stores/retrieves Salesforce connection secrets
  - builds OAuth authorize URL
  - exchanges OAuth code for tokens
  - saves tenant refresh token and instance URL
- `AWS/NativeForms-PrefillForm.mjs`
  - exchanges refresh token for access token
  - executes Salesforce SOQL queries
  - reads Salesforce records by ID
- `AWS/NativeForms-SubmitForm.mjs`
  - exchanges refresh token for access token
  - calls Salesforce Apex REST when configured
  - describes Salesforce objects
  - executes SOQL
  - creates, updates, deletes Salesforce records
  - creates `ContentVersion` for file uploads
- Apex AWS callout controllers:
  - `NativeFormsAwsClient`
  - `NativeFormsSetupController`
  - `NativeFormsHomeController`
  - `NativeFormsSubmissionLogsController`
  - `NativeFormsTenantEntitlements`
