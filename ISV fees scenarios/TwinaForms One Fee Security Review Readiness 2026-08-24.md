# TwinaForms One-Fee Security Review Readiness

Date: 2026-08-24

## Goal

Minimize the chance of paying more than one AppExchange Security Review fee for the first paid/freemium TwinaForms submission.

## Fee Rule Interpreted From The AppExchange Fee FAQ

For paid/freemium AppExchange solutions, the initial security review is charged per attempt. If the review fails and TwinaForms must change package code or external endpoint code and resubmit, the FAQ indicates another paid attempt can apply.

The practical exception is a false-positive-only response. If Salesforce review feedback requires no code changes and only false-positive justification, the FAQ indicates the follow-up can be submitted without another paid fee.

Therefore, the safest strategy is to submit only when the package, external endpoints, scanner evidence, false-positive explanations, and reviewer test org are aligned to the same released version.

## Current Package To Submit

| Item | Value |
| --- | --- |
| AppExchange / Subscriber Package ID | `033gL0000009ZbFQAU` |
| 2GP Package ID | `0HogL0000002CUvSAM` |
| Subscriber Package Version ID | `04tgL000000OO9FQAW` |
| Version | `0.14.0.1` |
| Status | Released managed package |
| Ancestor | `0.13.0.1` |
| Code coverage | `83%` |
| Metadata removed | No |

## Latest Security Evidence

### Force.com Source Scanner / Checkmarx

Evidence folder:

- `security-reports/source-scanner/isv-submission-2026-08-20-0.14.0.1`

Latest report:

- Scan ID: `a0OKX000001JPwB2AW`
- Version scanned: `0.14.0.1`
- Subscriber package version id: `04tgL000000OO9FQAW`
- Security issues: `18`
- Quality issues: `0`
- Critical categories: `0`
- JavaScript/XSS categories: `0`
- SOQL/SOSL injection: `0`
- XSRF: `0`

Remaining findings are documented as package-controlled cryptographic storage / scanner false positives:

- `Apex CRUD Create Violation`: 7
- `Apex CRUD Update Violation`: 5
- `Apex SOQL SOSL User Mode Missing`: 5
- `Sharing`: 1

Current decision: acceptable for submission only if the false-positive explanation is uploaded with the scanner report.

### OWASP ZAP

Evidence folder:

- `security-reports/zap/isv-submission-2026-08-20-0.14.0.1`

Latest reports:

- 7 passive requestor reports generated successfully.
- No High-risk alert types.
- New import/export portable snapshot routes are included:
  - `POST /portable-snapshots/latest`
  - `GET /portable-snapshots`
  - `GET /portable-snapshots/{sourceOrgId}/{globalFormKey}`
- Protected routes reject unauthenticated requests with `401 Unauthorized`.

Current decision: acceptable for submission only if reports 01-07 and the August ZAP response/scope notes are uploaded.

### Salesforce Code Analyzer

Evidence folder:

- `security-reports/code-analyzer/pre-release-current`

Focused AppExchange report:

- `appexchange-security-focused.json`
- `appexchange-security-focused.html`

Current focused AppExchange findings:

- 28 severity-3 findings.
- 14 `AvoidHardcodedCredentialsInVarAssign`
- 10 `ProtectSensitiveData`
- 3 `AvoidHardcodedCredentialsInVarDecls`
- 1 `AvoidHardcodedCredentialsInFieldDecls`

Current decision: likely acceptable as false positives, but the explanation document should be refreshed for version `0.14.0.1` before submission. Do not rely only on the older April/June note.

## One-Fee Risk Assessment

Current risk level: medium until the submission documentation packet is refreshed.

Reasons:

- The latest scanner evidence is aligned to `0.14.0.1`.
- The latest package version is released and passed code coverage.
- The current Source Scanner report does not recommend code fixes.
- The latest ZAP packet includes the new import/export feature and has no High-risk findings.
- However, several existing upload documents still reference package `0.10.0.5`, version id `04tgL000000GburQAC`, June reports, and reports 01-06 only.
- Agentforce action support exists in the package. Salesforce has Agentforce security review questionnaire guidance, so the submission should include an Agentforce-specific note/questionnaire if the wizard asks for it.

## Required Before Paying / Submitting

1. Submit package version `04tgL000000OO9FQAW` (`0.14.0.1`), not an older package version.
2. Upload the August Source Scanner report and August false-positive explanation.
3. Upload the August ZAP reports 01-07 and August ZAP response/scope notes.
4. Refresh the product description, data-flow/auth/encryption, sample API callouts, test environment, and packet index documents to version `0.14.0.1`.
5. Add portable snapshot import/export to product, data-flow, and API callout documents.
6. Refresh the Code Analyzer false-positive explanation for the 28 current focused findings.
7. Confirm reviewer test org has `0.14.0.1` installed and connected.
8. Confirm MFA/test-login requirements are reviewer-friendly.
9. Include an Agentforce action note/questionnaire if the wizard presents the Agentforce upload section.
10. Do not submit stale June documents that conflict with the package version.

## Bottom Line

TwinaForms is not ready to submit for the one paid attempt until the documentation packet is refreshed. The scanner evidence itself is in good shape, but stale or conflicting documents can create avoidable review friction and may increase the chance of a paid resubmission if Salesforce treats the submission as incomplete or mismatched.
