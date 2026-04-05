# Salesforce Object Fields V1

## 1. `NF_Form__c`

### Purpose
Stable business identity of the form across all versions.

### Recommended fields
- `Name`
  User-facing form name

- `NF_Key__c`
  Unique internal/business key for the form

- `Status__c`
  High-level form lifecycle
  Suggested values:
  - Draft
  - Active
  - Archived

- `Current_Draft_Version__c`
  Lookup to `NF_Form_Version__c`

- `Current_Published_Version__c`
  Lookup to `NF_Form_Version__c`

- `Description__c`
  Admin description / internal notes

- `Category__c`
  Optional grouping field

- `Owner__c`
  Optional business owner field if you want something separate from Salesforce record owner

### Notes
- `NF_Form__c` should stay small and stable.
- Avoid storing compiled HTML or compiled AWS payload here.
- This object is mainly for identity, ownership, and “which version is current.”

## 2. `NF_Form_Version__c`

### Purpose
Versioned snapshot of the form design and publishable unit for AWS.

### Recommended fields
- `Name`
  Display label for the version
  Example: `Problem Report v3`

- `Form__c`
  Master-detail or lookup to `NF_Form__c`

- `Version_Number__c`
  Numeric version index

- `Version_Status__c`
  Suggested values:
  - Draft
  - Published
  - Archived

- `Form_Id__c`
  The AWS/public form id used by the HTML and Lambda

- `Publish_Token__c`
  Long-lived per-form publish token
  This should be protected and not broadly visible

- `Security_Mode__c`
  Suggested values:
  - public-create
  - public-prefill
  - secure-edit

- `Rate_Limit_Profile__c`
  Placeholder for future AWS-side rate limit strategy

- `Theme_JSON__c`
  Theme/settings source for HTML generation

- `Custom_CSS__c`
  Optional custom CSS source

- `Custom_JS__c`
  Optional custom JS source

- `UI_Settings_JSON__c`
  Optional UI-level settings bundle if you want them separate from theme

- `Prefill_Params_JSON__c`
  Optional storage for lightweight client-side prefill param mapping

- `Publish_Status__c`
  Suggested values:
  - Never Published
  - Publish Pending
  - Published
  - Publish Failed
  - Unpublished

- `Last_Published_At__c`
  Datetime

- `Last_Published_By__c`
  Lookup to User or text reference

- `Last_Publish_Error__c`
  Last publish failure summary

### Notes
- `NF_Form_Version__c` is the main publish unit.
- This object can carry the version-level settings needed to compile:
  - HTML
  - DynamoDB registration payload
- Child records hold the detailed shape:
  - `NF_Form_Element__c`
  - `NF_Form_Action__c`
- Do not use this object as a free-form text dump of the final generated HTML unless it is admin-only and purely for diagnostics.

## Suggested Relationship Choice
- `NF_Form__c` -> `NF_Form_Version__c`
  I recommend **master-detail** if you want versions tightly owned by the parent form.

## Next Objects
## 3. `NF_Form_Element__c`

### Purpose
Stores the UI/layout elements that belong to one form version.

### Recommended fields
- `Name`
  Human-readable label for the element record

- `Form_Version__c`
  Master-detail or lookup to `NF_Form_Version__c`

- `Element_Id__c`
  Stable runtime element id used in generated HTML

- `Element_Type__c`
  Suggested values:
  - heading
  - text
  - input
  - textarea
  - select
  - checkbox
  - radio
  - image
  - section
  - columns
  - hidden
  - repeatGroup

- `Order__c`
  Render order within the version

- `Parent_Element_Id__c`
  Optional parent reference key for nested future layouts

- `Field_Key__c`
  Runtime input key such as `email`, `contactId`, `existingCases`

- `Label__c`
  Main label text

- `Config_JSON__c`
  Element-specific settings
  Example uses:
  - placeholder
  - required
  - rows
  - readOnly
  - options
  - image source and alt text
  - section title and description
  - column definitions
  - visibility rules
  - repeat-group field config
  - column metadata

### Notes
- This object should model the source UI structure, not generated HTML.
- `Config_JSON__c` keeps the model flexible while still letting you use structured fields for the most important dimensions.
- For repeat groups, you can either:
  - store child columns as additional `NF_Form_Element__c` records later
  - or keep repeat-group field definitions inside `Config_JSON__c` for V1

## 4. `NF_Form_Action__c`

### Purpose
Stores the server-side actions that are compiled into the DynamoDB form definition.

### Recommended fields
- `Name`
  Human-readable action name

- `Form_Version__c`
  Master-detail or lookup to `NF_Form_Version__c`

- `Action_Scope__c`
  Suggested values:
  - Prefill
  - Submit

- `Order__c`
  Execution order within its scope

- `Command_Key__c`
  Stable command key used in runtime results/logs

- `Command_Type__c`
  Suggested values:
  - findOne
  - getById
  - findMany
  - create
  - update
  - delete
  - upsertMany

- `Object_Api_Name__c`
  Salesforce object targeted by the action

- `Store_Result_As__c`
  Optional runtime result alias

- `Config_JSON__c`
  Command-specific configuration
  Example uses:
  - `where`
  - `fieldsToReturn`
  - `orderBy`
  - `limit`
  - `fields`
  - `rows`
  - `idField`
  - `relationshipField`
  - `relationshipValue`
  - `deleteIds`
  - `runIf`

### Notes
- This is the key source object for compiled AWS behavior.
- At publish time, Salesforce should transform `NF_Form_Action__c` records into:
  - `prefillDefinition.commands`
  - `submitDefinition.commands`
- This object replaces the need to let HTML send commands at runtime.

## 5. `NF_Form_Publication__c`

### Purpose
Stores operational publication history for a version.

### Recommended fields
- `Name`
  Publication record label

- `Form__c`
  Lookup to `NF_Form__c`

- `Form_Version__c`
  Lookup to `NF_Form_Version__c`

- `Publication_Type__c`
  Suggested values:
  - Publish
  - Republish
  - Unpublish
  - Register Only

- `Publication_Status__c`
  Suggested values:
  - Pending
  - Success
  - Failed

- `Published_At__c`
  Datetime

- `Published_By__c`
  Lookup to User or equivalent reference

- `AWS_Response_JSON__c`
  Optional admin-only stored response from registration/publish process

- `Generated_HTML_Ref__c`
  Optional reference to where the generated HTML was saved
  Example: S3 path or document reference

- `Published_Form_Id__c`
  The form id used for that publication

- `Error_Message__c`
  Summary of the failure if publish failed

### Notes
- `NF_Form_Publication__c` is not the design source of truth.
- It is an operations/history object.
- If you store generated payloads or HTML references here, keep them admin-restricted.
- This object is where rollback/debugging information should live, not on the builder objects.

## Summary
The full recommended V1 object model is:
1. `NF_Form__c`
2. `NF_Form_Version__c`
3. `NF_Form_Element__c`
4. `NF_Form_Action__c`
5. `NF_Form_Publication__c`
