# Screen Flow → Connected Forms

**Status:** Proposed (not built) — **overall idea endorsed; graph/compiler element needs a follow-up discussion (see §0).**
**Area:** Designer import (Apex, new Flow metadata read) + Prefill + Submit + Conditional logic + Post-submit URL (all existing engines)
**Author note:** Targeted after 0.1. Sits in the **"structured Salesforce metadata → form"** family alongside Page Layout → Form and Field Set → Form.

---

## 0. Summary & status (read first)

**We like the overall idea and it is feasible** — a Salesforce **Screen Flow** is a richly structured
source that encodes not just fields but the **object binding, prefill, submit, and conditional logic**. A
multi-screen / branching flow **compiles into a graph of connected TwinaForms forms**, linked by the
existing **post-submit URL** feature (which already supports a **formula mode** for conditional routing and
**merge-field templates** for passing the record Id forward).

**Open item to revisit together:** the **graph element** — i.e. how we walk the Flow graph and compile it
into N connected forms (decisions → routing, subflows → linked chains, cross-screen state). The *runtime
primitives* all exist; the *compiler* and its **supported subset** are the part to design carefully. **This
needs another working session before build.** The rest of the design below is solid.

---

## 1. Why this beats AI generation (design rationale)

Page Layout → Form is loved because the **source already encodes the answer** — deterministic, trustworthy,
auditable. AI generation throws that away and puts a QA/trust burden back on the admin ("did it map the
right field to the right SObject field?"). For forms that write to production records, **deterministic >
probabilistic**.

A **Screen Flow is an even richer structured source than a page layout** — it encodes fields **plus** the
object writeback, prefill, and conditions. So Flow → Form can produce a *more complete* form than Layout →
Form, deterministically. AI is explicitly **not** the direction here.

**Positioning bonus:** turns the argument we already make on the timesheet page ("Flow requires a paid
Salesforce license per submitter") into a one-click feature — *take your internal Screen Flow public, no
per-user license.*

---

## 2. The cascade — Flow elements → connected forms

A multi-screen / branching flow becomes a **graph of linked forms**:

| Flow element | Becomes | Engine (exists) |
|---|---|---|
| **Screen** | One form | Form builder |
| **Screen input fields / display text** | Form fields (by type) / display text | Field elements |
| **Choice sets / picklist choices** | Select / radio **options** | Options |
| **Get Record** (single) | **Prefill** `getById` / `findOne` | Prefill engine |
| **Get Records** (collection) | **Prefill** `findMany` → **repeat-group table** | Prefill `findMany` + Repeated Records *(reuses the Related-Records-Table feature)* |
| **Create / Update Records** | **Submit** action + field mapping on that form | Submit engine |
| **Component visibility conditions** | **Conditional logic** (show/hide) | Conditional logic |
| **Decision** | **Formula post-submit URL** → routes to the correct next form | `postSubmitUrlMode = "formula"` |
| **Screen → Screen transition** | Post-submit button → next form, **passing record Id** via merge-field URL | `postSubmitUrlTemplate` (merge fields) |
| **Subflow** | Its own imported form-chain, linked by button/URL (recurse) | Same import, recursively |

### Verified runtime primitives
The two load-bearing pieces are confirmed in code (`NativeFormsPublisher.cls:2173-2177`):
- **`postSubmitUrlMode` supports `"formula"`** → conditional next-form routing (= Flow Decision).
- **`postSubmitUrlTemplate` supports merge fields** → inject the created/updated **record Id** into the
  next form's prefill URL params.
- Plus `postSubmitAutoLinkEnabled`, `postSubmitButtonLabel`, `postSubmitDelaySeconds` (auto-redirect or button).

---

## 3. The crux — cross-screen state

A Flow holds a **record variable in memory** across screens and commits once at the end. Separate form
pages each submit independently, so state must be carried explicitly.

- **Recommended convention — commit-and-pass-Id.** Each form commits its piece (Create/Update) and passes
  the **record Id** forward in the post-submit URL; the next form's Get-Record prefill re-reads it. Fits
  Salesforce and the prefill model; Ids in URLs are safe and normal.
- **Hard/edge case — deferred commit.** Flows that build up large **uncommitted** field state across many
  screens before a single final commit would require shoveling all that state through URL params
  (size-limited, messy, exposes data). **Scope decision:** support commit-and-pass-Id; **flag
  deferred-commit flows** as unsupported/partial via diagnostics.

---

## 4. The compiler (the part to revisit — §0)

The importer stops being a single-form transform and becomes a **flow-graph → connected-forms compiler**:

1. Read the Flow metadata (new): `Flow` / `FlowScreen` / `FlowScreenField` / choices / `recordLookups` /
   `recordCreates` / `recordUpdates` / `decisions` / `subflows`.
2. Walk the graph from Start → emit **one form per Screen**.
3. For each transition, wire navigation (button + merge-field URL) and **param-passing** (record Id).
4. For each **Decision**, emit a **formula post-submit URL** routing to the right next form.
5. For each **Subflow**, recurse into its own chain and link it (guard against recursion loops).
6. For Get/Create/Update, emit prefill/submit as in §2.
7. **Diagnostics:** unsupported nodes (Apex actions, loops, LWC screen components, complex assignment
   expressions, runtime-only context) are **skipped and reported** — exactly the pattern the Page Layout
   import already uses (`buildPageLayoutImportDiagnosticsJson` + skipped-detail records).

### Supported subset (v1 proposal — to confirm in the follow-up)
- ✅ Screens with standard input fields + display text + choice sets.
- ✅ Get/Create/Update Records; simple Decisions (route to next form); subflows (recurse).
- ✅ Component visibility conditions → conditional logic.
- ⚠️ Loops — deferred (could later map to repeat groups).
- ❌ Apex actions, LWC screen components, runtime-only context, large deferred-commit state → skip + report.

> **This subset + the graph traversal is the §0 open item to discuss before build.**

---

## 5. Architecture — parallel to the existing Layout import

Clone the loved scaffolding, swap the metadata source:
- `getFlowImportOptions` (list screen flows) — *cf.* `getPageLayoutImportOptions`
- `previewFlowImport` — *cf.* `previewPageLayoutImport`
- `createFormFromFlow` → plan → elements → prefill → submit → conditions → navigation → diagnostics —
  *cf.* `createFormFromPageLayout` / `buildPageLayoutImportElements` / `buildPageLayoutImportPlan`
- New: **Flow metadata read** (Metadata/Tooling API) instead of `describeLayout` (`fetchPageLayoutMetadata`).

**Composes features we've already specced:** related-records table (`findMany`), conditional logic,
formula post-submit URL, submit mapping. This is the capstone that ties them together.

---

## 6. Complexity

| Part | Complexity | Notes |
|---|---|---|
| Flow metadata read (new source) | **Medium** | New Metadata/Tooling read of `Flow` + screens/choices/record-ops/decisions/subflows. |
| **Graph → connected-forms compiler** (§4) | **High** | The heavy lift: traversal, routing, subflow recursion, param-passing, supported-subset enforcement, diagnostics. **§0 open item.** |
| Per-form elements / prefill / submit / conditions | **Low–Medium** | Reuses existing engines + the layout-import scaffolding. |
| Cross-screen state (commit-and-pass-Id) | **Medium** | Convention + wiring record Ids through post-submit URLs. |
| Runtime (routing, merge-field URL, prefill, submit) | **None–Low** | Primitives confirmed to exist (`postSubmitUrlMode = formula` + template merge fields). |
| **Overall** | **High** | Feasible and deterministic because every *runtime* primitive exists; the new lift is the Apex **compiler** + supported subset, not new engines. |

**One-line answer:** High — but de-risked: the runtime already routes conditionally and passes record Ids
between forms; the real work is the Flow-graph compiler and its supported subset, which we will design in a
follow-up (§0).

---

## 7. How to deploy

> Mostly Salesforce-side. Org alias: **TwinaFormsDevHub**. Runtime primitives already exist; **no AWS change expected** (verify only).

### 7a. Components changed
- `force-app/main/default/lwc/nativeFormsDesigner/*` — Flow picker + import flow + diagnostics view.
- `force-app/main/default/classes/NativeFormsDesignerController.cls` (+ tests) — Flow metadata read,
  `createFormFromFlow` compiler, prefill/submit/condition/navigation generation, diagnostics.
- **AWS Prefill/Submit Lambdas:** no change expected (prefill, submit, formula post-submit URL all exist).

### 7b. Deploy commands (PowerShell)
```powershell
sf project deploy start `
  --source-dir force-app/main/default/lwc/nativeFormsDesigner `
  --source-dir force-app/main/default/classes/NativeFormsDesignerController.cls `
  --source-dir force-app/main/default/classes/NativeFormsDesignerBuilderTest.cls `
  --target-org TwinaFormsDevHub
sf apex run test --tests NativeFormsDesignerBuilderTest `
  --target-org TwinaFormsDevHub --result-format human --wait 10
```

### 7c. Smoke test
1. Import a simple **2-screen flow** (Get Record → edit → Create) → confirm two linked forms, record Id
   passed forward, submit writes back.
2. Import a flow with a **Decision** → confirm the formula post-submit URL routes to the correct next form
   per the branch condition.
3. Import a flow with a **subflow** → confirm the subflow becomes its own linked chain.
4. Import a flow with **unsupported nodes** (Apex action / loop / LWC component) → confirm they are skipped
   and reported in diagnostics, and the rest imports cleanly.

---

## 8. Open questions
- **§0 graph/compiler design + supported subset — schedule the follow-up session before build.**
- Cross-screen state: confirm commit-and-pass-Id as the only v1 model; deferred-commit flows out of scope?
- Decision mapping limits — how complex a decision tree do we support before flagging "too complex"?
- Subflow recursion depth / loop-guard policy.
- Pro-tier gating — tie to `enableProPageLayoutClone` (and reuse its entitlement)?
- Ship **Field Set → Form** alongside as the cheap quick-win in the same release?
