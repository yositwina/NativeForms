# AWS Auth

## Purpose
Keep Codex aligned with the NativeForms tenant trust model, public runtime trust model, and admin/bootstrap separation.

## Use When
Use for Lambda auth, tenant registration, bearer-secret flows, connected app or callback decisions, runtime security, or admin API protection changes.

## NativeForms Rules
- Keep tenant trust separate from public form trust.
- Salesforce package/admin calls use Bootstrap V2 HMAC signatures. Public HTML never uses package service credentials.
- Public runtime uses `formId` plus per-form `publishToken`, then resolves tenant ownership indirectly through the stored form record.
- User-verification same-tab verification sessions are public runtime tokens only. AWS must derive the allowed session mode from the published form config, not from the browser request, and cap same-tab expiry at 12 hours even when the browser asks for local midnight.
- Store tenant-specific Salesforce connection data per org, but do not store subscriber-entered OAuth client credentials per tenant.
- The packaged External Client App uses one TwinaForms-owned OAuth client id/secret configured centrally in AWS, preferably in Secrets Manager with Lambda env var `SALESFORCE_OAUTH_CLIENT_SECRET_NAME`.
- `NativeFormsBackend`, `NativeForms-PrefillForm`, and `NativeForms-SubmitForm` must all be able to read that central OAuth client secret.
- Per-tenant Salesforce connection secrets should hold the tenant refresh token, instance URL, login base URL, token metadata, and org identity only.
- Use the stored tenant `loginBaseUrl` for org-specific auth/bootstrap behavior rather than assuming one global Salesforce login host.
- Bootstrap V2 is the preferred clean-install path for Salesforce package-to-AWS calls. It generates a per-org Salesforce-side signing secret, transfers it during OAuth-authenticated bootstrap, and signs Salesforce-to-AWS package calls with HMAC-SHA256.
- Do not reintroduce Salesforce Named Credential or External Credential dependencies for normal Connect, publish, entitlement, disconnect, or Submission Logs calls unless explicitly approved.
- Bootstrap V2 signed requests must include org id, timestamp, nonce, body hash, signature, and algorithm headers. AWS must reject replayed nonces.
- Bootstrap V2 should avoid Salesforce Named Credential dependency for the initial setup path. The Salesforce package may build the AWS `/connect` URL directly, including org id and login base URL; AWS must then use Salesforce OAuth as the trust proof and verify the callback org id before storing connection/signing material.
- For Bootstrap V2 package-to-AWS calls, prefer direct HTTPS callouts to the packaged Remote Site Setting plus HMAC headers over Named Credential callouts, so customers do not need to create permission sets solely for External Credential Principal Access.
- The spike currently stores nonces in `NativeFormsAdminAudit` only because IAM/table creation is not finalized. Production should use a dedicated `NativeFormsBootstrapV2Nonces` table with TTL and least-privilege Lambda access.
- Admin auth is still a separate concern from customer runtime auth; Cognito belongs to the admin app path, not the public form runtime path.
- `admin.twinaforms.com` now uses Cognito Hosted UI for browser login plus Cognito JWT validation in `NativeFormsAdminApi`.
- Current admin Cognito setup is User Pool `eu-north-1_ofYRC83LO`, app client `23smj51rvoqsni85ai4e4rde3p`, hosted domain `https://twinaforms-admin.auth.eu-north-1.amazoncognito.com`, group `TwinaFormsAdmins`.
- Keep this setup on low-cost Cognito features: Lite tier, admin-created users only, no SMS MFA, no Plus tier, and no Cognito advanced security features unless explicitly approved.

## Escalate When
- A change mixes tenant admin trust with public runtime trust.
- A proposal introduces browser-visible admin credentials or a single global Salesforce refresh token/connection for all orgs. A central packaged-app OAuth client credential is allowed; tenant refresh tokens are still per org.
- Bootstrap V2 work must stay on branch `bootstrap-v2-spike` until explicitly promoted. The OAuth callback helper may call `/services/apexrest/nativeforms/bootstrap-v2/signing-secret` and store `bootstrap_v2_*` fields in the per-org Salesforce connection secret.

## Source Docs
- `AWS/documentation/Multi tenant and security approach.md`
- `AWS/documentation/Security Protocols.md`
- `AWS/documentation/Technical and specs/TwinaForms_Bootstrap_V2_Spike.md`
- `SalesforcePackage/Salesforce_Connected_App_Strategy.md`
- `AWS/documentation/admin_control_app_v1_focused_spec.md`
