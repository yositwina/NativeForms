# Salesforce Publish Flow V1

## Goal
Define the end-to-end publish flow from Salesforce design records into:
- DynamoDB form registration on AWS
- generated HTML for the public form

## Source Of Truth
The source of truth remains in Salesforce:
- `NF_Form__c`
- `NF_Form_Version__c`
- `NF_Form_Element__c`
- `NF_Form_Action__c`

Generated outputs are compiled artifacts:
- AWS registration payload
- generated HTML

## High-Level Flow
```text
Builder User edits form in Salesforce
        |
        v
Salesforce saves form/version/elements/actions
        |
        v
User clicks Publish
        |
        v
Salesforce validates the version
        |
        v
Salesforce compiles:
- UI HTML / FORM_DEF
- DynamoDB registration payload
        |
        v
Salesforce sends registration payload to AWS
        |
        v
AWS stores / updates form record in DynamoDB
        |
        v
Salesforce stores or publishes generated HTML
        |
        v
Salesforce marks version as Published
        |
        v
Publication record is saved for audit/history
```

## Recommended Publish Steps

### 1. User edits the form
Builder user edits:
- form metadata
- version settings
- UI elements
- prefill actions
- submit actions

The version remains in `Draft`.

### 2. User clicks Publish
Salesforce starts a publish process for one `NF_Form_Version__c`.

### 3. Salesforce validates the version
Before publishing, validate:
- required top-level form/version settings exist
- element ordering is valid
- element ids and keys are valid
- action ordering is valid
- required command settings exist
- action object/field usage is internally consistent
- security mode is chosen

If validation fails:
- do not publish
- save error summary

### 4. Salesforce generates or confirms stable ids
For the version being published:
- ensure `Form_Id__c` exists
- ensure `Publish_Token__c` exists

Recommended rule:
- `Form_Id__c` stays stable for a published form identity
- `Publish_Token__c` may rotate on republish if you want stronger control

### 5. Salesforce compiles the AWS registration payload
From the version and child records, Salesforce builds:
- `prefillPolicy`
- `submitPolicy`
- `prefillDefinition`
- `submitDefinition`

This is the payload sent to:
- `POST /forms/register`

### 6. Salesforce compiles the browser artifact
Salesforce generates the public HTML artifact.

That artifact should contain only:
- `formId`
- `publishToken`
- UI/runtime config
- layout/theme/settings
- custom CSS / JS if enabled

The artifact should not contain:
- executable submit commands
- executable prefill commands
- response mapping for AWS execution

### 7. Salesforce sends the registration payload to AWS
Salesforce calls the AWS backend registration endpoint.

Expected AWS result:
- DynamoDB record created or updated
- hashed token stored
- server-side definitions stored

If AWS registration fails:
- publish should be treated as failed
- version should not be marked fully published

### 8. Salesforce stores/publishes the HTML
After successful registration:
- save generated HTML to the chosen public hosting target
- or save it to a staging target first, then switch live

### 9. Salesforce updates publication state
After successful AWS registration and HTML publish:
- mark version as `Published`
- update `NF_Form__c.Current_Published_Version__c`
- update publish timestamps
- create `NF_Form_Publication__c`

### 10. Salesforce records publication history
Create one `NF_Form_Publication__c` row with:
- form
- version
- status
- publish date
- publisher
- optional AWS response
- optional generated HTML reference

## Recommended Failure Rules

### If validation fails
- stop immediately
- no AWS call
- no HTML publish

### If AWS registration fails
- do not mark version published
- do not switch live HTML
- create failed publication log

### If HTML publish fails after AWS registration succeeds
- mark publication failed or partial
- keep detailed publication log
- optionally retry HTML publish

## Recommended Versioning Rules

### Draft editing
- always edit a draft version
- do not edit the live published version directly

### Publish behavior
Two valid options:

#### Option A: Same version becomes published
- simpler
- good for V1

#### Option B: Immutable published version
- draft is cloned to a new published snapshot
- better long-term audit model

Recommendation for V1:
- start with Option A

## Recommended Unpublish Behavior
Unpublish should:
- mark the version as no longer live
- update `NF_Form__c.Current_Published_Version__c`
- optionally remove or disable the public HTML endpoint
- optionally deactivate the DynamoDB form record

Recommended AWS-side behavior:
- set DynamoDB status to something like `unpublished`
- Lambdas reject requests for unpublished forms

## Security Notes
- Browser should never send commands for execution
- Salesforce should compile commands into the AWS registration payload
- AWS should remain the execution authority
- publication snapshots, if stored, should be admin-restricted

## Recommendation For V1
Implement the publish flow as:
1. validate
2. compile registration payload
3. register/update AWS
4. generate/publish HTML
5. update Salesforce publication state
6. write publication log

## Next Step
Define builder V1 scope:
- supported element types
- supported command types
- what admins can customize
- what is deferred
