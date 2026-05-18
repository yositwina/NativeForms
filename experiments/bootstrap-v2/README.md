# Bootstrap V2 Experiment

Status: Experimental only

Branch: `bootstrap-v2-spike`

This folder is the working area for the Bootstrap V2 spike. It is intentionally separate from the production AWS and Salesforce package paths so the experiment can be reviewed, removed, or promoted deliberately.

## Purpose

Bootstrap V2 explores replacing the current manual tenant-secret setup with:

- OAuth-verified one-time bootstrap.
- Salesforce-generated per-org signing secret.
- Protected managed package storage.
- HMAC-signed Salesforce-to-AWS calls.

## Folder Rules

- Keep spike notes, sample payloads, local scripts, and temporary test material here.
- Do not put production Lambda code here.
- Do not put deployable Salesforce metadata here; Salesforce metadata must still live under `force-app/main/default`.
- Any deployable spike code added under `AWS` or `force-app` must be clearly named `BootstrapV2` / `bootstrap-v2` and treated as experimental.
- Do not change the existing Connect UI during phase 1.
- Do not remove the current manual tenant-secret flow during phase 1.
- Do not create a package from this branch unless explicitly approved.

## Expected Spike Layout

Potential files to add later:

- `payloads/` - sample signed requests, bootstrap responses, and replay-test examples.
- `notes/` - test notes and security review notes.
- `scripts/` - local-only helpers for HMAC verification and mock request generation.

## Source Spec

See:

- `AWS/documentation/Technical and specs/TwinaForms_Bootstrap_V2_Spike.md`

## Current Manual Test Boundary

Phase 1 and the direct Phase 2 Salesforce REST smoke test have passed.

The next required manual test is a real browser OAuth connection against a test tenant, followed by checking the per-org AWS Salesforce connection secret for `bootstrap_v2_status: ready`.
