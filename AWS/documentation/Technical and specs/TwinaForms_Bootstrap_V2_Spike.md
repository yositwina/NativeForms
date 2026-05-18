# TwinaForms Bootstrap V2 Spike

Status: Experimental spike, promoted for clean-org package validation

Branch: `bootstrap-v2-spike`

## Goal

Test a cleaner TwinaForms installation flow without damaging the current working Connect/manual tenant-secret solution.

The target setup experience is:

1. Install the managed package.
2. Open Connect.
3. Click Connect TwinaForms.
4. Assign users/seats.

The spike explores replacing the manual tenant-secret copy step with:

- OAuth-verified one-time bootstrap.
- A per-org signing secret generated inside Salesforce Apex.
- Protected package storage for that signing secret.
- HMAC-signed Salesforce-to-AWS calls after bootstrap.

## Release Safety Rules

- Do not change the existing Connect UI in phase 1.
- Do not create a Salesforce package from this branch unless explicitly approved.
- Keep spike notes, sample payloads, and temporary scripts under `experiments/bootstrap-v2`.
- Keep all new AWS endpoints and Apex classes clearly marked as experimental.
- Keep the current package branch intact so the working package can still be used.
- The spike must be removable without changing existing customer-facing setup behavior.

## Experimental Endpoint Naming

Any AWS endpoints added for this spike should use a clear experimental name, for example:

- `/tenant/bootstrap-v2/start`
- `/tenant/bootstrap-v2/complete`
- `/tenant/bootstrap-v2/verify-signed-call`

Any Salesforce Apex REST endpoints added for this spike should use a clear experimental path, for example:

- `/services/apexrest/nativeforms/bootstrap-v2/signing-secret`
- `/services/apexrest/nativeforms/bootstrap-v2/health`

These endpoints are not part of the production API contract until promoted from this spike.

## Phase 1 Scope

Phase 1 should prove the smallest useful technical loop:

1. Apex generates a per-org random signing secret.
2. Apex stores it in protected managed package storage.
3. Apex signs a test payload with HMAC.
4. AWS verifies the signed payload on an experimental endpoint.

Phase 1 does not change the Connect page and does not replace the current manual tenant-secret flow.

Phase 1 implementation files:

- `force-app/main/default/classes/NativeFormsBootstrapV2Signer.cls`
- `force-app/main/default/objects/NativeForms_Protected_Config__c/fields/Bootstrap_V2_Signing_Secret__c.field-meta.xml`
- `AWS/NativeFormsBackend.mjs` experimental route `/tenant/bootstrap-v2/verify-signed-call`
- `tests/bootstrap-v2-hmac.test.mjs`
- `experiments/bootstrap-v2/`

## Phase 2 Scope

Phase 2 proves that OAuth can become the first trust bridge for Bootstrap V2.

After the normal Salesforce OAuth callback succeeds, AWS should:

1. Use the callback access token and instance URL.
2. Call the experimental packaged Apex REST endpoint:
   `/services/apexrest/nativeforms/bootstrap-v2/signing-secret`
3. Pass the authenticated org id in the request body.
4. Receive the per-org HMAC signing secret from protected Salesforce package storage.
5. Store that secret in the existing per-org AWS Salesforce connection secret.

Phase 2 must remain non-blocking while it is experimental. If the Apex endpoint is not deployed, not accessible, or returns an error, the existing OAuth connection should still complete and AWS should store an experimental `bootstrap_v2_status` of `not_available`.

Phase 2 implementation files:

- `force-app/main/default/classes/NativeFormsBootstrapV2Api.cls`
- `force-app/main/default/classes/NativeFormsBootstrapV2ApiTest.cls`
- `AWS/bootstrap-v2-salesforce.mjs`
- `tests/bootstrap-v2-salesforce.test.mjs`
- `AWS/NativeFormsBackend.mjs` OAuth callback experimental helper call

## Future Phase Scope

After Phase 2 works:

1. AWS completes OAuth and confirms the real Salesforce org id.
2. AWS opens a short-lived one-time bootstrap session.
3. AWS calls a packaged Apex REST endpoint server-to-server using the OAuth token.
4. Salesforce returns the generated per-org signing secret only during that bootstrap session.
5. AWS stores the secret securely.
6. Future package calls are authenticated with HMAC signatures, timestamp, nonce, and replay protection.

## Security Review Notes

The intended review story is:

- No hard-coded package secret.
- Per-subscriber-org signing secret.
- Protected managed package storage in Salesforce.
- Secret transferred only server-to-server over TLS.
- OAuth verifies the subscriber org before AWS accepts bootstrap material.
- Secret is never returned to LWC, browser JavaScript, URL parameters, debug output, or user-visible errors.
- Future calls use HMAC signatures instead of repeatedly sending the secret.
- Signed calls include timestamp and nonce replay protection.
- A reconnect/reset path exists before production adoption.

## Phase 3 Scope

Phase 3 tests using Bootstrap V2 signatures on real Salesforce-to-AWS package calls.

The current spike behavior is:

1. AWS verifies requests with the per-org signing secret saved during OAuth bootstrap.
2. AWS rejects replayed signatures by recording the `(orgId, nonce)` pair before accepting the request.
3. Salesforce package calls add Bootstrap V2 signature headers for:
   - `GET /tenant/auth-health`
   - `GET /tenant/entitlements`
   - `POST /tenant/disconnect`
   - `POST /forms/register`
   - `POST /forms/unpublish`
   - `POST /forms/publish/presign`

Phase 3 is still experimental. It must not be packaged or promoted until the nonce table, IAM, reconnect/reset behavior, and clean-org setup story are finalized.

## Phase 3 Implementation Files

- `AWS/NativeFormsBackend.mjs`
- `AWS/bootstrap-v2-hmac.mjs`
- `force-app/main/default/classes/NativeFormsAwsClient.cls`
- `force-app/main/default/classes/NativeFormsSetupController.cls`
- `force-app/main/default/classes/NativeFormsTenantEntitlements.cls`
- `force-app/main/default/classes/NativeFormsBootstrapV2Signer.cls`

## Phase 3 Replay Protection

Bootstrap V2 signed calls include:

- timestamp
- nonce
- body hash
- HMAC signature

AWS stores each accepted nonce and rejects reuse of the same nonce for the same org.

For the spike, nonce storage is configurable through Lambda environment variables:

- `BOOTSTRAP_V2_NONCE_TABLE`
- `BOOTSTRAP_V2_NONCE_KEY_ATTRIBUTE`

Current spike deployment uses the existing `NativeFormsAdminAudit` table with key attribute `auditId` because the Codex AWS role does not yet have permission to create or manage a dedicated nonce table.

Production should use a dedicated `NativeFormsBootstrapV2Nonces` DynamoDB table with TTL enabled and least-privilege IAM for the backend Lambda.

## Phase 3 Test Results

Run date: 2026-05-06

- AWS `NativeFormsBackend` deployed on `nodejs24.x`.
- Lambda environment configured for spike nonce storage:
  - `BOOTSTRAP_V2_NONCE_TABLE=NativeFormsAdminAudit`
  - `BOOTSTRAP_V2_NONCE_KEY_ATTRIBUTE=auditId`
- Local Node checks passed:
  - `node --check AWS\NativeFormsBackend.mjs`
  - `npm.cmd test`
- Salesforce Apex deploy to `TwinaFormsDevHub` passed for:
  - `NativeFormsAwsClient`
  - `NativeFormsSetupController`
  - `NativeFormsTenantEntitlements`
  - `NativeFormsBootstrapV2Signer`
- Salesforce test `NativeFormsBootstrapV2SignerTest` passed with 3/3 tests.
- Execute Anonymous compile/run passed, but the live callout could not access `NativeForms_Bootstrap` from the Dev Hub execution context. This appears to be org setup/principal access, not a compile failure.

## Phase 3 Open Items

- Rotate or delete/recreate the Dev Hub test Salesforce connection because a test connection secret was pasted into chat during manual verification.
- Add a dedicated nonce table with TTL before production adoption.
- Add least-privilege IAM for the backend Lambda to write nonce records.
- Decide whether HMAC should become primary auth and tenant bearer should become compatibility-only.
- Add a visible reconnect/reset path before replacing the manual tenant-secret setup.

## Phase 4 Scope

Phase 4 tests removing the customer-facing External Credential Principal Access setup from the Bootstrap V2 path.

The current Phase 4 spike behavior is:

1. `NativeFormsSetupController.registerOrg` no longer calls AWS through a Salesforce Named Credential.
2. The Salesforce package builds the AWS `/connect` URL directly from the org id, org login base URL, admin email, and org name.
3. AWS `/connect` can create/update the tenant registration from the URL context before redirecting to Salesforce OAuth.
4. AWS OAuth callback verifies that the org id returned by Salesforce OAuth matches the requested org id before saving connection/signing material.
5. Main Salesforce-to-AWS package calls use direct HTTPS endpoints covered by packaged Remote Site Settings plus Bootstrap V2 HMAC headers.

This phase removes the need for a subscriber-created permission set containing External Credential Principal Access for the normal Connect/publish/entitlements path.

## Phase 4 Implementation Files

- `AWS/NativeFormsBackend.mjs`
- `force-app/main/default/classes/NativeFormsAwsClient.cls`
- `force-app/main/default/classes/NativeFormsSetupController.cls`
- `force-app/main/default/classes/NativeFormsTenantEntitlements.cls`
- `force-app/main/default/classes/NativeFormsHomeController.cls`
- `force-app/main/default/lwc/nativeFormsConnect/*`

## Phase 4 Test Results

Run date: 2026-05-06

- `node --check AWS\NativeFormsBackend.mjs` passed.
- `NativeFormsBackend` deployed on `nodejs24.x`.
- DevHub deploy passed with `NoTestRun` for Phase 4 Apex/LWC files.
- Focused Apex tests passed separately:
  - `NativeFormsAwsControllersTest`
  - `NativeFormsCoreServicesTest`
  - 23 tests run, 100% pass.
- DevHub Execute Anonymous status probe returned `tenantAuthVerified=true`.
- DevHub Execute Anonymous direct-connect probe returned a `/connect` URL without any Apex callouts.
- AWS `/connect` URL returned HTTP 302 to the DevHub Salesforce OAuth authorize endpoint.

## Phase 5 Scope

Phase 5 removes the last package-visible Named Credential and External Credential mechanism.

The current Phase 5 behavior is:

1. Salesforce Named Credential metadata is removed from the package source.
2. Salesforce External Credential metadata is removed from the package source.
3. Submission Logs use direct HTTPS plus Bootstrap V2 HMAC signatures.
4. Connect User Access grants/removes only `TwinaForms User` and `TwinaForms Admin`.
5. Customer-facing setup text no longer asks admins to create service-access permission sets or principal access entries.

## Phase 5 Implementation Files

- `force-app/main/default/classes/NativeFormsSubmissionLogsController.cls`
- `AWS/NativeFormsSubmissionLogsApi.mjs`
- `force-app/main/default/classes/NativeFormsSetupController.cls`
- `force-app/main/default/classes/NativeFormsHomeController.cls`
- `force-app/main/default/lwc/nativeFormsConnect/*`
- `force-app/main/default/lwc/nativeFormsHome/*`
- `force-app/main/default/lwc/nativeFormsAdminFeatures/*`
- `force-app/main/default/remoteSiteSettings/NativeForms_SubmissionLogs.remoteSite-meta.xml`

## Phase 5 Open Items

- Deploy the updated Submission Logs Lambda with Bootstrap V2 verification.
- Full clean-org/manual test is still required with no Named Credentials, no External Credentials, and no External Credential Principal Access assigned.
- Focused deploy with selected tests is blocked by selected-class coverage for `NativeFormsAwsClient`; broader package test runs may cover it, but add targeted coverage before packaging.
