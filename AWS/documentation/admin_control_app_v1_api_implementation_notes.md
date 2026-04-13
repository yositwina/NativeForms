# NativeForms Admin Control App - API Implementation Notes

## Current scaffold

Initial Lambda scaffold created:

- `AWS/NativeFormsAdminApi.mjs`

## Implemented routes in the scaffold

- `GET /admin/overview`
- `GET /admin/plans`
- `GET /admin/tenants`
- `GET /admin/tenants/{orgId}`

## Current behavior

- reads tenant data from `NativeFormsTenants`
- reads plan data from `NativeFormsPlans`
- falls back to built-in default plan definitions if `NativeFormsPlans` is empty or not available yet
- returns responses in the V1 API contract shape

## Authentication behavior

- controlled by environment variable `REQUIRE_ADMIN_AUTH`
- if `true`, requests must send `Authorization: Bearer <token>`
- if `false`, the scaffold allows local/S3 prototype access during early development

## Important implementation note

This is a V1 scaffold, not the full admin backend yet.

Not implemented yet:

- audit endpoints
- support endpoints
- plan-changing actions
- trial extension actions
- suspend / reactivate actions
- resend setup / regenerate secret / refresh health actions
- Cognito token verification logic

## Suggested next step

Wire `AWS/admin-console/app.js` to:

- `GET /admin/tenants`
- `GET /admin/tenants/{orgId}`
- `GET /admin/plans`

That will turn the S3 static shell into a real read-only admin console first.
