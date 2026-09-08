# TwinaForms - Describe Your Solution

Date: 2026-08-24

Package version: TwinaForms managed package `0.14.0.1`

AppExchange / Subscriber Package ID: `033gL0000009ZbFQAU`

Subscriber Package Version ID: `04tgL000000OO9FQAW`

## Executive Summary

TwinaForms is a managed Salesforce package and AWS-hosted runtime that lets Salesforce admins design, publish, and operate Salesforce-connected public web forms.

The Salesforce package provides the administration surface: setup, OAuth connection, form design, page-layout import, publish management, prefill and submit configuration, connected-org import/export, submission logs, and user access management. The AWS runtime hosts public form artifacts, validates public form requests, performs tenant-scoped Salesforce API operations, stores runtime security records, and exposes protected service APIs used by the package.

The solution is designed for multi-tenant packaged use. Each subscriber Salesforce org is treated as a separate tenant identified by its Salesforce `orgId`. The security model separates:

- subscriber org connection trust
- package-to-AWS service trust
- public form runtime trust
- connected-org import/export trust
- Agentforce-assisted draft creation inside Salesforce

After the customer connects their Salesforce org with OAuth, TwinaForms creates a private per-org signing secret that lets Salesforce prove to AWS that later package service calls came from the installed TwinaForms package in that org.

When a form is published, the Salesforce package generates a per-form publish token. AWS stores a hashed copy with the server-side form policy, and the public form uses that token when calling the prefill and submit endpoints. The public browser never receives the tenant service secret, Salesforce OAuth refresh token, AWS secrets, or executable Salesforce command definitions.

## Solution Components

### Salesforce Managed Package

The TwinaForms Salesforce package includes:

- Lightning Web Components for Connect, Home, Designer, published-form management, submission logs, prefill/submit configuration, connected-org imports, permission management, and setup workflows.
- Apex controllers for setup, publishing, AWS callouts, tenant entitlement checks, access management, demo data, user verification, connected-org import/export, Agentforce action support, and submission log handling.
- Custom objects and metadata that store form definitions, form versions, form elements, form actions, publication records, project organization, user-facing configuration, and submission-log cryptography metadata.
- Permission sets for customer users and package setup access.
- Remote Site Settings for direct HTTPS callouts from packaged Apex to the TwinaForms AWS endpoints.

The Salesforce package is responsible for building forms, configuring allowed Salesforce objects/fields/actions, publishing generated HTML artifacts, importing forms from Salesforce page layouts, importing forms from connected-org snapshots, and calling AWS service endpoints through package-controlled callout logic.

### AWS Runtime

The AWS runtime contains these main Lambda services:

- Salesforce backend Lambda for tenant setup, OAuth callback handling, tenant status, signed service-access checks, form registration, publish/unpublish support, plan/entitlement responses, Salesforce metadata assist routes, connected-org management, and portable snapshot import/export routes.
- Prefill Lambda for public browser prefill requests against published form policy.
- Submit Lambda for public browser submit requests against published form policy.
- Submission Logs API Lambda for protected Salesforce-facing submission log list/detail/config routes.
- Admin API Lambda for TwinaForms operational administration, protected by Cognito.

AWS storage includes:

- DynamoDB tenant records keyed by Salesforce `orgId`.
- DynamoDB form security records keyed by form id and associated with the owning `orgId`.
- DynamoDB submission log records with tenant-scoped indexes and TTL retention.
- DynamoDB connected-org membership and portable snapshot metadata records.
- Private S3 storage for portable form snapshot JSON.
- Public S3/CloudFront storage for generated published form artifacts.
- AWS Secrets Manager entries for the central TwinaForms OAuth client configuration and per-org Salesforce connection records.

## Setup and Trust Flow

### Tenant Registration and OAuth

When a subscriber installs TwinaForms, an admin opens the packaged Connect page and prepares the org connection. The Connect page gathers non-secret org setup context such as `orgId`, admin email, company name, and org login base URL. The admin then authorizes TwinaForms through Salesforce OAuth.

AWS exchanges the Salesforce OAuth authorization code server-to-server using TwinaForms-owned OAuth client credentials. AWS validates that the Salesforce org returned by OAuth matches the org that initiated setup. AWS then stores the org-specific refresh token, instance URL, and connection metadata in AWS Secrets Manager under that org id.

Subscriber admins do not create Salesforce Named Credentials, External Credentials, or customer-managed OAuth client secrets for this setup path.

### Package Service Access

After OAuth succeeds, AWS uses the freshly authorized Salesforce OAuth access token to call a packaged Apex endpoint inside the authenticated subscriber org. Salesforce requires the OAuth access token, and Apex validates that the requested `orgId` matches `UserInfo.getOrganizationId()` before returning or creating the private per-org signing secret. AWS stores the resulting signing secret in the org-specific Salesforce connection secret.

Later package-to-AWS calls are signed by Apex with HMAC headers. Each signed request includes the org id, timestamp, nonce, body hash, and signature. AWS verifies each request within a short timestamp window and records nonces so the same signed request cannot be replayed successfully after it has already been used.

Protected package-to-AWS calls include tenant service-health checks, form registration, publish/unpublish operations, tenant entitlement/home-summary calls, Salesforce metadata assist routes, connected-org routes, portable snapshot routes, and submission log API calls.

## Public Form Runtime Security

Each published form has:

- a form id
- an owning Salesforce `orgId`
- a published version id
- a per-form publish token
- a server-side form security record in DynamoDB
- prefill and submit policies
- stored prefill and submit definitions generated by the Salesforce package

The public browser sends only the form id, publish token, and user input or lookup parameters. The browser does not send executable command definitions, object allowlists, field allowlists, tenant secrets, OAuth tokens, or Salesforce credentials.

AWS validates the form id, publish token hash, form status, tenant status, allowed parameters, command allowlists, object allowlists, writable fields, and form security mode before any Salesforce read or write operation is attempted.

## Connected-Org Import/Export

TwinaForms 0.14 includes connected-org import/export for moving latest published form definitions between connected Salesforce orgs, such as sandbox and production.

An admin can connect another Salesforce org from TwinaForms setup. The connection uses Salesforce OAuth and package-to-AWS service trust. Connected org membership is stored in AWS, and AWS checks that both the requesting org and source org are active members of the same connected group before listing or returning snapshots.

After publish, TwinaForms can save the latest published portable form JSON snapshot to AWS through:

- `POST /portable-snapshots/latest`

Target orgs can list and retrieve snapshots through:

- `GET /portable-snapshots`
- `GET /portable-snapshots/{sourceOrgId}/{globalFormKey}`

Portable snapshot APIs are protected package-to-AWS routes. They do not use public form publish tokens. They do not expose Salesforce OAuth refresh tokens, tenant signing secrets, public form publish tokens, source Salesforce record ids, Salesforce file ids, or source publication records.

Imports from connected org snapshots always create Draft versions for review in the target org. TwinaForms does not automatically publish imported snapshots.

## Agentforce Action

TwinaForms 0.14 includes an Agentforce-compatible Apex invocable action:

- Action label: `Create TwinaForms Form from Page Layout`
- Apex class: `NativeFormsAgentforceActions`
- Method: `createFormFromPageLayout`

An admin can ask Agentforce to create a TwinaForms form from a Salesforce object page layout. If one layout is available, the action creates a Draft TwinaForms form. If several layouts are available, it returns choices so Agentforce can ask the user which layout to use. The action returns the draft form id, version id, field counts, warnings, and a Designer URL.

The action creates Draft forms only. It does not publish forms automatically. A Salesforce admin reviews the generated draft in TwinaForms Designer before publishing.

## Submission Logs

TwinaForms records operational submission history for subscriber-org auditability and troubleshooting inside Salesforce. Submission logs are tenant-scoped and use plan-based retention. Basic metadata records outcome, submission reference, form id, time, and failure category.

Detailed submission log payloads are encrypted before storage when the tenant plan supports detail logs and the tenant key configuration is ready. The design uses a hybrid encryption model:

- Salesforce stores hidden org-level cryptographic material.
- AWS stores only the synced public key and key version.
- AWS encrypts detail payloads with a one-time AES key.
- AWS encrypts the AES key with the org public key.
- The Salesforce Submission Logs UI decrypts detail using the org-side private key.

## Security Controls Summary

Key controls include:

- Salesforce OAuth authorization code flow with refresh token support.
- Org id validation during OAuth callback.
- One AWS Secrets Manager connection record per subscriber org.
- HMAC signing for package-to-AWS service calls using the private per-org signing secret.
- Protected package storage for org signing secrets.
- Per-form publish tokens generated by the Salesforce package and stored as hashes in AWS.
- Server-side form policies for command, object, and field allowlists.
- Tenant-scoped DynamoDB records and tenant-active checks.
- Connected-org group membership checks before snapshot list/download.
- Private S3 storage for portable snapshot JSON.
- Draft-only connected-org imports.
- Draft-only Agentforce page-layout action.
- No browser-visible tenant secret, OAuth refresh token, AWS secret, or executable command definition.
- Submission detail encryption before DynamoDB storage.


