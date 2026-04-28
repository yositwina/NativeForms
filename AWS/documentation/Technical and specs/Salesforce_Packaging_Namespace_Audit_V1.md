# Salesforce Packaging Namespace Audit V1

Current TwinaForms managed 2GP package:
- package name: `TwinaForms`
- package id: `0HogL0000002CUvSAM`
- latest beta package version id: `08cgL0000008gbZQAQ`
- latest package2 version id: `05igL0000002uR7QAI`
- latest subscriber package version id: `04tgL000000ENMXQA4`
- latest install URL: `https://login.salesforce.com/packaging/installPackage.apexp?p0=04tgL000000ENMXQA4`

Packaging note:
- do not rely on `externalCredentialPrincipalAccesses` packaging inside shipped permission sets for TwinaForms install flow
- subscriber setup must still include the manual External Credential Principal Access enablement step
- current beta packaging should include the package-safe External Client App header and OAuth settings metadata; subscriber setup should not ask for Consumer Key or Consumer Secret because OAuth settings are hidden for installed External Client Apps
- AWS must use the TwinaForms-owned source-org External Client App client credentials centrally, while each subscriber org stores only its refresh token and instance URL
- packageable External Client App source metadata must come from the persistent Dev Hub/source org, not an ephemeral scratch org; use retrieved `orgScopedExternalApp` and `oauthLink` values
- package-owned email templates must not live in `unfiled$public`; use a dedicated package email folder to avoid install collisions with subscriber templates
- ship only one packaged Salesforce app in App Launcher, `TwinaForms`; admin/support-debug tooling must live inside that app as a gated area controlled by the AWS admin flag plus the `TwinaForms Admin` permission set
- LWC-to-Apex save/update/register calls should use primitive parameters or JSON string payloads, not custom Apex inner-class DTO parameters

Date: 2026-04-27

## Purpose

Before creating the first managed package version, TwinaForms needs a namespace-readiness audit so a clean subscriber install does not fail because of string-based metadata names.

Target namespace assumption:

- `twinaforms`

Expected managed names include:

- `twinaforms__NF_Form__c`
- `twinaforms__NF_Form_Version__c`
- `twinaforms__NF_Form_Element__c`
- `twinaforms__NF_Form_Action__c`
- `twinaforms__NF_Form_Publication__c`

## Audit Summary

The core Apex object model is mostly package-safe because it uses compile-time Apex references such as `NF_Form__c`, `NF_Form_Version__c`, and direct SOQL. Managed packaging should resolve those references inside the package namespace.

The main namespace risk is string-based metadata naming:

- Named Credential callout names
- External Credential principal access names
- Permission Set lookup/assignment logic
- customer-facing setup docs that mention technical names
- clean-org install validation

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

These compile inside the namespace and should not require manual `twinaforms__` prefixes in Apex source.

Rule:

- Do not add namespace prefixes to Apex source object/field references.
- Let Salesforce packaging compile them into the package namespace.

### 2. Dynamic Schema Lookups

Status: acceptable, with clean-install validation required.

The app uses `Schema.getGlobalDescribe()` mostly for customer Salesforce objects and fields selected in Prefill/Submit/Designer mappings.

Examples:

- `NativeFormsDesignerController`
- `NativeFormsPrefillActionsController`
- `NativeFormsSubmitActionsController`
- `NativeFormsPublisher`

These helpers canonicalize object/field names through describe results. That is good for customer objects like `Contact`, `Case`, and custom customer fields.

Risk:

- If package object names are ever stored as plain strings in config JSON and passed through dynamic describe, those strings may need namespace-aware resolution.

Current recommendation:

- No immediate code change.
- Add clean-package QA that opens Designer, Prefill, Submit, and Publish in an installed subscriber org.

### 3. Named Credentials

Status: code is intentionally namespace-aware.

The package has these Named Credentials:

- `NativeForms`
- `NativeForms_Bootstrap`
- `NativeForms_SubmissionLogs`

Apex callouts build names dynamically:

- `NativeFormsAwsClient.namedCredentialName()`
- `NativeFormsSetupController.bootstrapNamedCredentialName()`
- `NativeFormsHomeController.bootstrapNamedCredentialName()`
- `NativeFormsSubmissionLogsController.namedCredentialName()`

The current pattern derives namespace from `ClassName.class.getName()` and returns:

- unmanaged/dev org: `NativeForms`
- managed subscriber org: `twinaforms__NativeForms`

This is the right packaging-safe direction.

Clean-org validation required:

- Connect Step 1 can call `twinaforms__NativeForms_Bootstrap`.
- Publish can call `twinaforms__NativeForms`.
- Submission Logs can call `twinaforms__NativeForms_SubmissionLogs`.

### 4. External Credentials And Principal Access

Status: highest-risk area to validate.

Packaged external credentials:

- `TwinaFormsBootstrap`
- `TwinaFormsLambdaAuth`

Packaged principals:

- `TwinaFormsBootstrapPrincipal`
- `TwinaFormsSharedSecret`

Permission-set metadata currently grants:

- `TwinaFormsBootstrap-TwinaFormsBootstrapPrincipal`
- `TwinaFormsLambdaAuth-TwinaFormsSharedSecret`

Risk:

- In a managed package install, Salesforce may display and/or internally reference these as namespaced principal entries.
- The package metadata may resolve this correctly, but this must be verified in a real install org.

Clean-org validation required:

- Install package.
- Assign `TwinaForms User`.
- Confirm External Credential Principal Access is present/effective for:
  - Bootstrap
  - Shared Secret
- Run Connect without manually adding principal access.
- Publish without manually adding principal access.

If this fails:

- Treat it as packaging blocker.
- Adjust permission-set metadata or post-install guidance before first release.

### 5. Permission Sets

Status: mostly safe in code, docs need namespace-aware wording.

Packaged permission sets:

- source full name: `TwinaForms_User`
- source full name: `NativeForms_Admin`
- labels:
  - `TwinaForms User`
  - `TwinaForms Admin`

`NativeFormsHomeController` queries by permission set `Label`, not `DeveloperName`.

That is good because labels should remain customer-visible and not namespace-prefixed.

Risk:

- Setup docs may mention permission-set API names or old technical names.
- Subscriber Setup UI may show namespaced API names while labels stay friendly.

Rule:

- Customer-facing docs should tell users to assign by label:
  - `TwinaForms User`
  - `TwinaForms Admin`
- Avoid telling users to search for developer names unless unavoidable.

### 6. Lightning App And Tabs

Status: packaging visibility needs a product rule.

The labels seen by users can stay friendly:

- `TwinaForms`

Internal names will be namespaced after packaging.

Risk:

- A separate packaged `TwinaForms Admin` app appears in App Launcher immediately after install, even when the tenant-level admin flag is closed.
- AWS can gate admin/debug functionality, but it cannot dynamically hide or reveal a packaged Lightning app tile in App Launcher.

Rule:

- Ship only the main `TwinaForms` app.
- Keep admin/debug features inside that app as a gated tab/area.
- Use the AWS admin flag plus `TwinaForms Admin` permission-set access to control who can actually use that area.

Clean-org validation required:

- Assigned `TwinaForms User` can see the main app and tabs.
- Assigned `TwinaForms Admin` can see the gated admin/debug area inside the main app when intended.

### 7. AWS Side

Status: no direct dependency on Salesforce package namespace found.

AWS runtime endpoints identify tenants/forms by:

- org id
- form id / publish id
- tenant secrets
- AWS plan/tenant records

AWS does not need to know Salesforce Named Credential names.

Important:

- Do not add Salesforce namespace awareness to AWS unless a Salesforce payload contract explicitly requires it.
- Keep namespace concerns inside Salesforce package code and metadata.

### 8. LWC-To-Apex DTO Binding

Status: package-hardening required.

Managed package QA found that `NativeFormsSetupController.registerOrg` could fail from LWC with only a Salesforce internal server error before Apex debug logs were written. The Aura request reached `aura://ApexActionController/ACTION$execute`, but the method used an Apex inner-class DTO parameter from packaged LWC.

Rule:

- For LWC-called package-visible save/update/register methods, avoid custom Apex DTO parameters.
- Pass complex request bodies as `String inputJson` or `String requestJson`.
- Deserialize inside Apex with `JSON.deserialize`.
- Keep response DTOs as Apex classes; the observed risk is request parameter binding before Apex execution.

Clean-org validation required:

- Connect `Generate Secret`.
- Admin feature save.
- Theme save.
- Builder element save.
- Prefill action save.
- Submit action save.

## Pre-Package Checklist

Before first managed package version:

1. Confirm target namespace is final: `twinaforms`.
2. Create a packaging org/package version.
3. Install into a clean subscriber test org.
4. Assign `TwinaForms User` by label.
5. Open `TwinaForms Connect`.
6. Verify Connect Step 1 without manually adding External Credential Principal Access.
7. Save tenant secret into packaged Named Credential principal.
8. Verify Connect Step 2.
9. Open Designer.
10. Create a form.
11. Add fields, including Time, Formula, File Upload, and Records List if plan allows.
12. Publish.
13. Submit a public form.
14. Open Submission Logs.
15. Assign/remove `TwinaForms User` from Connect User Access.
16. If admin flag is open, assign/remove `TwinaForms Admin`.
17. Confirm no setup screen or help text tells users to use unmanaged API names.

## Blockers To Watch

Treat any of these as package blockers:

- Named Credential callout fails because Apex used the wrong namespaced name.
- External Credential Principal Access is not effective after assigning packaged permission set.
- External Client App Manager does not show the packaged `TwinaForms` app after install.
- Permission-set management cannot find packaged permission sets.
- App/tabs are not visible after permission-set assignment.
- Docs/screens instruct users to configure unmanaged principal names that do not exist in subscriber org.
- LWC action returns a Salesforce internal server error with no Apex log because request DTO binding failed before the Apex method body.

## Current Recommendation

Do not create the release package until a clean managed-install org confirms:

- named credential namespace helper works
- external credential principal access is packaged correctly
- `TwinaForms User` alone is enough for normal Connect/Designer/Publish flow
