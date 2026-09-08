import assert from "node:assert/strict";
import { columnTemplate, buildSubmissionHtml } from "./htmlBuilder.mjs";

assert.equal(columnTemplate(3, "wideLast"), "minmax(0,1fr) minmax(0,1fr) minmax(0,2fr)");
assert.equal(columnTemplate(3, "wideMiddle"), "minmax(0,1fr) minmax(0,2fr) minmax(0,1fr)");
assert.equal(columnTemplate(3, "not-a-layout"), "repeat(3,minmax(0,1fr))");

const html = buildSubmissionHtml({
  config: {
    title: "Layout test",
    schema: [{
      elementId: "section1",
      type: "section",
      label: "Details",
      columns: 3,
      columnLayout: "wideLast"
    }],
    rtlEnabled: false
  },
  inputPayload: { input: {} }
});
assert.match(html, /grid-template-columns:minmax\(0,1fr\) minmax\(0,1fr\) minmax\(0,2fr\)/);

console.log("column layout preset tests passed");
