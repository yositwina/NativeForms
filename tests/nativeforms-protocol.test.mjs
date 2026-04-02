import assert from "node:assert/strict";

function getByPath(obj, path) {
  if (!path) return undefined;
  const normalized = String(path).replace(/\[(\d+)\]/g, ".$1");
  return normalized.split(".").reduce((acc, key) => (acc == null ? undefined : acc[key]), obj);
}

function setByPath(obj, path, value) {
  const parts = String(path).split(".");
  let current = obj;
  for (let i = 0; i < parts.length - 1; i += 1) {
    const key = parts[i];
    if (!current[key] || typeof current[key] !== "object" || Array.isArray(current[key])) {
      current[key] = {};
    }
    current = current[key];
  }
  current[parts[parts.length - 1]] = value;
}

function splitArgs(value) {
  const args = [];
  let current = "";
  let depth = 0;
  for (const char of value) {
    if (char === "," && depth === 0) {
      if (current.trim()) args.push(current.trim());
      current = "";
      continue;
    }
    if (char === "(") depth += 1;
    if (char === ")") depth -= 1;
    current += char;
  }
  if (current.trim()) args.push(current.trim());
  return args;
}

function stripQuotes(value) {
  if ((value.startsWith("'") && value.endsWith("'")) || (value.startsWith("\"") && value.endsWith("\""))) {
    return value.slice(1, -1);
  }
  return value;
}

function resolveToken(token, context) {
  if (token === "true") return true;
  if (token === "false") return false;
  if (token === "null") return null;
  if (/^-?\d+(\.\d+)?$/.test(token)) return Number(token);
  if ((/^['"].*['"]$/).test(token)) return stripQuotes(token);
  return getByPath(context, token);
}

function parseExpression(expr) {
  const trimmed = String(expr).trim();
  for (const fnName of ["firstNotBlank", "concat", "trim"]) {
    if (trimmed.startsWith(`${fnName}(`) && trimmed.endsWith(")")) {
      return {
        type: "function",
        fnName,
        args: splitArgs(trimmed.slice(fnName.length + 1, -1))
      };
    }
  }
  return { type: "path", path: trimmed };
}

function resolveExpression(expr, context) {
  const parsed = parseExpression(expr);
  if (parsed.type === "path") {
    return resolveToken(parsed.path, context);
  }
  if (parsed.fnName === "firstNotBlank") {
    for (const arg of parsed.args) {
      const value = resolveToken(arg, context);
      if (value !== undefined && value !== null && value !== "") return value;
    }
    return null;
  }
  if (parsed.fnName === "concat") {
    return parsed.args.map((arg) => {
      const value = resolveToken(arg, context);
      return value == null ? "" : String(value);
    }).join("");
  }
  if (parsed.fnName === "trim") {
    const value = parsed.args.length > 0 ? resolveToken(parsed.args[0], context) : "";
    return value == null ? "" : String(value).trim();
  }
  return undefined;
}

function resolveValue(value, context) {
  if (typeof value === "string") {
    const match = value.match(/^\{(.+)\}$/);
    if (match) return resolveExpression(match[1], context);
    return value;
  }
  if (Array.isArray(value)) return value.map((item) => resolveValue(item, context));
  if (value && typeof value === "object") {
    const out = {};
    for (const [key, nestedValue] of Object.entries(value)) {
      out[key] = resolveValue(nestedValue, context);
    }
    return out;
  }
  return value;
}

function shouldRunCommand(runIf, context) {
  if (!runIf) return true;
  const actual = getByPath(context, runIf.var);
  if (runIf.isBlank === true) return actual === undefined || actual === null || actual === "";
  if (runIf.isNotBlank === true) return !(actual === undefined || actual === null || actual === "");
  if (Object.prototype.hasOwnProperty.call(runIf, "equals")) return actual === runIf.equals;
  if (Object.prototype.hasOwnProperty.call(runIf, "notEquals")) return actual !== runIf.notEquals;
  return true;
}

function applyResponseMapping(responseMapping, context) {
  const output = {};
  for (const [targetPath, sourceExpression] of Object.entries(responseMapping || {})) {
    const value = resolveValue(sourceExpression, context);
    if (value !== undefined) setByPath(output, targetPath, value);
  }
  return output;
}

function normalizeNotFoundConfig(command = {}, request = {}) {
  const configured = command.onNotFound ?? request.onNotFound ?? "ignore";
  if (typeof configured === "string") return { action: configured, message: null };
  if (configured && typeof configured === "object") {
    return { action: configured.action || "ignore", message: configured.message || null };
  }
  return { action: "ignore", message: null };
}

function buildRowContext(context, row, rowIndex) {
  return { ...context, row, rowIndex };
}

function resolveRowsSource(rows, context) {
  const resolvedRows = resolveValue(rows, context);
  return Array.isArray(resolvedRows) ? resolvedRows : [];
}

async function run() {
  const context = {
    params: {
      email: "user@example.com"
    },
    foundContact: {
      Id: "003xx0000001234AAA",
      Email: "user@example.com",
      FirstName: "Dana",
      LastName: "Cohen"
    },
    issueUpdates: [
      { Id: "a01xx1", Title__c: "Initial Investigation", Notes__c: "Existing child row" },
      { Id: "a01xx2", Title__c: "Follow Up", Notes__c: "Second row" }
    ],
    input: {
      issueUpdates: [
        { Id: "a01xx1", title: "Initial Investigation", notes: "Updated row" },
        { title: "New Follow Up", notes: "New row" }
      ],
      _deletedRepeatGroups: {
        issueUpdates: ["a01delete"]
      }
    },
    createdCase: {
      id: "500xx0000007777AAA"
    }
  };

  assert.equal(resolveValue("{trim('  hi  ')}", context), "hi");
  assert.equal(resolveValue("{concat(foundContact.FirstName, ' ', foundContact.LastName)}", context), "Dana Cohen");
  assert.equal(resolveValue("{firstNotBlank(missing.value, foundContact.Email)}", context), "user@example.com");

  const mapped = applyResponseMapping({
    "input.email": "{foundContact.Email}",
    "hidden.contactId": "{foundContact.Id}",
    "meta.foundContact": "{foundContact.Id}",
    "repeatGroups.issueUpdates": "{issueUpdates}"
  }, context);

  assert.equal(mapped.input.email, "user@example.com");
  assert.equal(mapped.hidden.contactId, "003xx0000001234AAA");
  assert.equal(mapped.meta.foundContact, "003xx0000001234AAA");
  assert.equal(mapped.repeatGroups.issueUpdates.length, 2);

  assert.equal(shouldRunCommand({ var: "foundContact.Id", isNotBlank: true }, context), true);
  assert.equal(shouldRunCommand({ var: "missing.value", isBlank: true }, context), true);

  const notFound = normalizeNotFoundConfig({ onNotFound: { action: "error", message: "Missing contact" } }, {});
  assert.deepEqual(notFound, { action: "error", message: "Missing contact" });

  const rows = resolveRowsSource("{input.issueUpdates}", context);
  assert.equal(rows.length, 2);

  const previewOps = rows.map((row, rowIndex) => {
    const rowContext = buildRowContext(context, row, rowIndex);
    const fields = resolveValue({
      Title__c: "{row.title}",
      Notes__c: "{row.notes}",
      Case__c: "{createdCase.id}"
    }, rowContext);

    return {
      action: row.Id ? "update" : "create",
      id: row.Id || null,
      fields
    };
  });

  assert.equal(previewOps[0].action, "update");
  assert.equal(previewOps[0].fields.Case__c, "500xx0000007777AAA");
  assert.equal(previewOps[1].action, "create");
  assert.equal(context.input._deletedRepeatGroups.issueUpdates[0], "a01delete");

  console.log("All NativeForms AWS protocol tests passed.");
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
