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
- `NativeFormsBackend` owns publish lifecycle routes such as `POST /forms/register`, `POST /forms/publish/presign`, and `POST /forms/unpublish`.
- `POST /forms/unpublish` marks the `NativeFormsFormSecurity` record as `unpublished` and replaces the hosted form HTML with a small unavailable page when the publish key is known; it must not delete submission logs.
- Pro V1 browser file uploads use presigned S3 `PUT` requests into `nativeformspublish`, so that bucket must allow CORS from `https://forms.twinaforms.com` for at least `PUT`, `GET`, and `HEAD`.
- Confirmed deployed Lambda region is `eu-north-1`.
- Confirmed Lambda function names used in this project include `NativeFormsBackend` and `NativeFormsAdminApi`.
- Repo also contains the public runtime Lambdas `NativeForms-PrefillForm` and `NativeForms-SubmitForm`; do not change those without explicit user approval.
- Known public web domains in this project include `twinaforms.com`, `admin.twinaforms.com`, and `forms.twinaforms.com`.
- CloudFront distribution IDs and internal distribution names are not yet verified in-repo because the current IAM user cannot list CloudFront distributions.
- On this workstation, the confirmed AWS CLI profile for Codex deploy work is `codex-nativeforms`.
- The local AWS CLI config also contains a `nativeforms-codex` profile, but `codex-nativeforms` is the confirmed working profile used for Lambda deploys in this repo.

## Escalate When
- A publish target is unclear between bucket root and prefix path.
- A task requires verified CloudFront distribution IDs, invalidations, or alias-to-distribution mapping.
- A change touches `NativeForms-PrefillForm` or `NativeForms-SubmitForm` without explicit user approval.

## Source Docs
- `AWS/documentation/Starter_Launch_Remaining_Checklist.md`
- `AWS/documentation/admin_control_app_v1_screen_structure.md`
- `AWS/documentation/admin_control_app_v1_focused_spec.md`
- `AWS/documentation/Technical and specs/admin_control_app_v1_api_implementation_notes.md`
