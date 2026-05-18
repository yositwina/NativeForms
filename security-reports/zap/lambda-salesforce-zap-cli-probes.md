# ZAP CLI and HTTP Probe Report

Date: 2026-04-29T10:15:14.9540712+03:00

Scope: Salesforce-related TwinaForms AWS Lambda Function URLs. This was a safe CLI pass: no active destructive scan and no disconnect against a real tenant.

## ZAP CLI Result

ZAP CLI zapit was run against GET /public/plans on the backend Lambda URL.

Alerts observed:
- Medium: Cross-Domain Misconfiguration, Access-Control-Allow-Origin: *
- Low: Strict-Transport-Security Header Not Set
- Low: X-Content-Type-Options Header Missing
- Informational: Re-examine Cache-control Directives

## Route Probes

### Backend public plans

- Method: GET
- URL: https://f4apx2tkemgn5i2vagzhboeyjm0nnnjh.lambda-url.eu-north-1.on.aws/public/plans
- Status: 200
- Content-Type: application/json
- Access-Control-Allow-Origin: *

Response preview:
```text
{"success":true,"storageMode":"dynamodb","items":[{"planCode":"free","label":"Free","description":"Permanent low-volume entry plan.","durationType":"forever","durationDays":null,"limits":{"maxSfUsers":1,"maxForms":1,"maxSubmissionsPerMonth":100,"submissionLogRetentionDays":30},"limitSummary":[{"key":"maxForms","label":"Forms","value":"1"},{"key":"maxSubmissionsPerMonth","label":"Monthly submissions","value":"100"},{"key":"maxSfUsers","label":"Active users","value":"1"}],"features":[]},{"planCode":"starter","label":"Starter","description":"Paid production plan without Pro-only features.","durationType":"forever","durationDays":null,"limits":{"maxSfUsers":1,"maxForms":5,"maxSubmissionsPerMonth...
```

### Backend tenant status deleted test org

- Method: GET
- URL: https://f4apx2tkemgn5i2vagzhboeyjm0nnnjh.lambda-url.eu-north-1.on.aws/tenant/status?orgId=00Dg5000008sWZN
- Status: 200
- Content-Type: application/json
- Access-Control-Allow-Origin: *

Response preview:
```text
{"success":true,"registered":false,"connected":false,"setupState":"not_registered","connectUrl":null,"tenant":null,"hasClientCredentials":true,"oauthClientConfigured":true,"hasRefreshToken":true,"hasInstanceUrl":true}
```

### Backend auth health without bearer

- Method: GET
- URL: https://f4apx2tkemgn5i2vagzhboeyjm0nnnjh.lambda-url.eu-north-1.on.aws/tenant/auth-health?orgId=00Dg5000008sWZN
- Status: 401
- Content-Type: application/json
- Access-Control-Allow-Origin: *

Response preview:
```text
{"success":false,"authenticated":false,"error":"Missing Authorization bearer token"}
```

### Backend entitlements without bearer

- Method: GET
- URL: https://f4apx2tkemgn5i2vagzhboeyjm0nnnjh.lambda-url.eu-north-1.on.aws/tenant/entitlements?orgId=00Dg5000008sWZN
- Status: 401
- Content-Type: application/json
- Access-Control-Allow-Origin: *

Response preview:
```text
{"success":false,"error":"Missing Authorization bearer token"}
```

### Backend connect deleted test org

- Method: GET
- URL: https://f4apx2tkemgn5i2vagzhboeyjm0nnnjh.lambda-url.eu-north-1.on.aws/connect?orgId=00Dg5000008sWZN
- Status: 502
- Content-Type: application/json
- Access-Control-Allow-Origin: 

Response preview:
```text
Internal Server Error
```

### Backend OAuth callback invalid state/code

- Method: GET
- URL: https://f4apx2tkemgn5i2vagzhboeyjm0nnnjh.lambda-url.eu-north-1.on.aws/oauth/callback?state=invalid&code=test
- Status: 200
- Content-Type: text/html
- Access-Control-Allow-Origin: 

Response preview:
```text
<html> <body style="font-family: Arial, sans-serif; padding: 20px;"> <h2>OAuth Callback Error</h2> <p>Missing or invalid orgId/state.</p> </body> </html>
```

### Backend forms register without bearer

- Method: POST
- URL: https://f4apx2tkemgn5i2vagzhboeyjm0nnnjh.lambda-url.eu-north-1.on.aws/forms/register
- Status: 400
- Content-Type: application/json
- Access-Control-Allow-Origin: *

Response preview:
```text
{"success":false,"error":"Expected property name or '}' in JSON at position 1"}
```

### Backend tenant disconnect fake org without bearer

- Method: POST
- URL: https://f4apx2tkemgn5i2vagzhboeyjm0nnnjh.lambda-url.eu-north-1.on.aws/tenant/disconnect
- Status: 400
- Content-Type: application/json
- Access-Control-Allow-Origin: *

Response preview:
```text
{"success":false,"error":"Expected property name or '}' in JSON at position 1"}
```

### Prefill GET no payload

- Method: GET
- URL: https://a2guxusajjhwzakf3tg6ispb640pgsno.lambda-url.eu-north-1.on.aws
- Status: 200
- Content-Type: application/json
- Access-Control-Allow-Origin: *

Response preview:
```text
{"success":true,"message":"NativeForms prefill endpoint is alive"}
```

### Submit GET no payload

- Method: GET
- URL: https://hfkuwm6emqiaz2drmuip6zqn5m0agbyp.lambda-url.eu-north-1.on.aws
- Status: 200
- Content-Type: application/json
- Access-Control-Allow-Origin: *

Response preview:
```text
{"success":true,"message":"NativeForms endpoint is alive"}
```

### Submission logs status without bearer

- Method: GET
- URL: https://jafi5esjqnvip3gbdahj7d2a7m0eyhby.lambda-url.eu-north-1.on.aws/submission-log-config/status?orgId=00Dg5000008sWZN
- Status: 401
- Content-Type: application/json
- Access-Control-Allow-Origin: *

Response preview:
```text
{"success":false,"error":"Missing Authorization bearer token"}
```

### Submission logs list without bearer

- Method: GET
- URL: https://jafi5esjqnvip3gbdahj7d2a7m0eyhby.lambda-url.eu-north-1.on.aws/submission-logs?orgId=00Dg5000008sWZN
- Status: 401
- Content-Type: application/json
- Access-Control-Allow-Origin: *

Response preview:
```text
{"success":false,"error":"Missing Authorization bearer token"}
```

### Submission logs sync without bearer

- Method: POST
- URL: https://jafi5esjqnvip3gbdahj7d2a7m0eyhby.lambda-url.eu-north-1.on.aws/submission-log-config/sync
- Status: 500
- Content-Type: application/json
- Access-Control-Allow-Origin: *

Response preview:
```text
{"success":false,"error":"Expected property name or '}' in JSON at position 1"}
```

## Initial Notes

- Public /public/plans returned 200 and is intentionally public, but ZAP reported permissive CORS and missing security headers.
- Tenant-secret protected endpoints should return an authorization failure without bearer auth.
- POST /tenant/disconnect was tested only with a fake org id to avoid changing a real tenant. It returned tenant-not-found rather than authorization failure, which supports source-review concern that auth is not checked first.
## Follow-up Valid JSON POST Probes

### Backend forms register without bearer, complete valid body

- Method: POST
- URL: https://f4apx2tkemgn5i2vagzhboeyjm0nnnjh.lambda-url.eu-north-1.on.aws/forms/register
- Status: 401

Response preview:
```text
{"success":false,"error":"Missing Authorization bearer token"}
```

This confirms `/forms/register` rejects a complete valid request without bearer authentication. A partial request is validated before auth and may return validation messages first.

### Backend tenant disconnect without bearer, fake org

- Method: POST
- URL: https://f4apx2tkemgn5i2vagzhboeyjm0nnnjh.lambda-url.eu-north-1.on.aws/tenant/disconnect
- Status: 400

Response preview:
```text
{"success":false,"error":"Tenant not found"}
```

This route still reaches tenant lookup before bearer authentication. It was tested only with a fake org id to avoid changing a real tenant. Source review should treat this as a likely authorization-order bug.

### Submission logs sync without bearer, valid body

- Method: POST
- URL: https://jafi5esjqnvip3gbdahj7d2a7m0eyhby.lambda-url.eu-north-1.on.aws/submission-log-config/sync
- Status: 401

Response preview:
```text
{"success":false,"error":"Missing Authorization bearer token"}
```

This route correctly rejects without bearer authentication.

## After-Fix Verification

The two actionable findings were corrected and redeployed to `NativeFormsBackend` on 2026-04-29.

### Tenant status for deleted tenant

- Method: GET
- URL: https://f4apx2tkemgn5i2vagzhboeyjm0nnnjh.lambda-url.eu-north-1.on.aws/tenant/status?orgId=00Dg5000008sWZN
- Status: 200

Response preview:
```text
{"success":true,"registered":false,"connected":false,"setupState":"not_registered","connectUrl":null,"tenant":null,"hasClientCredentials":true,"oauthClientConfigured":true,"hasRefreshToken":false,"hasInstanceUrl":false}
```

The deleted/unregistered tenant no longer reports refresh-token or instance-url presence.

### Tenant disconnect without bearer

- Method: POST
- URL: https://f4apx2tkemgn5i2vagzhboeyjm0nnnjh.lambda-url.eu-north-1.on.aws/tenant/disconnect
- Status: 401

Response preview:
```text
{"success":false,"error":"Missing Authorization bearer token"}
```

The route now rejects before tenant lookup or mutation when the bearer secret is missing.

## Published Form Probe: `form1`

Tested on 2026-04-29:

```text
https://forms.twinaforms.com/twinaforms/form1?email=liam.carter@example.com
```

### Static published page

- Method: GET
- Status: 200
- Host: CloudFront/S3
- Response size: 101,896 bytes
- Runtime config exposed expected public values: `formId`, `versionId`, `publishToken`, prefill Lambda URL, submit Lambda URL, reCAPTCHA site key.
- reCAPTCHA is enabled for submit.
- Secret-code gate is disabled for this form.

ZAPit reported 11 alerts:

- Medium: Content Security Policy header not set.
- Medium: Missing anti-clickjacking header.
- Medium: Subresource Integrity attribute missing for Google reCAPTCHA script.
- Low: Cross-domain JavaScript source inclusion for Google reCAPTCHA script.
- Low: `Server` header exposes `AmazonS3`.
- Low: Strict-Transport-Security header not set.
- Low: `X-Content-Type-Options` header missing.
- Informational: email address appears in the URL query string.
- Informational: suspicious comments.
- Informational: modern web application.
- Informational: cache-control directives.

### Prefill endpoint

- Method: POST
- URL: published prefill Lambda URL from the page config
- Body: valid `publishToken`, form id, and `email=liam.carter@example.com`
- Status: 200

Response included prefilled Contact data and Salesforce metadata for the matching Contact:

```text
success=true
firstName=Liam
lastName=Carter
email=liam.carter@example.com
phone=415-555-0102
aliases.PrefilContact.Id=<Salesforce Contact Id>
aliases.PrefilContact.attributes.url=/services/data/v60.0/sobjects/Contact/<Contact Id>
results[0].objectApiName=Contact
results[0].found=true
```

This is functionally correct for the demo form, but it is a privacy/security design point for real customer data: a public form with prefill enabled and no secret-code gate can disclose configured prefill fields to anyone who knows or guesses the lookup parameter.

### Prefill unknown email

- Method: POST
- Body: valid `publishToken`, form id, and an unknown email
- Status: 200

Response preview:

```text
success=true
input={}
aliases.PrefilContact=null
results[0].found=false
```

The response does not return Contact data for unknown email values, but it does disclose whether a configured lookup found a record.

### Prefill invalid token

- Method: POST
- Body: invalid `publishToken`, valid form id and known email
- Status: 401

The invalid token was rejected.

### Submit without CAPTCHA

- Method: POST
- URL: published submit Lambda URL from the page config
- Body: valid `publishToken`, form id, basic input, no CAPTCHA token
- Status: 400

The request was rejected before creating a submission record.

## Published Form Prefill Hardening: After Fix

Updated and redeployed `NativeForms-PrefillForm` on 2026-04-29.

Root cause clarification:

The original issue was not that prefill lacked a publish-token mechanism. The mechanism already existed: the prefill Lambda loaded the form security record by `formId`, checked that it was published, and compared the incoming `publishToken` hash to the stored hash before tenant lookup and Salesforce access.

The real problem was the public response shape after a valid token:

- It returned mapped runtime data, which is needed.
- It also returned raw `aliases`, Salesforce record metadata such as `attributes.url`, and internal command `results`.
- It accepted unexpected request params even if they were not part of the published prefill definition.

Changes made:

- Missing `publishToken` is rejected with 401 before request execution.
- Invalid `publishToken` is rejected with 401.
- A valid token paired with the wrong `formId` is rejected with 401.
- Unexpected prefill params are rejected with 400.
- Public successful prefill response now returns only runtime-needed sections:
  - `success`
  - `formId`
  - `input`
  - `hidden`
  - `meta`
  - `repeatGroups`
- Raw `aliases`, internal command `results`, and full mapped `output` are no longer returned to the browser.
- Removed verbose context/mapped-output logging from the public Lambda path.
- Increased `NativeForms-PrefillForm` timeout from 3 seconds to 10 seconds and memory from 128 MB to 256 MB to reduce cold-start/Salesforce-call timeout failures.

Validation results:

### Valid token and known email

- Status: 200

Response preview:

```text
{"success":true,"formId":"nf-00Dg5000008sWZN-a04g5000001BARhAAO","input":{"lastName":"Carter","email":"liam.carter@example.com","phone":"415-555-0102","firstName":"Liam"},"hidden":{},"meta":{},"repeatGroups":{}}
```

### Missing token

- Status: 401

Response preview:

```text
{"success":false,"error":"Missing required field: publishToken"}
```

### Invalid token

- Status: 401

Response preview:

```text
{"success":false,"error":"Unauthorized: invalid publish token"}
```

### Valid token with wrong form id

- Status: 401

Response preview:

```text
{"success":false,"error":"Unauthorized: invalid publish token"}
```

### Extra unexpected param

- Status: 400

Response preview:

```text
{"success":false,"error":"Unexpected prefill parameter"}
```

## Published Form Submit Negative Probes

Tested on 2026-04-29 against:

```text
https://forms.twinaforms.com/twinaforms/form1?email=liam.carter@example.com
```

This form has reCAPTCHA enabled and no file upload fields.

### Passive ZAP page scan

ZAPit still reports the same static page/header alerts:

- Medium: CSP header not set.
- Medium: anti-clickjacking header missing.
- Medium: SRI missing for Google reCAPTCHA script.
- Low: cross-domain JavaScript source inclusion for Google reCAPTCHA.
- Low: `Server` header exposes `AmazonS3`.
- Low: HSTS header not set.
- Low: `X-Content-Type-Options` header missing.
- Informational: email address in URL.
- Informational: suspicious comments.
- Informational: modern web application.
- Informational: cache-control directives.

These are page/header findings, not submit data-access findings.

### Submit without CAPTCHA

- Status: 400

Response preview:

```text
{"success":false,"submissionRef":"<ref>","error":"Please complete the CAPTCHA."}
```

The request was rejected before successful submission.

### Submit with invalid publish token

- Status: 401

Response preview:

```text
{"success":false,"submissionRef":"<ref>","error":"Unauthorized: invalid publish token"}
```

### Submit with wrong form id

- Status: 403

Response preview:

```text
{"success":false,"submissionRef":"<ref>","error":"Form is not published"}
```

### Submit missing required browser field

- Status: 400

Response preview:

```text
{"success":false,"submissionRef":"<ref>","error":"Please complete the CAPTCHA."}
```

Because CAPTCHA is enforced first, the request is blocked before field-level validation.

### Submit with unexpected input field

- Status: 400

Response preview:

```text
{"success":false,"submissionRef":"<ref>","error":"Please complete the CAPTCHA."}
```

Because CAPTCHA is enforced first, the request is blocked before submit mapping/field-policy execution.

### Submit missing publish token

- Status: 401

Response preview:

```text
{"success":false,"submissionRef":"<ref>","error":"Missing required field: publishToken"}
```

### Submit missing form id

- Status: 400

Response preview:

```text
{"success":false,"submissionRef":"<ref>","error":"Missing required field: formId"}
```

### Submit empty body

- Status: 400

Response preview:

```text
{"success":false,"submissionRef":"<ref>","error":"Missing required field: formId"}
```

### Positive submit

Initially automated CLI testing could not complete Google reCAPTCHA. After the form admin removed CAPTCHA from this test form, one positive submit probe was executed.

- Status: 200
- Result: test Contact created
- Created Contact Id: `003g500000EmijRAAR`
- Submission reference: `NF-20260429143655-D808AE`

Response preview:

```text
{"success":true,"submissionRef":"NF-20260429143655-D808AE","results":[{"commandKey":"submitAction1_find","type":"findOne","objectApiName":"Contact","id":null,"found":false,"skipped":false,"success":true},{"commandKey":"submitAction1","type":"update","skipped":true,"success":true},{"commandKey":"submitAction1_create","type":"create","objectApiName":"Contact","id":"003g500000EmijRAAR","skipped":false,"success":true}]}
```

The positive submit path works, but the public success response exposes internal command names, object names, operation types, and the Salesforce Contact Id. This should be reviewed. A safer public response would return only:

```text
{"success":true,"submissionRef":"NF-..."}
```

or an optional customer-facing post-submit message. Detailed command results should stay in server logs/admin logs, not the public browser response.

CloudWatch note:

The submit succeeded, but the submit Lambda logged a non-fatal warning:

```text
Submission log plan lookup failed: AccessDeniedException ... not authorized to perform dynamodb:GetItem on ... table/NativeFormsPlans
```

This indicates the `NativeForms-SubmitForm` role is missing read permission for `NativeFormsPlans`. Submission still succeeds because logging handles this failure as non-fatal.

### Behavior To Review

The submit Lambda returns a `submissionRef` even for rejected requests. This can be useful for support/log correlation, but it should be intentional. The response does not expose Salesforce data.
