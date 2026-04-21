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

## Careful Implementation Rules
- Implement this in small deployable slices, not as one large publisher rewrite.
- Keep English fallback active the whole time so partially migrated forms never render blank labels/messages.
- Do not migrate low-value decorative text if removing it is cleaner.
- Avoid changing AWS runtime contracts for V1 unless a customer-facing multilingual gap cannot be solved in Salesforce publish output.
- Keep all base dictionaries inside the Salesforce package for V1.
- Republish only test forms first after each slice; do not assume older published forms pick up changes automatically.
- Pause for manual testing after the high-risk slices: basic runtime text, validation text, file upload, and secret code.
- When a string is already per-form configurable, do not duplicate it into the packaged dictionary unless it is needed as a fallback.

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

Rule for V1:
- if these fields are blank or still match a packaged default from another language, the runtime should resolve them to the current form language instead of keeping stale English text

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

## Current V1 Boundary
### What we will translate in V1
- customer-facing runtime action/status text
- visible validation text
- runtime labels that appear during normal form use
- file-upload public flow text
- repeat-group public action text
- result-panel titles
- date hints/placeholders tied to locale

### What can remain English in V1
- deep technical/debug detail blocks
- low-level internal configuration failures
- backend exception detail returned only for troubleshooting

### What we should remove instead of translate
- decorative secret-code badge/title/helper text
- extra helper headlines for file upload when the field label already explains the action
- generic seeded English filler values such as `Enter text`, `Enter longer text`, `Enter number`, `name@example.com`, `Phone number`, and `https://example.com`

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

Salesforce-backed option labels:
- picklist option labels should come from Salesforce translations, not from the packaged runtime dictionary
- for Salesforce-backed picklists, the published form should show the translated option labels defined in Salesforce for the selected language
- packaged dictionaries should only own generic wrapper text around picklists, such as the empty `Select...` placeholder
- `Radio Group` should use the same Salesforce-backed picklist source model as `Picklist`; the difference is presentation only
- `Radio Group` option labels should therefore also come from Salesforce translations, not from packaged runtime text or a separate free-text option editor

### Required fields
No translation work needed for the `*` marker itself.

### Date validation
Dictionary:
- invalid date format
- min date validation
- max date validation

Locale-aware:
- date format hint and placeholder text

### Generic input placeholders and seeded values
- generic text-like fields should not use seeded `defaultValue` sample content in V1
- relevant text-like fields should use localized placeholder defaults instead of seeded sample values
- legacy seeded English sample defaults should be treated as placeholder candidates in the current form language unless the admin explicitly changes them to real content
- date fields remain the exception because a locale-aware date hint/placeholder is useful

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

## Implementation Sequence With File-Level Scope
### Phase 0. Baseline inventory and key freeze
Objective:
- create a stable, implementation-ready string/key inventory before code migration begins

Files to inspect:
- [NativeFormsPublisher.cls](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/classes/NativeFormsPublisher.cls)
- [nativeFormsDesigner.js](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/lwc/nativeFormsDesigner/nativeFormsDesigner.js)
- [nativeFormsDesigner.html](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/lwc/nativeFormsDesigner/nativeFormsDesigner.html)
- [NativeFormsDesignerController.cls](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/classes/NativeFormsDesignerController.cls)

Concrete tasks:
- inventory all customer-facing runtime strings
- assign each one to:
  - dictionary
  - per-form configurable
  - remove
  - English technical fallback
- freeze the first V1 dictionary key set before implementation begins

Output:
- key list added to this doc or a sibling appendix

User testing gate:
- no manual testing needed yet

### Phase 1. Language plumbing in Salesforce
Objective:
- let each form version choose a language without changing runtime behavior yet

Primary files:
- [NativeFormsDesignerController.cls](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/classes/NativeFormsDesignerController.cls)
- [nativeFormsDesigner.js](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/lwc/nativeFormsDesigner/nativeFormsDesigner.js)
- [nativeFormsDesigner.html](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/lwc/nativeFormsDesigner/nativeFormsDesigner.html)

Concrete tasks:
- add `languageCode` to version UI settings
- expose `selectedVersionLanguageCode` in workspace payload
- add a `Language` control in Form Settings
- default new/old forms to `en`
- preserve existing forms by treating missing `languageCode` as `en`

Definition of done:
- admins can pick `English`, `Hebrew`, or `Spanish`
- no runtime text changes yet
- old forms still load without migration scripts

User testing gate:
- optional quick check in designer only

### Phase 2. Package-owned dictionary provider
Objective:
- centralize all reusable runtime text in one Apex-owned provider

Primary files:
- new [NativeFormsRuntimeI18n.cls](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/classes/NativeFormsRuntimeI18n.cls)
- possibly supporting test/helper class later

Concrete tasks:
- implement language normalization: `en`, `he`, `es`
- implement English fallback
- implement dictionary maps for V1 keys
- add date placeholder/validation helper methods tied to locale and format
- keep key names stable and human-readable

Recommended structure:
- one top-level method to return the resolved dictionary map for a given language
- helper methods for date messages so publisher logic stays clean

Definition of done:
- one class returns resolved runtime text for all V1 keys
- Hebrew and English complete
- Spanish scaffold present, even if lightly reviewed

User testing gate:
- no manual testing yet

### Phase 3. Publisher config injection
Objective:
- publish `languageCode` and resolved `runtimeText` into the generated form config

Primary files:
- [NativeFormsPublisher.cls](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/classes/NativeFormsPublisher.cls)

Concrete tasks:
- load selected `languageCode` from UI settings
- call `NativeFormsRuntimeI18n`
- embed:
  - `languageCode`
  - `runtimeText`
into `window.NativeFormsConfig`
- keep existing per-form configured values untouched
- ensure missing keys still fall back cleanly

Definition of done:
- published HTML contains `languageCode` and `runtimeText`
- English forms render exactly as before
- Hebrew forms still behave normally even before all text is migrated

User testing gate:
- yes
- ask for a quick HTML/runtime smoke test on one simple form after this phase

### Phase 4. Migrate low-risk runtime text first
Objective:
- migrate the most visible but lowest-risk hardcoded strings first

Primary files:
- [NativeFormsPublisher.cls](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/classes/NativeFormsPublisher.cls)

Concrete tasks:
- replace hardcoded text for:
  - `Submitting...`
  - result panel titles
  - picklist `Select...`
  - repeat-group `Add Row`
  - post-submit countdown text
- keep technical detail blocks unchanged in English

Definition of done:
- these strings render from `runtimeText`
- English output is unchanged in meaning
- Hebrew shows translated values for these items

User testing gate:
- yes
- this is the first meaningful public-form language check

### Phase 5. Validation and locale text migration
Objective:
- move customer-facing validation strings out of hardcoded English

Primary files:
- [NativeFormsPublisher.cls](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/classes/NativeFormsPublisher.cls)
- [NativeFormsRuntimeI18n.cls](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/classes/NativeFormsRuntimeI18n.cls)

Concrete tasks:
- migrate:
  - date invalid/min/max messages
  - review-date-fields prompt
  - CAPTCHA-required message
  - secret-code-required-before-submit
  - upload required/waiting/review prompts
- move date placeholders/hints to locale-aware helpers
- keep technical submit-debug details in English

Definition of done:
- standard validation messages respect `languageCode`
- Hebrew forms no longer show English validation in the covered flows

User testing gate:
- yes
- this is a required manual checkpoint because validation quality is customer-visible

### Phase 6. File-upload multilingual slice
Objective:
- finish multilingual-safe file-upload UI and messaging

Primary files:
- [NativeFormsPublisher.cls](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/classes/NativeFormsPublisher.cls)
- [NativeFormsRuntimeI18n.cls](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/classes/NativeFormsRuntimeI18n.cls)
- optionally [nativeFormsDesigner.html](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/lwc/nativeFormsDesigner/nativeFormsDesigner.html) and [nativeFormsDesigner.js](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/lwc/nativeFormsDesigner/nativeFormsDesigner.js) for preview parity

Concrete tasks:
- migrate:
  - browse single/multiple
  - remove single/multiple
  - uploading
  - ready
  - uploaded fallback file name
  - upload wait/required/review prompts
  - allowed/max-size/multiple-files meta text
- keep upload surface minimal
- do not reintroduce unnecessary helper headlines

Definition of done:
- upload flow is language-safe in public runtime
- upload meta text and statuses respect `languageCode`

User testing gate:
- yes, required
- this should be tested on the working public upload form before continuing

### Phase 7. Secret-code multilingual slice
Objective:
- complete the multilingual secret-code flow cleanly

Primary files:
- [NativeFormsPublisher.cls](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/classes/NativeFormsPublisher.cls)
- [NativeFormsDesignerController.cls](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/classes/NativeFormsDesignerController.cls)
- [nativeFormsDesigner.js](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/lwc/nativeFormsDesigner/nativeFormsDesigner.js)
- [nativeFormsDesigner.html](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/lwc/nativeFormsDesigner/nativeFormsDesigner.html)

Concrete tasks:
- ensure public runtime uses:
  - configurable intro/sent/invalid/verified messages
  - configurable send/verify/resend button labels
- remove any remaining unnecessary fixed English secret-code labels/placeholders
- move remaining generic secret-code validation prompts into `runtimeText`
- keep designer preview aligned with the runtime structure

Definition of done:
- secret-code flow contains no decorative fixed English copy
- public secret-code actions are multilingual-safe
- per-form overrides still work

User testing gate:
- yes, required
- this is the other major customer-facing flow that should be validated manually

### Phase 8. Hebrew QA and RTL correction
Objective:
- confirm that translation plus directionality feels production-safe

Primary files:
- [NativeFormsPublisher.cls](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/classes/NativeFormsPublisher.cls)
- [nativeFormsDesigner.css](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/lwc/nativeFormsDesigner/nativeFormsDesigner.css)
- any touched layout files from earlier phases

Concrete tasks:
- verify:
  - text alignment
  - button alignment
  - label placement left/right/above/none
  - file upload
  - secret code
  - repeat groups
  - result panels
  - validation messages
- fix only actual layout/readability issues found in Hebrew

Definition of done:
- Hebrew feels intentionally supported, not merely translated

User testing gate:
- yes, required
- this is the main user approval checkpoint before calling V1 complete

### Phase 9. Spanish scaffold pass
Objective:
- leave the system ready for a third language without blocking V1 on perfect Spanish QA

Primary files:
- [NativeFormsRuntimeI18n.cls](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/classes/NativeFormsRuntimeI18n.cls)

Concrete tasks:
- populate Spanish keys
- verify no missing-key crashes
- keep English fallback for anything intentionally deferred

Definition of done:
- `es` is selectable
- forms publish safely with Spanish selected

User testing gate:
- optional unless Spanish becomes launch-critical

## Manual Testing Gates Where I Should Ask You
I should explicitly pause and ask for your testing after these slices:
1. After Phase 3
Reason:
- confirm published config and simple runtime rendering are stable

2. After Phase 5
Reason:
- validation text quality must be checked by a human in the real form flow

3. After Phase 6
Reason:
- file upload is a working flow already and multilingual changes should not break it

4. After Phase 7
Reason:
- secret code is sensitive and should be checked in the browser, not only by code review

5. After Phase 8
Reason:
- Hebrew/RTL polish is primarily a visual/UX judgment call

## Suggested Test Forms During Implementation
Use a small fixed set of forms during implementation:
- one simple contact form with no advanced features
- one repeat-group form
- one file-upload form
- one secret-code-protected form

Do not use too many forms during the build. Reuse the same forms for faster regression checking.

## Automated Checks Per Slice
Before asking for manual testing, do:
- Salesforce deploy compile check or direct deploy
- republish only the targeted test form
- verify generated HTML includes the expected `languageCode` and `runtimeText` keys
- smoke-check that English fallback still renders

## Risks and Protections
### Risk: publisher regression from large string rewrites
Protection:
- migrate by area, not all at once
- keep English fallback alive at every phase

### Risk: mixed ownership between dictionary and form settings
Protection:
- keep a strict split:
  - business copy = form settings
  - reusable generic UI text = dictionary

### Risk: Hebrew translation without RTL polish
Protection:
- require explicit RTL QA phase before calling V1 done

### Risk: older published forms not updating
Protection:
- document that republish is required
- use dedicated test forms after each slice

### Risk: over-translating technical/debug text
Protection:
- keep low-level technical details English in V1
- translate only customer-facing validation/runtime text

## Release Readiness Checklist
- `languageCode` exists in Form Settings
- English fallback works on older forms
- published config includes resolved `runtimeText`
- high-visibility runtime strings migrated
- validation strings migrated
- file-upload flow migrated
- secret-code flow migrated
- Hebrew manual QA completed
- Spanish scaffold present
- doc updated with final key list and any deliberate English fallbacks

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
