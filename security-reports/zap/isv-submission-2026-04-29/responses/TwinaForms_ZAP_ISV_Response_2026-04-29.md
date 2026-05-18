# TwinaForms ZAP ISV Response

This document explains the ZAP findings from the official reports in `security-reports/zap/isv-submission-2026-04-29/official-reports`.

## `01-published-form-page.html`

### Content Security Policy (CSP) Header Not Set

Classification: Accepted hardening item for launch.

The published form is served through CloudFront and S3. AWS managed `SecurityHeadersPolicy` is already attached to the `forms.twinaforms.com` distribution, which adds HSTS, `X-Content-Type-Options`, `Referrer-Policy`, `X-XSS-Protection`, and `X-Frame-Options`.

The remaining CSP finding is expected because the current CloudFront Free plan does not allow custom response headers policies. A custom CSP policy was prepared but could not be attached without moving the distribution to a paid CloudFront plan.

This finding does not show exposed Salesforce data, tokens, credentials, or tenant secrets. Runtime prefill and submit operations are validated server-side with the published form token.

### Server Leaks Version Information via `Server` Header

Classification: Expected infrastructure header.

The response includes `Server: AmazonS3` because the published form HTML is hosted on S3 behind CloudFront. This value identifies the AWS hosting service but does not expose application version numbers, source paths, credentials, tenant data, or Salesforce data.

### Information Disclosure - Sensitive Information in URL

Classification: Expected test input and accepted product behavior for this demo form.

The tested URL intentionally includes `email=liam.carter@example.com` to exercise the public prefill flow. This is sample data, not a password, OAuth token, API key, tenant secret, or AWS secret.

TwinaForms allows form administrators to configure prefill links. A lookup value such as an email address can be used when that is the intended form design. The browser cannot use that URL parameter to choose arbitrary Salesforce objects, fields, or queries. The prefill endpoint validates the published form token and rejects unexpected parameters.

For forms with more sensitive lookup values, the recommended form design is to avoid sensitive identifiers in the URL or use stronger verification before showing sensitive data.

### Information Disclosure - Suspicious Comments

Classification: False positive.

The reported evidence is generated form/runtime text such as `Select`. It is not a source-code comment, stack trace, credential, internal endpoint, or secret.

### Modern Web Application

Classification: Informational.

The published form is a JavaScript-enabled public web form. This is expected and does not indicate a vulnerability by itself.

### Re-examine Cache-control Directives

Classification: Expected behavior.

The published form uses conservative cache behavior so recently republished forms and setup changes are not hidden by stale browser or CDN content during customer onboarding and launch testing.

## `02-prefill-lambda.html`

### Cross-Domain Misconfiguration

Classification: Accepted runtime behavior.

The prefill Lambda allows cross-origin browser calls because published forms are static pages hosted separately from the Lambda Function URL. The endpoint does not rely on cookies or browser credentials. It requires a per-form public `publishToken`, validates the form id, rejects unexpected parameters, and returns only the fields mapped by the form designer for that published form.

This CORS configuration is not an authentication mechanism and does not grant access to arbitrary Salesforce data.

### Strict-Transport-Security Header Not Set

Classification: Accepted AWS Lambda Function URL limitation/hardening item.

The Lambda Function URL is an AWS-managed HTTPS endpoint. Salesforce and browser traffic use HTTPS. The missing HSTS header is a response-header hardening item on the AWS-managed Lambda URL domain, not evidence of plaintext transport.

If the endpoint is later placed behind a custom CloudFront/API Gateway domain, HSTS can be added there.

### X-Content-Type-Options Header Missing

Classification: Valid hardening item.

The endpoint returns JSON. Adding `X-Content-Type-Options: nosniff` to Lambda JSON responses is a reasonable future hardening improvement. The finding does not show data exposure or authentication bypass.

## `03-submit-lambda.html`

### Cross-Domain Misconfiguration

Classification: Accepted runtime behavior.

The submit Lambda must accept browser calls from published TwinaForms forms. The endpoint does not use cookies for authentication. It validates the per-form `publishToken`, form id, and configured submit policy before writing to Salesforce.

The official report uses safe rejection cases and does not create Salesforce records.

### Strict-Transport-Security Header Not Set

Classification: Accepted AWS Lambda Function URL limitation/hardening item.

The endpoint is served over HTTPS. The missing HSTS header is a response-header hardening item on the AWS-managed Lambda URL domain.

## `04-salesforce-backend-lambda.html`

### Cross-Domain Misconfiguration

Classification: Accepted behavior for this scan context.

Some backend responses include permissive CORS headers. These routes are not protected by CORS; protected routes require the tenant bearer secret used by Salesforce callouts. The official ZAP report intentionally sends missing-auth requests and verifies that protected routes reject unauthenticated access.

No tenant bearer secret is included in the report.

### Strict-Transport-Security Header Not Set

Classification: Accepted AWS Lambda Function URL limitation/hardening item.

The endpoint is HTTPS-only from the Salesforce package perspective. The missing HSTS header is a response-header hardening item on the AWS-managed Lambda URL domain.

### X-Content-Type-Options Header Missing

Classification: Valid hardening item.

The endpoint returns JSON. Adding `X-Content-Type-Options: nosniff` to Lambda JSON responses is a reasonable future hardening improvement.

### Re-examine Cache-control Directives

Classification: Informational.

The backend endpoint returns JSON operational responses. Caching is not used as an access control mechanism. Protected routes require tenant bearer authentication.

## `05-submission-logs-lambda.html`

### Cross-Domain Misconfiguration

Classification: Accepted behavior for this scan context.

The submission logs Lambda is called by Salesforce with tenant bearer authentication. The official ZAP report sends missing-auth requests and verifies that the routes reject unauthenticated access. No tenant bearer secret is included in the report.

### Strict-Transport-Security Header Not Set

Classification: Accepted AWS Lambda Function URL limitation/hardening item.

The endpoint is served over HTTPS. The missing HSTS header is a response-header hardening item on the AWS-managed Lambda URL domain.

## `06-admin-api-cognito.html`

### Strict-Transport-Security Header Not Set

Classification: Accepted AWS Lambda Function URL limitation/hardening item.

The Admin API is now protected by Cognito JWT validation. The official ZAP report sends requests without a Cognito token and verifies that the API rejects them with `401 Unauthorized`.

The missing HSTS header is reported on the AWS-managed Lambda Function URL. The admin web console itself is hosted on `admin.twinaforms.com` and uses Cognito Hosted UI login. A future API Gateway or custom CloudFront/API domain can add HSTS to the API response layer.
