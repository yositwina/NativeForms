# NativeForms Architecture

## Purpose
Map the real NativeForms system so Codex starts from project boundaries, not generic assumptions.

## Use When
Use for cross-system design, Home/admin/product changes, publish-flow work, or any change touching both Salesforce and AWS.

## NativeForms Rules
- For Yosi-led product/debug sessions, do not change or deploy code without explicit permission for that specific fix. First analyze, explain the likely cause and options, then wait for approval before implementation. Small documentation or operating-rule updates are allowed when explicitly requested.
- Salesforce is the design source of truth for forms, versions, elements, and actions.
- Salesforce also owns the admin organization model for authored assets, with hierarchy: `Project -> Form -> Version`.
- Designer recovery keeps published data immutable: Restore From Published creates a new draft version on the same form from the selected published version; it does not overwrite the damaged draft.
- Linked sandbox/production forms preserve the same `NF_Key__c` form number across orgs, but Salesforce orgs stay separate and published URLs stay environment-specific through the AWS tenant/company slug. Move form definitions by portable JSON/snapshot into a new target draft version; never move `Form_Id__c`, publish tokens, source published URLs, publication records, or source Salesforce record IDs.
- Linked forms Phase 2 focuses on theme/image/asset portability, richer compatibility preview, and clear storage/limit errors. Themes are reusable Salesforce `NF_Theme__c` records linked from `NF_Form__c.Theme__c`; `NF_Form_Version__c.Theme_JSON__c` is only a compatibility/fallback snapshot. Theme header, background, footer images, and canvas image elements use Salesforce Files/`ContentVersion` through the existing package upload flow. Do not add export integrity hashes, signatures, or stronger form fingerprints in this phase unless the detailed design is explicitly reopened.
- Linked forms Phase 3 design uses AWS connected org groups as a snapshot broker: group membership in DynamoDB, latest Published portable JSON in private S3, searchable metadata in DynamoDB, and Salesforce import still creates Draft versions. AWS is not the design source of truth, and Phase 3 does not need connected-org refresh tokens unless a later feature requires AWS-to-Salesforce calls.
- Designer Undo V1 is intentionally small: keep up to 5 local element snapshots and restore the selected draft version's `NF_Form_Element__c` rows from the latest snapshot.
- Formula Fields V1 are Salesforce-authored and browser-evaluated only: Designer preview and published HTML runtime compute them, with no AWS submit-time recheck in V1. Records List formula targets are same-row only via `{row.fieldKey}` plus optional top-level `{fieldKey}` references.
- Button Element V1 is Salesforce-authored and browser-executed portal navigation: Salesforce resolves selected published-form targets during publish, while generated HTML resolves allowed field/row values and optionally invokes the normal submit flow before navigation. It adds no AWS endpoint or submitted field payload.
- Blank formula expressions are allowed in V1 and behave as empty derived values until the admin enters an expression.
- AWS is the execution authority for runtime registration, prefill, submit, plan/tenant data, and admin operations.
- Publish flow is: validate in Salesforce, compile artifacts, register in AWS, publish HTML, then update Salesforce publication state.
- Tenant identity is `orgId`; tenant trust and public form trust must stay separate.
- Starter is the first product-quality baseline; Pro extends the same platform rather than replacing it.

## Escalate When
- A change blurs source-of-truth boundaries between Salesforce records and AWS compiled/runtime data.
- A change alters publish flow, plan model, tenant isolation, or runtime trust boundaries.

## Source Docs
- `SalesforcePackage/Salesforce_Publish_Flow_V1.md`
- `SalesforcePackage/Salesforce_Object_Hierarchy.md`
- `AWS/documentation/Multi tenant and security approach.md`
- `AWS/documentation/NativeForms_Product_Plan_Starter_Pro.md`
