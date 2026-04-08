# NativeForms Builder V2 Design

## Goal
Create a new Builder page from scratch and keep the current `NativeForms Builder` page as the working prototype.

Builder V2 should focus first on the **canvas experience**, not on the full property editor.

## Why a New Page
- The current Builder already works end to end and should remain stable.
- The new Builder needs a different layout and interaction model.
- We want freedom to experiment with canvas editing without breaking the working prototype.

## V2 First Scope
Start with only these building blocks:
- `Section`
- `Columns`
- `Text Input`

This is enough to evaluate:
- how the canvas looks
- how items move on the canvas
- how sections and rows should behave
- whether the editing experience feels closer to FormAssembly

For this first V2 experiment, the right panel can stay mostly blank or minimal.

## Top Bar
The user flow should be:
1. Choose `Form`
2. Choose `Version`

Rules:
- Version list is filtered by the selected form
- Published version is shown first if one exists
- Otherwise default to the latest relevant version

The top bar should align to the left/center/right layout grid.

## Left Panel
Replace the current tile palette with compact add controls:

- `Input Field` picklist + `Add`
- `Display Element` picklist + `Add`

For the first V2 iteration:
- Input Field picklist includes `Text Input`
- Display Element picklist includes `Section` and `Columns`

## Center Canvas
The canvas should show **real preview blocks**, not metadata cards.

Examples:
- `Text Input`
  - label
  - visible text box under the label
- `Section`
  - visible section container with title
- `Columns`
  - visible row layout container with column slots

The canvas should support:
- selecting items
- reordering items
- moving items into and around sections/columns

## Drag and Drop
Drag and drop is a core V2 goal.

We want to test:
- dragging new items from the left panel into the canvas
- dragging existing items within the canvas
- moving items into sections / columns

Even if the first iteration uses simpler movement helpers at first, the design should target drag and drop.

## Right Panel
For the first V2 canvas experiment:
- keep the right panel minimal
- it does not need full field editing yet

Later we will add the improved compact property layout:
- label on the left
- input/editor on the right

## Display Elements
Display elements should render real visible content on the canvas.

Examples:
- heading/text elements should show their actual text
- image should later show the chosen image or placeholder

Image support can wait until after the first V2 canvas experiment.

## Phase Order

### Phase 2A
- New Builder page shell
- Form picker
- Version picker
- Left add controls
- Canvas with:
  - Section
  - Columns
  - Text Input
- Basic item selection
- Basic move/reorder support

### Phase 2B
- Drag and drop
- Better visual section/column behavior
- More realistic form preview styling

### Phase 2C
- Reintroduce a full right-side property editor
- Add more field types
- Add display text editing
- Add image support

## Important Product Decision
Do **not** alter the current Builder page to become V2.

Instead:
- keep the current page for working development and publish flow
- build a new page specifically for the improved builder experience

## Open Feature Backlog

These items should stay visible while we iterate on the new `NativeForms Designer` page.

### 1. Mobile Responsive
- The published form must render well on phones and tablets.
- The Designer itself should also degrade cleanly at narrower widths.
- This is tied to:
  - section and column behavior
  - responsive stacking rules
  - future preview fidelity

### 2. Form Width
- Admin should be able to choose the overall rendered form width.
- Likely options later:
  - narrow
  - standard
  - wide
  - full width
- This belongs more to page/form settings than per-field editing.
- It should connect later to:
  - theme settings
  - canvas preview width
  - published HTML shell width

### 3. Title Setting
- Admin should be able to set the form title explicitly.
- The canvas header and published form header should reflect that title.
- This should likely live in a page/settings panel rather than on an individual field.
- It ties to:
  - future settings page
  - publish preview
  - generated HTML title and visible form heading

### 4. Conditional Fields
- Fields and display blocks should be able to appear conditionally.
- Examples:
  - show field B only if checkbox A is checked
  - show a section only if picklist value = X
- This is a core builder feature and should eventually show visually on the canvas.
- It ties to:
  - future right-panel property rules
  - runtime form behavior
  - badges/indicators on canvas items

## Suggested Tie-In To Current Open Work

### Designer Canvas
- sections and columns
- drag and drop
- visual placement of fields inside sections
- later visual indicator for conditional items

### Right Panel / Settings
- title setting
- width setting
- conditional logic editor
- responsive behavior hints or preview modes

### Published Form Runtime
- mobile responsiveness
- width application
- title rendering
- conditional visibility behavior

### 5. Thank You Page Per Form
- Each form should be able to define its own thank-you page behavior.
- Options later may include:
  - inline thank-you message
  - hosted thank-you page
  - redirect after submit
- This should be configured per form or per published version.

### 6. Post-Submit Redirect URL
- Admin should be able to configure a URL to open after successful submit.
- This may be used instead of, or together with, a thank-you page.
- Needs later design for:
  - delay vs immediate redirect
  - success-only redirect
  - safe URL validation

### 7. Native Confirmation Code Support
- NativeForms should later support sending a confirmation code to the user by:
  - email
  - SMS
- The entered code or verified state may need to be saved in Salesforce on a field/custom field.
- This will need a later dedicated design for:
  - code generation
  - delivery channel
  - verification UI
  - retry/expiration rules
  - Salesforce field mapping
- This is intentionally a later design phase, but should stay in the product backlog now.

### 8. Nested Sections
- The Designer should support nested sections up to 2 levels deep.
- This is mainly for richer layout/composition, not unlimited container depth.
- It ties to:
  - canvas drag/drop rules
  - section rendering
  - section property inheritance
  - published HTML structure
  - mobile responsive stacking behavior
- This should stay constrained to 2 levels to avoid overcomplicating the UX and runtime model.
