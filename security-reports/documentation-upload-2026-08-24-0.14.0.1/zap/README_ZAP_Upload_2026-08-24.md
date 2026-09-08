# ZAP Upload Note

Date: 2026-08-24

Package version: `0.14.0.1`

Subscriber Package Version ID: `04tgL000000OO9FQAW`

## Files To Upload

Primary response notes:

- `responses/TwinaForms_ZAP_ISV_Response_2026-08-20.md`
- `responses/TwinaForms_ZAP_Scope_Note_2026-08-20.md`

Official reports:

- `official-reports/01-published-form-page.html`
- `official-reports/02-prefill-lambda.html`
- `official-reports/03-submit-lambda.html`
- `official-reports/04-salesforce-backend-lambda.html`
- `official-reports/05-submission-logs-lambda.html`
- `official-reports/06-admin-api-cognito.html`
- `official-reports/07-portable-snapshots-import-export.html`

If uploading HTML reports, include the sibling generated asset folders under `official-reports` so CSS/images resolve correctly.

## Review Position

The August 20, 2026 ZAP packet covers the current `0.14.0.1` runtime scope. It includes the new import/export portable snapshot routes:

- `POST /portable-snapshots/latest`
- `GET /portable-snapshots`
- `GET /portable-snapshots/{sourceOrgId}/{globalFormKey}`

The ZAP plans were passive requestor evidence scans. Protected backend, submission-log, admin API, and portable snapshot routes were intentionally scanned without bearer/JWT credentials to demonstrate unauthenticated rejection without exposing tenant secrets.

## Result Summary

- All 7 ZAP plans completed successfully.
- No High-risk alert types were reported.
- Protected import/export routes returned expected `401 Unauthorized` responses without bearer credentials.
- Remaining ZAP findings are documented as expected public-form behavior, AWS-managed endpoint header limitations, or accepted hardening items.

No endpoint code change is currently recommended based on this ZAP packet. The response and scope notes should be uploaded with the reports so the reviewer sees the intended authentication model and the new import/export coverage.
