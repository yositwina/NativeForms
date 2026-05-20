# Salesforce Packaging

## Purpose
Keep Codex package-safe when working on Apex, LWC, metadata, object model, and install/setup behavior.

## Use When
Use for package-visible metadata, object changes, tabs/apps/pages, Apex/LWC changes, clean-org install readiness, or release-hardening work.

## NativeForms Rules
- Keep the core package centered on `NF_Form__c`, `NF_Form_Version__c`, `NF_Form_Element__c`, `NF_Form_Action__c`, and `NF_Form_Publication__c`.
- Treat generated HTML and AWS payloads as compiled artifacts, not Salesforce design source records.
- Favor package-safe setup and customer-safe messaging over debug-oriented behavior.
- Assume clean-org validation matters; package work is not done until setup, connect, publish, and core usage make sense without internal knowledge.
- Starter package polish, demo quality, Apex tests, and install/post-install guidance are release-critical.
- Apex test strategy target is `80-85%` overall coverage. Do not optimize for only `75%`, and do not chase `100%` or intentionally push classes above `85%` just to raise numbers.
- For NativeForms Apex tests, start with shared foundations instead of one-off setup in each test:
  - reusable Salesforce fixture factory
  - reusable config JSON builder
  - reusable AWS `HttpCalloutMock` layer
- Do not use the full demo installer as the default Apex test base. Use smaller deterministic fixtures that resemble the demo conceptually but are faster and more stable.
- Default Salesforce deployment alias for this repo is `NativeFormsDev` unless the user explicitly asks for a different org.
- Permission-set split rule: keep ordinary customer access and support/debug admin access separate. `TwinaForms User` should be the counted customer-facing seat, while `TwinaForms Admin` should stay a separate support/debug permission set and gated access path inside the main `TwinaForms` app.
- App packaging rule: ship only one packaged Lightning app in App Launcher, `TwinaForms`. Admin/support-debug tooling belongs inside that app as a gated tab/area, not as a separate packaged `TwinaForms Admin` app tile.
- Permission-set management location rule: manage `TwinaForms User` / `TwinaForms Admin` assignment from the `TwinaForms Connect` page, not `TwinaForms Home`, so setup/access troubleshooting stays in one place. Connect grants/removes only the packaged user/admin permission sets; there is no subscriber-created service-access permission set in the Bootstrap V2 flow.
- Namespace packaging rule: do not add `twinaforms__` prefixes to compile-time Apex object/field references. Do audit string-based metadata names instead, especially Permission Set lookup, app/tab visibility, Remote Site Settings, External Client App metadata, and setup docs. Use `AWS/documentation/Technical and specs/Salesforce_Packaging_Namespace_Audit_V1.md` before creating a package version.
- Managed LWC-to-Apex boundary rule: for package-visible Lightning/Aura methods called from LWC, avoid custom Apex DTO parameters such as inner classes (`MyInput inputValue`) for save/update/register actions. Prefer primitives or `String inputJson`, then deserialize inside Apex. In managed packages, namespace/type binding for custom DTO params can fail before Apex execution, often showing only a Salesforce internal server error and no debug log.
- Named/External Credential removal rule: the managed package install flow should not include Salesforce Named Credential or External Credential metadata. Package-to-AWS calls use direct HTTPS endpoints covered by packaged Remote Site Settings plus Bootstrap V2 HMAC signatures.
- Permission-set lookup rule: product code should find packaged permission sets by customer-facing label (`TwinaForms User`, `TwinaForms Admin`) rather than developer/API name where practical.
- External Credential packaging rule: do not reintroduce customer-facing External Credential Principal Access setup unless explicitly approved. The purpose of Bootstrap V2 is clean install without a subscriber-created credential permission set.
- External Client App packaging rule: include the package-safe External Client App header and OAuth settings in the managed package so subscribers do not create the app manually. Do not package global OAuth settings, consumer credential material, or configurable policy metadata. Installed External Client Apps hide OAuth settings from subscribers, so TwinaForms Connect must not ask customers to copy a Consumer Key or Consumer Secret; AWS uses the TwinaForms-owned source-org client credentials centrally.
- External Client App source-org rule: the packaged app must be owned by a persistent Dev Hub/source org and include Salesforce's retrieved `orgScopedExternalApp` and `oauthLink` values. If package creation says the ECA was created in an ephemeral org, create/deploy the ECA in the Dev Hub/source org, enable `enablePackageEcaOauthFromDevOrg`, retrieve the header/OAuth settings, and retry. Policy metadata is not packageable in this flow.
- External Client App refresh-token rule: for the associated packaged ECA model, set the source-org refresh token policy to valid until revoked. AWS refreshes access tokens centrally and stores/revokes refresh tokens per tenant; do not use a fixed 365-day expiry unless the product intentionally wants annual reconnects.
- Email template packaging rule: do not ship package email templates from `unfiled$public`. Put them in a dedicated package-owned email folder so installs do not collide with subscriber unfiled templates that share the same name.
- Do not show internal page-version labels such as `Designer v20.29` or `Page Version v2.7` in customer-facing package pages.
- In `nativeFormsDesigner`, new text-like property controls must use local draft state while typing and commit only on `blur` or explicit finish. Do not wire `oninput`, mid-typing `applyEditorDraft()`, or save-triggered rerenders for plain text inputs or plain textareas unless the user explicitly wants live preview.
- For repeated property editors such as conditional rows, treat blank/new rows as draft UI state first and sanitize only when persisting. Do not round-trip blank draft rows through saved config too early, or `Add Condition` / selection flows will look broken.
- When a Designer control feels jumpy, misses letters, loses first clicks, or makes buttons seem dead, assume the root cause is usually blur/save/rerender interference before trying layout-only fixes.
- Element type metadata parity rule: before every package version, compare all element types that Apex/LWC can create or import against `force-app/main/default/objects/NF_Form_Element__c/fields/Element_Type__c.field-meta.xml`. New saved element types must be present in the picklist metadata before packaging. Keep `Element_Type__c` unrestricted because it is an internal package enum; a restricted subscriber picklist can reject new package element types after upgrade even when the Designer UI and Apex code support them. Virtual Designer-only elements such as submit button and secret-code controls do not need picklist values unless they are saved as `NF_Form_Element__c` records. Treat a mismatch or a restricted `Element_Type__c` metadata file as a release blocker.
- Branding rule: do not introduce new user-facing `NativeForms` text. Use `TwinaForms` in emails, labels, help text, and UI copy unless the user explicitly asks otherwise or the string is a fixed technical identifier.
- Multilingual rule: do not introduce fixed English customer-facing text inside form canvas previews or published forms unless it is an error/debug message. If helper/action text is needed, make it configurable in Salesforce properties/settings or omit it. Preserve label-placement flexibility instead of compensating with hard-coded English guidance.
- Secret-code rule: avoid fixed English-only preview/runtime copy such as `Locked Until Verified`, `Secret Code Verification`, or `Code step appears after the user presses Enter`. Public-form button labels should be configurable when they are part of the customer experience.
- Current managed 2GP package id for this repo is `0HogL0000002CUvSAM` (`TwinaForms`). Keep `sfdx-project.json` and packaging notes aligned if Salesforce ever returns a replacement package id.
- Current latest released install link is `https://login.salesforce.com/packaging/installPackage.apexp?p0=04tgL000000FtXFQA0` for `TwinaForms@0.8.0-1` / version `0.8.0.1`. It changes `NF_Form_Element__c.Element_Type__c` to unrestricted so subscriber orgs cannot reject `multiCheckbox` or future internal element values after upgrade; code coverage was `84%`. Current latest beta test link is `https://test.salesforce.com/packaging/installPackage.apexp?p0=04tgL000000FtXFQA0` for the same version. Update this skill and `AWS/documentation/Technical and specs/Salesforce_Packaging_Namespace_Audit_V1.md` every time a new package version is created or promoted.
- Package-test reset rule: after creating a new TwinaForms beta package for this test cycle, delete the DynamoDB tenant record `orgId=00Dg5000008sWZN` from `NativeFormsTenants` in `eu-north-1` so the install test starts with a fresh AWS tenant state.

## Escalate When
- A change introduces metadata or behavior that may fail in a clean org or subscriber org.
- A shortcut would leave setup, packaging, or upgrade behavior understandable only to internal developers.

## Source Docs
- `SalesforcePackage/Salesforce_Object_Hierarchy.md`
- `SalesforcePackage/Salesforce_Publish_Flow_V1.md`
- `AWS/documentation/Starter_Immediate_List.md`
- `AWS/documentation/Starter_Launch_Remaining_Checklist.md`
