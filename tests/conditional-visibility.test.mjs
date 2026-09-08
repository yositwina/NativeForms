import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const apex = readFileSync(new URL('../force-app/main/default/classes/NativeFormsPublisher.cls', import.meta.url), 'utf8');
function emittedFunction(name) {
  const line = apex.split(/\r?\n/).find(line => line.includes(`html += 'function ${name}(`));
  assert.ok(line, `Publisher emits ${name}`);
  return line.slice(line.indexOf("html += '") + 9, line.lastIndexOf("';"))
    .replace(/\\([\s\S])/g, (_, character) => ({ n: '\n', r: '\r', t: '\t' }[character] ?? character));
}
function control(value, extra = {}) {
  return { value, type: 'text', dataset: {}, ...extra };
}
function scope(fields) {
  for (const [key, controls] of Object.entries(fields)) {
    controls.forEach(control => { control.dataset.repeatFieldKey = key; });
  }
  return {
    querySelectorAll(selector) {
      const key = selector.match(/(?:name|data-repeat-field-key)=['"]([^'"]+)['"]/);
      return key ? fields[key[1]] || [] : Object.values(fields).flat();
    },
    querySelector(selector) {
      const fields = this.querySelectorAll(selector);
      return selector.includes(':checked') ? fields.find(field => field.checked) || null : fields[0] || null;
    }
  };
}
function runtime(fields = {}) {
  const context = vm.createContext({ form: scope(fields), console });
  for (const name of ['readFieldValue', 'readRepeatFieldValueByKey', 'evaluateSingleCondition', 'evaluateConditionExpression', 'evaluateElementConditions']) {
    vm.runInContext(emittedFunction(name), context);
  }
  return context;
}
function conditional(row, conditions, expression = '') {
  return {
    dataset: { conditions: JSON.stringify(conditions), conditionExpression: expression },
    closest(selector) { assert.equal(selector, '[data-repeat-row]'); return row; }
  };
}
const equals = value => ({ fieldKey: 'activity', operator: 'equals', value });

test('regular fields show and hide when the source changes', () => {
  const source = control('נסיעות');
  const api = runtime({ activity: [source] });
  const target = conditional(null, [equals('נסיעות')]);
  assert.equal(api.evaluateElementConditions(target), true);
  source.value = 'איסוף ציוד';
  assert.equal(api.evaluateElementConditions(target), false);
});

test('two records evaluate their own source independently', () => {
  const first = control('נסיעות');
  const second = control('איסוף ציוד');
  const api = runtime();
  const targetA = conditional(scope({ activity: [first] }), [equals('נסיעות')]);
  const targetB = conditional(scope({ activity: [second] }), [equals('נסיעות')]);
  assert.equal(api.evaluateElementConditions(targetA), true);
  assert.equal(api.evaluateElementConditions(targetB), false);
  second.value = 'נסיעות';
  first.value = '';
  assert.equal(api.evaluateElementConditions(targetA), false);
  assert.equal(api.evaluateElementConditions(targetB), true);
});

test('global fallback occurs only when the source is absent from the row', () => {
  const api = runtime({ activity: [control('נסיעות')] });
  assert.equal(api.evaluateElementConditions(conditional(scope({}), [equals('נסיעות')])), true);
  assert.equal(api.evaluateElementConditions(conditional(scope({ activity: [control('')] }), [equals('נסיעות')])), false);
  const checkbox = control('', { type: 'checkbox', checked: false });
  const target = conditional(scope({ activity: [checkbox] }), [{ fieldKey: 'activity', operator: 'isFalse' }]);
  assert.equal(api.evaluateElementConditions(target), true);
  checkbox.checked = true;
  assert.equal(api.evaluateElementConditions(target), false);
});

test('row conditions support compound AND/OR expressions', () => {
  const api = runtime();
  const approved = control('', { type: 'checkbox', checked: false });
  const row = scope({ activity: [control('נסיעות')], approved: [approved] });
  const conditions = [equals('נסיעות'), { fieldKey: 'approved', operator: 'isTrue' }, { fieldKey: 'missing', operator: 'isBlank' }];
  assert.equal(api.evaluateElementConditions(conditional(row, conditions, '1 AND 2')), false);
  assert.equal(api.evaluateElementConditions(conditional(row, conditions, '( 1 AND 2 ) OR 3')), true);
  approved.checked = true;
  assert.equal(api.evaluateElementConditions(conditional(row, conditions, '1 AND 2')), true);
});

test('adding a row reevaluates conditions after inserting it', () => {
  const calls = [];
  const row = {};
  const fragment = { querySelector: () => row };
  const host = { children: [], appendChild(value) { this.children.push(value); this.lastElementChild = row; calls.push('insert'); } };
  const template = { content: { cloneNode: () => fragment } };
  const context = vm.createContext({
    form: { querySelector: selector => selector.startsWith('template') ? template : host },
    setupRepeatRow() {}, applyDateConstraints() {}, initDatePickers() {}, initRepeatRowSignatures() {}, initLookupControls() {}, wireLiveValidation() {},
    evaluateAllFormulaFields() { calls.push('formulas'); },
    evaluateConditions() { calls.push('conditions'); }
  });
  vm.runInContext(emittedFunction('addRepeatRow'), context);
  context.addRepeatRow('activities');
  assert.equal(calls.at(-1), 'conditions');
  assert.ok(calls.indexOf('insert') < calls.indexOf('conditions'));
});

test('conditional ancestor visibility controls required validation without changing values', () => {
  let hidden = true;
  let checks = 0;
  const required = control('preserved value', {
    closest(selector) { assert.equal(selector, '[data-condition-hidden]'); return hidden ? {} : null; },
    setCustomValidity() {},
    checkValidity() { checks += 1; return false; },
    reportValidity() { return false; }
  });
  const context = vm.createContext({
    form: { querySelectorAll: () => [required] },
    updateCharacterCounter() {}
  });
  for (const name of ['isConditionHidden', 'validateField', 'validateAllFields']) {
    vm.runInContext(emittedFunction(name), context);
  }
  assert.equal(context.isConditionHidden(required), true);
  assert.equal(context.validateAllFields(), true);
  assert.equal(checks, 0);
  assert.equal(required.value, 'preserved value');
  hidden = false;
  assert.equal(context.isConditionHidden(required), false);
  assert.equal(context.validateAllFields(), false);
  assert.equal(checks, 1);
});

test('visibility evaluation updates wrappers and clears the validation marker on reveal', () => {
  const source = control('other');
  const target = conditional(scope({ activity: [source] }), [equals('נסיעות')]);
  target.style = {};
  target.setAttribute = (name, value) => { assert.equal(name, 'data-condition-hidden'); target.dataset.conditionHidden = value; };
  target.removeAttribute = name => { assert.equal(name, 'data-condition-hidden'); delete target.dataset.conditionHidden; };
  const api = runtime();
  api.form.querySelectorAll = () => [target];
  api.manualVisibilityState = {};
  vm.runInContext(emittedFunction('evaluateConditions'), api);
  api.evaluateConditions();
  assert.equal(target.hidden, true);
  assert.equal(target.style.display, 'none');
  assert.equal(target.dataset.conditionHidden, 'true');
  source.value = 'נסיעות';
  api.evaluateConditions();
  assert.equal(target.hidden, false);
  assert.equal(target.style.display, '');
  assert.equal(Object.hasOwn(target.dataset, 'conditionHidden'), false);
});

test('visible required date and time fields retain native required validation', () => {
  for (const kind of ['Date', 'Time']) {
    const field = control('', {
      dataset: { [`nativeforms${kind}`]: 'true' },
      closest: () => null, setCustomValidity() {}, checkValidity: () => false, reportValidity: () => false
    });
    const api = vm.createContext({ updateCharacterCounter() {} });
    for (const name of ['isConditionHidden', `validate${kind}Field`, 'validateField']) {
      vm.runInContext(emittedFunction(name), api);
    }
    assert.equal(api.validateField(field, false), false, `blank required ${kind} is invalid`);
  }
});

test('hidden valid date and time values still serialize in normalized format', () => {
  const date = control('09/08/2026', { name: 'date', dataset: { dateFormat: 'us' }, closest: () => ({}) });
  const time = control('7:30 PM', { name: 'time', dataset: { timeFormat: '12h' }, closest: () => ({}) });
  const api = vm.createContext({
    form: { querySelectorAll: selector => selector.includes('date') ? [date] : [time] },
    validateDateField() { assert.fail('hidden date must not validate'); },
    validateTimeField() { assert.fail('hidden time must not validate'); }
  });
  for (const name of ['isConditionHidden', 'isValidDateParts', 'parseDateValue', 'parseTimeValue', 'formatTimeForField', 'collectNormalizedDateValues', 'collectNormalizedTimeValues']) {
    vm.runInContext(emittedFunction(name), api);
  }
  assert.equal(api.collectNormalizedDateValues().values.date, '2026-09-08');
  assert.equal(api.collectNormalizedTimeValues().values.time, '19:30');
});
