# Salesforce Packaging Namespace Audit V1

Last updated: 2026-05-10

## Current TwinaForms Managed 2GP Package

- package name: `TwinaForms`
- package id: `0HogL0000002CUvSAM`
- latest beta package version create request id: `08cgL00000097WvQAI`
- latest package2 version id: `05igL00000037mXQAQ`
- latest subscriber package version id: `04tgL000000F7VpQAK`
- latest install URL: `https://login.salesforce.com/packaging/installPackage.apexp?p0=04tgL000000F7VpQAK`
- target namespace: `twinaforms`

## Packaging Note

The current target install flow is Bootstrap V2:

- no Salesforce Named Credential metadata in the managed package
- no Salesforce External Credential metadata in the managed package
- no subscriber-created service-access permission set
- package-to-AWS calls use direct HTTPS endpoints and Bootstrap V2 HMAC signatures
- Salesforce OAuth remains the first trust anchor for the org connection

## Purpose

Before creating a managed package version, TwinaForms needs a namespace-readiness audit so a clean subscriber install does not fail because of string-based metadata names.

## Audit Summary

The core Apex object model is mostly package-safe because it uses compile-time Apex references such as `NF_Form__c`, `NF_Form_Version__c`, and direct SOQL. Managed packaging should resolve those references inside the package namespace.

The current namespace risks are:

- Permission Set lookup/assignment logic
- packaged Remote Site Settings
- External Client App package metadata
- customer-facing setup docs that mention technical names
- clean-org install validation

Named Credentials and External Credentials are intentionally removed from the package flow and are no longer namespace risks.

## Findings

### 1. Apex Object References

Status: mostly safe.

Most package objects are referenced directly in Apex:

- `NF_Form__c`
- `NF_Form_Version__c`
- `NF_Form_Element__c`
- `NF_Form_Action__c`
- `NF_Form_Publication__c`
- `NF_Project__c`
- `NF_Theme__c`
- `NativeForms_Config__c`

Rule:

- Do not add namespace prefixes to Apex source object/field references.
- Let Salesforce packaging compile them into the package namespace.

### 2. Dynamic Schema Lookups

Status: acceptable, with clean-install validation required.

The app uses `Schema.getGlobalDescribe()` mostly for customer Salesforce objects and fields selected in Prefill, Submit, and Designer mappings.

Risk:

- If package object names are ever stored as plain strings in config JSON and passed through dynamic describe, those strings may need namespace-aware resolution.

Current recommendation:

- No immediate code change.
- Add clean-package QA that opens Designer, Prefill, Submit, and Publish in an installed subscriber org.

### 3. Package-To-AWS Callouts

Status: Bootstrap V2 direct HTTPS.

The package should use:

- packaged Remote Site Settings for AWS Lambda and S3 endpoints
- direct HTTPS endpoints in Apex
- Bootstrap V2 HMAC request headers

The package should not use:

- Salesforce Named Credentials
- Salesforce External Credentials
- External Credential Principal Access

Clean-org validation required:

- Connect can prepare the AWS OAuth URL without a Salesforce callout.
- OAuth callback completes and stores the org connection in AWS.
- `tenant/auth-health` verifies signed service access.
- Publish can call AWS with HMAC signatures.
- Submission Logs can call AWS with HMAC signatures.

### 4. Permission Sets

Status: mostly safe in code.

Packaged permission sets:

- source full name: `TwinaForms_User`
- source full name: `NativeForms_Admin`
- labels:
  - `TwinaForms User`
  - `TwinaForms Admin`

`NativeFormsHomeController` queries by permission set `Label`, not `DeveloperName`.

Rule:

- Customer-facing docs should tell users to assign by label:
  - `TwinaForms User`
  - `TwinaForms Admin`
- Avoid telling users to search for developer names unless unavoidable.
- Do not document a `TwinaForms Service Access` permission set for the Bootstrap V2 install flow.

### 5. Lightning App And Tabs

Status: packaging visibility needs validation.

The label seen by users can stay friendly:

- `TwinaForms`

Rule:

- Ship only the main `TwinaForms` app.
- Keep admin/debug features inside that app as a gated tab/area.
- Use the AWS admin flag plus `TwinaForms Admin` permission-set access to control who can actually use that area.

Clean-org validation required:

- Assigned `TwinaForms User` can see the main app and tabs.
- Assigned `TwinaForms Admin` can see the gated admin/debug area inside the main app when intended.

### 6. AWS Side

Status: no direct dependency on Salesforce package namespace found.

AWS runtime endpoints identify tenants/forms by:

- org id
- form id / publish id
- per-form publish token
- Bootstrap V2 signing secret stored per org
- AWS plan/tenant records

AWS does not need to know Salesforce package namespace details.

### 7. LWC-To-Apex DTO Binding

Status: package-hardening rule.

Managed package QA found that LWC calls can fail with a Salesforce internal server error before Apex debug logs are written when package-visible methods accept custom Apex inner-class DTO parameters.

Rule:

- For LWC-called package-visible save/update/register methods, avoid custom Apex DTO parameters.
- Pass complex request bodies as `String inputJson` or `String requestJson`.
- Deserialize inside Apex with `JSON.deserialize`.
- Keep response DTOs as Apex classes.

## Pre-Package Checklist

Before the next managed package version:

1. Confirm target namespace is final: `twinaforms`.
2. Create a package version.
3. Install into a clean subscriber test org.
4. Assign `TwinaForms User` by label.
5. Open `TwinaForms Connect`.
6. Verify Connect without creating Named Credentials or External Credentials.
7. Complete Salesforce OAuth.
8. Verify signed service access.
9. Assign/remove `TwinaForms User` from Connect User Access.
10. Open Designer.
11. Create a form.
12. Add fields, including Time, Formula, File Upload, and Records List if plan allows.
13. Publish.
14. Submit a public form.
15. Open Submission Logs.
16. If admin flag is open, assign/remove `TwinaForms Admin`.
17. Confirm no setup screen or help text tells users to configure old service credentials.

## Blockers To Watch

Treat any of these as package blockers:

- any Apex/LWC/package metadata still references Salesforce Named Credentials
- any Apex/LWC/package metadata still references Salesforce External Credentials
- Connect fails in a clean org before OAuth because setup access is missing
- Permission-set management cannot find packaged permission sets
- App/tabs are not visible after permission-set assignment
- LWC action returns a Salesforce internal server error with no Apex log because request DTO binding failed before the Apex method body

## Current Recommendation

Do not create the release package until a clean managed-install org confirms:

- `TwinaForms User` alone is enough for normal Connect/Designer/Publish/Logs flow
- Connect and publish use Bootstrap V2 HMAC, not Salesforce Named/External Credentials
- customer-facing setup text does not mention the old service-access setup
