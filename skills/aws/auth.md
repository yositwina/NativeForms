# AWS Auth

## Purpose
Keep Codex aligned with the NativeForms tenant trust model, public runtime trust model, and admin/bootstrap separation.

## Use When
Use for Lambda auth, tenant registration, bearer-secret flows, connected app or callback decisions, runtime security, or admin API protection changes.

## NativeForms Rules
- Keep tenant trust separate from public form trust.
- Salesforce admin/server calls use the tenant bearer secret; public HTML never uses that secret.
- Public runtime uses `formId` plus per-form `publishToken`, then resolves tenant ownership indirectly through the stored form record.
- Store tenant-specific Salesforce connection data per org, not as one shared backend credential.
- Use the stored tenant `loginBaseUrl` for org-specific auth/bootstrap behavior rather than assuming one global Salesforce login host.
- Admin auth is still a separate concern from customer runtime auth; Cognito belongs to the admin app path, not the public form runtime path.

## Escalate When
- A change mixes tenant admin trust with public runtime trust.
- A proposal introduces shared cross-tenant secrets, browser-visible admin credentials, or a single global Salesforce connection for all orgs.

## Source Docs
- `AWS/documentation/Multi tenant and security approach.md`
- `AWS/documentation/Security Protocols.md`
- `SalesforcePackage/Salesforce_Connected_App_Strategy.md`
- `AWS/documentation/admin_control_app_v1_focused_spec.md`
