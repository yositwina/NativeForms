# Salesforce Connected App Strategy

## Goal

Define the TwinaForms subscriber-org Salesforce connection model for packaged multi-tenant use.

## Why This Exists

TwinaForms needs a per-org Salesforce API connection so AWS can:

- prefill from the subscriber org
- submit updates into the subscriber org
- keep one refreshable connection per Salesforce org
- reuse the TwinaForms-owned packaged External Client App credentials safely across customers

This connection is separate from public form publish-token validation and from the Bootstrap V2 HMAC signatures used by packaged Apex calls into AWS.

## Target Model

Each subscriber org installs the TwinaForms package and completes a one-time OAuth connection from the packaged Connect page.

That connection should:

- belong to that subscriber org
- be refreshable
- allow API access
- be stored in AWS under that org's `orgId`
- use the central TwinaForms OAuth client id/secret configured in AWS
- avoid customer-created Salesforce Named Credentials and External Credentials

## User-Facing Setup Flow

1. Install the managed package.
2. Open the `TwinaForms` app.
3. Open `Connect`.
4. Click `Prepare Connection`.
5. Click `Connect TwinaForms`.
6. Approve Salesforce OAuth access.
7. Return to Connect and assign `TwinaForms User` seats.
8. Install demo records or continue to Home.

No subscriber admin should need to create a Salesforce Named Credential, External Credential, External Credential Principal Access, or extra service-access permission set.

## OAuth Flow

Use:

- authorization code flow
- refresh token / offline access

Minimum scopes:

- `api`
- `refresh_token`
- `offline_access`

## Callback Target

The OAuth callback target is the AWS backend callback endpoint.

Example:

- `https://<twinaforms-backend>/oauth/callback`

The auth request includes org context, and AWS validates that the Salesforce org returned by OAuth matches the org that started the connection.

## Bootstrap V2 Trust Flow

After OAuth succeeds:

1. AWS exchanges the authorization code server-to-server using TwinaForms-owned OAuth client credentials.
2. AWS verifies the returned Salesforce org id.
3. AWS calls the packaged Apex REST endpoint in that authenticated org.
4. Apex returns a per-org Bootstrap V2 signing secret generated and stored in protected package storage.
5. AWS stores the signing secret in the org-specific Salesforce connection secret.
6. Future package-to-AWS calls are signed with HMAC-SHA256 from Apex.

The signing secret is not shown to the browser or customer.

## What AWS Stores

Store the TwinaForms source-org External Client App credentials once in AWS:

- recommended secret name: `TwinaForms/SalesforceOAuthClient`
- fields: `client_id`, `client_secret`
- Lambda env var: `SALESFORCE_OAUTH_CLIENT_SECRET_NAME`

Store one Secrets Manager entry per Salesforce org:

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
- `bootstrap_v2_signing_secret_b64`
- `bootstrap_v2_status`
- `bootstrap_v2_updated_at`

Also update the tenant record in DynamoDB:

- `salesforceConnectionStatus`
- `salesforceConnectionUpdatedAt`
- optional connected user metadata

## Runtime Usage

At runtime:

1. Lambda loads form data by form id / publish id.
2. Lambda gets `orgId` from the form or tenant record.
3. Lambda loads `NativeForms/SalesforceConnection/<orgId>`.
4. Lambda loads the central TwinaForms OAuth client credentials from AWS Secrets Manager.
5. Lambda refreshes the Salesforce access token with the tenant refresh token.
6. Lambda reads or writes that subscriber org's Salesforce data.

Package-originated management calls from Salesforce to AWS use direct HTTPS endpoints plus Bootstrap V2 HMAC signatures.

## Important Separation

TwinaForms has three separate trust layers:

1. Salesforce org connection
- Salesforce OAuth
- org-specific refresh token and instance URL
- used by AWS to call Salesforce APIs

2. Package-to-AWS service access
- per-org Bootstrap V2 signing secret
- HMAC-signed Apex requests
- used by Salesforce package calls to AWS

3. Public form auth
- per-form publish token
- used by published HTML prefill and submit endpoints

These should remain separate.

## Packaging Direction

For the next TwinaForms managed beta package:

- include the package-safe External Client App metadata in the managed package
- package the app header and OAuth settings
- do not package Salesforce Named Credential metadata
- do not package Salesforce External Credential metadata
- do not ask subscribers to copy Consumer Key or Consumer Secret
- do not ask subscribers to create service-access permission sets
- keep the source External Client App in the persistent Dev Hub/source org
- set the Dev Hub/source External Client App refresh token policy to `Refresh token is valid until revoked`
- use packaged Remote Site Settings for direct AWS HTTPS endpoints

This keeps setup customer-light while keeping the Salesforce OAuth trust boundary explicit.

## Current Implementation Note

The Lambdas support:

- tenant registration
- tenant status/subscription enforcement
- per-org Salesforce connection lookup in Secrets Manager
- Bootstrap V2 HMAC verification for Salesforce-originated package calls

The package should now be validated in a clean subscriber org with no Named Credential or External Credential setup.
