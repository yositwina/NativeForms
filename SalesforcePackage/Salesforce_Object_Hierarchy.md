# Salesforce Object Hierarchy

## Goal
Define the core Salesforce package object structure for NativeForms before field-level design.

## Recommended V1 Objects
- `NF_Form__c`
- `NF_Form_Version__c`
- `NF_Form_Element__c`
- `NF_Form_Action__c`
- `NF_Form_Publication__c`

## Hierarchy Diagram
```text
NF_Form__c
|
+-- NF_Form_Version__c
    |
    +-- NF_Form_Element__c
    |
    +-- NF_Form_Action__c
    |
    +-- NF_Form_Publication__c
```

## Relationship Meaning

### `NF_Form__c`
The stable business identity of a form.

One record represents the form itself across time.

### `NF_Form_Version__c`
A versioned snapshot of the form design.

Each form can have:
- one or more draft versions
- one currently published version
- archived historical versions

### `NF_Form_Element__c`
The UI/layout elements that belong to one specific form version.

Examples:
- heading
- image
- input
- select
- checkbox
- radio
- textarea
- section
- columns
- hidden field
- repeat group

### `NF_Form_Action__c`
The server-side executable actions for one specific form version.

This covers both:
- prefill actions
- submit actions

These actions are later compiled into the DynamoDB registration payload.

### `NF_Form_Publication__c`
Operational publication history for one specific form version.

This is not the design source of truth.
It is meant for:
- publish/unpublish history
- AWS registration tracking
- S3/HTML publish tracking
- admin/debug visibility

## Source Of Truth
The source of truth should remain:
- form
- version
- elements
- actions

Generated outputs such as:
- final HTML
- DynamoDB payload

should be treated as compiled artifacts, not primary editable design records.

## Design Notes
- `NF_Form_Security__c` is not recommended for V1.
- Security settings should live with the version/publication model and compile into the AWS registration payload.
- The browser should never be the source of truth for executable commands.

## Next Step
Define fields for each object, starting with:
1. `NF_Form__c`
2. `NF_Form_Version__c`
3. `NF_Form_Element__c`
4. `NF_Form_Action__c`
5. `NF_Form_Publication__c`
