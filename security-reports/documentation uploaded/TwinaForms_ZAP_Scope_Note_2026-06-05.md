# TwinaForms ZAP Scope Note

Date: 2026-06-05

These OWASP ZAP reports are passive requestor scans for ISV evidence. Active attack scans were also run internally against the same endpoint set and produced no High-risk, injection, or XSS findings.

## Scope

The scan scope covers the current TwinaForms public/runtime surfaces used by the released managed package `0.10.0.5`:

- published public form page on `forms.twinaforms.com`
- public prefill Lambda Function URL
- public submit Lambda Function URL
- Salesforce-to-AWS backend Lambda Function URL
- submission logs Lambda Function URL
- TwinaForms Admin API Lambda Function URL

The protected backend, submission-log, and admin API routes were intentionally scanned without tenant bearer secrets or Cognito JWTs. The purpose is to demonstrate unauthenticated rejection without exposing credentials in scanner reports.

## Scan Type

The ZAP Automation Framework `requestor` job was used to send known safe requests to each target. The reports were generated with the `risk-confidence-html` template.

No active attack scan was run. No tenant bearer secret, OAuth refresh token, Cognito token, Salesforce session id, or real customer credential is included in the plans or reports.

## Evidence Locations

- Automation plans: retained in the dated project evidence folder.
- Official reports: attach reports 01-06 with the submission packet.
- Response notes: included in this documentation upload packet.

## Reviewer Disposition

The reports are intended as DAST support evidence for the ISV security review packet. Findings are triaged in `TwinaForms_ZAP_ISV_Response_2026-06-05.md`.
