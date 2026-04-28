# Salesforce Connected App Strategy

## Goal
Define the NativeForms subscriber-org Salesforce connection model for packaged multi-tenant use.

## Why this exists
NativeForms needs a per-org Salesforce API connection so AWS can:
- prefill from the subscriber org
- submit updates into the subscriber org
- keep one refreshable connection per tenant org
- reuse the TwinaForms-owned packaged External Client App credentials safely across tenants

This must be separate from:
- tenant secret auth between Salesforce and AWS
- per-form `publishToken` auth between public HTML and AWS

## Target model
Each subscriber org installs the NativeForms package and then completes a one-time Salesforce connection step.

That connection should:
- belong to that subscriber org
- be refreshable
- allow API access
- be stored in AWS under that org's `orgId`
- use the central TwinaForms OAuth client id/secret configured in AWS, not subscriber-entered client credentials

## User-facing setup flow
1. Install package
2. Assign `TwinaForms User` / `TwinaForms Admin` permission sets as needed
3. Create a subscriber-owned permission set:
   - Label: `TwinaForms Credentials`
   - API Name: `TwinaFormsCredentials`
4. In `TwinaForms Credentials`, open `External Credential Principal Access` and enable:
   - `TwinaFormsBootstrapPrincipal`
   - `TwinaFormsSharedSecret`
5. Assign `TwinaForms Credentials` to the same users who need TwinaForms access
6. Register org with AWS
7. Click `Connect Salesforce`
8. Approve access
9. NativeForms stores the Salesforce connection for that org
10. Publish forms

## OAuth flow
Use:
- authorization code flow
- refresh token / offline access

Minimum scopes:
- `api`
- `refresh_token`
- `offline_access`

## Callback target
Preferred first implementation:
- AWS callback endpoint

Example:
- `https://<nativeforms-backend>/oauth/callback`

The auth request should include:
- `state=<orgId>`

This allows AWS to bind the callback result to the correct tenant.

## What AWS stores
Store the TwinaForms source-org External Client App credentials once in AWS:
- recommended secret name: `TwinaForms/SalesforceOAuthClient`
- fields: `client_id`, `client_secret`
- Lambda env var: `SALESFORCE_OAUTH_CLIENT_SECRET_NAME`
- apply the env var and Secrets Manager read permission to `NativeFormsBackend`, `NativeForms-PrefillForm`, and `NativeForms-SubmitForm`

Store one Secrets Manager entry per org:
- `NativeForms/SalesforceConnection/<orgId>`

Suggested fields:
- `orgId`
- `loginBaseUrl`
- `oauth_client_source`
- `oauth_client_id_last4`
- `refresh_token`
- `instance_url`
- `id_url`
- `token_issued_at`
- `updated_at`

Also update the tenant record in DynamoDB:
- `salesforceConnectionStatus`
- `salesforceConnectionUpdatedAt`
- optional connected user metadata

## Runtime usage
At runtime:
1. Lambda loads form by `formId`
2. Lambda gets `orgId` from the form record
3. Lambda loads `NativeForms/SalesforceConnection/<orgId>`
4. Lambda loads the central TwinaForms OAuth client credentials from AWS config/Secrets Manager
5. Lambda refreshes access token with the tenant refresh token plus central client credentials
6. Lambda reads or writes that subscriber org's Salesforce data

## Important separation
NativeForms has three separate trust layers:

1. Tenant admin auth
- tenant secret
- used for `/tenant/register` and `/forms/register`

2. Public form auth
- per-form `publishToken`
- used by HTML prefill and submit

3. Salesforce org connection
- central TwinaForms OAuth client credentials
- org-specific OAuth refresh token and instance URL
- used by AWS to call Salesforce APIs

These should remain separate.

## Packaging direction
For the next TwinaForms managed beta package:
- include the package-safe External Client App metadata in the managed package
- package the app header and OAuth settings
- do not package global OAuth settings, consumer credential material, or configurable policy metadata
- do not ask subscribers to copy Consumer Key or Consumer Secret; those settings are hidden for installed External Client Apps
- keep the subscriber setup step limited to authorizing the packaged TwinaForms app after tenant secret setup is verified
- keep the source External Client App in the persistent Dev Hub/source org; package source must use the retrieved `orgScopedExternalApp` and `oauthLink` values from that org
- set the Dev Hub/source External Client App refresh token policy to `Refresh token is valid until revoked`; AWS owns refresh-token use and tenant disconnect/revocation handling
- use a subscriber-created `TwinaForms Credentials` permission set for External Credential Principal Access, because the packaged permission sets are not the right manual assignment surface in subscriber orgs

This keeps setup customer-light while respecting Salesforce's External Client App packaging model.

Longer-term direction:
- validate the packageable associated External Client App model in clean subscriber orgs
- package only the External Client App header and OAuth settings
- keep global OAuth settings, consumer credentials, and generated policy artifacts outside the managed package source

Likely package areas:
- setup UI
- external client app metadata
- external credential / named credential support where needed
- admin permission set updates

## Current implementation note
The Lambdas already support:
- tenant registration
- tenant status/subscription enforcement
- per-org Salesforce connection lookup in Secrets Manager

What still needs to be finalized is the package-supported connection bootstrap flow itself and the generated policies metadata after first deploy/retrieve.

## Next implementation step
Create the package-side auth scaffolding:
- metadata folders for auth assets
- setup UI artifact for `Connect Salesforce`
- final decision on how the subscriber org provides the connected app/auth context
