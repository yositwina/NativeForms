import { Parser } from './formulaExprEval';

const FORMULA_SOURCE_REGEX = /\{([a-zA-Z0-9_]+)\}/g;
const DEFAULT_NUMERIC_EMPTY = null;

function sanitizeReferenceKey(fieldKey) {
    return `field_${String(fieldKey || '').replace(/[^a-zA-Z0-9_]/g, '_')}`;
}

function isBlankValue(value) {
    return value === null || value === undefined || String(value) === '';
}

function toText(value) {
    return isBlankValue(value) ? '' : String(value);
}

function toNumber(value) {
    if (value === null || value === undefined || value === '') {
        return null;
    }
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
}

function normalizeComparable(value) {
    if (typeof value === 'string') {
        const trimmed = value.trim().toLowerCase();
        if (trimmed === 'true') {
            return true;
        }
        if (trimmed === 'false') {
            return false;
        }
    }
    return value;
}

function parseIsoDateLike(rawValue) {
    const value = String(rawValue || '').trim();
    if (!value) {
        return null;
    }
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function pad2(value) {
    return String(value).padStart(2, '0');
}

function isoLocalDate(dateValue) {
    return `${dateValue.getFullYear()}-${pad2(dateValue.getMonth() + 1)}-${pad2(dateValue.getDate())}`;
}

function isoLocalDateTime(dateValue) {
    return `${isoLocalDate(dateValue)}T${pad2(dateValue.getHours())}:${pad2(dateValue.getMinutes())}:${pad2(dateValue.getSeconds())}`;
}

function runtimeFunctions() {
    return {
        CONCAT: (...args) => args.map((item) => toText(item)).join(''),
        IF: (conditionValue, trueValue, falseValue) => (conditionValue ? trueValue : falseValue),
        COALESCE: (...args) => {
            for (let index = 0; index < args.length; index += 1) {
                if (!isBlankValue(args[index])) {
                    return args[index];
                }
            }
            return null;
        },
        ISBLANK: (value) => isBlankValue(value),
        VALUE: (value) => toNumber(value),
        TEXT: (value) => toText(value),
        ROUND: (value, digits = 0) => {
            const numericValue = toNumber(value);
            const numericDigits = Number.isFinite(Number(digits)) ? Number(digits) : 0;
            if (numericValue === null) {
                return null;
            }
            const factor = 10 ** numericDigits;
            return Math.round(numericValue * factor) / factor;
        },
        ABS: (value) => {
            const numericValue = toNumber(value);
            return numericValue === null ? null : Math.abs(numericValue);
        },
        MIN: (...args) => {
            const values = args.map((item) => toNumber(item)).filter((item) => item !== null);
            return values.length ? Math.min(...values) : null;
        },
        MAX: (...args) => {
            const values = args.map((item) => toNumber(item)).filter((item) => item !== null);
            return values.length ? Math.max(...values) : null;
        },
        TODAY: () => isoLocalDate(new Date()),
        NOW: () => isoLocalDateTime(new Date()),
        YEAR: (value) => {
            const parsed = parseIsoDateLike(value);
            return parsed ? parsed.getFullYear() : null;
        },
        MONTH: (value) => {
            const parsed = parseIsoDateLike(value);
            return parsed ? parsed.getMonth() + 1 : null;
        },
        DAY: (value) => {
            const parsed = parseIsoDateLike(value);
            return parsed ? parsed.getDate() : null;
        }
    };
}

function buildParser() {
    const parser = new Parser({
        operators: {
            add: true,
            subtract: true,
            multiply: true,
            divide: true,
            remainder: false,
            power: false,
            factorial: false,
            comparison: true,
            logical: true,
            conditional: true,
            concatenate: false,
            assignment: false,
            array: false,
            fndef: false,
            in: false
        },
        allowMemberAccess: false
    });
    parser.unaryOps = {
        '-': (value) => -Number(value),
        '+': Number,
        not: (value) => !value
    };
    parser.binaryOps = {
        '+': (left, right) => Number(left) + Number(right),
        '-': (left, right) => Number(left) - Number(right),
        '*': (left, right) => Number(left) * Number(right),
        '/': (left, right) => Number(left) / Number(right),
        '==': (left, right) => normalizeComparable(left) === normalizeComparable(right),
        '!=': (left, right) => normalizeComparable(left) !== normalizeComparable(right),
        '>': (left, right) => left > right,
        '<': (left, right) => left < right,
        '>=': (left, right) => left >= right,
        '<=': (left, right) => left <= right,
        and: (left, right) => Boolean(left && right),
        or: (left, right) => Boolean(left || right)
    };
    parser.ternaryOps = {
        '?': (conditionValue, trueValue, falseValue) => (conditionValue ? trueValue : falseValue)
    };
    parser.functions = runtimeFunctions();
    parser.consts = {
        true: true,
        false: false
    };
    return parser;
}

function normalizeExpression(expression) {
    return String(expression || '')
        .replace(/\bAND\b/g, 'and')
        .replace(/\bOR\b/g, 'or')
        .replace(/\bTRUE\b/g, 'true')
        .replace(/\bFALSE\b/g, 'false')
        .trim();
}

function extractFormulaReferences(expression) {
    const references = [];
    const seen = new Set();
    const normalizedExpression = normalizeExpression(expression);
    let match;
    while ((match = FORMULA_SOURCE_REGEX.exec(normalizedExpression)) !== null) {
        const fieldKey = String(match[1] || '').trim();
        if (!fieldKey || seen.has(fieldKey)) {
            continue;
        }
        seen.add(fieldKey);
        references.push(fieldKey);
    }
    return references;
}

function compileFormula(expression) {
    const references = extractFormulaReferences(expression);
    const variableMap = {};
    references.forEach((fieldKey) => {
        variableMap[fieldKey] = sanitizeReferenceKey(fieldKey);
    });
    const normalizedExpression = normalizeExpression(expression).replace(FORMULA_SOURCE_REGEX, (_, fieldKey) => variableMap[fieldKey] || sanitizeReferenceKey(fieldKey));
    const parser = buildParser();
    const compiled = parser.parse(normalizedExpression);
    return {
        compiled,
        references,
        variableMap
    };
}

function normalizeOutputValue(targetType, value) {
    if (targetType === 'number') {
        return toNumber(value);
    }
    if (value === null || value === undefined) {
        return '';
    }
    return String(value);
}

export function evaluateFormulaExpression(expression, sourceValues = {}, targetType = 'text') {
    const compiled = compileFormula(expression);
    const parserValues = {};
    compiled.references.forEach((fieldKey) => {
        parserValues[compiled.variableMap[fieldKey]] = sourceValues[fieldKey];
    });
    const rawValue = compiled.compiled.evaluate(parserValues);
    return {
        references: compiled.references,
        value: normalizeOutputValue(targetType, rawValue)
    };
}

export function validateFormulaConfig({
    expression,
    fieldKey,
    targetType,
    elements = [],
    insideRepeatGroup = false
}) {
    const normalizedExpression = normalizeExpression(expression);
    if (insideRepeatGroup) {
        return { valid: false, message: 'Formula fields are not supported inside repeat groups in V1.', references: [] };
    }
    if (!['text', 'number'].includes(targetType)) {
        return { valid: false, message: 'Only Text and Number fields can use formulas in V1.', references: [] };
    }
    if (!normalizedExpression) {
        return { valid: true, message: '', references: [] };
    }
    let compiled;
    try {
        compiled = compileFormula(normalizedExpression);
    } catch (error) {
        return { valid: false, message: error?.message || 'Formula syntax is invalid.', references: [] };
    }

    const byFieldKey = new Map();
    (elements || []).forEach((item) => {
        if (item?.fieldKey) {
            byFieldKey.set(item.fieldKey, item);
        }
    });

    for (let index = 0; index < compiled.references.length; index += 1) {
        const referenceKey = compiled.references[index];
        if (referenceKey === fieldKey) {
            return { valid: false, message: 'A formula field cannot reference itself.', references: compiled.references };
        }
        const referencedElement = byFieldKey.get(referenceKey);
        if (!referencedElement) {
            return { valid: false, message: `Unknown field reference: ${referenceKey}.`, references: compiled.references };
        }
        const config = referencedElement.configJson ? JSON.parse(referencedElement.configJson) : {};
        if (config?.isFormula === true) {
            return { valid: false, message: `Formula fields cannot reference another formula field: ${referenceKey}.`, references: compiled.references };
        }
    }

    return { valid: true, message: '', references: compiled.references };
}

export function previewFormulaValue({
    expression,
    fieldKey,
    targetType,
    elements = [],
    insideRepeatGroup = false,
    sourceValues = {}
}) {
    const validation = validateFormulaConfig({
        expression,
        fieldKey,
        targetType,
        elements,
        insideRepeatGroup
    });
    if (!validation.valid) {
        return {
            valid: false,
            message: validation.message,
            references: validation.references || [],
            value: targetType === 'number' ? DEFAULT_NUMERIC_EMPTY : ''
        };
    }
    if (!normalizeExpression(expression)) {
        return {
            valid: true,
            message: '',
            references: [],
            value: targetType === 'number' ? DEFAULT_NUMERIC_EMPTY : ''
        };
    }
    try {
        const result = evaluateFormulaExpression(expression, sourceValues, targetType);
        return {
            valid: true,
            message: '',
            references: result.references,
            value: result.value
        };
    } catch (error) {
        return {
            valid: false,
            message: error?.message || 'Formula evaluation failed.',
            references: validation.references || [],
            value: targetType === 'number' ? DEFAULT_NUMERIC_EMPTY : ''
        };
    }
}
