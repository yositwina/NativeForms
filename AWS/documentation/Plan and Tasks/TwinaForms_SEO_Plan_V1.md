# TwinaForms SEO Plan V1

Last updated: 2026-05-20

## Strategic framing

TwinaForms doesn't need SEO for raw traffic volume. It needs SEO to convert the small, finite audience of Salesforce admins (roughly 30k–100k worldwide) who Google "salesforce form builder" each month. That audience has high purchase intent. Winning them is the business; chasing generic "form builder" queries is a distraction.

Priority order:

1. **Transactional queries** — `salesforce form builder`, `formassembly alternative`. Fastest to convert.
2. **Problem-research queries** — `how to prefill salesforce data into a form`. Mid-funnel; help pages already start this.
3. **Generic SaaS queries** — `free form builder`. Low priority, low conversion.

---

## Phase 1 — Foundation (1–2 weeks, mostly technical)

One-time setup. Non-negotiable.

| Action | Why it matters |
|---|---|
| Google Search Console + Bing Webmaster Tools | Visibility into how Google sees the site; query data; index status. |
| Analytics (GA4 or Plausible) | Conversion funnel; channel attribution. Plausible is simpler/privacy-friendly. |
| `sitemap.xml` listing every public page | Helps crawlers discover new help pages quickly. |
| `robots.txt` declaring the sitemap | Standard practice; no surprises. |
| `og:` + `twitter:` meta tags on every page | Determines how the site renders when shared on LinkedIn (where SF admins live). |
| JSON-LD structured data: `Organization`, `SoftwareApplication`, `FAQPage` on help pages, `BreadcrumbList` | Enables rich-result eligibility, helps Google understand entity types. |
| Canonical tags on every page | Prevents duplicate-content issues with `?ref=...` params and trailing-slash variants. |
| Verify hreflang correctness in Search Console | Already in place for EN/HE; verify it's reciprocal and crawlable. |
| 404 page | Bad 404s leak link equity. |
| Favicon + Apple touch icon | Trust signal in browser tabs and SERPs. |

Cost: ~1–2 days of work, $0 in tools.

---

## Phase 2 — On-page optimization (2–3 weeks)

### Step 1: Keyword research

Pick the 20 highest-intent target queries before writing or changing copy. Map each page to one primary keyword.

Target categories:

- **Brand**: `twinaforms`, `twina forms`
- **Category**: `salesforce form builder`, `salesforce native forms`, `salesforce form to update record`, `salesforce form prefill`
- **Comparison**: `formassembly alternative`, `conga forms alternative`, `salesforce web-to-lead alternative`
- **Specific feature**: `salesforce form with file upload`, `salesforce form contact verification`, `salesforce signature form`

### Step 2: Per-page optimization

| Action | Notes |
|---|---|
| Optimize title tags + meta descriptions | Title tag is the largest single SERP signal. Test variants. |
| One target keyword per page; intent must match | Don't try to rank every page for everything. |
| Internal linking audit | Marketing↔Help cross-links; pricing↔use cases. |
| H1/H2 keyword alignment | Already mostly good; verify per page. |
| Image alt text using relevant terms (when accurate) | Free signal; do not stuff. |
| Dedicated "Pricing" page or strong `#plans` anchor | "salesforce form builder pricing" is high-intent. |

---

## Phase 3 — Content expansion (ongoing, biggest long-term payoff)

### Use-case landing pages

One per scenario, each targeting a specific high-intent query. ~500–800 words, screenshot, sandbox install link, optional starter template link.

- `/forms/lead-capture/` — "Salesforce lead capture form"
- `/forms/contact-update/` — "Salesforce contact update form"
- `/forms/case-creation/` — "Salesforce case form"
- `/forms/event-registration/` — "Salesforce event registration form"

### Comparison pages

These win in B2B SaaS. They tend to outperform homepages for branded-competitor queries.

- `/vs/formassembly/` — primary competitor
- `/vs/conga-forms/`
- `/vs/web-to-lead/`

### Blog or Resources section

Slow burn, compounding. Cadence: one article every 2 weeks for 12 months ≈ 25 articles — a long-tail moat.

Example topics:

- "How to capture a signature in Salesforce"
- "5 ways to verify identity before a form submission"
- "Why field-level security matters in public Salesforce forms"
- "Building HIPAA-compliant Salesforce forms"

---

## Phase 4 — Authority and links (ongoing)

### Salesforce-ecosystem-specific moves

- **AppExchange listing** when ready — itself a massive trust signal and ranking accelerant; SF links carry weight.
- **Trailblazer Community** engagement — answer questions; mention TwinaForms only when genuinely relevant.
- **Salesforce admin Stack Exchange** — same pattern.
- **/r/salesforce** subreddit — be helpful first, promote sparingly.
- **Salesforce LinkedIn groups** — SF admins live on LinkedIn.

### General B2B SaaS moves

- G2, Capterra, GetApp, SaaSHub, Product Hunt
- Guest posts on Salesforce admin blogs (Apex Hours, Automation Champion, etc.)
- Open-source a small tangential utility (Apex helper, CSS reset) on GitHub for developer credibility

---

## Phase 5 — Measure and iterate (monthly cadence)

- Search Console queries with impressions but no clicks → CTR optimization (better title/description).
- Pages getting traffic but no conversion → CRO problem, not SEO.
- Rankings on the 20 target keywords (SerpRobot's free tier is fine).
- UTM tracking on every external link to know which channel drove each sandbox install.

---

## Prioritized order for *current* stage

1. **Phase 1 entirely** — day 1–3. Cannot wait.
2. **Comparison page vs FormAssembly** — first content page; high-conversion, easier rank than open category queries.
3. **2–3 use-case landing pages** for strongest scenarios (Contact update, Case create, Lead capture).
4. **G2 + Capterra listings** while waiting for AppExchange — they rank well in some queries.
5. **Hebrew SEO play** — unique angle, near-zero competition for Israeli Salesforce market.
6. **AppExchange listing** as soon as possible — best single SEO + trust event in this niche.

---

## What *not* to do early

- Don't build a full blog yet — overinvestment vs. payoff at zero traffic.
- Don't chase generic "form builder" — too big; the SurveyMonkeys win.
- Don't write fluff content just to publish weekly. Quality over cadence.
- Don't buy backlinks. Google penalties.

---

## Open questions

- Which analytics tool? (GA4 vs Plausible vs Fathom — privacy/cost tradeoffs)
- Blog under `/blog/` subfolder or separate subdomain? (Subfolder concentrates authority on the main domain — preferred.)
- Hebrew help section — schedule for after English content is mature, or in parallel?
- Comparison-page approach — direct competitor comparisons (named) or feature-led comparisons (anonymous)?

---

## Status

- Plan written: 2026-05-20
- Phase 1 implementation: pending (awaiting FormAssembly competitive analysis first)
