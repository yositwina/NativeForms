# TwinaForms Data Flow, Authentication, Encryption, and Usage

Date: 2026-08-24

Package version: TwinaForms managed package `0.14.0.1`

AppExchange / Subscriber Package ID: `033gL0000009ZbFQAU`

Subscriber Package Version ID: `04tgL000000OO9FQAW`

## Purpose

This document explains how TwinaForms moves information between Salesforce, AWS, public published forms, connected Salesforce orgs, and Agentforce-assisted admin workflows. It covers usage flow, information flow, authentication, encryption in transit and at rest, and Salesforce data touchpoints.

## Basic Usage Instructions

1. A Salesforce admin installs the TwinaForms managed package.
2. The admin opens the TwinaForms app and goes to the Connect page.
3. The admin connects the subscriber org to TwinaForms through Salesforce OAuth.
4. TwinaForms verifies secure package service access between Salesforce and AWS.
5. The admin grants TwinaForms user access to selected Salesforce users.
6. The admin designs a form in Salesforce using the TwinaForms Designer, imports a Salesforce page layout, imports a connected-org snapshot, or asks Agentforce to create a draft from a Salesforce page layout.
7. The admin configures allowed Salesforce objects, fields, prefill behavior, and submit behavior.
8. The admin publishes the form.
9. Salesforce registers the published form policy with AWS and uploads the generated public form artifact.
10. TwinaForms can save the latest published portable snapshot to AWS for connected-org import.
11. End users open the public form URL, optionally prefill data, and submit the form.
12. AWS validates the published form request and performs tenant-scoped Salesforce API operations based on the server-side policy.
13. The Salesforce admin can review form records, publication status, connected-org import options, and submission logs in the TwinaForms Salesforce app.

## High-Level Information Flow

### 1. Package Setup and OAuth

The subscriber admin starts in Salesforce. The packaged Connect page sends setup context to AWS, including Salesforce org id, admin email, company name, and login base URL. This initial AWS connect endpoint is intentionally public because it only starts the OAuth setup flow and accepts non-secret setup context.

AWS does not treat this pre-OAuth context as authentication, and it does not grant access to Salesforce data, AWS data, tenant secrets, or protected package service APIs. The admin then authorizes TwinaForms using Salesforce OAuth.

AWS receives the OAuth callback, exchanges the authorization code server-to-server, validates that the returned Salesforce org id matches the org that initiated setup, and stores the org-specific Salesforce connection in AWS Secrets Manager.

After OAuth connection, AWS uses the authorized Salesforce session to retrieve or create a private per-org package service secret from the installed package. Later signed requests include org id, timestamp, nonce, body hash, and HMAC signature.

### 2. Form Design, Page-Layout Import, and Agentforce Draft Creation

The Salesforce package stores form design records in Salesforce custom objects. Admins can create forms directly in Designer or import supported Salesforce page-layout fields into a draft form.

TwinaForms also exposes the `Create TwinaForms Form from Page Layout` Agentforce-compatible Apex invocable action. Agentforce can call this action with an object API name and optional layout selection. The action creates a Draft TwinaForms form and returns a Designer URL for admin review. It does not publish automatically.

### 3. Form Publish

When the admin publishes a form:

- Salesforce generates or uses the form id.
- Salesforce generates a per-form publish token.
- Salesforce sends AWS the server-side form policy and runtime definitions.
- AWS stores a hashed copy of the publish token with the server-side form policy in DynamoDB.
- Salesforce uploads or publishes the generated public form artifact to AWS-hosted form storage.
- TwinaForms can save the latest published portable snapshot to protected AWS storage for connected-org import.

The published public form contains the form id and publish token needed to call the public prefill and submit endpoints. It does not contain Salesforce OAuth tokens, AWS secrets, tenant service secrets, or executable Salesforce command definitions.

### 4. Public Prefill

When a public user opens a form and a prefill request is triggered, the browser sends only the form id, publish token, and allowed lookup parameters to the AWS prefill endpoint.

AWS validates form id, publish token hash, published status, tenant status, allowed parameters, stored prefill commands, and allowed Salesforce objects before querying Salesforce. The browser cannot choose arbitrary Salesforce objects, fields, or SOQL.

### 5. Public Submit

When a public user submits a form, the browser sends the form id, publish token, and user-entered form values to the AWS submit endpoint.

AWS validates form id, publish token hash, published status, tenant status, server-side submit policy, configured objects, writable fields, and form security mode before performing Salesforce writeback.

### 6. Connected-Org Portable Snapshots

Connected-org import/export moves latest published TwinaForms form definitions between connected Salesforce orgs.

Flow:

1. An admin connects another org through TwinaForms setup.
2. AWS stores connected-org group membership metadata.
3. After publish, Salesforce sends the latest published portable form JSON to AWS using signed package-to-AWS service access.
4. AWS stores snapshot metadata in DynamoDB and the portable JSON in private S3.
5. A target connected org lists available snapshots.
6. The admin selects a snapshot and TwinaForms loads it into the existing import preview.
7. Import creates a Draft version in the target org.

Portable snapshots are form definitions, not submitted form responses. They do not include Salesforce OAuth refresh tokens, tenant signing secrets, public form publish tokens, source Salesforce record ids, source Salesforce file ids, source file URLs, or source publication records.

### 7. Submission Logs

TwinaForms writes tenant-scoped submission log metadata to AWS for auditability and troubleshooting inside Salesforce. Basic metadata includes submission reference, form id, submitted time, outcome, failure category, and retention fields.

When detailed logs are enabled by plan and key configuration, submitted values and technical details are encrypted before storage. Plain log metadata does not include submitted values or raw Salesforce/API failure text.

## Authentication Model

### Salesforce OAuth

TwinaForms uses Salesforce OAuth authorization code flow for subscriber org connection. AWS exchanges the authorization code server-to-server and validates the returned Salesforce org id. AWS stores the resulting org-specific refresh token and instance URL in AWS Secrets Manager.

### Package-to-AWS Service Authentication

Protected package service calls to AWS are signed by Apex using HMAC. Each signed request includes:

- `x-twinaforms-org-id`
- `x-twinaforms-bootstrap-v2-timestamp`
- `x-twinaforms-bootstrap-v2-nonce`
- `x-twinaforms-bootstrap-v2-body-sha256`
- `x-twinaforms-bootstrap-v2-signature`
- `x-twinaforms-bootstrap-v2-algorithm`

AWS verifies the signature, timestamp, body hash, nonce, and org context before accepting protected package service requests.

### Public Form Authentication

Public forms do not use the tenant service secret or Salesforce OAuth token. Each published form uses a per-form publish token generated by the Salesforce package during publish. AWS stores only a hashed copy of the publish token with the server-side form policy.

The publish token is not sufficient by itself. AWS also validates form id, form status, tenant status, command allowlists, object allowlists, field allowlists, and form security mode.

### Connected-Org Snapshot Authorization

Connected-org snapshot APIs use package-to-AWS service authentication, not public form tokens. AWS authorizes snapshot list and download only when:

- the requesting org is an active member of a connected org group
- the source org is an active member of the same group
- the snapshot belongs to that group

### Agentforce Action Authorization

The Agentforce page-layout action runs inside Salesforce as an Apex invocable action. It is not a public AWS endpoint. It creates Draft forms only and relies on Salesforce session, package permissions, Apex sharing, and existing TwinaForms Designer/page-layout import logic.

## Encryption and Data Protection

### Encryption in Transit

TwinaForms uses HTTPS/TLS for network communication between:

- Salesforce packaged Apex and AWS Lambda endpoints
- AWS OAuth callback and Salesforce OAuth/token endpoints
- public browser forms and AWS prefill/submit endpoints
- browser users and published form hosting
- Salesforce users and Salesforce Lightning pages

Package-to-AWS service calls also include HMAC request signing in addition to HTTPS transport protection.

### Token and Secret Storage

Salesforce OAuth refresh tokens are stored in AWS Secrets Manager in org-specific secrets. The central TwinaForms OAuth client configuration is also stored in AWS Secrets Manager.

The private per-org package service signing secret is stored in protected package-managed Salesforce storage and in the org-specific AWS connection secret. It is not exposed to the browser, public form HTML, normal Salesforce records, or subscriber users.

### Data at Rest

AWS stores tenant records, form security policies, connected-org membership, portable snapshot metadata, and submission log metadata in DynamoDB. DynamoDB provides encryption at rest through AWS-managed encryption.

AWS Secrets Manager stores OAuth and connection secrets using AWS-managed secret storage controls.

Published public form artifacts are stored in S3 and served through CloudFront. Portable snapshot JSON is stored separately in private S3 storage and is accessed only through protected package-to-AWS routes.

### Submission Log Detail Encryption

When detailed submission logs are enabled, sensitive submission details are encrypted before being stored in DynamoDB. The design uses a hybrid encryption model:

- Salesforce stores hidden org-level cryptographic material.
- AWS stores only the synced public key and key version.
- AWS encrypts detailed payloads with a one-time AES key.
- AWS encrypts the AES key with the org public key.
- The Salesforce Submission Logs UI decrypts detail using org-side private key material.

## Salesforce Data Touchpoints

### Data Stored in Salesforce

The managed package stores form configuration in Salesforce custom objects, including:

- projects
- forms
- form versions
- form elements
- form actions
- publication records
- package configuration
- submission-log key metadata

Agentforce-assisted form creation creates the same Draft form/version/element records that the normal Designer page-layout import flow creates.

### Data Stored in AWS

TwinaForms stores limited Salesforce-related data in AWS:

- tenant metadata in DynamoDB
- org-specific Salesforce OAuth connection records in AWS Secrets Manager
- server-side form security policies and runtime definitions in DynamoDB
- generated public form artifacts in S3/CloudFront
- connected-org membership metadata in DynamoDB
- portable snapshot metadata in DynamoDB
- portable snapshot JSON in private S3
- submission log metadata in DynamoDB
- encrypted submission log detail in DynamoDB when enabled

### Data Used At Runtime But Not Stored In Public Artifacts

The public browser does not receive:

- Salesforce OAuth refresh tokens
- Salesforce access tokens
- AWS secrets
- tenant service secrets
- private per-org signing secrets
- executable Salesforce command definitions
- Salesforce object/field allowlists used for server enforcement
- portable snapshot JSON for protected connected-org imports unless loaded by an authenticated package admin flow

## Data Flow Summary

1. Salesforce admin connects the org to TwinaForms through OAuth.
2. Salesforce and AWS establish package-to-AWS HMAC service trust.
3. Salesforce admin creates a form directly, imports a layout, imports a connected snapshot, or asks Agentforce to create a draft from a layout.
4. Salesforce publishes a reviewed form.
5. Salesforce registers the form policy with AWS using signed package service access.
6. AWS stores the policy and hashed publish token.
7. AWS hosts the public form artifact.
8. A public user opens the form and submits data through HTTPS.
9. AWS validates form id, publish token, tenant status, and server-side policy.
10. AWS uses the org-specific Salesforce connection to perform allowed Salesforce API operations.
11. AWS writes tenant-scoped submission log metadata and encrypted detail when enabled.
12. Salesforce admins review records and logs inside the TwinaForms Salesforce app.
13. Connected orgs can import latest published portable snapshots as Draft versions for review.
