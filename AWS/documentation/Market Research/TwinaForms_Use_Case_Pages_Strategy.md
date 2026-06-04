# TwinaForms Use-Case Pages — SEO Strategy

**Status:** Primary SEO push. Build before feature pages (see [TwinaForms_Feature_Page_Priority_Map.md](./TwinaForms_Feature_Page_Priority_Map.md)).
**Owner:** Gil
**Last updated:** 2026-05-28
**Audience:** English-only customers.

---

## Why use-case pages over feature pages

A feature page answers "what is X?" — useful if the searcher already knows your category.
A use-case page answers "how do I solve Y?" — captures the searcher *before* they know form-builders are the solution.

Use-case pages convert better because:
- The H1 matches the searcher's exact job-to-be-done
- The reader self-identifies in the first scroll ("yes, that's my problem")
- The page can combine multiple features into one persuasive story
- Competition is lower (commodity feature pages crowd the "salesforce form prefill" SERP; "salesforce timesheet form" has fewer well-optimized contenders)

**Lead with these. Feature pages are backstop.**

---

## The 4 use-case pages

### U1 — Salesforce Timesheet Form

**Detailed plan:** [TwinaForms_U1_Timesheet_Page_Plan.md](./TwinaForms_U1_Timesheet_Page_Plan.md)

- **URL:** `/solutions/salesforce/timesheet-form/`
- **Primary keyword:** `salesforce timesheet form`
- **Supporting keywords:** `salesforce time tracking form`, `salesforce contractor hours form`, `track billable hours salesforce`, `weekly timesheet salesforce`
- **Audience:** SF admins at agencies, consultancies, contractor shops, professional services firms with hourly workers
- **Pain to lead with:** Hours tracked in spreadsheets → manual data entry → no audit trail → no signed copy for payroll/billing
- **TwinaForms features combined:**
  - Repeated Records (multiple time entries per submission)
  - Prefill (worker info, project list)
  - Submit to custom object (Timesheet, Time Entry)
  - **Submission PDF + Signature** (signed timesheet for payroll/audit)
- **NPSP variant?** No standalone page — the volunteer-hours angle is covered by U2.
- **Why P0:** highest commercial-intent search query in the set; combines TwinaForms' two strongest differentiators (Repeated Records + signed PDF).

### U2 — Salesforce Volunteer Signup Form (NPSP)

- **URL:** `/solutions/npsp/volunteer-signup-form/`
- **Primary keyword:** `npsp volunteer signup form`
- **Supporting keywords:** `salesforce volunteer form`, `volunteer hours tracking salesforce`, `npsp volunteer management form`, `volunteers for salesforce form`
- **Audience:** NPSP admins, volunteer coordinators at nonprofits
- **Pain to lead with:** Volunteers managed in spreadsheets or Google Forms → manual re-entry into NPSP → privacy issues → no parental consent for minors
- **TwinaForms features combined:**
  - Page Layout → Form (clone the volunteer signup layout)
  - Contact Verification (privacy)
  - Repeated Records (log multiple shifts per submission)
  - Signature (waiver / parental consent)
- **NPSP variant?** This IS the NPSP variant — no Regular SF page needed for this one.
- **Why P0:** very high intent ("npsp" in query = self-identified buyer), low competition. NPSP admins literally search this.

### U3 — Salesforce Update Contact Form

- **URL (Regular):** `/solutions/salesforce/update-contact-form/`
- **URL (NPSP):** `/solutions/npsp/donor-self-update-form/`
- **Primary keyword (Regular):** `salesforce update contact form`
- **Primary keyword (NPSP):** `donor self-update form salesforce`
- **Supporting keywords:** `salesforce contact data refresh form`, `update salesforce record from form`, `let contacts update their own info salesforce`
- **Audience:** SF admins managing contact-data freshness; nonprofit admins running donor data hygiene
- **Pain to lead with:** Contact data goes stale → undeliverable email → wasted outreach → can't ask contacts to update via raw form (data exposure risk)
- **TwinaForms features combined:**
  - Prefill (load existing record so contact only edits what changed)
  - Contact Verification (so the right person updates the right record — this is the safety story)
  - Submit (update existing record, not create new)
- **NPSP variant?** Yes — full split. "Donor self-update" is a distinct query with distinct buyer.
- **Why P0:** evergreen pain across every SF org. The verification angle is the differentiator vs. generic competitors.

### U4 — Salesforce Intake Form

- **URL (Regular):** `/solutions/salesforce/intake-form/`
- **URL (NPSP):** `/solutions/npsp/grant-intake-form/` (variant)
- **Primary keyword (Regular):** `salesforce intake form`
- **Primary keyword (NPSP):** `grant application form salesforce`, `npsp client intake form`
- **Supporting keywords:** `salesforce client onboarding form`, `salesforce case intake`, `program intake form npsp`
- **Audience:** services orgs, consultancies, nonprofits running programs/grants
- **Pain to lead with:** Intake collected by email/PDF → manual re-keying → lost forms → no signed record → applicant ghosting
- **TwinaForms features combined:**
  - Page Layout → Form (clone the intake-object layout)
  - Prefill (if referral link includes known info)
  - Submission PDF + Signature (signed intake on file)
  - File Uploads (resumes, supporting documents)
- **NPSP variant?** Yes — "grant application" is a distinct, high-intent NPSP query.
- **Why P0:** broad-intent keyword family + the NPSP grant-intake variant is one of the highest-converting nonprofit searches.

---

## Page count summary

| Use case | Pages | Cumulative |
|---|---|---|
| U1 Timesheet | 1 | 1 |
| U2 Volunteer Signup (NPSP only) | 1 | 2 |
| U3 Update Contact (Regular + NPSP) | 2 | 4 |
| U4 Intake (Regular + NPSP grant variant) | 2 | 6 |

**Total: 6 use-case pages.** Combined with Tier 1 feature pages (6), that's a 12-page Phase 1 that covers the most commercial keyword surface area without writing thin pages.

---

## Why these 4 (and not others)

Considered and rejected for the initial 4:
- "Salesforce survey form" — competitive against SurveyMonkey/Typeform; hard SEO battle, lower ROI
- "Salesforce event registration form" — moderate volume but heavy competition from Eventbrite-style players
- "Salesforce lead form" — high volume but every form vendor targets this; we'd be late entrants
- "Salesforce expense report form" — strong fit for Repeated Records but smaller audience than timesheets

The 4 chosen are where (a) the search has commercial intent, (b) competition is beatable, and (c) TwinaForms has a feature combination that genuinely solves it without manual stitching.

---

## Build order

1. **U1 Timesheet** (detailed plan: [TwinaForms_U1_Timesheet_Page_Plan.md](./TwinaForms_U1_Timesheet_Page_Plan.md))
2. **U2 Volunteer Signup** — leverage Page Layout → Form feature, shipping it gives NPSP audience a flagship
3. **U3 Regular Update Contact** — broadest evergreen page
4. **U4 Regular Intake Form**
5. **U3 NPSP Donor Self-Update**
6. **U4 NPSP Grant Intake**

Ship 1 → 2 → 3, see what ranks in 6 weeks, then commit to 4–6 based on data.
