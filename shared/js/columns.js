/*
 * PSU serializes component props with camelCased keys (measured on 2026.3.4: a column "Team" arrives
 * as "team", "ID" as "id"). Column names that users pass as parameters (-X Team) are therefore
 * matched against the data case-insensitively, and against their camelCase form.
 */

export function camelCase(name) {
    const s = String(name);
    // Newtonsoft's camel casing: lower the leading run of capitals, keep the last one when a
    // lower-case letter follows ("XAxis" -> "xAxis", "ID" -> "id", "URLValue" -> "urlValue")
    const m = s.match(/^[A-Z]+/);
    if (!m) {
        return s;
    }
    const run = m[0];
    if (run.length === s.length || run.length === 1) {
        return s.toLowerCase().slice(0, run.length) + s.slice(run.length);
    }
    return run.slice(0, -1).toLowerCase() + s.slice(run.length - 1);
}

// All keys that appear in the rows, in first-seen order.
export function columnsOf(rows) {
    const seen = new Set();
    for (const row of rows || []) {
        if (row && typeof row === "object" && !Array.isArray(row)) {
            Object.keys(row).forEach((k) => seen.add(k));
        }
    }
    return [...seen];
}

/*
 * Resolve a requested column name against the keys of the data. Returns the actual key, or
 * undefined. Exact match first, then camelCase, then case-insensitive.
 */
export function resolveColumn(requested, keys) {
    if (requested === undefined || requested === null || requested === "") {
        return undefined;
    }
    const name = String(requested);
    if (keys.includes(name)) {
        return name;
    }
    const camel = camelCase(name);
    if (keys.includes(camel)) {
        return camel;
    }
    const lower = name.toLowerCase();
    return keys.find((k) => k.toLowerCase() === lower);
}

export function resolveColumns(requested, keys) {
    const list = Array.isArray(requested) ? requested : requested === undefined || requested === null ? [] : [requested];
    return list.map((r) => resolveColumn(r, keys)).filter((k) => k !== undefined);
}

// The value of a column, by whatever name the user gave.
export function getter(requested, keys) {
    const key = resolveColumn(requested, keys);
    return key === undefined ? () => undefined : (row) => (row ? row[key] : undefined);
}

// The columns of a row an event sends back to the server (-EventColumns); without a list, the whole row.
// Names match like everywhere else (case-insensitive); unknown names are left out.
export function pickColumns(row, columns) {
    if (!row || typeof row !== "object" || !Array.isArray(columns) || columns.length === 0) {
        return row;
    }
    const keys = Object.keys(row);
    const out = {};
    for (const c of columns) {
        const key = resolveColumn(c, keys);
        if (key !== undefined) {
            out[key] = row[key];
        }
    }
    return out;
}

/*
 * The original spelling of every key of the rows. PSU camelCases the keys of the rows on their way to
 * the browser; a component that shows column names sends the original names along as values (which PSU
 * leaves alone) and maps them back here: key -> original name. Keys without an original stay as they are.
 */
export function originalNames(keys, columnNames) {
    const original = new Map();
    for (const name of Array.isArray(columnNames) ? columnNames : []) {
        const text = String(name);
        const key = keys.includes(text) ? text : keys.find((k) => k === camelCase(text)) ?? keys.find((k) => k.toLowerCase() === text.toLowerCase());
        if (key !== undefined && !original.has(key)) {
            original.set(key, text);
        }
    }
    return original;
}
