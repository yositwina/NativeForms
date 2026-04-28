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
- Permission-set management location rule: manage `TwinaForms User` / `TwinaForms Admin` assignment from the `TwinaForms Connect` page, not `TwinaForms Home`, so setup/access troubleshooting stays in one place.
- Namespace packaging rule: do not add `twinaforms__` prefixes to compile-time Apex object/field references. Do audit string-based metadata names instead, especially Named Credentials, External Credential principal access, Permission Set lookup, app/tab visibility, and setup docs. Use `AWS/documentation/Technical and specs/Salesforce_Packaging_Namespace_Audit_V1.md` before creating a package version.
- Managed LWC-to-Apex boundary rule: for package-visible Lightning/Aura methods called from LWC, avoid custom Apex DTO parameters such as inner classes (`MyInput inputValue`) for save/update/register actions. Prefer primitives or `String inputJson`, then deserialize inside Apex. In managed packages, namespace/type binding for custom DTO params can fail before Apex execution, often showing only a Salesforce internal server error and no debug log.
- Named Credential rule: Apex callouts must resolve packaged Named Credential names through the existing namespace helper pattern, so unmanaged orgs use `NativeForms*` and subscriber orgs use `twinaforms__NativeForms*`.
- Permission-set lookup rule: product code should find packaged permission sets by customer-facing label (`TwinaForms User`, `TwinaForms Admin`) rather than developer/API name where practical.
- External Credential packaging rule: do not rely on `externalCredentialPrincipalAccesses` inside packaged permission-set metadata for install success. Keep the subscriber setup flow/documentation explicit about the manual External Credential Principal Access step.
- External Client App packaging rule: include the package-safe External Client App header and OAuth settings in the managed package so subscribers do not create the app manually. Do not package global OAuth settings, consumer credential material, or configurable policy metadata. Installed External Client Apps hide OAuth settings from subscribers, so TwinaForms Connect must not ask customers to copy a Consumer Key or Consumer Secret; AWS uses the TwinaForms-owned source-org client credentials centrally.
- External Client App source-org rule: the packaged app must be owned by a persistent Dev Hub/source org and include Salesforce's retrieved `orgScopedExternalApp` and `oauthLink` values. If package creation says the ECA was created in an ephemeral org, create/deploy the ECA in the Dev Hub/source org, enable `enablePackageEcaOauthFromDevOrg`, retrieve the header/OAuth settings, and retry. Policy metadata is not packageable in this flow.
- External Client App refresh-token rule: for the associated packaged ECA model, set the source-org refresh token policy to valid until revoked. AWS refreshes access tokens centrally and stores/revokes refresh tokens per tenant; do not use a fixed 365-day expiry unless the product intentionally wants annual reconnects.
- Email template packaging rule: do not ship package email templates from `unfiled$public`. Put them in a dedicated package-owned email folder so installs do not collide with subscriber unfiled templates that share the same name.
- When changing a Salesforce page design, bump the page version label shown in the UI (for example `Designer v9.4` in the top-left of the Designer page) so the rendered screen reflects the latest design revision.
- In `nativeFormsDesigner`, new text-like property controls must use local draft state while typing and commit only on `blur` or explicit finish. Do not wire `oninput`, mid-typing `applyEditorDraft()`, or save-triggered rerenders for plain text inputs or plain textareas unless the user explicitly wants live preview.
- For repeated property editors such as conditional rows, treat blank/new rows as draft UI state first and sanitize only when persisting. Do not round-trip blank draft rows through saved config too early, or `Add Condition` / selection flows will look broken.
- When a Designer control feels jumpy, misses letters, loses first clicks, or makes buttons seem dead, assume the root cause is usually blur/save/rerender interference before trying layout-only fixes.
- Branding rule: do not introduce new user-facing `NativeForms` text. Use `TwinaForms` in emails, labels, help text, and UI copy unless the user explicitly asks otherwise or the string is a fixed technical identifier.
- Multilingual rule: do not introduce fixed English customer-facing text inside form canvas previews or published forms unless it is an error/debug message. If helper/action text is needed, make it configurable in Salesforce properties/settings or omit it. Preserve label-placement flexibility instead of compensating with hard-coded English guidance.
- Secret-code rule: avoid fixed English-only preview/runtime copy such as `Locked Until Verified`, `Secret Code Verification`, or `Code step appears after the user presses Enter`. Public-form button labels should be configurable when they are part of the customer experience.
- Current managed 2GP package id for this repo is `0HogL0000002CUvSAM` (`TwinaForms`). Keep `sfdx-project.json` and packaging notes aligned if Salesforce ever returns a replacement package id.
- Current latest beta install link is `https://login.salesforce.com/packaging/installPackage.apexp?p0=04tgL000000ENMXQA4`. Update this skill and `AWS/documentation/Technical and specs/Salesforce_Packaging_Namespace_Audit_V1.md` every time a new package version is created.

## Escalate When
- A change introduces metadata or behavior that may fail in a clean org or subscriber org.
- A shortcut would leave setup, packaging, or upgrade behavior understandable only to internal developers.

## Source Docs
- `SalesforcePackage/Salesforce_Object_Hierarchy.md`
- `SalesforcePackage/Salesforce_Publish_Flow_V1.md`
- `AWS/documentation/Starter_Immediate_List.md`
- `AWS/documentation/Starter_Launch_Remaining_Checklist.md`
