# Project-Based Form Organization V1

## Decision
NativeForms will organize forms with a first-class `Project` layer above `Form`.

Hierarchy:
- Project
- Form
- Version

Customer-facing name:
- `Project`

This V1 replaces the idea of folders/tags for primary form organization. `Category` remains a separate descriptive field and is not reused as the main organization model.

## UX Rules
- The Designer header should show `Project` before `Form`.
- Admins first choose a project, then work with forms inside that project.
- The current `+ New Form` action remains the main entry point for creating both forms and projects.
- Creating a project should happen inline inside the `+ New Form` modal.
- The modal should ask for:
  - Form Name
  - Project
- The Project picker should include existing projects plus `+ Create New Project`.
- Choosing `+ Create New Project` should reveal an inline `Project Name` input and create the project inside the same flow.
- If a project has no forms, the Designer should show a clean empty state and keep `+ New Form` as the main call to action.

## Salesforce Packaging Rules
- Use a real custom object: `NF_Project__c`.
- Add a lookup from `NF_Form__c` to `NF_Project__c`.
- If a new object is added, package it with:
  - custom tab
  - page layout
  - search layout support
  - `TwinaForms Admin` permission-set access
  - `TwinaForms Admin` app tab entry
- Keep the main `TwinaForms` app unchanged in V1 to avoid nav clutter.

## Upgrade Rules
- Existing forms must be automatically assigned to a default `General` project.
- System projects `General` and `Archive` must be created idempotently if missing.
- Backfill should only touch forms whose project is blank.
- The normalization path should run from the Salesforce Designer workspace flow so both clean installs and upgrades converge safely.

## Object Rules
- `NF_Project__c.Name` is the human-readable project name.
- Add optional `Description__c` for admin context.
- Project names must be unique case-insensitively after trim.
- A project with assigned forms cannot be deleted until forms are reassigned.

## Non-Goals For V1
- No nested projects
- No tags
- No project-level theme/language defaults
- No AWS/runtime contract changes
- No public-form behavior changes
