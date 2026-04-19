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
- When changing a Salesforce page design, bump the page version label shown in the UI (for example `Designer v9.4` in the top-left of the Designer page) so the rendered screen reflects the latest design revision.

## Escalate When
- A change introduces metadata or behavior that may fail in a clean org or subscriber org.
- A shortcut would leave setup, packaging, or upgrade behavior understandable only to internal developers.

## Source Docs
- `SalesforcePackage/Salesforce_Object_Hierarchy.md`
- `SalesforcePackage/Salesforce_Publish_Flow_V1.md`
- `AWS/documentation/Starter_Immediate_List.md`
- `AWS/documentation/Starter_Launch_Remaining_Checklist.md`
