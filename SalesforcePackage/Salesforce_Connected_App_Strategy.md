# Salesforce Connected App Strategy

## Goal
Define the NativeForms subscriber-org Salesforce connection model for packaged multi-tenant use.

## Why this exists
NativeForms needs a per-org Salesforce API connection so AWS can:
- prefill from the subscriber org
- submit updates into the subscriber org
- keep one refreshable connection per tenant org

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

## User-facing setup flow
1. Install package
2. Assign permission sets
3. Register org with AWS
4. Click `Connect Salesforce`
5. Approve access
6. NativeForms stores the Salesforce connection for that org
7. Publish forms

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
Store one Secrets Manager entry per org:
- `NativeForms/SalesforceConnection/<orgId>`

Suggested fields:
- `orgId`
- `loginBaseUrl`
- `client_id`
- `client_secret`
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
4. Lambda refreshes access token
5. Lambda reads or writes that subscriber org's Salesforce data

## Important separation
NativeForms has three separate trust layers:

1. Tenant admin auth
- tenant secret
- used for `/tenant/register` and `/forms/register`

2. Public form auth
- per-form `publishToken`
- used by HTML prefill and submit

3. Salesforce org connection
- org-specific OAuth connection
- used by AWS to call Salesforce APIs

These should remain separate.

## Packaging direction
For the associated model, the package should include:
- the External Client App header
- the OAuth settings file

The source org keeps the global OAuth settings file and consumer credentials.

This matches Salesforce's associated-distribution model, where subscriber orgs reference the source org's global OAuth settings.

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
