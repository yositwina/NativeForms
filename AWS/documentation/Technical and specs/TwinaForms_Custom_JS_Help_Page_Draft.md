# TwinaForms Custom JavaScript Help Page Draft

## Page Title
TwinaForms Custom JavaScript

## Intro
Custom JavaScript lets you add advanced browser-side automation to a published TwinaForms form.

Use it when you want the form to:

- fill one field from another
- react to changes in user input
- show or hide content in custom ways
- apply lightweight custom behavior beyond the standard builder options

Custom JavaScript runs in the browser, not in Salesforce or AWS.

Use only trusted code.

## Where To Add It
In TwinaForms Designer:

1. Open the form
2. Open `Form Settings`
3. Open `Advanced`
4. Click `Edit Custom JavaScript`
5. Paste your code and save
6. Republish the form

## Supported API
Use the TwinaForms runtime API when possible.

Supported methods:

```javascript
TwinaForms.getValue(key)
TwinaForms.setValue(key, value)
TwinaForms.getAll()
TwinaForms.showElement(id)
TwinaForms.hideElement(id)
TwinaForms.on(eventName, handler)
TwinaForms.off(eventName, handler)
```

Supported events:

- `form:init`
- `form:ready`
- `change`
- `prefill:before`
- `prefill:after`
- `prefill:error`
- `submit:before`
- `submit:after`
- `submit:error`

## Basic Pattern
Most scripts follow this pattern:

```javascript
(function (TwinaForms) {
  function syncSomething() {
    const source = TwinaForms.getValue("text5") || "";
    TwinaForms.setValue("text6", source);
  }

  TwinaForms.on("change", function () {
    syncSomething();
  });

  syncSomething();
})(TwinaForms);
```

## Example 1: Country To Phone Country Code
Assume:

- `text5` = country
- `text6` = phone country code

```javascript
(function (TwinaForms) {
  const phoneCodes = {
    "Israel": "+972",
    "United States": "+1",
    "Canada": "+1",
    "United Kingdom": "+44",
    "Germany": "+49",
    "France": "+33",
    "Spain": "+34",
    "Italy": "+39"
  };

  function updatePhoneCode() {
    const country = TwinaForms.getValue("text5") || "";
    TwinaForms.setValue("text6", phoneCodes[country] || "");
  }

  TwinaForms.on("change", function () {
    updatePhoneCode();
  });

  updatePhoneCode();
})(TwinaForms);
```

## Example 2: Build Full Name From Two Fields
Assume:

- `text1` = first name
- `text2` = last name
- `text3` = full name

```javascript
(function (TwinaForms) {
  function updateFullName() {
    const first = (TwinaForms.getValue("text1") || "").trim();
    const last = (TwinaForms.getValue("text2") || "").trim();
    const fullName = [first, last].filter(Boolean).join(" ");
    TwinaForms.setValue("text3", fullName);
  }

  TwinaForms.on("change", function () {
    updateFullName();
  });

  updateFullName();
})(TwinaForms);
```

## Example 3: Show A Section Only When A Checkbox Is Checked
Assume:

- `checkbox11` = controlling checkbox
- `sectionPromo` = element id of a display section

```javascript
(function (TwinaForms) {
  function syncSection() {
    const checked = TwinaForms.getValue("checkbox11") === true;
    if (checked) {
      TwinaForms.showElement("sectionPromo");
    } else {
      TwinaForms.hideElement("sectionPromo");
    }
  }

  TwinaForms.on("change", function () {
    syncSection();
  });

  syncSection();
})(TwinaForms);
```

## Example 4: Set A Greeting Based On Country
Assume:

- `text5` = country
- `text7` = greeting

```javascript
(function (TwinaForms) {
  function updateGreeting() {
    const country = TwinaForms.getValue("text5") || "";

    if (country === "Israel") {
      TwinaForms.setValue("text7", "Shalom");
      return;
    }

    if (country === "Spain") {
      TwinaForms.setValue("text7", "Hola");
      return;
    }

    TwinaForms.setValue("text7", "Hello");
  }

  TwinaForms.on("change", function () {
    updateGreeting();
  });

  updateGreeting();
})(TwinaForms);
```

## Example 5: Build A Salesforce Datetime Value
Assume:

- `date1` = Date field
- `time1` = Time field in `HH:mm`
- `text5` = hidden Text field submitted to a Salesforce Datetime field

This example combines the selected date, selected time, and the submitter's browser timezone offset into an ISO 8601 value like `2026-04-23T14:30:00+03:00`.

```javascript
(function (TwinaForms) {
  function pad(n) {
    return String(n || 0).padStart(2, "0");
  }

  function offsetPart() {
    var minutes = -new Date().getTimezoneOffset();
    var sign = minutes >= 0 ? "+" : "-";
    var m = Math.abs(minutes);
    return sign + pad(Math.floor(m / 60)) + ":" + pad(m % 60);
  }

  function datePart() {
    var val = TwinaForms.getValue("date1");
    if (val) return String(val);

    var d = new Date();
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
  }

  function timePart() {
    var val = TwinaForms.getValue("time1");
    if (val) {
      var p = String(val).split(":");
      return pad(p[0]) + ":" + pad(p[1]) + ":" + pad(p[2]);
    }

    var d = new Date();
    return pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":" + pad(d.getSeconds());
  }

  function updateSfDatetime() {
    TwinaForms.setValue("text5", datePart() + "T" + timePart() + offsetPart());
  }

  TwinaForms.on("input", updateSfDatetime);
  TwinaForms.on("change", updateSfDatetime);

  updateSfDatetime();
})(TwinaForms);
```

## Good Practices
- Keep scripts short and focused
- Prefer `TwinaForms.getValue()` and `TwinaForms.setValue()` over direct DOM selectors
- Republish after saving new code
- Test with realistic form values

## Avoid
- very large scripts
- code that depends heavily on the page HTML structure
- untrusted copied code

## Support Note
TwinaForms officially supports the `TwinaForms` runtime API.

TwinaForms does not automatically include third-party libraries such as `jQuery`, so prefer the built-in API and plain JavaScript unless you explicitly control that dependency.

Direct DOM scripting may work, but it is less stable and may break more easily if the published HTML structure changes in future versions.
