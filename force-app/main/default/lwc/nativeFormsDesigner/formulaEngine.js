import { Parser } from './formulaExprEval';

const FORMULA_SOURCE_REGEX = /\{((?:row\.)?[a-zA-Z0-9_]+)\}/g;
const ISO_DATE_ONLY_REGEX = /^(\d{4})-(\d{2})-(\d{2})$/;
const DEFAULT_NUMERIC_EMPTY = null;

// Language used by DAYNAME when the formula does not pass one explicitly. The designer sets this
// from the version language so the preview matches what the published form will render.
let formulaLanguage = 'en';

export function setFormulaLanguage(languageCode) {
    formulaLanguage = String(languageCode || '').trim() || 'en';
}

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

function toInt(value) {
    const numeric = toNumber(value);
    return numeric === null ? null : Math.trunc(numeric);
}

function parseIsoDateLike(rawValue) {
    const value = String(rawValue || '').trim();
    if (!value) {
        return null;
    }
    // A bare "YYYY-MM-DD" is parsed as UTC midnight by the JS engine, but every reader below
    // (getFullYear/getMonth/getDate, isoLocalDate, addDays) is local. West of Greenwich that
    // reported the previous day. Build local midnight so all date maths stays in one timezone.
    const dateOnly = value.match(ISO_DATE_ONLY_REGEX);
    if (dateOnly) {
        const year = Number(dateOnly[1]);
        const month = Number(dateOnly[2]);
        const day = Number(dateOnly[3]);
        const parsed = new Date(year, month - 1, day);
        return parsed.getFullYear() === year && parsed.getMonth() === month - 1 && parsed.getDate() === day
            ? parsed
            : null;
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

function isIsoDateValue(value) {
    return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value.trim()) && parseIsoDateLike(value) !== null;
}

function addDays(dateValue, days) {
    const parsed = parseIsoDateLike(dateValue);
    const numericDays = Number(days);
    if (!parsed || !Number.isFinite(numericDays)) {
        return NaN;
    }
    parsed.setDate(parsed.getDate() + numericDays);
    return isoLocalDate(parsed);
}

function diffDays(leftDateValue, rightDateValue) {
    const leftDate = parseIsoDateLike(leftDateValue);
    const rightDate = parseIsoDateLike(rightDateValue);
    if (!leftDate || !rightDate) {
        return NaN;
    }
    const msPerDay = 24 * 60 * 60 * 1000;
    return Math.round((leftDate.getTime() - rightDate.getTime()) / msPerDay);
}

function addFormulaValues(left, right) {
    if (isIsoDateValue(left) && Number.isFinite(Number(right))) {
        return addDays(left, right);
    }
    if (Number.isFinite(Number(left)) && isIsoDateValue(right)) {
        return addDays(right, left);
    }
    return Number(left) + Number(right);
}

function subtractFormulaValues(left, right) {
    if (isIsoDateValue(left) && Number.isFinite(Number(right))) {
        return addDays(left, -Number(right));
    }
    if (isIsoDateValue(left) && isIsoDateValue(right)) {
        return diffDays(left, right);
    }
    return Number(left) - Number(right);
}

function isoLocalDateTime(dateValue) {
    return `${isoLocalDate(dateValue)}T${pad2(dateValue.getHours())}:${pad2(dateValue.getMinutes())}:${pad2(dateValue.getSeconds())}`;
}

function runtimeFunctions() {
    return {
        CONCAT: (...args) => args.map((item) => toText(item)).join(''),
        URLENCODE: (value) => encodeURIComponent(toText(value)),
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
        },
        // WEEKDAY matches the Salesforce convention: 1 = Sunday .. 7 = Saturday.
        WEEKDAY: (value) => {
            const parsed = parseIsoDateLike(value);
            return parsed ? parsed.getDay() + 1 : null;
        },
        DAYNAME: (value, locale) => {
            const parsed = parseIsoDateLike(value);
            if (!parsed) {
                return null;
            }
            const requested = toText(locale) || formulaLanguage;
            try {
                return new Intl.DateTimeFormat(requested, { weekday: 'long' }).format(parsed);
            } catch (error) {
                return new Intl.DateTimeFormat('en', { weekday: 'long' }).format(parsed);
            }
        },
        DATE: (year, month, day) => {
            const yearValue = toInt(year);
            const monthValue = toInt(month);
            const dayValue = toInt(day);
            if (yearValue === null || monthValue === null || dayValue === null || yearValue < 1000) {
                return null;
            }
            const parsed = new Date(yearValue, monthValue - 1, dayValue);
            const roundTrips = parsed.getFullYear() === yearValue
                && parsed.getMonth() === monthValue - 1
                && parsed.getDate() === dayValue;
            return roundTrips ? isoLocalDate(parsed) : null;
        },
        // Clamps to the last day of the target month, matching Salesforce ADDMONTHS.
        ADDMONTHS: (value, months) => {
            const parsed = parseIsoDateLike(value);
            const count = toInt(months);
            if (!parsed || count === null) {
                return null;
            }
            const targetMonth = parsed.getMonth() + count;
            const lastDayOfTarget = new Date(parsed.getFullYear(), targetMonth + 1, 0).getDate();
            return isoLocalDate(new Date(parsed.getFullYear(), targetMonth, Math.min(parsed.getDate(), lastDayOfTarget)));
        },
        DATEVALUE: (value) => {
            const parsed = parseIsoDateLike(value);
            return parsed ? isoLocalDate(parsed) : null;
        },
        LEFT: (value, count) => {
            const length = toInt(count);
            return length === null || length <= 0 ? '' : toText(value).slice(0, length);
        },
        RIGHT: (value, count) => {
            const length = toInt(count);
            return length === null || length <= 0 ? '' : toText(value).slice(-length);
        },
        // Start is 1-based, matching Salesforce MID.
        MID: (value, start, count) => {
            const startValue = toInt(start);
            const length = toInt(count);
            if (startValue === null || length === null || length <= 0) {
                return '';
            }
            const from = Math.max(0, startValue - 1);
            return toText(value).slice(from, from + length);
        },
        LEN: (value) => toText(value).length,
        TRIM: (value) => toText(value).trim(),
        UPPER: (value) => toText(value).toUpperCase(),
        LOWER: (value) => toText(value).toLowerCase(),
        // split/join rather than a regex: no ReDoS surface and no pattern injection.
        SUBSTITUTE: (value, search, replacement) => {
            const text = toText(value);
            const needle = toText(search);
            return needle ? text.split(needle).join(toText(replacement)) : text;
        },
        CONTAINS: (value, search) => toText(value).indexOf(toText(search)) >= 0,
        BEGINS: (value, search) => toText(value).startsWith(toText(search)),
        // Function forms of the existing lowercase and/or operators, with identical truthiness.
        AND: (...args) => args.every((item) => Boolean(item)),
        OR: (...args) => args.some((item) => Boolean(item)),
        NOT: (value) => !value,
        MOD: (value, divisor) => {
            const numericValue = toNumber(value);
            const numericDivisor = toNumber(divisor);
            if (numericValue === null || numericDivisor === null || numericDivisor === 0) {
                return null;
            }
            return numericValue % numericDivisor;
        },
        CEILING: (value) => {
            const numericValue = toNumber(value);
            return numericValue === null ? null : Math.ceil(numericValue);
        },
        FLOOR: (value) => {
            const numericValue = toNumber(value);
            return numericValue === null ? null : Math.floor(numericValue);
        },
        POWER: (base, exponent) => {
            const numericBase = toNumber(base);
            const numericExponent = toNumber(exponent);
            if (numericBase === null || numericExponent === null) {
                return null;
            }
            const result = numericBase ** numericExponent;
            return Number.isFinite(result) ? result : null;
        },
        SQRT: (value) => {
            const numericValue = toNumber(value);
            return numericValue === null || numericValue < 0 ? null : Math.sqrt(numericValue);
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
        '+': addFormulaValues,
        '-': subtractFormulaValues,
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

// Applies replacer only to the parts of the expression that sit outside quoted string literals,
// so CONCAT("AND", ...) keeps its literal text intact.
function replaceOutsideStringLiterals(source, replacer) {
    return String(source || '').replace(
        /"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|[^"']+/g,
        (segment) => (segment[0] === '"' || segment[0] === "'" ? segment : replacer(segment))
    );
}

function normalizeExpression(expression) {
    // AND/OR are infix operators in the parser, so uppercase forms are folded to lowercase.
    // The negative lookahead leaves "AND(" and "OR(" alone: those resolve to the AND()/OR()
    // functions instead, which is what a Salesforce admin will reach for first.
    return replaceOutsideStringLiterals(expression, (segment) => segment
        .replace(/\bAND\b(?!\s*\()/g, 'and')
        .replace(/\bOR\b(?!\s*\()/g, 'or')
        .replace(/\bTRUE\b/g, 'true')
        .replace(/\bFALSE\b/g, 'false')).trim();
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

function findRepeatGroupAncestor(item, elements = []) {
    let parentElementId = item?.parentElementId;
    while (parentElementId) {
        const parent = elements.find((candidate) => candidate.elementId === parentElementId);
        if (!parent) {
            return null;
        }
        if (parent.elementType === 'repeatGroup') {
            return parent;
        }
        parentElementId = parent.parentElementId;
    }
    return null;
}

function rowReferenceKey(referenceKey) {
    return String(referenceKey || '').startsWith('row.')
        ? String(referenceKey).slice(4)
        : '';
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
        const rawValue = Object.prototype.hasOwnProperty.call(sourceValues || {}, fieldKey)
            ? sourceValues[fieldKey]
            : '';
        parserValues[compiled.variableMap[fieldKey]] = rawValue === null || rawValue === undefined ? '' : rawValue;
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
    insideRepeatGroup = false,
    allowFormulaReferences = false
}) {
    const normalizedExpression = normalizeExpression(expression);
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

    const targetElement = (elements || []).find((item) => item?.fieldKey === fieldKey) || null;
    const targetRepeatGroup = insideRepeatGroup ? findRepeatGroupAncestor(targetElement, elements) : null;
    const rowFieldKeys = new Set(
        targetRepeatGroup
            ? (elements || [])
                .filter((item) => item?.parentElementId === targetRepeatGroup.elementId && item?.fieldKey)
                .map((item) => item.fieldKey)
            : []
    );
    const byFieldKey = new Map();
    (elements || []).forEach((item) => {
        if (item?.fieldKey) {
            byFieldKey.set(item.fieldKey, item);
        }
    });

    for (let index = 0; index < compiled.references.length; index += 1) {
        const referenceKey = compiled.references[index];
        const rowKey = rowReferenceKey(referenceKey);
        if (rowKey) {
            if (!insideRepeatGroup) {
                return { valid: false, message: 'Row references can only be used inside a Records List.', references: compiled.references };
            }
            if (rowKey === fieldKey) {
                return { valid: false, message: 'A formula field cannot reference itself.', references: compiled.references };
            }
            if (!rowFieldKeys.has(rowKey)) {
                return { valid: false, message: `Unknown row field reference: ${rowKey}.`, references: compiled.references };
            }
            const referencedRowElement = (elements || []).find((item) => item?.parentElementId === targetRepeatGroup?.elementId && item?.fieldKey === rowKey);
            const rowConfig = referencedRowElement?.configJson ? JSON.parse(referencedRowElement.configJson) : {};
            if (rowConfig?.isFormula === true && !allowFormulaReferences) {
                return { valid: false, message: `Formula fields cannot reference another formula field: ${referenceKey}.`, references: compiled.references };
            }
            continue;
        }
        if (referenceKey === fieldKey) {
            return { valid: false, message: 'A formula field cannot reference itself.', references: compiled.references };
        }
        const referencedElement = byFieldKey.get(referenceKey);
        if (!referencedElement) {
            return { valid: false, message: `Unknown field reference: ${referenceKey}.`, references: compiled.references };
        }
        if (insideRepeatGroup && referencedElement.parentElementId && findRepeatGroupAncestor(referencedElement, elements)) {
            return { valid: false, message: `Use {row.${referenceKey}} for row field references.`, references: compiled.references };
        }
        const config = referencedElement.configJson ? JSON.parse(referencedElement.configJson) : {};
        if (config?.isFormula === true && !allowFormulaReferences) {
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
    sourceValues = {},
    allowFormulaReferences = false
}) {
    const validation = validateFormulaConfig({
        expression,
        fieldKey,
        targetType,
        elements,
        insideRepeatGroup,
        allowFormulaReferences
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
