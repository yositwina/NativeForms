# TwinaForms Active Attack Scans — NOT FOR ISV SUBMISSION

Date: 2026-06-05
Package context: TwinaForms managed package `0.10.0.5`
Tool: OWASP ZAP 2.17.0 Automation Framework — `activeScan` job (real attack payloads)

## Why this folder exists

The official ISV submission packet (`security-reports/zap/isv-submission-2026-06-05`)
uses **passive** `requestor` scans. The Salesforce AppExchange security review runs its
own **active** DAST against the endpoints. These scans were run internally to pre-empt
what that active review will find. **Do not submit this folder** as ISV evidence — it is
internal hardening verification only.

## Safety boundaries used

Active scanning fuzzes parameters with live attack payloads. To avoid damaging the live
tenant org (`00Dg5000008sWZN`):

- **Prefill Lambda** — seeded with a **valid** publish token. Prefill is read-only
  (queries Salesforce), so this safely exercises the real query path. This is the
  primary SOQL-injection test surface.
- **Submit Lambda** — seeded with **rejection cases only** (invalid token, wrong form id).
  The scanner fuzzes the pre-auth parsing/auth surface **without creating any Salesforce
  records**. The authenticated write path is intentionally NOT fuzzed here. To test the
  write path, re-run plan `03` against a dedicated **scratch/test org** with a valid token.
- **Backend / submission-logs / admin** protected routes — seeded **without** bearer /
  Cognito tokens. The scanner fuzzes the pre-auth surface (stays at the 401 layer).

## Results — summary

**No High-risk findings. No injection (SQLi/SOQLi), XSS, path traversal, or command
injection fired on any endpoint.** The active scan surfaced nothing beyond the same
header/CORS hardening items already documented and accepted in the passive ISV packet.

| # | Target | Active-scan findings | Risk |
|---|--------|----------------------|------|
| 01 | Published form page (static S3/CloudFront) | Content Security Policy (CSP) Header Not Set | Medium |
| 02 | Prefill Lambda (valid token, read path) | Cross-Domain Misconfiguration (CORS) | Medium |
| 03 | Submit Lambda (rejection seeds) | Cross-Domain Misconfiguration (CORS) | Medium |
| 04 | Salesforce backend Lambda | Cross-Domain Misconfiguration (CORS) | Medium |
| 05 | Submission-logs Lambda | Cross-Domain Misconfiguration (CORS) | Medium |
| 06 | Admin API (Cognito) | Strict-Transport-Security Header Not Set | Low |

All six findings already appear in the passive ISV ZAP response
(`TwinaForms_ZAP_ISV_Response_2026-06-05.md`) and are dispositioned there as accepted
hardening items / expected public-form runtime behavior. The active scan adds confidence
that these are the *only* DAST findings, not just the passive ones.

### What this confirms

- The valid-token prefill fuzzing produced **no SOQL injection** — the server-side
  form policy (object/field/command allowlists) holds under active attack input.
- Protected backend, submission-logs, and admin routes stayed at unauthenticated
  rejection under attack payloads — **no auth bypass**.
- The static published form reflected no XSS; the `X-XSS-Protection` and
  `X-Content-Type-Options: nosniff` headers are present in evidence.

### Known gap (deliberate)

The authenticated **submit write path** was not actively fuzzed (to protect live data).
Salesforce's own review may exercise it against their test org. Recommended follow-up:
run `plans/03-submit-lambda-active.yaml` with a valid token against a scratch org before
final submission if you want write-path injection coverage in hand.

## How to reproduce

```powershell
Set-Location "C:\Program Files\ZAP\Zed Attack Proxy"
.\zap.bat -cmd -autorun "C:\Users\Yosi\NativeFormsAWS\security-reports\AttackTestsNotForSubmission\plans\01-published-form-page-active.yaml"
# ...repeat for plans 02-06
```

## Contents

- `plans/` — six ZAP active-scan automation plans (one per endpoint)
- `reports/` — six generated HTML reports (risk-confidence template)
