# Starter Immediate List

Last updated: 2026-04-18
0. on form setting, add option to change the form name under general (done)
0.  permision set changes
- TwinaFrom Adim App ant its tabs shoudl be in a differtn permision set not teh reglar one.
We need to enable this permission set as a support flag seats in dynamoddb per tenant and controled from Admin,twinaforms.
- Support limiting number of users, data should  be taken from Dynamodb, a differnt number is set per plan to be configured in Plans in admin.twinaforms
1. Finish Salesforce TwinaForms UI polish.
2. Rewrtie forms demo-data creation records.
3. Support republishing from a published version, then create the new draft as a copy of that republished version, with a double-confirmation popup before republish.
4. Clean customer-facing setup, publish, and runtime error messages (done)
5. Run full Starter QA across setup, connect, publish, prefill, submit, themes, logs, and admin.
6. Add Apex test classes needed for package readiness.
7. Create and validate the Salesforce package in a clean org.
8. Prepare install, post-install, and launch-facing docs.
9. Add Cognito authentication for the Admin app.
10. Keep CloudFront HTML caching effectively disabled for `twinaforms.com` during active Starter launch iteration; after Admin Cognito is complete and website copy stabilizes, split HTML vs asset caching behaviors.
11. Rebuild Home page (including style). Done.
12. Add thank-you page / thank-you message after submit. Done.
13. Add a `Required` checkbox for supported input fields above `User Access` on the Designer page. Done.
14. Finalize runtime endpoint cleanup in published forms and admin console. Deferred for now because the current endpoints work, are not customer-visible, and changing them now does not provide meaningful Starter launch value.
