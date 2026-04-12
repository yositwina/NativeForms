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

`expr-eval` lets us register any JavaScript function as a parser function, with no parser changes and no security impact. This means we can ship a rich function library in V1 without compromising the safety or simplicity of the DSL approach.

### String Functions
- `CONCAT(...)` — concatenate all arguments as text
- `LEFT(text, n)` — leftmost `n` characters
- `RIGHT(text, n)` — rightmost `n` characters
- `MID(text, start, length)` — substring starting at `start` for `length` characters
- `LEN(text)` — string length as a number
- `UPPER(text)` — uppercase
- `LOWER(text)` — lowercase
- `TRIM(text)` — remove leading/trailing whitespace
- `REPLACE(text, find, replaceWith)` — replace all occurrences (string-only, no regex)
- `CONTAINS(text, search)` — boolean
- `STARTSWITH(text, prefix)` — boolean
- `ENDSWITH(text, suffix)` — boolean

### Conversion Functions
- `VALUE(text)` — convert text to number; returns `null` on bad input
- `TEXT(value)` — convert any value to text

### Logic Functions
- `IF(condition, trueValue, falseValue)` — conditional branching
- `COALESCE(...)` — return first non-null/non-empty argument
- `ISBLANK(value)` — boolean, true when value is null or empty string

### Number Functions
- `ROUND(num, digits)` — round to N decimal places
- `ABS(num)` — absolute value
- `MIN(a, b, ...)` — smallest argument
- `MAX(a, b, ...)` — largest argument
- `MOD(a, b)` — remainder
- `CEILING(num)` — round up to integer
- `FLOOR(num)` — round down to integer

### Date Functions — Current / Now
- `TODAY()` — current date as `YYYY-MM-DD`
- `NOW()` — current datetime as `YYYY-MM-DDTHH:mm:ss`
- `YEAR(date)` — number
- `MONTH(date)` — number, 1–12
- `DAY(date)` — number, 1–31
- `WEEKDAY(date)` — number, 1=Sunday … 7=Saturday

### Date Functions — Math
- `ADDDAYS(date, n)` — add `n` days
- `ADDMONTHS(date, n)` — add `n` months
- `ADDYEARS(date, n)` — add `n` years
- `ADDHOURS(datetime, n)` — add `n` hours
- `ADDMINUTES(datetime, n)` — add `n` minutes

### Date Functions — Diffs / Age
- `DIFFDAYS(d1, d2)` — integer days from `d1` to `d2`
- `DIFFMONTHS(d1, d2)` — integer months from `d1` to `d2`
- `DIFFYEARS(d1, d2)` — integer years from `d1` to `d2`
- `AGE(birthDate)` — integer years from `birthDate` to today

### Date Functions — Formatting / Parsing
- `FORMATDATE(date, format)` — format a date using token string (see "Format Tokens" below)
- `PARSEDATE(text, format)` — inverse of `FORMATDATE`

### Date Functions — Comparisons
- `ISBEFORE(d1, d2)` — boolean
- `ISAFTER(d1, d2)` — boolean
- `ISSAME(d1, d2)` — boolean

### Date Functions — Convenience
- `STARTOFMONTH(date)` — first day of month
- `ENDOFMONTH(date)` — last day of month
- `STARTOFWEEK(date)` — first day of the week containing `date`
- `ENDOFWEEK(date)` — last day of the week containing `date`

---

## Behavior Notes

### `CONCAT`
Concatenates all arguments as text. Numbers and dates are converted to their string representation.

```text
CONCAT({firstName}, " ", {lastName})
```

### `LEFT` / `RIGHT` / `MID` / `LEN`
Standard string slicing. Out-of-range arguments return an empty string rather than throwing.

```text
LEFT({code}, 3)
RIGHT({code}, 4)
MID({code}, 4, 2)
LEN({fullName})
```

### `VALUE`
Converts text to number. If conversion fails, returns `null` and the formula's result is `null`.

```text
VALUE({amountText})
```

### `IF`
Conditional branching, identical to Salesforce/Excel.

```text
IF({amount} > 100, "Large", "Small")
```

### `TODAY` / `NOW`
Returns the current date or datetime, in the **user's browser timezone**, as an ISO string. See "Timezone Handling" below.

```text
TODAY()        →  "2026-04-11"
NOW()          →  "2026-04-11T14:32:09"
```

### Date math (`ADDDAYS`, `ADDMONTHS`, etc.)
All date math functions accept and return ISO date strings. They preserve the input format — `ADDDAYS` on a date string returns a date string; `ADDHOURS` on a datetime string returns a datetime string.

```text
ADDDAYS(TODAY(), 14)
ADDMONTHS({startDate}, 6)
ADDHOURS(NOW(), -2)
```

### Date diffs (`DIFFDAYS`, `DIFFMONTHS`, `DIFFYEARS`)
Return an integer representing `d2 − d1`. A negative result means `d1` is after `d2`.

```text
DIFFDAYS({startDate}, {endDate})
DIFFYEARS({birthDate}, TODAY())
```

### `AGE`
Convenience wrapper that returns `DIFFYEARS({birthDate}, TODAY())`.

```text
AGE({birthDate})
```

### `FORMATDATE`
Formats an ISO date or datetime using a small token language (see "Format Tokens").

```text
FORMATDATE(TODAY(), "DD/MM/YYYY")     →  "11/04/2026"
FORMATDATE({createdDate}, "MMM YYYY")  →  "Apr 2026"
```

### `PARSEDATE`
Inverse of `FORMATDATE`. Useful when a user enters a date in a non-standard format and the formula needs the ISO version.

```text
PARSEDATE({userText}, "DD/MM/YYYY")   →  "2026-04-11"
```

### Date comparisons
Return boolean for use inside `IF`.

```text
IF(ISAFTER(TODAY(), {dueDate}), "Overdue", "On Time")
IF(ISBEFORE({startDate}, {endDate}), "Valid", "Invalid range")
```

### Convenience date functions
Return adjusted ISO date strings for the start/end of a period.

```text
STARTOFMONTH(TODAY())       →  "2026-04-01"
ENDOFMONTH(TODAY())         →  "2026-04-30"
```

---

## Format Tokens

`FORMATDATE` and `PARSEDATE` use this small token set (dayjs/moment convention):

| Token | Meaning | Example |
|---|---|---|
| `YYYY` | 4-digit year | `2026` |
| `YY` | 2-digit year | `26` |
| `MMMM` | full month name | `April` |
| `MMM` | short month name | `Apr` |
| `MM` | 2-digit month | `04` |
| `M` | 1–2 digit month | `4` |
| `DD` | 2-digit day | `11` |
| `D` | 1–2 digit day | `11` |
| `HH` | 24-hour hours | `14` |
| `mm` | minutes | `32` |
| `ss` | seconds | `09` |

The exact token list should be documented in UI help.

---

## Internal Date Representation

**Decision:** all date values inside the formula engine are ISO strings.

- Date-only: `YYYY-MM-DD`
- Datetime: `YYYY-MM-DDTHH:mm:ss`

Why ISO:
- HTML `<input type="date">` already uses this format
- Salesforce date and datetime fields accept this format
- JavaScript `new Date("2026-04-11")` parses it natively
- ISO strings sort and compare correctly as text
- No timezone drift bugs from `new Date(string)` ambiguity

Every date function:
- Accepts an ISO string (or `null`)
- Returns an ISO string (or `null` on bad input)
- Internally converts to a `Date` object only for math, then converts back to ISO

---

## Timezone Handling

For V1, all date functions evaluate in the **user's browser local timezone**.

- A form filled out in Israel sees Israel's `TODAY()`
- A form filled out in California sees California's `TODAY()`
- This matches what the user sees on screen

Designer preview also uses the admin's local timezone. Document this clearly in UI help.

If server-side re-evaluation is added in a later version, the Lambda will need the user's timezone in the submit payload to produce identical results.

---

## Null and Empty Value Handling

Every function returns `null` when given a null or invalid input rather than throwing. This means formulas degrade gracefully when source fields are empty.

- `LEN(null)` → `0`
- `VALUE("")` → `null`
- `ADDDAYS(null, 7)` → `null`
- `IF(null, "yes", "no")` → `"no"` (null is falsy)

For explicit empty checks, use `ISBLANK`:

```text
IF(ISBLANK({email}), "Missing", {email})
```

For default values, use `COALESCE`:

```text
COALESCE({nickname}, {firstName}, "Unknown")
```

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
- roughly `1,100–1,400` lines of code (revised upward to account for the expanded date/string/number function library)

### Likely Breakdown
- Designer UI + state:
  - `120–220` lines
- Designer formula evaluation helper:
  - `180–320` lines
- Function library (string + number + date + logic):
  - `250–350` lines
- Publisher changes:
  - `80–150` lines
- Published runtime evaluator:
  - `180–300` lines
- validation and cleanup:
  - `120–250` lines

This is a medium-complexity feature if the scope remains controlled.

### Optional dependency: `dayjs`
For V1, native JavaScript `Date` is sufficient and avoids any third-party library audit.

If timezone support or fancier formatting becomes important in V2, swap to `dayjs` (~6KB minified). It's smaller than `date-fns`, has timezone support as an optional plugin, and is widely audited. The function signatures stay identical — only the internal helper module changes.

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

### Strings

#### Full name
```text
CONCAT({firstName}, " ", {lastName})
```

#### Initial + surname
```text
CONCAT(LEFT({firstName}, 1), ". ", {lastName})
```

#### Lowercase email
```text
LOWER({email})
```

#### Strip phone formatting
```text
REPLACE(REPLACE({phone}, "-", ""), " ", "")
```

#### Default to a fallback
```text
COALESCE({nickname}, {firstName}, "Unknown")
```

### Numbers

#### Convert text to number
```text
VALUE({amountText})
```

#### Quantity × unit price
```text
VALUE({qty}) * VALUE({unitPrice})
```

#### Round to 2 decimals
```text
ROUND(VALUE({amountText}), 2)
```

#### Largest of three values
```text
MAX(VALUE({offer1}), VALUE({offer2}), VALUE({offer3}))
```

### Logic

#### Approved / pending label
```text
IF({agreeTerms}, "Approved", "Pending")
```

#### Size bucket
```text
IF({amount} > 1000, "Large", IF({amount} > 100, "Medium", "Small"))
```

#### Required field check
```text
IF(ISBLANK({email}), "Missing email", "OK")
```

### Dates — current

#### Today's date as default
```text
TODAY()
```

#### Current year
```text
YEAR(TODAY())
```

#### Current month name
```text
FORMATDATE(TODAY(), "MMMM")
```

### Dates — math

#### 14 days from today
```text
ADDDAYS(TODAY(), 14)
```

#### One month from start date
```text
ADDMONTHS({startDate}, 1)
```

#### End-of-month billing date
```text
ENDOFMONTH(TODAY())
```

#### Next Monday (week starts Sunday)
```text
ADDDAYS(STARTOFWEEK(TODAY()), 8)
```

### Dates — diffs and age

#### Days until renewal
```text
DIFFDAYS(TODAY(), {renewalDate})
```

#### Customer age from birthdate
```text
AGE({birthDate})
```

#### Length of stay in days
```text
DIFFDAYS({checkIn}, {checkOut})
```

### Dates — comparisons inside `IF`

#### Show "Overdue" if past due
```text
IF(ISAFTER(TODAY(), {dueDate}), "Overdue", "On Time")
```

#### Validate date range
```text
IF(ISBEFORE({startDate}, {endDate}), "Valid range", "Invalid range")
```

#### Conditional default date
```text
IF({isUrgent}, ADDDAYS(TODAY(), 1), ADDDAYS(TODAY(), 7))
```

### Dates — formatting

#### Display as DD/MM/YYYY
```text
FORMATDATE({createdDate}, "DD/MM/YYYY")
```

#### Display as long date
```text
FORMATDATE(TODAY(), "MMMM D, YYYY")
```

#### Parse user text into ISO
```text
PARSEDATE({userText}, "DD/MM/YYYY")
```

### Combined examples

#### Customer summary line
```text
CONCAT({firstName}, " ", {lastName}, " (age ", AGE({birthDate}), ")")
```

#### Days remaining label
```text
IF(DIFFDAYS(TODAY(), {expiryDate}) > 0,
   CONCAT(DIFFDAYS(TODAY(), {expiryDate}), " days remaining"),
   "Expired")
```

#### Build a Salesforce-friendly datetime string
```text
CONCAT({eventDate}, "T", {eventTime}, ":00")
```

---

## Final Recommendation
Implement this feature later as a controlled `Pro` feature with:
- `expr-eval`
- a small fixed function set
- text/number output only
- no formula chaining in V1

This gives strong user value without turning NativeForms into a full spreadsheet engine.

