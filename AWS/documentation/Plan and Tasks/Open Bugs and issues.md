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
