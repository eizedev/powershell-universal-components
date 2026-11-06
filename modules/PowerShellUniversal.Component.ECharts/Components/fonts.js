/*
 * Text sizes from the app's theme. An app stylesheet sets --psu-chart-font-size (e.g. 14px); every text
 * of a chart then grows or shrinks by the same factor against ECharts' base of 12 px: axis labels,
 * legend, data labels, tooltip, titles, and the smaller sizes the width rules use in narrow charts
 * (responsive() in buildOption.js), so a phone still gets smaller text than a wide screen.
 *
 * Without the property the option is returned unchanged.
 */

export const BASE_FONT = 12;
const MIN_FONT = 8;
const MAX_FONT = 32;

// ECharts' own sizes where an option leaves them out (ECharts 6.1): these are filled in before
// scaling, so the factor reaches them and the layout code (layout.js) reads the size that is drawn
const TITLE = 18;
const TOOLTIP = 14;
const AXES = ["xAxis", "yAxis", "radiusAxis", "angleAxis", "singleAxis", "parallelAxis"];
const SERIES_LABELS = ["label", "endLabel", "edgeLabel", "upperLabel"];

/*
 * The size an app stylesheet asks for: px or a bare number, rem/em against the root's font size.
 * Anything else, or a size outside 8 ... 32 px, is ignored.
 */
export function parseFontSize(value, rootPx = 16) {
    const m = /^\s*(\d+(?:\.\d+)?)\s*(px|rem|em)?\s*$/i.exec(String(value ?? ""));
    if (!m) return undefined;
    const n = Number(m[1]) * (m[2] && m[2].toLowerCase() !== "px" ? rootPx : 1);
    return n >= MIN_FONT && n <= MAX_FONT ? n : undefined;
}

function isPlainObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v) && Object.getPrototypeOf(v) === Object.prototype;
}

function list(v) {
    return v === undefined || v === null ? [] : Array.isArray(v) ? v : [v];
}

// a copy with every numeric fontSize and lineHeight multiplied; arrays of plain values (data) are kept
function scaled(value, factor) {
    if (Array.isArray(value)) {
        return value.some((v) => isPlainObject(v) || Array.isArray(v)) ? value.map((v) => scaled(v, factor)) : value;
    }
    if (!isPlainObject(value)) return value;
    const out = {};
    for (const [k, v] of Object.entries(value)) {
        out[k] = (k === "fontSize" || k === "lineHeight") && typeof v === "number" ? Math.round(v * factor * 10) / 10 : scaled(v, factor);
    }
    return out;
}

// sets `obj[key].fontSize` to `size` when it has none; returns the (copied) object
function withDefault(obj, key, size) {
    if (!isPlainObject(obj)) return obj;
    const part = isPlainObject(obj[key]) ? obj[key] : {};
    return part.fontSize === undefined ? { ...obj, [key]: { ...part, fontSize: size } } : obj;
}

function mapList(v, fn) {
    if (v === undefined || v === null) return v;
    return Array.isArray(v) ? v.map(fn) : fn(v);
}

// ECharts' defaults written into the parts of the option that exist
function withDefaults(option) {
    const o = { ...option, textStyle: { ...(option.textStyle || {}), fontSize: (option.textStyle && option.textStyle.fontSize) ?? BASE_FONT } };
    o.title = mapList(o.title, (t) => withDefault(withDefault(t, "textStyle", TITLE), "subtextStyle", BASE_FONT));
    o.legend = mapList(o.legend, (l) => withDefault(l, "textStyle", BASE_FONT));
    if (o.tooltip) o.tooltip = mapList(o.tooltip, (t) => withDefault(t, "textStyle", TOOLTIP));
    for (const axis of AXES) {
        o[axis] = mapList(o[axis], (a) => withDefault(withDefault(a, "axisLabel", BASE_FONT), "nameTextStyle", BASE_FONT));
    }
    o.radar = mapList(o.radar, (r) => withDefault(r, "axisName", BASE_FONT));
    o.series = list(o.series).map((s) => SERIES_LABELS.reduce((acc, key) => (isPlainObject(acc[key]) ? withDefault(acc, key, BASE_FONT) : acc), s));
    return o;
}

/*
 * The option with its text sizes for a base size `size` (px): unchanged for the default of 12 px or
 * a missing size, otherwise ECharts' defaults filled in and every size multiplied by size / 12.
 */
export function scaleFonts(option, size) {
    const factor = size ? size / BASE_FONT : 1;
    if (!option || !Number.isFinite(factor) || factor === 1) return option;
    return scaled(withDefaults(option), factor);
}
