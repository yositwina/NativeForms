# NativeForms Formula Feature Spec

## Purpose
This document captures the agreed V1 design for NativeForms formula fields so implementation, packaging, and future maintenance all follow the same rules.

This is a `Pro` feature.

## Commercial Placement
- plan: `Pro`
- not included in: `Starter`
- feature flag: `enableProFormulaFields`

## Feature Goal
Allow a form field to calculate its value from other fields before submit, similar to a lightweight derived field in Salesforce or FormAssembly.

Typical use cases:
- combine separate fields into one submit-ready value
- convert text to number
- create a visible derived value
- create a hidden calculated value for submit

Examples:
- combine first and last name
- use `IF` for conditional output
- use `TODAY()` for current date default/derived values
- use `VALUE()` to convert entered text into a numeric field

## V1 Scope

### Included
- formula on normal fields
- formula target fields allowed:
  - `text`
  - `number`
- evaluation in:
  - `NativeForms Designer`
  - published HTML runtime
- formula value included in submit payload
- formula field can still use normal visibility behavior:
  - visible
  - hidden
- visible formula fields render as normal fields with `readonly`
- hidden non-formula fields may be used as source fields
- dates and datetimes use ISO / Salesforce-compatible values

### Not Included in V1
- formula-to-formula references
- formula inside repeat groups
- submit-time server recheck of formula values
- advanced date math beyond the approved function list
- custom user-defined functions
- spreadsheet-like dependency graph
- cross-record or cross-object references
- formula usage inside condition-builder logic

## Field Model
Formula does **not** introduce a special field type.

Formula is an additional property on an existing field.

### Allowed target fields in V1
- `text`
- `number`

### Element config
- `isFormula: true|false`
- `formulaExpression: string`

There is no separate `formulaOutputType` in V1. The host field type defines the output.

## Runtime ownership rule
For V1, a field with `isFormula = true` is a formula-owned target field.

That means:
- the field keeps its normal field type for rendering and mapping
- its value is owned by the formula evaluator, not by direct user entry
- the computed formula result is the authoritative value

So for V1:
- direct user input into the formula target field is not allowed
- direct prefill into the formula target field is ignored
- source fields referenced by the formula can still be user-entered or prefilled normally

This avoids confusing conflicts where a user types into a field and then the formula immediately overwrites it.

## Library choice

### Agreed parser
- `expr-eval`

### Packaging decision
For V1, `expr-eval` should be added as an npm dependency in the repo and the needed parser code should be copied/embedded into:
- the Designer-side local JS helper
- the published browser runtime

There is no AWS runtime dependency or server re-evaluation path in V1.

## Formula syntax

### Field references
Use field keys wrapped in braces:

```text
{firstName}
{lastName}
{amountText}
```

### Function style
Functions are written in uppercase:

```text
CONCAT({firstName}, " ", {lastName})
VALUE({amountText})
IF({agreeTerms}, "Yes", "No")
TODAY()
```

### String literals
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

## Supported V1 functions

### String
- `CONCAT(...)`

### Conversion
- `VALUE(text)`
- `TEXT(value)`

### Logic
- `IF(condition, trueValue, falseValue)`
- `COALESCE(...)`
- `ISBLANK(value)`

### Number
- `ROUND(num, digits)`
- `ABS(num)`
- `MIN(a, b, ...)`
- `MAX(a, b, ...)`

### Date / time
- `TODAY()`
- `NOW()`
- `YEAR(date)`
- `MONTH(date)`
- `DAY(date)`

## Internal date representation
All date values inside the formula engine are ISO strings.

- Date-only: `YYYY-MM-DD`
- Datetime: `YYYY-MM-DDTHH:mm:ss`

For V1, all date functions evaluate in the user's browser local timezone.

## Null and empty handling
Every function should return `null` when given a null or invalid input rather than throwing.

Examples:
- `VALUE("")` -> `null`
- `YEAR(null)` -> `null`
- `IF(null, "yes", "no")` -> `"no"`

## Supported operators
The parser should allow the normal expression operators needed for V1:
- `+`
- `-`
- `*`
- `/`
- comparison:
  - `==`
  - `!=`
  - `>`
  - `>=`
  - `<`
  - `<=`
- logical:
  - `and`
  - `or`

Assignment, custom function definition, array operations, and other unused parser features should stay disabled.

## Validation rules

### Formula validation must check
- invalid syntax
- unknown field reference
- unknown function
- wrong number of arguments
- unsupported target field type
- formula target referencing itself
- formula inside repeat group
- blank expressions are allowed and should be treated as an empty derived value, not a validation failure

### Circular reference rule
For V1:
- formula fields cannot reference other formula fields

### Missing field references
If a formula references a field key that does not exist:
- show a Designer validation error
- do not allow the formula to be saved

### Invalid formula behavior in Designer
If the formula is invalid:
- live preview shows blank or null immediately
- the formula editor shows a light red invalid state
- the user may continue editing without an immediate hard stop
- publish is blocked until the formula is valid

## Designer UX

### Availability
Formula controls appear only when:
- `enableProFormulaFields` is enabled for the tenant
- selected field type is `text` or `number`
- the field is not inside a repeat group

### Right panel additions
When a supported field is selected, add:
- `Use Formula`
- `Formula Expression`
- `Insert Field`
- live preview
- validation message

### Field insertion helper
Formula editing should include an `Insert Field` picker similar to the post-submit token picker.

Rules:
- insert `{fieldKey}` at the current cursor position
- only list valid source fields
- exclude:
  - the current field itself
  - other formula fields
  - repeat-group fields in V1

### Canvas behavior
- formula result previews live on the canvas
- formula fields still visually look like their normal field type
- visible formula targets appear like normal readonly fields

## Prefill interaction
For V1:
- prefill should not overwrite a formula field's computed value
- formula fields should calculate from current form state after prefill loads source values
- direct prefill mapping into the formula target field should be ignored
- prefill should apply only to source fields that the formula reads from

This means:
1. prefill loads source fields
2. formula recalculates
3. submit uses the computed result

## User input interaction
For V1:
- a formula target field is not a user-entry field
- if the field is visible, render it as readonly
- if the field is hidden, still submit the computed value
- source fields remain normal editable/prefillable fields

## Behavior interpretation for formula fields
The existing behavior settings still exist on the field record, but V1 should interpret them like this when `isFormula = true`:

- `Hidden`
  - hide the field
  - still submit the computed value

- `Editable`
  - render as visible computed output
  - do not allow direct user editing

- `Read only when prefilled`
  - render as visible computed output
  - do not allow direct user editing

So in practice, V1 formula fields behave as:
- visible derived field
- or hidden derived field

## Publisher and runtime requirements

### Publisher must emit
- formula metadata into the published definition or field data attributes
- field references used by each formula
- expression string

### Published runtime must support
- loading formula definitions
- listening for dependent field changes
- evaluating formulas with `expr-eval`
- updating values before submit

V1 implementation is in Salesforce publish code and the published browser runtime only.

Relevant Salesforce file:
- `force-app/main/default/classes/NativeFormsPublisher.cls`

Relevant Designer files:
- `force-app/main/default/lwc/nativeFormsDesigner/nativeFormsDesigner.js`
- helper modules added under the same LWC bundle

## Recommended technical architecture

### In Designer
- local formula helper module wrapping `expr-eval`
- parse and validate formula
- map `{fieldKey}` references to current field values
- evaluate result for preview

### In published runtime
- same evaluation rules as Designer
- recalculate on source field change
- write final value into the field before submit

### Shared rule
Designer and runtime must use the same supported function set and reference syntax.

## Multi-lingual rule
Any customer-visible formula copy introduced in the published form must use the existing multilingual dictionary and fallback model.

Do not introduce fixed English customer-facing formula text in the published runtime.

Designer-only admin/debug validation text may remain English in V1.

## Security / trust notes

### Do not
- use raw JavaScript `eval`
- allow arbitrary user-defined code

### Do
- use a controlled parser/evaluator
- whitelist supported functions
- validate field references and function usage before runtime

This matters for:
- safety
- AppExchange readiness
- predictable support burden

## Estimated implementation size
- medium complexity feature
- mostly Salesforce Designer + Publisher work
- no AWS contract change in V1

## Recommended implementation order
1. add Designer UI for formula properties
2. implement formula parser and validator in Designer
3. support live preview in Designer
4. emit formula metadata in publisher
5. add runtime formula evaluator to published HTML
6. include formula result in submit payload
7. add validation and polish

## Final recommendation
Implement Formula Fields later as a controlled `Pro` feature with:
- `expr-eval`
- a small fixed function set
- `text` and `number` targets only
- no formula chaining
- no repeat-group support
- browser-only evaluation in V1

This gives strong user value without turning NativeForms into a spreadsheet engine.
