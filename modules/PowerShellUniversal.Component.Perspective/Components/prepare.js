/*
 * Pure helpers of the Perspective component (no React, no browser APIs), so node --test covers them.
 */
import { resolveColumn, columnsOf, camelCase } from "../../../shared/js/columns.js";

export const THEMES = { light: "Pro Light", dark: "Pro Dark" };

// column names from PowerShell are matched like everywhere else (case-insensitive) against the data
function mapColumns(list, keys) {
    return (Array.isArray(list) ? list : list ? [list] : []).map((c) => resolveColumn(c, keys) ?? c);
}

// the viewer configuration from the simple parameters; -Config (the full Perspective config) wins
export function viewerConfig(props, keys, mode) {
    const config = {
        plugin: props.plugin || "Datagrid",
        theme: THEMES[mode] || THEMES.light,
        settings: Boolean(props.settings)
    };
    if (props.columns) config.columns = mapColumns(props.columns, keys);
    if (props.groupBy) config.group_by = mapColumns(props.groupBy, keys);
    if (props.splitBy) config.split_by = mapColumns(props.splitBy, keys);
    if (props.sort) {
        // "Column desc" / "Column" (asc)
        config.sort = (Array.isArray(props.sort) ? props.sort : [props.sort]).map((s) => {
            const [name, dir] = String(s).trim().split(/\s+/);
            return [resolveColumn(name, keys) ?? name, /^desc/i.test(dir || "") ? "desc" : "asc"];
        });
    }
    if (props.aggregates && typeof props.aggregates === "object") {
        config.aggregates = Object.fromEntries(Object.entries(props.aggregates).map(([k, v]) => [resolveColumn(k, keys) ?? k, String(v)]));
    }
    if (props.filter) {
        // "Column == value" / "Column > 5": column, operator, value
        config.filter = (Array.isArray(props.filter) ? props.filter : [props.filter]).map((f) => {
            const m = /^\s*(\S+)\s+(==|!=|<=|>=|<|>|contains|in|not in|is null|is not null|begins with|ends with)\s*(.*)$/i.exec(String(f));
            if (!m) return null;
            const value = m[3] === "" ? null : Number.isNaN(Number(m[3])) ? m[3] : Number(m[3]);
            return [resolveColumn(m[1], keys) ?? m[1], m[2].toLowerCase(), value];
        }).filter(Boolean);
    }
    return props.config && typeof props.config === "object" ? { ...config, ...props.config } : config;
}

const DATE = /^\d{4}-\d{2}-\d{2}$/;
const DATETIME = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:\d{2})?$/;

/*
 * Rows for Perspective: keys back to the names PowerShell had (PSU camelCases them in transit), and
 * ISO date strings as dates, so the grid sorts, filters and groups them as dates. Returns the rows and
 * the schema of the date columns.
 */
export function prepareRows(rows, columnNames) {
    const keys = columnsOf(rows);
    const original = new Map();
    for (const name of Array.isArray(columnNames) ? columnNames : []) {
        const key = keys.includes(name) ? name : keys.find((k) => k === camelCase(name)) ?? keys.find((k) => k.toLowerCase() === String(name).toLowerCase());
        if (key !== undefined) original.set(key, String(name));
    }
    // every column's type from its values: Perspective would otherwise guess from the first rows
    const types = {};
    for (const key of keys) {
        const values = rows.map((r) => r[key]).filter((v) => v !== null && v !== undefined && v !== "");
        if (values.length && values.every((v) => typeof v === "string" && DATE.test(v))) types[key] = "date";
        else if (values.length && values.every((v) => typeof v === "string" && DATETIME.test(v))) types[key] = "datetime";
        else if (values.length && values.every((v) => typeof v === "boolean")) types[key] = "boolean";
        else if (values.length && values.every((v) => typeof v === "number")) types[key] = values.every((v) => Number.isInteger(v)) ? "integer" : "float";
        else types[key] = "string";
    }
    const name = (k) => original.get(k) ?? k;
    const schema = {};
    for (const [k, t] of Object.entries(types)) schema[name(k)] = t;
    const out = rows.map((r) => {
        const o = {};
        for (const k of keys) {
            const v = r[k];
            // datetime as epoch milliseconds; date as the calendar day (UTC midnight, no time zone shift)
            o[name(k)] = types[k] === "datetime" && typeof v === "string" ? Date.parse(v) : types[k] === "date" && typeof v === "string" ? Date.parse(`${v}T00:00:00Z`) : types[k] === "string" && v !== null && v !== undefined && typeof v !== "string" ? String(v) : v;
        }
        return o;
    });
    return { rows: out, schema, columns: keys.map(name) };
}
