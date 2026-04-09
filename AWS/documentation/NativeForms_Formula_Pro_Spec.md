# NativeForms Formula Feature Spec

## Purpose
This document captures the agreed design for the NativeForms formula feature so it can be implemented later without losing product, UX, and technical decisions.

This is a `Pro` feature.

---

## Plan Placement

### Commercial Packaging
- plan: `Pro`
- not included in: `Starter`

### Why It Is Pro
- formula fields add real runtime logic and computed values
- formula authoring increases product complexity and support load
- formula logic is a strong differentiation feature compared to basic form builders

---

## Feature Goal
Allow a form field to calculate its value from other fields before submit, similar to a lightweight formula field in Salesforce or FormAssembly.

Typical use cases:
- combine separate fields into one submit-ready value
- convert text to number
- create a display or hidden calculated value
- prepare a Salesforce target field such as a combined date/time string

Examples:
- combine first and last name
- use `IF` for conditional output
- use `TODAY()` for current date default/derived values
- use `VALUE()` to convert entered text into a numeric field

---

## Scope for V1

### Included
- formula on normal fields
- output type:
  - `text`
  - `number`
- evaluation in:
  - `NativeForms Designer`
  - published HTML runtime
- formula value included in submit payload
- formula field can also use normal field behavior:
  - `Editable`
  - `Read only when prefilled`
  - `Hidden`

### Not Included in V1
- formula-to-formula references
- advanced date math beyond `TODAY()`
- custom user-defined functions
- spreadsheet-like dependency graph
- Salesforce-style full formula language compatibility
- cross-record or cross-object references
- formula usage inside condition-builder logic

---

## Field Model

The formula feature does **not** introduce a special hidden field type.

The existing model stays:
- field type:
  - `text`
  - `number`
  - `date`
  - `checkbox`
  - `picklist`
  - other normal field types
- field behavior:
  - `Editable`
  - `Read only when prefilled`
  - `Hidden`

Formula is an additional property on a normal field.

### Proposed Element Config
- `isFormula: true|false`
- `formulaOutputType: "text" | "number"`
- `formulaExpression: string`

---

## Library Choice

### Agreed Library
- `expr-eval`

### Reason
- smaller and lighter than a full spreadsheet engine
- safer than custom `eval`
- supports variables and custom functions
- suitable for a controlled NativeForms formula language

### Why Not Full Spreadsheet Engine
- a library like `HyperFormula` is too heavy for V1
- `Formula.js` has useful Excel functions, but we still need custom field-reference behavior and runtime integration
- `expr-eval` gives the best balance between flexibility and implementation control

---

## Formula Syntax

### Field References
Use field keys wrapped in braces:

```text
{firstName}
{lastName}
{amountText}
```

### Function Style
Functions are written in uppercase:

```text
CONCAT({firstName}, " ", {lastName})
VALUE({amountText})
IF({agreeTerms}, "Yes", "No")
TODAY()
```

### String Literals
Strings use double quotes:

```text
"Hello"
" "
"Approved"
```

### Numbers
Numbers are entered normally:

```text
100
3.14
-1
```

---

## Supported V1 Functions

### Required
- `CONCAT(...)`
- `LEFT(text, n)`
- `RIGHT(text, n)`
- `MID(text, start, length)`
- `LEN(text)`
- `VALUE(text)`
- `IF(condition, trueValue, falseValue)`
- `TODAY()`

### Behavior Notes

#### `CONCAT`
Concatenates all arguments as text.

Example:

```text
CONCAT({firstName}, " ", {lastName})
```

#### `LEFT`
Returns the leftmost `n` characters.

Example:

```text
LEFT({code}, 3)
```

#### `RIGHT`
Returns the rightmost `n` characters.

#### `MID`
Returns a substring starting at `start` for `length` characters.

#### `LEN`
Returns string length as a number.

#### `VALUE`
Converts text to number.

Example:

```text
VALUE({amountText})
```

If conversion fails, formula evaluation should return a clear error state.

#### `IF`
Conditional branching is required in V1.

Example:

```text
IF({amount} > 100, "Large", "Small")
```

#### `TODAY`
Returns the current date.

For V1, the recommendation is:
- output as ISO-like date string: `YYYY-MM-DD`

This works well with HTML date inputs and submit payloads.

---

## Supported Operators Inside Formula Expressions

Because `IF` requires boolean logic, the parser should support the normal expression operators offered through `expr-eval`, such as:
- `+`
- `-`
- `*`
- `/`
- comparison operators:
  - `==`
  - `!=`
  - `>`
  - `>=`
  - `<`
  - `<=`
- logical operators supported by the chosen parser if enabled safely

The exact enabled operator set should be kept small and documented in UI help.

---

## Validation Rules

### Formula Validation Must Check
- invalid syntax
- unknown field reference
- unknown function
- wrong number of arguments
- invalid numeric conversion for `VALUE`
- unsupported output type
- circular reference

### V1 Circular Reference Rule
For V1:
- formula fields cannot reference other formula fields

This is the simplest and safest way to avoid dependency loops.

### Missing Field References
If a formula references a field key that does not exist:
- show a Designer validation error
- do not allow the formula to be saved silently

---

## Designer UX

### Right Panel Additions
When a supported field is selected, add:
- `Use Formula`
- `Formula Output Type`
  - `Text`
  - `Number`
- `Formula Expression`

### Canvas Behavior
- formula result should preview live on the canvas
- if formula is invalid:
  - show a clear inline error state
- formula fields should still visually look like their normal field type

### Formula Help
The UI should include a short helper section with examples:
- `CONCAT({firstName}, " ", {lastName})`
- `VALUE({amountText})`
- `IF({agreeTerms}, "Yes", "No")`
- `TODAY()`

---

## Runtime Behavior in Published HTML

### Evaluation Timing
Formula values should recalculate:
- on page load
- when any referenced source field changes

### Runtime Result
- the computed value is written into the formula field
- if the field behavior is `Hidden`, the value is still included in the submit payload
- if the field behavior is visible/read-only, the user can see the result but not edit it directly if configured that way

### Submit Integration
Formula fields behave like normal fields for submit mapping:
- they have a field key
- they can map into Salesforce submit actions
- their computed value is sent as part of `input`

---

## Prefill Interaction

For V1:
- prefill should not overwrite a formula field’s computed value
- formula fields should calculate from current form state after prefill loads source values

This means:
1. prefill loads source fields
2. formula recalculates
3. submit uses the computed result

---

## HTML / Publisher Requirements

### Publisher Must Emit
- formula metadata into published definition
- field references used by each formula
- output type
- expression string

### Hosted Runtime Must Support
- loading formula definitions
- listening for dependent field changes
- evaluating formulas with `expr-eval`
- updating values before submit

This requires updates both in Salesforce publish code and in AWS-hosted runtime logic.

Relevant AWS files:
- `AWS/NativeForms-PrefillForm.mjs`
- `AWS/NativeForms-SubmitForm.mjs`

Relevant Salesforce publish file:
- `force-app/main/default/classes/NativeFormsPublisher.cls`

---

## Recommended Technical Architecture

### In Designer
- lightweight formula helper module wrapping `expr-eval`
- parse and validate formula
- map `{fieldKey}` references to real current values
- evaluate result for preview

### In Published Runtime
- same evaluation rules as Designer
- recalculate on source field change
- write final value into form payload before submit

### Shared Rule
Designer and runtime must use the same supported function set and reference syntax.

---

## Security / Trust Notes

### Do Not
- use raw JavaScript `eval`
- allow arbitrary user-defined code

### Do
- use controlled parser/evaluator
- whitelist supported functions
- validate field references and function usage before runtime

This is important for:
- safety
- AppExchange readiness
- predictable support burden

---

## Estimated Implementation Size

### Estimated Total
- roughly `900–1,100` lines of code

### Likely Breakdown
- Designer UI + state:
  - `120–220` lines
- Designer formula evaluation helper:
  - `180–320` lines
- Publisher changes:
  - `80–150` lines
- Published runtime evaluator:
  - `180–300` lines
- validation and cleanup:
  - `120–250` lines

This is a medium-complexity feature if the scope remains controlled.

---

## Recommended Implementation Order

1. add Designer UI for formula properties
2. implement formula parser/validator in Designer
3. support live preview in Designer
4. emit formula metadata in publisher
5. add runtime formula evaluator to published HTML
6. include formula result in submit payload
7. add error handling and polish

---

## Example V1 Formulas

### Full Name
```text
CONCAT({firstName}, " ", {lastName})
```

### Numeric Conversion
```text
VALUE({amountText})
```

### Conditional Label
```text
IF({agreeTerms}, "Approved", "Pending")
```

### Date Default
```text
TODAY()
```

### Phone Prefix Example
```text
LEFT({mobilePhone}, 3)
```

---

## Final Recommendation
Implement this feature later as a controlled `Pro` feature with:
- `expr-eval`
- a small fixed function set
- text/number output only
- no formula chaining in V1

This gives strong user value without turning NativeForms into a full spreadsheet engine.
