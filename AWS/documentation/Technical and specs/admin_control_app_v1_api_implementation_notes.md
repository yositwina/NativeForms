# NativeForms Admin Control App - API Implementation Notes

## Current scaffold

Initial Lambda scaffold created:

- `AWS/NativeFormsAdminApi.mjs`

Runtime/publish lifecycle routes are implemented in:

- `AWS/NativeFormsBackend.mjs`

## Implemented routes in the scaffold

- `GET /admin/overview`
- `GET /admin/plans`
- `GET /admin/tenants`
- `GET /admin/tenants/{orgId}`

## Implemented NativeFormsBackend runtime/admin routes

### `POST /forms/register`

Registers or updates the published form runtime security record in `NativeFormsFormSecurity`.

Used by Salesforce publish after the HTML has been uploaded.

Important fields:

- `orgId`
- `formId`
- `publishedVersionId`
- `publishToken`
- `status`
- `securityMode`
- `generatedHtmlRef`
- `publicUrl`
- `prefillPolicy`
- `submitPolicy`
- `prefillDefinition`
- `submitDefinition`

### `POST /forms/unpublish`

Disables public runtime access for a form before Salesforce deletes the Designer form definition.

Request body:

```json
{
  "orgId": "00Dxxxxxxxxxxxx",
  "formId": "nf-00Dxxxxxxxxxxxx-a0123456789ABC"
}
```

Authentication:

- Uses the same tenant bearer-token auth as publish/register.
- The form security record must belong to the same normalized `orgId`.

Behavior:

- If the `NativeFormsFormSecurity` record exists, set `status` to `unpublished`.
- Set `unpublishedAt` if it was not already set.
- Update `updatedAt`.
- If `generatedHtmlRef` can be resolved to a key in `nativeformspublish`, replace that hosted form HTML with a small “form no longer available” page.
- If the form security record is already missing, return success with `found: false`; the Salesforce delete flow can continue because no live AWS runtime was found.
- Do not delete submission logs. Logs remain governed by plan retention.

Salesforce delete rule:

- Salesforce should call `/forms/unpublish` before deleting a published form.
- If this call fails for a published form, Salesforce should block the delete so a live public form is not orphaned.

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

## Hosting target

The live `admin.twinaforms.com` CloudFront distribution currently points to:

- bucket: `nativeformspublish`
- origin path: `/admin-console/dev`

So admin-console static deploys must publish to:

- `s3://nativeformspublish/admin-console/dev/`

Updating a local file under `AWS/admin-console/` is not enough by itself. The matching file must be uploaded to that exact S3 prefix, and HTML changes may still require a CloudFront invalidation for `/index.html`.
