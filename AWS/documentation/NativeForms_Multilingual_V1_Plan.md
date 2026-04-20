# NativeForms Multilingual V1 Plan

Last updated: 2026-04-20

## Goal
Add multilingual support to published TwinaForms form experiences with a clean ownership model and a practical V1 scope.

V1 target languages:
- `en`
- `he`
- `es` scaffold only

V1 decision:
- Customer-facing runtime text and validation text should support multiple languages.
- Most technical/debug-style error messages may remain English in V1.

## Core Principles
- Do not introduce fixed English customer-facing text in published forms when the text is visible during normal form usage.
- Prefer removing unnecessary decorative/instructional copy over translating it.
- Customer/business copy should be configurable per form where appropriate.
- Generic platform/runtime copy should come from a packaged language dictionary.
- Published forms should be self-contained after publish and should not need a live translation fetch.
- Form design remains the source of truth in Salesforce.
- Hebrew support includes RTL QA, not only translated strings.

## Scope
### In scope for V1
- Published form runtime text
- Validation text shown during normal form usage
- Secret-code public flow text
- File-upload public flow text
- Repeat-group customer-facing action text
- Result-panel titles and generic customer-facing result text
- Locale-sensitive date hint text
- Designer secret-code preview text
- Form-level language selection in Salesforce

### Out of scope for V1
- Full Salesforce admin/designer UI localization
- Admin console localization
- DynamoDB-hosted language dictionaries
- Browser auto-detection of language
- Tenant-wide translation override management
- Full translation of low-level technical/debug errors

## Ownership Model
### 1. Per-form configurable text
Use Form Settings for text that is customer/business-specific.

Examples:
- submit button label
- submit success message
- post-submit button label
- secret-code intro text
- secret-code sent message
- secret-code invalid message
- secret-code verified message
- secret-code send button label
- secret-code verify button label
- secret-code resend button label

### 2. Packaged runtime dictionary
Use Salesforce-package-owned language dictionaries for reusable generic runtime text.

Examples:
- `Submitting...`
- `Submitted successfully`
- `Submit failed`
- `Select...`
- `Add Row`
- file upload status/action text
- validation messages
- CAPTCHA required text
- countdown text

### 3. Remove entirely when possible
Some text should not exist at all in V1 because the UI is clear without it.

Examples:
- `Locked Until Verified`
- `Secret Code Verification`
- `Code step appears after the user presses Enter`
- `Choose a file to upload`

## Product Decisions
- Language selection is per form.
- Base dictionaries live in the Salesforce package, not DynamoDB.
- Publisher resolves the selected language plus form overrides and embeds the final text bundle in the published config.
- English remains the fallback language only.
- Hebrew uses RTL-aware layout verification.
- Spanish may be included as a starter dictionary scaffold, but `en` and `he` are the release priority.

## Text Categories
### A. Must be multilingual in V1
- normal customer-facing action text
- validation text
- form status text that appears during a standard successful/failed flow
- file-upload action/status text
- repeat-group action text
- generic runtime UI labels shown to form end users

### B. Can remain English in V1
- detailed technical/debug fallback text
- internal configuration/problem explanations
- deep technical error detail blocks

### C. Prefer to remove instead of translate
- decorative secret-code headings/badges
- extra helper headlines when a field label already explains the element

## Recommended Architecture
### Salesforce package
Add a packaged translation provider, for example:
- `NativeFormsRuntimeI18n.cls`

Responsibilities:
- expose built-in dictionaries for `en`, `he`, and `es`
- resolve a requested language code
- fall back to `en`
- provide locale-aware date hint strings

### Form settings
Add `languageCode` to form/version UI settings.

Recommended values:
- `en`
- `he`
- `es`

### Publisher
`NativeFormsPublisher.cls` should:
1. load `languageCode`
2. load the packaged runtime dictionary
3. merge in existing per-form configurable text where relevant
4. publish a resolved `runtimeText` object into `window.NativeFormsConfig`
5. replace hardcoded customer-facing runtime strings with `runtimeText` usage

### Runtime
Published runtime should use only:
- `config.runtimeText`
- existing per-form configured values already resolved into config

Runtime should not fetch translation data after publish.

## Suggested Config Shape
Example published config fragment:

```json
{
  "languageCode": "he",
  "runtimeText": {
    "submitting": "...",
    "submitSuccessTitle": "...",
    "submitErrorTitle": "...",
    "selectPlaceholder": "...",
    "repeatAddRow": "...",
    "postSubmitContinuingIn": "...",
    "fileBrowseSingle": "...",
    "fileBrowseMultiple": "...",
    "fileRemoveSingle": "...",
    "fileRemoveMultiple": "...",
    "fileUploading": "...",
    "fileReady": "...",
    "fileUploadedFallbackName": "...",
    "fileUploadPleaseWait": "...",
    "fileUploadRequired": "...",
    "fileUploadFailed": "...",
    "captchaRequired": "...",
    "validationDateInvalid": "...",
    "validationDateMin": "...",
    "validationDateMax": "..."
  }
}
```

## V1 String Ownership by Area
### Result panel
Dictionary:
- success title
- error title
- countdown text

Per-form configurable:
- success message
- post-submit button label

### Submit flow
Dictionary:
- submitting
- generic customer-safe submit failure title

Technical details:
- may remain English in V1

### Repeat groups
Dictionary:
- add row

Optional later:
- delete-row text if surfaced as visible text

### Picklists
Dictionary:
- select placeholder

### Required fields
No translation work needed for the `*` marker itself.

### Date validation
Dictionary:
- invalid date format
- min date validation
- max date validation

Locale-aware:
- date format hint and placeholder text

### CAPTCHA
Dictionary:
- `Please complete the CAPTCHA.`

### File upload
Dictionary:
- browse single
- browse multiple
- remove single
- remove multiple
- uploading
- ready
- uploaded fallback file name
- please wait for uploads
- required upload missing
- generic upload failed
- upload review prompt
- allowed/max size/multiple files allowed meta text

Remove:
- `Choose a file to upload`

### Secret code
Per-form configurable:
- intro text
- sent message
- invalid message
- verified message
- send button label
- verify button label
- resend button label

Remove:
- badge/title/helper text not required for the flow

Validation text:
- `Verify the secret code before continuing.` should move to dictionary

## Detailed Delivery Plan
### Phase 1. Define string inventory and ownership
Create a complete inventory of hardcoded user-visible strings in:
- [NativeFormsPublisher.cls](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/classes/NativeFormsPublisher.cls)
- [nativeFormsDesigner.html](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/lwc/nativeFormsDesigner/nativeFormsDesigner.html)
- [nativeFormsDesigner.js](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/lwc/nativeFormsDesigner/nativeFormsDesigner.js)

For each string, classify it as:
- dictionary
- per-form configurable
- remove
- technical English fallback

Output:
- a stable key list for runtime dictionaries

### Phase 2. Add form language setting
Update Form Settings to include:
- `Language`

Requirements:
- stored in version UI settings JSON
- defaults to `en`
- available now even before full migration is complete

Files likely touched:
- `NativeFormsDesignerController.cls`
- `nativeFormsDesigner.js`
- `nativeFormsDesigner.html`

### Phase 3. Build packaged dictionary provider
Create:
- `NativeFormsRuntimeI18n.cls`

Responsibilities:
- return dictionary maps for `en`, `he`, `es`
- normalize requested language
- fall back to `en`
- provide date-format-specific validation templates

Recommendation:
- keep dictionary data in Apex maps for V1
- move to static resources later only if size becomes unwieldy

### Phase 4. Publish resolved runtimeText
Update publisher so published config includes:
- `languageCode`
- `runtimeText`

Publisher should merge:
- selected packaged language dictionary
- per-form settings where relevant

Important:
- runtime remains self-contained after publish

### Phase 5. Migrate high-visibility runtime strings
Replace hardcoded publisher strings for:
- submitting
- success/error result titles
- select placeholder
- add row
- countdown text

Keep technical detail bodies English if not customer-facing.

### Phase 6. Migrate validation strings
Move customer-facing validation strings into dictionary-backed functions:
- date invalid
- date before/after range
- review date fields
- CAPTCHA required
- secret-code required-before-submit
- upload required/waiting/review text

Keep deep technical debug detail in English.

### Phase 7. Migrate file-upload flow
Move file-upload action/status/meta strings into the dictionary:
- browse
- remove
- uploading
- ready
- uploaded fallback name
- allowed/max size/multiple files allowed

Keep upload surface minimal and language-safe.

### Phase 8. Finish secret-code multilingual cleanup
Ensure secret-code public flow uses:
- configurable messages
- configurable button labels
- no extra decorative English-only text

Move any remaining generic validation prompts to the dictionary.

### Phase 9. Update designer preview
Ensure designer preview matches multilingual-safe rules:
- no fixed English decorative copy
- preview respects configurable secret-code button labels
- preview aligns with selected language direction where relevant

### Phase 10. Hebrew QA pass
Verify:
- RTL layout
- label placement left/right/above/none
- secret-code flow
- file-upload flow
- repeat groups
- result panels
- date inputs and hints
- button alignment and direction

### Phase 11. Spanish scaffold
Add `es` dictionary entries for the same keys.

V1 release does not require deep Spanish UX polishing if English/Hebrew are the launch priority, but the structure should support it cleanly.

## Suggested Initial Dictionary Keys
- `submitting`
- `submitSuccessTitle`
- `submitErrorTitle`
- `selectPlaceholder`
- `repeatAddRow`
- `postSubmitContinuingIn`
- `captchaRequired`
- `secretVerifyRequiredBeforeSubmit`
- `dateInvalid`
- `dateMin`
- `dateMax`
- `dateReview`
- `prefillLoadFailed`
- `submitFailedGeneric`
- `fileBrowseSingle`
- `fileBrowseMultiple`
- `fileRemoveSingle`
- `fileRemoveMultiple`
- `fileUploading`
- `fileReady`
- `fileUploadedFallbackName`
- `fileUploadsConfigMissing`
- `fileUploadPleaseWait`
- `fileUploadRequired`
- `fileUploadFailed`
- `fileUploadReview`
- `fileAllowedTypes`
- `fileMaxSize`
- `fileMultipleAllowed`

## UX Rules for Translators and Implementers
- Do not add text just because a control feels visually empty.
- Prefer labels and layout over helper headlines.
- Keep customer-facing text short.
- Avoid technical phrasing in public runtime copy.
- When a field already has a label, do not duplicate the meaning in another fixed sentence.
- Keep validation text direct and actionable.

## Acceptance Criteria
- Each form can choose `en` or `he` in Form Settings.
- Published forms show no fixed English customer-facing UI text in the covered V1 areas when set to Hebrew.
- Secret-code flow has no decorative English-only text.
- File-upload flow has no unnecessary English helper headline.
- Validation text in covered flows follows selected language.
- Published runtime does not fetch translations after publish.
- Existing configurable per-form text still works and overrides defaults as expected.

## Recommended Rollout Order
1. Language setting
2. Dictionary provider
3. Publisher `runtimeText`
4. High-visibility runtime strings
5. Validation strings
6. File upload
7. Secret code
8. Hebrew QA
9. Spanish scaffold

## Effort Estimate
For V1 with `en` and `he` done properly:
- approximately 3 to 4 focused working days

With Spanish scaffold and cleanup/refinement:
- approximately 4 to 6 working days

## Later Options
Possible later extensions:
- tenant-wide translation overrides
- admin-console localization
- browser-language auto-selection
- static-resource-based dictionary storage
- subscriber-editable translation packs
