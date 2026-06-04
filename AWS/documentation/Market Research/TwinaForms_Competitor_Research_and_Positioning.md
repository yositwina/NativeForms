# TwinaForms Competitor Research and Positioning

Date: 2026-05-03

This document summarizes the competitor findings discussed during TwinaForms launch planning. It focuses on Salesforce-connected form products, especially tools that can create public forms, prefill from Salesforce, submit back to Salesforce, or present themselves as Salesforce-native.

The conclusions below are based on public pages, AppExchange-visible positioning, pricing pages, public demos, and product observations. Some competitor implementation details are inferred from visible behavior and should be treated as directional unless confirmed by vendor documentation.

## Executive View

TwinaForms should not position itself as the only Salesforce form builder. The market already has strong players in several categories.

The clearer opening is:

> TwinaForms is an affordable Salesforce-native public form app for teams that want forms, prefill, submit, and Salesforce writeback without adopting a heavy external form platform or building an Experience Cloud portal.

The strongest launch wedge is not maximum enterprise depth. It is a combination of:

- Native Salesforce app experience.
- Lower per-org pricing.
- Public forms without Experience Cloud setup.
- Salesforce-focused prefill and submit flows.
- Secure Salesforce update links protected by user-verification verification.
- Custom objects and standard objects.
- Advanced Pro behavior such as custom JavaScript and live calculations.
- Simpler admin mental model than broad external form platforms.

## Competitor Summary Table

| Competitor | Category | Commercial Strength | Salesforce Native Fit | Main Strength | Main Opening For TwinaForms | Risk Level |
|---|---|---:|---:|---|---|---|
| FormAssembly | Enterprise Salesforce form platform | Very high | High | Mature Salesforce-focused data collection, enterprise trust, compliance positioning | Too heavy or expensive for smaller Salesforce teams | High |
| Formstack | Enterprise workflow/form platform | Very high | Medium | Broad form, workflow, document, and automation platform | External platform complexity and higher-cost positioning | High |
| Jotform | General form platform with Salesforce integration | Very high | Medium | Huge general form product, templates, payments, signatures, competitive per-user pricing | Not Salesforce-native first; per-user pricing can become expensive for teams | High |
| BreezyBit | Salesforce-native/near-native form builder | Low to medium | High | Direct Salesforce-native builder story, simple demo, likely Salesforce-hosted public forms | High entry price; likely less flexible for arbitrary custom JavaScript/live calculations | High |
| 123FormBuilder | General form builder with Salesforce integration | Medium | Low to medium | Mature general form builder and integrations | Less native Salesforce experience | Medium |
| Forms Made Easy | Salesforce-focused form builder | Low to medium | High | Salesforce-focused/native positioning | Less public scale; TwinaForms can compete on pricing, UX, and public runtime | Medium |

## Competitor Categories

### Enterprise Salesforce Form Platforms

Examples: FormAssembly, Formstack.

These products are mature and trusted. They are strong for larger companies, regulated use cases, complex data capture, procurement, and compliance/security review.

TwinaForms should not try to beat them feature-for-feature at launch.

### General External Form Platforms With Salesforce Integration

Examples: Jotform, 123FormBuilder.

These products are strong general form builders. They usually win on templates, payments, signatures, large feature sets, broad integrations, and brand recognition.

Their weakness for TwinaForms is that they are still external form platforms first, with Salesforce as one integration path.

### Salesforce-Native Or Near-Native Form Builders

Examples: BreezyBit, Forms Made Easy.

These are closest to TwinaForms in product story. They are dangerous because they speak directly to Salesforce admins and can look easier to set up.

TwinaForms must compete with these on clarity, price, setup simplicity, and Pro-level flexibility.

## FormAssembly

### What It Is

FormAssembly is a mature Salesforce-focused form and data collection platform. It is one of the strongest known competitors in the Salesforce form space.

### Strengths

- Longstanding Salesforce ecosystem presence.
- Strong enterprise trust and procurement credibility.
- Known for complex Salesforce mapping and data collection use cases.
- Strong compliance/security positioning.
- Likely familiar to many Salesforce consultants and admins.
- Advertises in AppExchange search for form-related terms, which suggests active acquisition budget.

### Weaknesses Or Openings For TwinaForms

- Heavier and more expensive than a simple Salesforce-native form app.
- Broader enterprise platform, not necessarily the simplest experience for small Salesforce teams.
- May feel like adopting another full product ecosystem.
- Its Salesforce form creation flow appears to be field-selection based: admins choose a Salesforce object and then pick fields for the form. In observed behavior, it does not reuse the admin's existing Salesforce page layout as the form blueprint.
- The observed Salesforce-generated form path is limited for TwinaForms' target use case: it creates a Salesforce submit/link workflow, but does not preserve existing layout sections/columns, does not use the Salesforce page layout as source, and does not provide the same multilingual layout import story.

### TwinaForms Position Against FormAssembly

Do not compete directly on enterprise compliance or feature breadth at launch.

Compete as:

> A simpler, lower-cost Salesforce-native form app for teams that do not need a heavy enterprise form platform.

For the Create From Salesforce Layout feature, use a sharper message:

> TwinaForms turns an existing Salesforce page layout into a secure multilingual external form.

This is stronger than generic Salesforce field mapping. The value is that the Salesforce admin's existing object layout becomes the starting point: sections, field order, columns, translated Salesforce field labels, translated picklist and multi-picklist option labels, and Salesforce API values for submit are preserved where Salesforce provides the metadata. This reduces setup time and avoids the common admin mistake of rebuilding a public form manually from object fields.

### Competitive Risk

High for enterprise customers. Medium for small Salesforce teams if TwinaForms messaging and pricing are clear.

## Formstack

### What It Is

Formstack is a mature form/workflow/productivity platform with Salesforce integration.

### Strengths

- Mature brand and broad platform.
- Strong workflow, document, signature, and automation ecosystem.
- Enterprise-friendly positioning.
- Known in the general business forms market.

### Weaknesses Or Openings For TwinaForms

- External platform model.
- Can feel broad/heavy for a Salesforce admin who only wants public forms connected to Salesforce.
- Pricing and product packaging can be more than a small team needs.

### TwinaForms Position Against Formstack

Compete on Salesforce focus and simplicity:

> Public Salesforce forms without adopting a broad external workflow platform.

### Competitive Risk

High as a general form/workflow competitor. Medium as a direct Salesforce-native builder competitor.

## Jotform

### What It Is

Jotform is a large horizontal form platform with Salesforce integration and an AppExchange app.

Public signals indicate that Jotform is commercially large:

- Founded in 2006.
- Publicly claims tens of millions of users.
- Publicly claims billions of form submissions.
- Large template library.
- Broad product set including forms, PDFs, signatures, payments, approvals, tables, AI features, and integrations.

Jotform for Salesforce appears to embed or expose Jotform functionality inside Salesforce, but the builder remains clearly Jotform-branded and Jotform-platform-oriented.

### Strengths

- Very large company and user base.
- Very mature general form builder.
- Strong templates and ease of use.
- Competitive public pricing.
- Broad features: payments, signatures, uploads, workflows, PDFs, integrations.
- AppExchange presence.
- Good option for simple or medium Salesforce-connected forms.

### Pricing Observations

Public/AppExchange-visible pricing discussed:

- Bronze: about $39 USD/user/month.
- Silver: about $49 USD/user/month.
- Gold: about $129 USD/user/month.
- Enterprise/custom pricing for larger needs.

Plan details observed:

- Lower paid plans remove Jotform branding.
- Custom branding and custom domain appear to be Enterprise/custom.
- HIPAA features appear only on higher plans.

### Weaknesses Or Openings For TwinaForms

- Jotform is a general external form platform first, not a Salesforce-native product first.
- Salesforce admins may need to learn Jotform concepts, account model, builder, and workspace behavior.
- The product experience can feel embedded in Salesforce rather than native to Salesforce.
- Pricing is per user/month. TwinaForms can be more attractive if priced per org/workspace.
- Salesforce-specific depth is less publicly proven than FormAssembly.

### TwinaForms Position Against Jotform

TwinaForms should not claim to beat Jotform on templates, payments, signatures, or broad form features.

TwinaForms should compete as:

> A focused Salesforce-native public form app with team-friendly pricing and no need to adopt a general external form platform.

If TwinaForms Starter is $50/month per org and Pro is $120/month per org, the comparison becomes strong for teams:

- Jotform Silver for 3 users: about $147/month.
- TwinaForms Starter for a small team: about $50/month if priced per org/workspace.

### Competitive Risk

High in small business and general form searches. Medium-high in Salesforce searches because the Salesforce app is newer and less Salesforce-specialist than FormAssembly.

## BreezyBit

### What It Is

BreezyBit Form Builder appears to be a very direct competitor to TwinaForms. It positions around Salesforce-native form building and has public demo videos showing a form builder inside Salesforce.

Public signals suggest BreezyBit may be a small or founder-led company, but this is not confirmed. Its product story is still serious and directly relevant.

### Strengths

- Very direct Salesforce-native positioning.
- Form builder appears inside Salesforce.
- Familiar builder layout: field/object list, form canvas, settings panel.
- Clear message that data stays in Salesforce.
- Public demo suggests simple setup and admin-friendly UX.
- Public form link pattern observed as `breezybit.my.site.com/form?...`, which suggests use of Salesforce public site / Experience Cloud / Sites infrastructure.
- Pricing is high enough that TwinaForms can undercut strongly.

### Pricing Observations

Public pricing observed:

- Essentials: about $349/month yearly, or $399/month monthly.
- Professional: about $449/month yearly, or $499/month monthly.
- Enterprise: about $599/month yearly, or $699/month monthly.
- Additional Enterprise user blocks: about $150/month per 5 users.

### Weaknesses Or Openings For TwinaForms

- Much higher entry price than TwinaForms proposed pricing.
- If the runtime depends on Salesforce public site / Experience Cloud / `my.site.com`, customers inherit Salesforce guest-user/site constraints.
- It may be less flexible for arbitrary customer-authored JavaScript and live calculations.
- Custom arbitrary JavaScript inside Salesforce Experience Cloud/Sites is difficult to expose safely due to Salesforce CSP, Lightning Web Security, managed package review expectations, and public-site security concerns.

Important: this does not mean BreezyBit cannot support declarative logic or packaged JavaScript features. It means customer-authored arbitrary JavaScript is likely harder for them to offer cleanly.

### Experience Cloud / Sites Consideration

The observed `my.site.com` style public URL suggests Salesforce-hosted public form pages.

This may help BreezyBit say:

> No external platform. Data stays in Salesforce.

However, it also creates a TwinaForms counter-position:

> Public forms managed from Salesforce without requiring customers to manage Experience Cloud or Salesforce public-site runtime details.

For unauthenticated public visitors, Salesforce Sites/guest-user behavior may avoid per-external-user Experience Cloud licenses, but it still depends on Salesforce public-site security, guest permissions, org/site setup, limits, and platform behavior.

### TwinaForms Position Against BreezyBit

BreezyBit is probably the closest product competitor.

TwinaForms should compete on:

- Much lower price.
- Simpler starter product.
- No Experience Cloud/Sites setup requirement.
- AWS public runtime kept behind the scenes.
- Custom JavaScript and live calculations as Pro differentiators.
- Salesforce remains the source of truth.

Do not lead with "hosted on AWS." Lead with:

> Create and manage public forms directly from Salesforce, without building an Experience Cloud portal.

### Competitive Risk

High as a direct product/story competitor. Lower as a commercial scale competitor if the company is small, but this should not be dismissed.

## 123FormBuilder

### What It Is

123FormBuilder is a general form builder with Salesforce integration.

### Strengths

- Mature general form-builder category product.
- Salesforce integration.
- Templates and broad form features.
- Lower barrier for simple web forms.

### Weaknesses Or Openings For TwinaForms

- Less Salesforce-native than TwinaForms.
- External platform model.
- May be less attractive to Salesforce admins who want objects, package tabs, permissions, and Salesforce-first setup.

### TwinaForms Position Against 123FormBuilder

Compete on Salesforce-native focus:

> A Salesforce-first app, not a general form tool with a Salesforce connector.

### Competitive Risk

Medium. Strong for general form buyers, weaker for Salesforce-native buyers.

## Forms Made Easy

### What It Is

Forms Made Easy appears to be a Salesforce-focused/native form builder competitor.

### Strengths

- Salesforce-focused positioning.
- Likely appeals to admins looking for native Salesforce form creation.
- Directly relevant in AppExchange-style comparisons.

### Weaknesses Or Openings For TwinaForms

- Public commercial scale appears lower than larger players.
- Need more direct feature/pricing investigation before final comparison.
- TwinaForms may compete with clearer pricing, public runtime story, and Pro flexibility.

### TwinaForms Position Against Forms Made Easy

Compete on simplicity, pricing, public form runtime, and advanced Pro features.

### Competitive Risk

Medium. Needs deeper follow-up research.

## Feature Themes And Differentiators

### Salesforce-Native Experience

Many competitors integrate with Salesforce. Fewer feel truly Salesforce-native.

TwinaForms should use this distinction carefully:

- Avoid: "The only native Salesforce form builder."
- Use: "A Salesforce-native app experience for building and managing public forms."

### No Experience Cloud Required

This is likely one of TwinaForms' strongest differentiators.

Recommended wording:

> Publish public forms without building an Experience Cloud portal.

Avoid making Experience Cloud sound bad. Many customers use it successfully. The point is that TwinaForms reduces setup burden for teams that only need forms.

### AWS Runtime

Do not lead with AWS as the product benefit.

Customers care about outcomes:

- Public forms load outside Salesforce.
- Salesforce remains the source of truth.
- Operational data is encrypted on AWS.
- The public runtime can validate form context before prefill and submit.

Recommended wording:

> Salesforce stays the source of truth. TwinaForms uses a secure AWS runtime for public form access.

### Custom JavaScript And Live Calculations

This can become an important Pro differentiator.

Competitors using Salesforce-hosted Experience/Sites may find arbitrary customer-authored JavaScript harder to expose safely because of CSP, Lightning Web Security, and managed-package/public-site review concerns.

Recommended wording:

> Advanced live form behavior, including calculations and custom JavaScript, without requiring customers to relax Experience Cloud security settings.

### Pricing

Proposed TwinaForms pricing:

- Free: limited trust-building plan.
- Trial: time-limited full evaluation.
- Starter: $50/month per org/workspace.
- Pro: $120/month per org/workspace.

This pricing is especially strong if positioned against:

- BreezyBit at about $349/month+.
- Jotform per-user pricing.
- FormAssembly/Formstack enterprise-oriented pricing.

Recommended pricing language:

> Simple per-org pricing for Salesforce teams.

## Risks

### Setup Complexity

TwinaForms setup is now being simplified through Bootstrap V2 so customers should not need to create Salesforce service credentials manually.

This is the biggest onboarding risk.

Mitigation:

- Keep improving the Connect page.
- Make setup language simple.
- Automate what can be automated.
- Make errors specific and helpful.

### AppExchange Trust

Customers will compare trust signals.

Mitigation:

- Strong website.
- Security documentation.
- ZAP/DAST report package.
- Salesforce Code Analyzer responses.
- Clear privacy and terms pages.
- Explain AWS/Salesforce boundaries simply.

### Feature Breadth

Jotform and Formstack have much broader feature sets.

Mitigation:

- Do not chase all features.
- Stay focused on Salesforce forms, prefill, submit, custom objects, and public runtime.

### Enterprise Compliance

Do not claim HIPAA, PCI, FedRAMP, or similar compliance unless the business intentionally builds the required program and agreements.

Safe language:

> Encrypted storage and Salesforce-controlled access.

Avoid:

> HIPAA compliant.

## Recommendation

TwinaForms should launch with a focused low-cost Salesforce strategy.

Recommended positioning:

> Simply create public forms directly from Salesforce.

Recommended longer positioning:

> TwinaForms is an affordable Salesforce-native public form app for teams that need prefill, submit, and Salesforce writeback without building an Experience Cloud portal or adopting a heavy external form platform.

Recommended market lane:

- Below FormAssembly/Formstack on cost and complexity.
- More Salesforce-native and team-priced than Jotform.
- Much cheaper and more flexible than BreezyBit.
- More focused than generic form builders.

Recommended plan framing:

- Starter: simple public Salesforce forms, secure Salesforce update links with user-verification verification, ready-to-use Salesforce registration form, prefill, submit, standard/custom objects, enough limits for real small teams.
- Pro: custom JavaScript, live calculations, file uploads, higher limits, advanced form behavior, and richer registration kit capabilities.
- Enterprise/custom later: custom domains, special security requirements, higher scale, hands-on support.

Current corrected Pro competitor-parity backlog:

Ordered from easiest to most complex:

| Order | Feature | Complexity | Why It Matters |
|---:|---|---|---|
| 1 | Clone field / clone section | Low | Speeds common Designer work and helps admins build repeated layouts faster. |
| 2 | Clone form | Low-medium | Lets admins reuse successful forms for new campaigns, departments, or demo scenarios. |
| 3 | Salesforce-focused template library | Medium | Helps TwinaForms feel ready on day one with practical Salesforce examples. |
| 4 | Survey field styles | Implemented as Pro V1 foundation | Adds competitor-parity survey UX: 1-5 star rating, NPS 0-10, Likert scale, ranking, and satisfaction scale. |
| 5 | Multi-page forms with progress | Medium-high | Makes long forms feel organized and reduces abandonment. |
| 6 | Registration kit | Medium-high | Builds on the Starter registration template with capacity, waitlist, cancellation/update links, attendance status, and optional TwinaForms registration objects. |
| 7 | Submission PDF | High | Gives customers a human-readable record of each submission for audit, application, consent, and service workflows. |
| 8 | Save and resume | High | Supports long forms where respondents may need to return later. |
| 9 | Electronic signature | Highest | Adds consent/approval value but brings audit, storage, PDF, and expectation complexity. |

Do not treat attaching uploaded files to Salesforce as missing. TwinaForms already supports attaching uploaded files to the Salesforce submit target object. Survey parity is covered by the Pro `enableProSurveyFields` foundation; normal Yes/No, checklist, comments, and long-text inputs are already covered by existing field types.

Recommended website emphasis:

- Native Salesforce app.
- Public forms without Experience Cloud.
- Create secure multilingual external forms from existing Salesforce page layouts.
- Secure Salesforce update links protected by user-verification verification.
- Ready-to-use Salesforce registration forms.
- Salesforce remains the source of truth.
- Affordable per-org pricing.
- Pro flexibility with calculations and custom JavaScript.

Recommended product priority:

1. Make onboarding feel simple and reliable.
2. Keep Salesforce/AWS trust language clear.
3. Polish first-run demo/install flow.
4. Make Starter and Pro differences obvious.
5. Prepare AppExchange documentation and security evidence.

TwinaForms does not need to beat every competitor everywhere. The launch opportunity is to be the clear, affordable, Salesforce-native public form app for teams that think the established options are too expensive, too external, or too heavy.

## Sources

- FormAssembly: https://www.formassembly.com/
- Formstack Salesforce: https://www.formstack.com/salesforce
- Jotform About: https://www.jotform.com/about/
- Jotform Salesforce integration: https://www.jotform.com/integrations/salesforce/
- Jotform Salesforce forms: https://www.jotform.com/salesforce-forms/
- Jotform pricing: https://www.jotform.com/pricing/
- Jotform AppExchange announcement: https://www.prnewswire.com/news-releases/jotform--powerful-online-forms-and-workflow-automation-for-salesforce-now-available-on-the-salesforce-appexchange-301918022.html
- BreezyBit Form Builder: https://breezybit.com/products/form-and-survey-builder/
- BreezyBit pricing: https://breezybit.com/pricing/
- BreezyBit live demo: https://www.youtube.com/watch?v=llh9z1yFu4Y
- 123FormBuilder Salesforce: https://www.123formbuilder.com/salesforce/
- Salesforce Experience Cloud pricing: https://www.salesforce.com/products/experience-cloud/pricing/
- Salesforce Lightning CSP documentation: https://developer.salesforce.com/docs/platform/lightning-components-security/guide/content-security-policy-intro.html
- Salesforce third-party JavaScript in LWC: https://developer.salesforce.com/docs/platform/lwc/guide/js-third-party-library
- Salesforce Lightning Web Security trusted mode: https://developer.salesforce.com/docs/platform/lightning-components-security/guide/lws-trusted-mode.html
