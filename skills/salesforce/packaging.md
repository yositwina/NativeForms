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
- Default Salesforce deployment alias for this repo is `NativeFormsDev` unless the user explicitly asks for a different org.
- Permission-set split rule: keep ordinary customer access and support/debug admin access separate. `TwinaForms User` should be the counted customer-facing seat, while `TwinaForms Admin` should stay a separate support/debug permission set and app-access path.
- Permission-set management location rule: manage `TwinaForms User` / `TwinaForms Admin` assignment from the `TwinaForms Connect` page, not `TwinaForms Home`, so setup/access troubleshooting stays in one place.
- When changing a Salesforce page design, bump the page version label shown in the UI (for example `Designer v9.4` in the top-left of the Designer page) so the rendered screen reflects the latest design revision.
- In `nativeFormsDesigner`, new text-like property controls must use local draft state while typing and commit only on `blur` or explicit finish. Do not wire `oninput`, mid-typing `applyEditorDraft()`, or save-triggered rerenders for plain text inputs or plain textareas unless the user explicitly wants live preview.
- For repeated property editors such as conditional rows, treat blank/new rows as draft UI state first and sanitize only when persisting. Do not round-trip blank draft rows through saved config too early, or `Add Condition` / selection flows will look broken.
- When a Designer control feels jumpy, misses letters, loses first clicks, or makes buttons seem dead, assume the root cause is usually blur/save/rerender interference before trying layout-only fixes.
- Branding rule: do not introduce new user-facing `NativeForms` text. Use `TwinaForms` in emails, labels, help text, and UI copy unless the user explicitly asks otherwise or the string is a fixed technical identifier.
- Multilingual rule: do not introduce fixed English customer-facing text inside form canvas previews or published forms unless it is an error/debug message. If helper/action text is needed, make it configurable in Salesforce properties/settings or omit it. Preserve label-placement flexibility instead of compensating with hard-coded English guidance.
- Secret-code rule: avoid fixed English-only preview/runtime copy such as `Locked Until Verified`, `Secret Code Verification`, or `Code step appears after the user presses Enter`. Public-form button labels should be configurable when they are part of the customer experience.

## Escalate When
- A change introduces metadata or behavior that may fail in a clean org or subscriber org.
- A shortcut would leave setup, packaging, or upgrade behavior understandable only to internal developers.

## Source Docs
- `SalesforcePackage/Salesforce_Object_Hierarchy.md`
- `SalesforcePackage/Salesforce_Publish_Flow_V1.md`
- `AWS/documentation/Starter_Immediate_List.md`
- `AWS/documentation/Starter_Launch_Remaining_Checklist.md`
