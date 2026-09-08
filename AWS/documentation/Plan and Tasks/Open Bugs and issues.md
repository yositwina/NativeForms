# Open Bugs

## Current
- [x] BUG-001 Package install app visibility
  - Severity: High
  - Area: Salesforce packaging / app visibility
  - Repro: Install the package in a clean Developer Edition org, then open App Launcher.
  - Actual: Both `TwinaForms` and `TwinaForms Admin` are visible as separate apps.
  - Expected: Only `TwinaForms` should be visible to normal installed users by default.
  - Resolution: Solved in source by removing the separate packaged `TwinaForms Admin` app and moving admin/support-debug tooling into the main `TwinaForms` app as a gated area.
  - Notes: `NativeForms_Admin_Features` now lives inside the main app, `TwinaForms User` hides that tab, and `TwinaForms Admin` keeps the gated admin/debug access path.

- [ ] BUG-002 Home page connect link opens missing page
  - Severity: High
  - Area: Salesforce Home page navigation
  - Repro: On the Home page, press the button/link that should open the Connect page.
  - Actual: Salesforce opens a modal saying `Page doesn't exist` and `Enter a valid URL and try again`.
  - Expected: The Connect page should open correctly from Home.
  - Notes: Do not solve yet. Logged from first beta package QA.

- [x] BUG-005 Admin tabs/objects still searchable from App Launcher
  - Severity: Medium
  - Area: Salesforce packaging / app visibility
  - Repro: Install the package in a clean org, open the 9-dot App Launcher, and search for TwinaForms admin-related items.
  - Actual: The separate `TwinaForms Admin` app is gone, but admin tabs/objects/items from the old admin surface can still be found from the App Launcher.
  - Expected: Admin-only items should not be discoverable by normal installed users from the App Launcher.
  - Resolution: Solved in source by removing `NativeForms_Admin_Features` from the packaged `TwinaForms` app navigation and removing the admin tab setting from `TwinaForms User`.
  - Notes: Retest in the next package version with a normal installed user. Admin/debug access remains in the separate `TwinaForms Admin` permission set for support scenarios.

- [x] BUG-003 Connect page still shows red setup warning text
  - Severity: Medium
  - Area: Salesforce Connect page / packaging QA
  - Repro: Open the Connect page manually in the packaged install org.
  - Actual: The page shows a red warning banner and a `What To Do First` section with manual principal-access instructions.
  - Expected: Remove this red warning text and remove the `What To Do First` section text.
  - Resolution: Solved in source by removing the duplicate red setup-warning banner from `nativeFormsConnect`.
  - Notes: The normal Step 1 setup instructions remain on the page; only the extra red warning block was removed.

- [x] BUG-004 Packaged install missing external credential access/setup
  - Severity: High
  - Area: Salesforce packaging / external credentials
  - Resolution: Superseded by Bootstrap V2 cleanup.
  - Notes: The target package flow no longer uses Salesforce Named Credential or External Credential metadata. Bootstrap V2 direct OAuth plus HMAC replaces the customer-created service-access permission set.

- [ ] BUG-006 Connect page shows User Access too early
  - Severity: Medium
  - Area: Salesforce Connect page / setup flow
  - Repro: Open the Connect page before Step 1 and Step 2 are both complete and green.
  - Actual: The `User Access` section is shown before the connection/setup flow is fully complete.
  - Expected: Show `User Access` only after Step 1 and Step 2 are both completed successfully.
  - Notes: Do not solve yet. Logged during beta package QA.

- [x] BUG-007 Connect page refresh checks tenant secret credential too early
  - Severity: High
  - Area: Salesforce Connect page / packaging QA
  - Repro: Older package flow refreshed Connect before service auth was complete.
  - Actual: The page showed credential/setup errors too early.
  - Expected: Page-load status checks should not probe a customer-created credential.
  - Resolution: Superseded by Bootstrap V2. The package no longer uses Salesforce Named Credentials or External Credentials for the setup path.

- [x] BUG-008 Connect page does not pre-check current user permission-set setup
  - Severity: Medium
  - Area: Salesforce Connect page / setup flow
  - Repro: Older package flow required a subscriber-created service-access permission set with External Credential Principal Access.
  - Actual: Connect showed setup-access errors when the current user lacked that manual credential assignment.
  - Expected: Connect should not require subscriber-created service credential permission sets.
  - Resolution: Superseded by Bootstrap V2 direct OAuth/HMAC flow. Normal setup no longer depends on Salesforce External Credential Principal Access.

- [x] BUG-009 Managed package LWC-to-Apex DTO binding fails before Apex logs
  - Severity: High
  - Area: Salesforce packaging / LWC-to-Apex contract
  - Repro: Install Beta 4, complete permission-set principal access correctly, open Connect, then press `Generate Secret`.
  - Actual: Salesforce returns `An internal server error has occurred` with error code `-583189392`; DevTools shows the Aura action calling `NativeFormsSetupController.registerOrg` with a custom DTO-shaped `requestBody`, but no Apex debug log is produced.
  - Expected: The action should reach Apex and either register the org or return a customer-safe handled error.
  - Resolution: Solved in source by changing package-visible LWC save/update/register request bodies from custom Apex DTO parameters to JSON string parameters that Apex deserializes inside the method body.
  - Notes: Same hardening was applied to Connect registration/client-credential save, Admin feature save, Theme save, Builder element update, Prefill action save, and Submit action save.

- [ ] BUG-010 Bootstrap V2 Connect success page missing old post-connect actions
  - Severity: Medium
  - Area: Salesforce Connect page / Bootstrap V2 onboarding
  - Repro: Complete Bootstrap V2 connection successfully in DevHub or a test org, then return to the Connect page.
  - Actual: The page focuses on the Bootstrap V2 connection steps and does not return to the old post-connect experience.
  - Expected: After successful connection, the Connect page should look like the old connected state: show user licensing/seat management and provide a clear button back to the Home page after assigning users.
  - Notes: Do not solve yet. Logged from Bootstrap V2 DevHub testing.

- [x] BUG-011 Bootstrap V2 still requires subscriber-created permission set with External Credential Principal Access
  - Severity: High
  - Area: Salesforce packaging / Bootstrap V2 setup simplification
  - Repro: Install/deploy Bootstrap V2 flow and open Connect as an admin without adding the required External Credential Principal Access to a permission set assigned to the current user.
  - Actual: `Prepare Connection` failed until the admin created or updated a permission set with principal access for the packaged External Credentials.
  - Expected: Bootstrap V2 should remove this manual permission-set setup requirement.
  - Resolution: Solved in source by removing Salesforce Named Credential and External Credential metadata, building the AWS `/connect` URL directly, and signing package-to-AWS calls with Bootstrap V2 HMAC. Submission Logs were moved to the same direct HTTPS + HMAC pattern.
  - Notes: Retest in a clean org with no Named Credentials, no External Credentials, and no External Credential Principal Access before package creation.

- [x] BUG-012 Section missing Hidden user-access option
  - Severity: High
  - Area: Salesforce Designer / Special Elements / customer form setup
  - Repro: Add or select a Section in Designer and try to configure it as hidden from public form visitors.
  - Actual: The Section properties panel did not expose the `Hidden` User Access option, even though published HTML supports hiding section containers through `fieldBehavior = hidden`.
  - Expected: Sections should expose the same `Editable / Locked / Hidden` User Access selector as supported containers so admins can hide a whole section and its child fields.
  - Resolution: Solved in source by enabling field behavior support for `section` in `nativeFormsDesigner` and rendering the User Access radio group for Sections.
  - Notes: Retest by selecting a Section, setting User Access to `Hidden`, saving, publishing, and confirming the public page hides the full section.

- [x] BUG-013 Verified email not discoverable as Prefill value source
  - Severity: High
  - Area: Salesforce Prefill Actions / User Verification / customer form setup
  - Repro: Enable User Verification, then create a Contact prefill action that should match `Contact.Email` to the email entered in the verification gate.
  - Actual: The Prefill Actions page only exposed `URL Parameter`, `Form Field`, `Literal Value`, and optional alias sources, so admins could not tell that the verified email was available.
  - Expected: Prefill Actions should expose a clear `Verified Email` value source that matches against the email approved by User Verification.
  - Resolution: Solved in source by adding `Verified Email` to Prefill Actions and publishing that source as the trusted `{params.email}` runtime value.
  - Notes: Configure `Contact.Email Equals Verified Email`, map `Contact.Id` into a hidden/read-only form field if needed, then use that field or alias for submit/update behavior.

- [x] BUG-014 Time validation message persists after corrected input
  - Severity: Medium
  - Area: Published form runtime / Time fields / multilingual validation
  - Repro: In a Hebrew published form, submit with an invalid Time value, correct the field, and observe the validation UI before submit succeeds.
  - Actual: The browser validation bubble and page-level error could continue showing the old English `Please enter a valid time in HH:mm format.` message after the user corrected the time.
  - Expected: Time validation should clear as soon as the corrected value is valid, and Hebrew forms should use Hebrew validation text.
  - Resolution: Solved in source by validating Time fields on input, clearing stale page-level validation errors after a valid correction, and adding localized `timeInvalid` / `timeReview` runtime text.
  - Notes: Retest by entering an invalid time, correcting it to `10:00`, and confirming the red status clears before submitting again.

- [x] BUG-015 Hidden Group does not hide child elements
  - Severity: High
  - Area: Salesforce Designer / Special Elements / Group visibility
  - Repro: Create a Group, place fields or records under the Group, then set the Group `User Access` / field behavior to `Hidden`.
  - Actual: Only the Group header/container label is hidden. Child elements inside the Group remain visible.
  - Expected: Hidden behavior on a Group should hide the entire Group subtree, including the header/container and every nested child element. The same cascade rule should apply consistently in Designer preview and published runtime.
  - Resolution: Solved in source by treating `fieldBehavior = hidden` on container elements as a static hidden subtree. Designer preview marks hidden Sections/Groups/Records Lists with a hidden-subtree class so child preview fields are suppressed, and published HTML emits `data-hidden-behavior="true"` so runtime visibility evaluation cannot re-show the hidden container after load.
  - Notes: Child controls remain part of the container DOM in published HTML, so existing hidden/prefilled data behavior is preserved while the public visual subtree stays hidden.

- [ ] BUG-016 Records List prefill/submit setup is too hard for normal admins
  - Severity: High
  - Area: Salesforce Designer / Prefill Actions / Submit Actions / Records List onboarding
  - Repro: Configure a real related-record form with User Verification, Contact prefill, parent Daily Report find-or-create, and child Daily Activities Records List submit.
  - Actual: The admin must manually coordinate multiple concepts across pages: Records List source prefill alias, child object, row field mappings, hidden Id fields, parent submit alias, records-list submit action, relationship field, and relationship value source. Even an experienced builder can confuse prefilled parent Id fields with submit result alias Ids.
  - Expected: Records List setup should guide the admin through one coherent parent-child flow, infer intent from the row mappings where possible, and prevent invalid combinations.
  - Product Decision: Do not require an explicit user-facing Records List mode and do not require prefill just to submit row records. Treat row prefill as optional input loading and row submit as the save definition.
  - Concept Solution: Infer the Records List row object from the selected row prefill alias and/or row submit action. If both exist, validate that they point to the same Salesforce object. If neither exists yet, show the row object as unknown until the admin selects a prefill alias or submit action. For create-only row submit, allow blank/new rows without a prefill alias or row Id mapping. For edit-existing rows, require a prefill source and an Id mapping before update/delete behavior is available. Keep the parent lookup Id definition in Submit Actions, but avoid making admins configure the same object/source twice.
  - Notes: Do not solve yet. This came from the first complex real-client setup and should be treated as a product usability gap, not only documentation.

- [x] BUG-017 Lookup fields are blocked inside Records Lists
  - Severity: Medium
  - Area: Salesforce Designer / Published runtime / Records List row fields
  - Repro: Try to place a Lookup field inside a Records List row.
  - Actual: Designer blocks the placement with `Lookup fields are not supported inside repeat groups in Starter V1.`
  - Expected: Admins may need per-row lookup selection for related-detail forms, especially when each child row must reference another Salesforce record.
  - Concept Solution: Implemented as scoped Records List lookup support. The published runtime renders lookup children as row-scoped compound controls, stores the selected Salesforce Id in a hidden `data-repeat-field-key` input, initializes lookup handlers for dynamically added/prefilled rows, resolves visible labels per row, and keeps lookup debounce/abort state per lookup instance. Submit continues to use existing `{row.fieldKey}` mapping.
  - Notes: Fixed for the real-client Records List use case. Lookup search still uses server-stored lookup definitions, strict field/object allowlisting, result limits, and the existing submit policy.

- [x] BUG-018 Published Date fields have no calendar picker
  - Severity: Medium
  - Area: Published runtime / mobile UX / Date fields
  - Repro: Add a Date element and open the published form on desktop or mobile.
  - Actual: The published Date control is a TwinaForms text input only. Users must type the date manually.
  - Expected: Date controls should allow normal manual typing and also expose a calendar picker by default.
  - Concept Solution: Implemented an always-on TwinaForms date picker in the Salesforce-generated published runtime. The picker fills the same text input, respects the existing US/EU display format and min/max date constraints, initializes inside Records List rows, and keeps submission normalization to Salesforce `YYYY-MM-DD`.
  - Notes: No AWS change and no new Designer setting. The browser native date input is still avoided so TwinaForms keeps consistent locale, RTL, validation, and Salesforce normalization behavior.

- [x] BUG-019 Formula fields cannot be used inside Records Lists
  - Severity: Medium
  - Area: Salesforce Designer / Published runtime / Records List row fields
  - Repro: Add a Text or Number field inside a Records List and try to configure it as a Formula field.
  - Actual: Designer and server-side save validation rejected formula fields inside repeat groups.
  - Expected: Admins should be able to calculate per-row text or number values, such as a row summary or row amount, and submit the calculated value with the row.
  - Concept Solution: Implemented same-row Records List formula support. A formula target inside a Records List may reference sibling row fields with `{row.fieldKey}` and normal top-level fields with `{fieldKey}`. Published runtime evaluates the formula separately for each row and submits the computed value through the existing row payload.
  - Notes: V1 remains intentionally scoped. Formula-to-formula references, cross-row totals, references to another Records List row, and AWS/server-side formula re-evaluation are still not supported.

- [x] BUG-020 Records List submit sends parent relationship field on update rows
  - Severity: High
  - Area: AWS Submit Lambda / Records List `upsertMany`
  - Repro: Prefill existing Records List rows, include a hidden row Activity Id field mapped to Salesforce `Id`, then submit row changes.
  - Actual: AWS treats rows with `Id` as updates, but still sends the configured parent relationship field such as `Daily_Instructor_Report__c`. Salesforce can reject the update with `INVALID_FIELD_FOR_INSERT_UPDATE` when the relationship field is not updateable by the connected user or cannot be changed after creation.
  - Expected: The parent relationship field should be applied to newly created child rows only. Existing child rows already belong to the parent and should update only their mapped row fields.
  - Concept Solution: In `upsertMany`, resolve the parent relationship value once but merge it into the Salesforce payload only for rows without an Id. Keep existing rows update-only and leave future explicit re-parenting as a separate advanced capability.
  - Resolution: Implemented in AWS submit runtime and protocol tests.

- [x] BUG-021 Salesforce Time fields are shifted by timezone on submit
  - Severity: High
  - Area: AWS Submit Lambda / Salesforce field coercion / Time fields
  - Repro: Submit `9:00` from a TwinaForms Time field mapped to a Salesforce Time field while the user/org is in Israel time.
  - Actual: Salesforce stores/displays `6:00`, indicating the short time value was interpreted through a GMT offset. A Time field should represent the entered clock time, not a DateTime moment.
  - Expected: Time submit values should preserve the entered wall-clock time, for example `9:00` should become `09:00` in Salesforce regardless of the form date timezone/GMT setting.
  - Concept Solution: When Salesforce describe reports a target field type of `time`, normalize submitted values to Salesforce's Time API shape `HH:mm:ss.SSSZ`, for example `09:00:00.000Z`. Do not apply TwinaForms date timezone/GMT settings to simple Time fields.
  - Resolution: Implemented in AWS submit runtime and protocol tests.

- [ ] ENH-022 Lookup selection can populate additional form fields
  - Severity: Medium
  - Area: Salesforce Designer / Lookup runtime / Prefill-like field mapping
  - Request: Match FormAssembly-style lookup behavior where the admin defines a Lookup search field, then maps fields from the selected Salesforce record into other TwinaForms fields.
  - Example: Search Contact by `Name`, then set form fields from the selected Contact such as Email, Phone, or a hidden Contact Id. Inside Records Lists, each row lookup should be able to populate fields in the same row.
  - Expected: Lookup configuration should support one or more `set field` mappings: selected lookup record field -> target form field. Top-level lookups may populate top-level fields. Row lookups may populate sibling row fields in the same Records List row.
  - Concept Solution: Extend the published lookup endpoint allowlist to include selected return fields, return those fields with each lookup result, and apply mapping client-side when the user chooses a result. Enforce object/field allowlisting in the published form security definition, keep mappings row-scoped inside Records Lists, and avoid allowing one row lookup to overwrite another row or unrelated top-level fields unless explicitly designed.
  - Notes: Do not implement yet. Treat as a usability enhancement for reducing manual prefill/formula/hidden-field setup after a lookup selection.

- [ ] BUG-023 Records List submit writes rows one-by-one, risking timeout and partial writes
  - Severity: High
  - Area: AWS submit runtime (`upsertMany`) / Records Lists
  - Repro: Publish a form with a Records List and submit it with many rows (roughly 40+), or prefill a parent whose child list is large and submit without changing anything.
  - Actual: `upsertMany` (`AWS/NativeForms-SubmitForm.mjs:3359`) loops over the rows and awaits one Salesforce REST call per row, sequentially. It also rewrites **every** row on every submit, with no dirty checking, so changing a single cell still issues one update per displayed row. Deletes are looped the same way. At roughly 200-400ms per write, 50 rows costs 10-20 seconds, inside a Lambda whose timeout is 30 seconds and which must also fit token refresh, the parent action, captcha and any Apex callouts.
  - Expected: Submitting a Records List should complete in about a second and should never leave Salesforce half-written.
  - Impact: Two distinct problems. (1) Slow submits - a visible multi-second spinner on ordinary forms. (2) **No transaction.** If the run times out at row 37, rows 1-36 are already committed. The user sees an error, and re-submitting recreates the rows that had no Id, producing duplicates. The hazard grows with row count.
  - Concept Solution: Replace the per-row loop with Salesforce sObject Collections (`/composite/sobjects`, up to 200 records per call) - one call for all creates and one for all updates, plus one for deletes. This turns 50 sequential round-trips into 2-3, cuts submit time to well under a second, shrinks the partial-write window to a single request, and improves every existing manually built Records List form, not only new ones. Optionally add dirty checking so unchanged rows are not rewritten at all.
  - Notes: Do not solve yet. Discovered while sizing the row limit for the Page Layout to Form related-records feature (`AWS/documentation/New features after 0.1/Layout_to_Form_Related_Records_Table.md`). Until this is fixed, cap the generated related-records list at 20 rows rather than 50. With sObject Collections in place, 100+ rows becomes safe.

- [ ] ENH-024 Records List should support a configurable row sort field and direction
  - Severity: Medium
  - Area: Salesforce Designer / Records List element / Prefill `findMany`
  - Request: On the Records List element, let the author choose which field the rows are sorted by and whether the order is ascending or descending.
  - Actual: Row order is whatever the prefill query returns. There is no per-element sort control in the designer.
  - Expected: Two new settings on the Records List element - a sort field picker (limited to the fields present in that list) and an Ascending/Descending toggle. The published form should render prefilled rows in that order.
  - Concept Solution: `findMany` already supports `orderBy`, so this is mostly designer UX plus passing the chosen field/direction into the generated prefill command. Decide whether the sort applies only to prefilled rows or also re-sorts after the user adds rows - simplest is prefill order only, since re-sorting under the user while they type is disorienting.
  - Notes: Default when unset should be `CreatedDate DESC` (newest first). Raised alongside the Page Layout to Form related-records feature, which needs a sensible default ordering for generated lists.
