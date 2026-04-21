# NativeForms Post Submit Pro Spec

## Purpose
This document captures the agreed design for the NativeForms post-submit success flow so it can be implemented later without losing the product, UX, and technical decisions.

This is a `Pro` feature.

---

## Plan Placement

### Commercial Packaging
- plan: `Pro`
- not included in: `Starter`

### Why It Is Pro
- post-submit next-step flow is part of guided multi-step experiences
- redirect behavior increases support and QA complexity
- it is more advanced than a normal thank-you message
- it is a strong upgrade feature for customers building semi-flow experiences

---

## Feature Goal
Allow a form to complete submission and then automatically move the user to the next step.

Typical use cases:
- step 1 form redirects to step 2 form
- redirect to payment page
- redirect to document/download page
- redirect to confirmation or onboarding step

The experience should feel smooth and intentional, not abrupt.

---

## Product Decision

### Agreed UX Direction
The preferred user experience is:
- show a short success state first
- then redirect automatically to the next-step URL
- also show a manual fallback button or link

### Why
- user sees confirmation that submit worked
- flow continues automatically
- fallback exists if redirect is blocked or delayed

---

## Scope for V1

### Included
- success title
- success message
- post-submit next-step URL
- post-submit button label
- redirect delay in seconds
- automatic redirect after successful submit
- manual fallback button:
  - `Continue now`
  - or custom label

### Not Included in V1
- conditional redirect logic
- different redirects by submit outcome
- formula-generated redirect URLs
- opening the next step in a new tab
- branching by plan or user profile
- token forwarding rules beyond simple query passthrough

---

## Recommended Runtime Behavior

### If No Redirect URL Is Defined
- show normal success state only
- do not redirect

### If Redirect URL Is Defined
1. submit succeeds
2. success screen appears
3. countdown starts
4. user is automatically redirected
5. manual fallback button is visible immediately

### Recommended Default Delay
- `2` or `3` seconds

This gives enough time for the user to see success without making the flow feel slow.

---

## Admin Configuration

### Proposed Fields
- `Enable Post Submit Redirect`
- `Success Title`
- `Success Message`
- `Redirect URL`
- `Redirect Button Label`
- `Redirect Delay Seconds`

### Recommended Defaults
- `Enable Post Submit Redirect = false`
- `Success Title = Thank you`
- `Success Message = Your form was submitted successfully.`
- `Redirect Button Label = Continue`
- `Redirect Delay Seconds = 3`

---

## UI / Authoring Design

### Recommended Location
The settings should live in the form-level publish/runtime area, not inside a single submit action.

Reason:
- redirect is a form experience decision
- it should apply after the full form succeeds
- it is not tied to one specific mapped field

### Suggested Future Page Placement
One of these is acceptable:
- `Designer` left panel or form-level settings area
- later dedicated runtime/publish settings area

Best long-term model:
- form-level runtime settings

---

## Success Screen Design

### Layout
- success title
- success message
- optional small countdown text:
  - `Continuing in 3 seconds...`
- primary button:
  - custom label or `Continue`

### Visual Behavior
- should use the assigned theme
- same fonts, colors, and button styles as the form
- should feel like part of the same experience, not a browser alert

---

## Redirect Rules

### Validation
- redirect URL must be a valid URL
- delay must be a non-negative integer
- empty URL means redirect is off

### Safe Behavior
- if redirect URL is invalid:
  - do not redirect
  - show success state only
  - log the issue for admin/debugging

### Countdown
- countdown is optional but recommended
- if implemented, keep it simple:
  - `Continuing in 3...`
  - `Continuing in 2...`
  - `Continuing in 1...`

---

## Query String / Context Handling

### V1 Recommendation
Keep redirect URL simple.

Supported:
- static absolute URL
- static relative URL if needed later

Not included in V1:
- advanced token merge
- automatic form output injection into the URL

Reason:
- reduces security risk
- keeps implementation predictable

---

## Runtime / Technical Requirements

### Published HTML Must Support
- success-state rendering after submit success
- optional timer
- redirect via `window.location`
- manual continue button

### Publisher Must Emit
- success flow settings into the published form config

### AWS Submit Runtime
No special AWS submit command change is required for the redirect itself.

The redirect happens after:
- successful submit response from the runtime

So the main implementation is in:
- `NativeFormsPublisher.cls`
- published HTML generation/runtime JS

---

## Failure Behavior

### If Submit Fails
- do not show success screen
- do not redirect
- show the normal error state

### If Redirect Fails
- keep the success screen visible
- manual continue button remains usable

---

## Security / Trust Notes

### Important Guardrails
- do not redirect before confirmed submit success
- validate redirect URL format
- do not silently swallow submit errors and redirect anyway
- if later query forwarding is added, review for token leakage and open redirect risk

---

## Why This Is Pro Instead of Starter
- multi-step continuation is more advanced than a basic thank-you state
- support cases become broader
- redirect behavior affects customer journeys directly
- strong fit for semi-flow generation and guided business processes

Starter can still later have:
- a simple thank-you message only

Pro gets:
- auto next-step redirect behavior

---

## Example User Story
1. User fills step 1 form
2. User presses `Submit`
3. Form submits successfully
4. Success message appears:
   - `Thank you`
   - `Your form was submitted successfully.`
5. Countdown starts
6. User is redirected to step 2 automatically
7. If needed, user can click:
   - `Continue now`

---

## Estimated Complexity

### Complexity Level
- low to medium

### Why
- mostly front-end/runtime work
- no major new data engine required
- simpler than formulas, repeat groups, or advanced submit flows

### Rough Size
- roughly `250-500` lines total across:
  - form config/publisher
  - runtime success screen
  - UI wiring for settings

---

## Recommended Implementation Order

1. add form-level config fields for success flow
2. expose settings in Salesforce UI
3. emit settings in publisher
4. render success screen in hosted HTML
5. add auto-redirect with delay
6. add manual continue button
7. test success vs failure behavior

---

## Final Recommendation
Implement this later as a `Pro` feature with:
- success screen
- optional auto-redirect
- short delay
- manual fallback button

This matches the preferred user experience and supports semi-flow generation without overcomplicating Starter.
