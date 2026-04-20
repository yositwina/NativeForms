# TwinaForms Home Redesign Phase

Last updated: 2026-04-17

## Purpose

This document turns the current home-page discussion into a practical redesign phase for the Salesforce `Home` tab.

The goal is not a cosmetic refresh only.
The goal is to make `Home` feel like a real product homepage:

- clear
- trustworthy
- commercially aware
- not overloaded with technical setup language

It should answer four questions fast:

1. Is this org ready to use TwinaForms?
2. What plan is this org on?
3. What limits and features apply right now?
4. What should the customer do next?

---

## Core Product Decision

`Home` should be an **account / workspace overview page**, not another action hub.

TwinaForms already has clear tabs:

- `Home`
- `Designer`
- `Prefill`
- `Submit`
- `Themes`
- `Logs`
- `Connect`
- `Contacts`

So `Home` should not compete with those tabs by acting like a shortcut menu.

`Home` should focus on:

- workspace readiness
- plan visibility
- limits visibility
- included vs locked capabilities
- upgrade guidance

---

## Strong Design Rule

### Plan features and limits must not be hardcoded in Apex or LWC

This is now a redesign-phase requirement.

The current LWC contains hardcoded plan features in:

- [nativeFormsHome.js](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/lwc/nativeFormsHome/nativeFormsHome.js)

That should be treated as temporary and replaced.

### Correct source of truth

Plan definitions for the home page should come from the AWS `NativeFormsPlans` DynamoDB table, not from hardcoded frontend or Apex structures.

This matches the broader product direction already documented in:

- [admin_control_app_plan_and_subscription_model.md](/c:/Users/Yosi/NativeFormsAWS/AWS/documentation/admin_control_app_plan_and_subscription_model.md)

### Practical rule

For Home:

- Salesforce-owned data:
  - connection/setup state
  - demo/sample installation state
  - installed sample record counts
- AWS-owned data:
  - current plan
  - plan label
  - limits
  - feature flags
  - upgrade messaging inputs

If DynamoDB plan data is unavailable, the UI may use a fallback temporarily, but the redesign should treat fallback mode as an implementation contingency, not the desired product model.

---

## Problems In The Current Home Screen

The current screen is structurally clean, but it still behaves like a status report more than a product homepage.

### 1. Too much equal-weight information

Current sections:

- hero
- connection
- plan
- features
- getting started

They are arranged neatly, but they all feel equally important.
There is not enough visual or product hierarchy.

### 2. The page speaks too technically

Terms like:

- `Tenant Auth`
- `Client Credentials`
- `Encryption`

are useful for troubleshooting, but they are not the best top-level home-page language for most Salesforce admins.

### 3. Missing commercial and usage visibility

The biggest gap is the lack of a true `Usage & Limits` section.

The page currently does not clearly answer:

- how many forms are allowed
- how many forms are already used
- whether the customer is close to a limit

That weakens both onboarding and upgrade guidance.

### 4. Demo data is too prominent

The current `Getting Started` card gives demo/sample installation too much weight.
Demo data is useful, but once the customer is connected, it should be secondary.

### 5. Upgrade story is too weak

Current wording such as:

- `Not included`
- `Not included by plan`

is technically correct but poor product language.

The page should explain value, not just absence.

---

## Redesign Goal

The redesigned home page should feel like:

`Status + Plan + Limits + Upgrade`

not:

`Setup checklist + technical values + sample data`

---

## Recommended Information Architecture

## Section order

1. Hero / summary
2. Top summary cards
3. Included features
4. Upgrade / locked capabilities
5. Installation details

This order is intentional.

It starts with readiness and plan clarity, then explains product value, then moves lower-value technical/demo detail down the page.

---

## Redesigned Page Structure

## 1. Hero

### Purpose

Give one fast summary sentence and one clear primary action.

### Content

Left side:

- page title: `TwinaForms Home`
- short status sentence
- supporting sentence

Right side:

- connection status pill
- plan pill
- primary CTA

### Example states

If connection is complete:

- `Your TwinaForms workspace is connected and ready.`
- primary CTA: `Upgrade Plan`

If connection is incomplete:

- `Your TwinaForms workspace needs setup before live use.`
- primary CTA: `Continue Connect`

### Product rule

The hero CTA should be state-driven:

- incomplete setup -> `Continue Connect`
- complete setup on Free/Starter/Trial -> `Upgrade Plan`
- complete setup on Pro -> no upgrade CTA required; optional `View Plan Details`

---

## 2. Top Summary Cards

Replace the current two large table-style cards with three compact, high-signal cards.

### Card A: Connection Status

Purpose:

- confirm readiness
- show only the most useful setup facts
- link to `Connect` when relevant

Show:

- overall state: `Ready to use` or `Setup incomplete`
- setup state
- tenant auth state
- credentials state

Secondary action:

- `View connection details`

Important:

- keep this card operational, not sales-focused
- use friendly language first, technical details second

### Card B: Current Plan

Purpose:

- explain current plan simply
- frame the current plan in business language
- support upgrade intent

Show:

- plan label
- short description from plan data
- retention
- key included/locked signals

Primary action when applicable:

- `Upgrade Plan`

Important:

- do not lead with negative phrasing like `Not included`
- prefer `Upgrade to unlock detailed logs`

### Card C: Usage & Limits

Purpose:

- make limits visible
- support upgrade readiness
- explain current usage at a glance

Show:

- forms used / forms allowed
- themes installed / target
- optional additional org asset counts if useful

Most important metric:

- `Forms used / maxForms`

If close to limit:

- show a warning-style message such as:
  - `You are close to your current form limit.`

Important:

- this card is the biggest missing product signal in the current Home design

---

## 3. Included Features Section

This section should explain what the product in this org can do today.

### Purpose

- orient new customers
- reinforce value
- match the existing app tabs without duplicating them

### Pattern

Use feature tiles, not plain rows.

Examples:

- Core Form Builder
- Themes
- Prefill
- Submit Actions
- Submission Logs

Each tile should show:

- feature name
- one-line description
- status badge such as `Included`

### Product rule

Only show features that are genuinely customer-meaningful on Home.

Avoid stuffing this section with every internal feature flag in the plan table.

---

## 4. Upgrade / Locked Capabilities

This is a dedicated section, not a side effect of the plan card.

### Purpose

- turn Home into a gentle commercial surface
- explain why upgrading matters
- avoid making the page feel negative

### Suggested content

Examples:

- Detailed Logs
- More Published Forms
- Longer Retention
- Advanced Security
- Advanced Pro Features

Each tile should explain:

- what the capability is
- why it matters in production

Bottom action row:

- `Compare Plans`
- `Upgrade Plan`

### Product rule

This section should be visible only when it makes sense.

Recommended:

- show for `free`, `starter`, and `trial`
- hide or minimize for `pro`

---

## 5. Installation Details

This section should move lower on the page.

### Purpose

- show demo/sample readiness
- provide version visibility
- keep technical/sample detail available without dominating the page

Show:

- installed version
- demo data status
- themes count
- contacts count
- cases count
- sample forms count

### Copy rule

Do not make `Demo Data: Not installed` feel like an error.

Use helper text like:

- `Demo data is optional and intended for testing and product exploration.`

---

## State-Based UX Rules

The home page should not render the same emphasis for every org.

## State A: Setup incomplete

Prioritize:

- connection card first
- `Continue Connect` CTA
- reduced upgrade pressure until setup is complete

## State B: Setup complete, Starter or Free

Prioritize:

- plan clarity
- usage and limits
- upgrade section

## State C: Trial

Prioritize:

- time-sensitive value
- trial end date if available
- conversion guidance

## State D: Pro

Prioritize:

- readiness
- usage
- included value

Reduce:

- locked-feature upsell content

---

## Data Model For Home

The redesign should stop treating Home as a loose merge of unrelated values.
It should move toward one explicit Home view model.

## Recommended view model

```json
{
  "workspace": {
    "connectionReady": true,
    "setupState": "connected",
    "tenantAuthStatus": "verified",
    "credentialsStatus": "configured",
    "primaryAction": "upgrade"
  },
  "plan": {
    "planCode": "starter",
    "label": "Starter",
    "description": "Paid production plan without Pro-only features.",
    "storageMode": "dynamodb",
    "limits": {
      "maxForms": 5,
      "maxSubmissionsPerMonth": 1000,
      "submissionLogRetentionDays": 90
    },
    "featureFlags": {
      "enableDetailedSubmissionLogs": true,
      "enableProRepeatGroups": false,
      "enableProFormulaFields": false
    }
  },
  "usage": {
    "activeFormsCount": 0,
    "themesInstalled": 4,
    "themesTarget": 4,
    "contactsInstalled": 2,
    "contactsTarget": 2,
    "casesInstalled": 4,
    "casesTarget": 4,
    "sampleFormsInstalled": 0,
    "sampleFormsTarget": 2
  },
  "demo": {
    "installed": false,
    "version": "1.0"
  }
}
```

### Important rule

The plan block should come from AWS plan data, not from hardcoded frontend structures.

---

## Recommended Backend Direction

## Current reality

Today the home page pulls from:

- `NativeFormsDemoDataController.getHomeState()`
- `NativeFormsSetupController.getConnectionStatus()`
- `NativeFormsSubmissionLogsController.getSubmissionLogStatus()`

This works, but it is not enough for the redesigned page because:

- it does not provide a true plan object
- it does not provide a true limits object
- it pushes plan meaning into LWC logic

## Recommended redesign direction

Create a dedicated Home data contract that merges:

- Salesforce setup/demo state
- AWS plan definition
- AWS tenant usage/limits

### Preferred options

Option A:

- create a dedicated AWS endpoint for home/plan summary
- Apex calls that endpoint
- LWC receives one cleaner home DTO

Option B:

- extend an existing Apex controller to call AWS plan/admin data and compose a home DTO

### Recommendation

Prefer a dedicated home-summary contract over making the LWC assemble product meaning from multiple narrow endpoints.

---

## Implementation Requirement: Remove Hardcoded Plan Features

The redesign phase should explicitly remove or phase out:

- `PLAN_FEATURES` in [nativeFormsHome.js](/c:/Users/Yosi/NativeFormsAWS/force-app/main/default/lwc/nativeFormsHome/nativeFormsHome.js)

### Replace with

- plan labels, limits, descriptions, and feature flags sourced from `NativeFormsPlans`
- customer-facing feature tile mapping driven by plan/feature data, with presentation logic in one controlled place

### Important nuance

Not every raw DynamoDB feature flag should be shown directly on Home.

Recommended approach:

- DynamoDB remains the source of truth
- Apex or a dedicated Home service maps raw feature flags into a smaller customer-facing set of Home display items

Example:

- raw flags:
  - `enableProRepeatGroups`
  - `enableProFormulaFields`
  - `enableProLoadFile` (`File Uploads`)
- customer-facing home tile:
  - `Advanced Pro Features`

This keeps the UI understandable without losing the benefits of dynamic plan data.

---

## Content Guidelines

## Use this tone

- clear
- reassuring
- product-oriented
- commercially credible

## Avoid this tone

- raw infrastructure language
- internal engineering wording
- negative-only labels

### Better examples

Avoid:

- `Not included`
- `Not included by plan`
- `Not ready`

Prefer:

- `Upgrade to unlock`
- `Available on higher plans`
- `Setup still needs attention`

---

## Visual Guidelines

## Layout

- strong hero
- three-card top row
- feature tiles below
- lower-importance installation details at bottom

## Hierarchy

- primary CTA in hero
- one commercial section
- one operational section

## Avoid

- long stacked tables
- too many equal-size cards with similar visual weight
- making demo/sample content feel like the main job of the page

---

## Phase Breakdown

## Phase 1: Product and data alignment

- confirm final Home purpose
- define one Home view model
- align current plan source of truth to `NativeFormsPlans`
- decide which plan values are shown on Home
- define customer-facing copy for included and locked capabilities

## Phase 2: Backend contract

- add or extend AWS/Apex contract for home plan and limits data
- expose plan description, limits, and selected feature flags
- expose active forms usage count if available
- expose storage mode for diagnostics if needed

## Phase 3: LWC redesign

- rebuild page layout and hierarchy
- replace hardcoded plan feature logic
- add Usage & Limits card
- move installation/demo details lower
- add upgrade section

## Phase 4: QA and content polish

- verify all states:
  - setup incomplete
  - starter
  - trial
  - pro
- polish copy
- verify empty states
- verify mobile/tablet layout inside Salesforce shell

---

## Success Criteria

The redesign is successful when:

- a customer can understand readiness in under 10 seconds
- a Starter customer can understand limits without opening another tab
- the page explains current plan value clearly
- upgrade messaging feels intentional, not pushy
- demo/sample content no longer dominates the page
- Home no longer depends on hardcoded plan features in the LWC

---

## Final Recommendation

The redesign should not be framed as:

- `make Home prettier`

It should be framed as:

- `make Home the product overview surface for setup, plan, limits, and upgrade readiness`

Most important implementation decision:

- plan and feature content on Home should come from the `NativeFormsPlans` DynamoDB model, not from hardcoded Apex/LWC logic

That keeps Home aligned with the broader NativeForms commercial architecture and prevents the UI from drifting away from the real plan model.
