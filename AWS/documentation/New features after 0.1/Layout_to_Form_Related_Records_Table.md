# Page Layout to Form — add Related Records as a Table

**Status:** Specified, ready to build (not yet built)
**Area:** Designer "Page Layout to Form" import (Apex + LWC) — no AWS changes
**Last reviewed:** 2026-09-08 — verified against source; decisions below are locked.

---

## 1. What this is

Extend **Page Layout to Form** so the generated form also includes **related records as an editable
table**. The author picks an object + page layout as today, then additionally picks **one related list**
and **up to 6 fields** from it. The import produces the parent layout at the top and, below it, a
**Records List** prefilled with that parent's existing children, where the form user can edit existing
rows and add new ones.

**Value:** it automates in one click the exact multi-part configuration that is built by hand today.
The largest lever is FormAssembly migration — parent-plus-child-rows is one of the most common FA form
shapes. Note it imports *structure*, not logic: FA rules and calculations still do not transfer.

---

## 2. Verified: what already exists (zero engine work)

Confirmed in source, not assumed:

| Building block | Status | Reference |
|---|---|---|
| Page Layout → Form import | Exists | `NativeFormsDesignerController.cls:1238` `createFormFromPageLayout`, `:3508` `buildPageLayoutImportElements`, `:2986` `buildPageLayoutImportPlan` |
| `findMany` prefill (filter/limit/orderBy) | Exists | `AWS/NativeForms-PrefillForm.mjs:927` |
| Prefill → table mapping is **automatic** | Exists | `NativeFormsPublisher.cls:957` — emits `repeatGroups.<fieldKey>.rows = {alias}` for any repeatGroup whose `repeatSourceAlias` matches a prefill action alias. No mapping code to write. |
| `upsertMany` submit **with parent binding** | Exists | `NativeFormsPublisher.cls:1154-1173` — `relationshipField` + `relationshipValue` already supported and configurable |
| Prefill security policy | **Derived automatically** | `NativeFormsPublisher.cls:862` — `allowedObjects` is collected from the action records, so adding a `findMany` action for the child object authorizes it with no extra work |
| Condition value sources (`verifiedEmail`, `param`, `field`, `alias`) | Exists | `NativeFormsPublisher.cls:1583` |
| Records List runtime, PDF, add/delete rows | Exists | Publisher repeat-group render + runtime |

**The AWS lambdas need no changes.** This is a Salesforce-only feature.

---

## 3. Correction to the original plan: related-list discovery

An earlier draft of this doc claimed related lists are already present in the page-layout metadata fetched
today. **They are not.** The backend calls `/ui-api/layout/` and `/ui-api/object-info/`
(`AWS/NativeFormsBackend.mjs:2798`, `:2782`); neither returns related lists — UI API exposes those through
a separate `related-list-info` resource. Following the original plan would require a new AWS endpoint, a
new `NativeFormsAwsClient` method, and Apex plumbing.

**Decision: use `Schema...getDescribe().getChildRelationships()` in Apex instead.** It returns every child
relationship (child object, the lookup field, relationship name) with **no callout**. It is currently
unused anywhere in the codebase. We give up "which related lists the admin placed on the layout, in their
order"; we gain a discovery step that is ~30 lines and keeps AWS off the critical path entirely.

---

## 4. Parent identification — the generated chain

**Decision: generate the verification identity chain only.** No `recordId` in the URL. The parent is found
from the verified Contact, or created on submit if it does not exist.

**Three shapes, auto-detected from the chosen parent object:**

| Shape | Condition | Example | Extra author input |
|---|---|---|---|
| **A** | Parent object *is* Contact | Edit my Contact, show all my Cases | None — the Contact alias *is* the parent alias; link 2 disappears |
| **B** | Parent has a Contact lookup | Show all Cases for my Account | None — `findOne` on `Id = {Contact.<lookup>}` |
| **C** | Identity matches many parents | One daily report per day → need today's | **Business key required** (e.g. a `date` URL param) |

Shapes A and B need **no extra picker questions**. Only C asks for a business key.

**Caveat for A/B:** if more than one parent matches, `findOne` picks an arbitrary record silently. Give
that query a deterministic `orderBy`, or warn at import time.

**The generated chain (matches the hand-built pattern in production today):**

1. **Identity** — User Verification → Contact alias (`verifiedEmail` → `{params.email}`).
2. **Find parent** *(shapes B/C)* — Prefill `findOne`, `<contactLookup> = {Contact.Id}` (valueSource
   `alias`), plus the business key `= {params.<key>}` (valueSource `param`) for shape C. Stored as an
   alias; its `Id` is mapped into a **hidden form field**.
3. **Load children** — Prefill `findMany` on the child object, `<parentLookup> = {ParentAlias.Id}`
   (valueSource `alias`). Rows reach the Records List via `repeatSourceAlias`.
4. **Save parent** — Submit `findAndUpdate` matching `Id = {input.<hiddenParentId>}` (valueSource
   `field`), with **"if no matching record is found → create new record."** Stored as a result alias.
5. **Save children** — Submit `upsertMany` with `relationshipValueSource = alias` pointing at step 4's
   result Id, so new rows attach to the parent whether it already existed or was just created.

**Security:** this is *stronger* than a `recordId` parameter. The parent derives from a server-verified
email plus (optionally) a business key, so no URL editing reaches another person's record and there is
nothing to enumerate.

---

## 5. Locked decisions

- **One related list per form** in phase 1. Multiple tables is a small later increment.
- **Row cap: 20.** Forced by BUG-023 (see §7). Raise to 100+ only once sObject Collections lands.
- **Row delete: off.** Generated lists allow edit + add only. The author can enable deletion afterwards
  in the designer. A deleted row destroys a Salesforce record; that should not ship by default on a form
  the author did not hand-build.
- **User Verification: auto-enabled** when a related list is picked, since the chain depends on a verified
  Contact. Warn the author that a sender email is required before publishing.
- **Pro gating:** rides the existing **Records List gating** (`enableProRepeatGroups`). No separate flag.
- **Default order:** `CreatedDate DESC` (newest first). Configurable sort is ENH-024.
- **Warn the author** when a typical parent has more than 20 children.
- **Child-field type whitelist** — see §6.
- **FLS:** mirror `filterStorableImportedElements` for the child object.
- **Query scoping:** reuse the existing `conditions` + `valueSource` shape. Never hand-roll a
  `whereClause` template — the conditions shape resolves server-side from the stored definition.

---

## 6. Child-field type whitelist (required)

Some element types render inside a Records List row but are **not wired into the row data path**, so they
fail silently. Two confirmed today:

- **Ranking** — `renderRankingControl` (`NativeFormsPublisher.cls:3276`) emits its hidden input without
  `data-repeat-field-key`. `setupRepeatRow` and `collectRepeatGroups` both iterate on that attribute, so
  the ranking input is never id-uniquified (duplicate ids and names across rows) and its value is **never
  collected on submit**. It looks perfect and loses the answer.
- **Location** — the row renderer has no `location` branch at all, so it falls through to the generic
  `<input>` tail and degrades to one plain text box instead of country/region/city.
- **Image** returns an empty string in rows. **File upload** is wired with the right attributes but
  per-row file handling is unverified — test before allowing it.

These are pre-existing bugs, harmless today because nobody hand-adds those types to a Records List. The
import changes that: it would emit them **automatically, at scale**, for authors who never chose them —
producing forms that look right in the designer and lose data on submit.

**Offer only:** text, textarea, number, email, tel, url, date, time, checkbox, select, multiCheckbox,
radio, lookup. Everything else is excluded from the picker, or imported as an unsupported-type skip with a
warning, exactly as `filterStorableImportedElements` already does for the parent.

---

## 7. Dependency: BUG-023

`upsertMany` writes rows **one at a time, sequentially**, and rewrites **every** row on every submit with
no dirty checking. At ~200-400ms per write inside a 30-second Lambda, ~50 rows risks timeout, and there is
**no transaction** — a timeout at row 37 leaves rows 1-36 committed, and re-submitting duplicates them.

This is why the cap is 20. Fixing BUG-023 with sObject Collections (`/composite/sobjects`, 200 records per
call) turns 50 sequential round-trips into 2-3, and would make 100+ rows safe. It also improves every
existing hand-built Records List form.

**Shape B is where the cap bites hardest** — "all Cases for an Account" is routinely more than 20 rows,
whereas "today's activities" rarely is. Treat BUG-023 as a harder dependency for shape B than for C.

---

## 8. Scope and effort

**~500-700 lines, Salesforce only, no engine changes. Roughly 3-5 focused days.**

| Piece | Est. lines |
|---|---|
| Apex: child-relationship discovery + child field describe | 40-60 |
| Apex: extend `createFormFromPageLayout` — emit hidden parent-Id field, 2 prefill actions, 2 submit actions, repeatGroup + up to 6 child elements | 120-180 |
| LWC: related-list + field picker, shape detection, warnings | 250-350 |
| Tests (`NativeFormsDesignerBuilderTest`, via the existing `pageLayoutImportMetadataMock` hook) | ~150 |
| AWS | 0 |

**Risks after the decisions above:** all Low. The former Medium items — business key generalization and
broken row field types — are resolved by shape auto-detection (§4) and the whitelist (§6) respectively.

---

## 9. How to deploy

> Org alias: **TwinaFormsDevHub**. Deploy `nativeFormsDesigner` (LWC),
> `NativeFormsDesignerController.cls` and `NativeFormsDesignerBuilderTest.cls`, then run
> `NativeFormsDesignerBuilderTest`.

## 10. Smoke test

1. Import a parent layout, add a related list with 3-4 fields. Open the form, verify by email → confirm
   the table below the layout is prefilled with that parent's children.
2. Open as a different verified contact → confirm different rows (scoping works).
3. Edit a row + submit → child record updates. Add a row + submit → new child created, linked to the parent.
4. Submit when **no parent exists yet** → parent is created and the new rows attach to it (§4 step 4).
5. Confirm row delete is not offered, and that more than 20 children triggers the author warning at import.
6. FLS: a user without access to a chosen child field → confirm it is excluded and reported.
