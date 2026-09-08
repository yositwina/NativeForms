# New Features After 0.1 — Index (ordered by complexity)

**Decision docs:** [PDF Rendering Engine Strategy](PDF_Rendering_Engine_Strategy.md) — migrate PDF output to
**HTML→Chromium** (pdfmake rejected; backed by two spikes). This *lowered* the complexity of both PDF
features below (table + theme are now HTML/CSS).

Easiest first, most complex last. Each row links to its full design doc.

| # | Feature | Complexity | Why |
|---|---|---|---|
| 1 | [Lookup: Copy Related Fields](Lookup_Copy_Related_Fields.md) | **Low** | Lambda already returns the related fields; just consume them + a small picker |
| 2 | [License Expired Banner (+ publish block)](License_Expired_Banner.md) | **Low** | Backend already knows expiry; expose 2 fields + simple banner + 1 publish guard |
| 3 | [PDF Repeat-Group Table Rendering](PDF_Repeat_Group_Table_Rendering.md) | **Low** | On HTML→Chromium it's an HTML `<table>` + CSS; one Apex flag passthrough |
| 4 | [Section & Records List: Column Layout Presets](Section_Column_Layout_Presets.md) | **Low–Medium** | All 4 render paths share one `grid-template-columns`; work is the panel UI + preview mirroring. Prerequisite for page-layout import fidelity |
| 5 | [HTML Source Toggle (Display Text)](HTML_Source_Toggle_for_Display_Text.md) | **Low–Medium** | Button is trivial; real work is AWS-side sanitization |
| 6 | [Trial/License End Alert Email](Trial_License_End_Alert_Email.md) | **Low–Medium** | SES sender + send fn exist; add cron + thresholds + idempotency (send via us-east-1) |
| 7 | [PDF Theme Tab (Phase 1)](PDF_Theme_Tab.md) | **Low–Medium** | Tokens → CSS variables on Chromium; the work is the named-theme library + per-form picker |
| 8 | [Layout → Form: Related Records Table](Layout_to_Form_Related_Records_Table.md) | **Medium** | All 3 engines exist; wire picker + parent-scoped `findMany` |
| 9 | [Move Forms Between Orgs — Phase 1 (Export/Import JSON)](Move_Forms_Between_Orgs.md) | **Medium** | Serializer + compatibility validator + importer; portable by API name |
| 10 | [Verified-Contact Auto Aliases (MVP)](User_Verification_Auto_Aliases_for_Verified_Contact.md) | **Medium–High** | Aliases easy; safe post-verification resolution is the work |
| 11 | [Move Forms Between Orgs — Phase 2 (Linked Move)](Move_Forms_Between_Orgs.md) | **Medium–High** | Adds OAuth env-link + AWS broker on top of Phase 1 |
| 11a | [Linked Sandbox/Production Forms - Phase 2 Portability](Linked_Sandbox_Production_Phase2_Portability_Design.md) | **Medium-High** | Adds theme/logo/assets portability, compatibility preview, and clearer import limit errors |
| 11b | [Linked Sandbox/Production Forms - Phase 3 AWS Connected Org Snapshots](Linked_Sandbox_Production_Phase3_AWS_Connected_Org_Snapshots_Design.md) | **High** | Adds connected-org groups, AWS snapshot storage/listing, and import-from-connected-org UX on top of Phase 2 portability |
| 12 | [Screen Flow → Connected Forms](Screen_Flow_to_Connected_Forms.md) | **High** | Flow-graph → connected-forms compiler + supported subset |

**11 features** (Move Forms split into phases = 13 rows).

> Biggest open design questions: **#10** (security-safe post-verification resolution) and **#12** (the
> graph/compiler supported subset — needs a working session before build).

