# NativeForms Apex Test Strategy V1

Last updated: 2026-04-21

## Purpose

Define the Apex test approach for the current Starter package baseline before implementation begins.

This strategy is meant to keep test work:

- package-safe
- fast enough to maintain
- meaningful for real product behavior
- strict enough for release confidence without chasing vanity coverage

## Current Baseline

- Production Apex classes: `20`
- Existing Apex test classes: `0`
- Current product state: broad feature surface is implemented enough to begin formal Apex test planning

## Coverage Target

Target overall Apex coverage:

- `80-85%`

Rules:

- do not optimize for only `75%`
- do not chase `100%`
- do not intentionally push even critical classes beyond `85%` just to raise numbers
- prioritize meaningful behavioral coverage over line-count padding

## Core Testing Principles

1. Use a shared fixture factory, not the real demo installer
- Tests should not depend on full demo-data installation logic as their base.
- Demo-style scenarios are useful, but fixture setup must stay smaller, deterministic, and faster.

2. Reuse small stable building blocks
- One reusable form/project/theme/contact fixture should support many tests.
- One reusable AWS mock layer should support many controllers.

3. Group tests by area, not one test class per production class
- The goal is maintainable coverage, not a one-to-one class map.

4. Test behavior, not generated markup details line by line
- For heavy classes like `NativeFormsPublisher`, assert important compiled outputs and contracts, not every string fragment.

5. Keep test data explicit and human-readable
- JSON-heavy configuration should come from helper builders, not copied raw strings everywhere.

## Shared Test Foundation

### 1. Salesforce fixture factory

Create one shared test factory, for example:

- `NativeFormsTestDataFactory`

Responsibilities:

- create one `NF_Project__c`
- create two forms under that project
- create one simple draft version
- create one richer draft/published-style version
- create one theme when needed
- create a few Contacts
- create a few child records such as Cases for records-list scenarios
- create a few form elements reused across tests
- create basic prefill/submit action records when needed

Recommended baseline fixture shapes:

- `Simple Contact Form`
  - text
  - email
  - checkbox
  - one submit action

- `Advanced Demo-Like Form`
  - sections/groups
  - picklist / radio
  - checkbox
  - file upload field
  - formula field
  - records list
  - prefill action
  - submit actions

### 2. Config JSON helper

Create one config helper, for example:

- `NativeFormsTestConfigFactory`

Responsibilities:

- build `Config_JSON__c` for elements
- build `UI_Settings_JSON__c` for versions
- build submit action config JSON
- build prefill action config JSON
- produce minimal, valid JSON for each supported scenario

Reason:

- NativeForms behavior depends heavily on config JSON
- tests will become brittle very quickly without builders

### 3. AWS callout mocks

Create one reusable mock layer, for example:

- `NativeFormsAwsMockFactory`

Responsibilities:

- return `HttpCalloutMock` implementations for:
  - bootstrap/setup success
  - bootstrap/setup failure
  - home/admin overview success
  - entitlement/limit success
  - tenant support-flag variants
  - generic AWS failure cases

Recommended response variants:

- healthy connected tenant
- tenant with user limits
- tenant with admin app closed
- setup/bootstrap denied
- runtime/API error payloads

### 4. Shared user contexts

Create a small user helper or fixtures for:

- admin-like user
- normal TwinaForms user
- optional support/debug user if needed

This is especially useful for:

- setup/connect/home tests
- permission-set-sensitive controller behavior

## Proposed Test Class Structure

Recommended test suite size:

- about `7-10` Apex test classes

Do not start with `20` one-to-one test classes.

### Group 1: Core services

- `NativeFormsCoreServicesTest`

Cover:

- `NativeFormsFormKeyService`
- `NativeFormsRuntimeI18n`
- `NativeFormsFeatureFlags`
- `NativeFormsTenantEntitlements`
- `NativeFormsProjectService`
- `NativeFormsFormulaExprEval`

### Group 2: Designer and builder behavior

- `NativeFormsDesignerBuilderTest`

Cover:

- `NativeFormsDesignerController`
- `NativeFormsBuilderController`

Focus:

- workspace loading
- element updates
- config persistence
- project defaulting
- formula save rules
- records-list restrictions

### Group 3: Prefill and submit actions

- `NativeFormsActionControllersTest`

Cover:

- `NativeFormsPrefillActionsController`
- `NativeFormsSubmitActionsController`

Focus:

- workspace/action options
- config save behavior
- repeat/records-list action constraints

### Group 4: Setup, home, and admin AWS-backed controllers

- `NativeFormsAwsControllersTest`

Cover:

- `NativeFormsAwsClient`
- `NativeFormsSetupController`
- `NativeFormsHomeController`
- `NativeFormsAdminController`
- `NativeFormsSecretCodeApi`

Focus:

- callout handling
- tenant limits
- support flags
- permission-set/access summaries
- customer-safe failure behavior

### Group 5: Publishing

- `NativeFormsPublisherTest`

Cover:

- `NativeFormsPublisher`

Focus:

- HTML generation succeeds
- important runtime text/config included
- formula metadata emitted
- multilingual/runtime dictionary inclusion
- records-list and radio/picklist source behavior

### Group 6: Demo and starter seed behavior

- `NativeFormsDemoDataTest`

Cover:

- `NativeFormsDemoDataController`
- `NativeFormsDemoDataService`

Focus:

- expected records are created
- starter demo shape stays valid
- project/form/version defaults are sane

### Group 7: Themes and logs

- `NativeFormsThemeAndLogsTest`

Cover:

- `NativeFormsThemesController`
- `NativeFormsSubmissionLogsController`

Focus:

- theme retrieval/update behavior
- log normalization and response shaping

## Implementation Order

### Phase 1: Shared test foundation

Build first:

- `NativeFormsTestDataFactory`
- `NativeFormsTestConfigFactory`
- `NativeFormsAwsMockFactory`

Optional:

- small assertion/helper utility if repetition becomes noisy

### Phase 2: Low-risk core service tests

Start with:

- `NativeFormsCoreServicesTest`

Reason:

- fastest path to stable early coverage
- lowest setup friction

### Phase 3: Controller tests without AWS complexity

Next:

- `NativeFormsDesignerBuilderTest`
- `NativeFormsActionControllersTest`
- `NativeFormsThemeAndLogsTest`

### Phase 4: AWS-backed controller tests

Then:

- `NativeFormsAwsControllersTest`

### Phase 5: Heaviest integration tests

Last:

- `NativeFormsPublisherTest`
- `NativeFormsDemoDataTest`

## Test Design Boundaries

Do test:

- valid happy paths
- important save/update flows
- high-risk guardrails
- main failure branches
- package-visible behavior

Do not over-test:

- tiny presentation-only wording differences
- every generated HTML line
- every impossible branch
- low-value utility wrappers beyond basic confidence

## Package Readiness Success Criteria

The Apex test phase is considered successful when:

- overall coverage is in the `80-85%` range
- no class is being over-tested just to chase numbers
- setup/connect/publish/designer/action flows have meaningful behavior coverage
- AWS-backed controllers are covered with stable mocks
- fixture creation is reusable and understandable
- clean-org/package-visible behavior is still the priority

## Working Assumption

This plan assumes the current feature surface is stable enough to begin test implementation.

If major product/UI flow changes continue, pause new test-writing until the changed area settles, rather than creating brittle tests that will be rewritten immediately.
