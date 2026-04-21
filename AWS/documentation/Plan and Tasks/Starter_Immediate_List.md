# Starter Immediate List

Last updated: 2026-04-19

1. Permission set changes.
TwinaForms Admin App and its tabs should be in a different permission set, not the regular one.
Enable this permission set as a support-flag seat in DynamoDB per tenant, controlled from Admin TwinaForms.
Support limiting the number of users, with data taken from DynamoDB. A different number should be set per plan and configured in Plans in `admin.twinaforms`.
See:
- `AWS/documentation/Technical and specs/Salesforce_Permission_Set_Management_V1.md`
Multilingual product rule:
2. Finish Salesforce TwinaForms UI polish.
3. Rewrite forms demo-data creation records.
4. Support republishing from a published version, then create the new draft as a copy of that republished version, with a double-confirmation popup before republish.
5. Run full Starter QA across setup, connect, publish, prefill, submit, themes, logs, and admin.
6. Add Apex test classes needed for package readiness.
7. Create and validate the Salesforce package in a clean org.
8. Prepare install, post-install, and launch-facing docs.
9. Add Cognito authentication for the Admin app.
10. Keep CloudFront HTML caching effectively disabled for `twinaforms.com` during active Starter launch iteration; after Admin Cognito is complete and website copy stabilizes, split HTML vs asset caching behaviors.
11. Keep CloudFront caching effectively disabled for `admin.twinaforms.com` during active Starter admin iteration; before production stabilization, restore normal production caching for the admin distribution.
12. Finalize runtime endpoint cleanup in published forms and admin console. Deferred for now because the current endpoints work, are not customer-visible, and changing them now does not provide meaningful Starter launch value.
13. Add option in Form Settings to change the form name under General. Done.
14. Clean customer-facing setup, publish, and runtime error messages. Done.
15. Rebuild Home page (including style). Done.
16. Add thank-you page / thank-you message after submit. Done.
17. Add a `Required` checkbox for supported input fields above `User Access` on the Designer page. Done.
