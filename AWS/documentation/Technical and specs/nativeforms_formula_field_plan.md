# NativeForms Formula Field — Plan and Design Summary

## Goal
Add a **Formula Field** type to NativeForms that lets admins compute a value from other inputs using a **restricted JavaScript expression**.

This should feel powerful but still lightweight, and should avoid the complexity of building a full custom formula parser in version 1.

---

## Core Product Decision
Use **real JavaScript-like expressions** for formulas, but only allow them to run in a **restricted, controlled context**.

### Why this direction
This is simpler than building a custom formula language once we need:
- text functions
- math operators
- dates
- parentheses
- null handling
- comparisons

A custom text-command language looks easier at first, but quickly becomes a real parser/evaluator project.

Restricted JS gives us:
- built-in math: `+ - * /`
- natural expression syntax
- easier learning for technical users
- enough flexibility for power users
- less product work than designing a full formula engine

---

## Scope for V1
### Formula type
A formula is a **single expression only**.

Not allowed in V1:
- full scripts
- loops
- assignments
- function declarations
- async code
- access to browser/global objects

### User intent
Admins write something like:

```js
(input.qty || 0) * (input.unitPrice || 0)
```

or

```js
(input.firstName || "").trim() + " " + (input.lastName || "").trim()
```

or

```js
helpers.addDays(input.startDate, 7)
```

---

## Runtime Model
### Allowed runtime context
The formula should only run with a small safe context, such as:
- `input` — the current form values
- `helpers` — approved helper functions

Example:

```js
{
  input: { firstName: "Yosi", qty: 2, unitPrice: 50 },
  helpers: { ...approved helper methods... }
}
```

### Must not expose
The formula must **not** have access to:
- `window`
- `document`
- `fetch`
- `XMLHttpRequest`
- `localStorage`
- `sessionStorage`
- `eval`
- `Function`
- network or DOM APIs

---

## Why Not a Custom Formula Parser in V1
A custom parser would require:
- tokenizer
- parser
- AST
- evaluator
- type rules
- precedence handling
- null behavior rules
- custom error messages

That becomes a much bigger feature once formulas include math and dates.

So the V1 product choice is:

**restricted JS expression > custom formula language**

for speed, flexibility, and lower engineering cost.

---

## UX Model
We decided **not** to use a workflow such as Draft / Approved / Published.

That feels too heavy for NativeForms.

### Simpler UX
The formula feature should feel immediate and lightweight:
- user writes formula
- system validates it
- user can test it with sample input
- if valid, it can be saved and used
- if invalid, it should not run

### V1 user-facing UI
Recommended UI elements:
- **Formula / Expression** text area
- **Test data** area
- **Test** button
- **Result** preview area
- **Error** message area
- **Save** button

### Internal system state
Instead of user-facing approval stages, keep simple technical state such as:
- `isValid`
- `validationError`
- `validatedAt`
- maybe `lastTestInput`
- maybe `lastTestResult`

### Main rule
**Only valid formulas can run.**

No Draft. No Approved. No Published.

---

## Validation Behavior
### Recommended behavior
- Validate on demand with **Test**
- Optionally also validate live while typing
- Save only if formula is valid
- Show clear error messages when invalid

### Example invalid expression
```js
input.qty *
```

Example error:

```text
Invalid formula: unexpected end of expression
```

---

## Helper Functions Strategy
To keep formulas simple and safer, expose common operations through `helpers.*`.

This is especially important for **date logic**, where raw JavaScript `Date` handling is messy and inconsistent.

### Recommended helper categories
#### Text helpers
- `helpers.left(text, n)`
- `helpers.right(text, n)`
- `helpers.trim(text)`
- `helpers.upper(text)`
- `helpers.lower(text)`
- `helpers.concat(...parts)`

#### Number helpers
- `helpers.round(num, digits)`
- `helpers.abs(num)`
- `helpers.min(a, b)`
- `helpers.max(a, b)`

#### Date helpers
- `helpers.today()`
- `helpers.now()`
- `helpers.addDays(date, n)`
- `helpers.addMonths(date, n)`
- `helpers.diffDays(date1, date2)`
- `helpers.formatDate(date, format)`

### Why helpers matter
Helpers let us:
- keep behavior consistent
- avoid messy raw JS date logic
- give admins easier examples
- evolve formulas safely later

---

## What We Should Allow in V1
### Allowed concepts
- `input.fieldKey`
- standard arithmetic operators
- parentheses
- string concatenation
- null-coalescing style patterns using `||`
- simple conditional expressions if needed later
- approved helper methods
- safe built-in string methods like:
  - `trim()`
  - `toUpperCase()`
  - `toLowerCase()`
  - `substring()`
  - `replace()` (carefully)

### Not allowed in V1
- statements
- loops
- custom functions
- assignments
- external calls
- browser APIs
- unrestricted object access

---

## Example Formula Use Cases
### Full name
```js
(input.firstName || "").trim() + " " + (input.lastName || "").trim()
```

### Lowercase email
```js
(input.email || "").toLowerCase()
```

### Multiply quantity by price
```js
(input.qty || 0) * (input.unitPrice || 0)
```

### Add 7 days to a date
```js
helpers.addDays(input.startDate, 7)
```

### First initial + surname
```js
helpers.left(input.firstName || "", 1) + ". " + (input.lastName || "")
```

### Clean phone format
```js
(input.phone || "").replace(/-/g, "")
```

---

## Non-Technical Admins
We believe many non-software users can still use this feature with support from:
- examples
- helper list
- test panel
- clear result preview
- friendly error messages

So the learning model is not “formula builder first.”
Instead it is:
- show examples
- let them test
- let them copy patterns

That should be enough for many practical use cases.

---

## Recommended Labeling in UI
Suggested naming for the field type:
- **Formula Field**
- or **Calculated Field**

Suggested editor label:
- **Expression**
- or **Formula Expression**

Suggested helper text:
- “Write a JavaScript-style expression using `input` and `helpers`.”

---

## Final V1 Design Decision
### Chosen approach
- Formula field uses **restricted JavaScript expressions**
- Formula is **single-expression only**
- Runtime exposes only **`input`** and **`helpers`**
- Formula can be **tested with sample input**
- Formula is saved and used only when **valid**
- No Draft / Approved / Published workflow
- Dates should mainly go through helper functions

### Summary sentence
NativeForms Formula Field V1 should be a **lightweight, JS-expression-based calculated field with safe runtime restrictions, helper functions, test input support, and simple valid/invalid behavior**.

---

## Suggested Next Step
Define the exact V1 contract for:
1. allowed expression rules
2. helper function list
3. validation behavior
4. formula editor screen layout
5. runtime evaluation strategy
