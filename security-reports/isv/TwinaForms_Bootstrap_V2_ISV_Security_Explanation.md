# TwinaForms Bootstrap V2 Security Explanation

## Purpose

This document explains the TwinaForms managed-package connection flow used to connect a subscriber Salesforce org to the TwinaForms AWS service.

The goal of the new Bootstrap V2 flow is to make installation simpler for subscriber admins while keeping Salesforce-to-AWS communication authenticated, tenant-isolated, and reviewable.

## Summary Of The Connection Flow

TwinaForms uses Salesforce OAuth as the first trust anchor between the subscriber org and the TwinaForms AWS service.

The subscriber admin opens the packaged TwinaForms Connect page and starts the connection. Salesforce opens the OAuth authorization screen. After the admin approves access, Salesforce redirects back to the TwinaForms AWS callback endpoint with an authorization code.

AWS exchanges that authorization code with Salesforce over TLS. AWS then verifies that the Salesforce org returned by OAuth is the same org that started the connection. Only after that org match succeeds does AWS save the org-specific OAuth connection and proceed with Bootstrap V2.

After OAuth succeeds, AWS uses the OAuth access token to call a packaged Apex REST endpoint inside the same authenticated subscriber org. That Apex endpoint returns a per-org signing secret that was generated and stored by the managed package in protected package-managed storage.

Future Salesforce package calls to AWS are signed with HMAC-SHA256 using that per-org signing secret. AWS verifies the signature before accepting those calls.

## Why OAuth Is The First Step

OAuth proves that a real Salesforce admin or authorized user approved TwinaForms access for the subscriber org.

The authorization code cannot be used by the browser alone to create a trusted connection. AWS exchanges the code server-to-server with Salesforce using the TwinaForms-owned OAuth client credentials. This lets AWS receive the Salesforce `instance_url`, org identity URL, access token, and refresh token from Salesforce directly.

AWS validates the org id returned by Salesforce OAuth against the org id that initiated the connection. If they do not match, AWS rejects the callback and does not save the connection.

This prevents a user from starting setup for one org and completing OAuth with another org.

## Per-Org Signing Secret

Each subscriber org receives its own Bootstrap V2 signing secret.

The signing secret is generated in Apex using Salesforce cryptographic APIs. It is stored in protected managed-package storage, not in a normal custom object field and not in browser storage.

The signing secret is not shown to the user, not returned to LWC JavaScript, not written to URLs, and not included in customer-facing error messages.

AWS receives this signing secret only after the OAuth callback has already proved the org identity. The transfer happens server-to-server over TLS from Salesforce to AWS, using the OAuth access token received during the callback.

## How Salesforce Calls AWS After Bootstrap

After Bootstrap V2 is ready, Salesforce does not send the raw signing secret on each request.

Instead, Apex signs each request using HMAC-SHA256. The signed request includes:

- Salesforce org id
- timestamp
- nonce
- HTTP method
- request path
- SHA-256 hash of the request body
- HMAC signature
- signature algorithm

AWS recalculates the expected signature using the signing secret stored for that org. If the signature does not match, AWS rejects the request.

This means the secret itself is not repeatedly transmitted after bootstrap.

## Replay Protection

Signed requests include a timestamp and nonce.

AWS rejects requests outside the allowed timestamp window. AWS also records accepted nonces and rejects repeated use of the same nonce for the same org.

For the current spike deployment, nonce records are stored in an existing DynamoDB-backed audit table because the dedicated nonce table is not yet finalized. Before production packaging, the intended design is a dedicated `NativeFormsBootstrapV2Nonces` DynamoDB table with TTL enabled and least-privilege Lambda access.

## Tenant Isolation

TwinaForms stores Salesforce connection data per Salesforce org.

The AWS connection secret for one org contains that org's refresh token, instance URL, login base URL, org identity metadata, and Bootstrap V2 signing material. Requests are verified against the org id in the signed headers and the stored AWS connection record for that org.

AWS does not use one subscriber org's OAuth refresh token or signing secret for another org.

## Why This Removes The Manual External Credential Setup

The older setup required subscriber admins to create or configure permission-set access for Salesforce External Credential Principal Access before the Connect page could call AWS.

Bootstrap V2 avoids that setup dependency for the main connection and package-to-AWS calls.

The packaged Connect page can build the AWS OAuth start URL directly. The first trusted connection is Salesforce OAuth, not a Named Credential callout. After OAuth, future calls are authenticated with HMAC signatures generated by Apex and verified by AWS.

This reduces installation friction while keeping the security boundary explicit:

- OAuth proves the subscriber org and grants AWS a Salesforce connection.
- Protected package storage holds the per-org signing secret.
- HMAC proves future package calls came from the org that owns that signing secret.

## Data Stored In AWS

AWS stores the following org-specific connection data in AWS Secrets Manager:

- Salesforce org id
- Salesforce instance URL
- Salesforce login base URL
- Salesforce OAuth refresh token
- Salesforce OAuth identity URL
- OAuth client source metadata
- Bootstrap V2 signing secret
- Bootstrap V2 status and timestamp metadata

The OAuth client id and client secret for the packaged TwinaForms app are TwinaForms-owned central credentials and are not entered by subscriber admins.

## Data Not Exposed To The Browser

The Bootstrap V2 signing secret is not exposed to:

- LWC JavaScript
- browser session storage
- browser local storage
- URL query parameters
- generated public forms
- customer-facing setup instructions
- standard UI messages

The OAuth callback and AWS storage happen server-side.

## Current Scope

This document describes the Bootstrap V2 connection and package-to-AWS call pattern.

The current Salesforce package implementation is designed to avoid Salesforce Named Credentials and External Credentials for the normal Connect, publish, entitlement, disconnect, and Submission Logs paths.

Submission Logs use a separate AWS Lambda endpoint, but Salesforce calls that endpoint directly over HTTPS and signs those requests with Bootstrap V2 HMAC headers. The separate endpoint is an AWS runtime separation, not a Salesforce Named Credential or External Credential dependency.

Clean subscriber-org testing is still required before packaging to confirm the installed package works without any customer-created Salesforce service credentials.

## Security Rationale For ISV Review

This design is safe for managed-package installation because it avoids customer-entered shared secrets while preserving server-side trust verification.

The first trust decision is Salesforce OAuth, which verifies that the subscriber org authorized TwinaForms. The second trust layer is a per-org HMAC signing secret generated inside Salesforce and stored in protected package-managed storage. AWS accepts signed Salesforce package calls only when the signature, org id, timestamp, nonce, and body hash are valid.

The design does not rely on a hard-coded package secret, does not expose the signing secret to browser code, and does not allow a connection for one org to be completed by OAuth from another org.

The result is a simpler subscriber setup experience with a clearer security model than the manual External Credential Principal Access flow.
