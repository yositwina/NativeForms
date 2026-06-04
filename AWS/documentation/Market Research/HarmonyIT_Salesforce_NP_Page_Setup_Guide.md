# Setup Guide — Adding "Salesforce לעמותות" Page to harmony-it.co.il

**Page content file:** [HarmonyIT_Salesforce_NP_Page_Content.html](./HarmonyIT_Salesforce_NP_Page_Content.html)
**Target URL:** `https://harmony-it.co.il/salesforce-for-nonprofits/`
**Time required:** 20–30 minutes, no coding skills needed.

---

## Before you start — what you'll need

1. WordPress admin login (you have this)
2. The HTML file: [HarmonyIT_Salesforce_NP_Page_Content.html](./HarmonyIT_Salesforce_NP_Page_Content.html)
3. To know what page builder is installed — we'll figure that out in Step 2 below

---

## Step 1 — Log in to WordPress

1. Open a browser, go to: **`https://harmony-it.co.il/wp-admin`** (or `/wp-login.php` — both work)
2. Enter your admin username and password
3. You'll land on the **Dashboard** (לוח בקרה)

If the URL above doesn't work, your admin may be at a custom path. Check with whoever set up the site for the correct admin URL.

---

## Step 2 — Identify your page builder

Different page builders need different paste methods. Quick way to know which you have:

1. In the left sidebar of WordPress admin, look for: **Plugins → Installed Plugins** (תוספים → תוספים מותקנים)
2. Look for one of these names in the list:

| If you see this plugin (active) | Then you're using |
|---|---|
| **Elementor** | Elementor — use Method A below |
| **Beaver Builder**, **Divi Builder**, **WPBakery** | Other builder — use Method A (still works with HTML widget) |
| Nothing of the above, or only **Classic Editor** | Gutenberg or Classic — use Method B below |

You can also just go ahead and create a new page (Step 3) and see what editor opens. If you see colorful drag-drop blocks with an "edit with Elementor" button — it's Elementor. If you see blue "+" buttons to add blocks — it's Gutenberg.

---

## Step 3 — Create a new page

1. In the left sidebar: **Pages → Add New** (דפים → הוסף חדש)
2. **Title field:** type — **`Salesforce לעמותות – 10 רישיונות חינם לניהול מתנדבים ותורמים`**
   - This is what shows as the page title in search results and the browser tab
3. **URL slug:** Look for a "Permalink" or "URL" field — usually right under the title or in the right sidebar. Set it to: **`salesforce-for-nonprofits`**
   - Final URL becomes `https://harmony-it.co.il/salesforce-for-nonprofits/`

Don't publish yet — we need to add the content first.

---

## Step 4 — Paste the page content

Open `HarmonyIT_Salesforce_NP_Page_Content.html` in any text editor (Notepad on Windows works). **Select all** (`Ctrl+A`) and **copy** (`Ctrl+C`). You'll paste this in one of the methods below.

### Method A — Elementor (or any builder with an HTML widget)

1. On the page edit screen, click the big blue button **"Edit with Elementor"** (ערוך עם Elementor)
2. The Elementor editor opens. You'll see your site's layout on the right, widgets list on the left.
3. In the left widgets panel, search (search box at top): **`HTML`**
4. Drag the **HTML widget** onto the page (drag it into the page area on the right)
5. A panel opens with a code text area
6. Paste (`Ctrl+V`) the entire HTML you copied
7. Click the green **"Update"** button at the bottom-left of the Elementor panel
8. Page is saved. Click "Preview" (eye icon) to see it.

### Method B — Gutenberg (the default WordPress editor)

1. On the page edit screen, you'll see "+" buttons. Click any "+"
2. In the popup search, type: **`HTML`**
3. Pick **"Custom HTML"** (HTML מותאם אישית)
4. A code text area opens
5. Paste (`Ctrl+V`) the entire HTML
6. Click **"Update"** or **"Publish"** at the top-right

### Method C — Classic Editor (if you see one big toolbar like Microsoft Word)

1. In the content area at the top-right of the box, you'll see two tabs: **"Visual"** and **"Text"** (חזותי / טקסט)
2. Click **"Text"** — this gives you a raw HTML editor
3. Paste (`Ctrl+V`) the entire HTML
4. Click **"Update"** or **"Publish"** on the right

---

## Step 5 — SEO settings

Look in the page editor for one of these SEO plugin panels (usually below the content area or in a right sidebar):

- **Yoast SEO** (red and white "Y" icon)
- **Rank Math** (yellow icon with "RM")
- **All in One SEO (AIOSEO)** (blue icon)

If you see any of them, fill in these fields:

| Field | Value |
|---|---|
| **SEO Title / Meta Title** | `Salesforce לעמותות – 10 רישיונות חינם, ניהול מתנדבים ותורמים \| Harmony IT` |
| **Meta Description** | `מדריך מקיף ל-Salesforce לעמותות: 10 רישיונות חינם דרך Power of Us, NPSP, ניהול מתנדבים ותורמים, ואיך לחבר טפסים בעברית. ייעוץ בעברית מ-Harmony IT.` |
| **Focus Keyword / Keyphrase** | `Salesforce לעמותות` |
| **URL Slug** | `salesforce-for-nonprofits` (already set in Step 3) |

If you don't see any SEO plugin — that's a separate issue (the title and meta will still come from WordPress defaults, which is OK but suboptimal). You can install Rank Math (free) later.

---

## Step 6 — Add to main navigation menu (optional but recommended)

So visitors can find the page from the menu:

1. **Appearance → Menus** (מראה → תפריטים)
2. On the left, find your new page in the list (it'll be under "Pages")
3. Check the box next to it
4. Click **"Add to Menu"** (הוסף לתפריט)
5. The page appears in the menu list on the right — you can drag it to the position you want
6. Recommended: place it between "Salesforce System" and "Successes" (or anywhere under your Salesforce section)
7. You may also want to rename it shorter in the menu: just type something like `Salesforce לעמותות` in the navigation label
8. **Save Menu** (שמור תפריט)

---

## Step 7 — Publish the page

Back on the page edit screen:

1. **For Elementor:** click the up-arrow next to "Update" → choose "Publish"
2. **For Gutenberg/Classic:** click the big blue **"Publish"** button at the top-right

The page is now live at `https://harmony-it.co.il/salesforce-for-nonprofits/`.

Test it: open the URL in a new browser tab. You should see your new page with the styled hero, table of contents, sections, FAQ, and CTAs.

---

## Step 8 — Submit to Google Search Console (optional, ~5 minutes)

If you want Google to find the page within 24–48 hours instead of 1–2 weeks:

1. Go to **`https://search.google.com/search-console`**
2. Make sure `harmony-it.co.il` is added as a property (if it's not — that's a separate setup)
3. In the URL search bar at the top, paste: `https://harmony-it.co.il/salesforce-for-nonprofits/`
4. Click **"Request Indexing"**
5. Google adds it to the priority crawl queue

---

## What can go wrong + how to fix it

### Problem: The page looks unstyled (no colors, no boxes, just plain text)

Your theme is stripping `<style>` tags. Two fixes:

- **Fix 1 (easiest):** ask whoever maintains the site to add `safe_style_css` allowlist for inline styles, OR
- **Fix 2:** I can rebuild the HTML using only inline `style="..."` attributes instead of a `<style>` block. Just tell me and I'll regenerate.

### Problem: The Hebrew text shows as boxes or question marks

The page is not being served with UTF-8 encoding. Add `<meta charset="utf-8">` at the very top of your theme's `header.php`, or use a plugin like "Encoding Override". Most modern WP setups handle this automatically — if it's an issue, ask the site maintainer.

### Problem: The page direction is left-to-right instead of right-to-left

The `dir="rtl"` attribute is set on the page content wrapper, so RTL should work even if the theme is LTR. If it doesn't:
- Check that your theme has Hebrew/RTL support
- The HTML I built includes `dir="rtl"` and `lang="he"` on the wrapper div, which should force the right direction regardless

### Problem: Schema (FAQPage) doesn't show up in Google

Use Google's Rich Results Test: paste your page URL at `https://search.google.com/test/rich-results` — it'll tell you if the FAQPage schema is being detected.

If schema is missing: your theme may be stripping `<script>` tags. Switch the editor to use a different paste method, or add the schema separately via Yoast/Rank Math's structured data settings.

### Problem: The CTA buttons aren't clickable / open weirdly

Each CTA is either a `mailto:`, `tel:`, or `https://wa.me/...` link. Test that:
- `mailto:revital@harmony-it.co.il` opens your default mail client
- `tel:+972584938049` opens the phone dialer (mobile only)
- `https://wa.me/972584938049` opens WhatsApp

If you want to change the destination email/phone, edit the HTML before pasting (search for `revital@harmony-it.co.il` and `972584938049`, replace as needed).

---

## What I built into the page — content checklist

For your reference, here's what's in the page (so you can verify nothing was lost in paste):

- [x] H1 with primary keyword + 10 free licenses hook
- [x] Lead paragraph + TLDR box + top CTA
- [x] Table of contents (auto-linked to chapters)
- [x] Chapter 1: Why NP data management breaks (with competitor alternatives paragraph — Excel, Google Forms, Monday, Priority, SAP)
- [x] Chapter 2: Salesforce + Power of Us 10 free licenses
- [x] Chapter 3: NPSP intro + key objects
- [x] Chapter 4: 5 areas Salesforce solves for NPs
- [x] Chapter 5: Real-world examples (4) + Eyal Epilepsy customer story callout with link to twinaforms.com
- [x] Chapter 6: Why forms are critical
- [x] Chapter 7: TwinaForms intro + cross-links to /he/np.html and /he/solutions/npsp/volunteer-signup-form/
- [x] Chapter 8: NPSP glossary (10 terms)
- [x] Mid-page CTA
- [x] Chapter 9: Why Harmony IT
- [x] FAQ with 15 questions (display + JSON-LD schema)
- [x] Closing CTA
- [x] BreadcrumbList JSON-LD schema
- [x] FAQPage JSON-LD schema (15 entries)
- [x] All CTAs route to: `revital@harmony-it.co.il` (email) / `058-4938049` (phone) / WhatsApp
- [x] Hebrew Rubik (headings) + Assistant (body) typography via Google Fonts (loaded by the HTML)
- [x] Mobile responsive layout

---

## Bottom line

You should be able to follow Steps 1–7 in under 30 minutes. If anything looks off after publishing — send me a screenshot of what you're seeing and I'll diagnose. The content itself is ~2,800 Hebrew words across 9 chapters + 15 FAQ entries — that's a substantial guide-style page targeting the keywords we identified.
