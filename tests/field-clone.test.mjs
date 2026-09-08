import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const source = readFileSync(new URL('../force-app/main/default/lwc/nativeFormsDesigner/nativeFormsDesigner.js', import.meta.url), 'utf8');
const start = source.indexOf('    get selectedElementCanClone()');
const end = source.indexOf('    get showColumnLayoutPicker()', start);
function harness(cloneField) {
    const context = vm.createContext({ cloneField });
    const Designer = vm.runInContext(`(class { ${source.slice(start, end)} })`, context);
    const designer = new Designer();
    Object.assign(designer, {
        selectedElement: { id: 'source', elementType: 'text', label: 'Latest label', fieldKey: 'text1', configJson: '{"formulaExpression":"{other}"}' },
        selectedProjectId: 'project', selectedFormId: 'form', selectedVersionId: 'draft',
        pendingVisualSavePromises: [],
        applyEditorDraft() {}, captureUndoStep: () => 'undo', removeUndoStep() {},
        loadWorkspace: async () => {}, syncSelectedState() {}, normalizeError: error => error.message
    });
    return designer;
}

test('Clone is available only for fields and disabled for read-only/busy state', () => {
    const designer = harness(() => {});
    for (const elementType of ['text', 'textarea', 'select', 'lookup', 'signature']) {
        designer.selectedElement.elementType = elementType;
        assert.equal(designer.selectedElementCanClone, true);
    }
    for (const elementType of ['section', 'group', 'columns', 'repeatGroup', 'heading', 'image', 'spacer', 'button', 'submitButton', 'userVerification']) {
        designer.selectedElement.elementType = elementType;
        assert.equal(designer.selectedElementCanClone, false);
    }
    designer.selectedElement.elementType = 'text';
    designer.isSelectedVersionReadOnly = true;
    assert.equal(designer.cloneFieldDisabled, true);
    designer.isSelectedVersionReadOnly = false;
    designer.isCloningField = true;
    assert.equal(designer.cloneFieldDisabled, true);
});

test('Clone waits for existing saves, preserves clicked snapshot, prevents double clicks and selects the copy', async () => {
    let release;
    const calls = [];
    const designer = harness(async payload => { calls.push(JSON.parse(payload.inputJson)); return { id: 'copy' }; });
    designer.pendingVisualSavePromises = [new Promise(resolve => { release = resolve; })];
    const cloning = designer.handleCloneField();
    await designer.handleCloneField();
    assert.equal(calls.length, 0);
    designer.selectedElement = { id: 'another', elementType: 'text' };
    release();
    await cloning;
    assert.equal(calls.length, 1);
    assert.equal(calls[0].id, 'source');
    assert.equal(calls[0].label, 'Latest label');
    assert.equal(calls[0].configJson, '{"formulaExpression":"{other}"}');
    assert.equal(designer.selectedElementId, 'copy');
    assert.equal(designer.isCloningField, false);
});

test('Failed pending save aborts Clone instead of copying stale data', async () => {
    let calls = 0;
    const designer = harness(async () => { calls++; });
    designer.pendingVisualSavePromises = [Promise.reject(new Error('Save failed'))];
    await designer.handleCloneField();
    assert.equal(calls, 0);
    assert.equal(designer.errorMessage, 'Save failed');
    assert.equal(designer.isCloningField, false);
});
