# Move Forms Between Orgs (Sandbox ↔ Production)

**Status:** Proposed (not built)
**Area:** Designer (export/import + Move) + form serialization + compatibility validation + Connect/OAuth (Environment Link) + AWS broker
**Author note:** Targeted after 0.1. Two phases — **Phase 1: Export/Import (JSON)**, **Phase 2: Linked one-click Move**.

---

## 1. What this is

Let admins **move a form definition between orgs** — primarily **sandbox ↔ production** — so forms can be
built/iterated in a sandbox and promoted to production (and pulled back).

Two phases:
- **Phase 1 — Export / Import (portable JSON package).** Export a form to a self-contained JSON file;
  import it into any other org. No org-linking required. Ships the hard, reusable core.
- **Phase 2 — Linked one-click "Move".** OAuth-link the two orgs once ("Connect Production"); then a
  **Move Forms** button promotes a form to the linked org, creating a **new version** (or a newer version
  on the existing form — admin's choice), via AWS as the broker. Built on top of Phase 1's serializer +
  validator.

---

## 2. Why this is feasible — forms are portable by API name (verified)

The form definition references Salesforce metadata by **API name**, not record Id — so it travels across
orgs as long as the target has the same metadata.

| Portable (by API name / logical id) | Reference |
|---|---|
| Submit/prefill actions → `Object_Api_Name__c`, field paths in `Config_JSON__c` | `NF_Form_Action__c`; `NativeFormsBuilderController.cls:658-681` (describe by API name) |
| Element field references → `Field_Key__c`, logical `Element_Id__c` / `Parent_Element_Id__c` | `NF_Form_Element__c` |
| Form identity → `NF_Key__c` (candidate stable key) | `NF_Form__c` |

| Org-specific — must NOT move; regenerate on publish | Reference |
|---|---|
| Publish token, generated HTML ref, published form id, AWS response | `NF_Form_Version__c.Publish_Token__c`, `NF_Form_Publication__c.Generated_HTML_Ref__c` / `Published_Form_Id__c` / `AWS_Response_JSON__c` |
| Embedded assets (image `publishedAssetUrl` / S3 URLs) in `Config_JSON__c` | per-element config |

**Takeaway:** the model is already cross-org friendly. The work is **serialization + validation +
transport**, not untangling org-specific Ids throughout the schema.

---

## 3. The five things that make it robust (beyond the basic idea)

### 3.1 Stable cross-org form identity (load-bearing)
To "update the existing form / bump its version" in the target, the system must know **which** target form
matches the source form. SF record Ids differ per org, so the form needs a **portable GUID** stored in both
orgs and known to AWS. **Reuse `NF_Key__c` if it is a stable slug; otherwise add a dedicated immutable
GUID.** Without it, "new version vs. update existing" cannot target reliably.

### 3.2 Pre-move compatibility validation (the #1 real-world risk)
Sandbox/prod metadata drift. A form referencing `Contact.My_New_Field__c` that exists in sandbox but not in
prod will break. **Before creating anything in the target**, validate that every referenced **object /
field / record type / page layout** exists in the target org (Schema describe in the target) and show a
**compatibility report**: *"3 fields missing in Production — deploy them first."* This is what makes the
feature trustworthy rather than a demo.

### 3.3 Strip & regenerate org-specific artifacts
Move the **definition only**. Drop publish tokens / AWS refs / published ids (regenerated on **re-publish**
in the target). Audit `Config_JSON__c` for **embedded assets** (image URLs / `publishedAssetUrl`) and any
record-Id defaults → re-upload or re-map. **Submissions never move** (per-org data).

### 3.4 Transport = AWS broker (Phase 2), not org-to-org
The source org serializes the form (records → JSON) and pushes it to **AWS keyed to the Environment Link**;
the target org pulls + imports. No direct org-to-org connection, no second inbound OAuth. AWS is already the
shared trust anchor.

### 3.5 Authorization, audit & conflict semantics
- **Authz:** only an admin who proved control of **both** orgs (the OAuth link) can Move; AWS authorizes
  against the established link.
- **Audit:** log who moved which form, direction, target version, when.
- **Conflict:** "update existing" creates a **new, inactive version** in the target for review + manual
  activation — **never silently overwrite** a live/edited prod form.

---

## 4. Phase 1 — Export / Import (JSON package)

**Flow:** Designer → **Export** → download a self-contained JSON (form + versions + elements + actions +
UI settings + theme + the **GUID** + a **manifest** of referenced objects/fields). In the target org →
**Import** → run compatibility validation (3.2) → strip org-specific artifacts (3.3) → create the
form/version.

- **No org-linking, no prod-OAuth.** Works across **any** two orgs — sandbox↔prod, prod↔prod, or as
  backup/template seeding.
- Ships the reusable core that Phase 2 builds on: **serializer, GUID, compatibility validator,
  artifact-stripper, importer.**

---

## 5. Phase 2 — Linked one-click "Move"

1. **Connect Production** (new button, e.g. on the Connect page): from the sandbox, the admin OAuths into
   the production org. AWS records an **Environment Link** (sandbox org ↔ production org = same customer),
   proven by OAuth control of both.
2. **Move Forms** (Designer button): pick **direction** (sandbox→prod or prod→sandbox) and target —
   **create a new form** in the target, or **add a newer version to the existing form** (matched by GUID,
   3.1). Admin selects.
3. **Transport:** source serializes (Phase 1) → pushes to AWS under the link → target pulls + imports
   (compatibility validation + artifact strip) → creates a **new inactive version** for review/activation.

Direction is general: sandbox↔prod is the headline case of a generic **org-pair link** (could extend to
prod↔prod between two customer orgs later).

---

## 6. Complexity

| Part | Phase | Complexity | Notes |
|---|---|---|---|
| Form serializer (records → JSON + manifest) | 1 | **Medium** | Walk form/versions/elements/actions/UI settings; emit GUID + referenced-metadata manifest. |
| Compatibility validator (target describe) | 1 | **Medium** | Check objects/fields/record types/layouts exist; produce a report. The trust core. |
| Artifact strip + asset handling | 1 | **Low–Medium** | Drop tokens/refs; re-upload/re-map embedded image assets. |
| Importer (create form/version in target) | 1 | **Medium** | Insert records, preserve GUID, new inactive version. |
| GUID / stable identity | 1 | **Low** | Reuse `NF_Key__c` or add immutable GUID. |
| Environment Link (OAuth-prod) + AWS link store | 2 | **Medium–High** | New OAuth flow from sandbox to prod; AWS records + authorizes the pair. |
| AWS broker (form-package push/pull) + authz + audit | 2 | **Medium** | Keyed to the link; reuses Phase 1 serializer. |
| Move UI (direction, target, new-vs-existing) | 2 | **Low–Medium** | Designer button + picker. |
| **Overall** | — | **Phase 1: Medium · Phase 2: Medium–High** | De-risked because the definition is already portable by API name (§2); the work is serialize + validate + transport, not Id untangling. |

**One-line answer:** Feasible and well-structured. Phase 1 (Export/Import JSON) is Medium and ships the
reusable core (serializer + compatibility validator + importer); Phase 2 (linked one-click Move) adds the
OAuth Environment Link + AWS broker on top — Medium–High. Biggest real risk is **metadata drift between
orgs**, handled by the compatibility report (3.2).

---

## 7. How to deploy

> Org alias: **TwinaFormsDevHub**. Phase 1 is Salesforce-side. Phase 2 adds AWS (Environment Link + broker).

### 7a. Components changed
- **Phase 1:** `nativeFormsDesigner` (Export/Import UI + compatibility report), new Apex serializer /
  validator / importer (+ tests). Storage: the JSON is a file the admin downloads/uploads — no backend.
- **Phase 2:** `nativeFormsConnect` (Connect Production / OAuth-prod), Apex Move controller, **AWS**
  Environment-Link + form-package store/authz (Submit/Admin API or a new endpoint), audit.

### 7b. Deploy commands (PowerShell)
```powershell
# Phase 1 (Salesforce only)
sf project deploy start `
  --source-dir force-app/main/default/lwc/nativeFormsDesigner `
  --source-dir force-app/main/default/classes `
  --target-org TwinaFormsDevHub
sf apex run test --target-org TwinaFormsDevHub --result-format human --wait 10

# Phase 2 additionally: deploy nativeFormsConnect + the AWS link/broker endpoint via its pipeline.
```

### 7c. Smoke test
**Phase 1:** Export a form from sandbox → import the JSON into another org → confirm the form/version is
created, GUID preserved, and the compatibility report flags a deliberately-missing field.
**Phase 2:** Connect Production from sandbox (OAuth) → Move a form sandbox→prod as a **new version on the
existing form** → confirm a new **inactive** version appears in prod, no live form overwritten, and the
move is audited. Re-publish in prod → confirm AWS artifacts regenerate.

---

## 8. Open questions
- Reuse `NF_Key__c` as the cross-org GUID, or add a dedicated immutable field?
- Compatibility mismatch policy: block the import, or import with the offending elements disabled + warned?
- Embedded image assets: re-upload to the target's AWS context automatically, or require re-publish?
- Phase 2 link model: strictly sandbox↔prod pairs, or a general org-group (3+ orgs)?
- Pro-tier / admin-only gating for cross-org Move.
- Should "Move" optionally carry the theme + PDF theme assignment, or definition only?
