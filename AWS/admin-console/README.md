# NativeForms Admin Console Prototype

This folder contains the first static prototype for the AWS-hosted Admin Control App.

## What it is

- plain HTML, CSS, and JavaScript
- no build step
- safe to open locally in a browser
- ready to upload directly to S3 for simple testing

## Current scope

- app shell
- primary `Tenants` screen
- search and filters
- mock tenant table
- tenant detail side panel

## Next planned step

Replace mock data in `app.js` with the future Admin API:

- `GET /admin/tenants`
- `GET /admin/tenants/{orgId}`
- `GET /admin/plans`

## How to use

Open:

- `AWS/admin-console/index.html`

or upload the folder contents to an S3 bucket configured for static hosting.
