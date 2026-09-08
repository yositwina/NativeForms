# TwinaForms ISV Security Review Packet

Date: 2026-06-05

Scope: released TwinaForms managed package `0.10.0.5` and AWS runtime endpoints used for ISV testing.

## Salesforce Code Analyzer

Reports:

- `security-reports/code-analyzer/isv-submission-2026-06-05/appexchange-security-focused.html`
- `security-reports/code-analyzer/isv-submission-2026-06-05/appexchange-security-focused.json`
- `security-reports/code-analyzer/isv-submission-2026-06-05/appexchange-security.html`
- `security-reports/code-analyzer/isv-submission-2026-06-05/appexchange-security.json`

Response:

- `security-reports/code-analyzer/isv-submission-2026-06-05/TwinaForms_Code_Analyzer_ISV_Response_2026-06-05.md`

Result summary:

- Focused AppExchange scan: 28 moderate findings.
- No critical or high findings in the focused AppExchange scan.
- Findings are documented as false positives or accepted public values related to `signature`, `token`, and `key` terminology.
- Broad analyzer scan: 1,646 engineering findings across high, moderate, low, and informational severities. This broader report is retained as engineering backlog/evidence and is separate from the focused AppExchange security response.

## OWASP ZAP

Reports:

- Attached report 01: published form page.
- Attached report 02: prefill Lambda.
- Attached report 03: submit Lambda.
- Attached report 04: Salesforce backend Lambda.
- Attached report 05: submission logs Lambda.
- Attached report 06: admin API Cognito-protected Lambda.

Responses:

- `security-reports/zap/isv-submission-2026-06-05/responses/TwinaForms_ZAP_ISV_Response_2026-06-05.md`
- `security-reports/zap/isv-submission-2026-06-05/responses/TwinaForms_ZAP_Scope_Note_2026-06-05.md`

Result summary:

- All six ZAP automation plans succeeded.
- The attached reports are passive requestor evidence scans. Active attack scans were also run internally against the same endpoint set and produced no High-risk, injection, or XSS findings.
- Protected backend, submission-log, and admin API routes reject unauthenticated requests.
- Public form endpoints are documented with expected public-form CORS/header findings, CSP/browser-side hardening context, and server-side authorization controls.
- The prior `X-Content-Type-Options Header Missing` endpoint finding remains absent in the refreshed reports.

## Reviewer Notes

Items to review before ISV submission:

- Confirm whether accepted header hardening items should remain documented or be fixed before final submission.
- Confirm whether external browser resources on published forms should receive SRI hardening before launch.
- Confirm whether the broad Recommended Code Analyzer findings should be treated as engineering backlog separately from the focused AppExchange security response.
