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
  - Resolution: Solved by changing install/setup instructions.
  - Notes: Packaged External Credentials and principals install, but the manual assignment surface is the subscriber-created permission set, not the packaged TwinaForms permission sets. Connect/setup instructions now tell the customer to create `TwinaForms Credentials` (`TwinaFormsCredentials`), add the two principals there, and assign that permission set to the same users who need TwinaForms access.

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
  - Repro: Install the package in a clean org, complete the External Credential Principal Access setup, then refresh the Connect page before tenant secret verification is complete.
  - Actual: The page shows a red error such as `TwinaForms could not connect yet because the required permission-set access is not fully enabled.` and Salesforce may surface an internal server error ID.
  - Expected: Page-load status checks should use the bootstrap/status path only. The tenant-secret Named Credential should be probed only when the user clicks `Test Tenant Secret`.
  - Resolution: Solved in source by adding an explicit `verifyTenantAuthNow` flag to `NativeFormsSetupController.getConnectionStatus`, using `false` for page load/Home/Admin status checks and `true` only for the Connect page `Test Tenant Secret` action.

- [ ] BUG-008 Connect page does not pre-check current user permission-set setup
  - Severity: Medium
  - Area: Salesforce Connect page / setup flow
  - Repro: Install the package, create `TwinaForms Credentials`, add the required External Credential Principal Access, but assign it to a different user than the one currently opening Connect.
  - Actual: Connect shows a generic setup-access error and does not clearly tell the current user that they are missing the required permission-set assignment.
  - Expected: On Connect page load, check whether the current user has the required `TwinaForms User` and subscriber-created `TwinaForms Credentials` assignments, then show a clear customer-safe message if not.
  - Notes: Do not solve yet. Logged during Beta 4 package QA after a wrong-user assignment caused the initial refresh error.

- [x] BUG-009 Managed package LWC-to-Apex DTO binding fails before Apex logs
  - Severity: High
  - Area: Salesforce packaging / LWC-to-Apex contract
  - Repro: Install Beta 4, complete permission-set principal access correctly, open Connect, then press `Generate Secret`.
  - Actual: Salesforce returns `An internal server error has occurred` with error code `-583189392`; DevTools shows the Aura action calling `NativeFormsSetupController.registerOrg` with a custom DTO-shaped `requestBody`, but no Apex debug log is produced.
  - Expected: The action should reach Apex and either register the org or return a customer-safe handled error.
  - Resolution: Solved in source by changing package-visible LWC save/update/register request bodies from custom Apex DTO parameters to JSON string parameters that Apex deserializes inside the method body.
  - Notes: Same hardening was applied to Connect registration/client-credential save, Admin feature save, Theme save, Builder element update, Prefill action save, and Submit action save.
