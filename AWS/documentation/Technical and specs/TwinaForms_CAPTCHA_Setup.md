# TwinaForms Shared CAPTCHA Setup

This project now uses one TwinaForms-managed Google reCAPTCHA for forms published on `forms.twinaforms.com`.

## Ownership model

- `Site Key`: public and shared by TwinaForms
- `Secret Key`: private and stored only in the AWS submit Lambda environment
- Salesforce customers do not paste CAPTCHA keys manually

## Current shared site key

- `6LcclLgsAAAAAF3Te6PKyPqNhges_8IJkXBJtsru`

## Code paths

- Salesforce publisher injects the shared site key into generated form HTML:
  - `force-app/main/default/classes/NativeFormsPublisher.cls`
- AWS validates the CAPTCHA token with the private secret:
  - `AWS/NativeForms-SubmitForm.mjs`

## Required AWS environment variable

Set this on the `NativeForms-SubmitForm` Lambda:

- `CAPTCHA_SECRET_KEY`

Without it, forms with CAPTCHA enabled will fail submit with a server-side configuration error.

## Deployment helper

Use this script from the repo root to deploy the submit Lambda code:

```powershell
.\AWS\deploy-nativeforms-submit.ps1
```

Use this version when you also want to set or rotate the shared CAPTCHA secret:

```powershell
.\AWS\deploy-nativeforms-submit.ps1 -CaptchaSecretKey "YOUR_PRIVATE_GOOGLE_SECRET"
```

Default assumptions in the script:

- Lambda name: `NativeForms-SubmitForm`
- AWS region: `eu-north-1`
- AWS profile: `nativeforms-codex`

## Recommended rollout order

1. Deploy the updated Salesforce package metadata/code.
2. Deploy the updated `NativeForms-SubmitForm` Lambda.
3. Set `CAPTCHA_SECRET_KEY` on the Lambda.
4. Republish a form with CAPTCHA enabled.
5. Test submit on `https://forms.twinaforms.com/...`

## Verification checklist

- Form renders the Google checkbox.
- Submit without CAPTCHA is blocked.
- Submit with CAPTCHA succeeds.
- Lambda no longer reports missing shared CAPTCHA secret key.
