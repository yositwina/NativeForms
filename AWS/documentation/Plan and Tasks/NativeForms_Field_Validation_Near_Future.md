# NativeForms Field Validation - Near Future

## Status
Deferred until File Upload malware scanning is complete.

## Product Decision
Better field validation is a valuable near-future enhancement, but public File Upload security is the higher-priority launch concern. Validation should be improved as part of normal field capabilities, not positioned as a separate paid feature by default.

## Current Foundation
TwinaForms already supports:
- required input checks
- email and URL browser-format checks
- number minimum and maximum values
- date range and time-format checks
- text rules for letters only, numbers only, and alphanumeric only
- required checks for lookup, signature, row signature, and file upload
- final Salesforce validation rules when a submitted record is written

Current gap:
- many friendly input checks occur in the published browser runtime; a direct caller can bypass browser behavior
- Salesforce can reject invalid business values, but this is later in the flow and may produce less helpful customer messages

## Recommended V1 Enhancement
Add guided validation options with admin-configured customer error messages:

| Element | Rules To Add |
| --- | --- |
| Text / Text Area | minimum length, maximum length, built-in pattern choices |
| Email | format plus optional allowed/blocked domain rules later |
| Phone | minimum/maximum digits and guided phone-format presets |
| Number | whole number only and decimal precision |
| Date | past only, future only, minimum age |
| Multi Checkbox | minimum and maximum selected choices |
| File Upload | file count and total upload size per submission |

Example customer error messages:
- `Employee ID must contain 8 digits.`
- `You must be at least 18 years old.`
- `Select no more than 3 choices.`

## Architecture Direction
Validation should run in two places:
1. Published browser runtime for immediate feedback.
2. AWS submit runtime against the stored published form definition before Salesforce commands or file finalization run.

Salesforce validation rules remain the final record-level business guardrail; they should not be the only server-side enforcement for TwinaForms-authored rules.

## Advanced Validation Later
After the guided presets are stable, consider a Pro advanced capability:
- `Reject When Formula Is True`
- configurable customer-facing rejection message
- possibly guided regular expressions for advanced admins

Do not begin with raw regular expressions as the primary UX. They are difficult to configure, localize, test, and support.

## Suggested Delivery Order
1. Complete File Upload malware scanning.
2. Add text length, number precision, date/age, and custom message presets.
3. Enforce those rules in AWS submit before Salesforce writes.
4. Add focused tests for bypassing browser validation.
5. Re-evaluate formula-driven rejection rules.

