# TwinaForms Upgrade Page

Simple static landing page for `https://twinaforms.com/upgrade`.

## Files

- `index.html`
- `styles.css`
- `app.js`

## Data source

The page reads live plan definitions from:

- `GET /public/plans` on `NativeFormsBackend`

That endpoint resolves plan limits and enabled feature names/descriptions from DynamoDB-backed plan and settings data.
