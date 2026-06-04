# AWS Infrastructure

## Purpose
Keep Codex aligned with the current NativeForms AWS hosting targets, region, and deployment locations.

## Use When
Use for S3 website publishing, Lambda deployment targets, region-aware AWS changes, or infrastructure discovery before making production updates.

## NativeForms Rules
- Default AWS region for this project is `eu-north-1`.
- Primary S3 bucket for NativeForms web assets and published content is `nativeformspublish`.
- `twinaforms.com` content is published into path-style folders inside `nativeformspublish`.
- `admin.twinaforms.com` is currently served from the same bucket through CloudFront distribution `E3BZPH4WKETIFB` with origin path `/admin-console/dev`.
- The correct admin console publish target is `s3://nativeformspublish/admin-console/dev/`.
- Current upgrade page publish target is `s3://nativeformspublish/upgrade/`.
- Published forms also use `nativeformspublish`, and the runtime public base URL in AWS is `https://forms.twinaforms.com`.
- `NativeFormsBackend` owns publish lifecycle routes such as `POST /forms/register`, `POST /forms/publish/presign`, and `POST /forms/unpublish`, plus signed Salesforce admin-assist routes such as `POST /salesforce/layouts`.
- `NativeFormsBackend` timeout is 15 seconds because Salesforce OAuth refresh plus UI API layout metadata reads can exceed the old 3-second default.
- `POST /forms/unpublish` marks the `NativeFormsFormSecurity` record as `unpublished` and replaces the hosted form HTML with a small unavailable page when the publish key is known; it must not delete submission logs.
- File Upload malware scanning is being activated through a private upload-staging bucket, separate from `nativeformspublish`: `NativeFormsBackend` presigns upload and reports GuardDuty tag state, and `NativeForms-SubmitForm` may attach a file only after `GuardDutyMalwareScanStatus=NO_THREATS_FOUND`, then deletes the staged object.
- File Upload malware scanning is live as of `2026-05-27`: staging bucket `nativeforms-upload-staging-355617663345-eu-north-1` has public access blocked, AES256 encryption, published-form upload CORS, and one-day lifecycle cleanup; GuardDuty Malware Protection plan `30cf34d7ca325a62c314` is active with scan-result tagging; Backend and Submit Lambdas use `UPLOAD_STAGING_BUCKET`.
- Pro Country / State / City autocomplete uses DynamoDB table `NativeFormsGeoLocations` in `eu-north-1`. The table key contract is `locationPartition` as the partition key and `searchKey` as the sort key; `NativeFormsBackend` queries it from `POST /forms/location/search`, and `AWS/import-geonames-locations.mjs` loads GeoNames country/admin/cities500 data.
- `NativeFormsBackend` must keep inline IAM policy `NativeFormsGeoLocationsRead`, granting `dynamodb:Query` on `arn:aws:dynamodb:eu-north-1:355617663345:table/NativeFormsGeoLocations`; otherwise published forms show an AccessDenied error during Country / State / City autocomplete.
- Confirmed deployed Lambda region is `eu-north-1`.
- Confirmed Lambda function names used in this project include `NativeFormsBackend` and `NativeFormsAdminApi`.
- Repo also contains the public runtime Lambdas `NativeForms-PrefillForm` and `NativeForms-SubmitForm`; do not change those without explicit user approval.
- Known public web domains in this project include `twinaforms.com`, `www.twinaforms.com`, `admin.twinaforms.com`, and `forms.twinaforms.com`.
- Current TwinaForms CloudFront distribution map:
  - `E2YFHJ9TF0SW5N`: `forms.twinaforms.com`, description begins `NativeForms published HTML`, origin `nativeformspublish`, pricing plan `Free`. Use for published customer forms only.
  - `E3BZPH4WKETIFB`: `admin.twinaforms.com`, description begins `TwinaForms admin console static site`, origin `nativeformspublish`, pricing plan `Pay-as-you-go`. Use for the internal admin console only.
  - `E2LZYP4RR814H`: `www.twinaforms.com`, description begins `www.twinaforms.com`, origin `nativeformspublish`, pricing plan `Pay-as-you-go`. Use for the public TwinaForms marketing/product website.
- Ignore unrelated CloudFront distributions for `evhomelink` and `case2web` when working on TwinaForms.
- On this workstation, the confirmed AWS CLI profile for Codex AWS work is `nativeforms-codex`.
- Avoid the default AWS credentials when they resolve to `evhomelinkUser`; use `nativeforms-codex` for TwinaForms AWS reads, deploys, and tenant test resets.

## Escalate When
- A publish target is unclear between bucket root and prefix path.
- A task requires verified CloudFront distribution IDs, invalidations, or alias-to-distribution mapping.
- A change touches `NativeForms-PrefillForm` or `NativeForms-SubmitForm` without explicit user approval.

## Source Docs
- `AWS/documentation/Starter_Launch_Remaining_Checklist.md`
- `AWS/documentation/admin_control_app_v1_screen_structure.md`
- `AWS/documentation/admin_control_app_v1_focused_spec.md`
- `AWS/documentation/Technical and specs/admin_control_app_v1_api_implementation_notes.md`
