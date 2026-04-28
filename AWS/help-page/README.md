# TwinaForms Help Pages

Static landing pages for the Help section on `https://twinaforms.com/help/...`.

## Pages

- `formulas.html` — served at `https://twinaforms.com/help/formulas`.
- `custom-javascript.html` — served at `https://twinaforms.com/help/custom-javascript`.

## Styling

All help pages share `styles.css`, which extends the visual language used on the Upgrade page (same font stack, accent color, card radius, shadow). Added for the help context:

- `.code-block` — dark code panel for copy-paste examples.
- `.inline` — light pill for inline literal references (`{fieldKey}`, `"Hot"`, etc.).
- `.fn-grid` / `.fn-card` — compact function reference cards.
- `.example-block` — title + description + code for each example.
- `.section-nav` — in-page anchor chips at the top of the hero.
- `.callout` — warm tip banner.

## Data source

These pages are fully static. No backend calls — just HTML + CSS + web fonts.

## Content ownership

Formula engine facts on `formulas.html` are derived from the implementation. If the engine gains new functions or operators, update `formulas.html` to match. Source of truth:

- `AWS/NativeFormsBackend/formulaEngine.js`
- `force-app/main/default/classes/NativeFormsPublisher.cls` (runtime evaluator bridge)
- `AWS/documentation/Technical and specs/NativeForms_Formula_Pro_Spec.md` (spec)
