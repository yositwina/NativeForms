# TwinaForms ZAP Scope Note

The ZAP reports in this folder cover the public/off-platform AWS endpoints used by the TwinaForms Salesforce package and public form runtime.

The testing follows a follow-the-data approach:

- public published form page
- public prefill endpoint
- public submit endpoint
- Salesforce-to-AWS backend endpoint
- Salesforce submission-log endpoint
- internal admin API endpoint

For Salesforce-to-AWS server callouts, the reports intentionally do not include real tenant bearer secrets. Protected routes are scanned with missing authentication so the official report can show unauthenticated rejection without exposing credentials in scan artifacts.

Valid authenticated Salesforce-to-AWS behavior is covered by functional testing and controlled CLI probes outside the ZAP artifact, because including real tenant secrets in a scanner report would create avoidable credential exposure.

The ZAP Automation Framework `requestor` job was used to send specific safe requests with expected response codes. The reports are passive scans and do not run active attack scans.
