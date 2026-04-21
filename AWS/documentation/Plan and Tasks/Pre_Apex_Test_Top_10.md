# Pre-Apex Test Top 10

Last updated: 2026-04-21

## Purpose

This is the short working list of what is still worth finishing **before** starting Apex test classes for package readiness.

This list is intentionally limited to the highest-signal engineering / product items only.

It does **not** try to include:

- package creation itself
- AppExchange listing work
- legal / billing / website launch work
- Cognito / admin auth hardening unless it directly blocks current product validation

## Recommended Remaining Items Before Apex Tests

0. clean ver number on pages (top left)
1. Run one full Starter manual QA pass in the current dev org
- Cover:
  - setup / connect
  - projects
  - designer
  - publish
  - prefill
  - submit
  - themes
  - multilingual
  - secret code
  - file upload
  - formula fields
  - logs
- Goal: find remaining product issues before formal Apex test investment.

2. Run one clean-org regression pass before Apex test design
- Validate that the current package-visible metadata and setup flow still behave correctly in a clean org.
- Focus on:
  - object/tab visibility
  - permission sets
  - TwinaForms Admin app
  - connect/setup flow
  - default seeded records like `General` and `Archive`

3. Freeze the pre-test scope and only then start Apex tests
- Once the items above are stable enough, freeze the feature surface for the Starter package baseline.
- Then begin Apex test classes against that stabilized behavior instead of chasing moving UI/runtime targets.

## Notes

- Multilingual support, Project organization, Formula Fields, and the main Designer / Prefill / Submit help cleanup are now implemented enough that they should be validated through QA, not kept as separate pre-test backlog items.
- Cognito, payment flow, AppExchange assets, and commercial launch work remain important, but they should not be mixed into the “before Apex tests” engineering list unless priorities change.
