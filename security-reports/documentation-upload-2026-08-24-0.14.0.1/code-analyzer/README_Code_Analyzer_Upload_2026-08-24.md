# TwinaForms Code Analyzer Upload Packet

Date: 2026-08-24

Package version: `0.14.0.1`

Subscriber Package Version ID: `04tgL000000OO9FQAW`

## Files

- `appexchange-security-focused.html`
- `appexchange-security-focused.json`
- `TwinaForms_Code_Analyzer_ISV_Response_2026-08-24.md`

## Source Documents Checked

This packet is for Salesforce Code Analyzer, not the official Salesforce Source Scanner / Checkmarx report.

The 2026-08-20 folder contains the current Source Scanner / Checkmarx evidence and explanation:

- `security-reports/source-scanner/isv-submission-2026-08-20-0.14.0.1/TwinaForms_Checkmarx_False_Positive_Explanation_2026-08-20.md`

For Code Analyzer, the latest current report files are under:

- `security-reports/code-analyzer/pre-release-current/appexchange-security-focused.html`
- `security-reports/code-analyzer/pre-release-current/appexchange-security-focused.json`

The older Code Analyzer response from 2026-06-05 references package version `0.10.0.5`, and the older `ProtectSensitiveData` note from 2026-04-29 covers only one subset of the current findings. The 2026-08-24 response in this folder refreshes those explanations for package version `0.14.0.1` and the current focused report.

## Summary

The staged focused AppExchange Code Analyzer report contains:

- Critical findings: `0`
- High findings: `0`
- Moderate findings: `28`

The remaining Moderate findings are keyword-based sensitive-data or hardcoded-credential matches for package terms such as `signature`, `token`, `key`, and `secret`.

Upload the focused report together with `TwinaForms_Code_Analyzer_ISV_Response_2026-08-24.md`. Do not use the old June response document for the 0.14 submission because it references package version `0.10.0.5`.
