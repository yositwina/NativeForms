# TwinaForms Agentforce Action V1

Last updated: 2026-07-23

## Decision

TwinaForms embeds Agentforce through one initial custom action:

- action label: `Create TwinaForms Form from Page Layout`
- Apex class: `NativeFormsAgentforceActions`
- method: `createFormFromPageLayout`
- implementation style: Apex `@InvocableMethod`

This action is the first Agentforce integration for ISV technical overview purposes. It creates a draft TwinaForms form from a Salesforce object page layout and returns the form/version ids plus a Designer tab URL for human review before publishing.

## User Story

An admin can ask Agentforce:

> Create a TwinaForms form from the Contact layout.

If TwinaForms finds exactly one layout for the object, the action creates the draft form. If more than one layout is available, the action returns layout choices and asks Agentforce to have the user choose one. Agentforce then calls the same action again with the selected layout key.

## Scope

V1 creates a draft only. It does not publish automatically.

Default behavior:

- source object comes from the prompt, for example `Contact`
- page-layout source is selected by layout key or label when needed
- language defaults to `en`
- import mode defaults to `secureUpdateOrCreate`
- project defaults to the normal TwinaForms `General` project unless a project id or new project name is supplied

## ISV Technical Overview Wording

TwinaForms embeds Agentforce through a custom Agentforce action exposed by Apex. The initial action, `Create TwinaForms Form from Page Layout`, lets Agentforce create a draft TwinaForms form from a Salesforce object page layout. If several layouts are available for the selected object, the action returns layout choices for the user to select before creation. The action returns the draft form id, version id, and Designer URL for admin review before publishing, keeping final publication under human control.

## Packaging Note

The action is implemented as an Apex invocable action in the package source. If Salesforce requires Agentforce metadata that creates a hard dependency on Agentforce licensing, package those Agentforce-specific metadata components in a separate TwinaForms Agentforce extension package while keeping this Apex action available in the core package.
