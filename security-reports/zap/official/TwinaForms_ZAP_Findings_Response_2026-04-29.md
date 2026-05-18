# TwinaForms ZAP Findings Response

Report reviewed: `official-zap-form1-recon-2026-04-29.html`

Target tested: `https://forms.twinaforms.com/twinaforms/form1?email=liam.carter@example.com`

Tool: ZAP 2.17.0 by Checkmarx

Scan type: Passive reconnaissance scan. The scan loaded the published TwinaForms test form and evaluated the HTTP response with ZAP passive rules. It did not run an active attack scan.

## Content Security Policy (CSP) Header Not Set

ZAP severity: Medium

Classification: Valid hardening recommendation, not a confirmed application vulnerability.

The tested page is a published TwinaForms static HTML form served from the TwinaForms public form hosting domain. ZAP reports this because the HTTP response does not currently include a Content-Security-Policy response header.

The finding does not show that Salesforce data, tokens, credentials, or tenant secrets were exposed. It is a browser hardening recommendation for the public form hosting layer.

TwinaForms uses a generated form page that only contains the published form configuration needed by the browser. Prefill and submit operations are still validated by the TwinaForms AWS service. Prefill requires the publish token that belongs to the published form, rejects unexpected prefill parameters, and does not allow the browser to choose Salesforce objects, fields, or actions.

Planned handling: add a CloudFront response header policy with an appropriate CSP for published forms. This needs to allow the expected TwinaForms runtime resources and any customer-enabled third-party scripts such as Google reCAPTCHA.

## Strict-Transport-Security Header Not Set

ZAP severity: Low

Classification: Valid hardening recommendation, not a confirmed application vulnerability.

The tested URL was loaded over HTTPS. ZAP reports this because the response does not currently include the Strict-Transport-Security header.

The finding does not indicate that the form was served over HTTP or that Salesforce data was transmitted without TLS. It only means the browser is not being instructed to remember HTTPS-only access for this domain.

Planned handling: add HSTS through the CloudFront response header policy for the public form hosting domain after confirming the domain is intended to be HTTPS-only for all production paths.

## Information Disclosure - Sensitive Information in URL

ZAP severity: Informational

Classification: Expected test input and accepted product behavior for this form, not a secret exposure.

ZAP reported the value `liam.carter@example.com` because the test URL intentionally included `email=liam.carter@example.com`. This email address is sample/demo data used to test public prefill behavior.

TwinaForms supports administrator-configured prefill links. A form administrator may choose to pass a lookup value such as an email address in the URL when designing a public form experience. This value is not a Salesforce credential, OAuth token, API key, tenant secret, or AWS secret.

The browser cannot use the URL parameter alone to run arbitrary Salesforce queries. The published form includes a server-issued publish token, and the TwinaForms prefill Lambda validates that token before running prefill. The prefill endpoint also rejects unexpected URL parameters and returns only the fields that the form designer mapped for that published form.

For forms that collect or prefill more sensitive information, the recommended configuration is to avoid sensitive identifiers in the URL and use stronger user verification, such as a secret-code step, before showing sensitive data.
