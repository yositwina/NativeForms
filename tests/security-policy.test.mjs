import assert from "node:assert/strict";
import crypto from "node:crypto";

function hashToken(token) {
  return crypto.createHash("sha256").update(String(token)).digest("hex");
}

function ensureFormToken(formSecurity, publishToken) {
  if (!publishToken) {
    throw new Error("Missing required field: publishToken");
  }
  if (!formSecurity || formSecurity.status !== "published") {
    throw new Error("Form is not published");
  }
  if (formSecurity.tokenHash !== hashToken(publishToken)) {
    throw new Error("Unauthorized: invalid publish token");
  }
}

function isRiskySubmitCommand(commandType) {
  return ["update", "delete", "upsertMany"].includes(commandType);
}

function validateFieldsForObject(objectApiName, fields, allowedWriteFields) {
  if (!fields || typeof fields !== "object") return;
  const allowed = allowedWriteFields?.[objectApiName] || [];
  for (const fieldName of Object.keys(fields)) {
    if (!allowed.includes(fieldName)) {
      throw new Error(`Field '${fieldName}' is not allowed for object '${objectApiName}'`);
    }
  }
}

function validatePrefillCommandAgainstPolicy(command, formSecurity) {
  const allowedCommands = formSecurity.prefillPolicy?.allowedCommands || [];
  const allowedObjects = formSecurity.prefillPolicy?.allowedObjects || [];

  if (!allowedCommands.includes(command.type)) {
    throw new Error(`Command type '${command.type}' is not allowed for prefill on form '${formSecurity.formId}'`);
  }

  if (command.objectApiName && !allowedObjects.includes(command.objectApiName)) {
    throw new Error(`Object '${command.objectApiName}' is not allowed for prefill on form '${formSecurity.formId}'`);
  }
}

function validateSubmitCommandAgainstPolicy(command, formSecurity) {
  const submitPolicy = formSecurity.submitPolicy || {};
  const allowedCommands = submitPolicy.allowedCommands || [];
  const allowedObjects = submitPolicy.allowedObjects || [];
  const allowedWriteFields = submitPolicy.allowedWriteFields || {};

  if (!allowedCommands.includes(command.type)) {
    throw new Error(`Command type '${command.type}' is not allowed for submit on form '${formSecurity.formId}'`);
  }

  if (command.objectApiName && !allowedObjects.includes(command.objectApiName)) {
    throw new Error(`Object '${command.objectApiName}' is not allowed for submit on form '${formSecurity.formId}'`);
  }

  if (isRiskySubmitCommand(command.type) && formSecurity.securityMode !== "secure-edit") {
    throw new Error(`Security mode '${formSecurity.securityMode}' does not allow command '${command.type}'`);
  }

  if (command.type === "create" || command.type === "update") {
    validateFieldsForObject(command.objectApiName, command.fields, allowedWriteFields);
  }

  if (command.type === "upsertMany") {
    validateFieldsForObject(command.objectApiName, command.fields, allowedWriteFields);
    if (command.relationshipField) {
      const allowed = allowedWriteFields?.[command.objectApiName] || [];
      if (!allowed.includes(command.relationshipField)) {
        throw new Error(`Relationship field '${command.relationshipField}' is not allowed for object '${command.objectApiName}'`);
      }
    }
  }
}

const secureEditPolicy = {
  formId: "problem-report-demo",
  status: "published",
  securityMode: "secure-edit",
  tokenHash: hashToken("demo-problem-report-v1-token"),
  prefillPolicy: {
    allowedCommands: ["findOne", "getById", "findMany"],
    allowedObjects: ["Contact", "Case"]
  },
  submitPolicy: {
    allowedCommands: ["create", "update", "upsertMany"],
    allowedObjects: ["Contact", "Case"],
    allowedWriteFields: {
      Contact: ["FirstName", "LastName", "Email"],
      Case: ["Subject", "Description", "Status", "Origin", "ContactId"]
    }
  },
  prefillDefinition: {
    commands: [{ type: "findMany", objectApiName: "Case" }],
    responseMapping: {
      "repeatGroups.existingCases": "{foundCases}"
    }
  },
  submitDefinition: {
    commands: [{ type: "create", objectApiName: "Case" }]
  }
};

const publicCreatePolicy = {
  ...secureEditPolicy,
  securityMode: "public-create"
};

ensureFormToken(secureEditPolicy, "demo-problem-report-v1-token");
assert.throws(() => ensureFormToken(secureEditPolicy, "wrong-token"), /invalid publish token/);
assert.equal(Array.isArray(secureEditPolicy.prefillDefinition.commands), true);
assert.equal(Array.isArray(secureEditPolicy.submitDefinition.commands), true);

validatePrefillCommandAgainstPolicy({
  type: "findMany",
  objectApiName: "Case"
}, secureEditPolicy);

assert.throws(() => validatePrefillCommandAgainstPolicy({
  type: "findMany",
  objectApiName: "Account"
}, secureEditPolicy), /not allowed for prefill/);

validateSubmitCommandAgainstPolicy({
  type: "create",
  objectApiName: "Case",
  fields: {
    Subject: "Test",
    Description: "Allowed",
    Origin: "Web",
    ContactId: "003xx"
  }
}, secureEditPolicy);

assert.throws(() => validateSubmitCommandAgainstPolicy({
  type: "update",
  objectApiName: "Case",
  fields: {
    Subject: "Test",
    OwnerId: "005xx"
  }
}, secureEditPolicy), /Field 'OwnerId' is not allowed/);

assert.throws(() => validateSubmitCommandAgainstPolicy({
  type: "upsertMany",
  objectApiName: "Case",
  relationshipField: "AccountId",
  fields: {
    Subject: "{row.Subject}",
    Description: "{row.Description}"
  }
}, secureEditPolicy), /Relationship field 'AccountId' is not allowed/);

assert.throws(() => validateSubmitCommandAgainstPolicy({
  type: "update",
  objectApiName: "Contact",
  fields: {
    FirstName: "Dana"
  }
}, publicCreatePolicy), /does not allow command 'update'/);

console.log("All NativeForms security policy tests passed.");
