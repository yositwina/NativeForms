# NativeForms Architecture

## Purpose
Map the real NativeForms system so Codex starts from project boundaries, not generic assumptions.

## Use When
Use for cross-system design, Home/admin/product changes, publish-flow work, or any change touching both Salesforce and AWS.

## NativeForms Rules
- Salesforce is the design source of truth for forms, versions, elements, and actions.
- Salesforce also owns the admin organization model for authored assets, with hierarchy: `Project -> Form -> Version`.
- Formula Fields V1 are Salesforce-authored and browser-evaluated only: Designer preview and published HTML runtime compute them, with no AWS submit-time recheck in V1.
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
