# NativeForms Runtime API - V1

## Purpose
Define the public browser-side runtime contract exposed by a published NativeForms HTML artifact.

This API is an HTML/runtime concern only. It does not change the Lambda payload contracts.

## Global API
Published forms expose a global object:

```js
window.NativeForms
```

Supported methods:

```js
NativeForms.getValue(key)
NativeForms.setValue(key, value)
NativeForms.getAll()
NativeForms.showElement(id)
NativeForms.hideElement(id)
NativeForms.on(eventName, handler)
NativeForms.off(eventName, handler)
```

## Method Behavior

### getValue
Returns the current value for a top-level input key.

```js
const email = NativeForms.getValue("email");
```

### setValue
Sets a top-level input value, refreshes the UI, and emits a `change` event.

```js
NativeForms.setValue("subject", "Updated by custom JS");
```

### getAll
Returns the full current input object, including repeat groups and deleted repeat-row tracking.

```js
const input = NativeForms.getAll();
```

### showElement / hideElement
Manually shows or hides an element by `FORM_DEF.elements[].id`.

```js
NativeForms.hideElement("existingCases");
NativeForms.showElement("existingCases");
```

### on / off
Registers or removes a runtime event listener.

```js
const unsubscribe = NativeForms.on("submit:after", (detail) => {
  console.log(detail.response);
});

unsubscribe();
```

## Runtime Events
Events are emitted in two forms:

1. Through `NativeForms.on(eventName, handler)`
2. As browser events on `window` with the prefix:
   - `nativeforms:<eventName>`

Example:
```js
window.addEventListener("nativeforms:prefill:after", (event) => {
  console.log(event.detail);
});
```

## Supported Events

### form:init
Emitted at the start of form boot.

### form:ready
Emitted after render and runtime setup are complete.

### change
Emitted when a field value changes through user interaction or `setValue`.

Payload example:
```js
{
  formId: "problem-report-demo",
  key: "email",
  value: "user@example.com",
  input: { ... },
  source: "user"
}
```

### prefill:before
Emitted just before the prefill request is sent.

### prefill:after
Emitted after a successful prefill response is applied to the form.

### prefill:error
Emitted when prefill fails or throws.

### submit:before
Emitted before submit validation and request execution.

### submit:after
Emitted after a successful submit response.

### submit:error
Emitted for validation failures, submit failures, or submit exceptions.

## Event Payload Rules
- Every event includes `formId`
- Most events also include the current `input`
- `prefill:after` and `submit:after` include `response`
- `prefill:error` and `submit:error` include either `error`, `errors`, or `response`

## Notes
- This API is intentionally small and stable.
- `showElement` and `hideElement` are UI-only and do not change Lambda payloads.
- Conditional visibility rules defined in `FORM_DEF` still apply independently.
