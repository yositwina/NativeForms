# Lookup: Copy Related Fields from the Selected Record

**Status:** Implemented (Designer, publisher, runtime, and Records List support deployed)
**Area:** Designer LWC (lookup element panel) + Publisher (`lookupDefinition` + runtime JS) + AWS Lookup Lambda
**Author note:** Targeted for a release after 0.1.

---

## 1. What the feature is

Today a **Lookup** element stores only the **record Id** of the selected record (plus a display label).
This feature lets the author also **copy additional fields from the looked-up record into other fields
on the canvas**.

**Example:** a `Country` lookup object has `Name` and `Country_Code__c`. The user looks up the country;
the **country code automatically appears in another field** on the form. The author configures: *"when
this lookup is selected, copy `Country_Code__c` → the `countryCode` field."*

---

## 2. The big finding — most of this already exists

Reading the lookup pipeline end to end, the runtime plumbing to carry related fields is **already in
place**:

| Layer | What exists today | Reference |
|---|---|---|
| Designer config | Lookup element already stores `lookupTargetObject`, `lookupSearchFields`, **`lookupDisplayFields`**, min length, limit | `NativeFormsPublisher.cls:3546-3576` |
| Published definition | `buildPublishedLookupDefinition` bakes `searchFields` + **`displayFields`** per lookup field | `NativeFormsPublisher.cls:3531-3580` |
| Lookup Lambda | A live endpoint (`/forms/lookup`) that searches + resolves records | `NativeFormsBackend.cls`→`runLookup` (`NativeFormsBackend.mjs:2270`) |
| **Lambda already returns the extra fields** | `formatLookupRecord` returns `{ id, label, **fields: { …displayFields → values }** }` | `NativeFormsBackend.mjs:2259-2266` |
| Runtime selection | `callLookup` returns `data.record` (with `id`, `label`, **and `fields`**); the page sets the hidden Id + label via `setLookupValue` | `NativeFormsPublisher.cls:2264,2270` |

### The gap is small
- The selected record's other field values **already arrive in `record.fields`** whenever those fields
  are in `displayFields`.
- The runtime **just ignores `record.fields`** today — it only consumes `id` + `label`.
- So the missing work is: (a) a designer mapping `sourceField → targetFormField`, (b) ensure the source
  field is returned, and (c) at selection, write `record.fields[sourceField]` into the target input.
  **No new endpoint, no new query, no new security model.**

---

## 3. The UX question: element panel vs. prefill screen

**Recommendation: put it on the element property panel (right side), NOT the prefill screen.**

### Why the element panel
1. **It's a property of *this* lookup.** "When this lookup changes, fill these fields" is intrinsic to
   the lookup element — it sits naturally next to the target object + display fields the author already
   configures there.
2. **Timing / mental model.** The **prefill screen runs at form *load*** (server-side Prefill Lambda,
   keyed on params/verified identity). This feature is an **interaction-time** behaviour — it fires
   **when the user picks a value**, mid-form. Putting an on-change behaviour under "Prefill" would
   mislead authors into thinking it runs at load.
3. **It rides the lookup pipeline, not the prefill pipeline.** The data comes from the **Lookup Lambda +
   `lookupDefinition`**, a completely different subsystem from the Prefill Lambda + aliases. Keeping the
   UX next to the mechanism that implements it avoids cross-wiring two subsystems for no benefit.
4. **Discoverability.** The author is already thinking "I have a country lookup, I want the code too"
   while looking at the lookup element. The control should be right there.

### Suggested panel UX (agreed design)
In the Lookup element's properties, a section **"Copy fields from the selected record"** — each mapping
is a row of **two picklists** (`From {object}` → `To form field`), with a **✕** to remove the row and an
**"+ Add another mapping"** button below to add more:

```
Copy fields from the selected record
┌──────────────────────────┬──────────────────────────┬───┐
│ From Country        ▼    │ To form field        ▼   │ ✕ │
├──────────────────────────┼──────────────────────────┼───┤
│ From Country        ▼    │ To form field        ▼   │ ✕ │
└──────────────────────────┴──────────────────────────┴───┘
              + Add another mapping
```

- **`From {object}`** picklist (e.g. **`From Country`** — show the lookup's target object name
  dynamically, not a generic "From Lookup") = fields of the lookup's target object. Reuse the describe
  already used for `displayFields` (`NativeFormsPublisher.cls:3552`).
- **`To form field`** picklist = other fields on the canvas (by field key / label).
- **✕ remove** on each row; **"+ Add another mapping"** appends a new empty row.
- **Read-only is automatic, not a checkbox.** The mapped target field is **auto-locked** (derived value),
  reusing the existing `lockOnPrefill` styling — this keeps the row to just the two picklists while
  preventing the user editing the value out of sync with the lookup. A per-row "allow editing" toggle can
  be added later only if authors ask for it.
- **Clearing the lookup clears the mapped target fields** (the runtime already has a clear handler).

### Validation (cheap, worth having)
- Reject the **same target field** being chosen in two rows (last-write-wins confusion).
- Reject a row that maps **onto the lookup element itself**.
- Ignore/skip incomplete rows (one picklist empty) at publish time.

### When the prefill screen *would* be right (it isn't here)
Only if the population had to happen at **load** with no user interaction. Even then, the lookup's own
`resolveLookupLabel` runs at load for a pre-set value (`NativeFormsPublisher.cls:2270`), so the same
mapping can apply there too — without involving the prefill screen.

---

## 4. Implementation sketch

1. **Designer (config):** new element config `lookupFieldMappings: [{ sourceField, targetFieldKey }]` on
   the lookup element (two-picklist rows, §3). Targets are auto-locked at runtime — no per-row `readOnly`
   flag in the MVP.
2. **Publisher (`buildPublishedLookupDefinition`):** add every mapping `sourceField` to that field's
   `displayFields` (or a dedicated `returnFields`) so the Lambda returns it, and emit `fieldMappings`
   into the published lookup definition / runtime config.
3. **Runtime JS:** in the lookup selection handler, after `setLookupValue`, loop the mappings and write
   `record.fields[sourceField]` into each target input; on clear, blank the targets. Apply read-only if
   configured.
4. **AWS Lambda:** **no change** — `formatLookupRecord` already returns `fields` for everything in
   `displayFields`.

---

## 5. Complexity

| Part | Complexity | Notes |
|---|---|---|
| Designer panel section + `lookupFieldMappings` config | **Low–Medium** | New mapping table UI on the lookup element; two dropdowns + a checkbox per row. |
| Publisher: add sources to `displayFields`, emit mappings | **Low** | Small change in `buildPublishedLookupDefinition`. |
| Runtime: apply `record.fields[src]` → target on select/clear | **Low** | The data already arrives in `record.fields`; just consume it. |
| AWS Lookup Lambda | **None** | Already returns the fields. |
| **Overall** | **Low** | The hard parts (a runtime lookup call that returns related fields) already exist. This is wiring a mapping into config + consuming data that's already on the wire. |

**One-line answer:** Low complexity — the Lookup Lambda already returns the related fields in
`record.fields`; the work is a small mapping UI on the **element panel** plus a few lines of runtime JS
to copy those values into the target fields.

---

## 6. Notes & edge cases

- **FLS / security:** mapped source fields are returned the same way `displayFields` are today, gated by
  the same object-field describe (`NativeFormsPublisher.cls:3552`). Confirm the running context respects
  field-level security so a mapping can't surface a field the user shouldn't read. No *new* exposure
  beyond how `displayFields` already works, but widen the test surface.
- **Field-type compatibility:** text code → text field is trivial. Define behaviour for picklist/number/
  date targets (coerce or restrict the target dropdown to compatible types).
- **User-editable targets:** if a mapped target is also editable, the derived value overwrites on select;
  clearing the lookup should clear/restore it. Read-only default avoids the conflict.
- **Multiple mappings per lookup** and **multiple lookups** on one form — keyed by `fieldKey`, already
  the model in `lookupDefinition.fields`.

---

## 7. How to deploy

> Org alias: **TwinaFormsDevHub** (per project deploy targets).

### 7a. Components changed
- `force-app/main/default/lwc/nativeFormsDesigner/*` — the mapping panel + `lookupFieldMappings` config.
- `force-app/main/default/classes/NativeFormsPublisher.cls` (+ `NativeFormsPublisherTest.cls`) —
  `buildPublishedLookupDefinition` adds source fields to `displayFields` and emits mappings; runtime JS
  consumes `record.fields`.
- **AWS Lookup Lambda: no change** (already returns `fields`).

### 7b. Deploy commands (PowerShell)
```powershell
sf project deploy start `
  --source-dir force-app/main/default/lwc/nativeFormsDesigner `
  --source-dir force-app/main/default/classes/NativeFormsPublisher.cls `
  --source-dir force-app/main/default/classes/NativeFormsPublisherTest.cls `
  --target-org TwinaFormsDevHub

sf apex run test --tests NativeFormsPublisherTest `
  --target-org TwinaFormsDevHub --result-format human --wait 10
```

### 7c. IMPORTANT — re-publish affected forms
The lookup definition + runtime JS are **baked at publish time** by `NativeFormsPublisher.cls`. After
deploy, each form using the new mapping must be **re-published** for it to take effect on the live form.

### 7d. Smoke test
1. On a lookup element, add a mapping row: `From Country = Country_Code__c` → `To form field = Country
   Code field`. Re-publish.
2. On the published form, pick a country → confirm the code field auto-fills and is read-only.
3. Clear the lookup → confirm the code field clears.
4. Confirm the submitted record carries both the lookup Id and the copied code value.
