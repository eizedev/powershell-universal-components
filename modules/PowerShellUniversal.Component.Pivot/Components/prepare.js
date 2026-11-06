/*
 * Pure helpers of the pivot report component (no React, no browser APIs), so node --test covers them.
 */
import { columnsOf, originalNames } from "../../../shared/js/columns.js";

// a view or template from the server larger than this is ignored (pivotkit-core limits the view's
// content again; this only keeps a huge string from being parsed at all)
export const MAX_VIEW_LENGTH = 256 * 1024;
// rows of a clicked cell that travel to the server with -OnCellClick (the panel shows up to 1000)
export const EVENT_ROWS = 100;
// how long a template is saved or deleted on the server before the report gives up
export const ENDPOINT_TIMEOUT_MS = 30000;
// changes of the view within this time are sent to -OnViewChange once
export const VIEW_EVENT_DELAY_MS = 600;
// the height when -Height is not set: the window's height minus PSU's app bar and the page padding,
// at least enough for the field list and a few rows of the table
export const DEFAULT_HEIGHT = "clamp(480px, calc(100svh - 200px), 1400px)";

// ISO 8601 as ConvertTo-PSUComponentData writes it ("2026-08-16T17:31:00.0000000", with an offset for
// dates of kind Local or Utc): date, time, fraction of a second, offset
const PSU_DATE = /^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}:\d{2})(\.\d+)?(Z|[+-]\d{2}:\d{2})?$/;

/*
 * A date from PowerShell as pivotkit reads it and a reader can read it. WORKAROUND (pivotkit-react
 * 0.1.0): the drill-down panel shows the source rows' values as they are, so .NET's round-trip format
 * would show as "2026-08-16T17:31:00.0000000". A fraction of zero goes, the T becomes a space, and a
 * midnight without an offset becomes the day alone ("2026-08-16"); pivotkit-core reads all of these as
 * the same date. Other values stay as they are.
 */
export function readableDate(value) {
    if (typeof value !== "string" || value.length < 19 || value.length > 40) {
        return value;
    }
    const m = PSU_DATE.exec(value);
    if (!m) {
        return value;
    }
    const [, day, time, fraction, offset] = m;
    const keepFraction = fraction && /[1-9]/.test(fraction) ? fraction : "";
    if (!offset && !keepFraction && time === "00:00:00") {
        return day;
    }
    return `${day} ${time}${keepFraction}${offset ?? ""}`;
}

/*
 * Rows with the column names PowerShell had: PSU camelCases the keys of the rows on their way to the
 * browser, New-UDPivotReport sends the original names along (columnNames). Dates become readableDate().
 */
export function restoreRows(rows, columnNames) {
    const list = Array.isArray(rows) ? rows.filter((r) => r && typeof r === "object" && !Array.isArray(r)) : [];
    const keys = columnsOf(list);
    const original = originalNames(keys, columnNames);
    const names = keys.map((k) => [k, original.get(k) ?? k]);
    return list.map((r) => {
        const o = {};
        for (const [k, name] of names) {
            o[name] = readableDate(r[k]);
        }
        return o;
    });
}

/*
 * A view from the server: an object (a hashtable in PowerShell) or a JSON string. Anything else, an
 * unparsable or an oversized string, gives undefined; pivotkit-core normalizes what is left and drops
 * what it does not know. A view is data: nothing in it runs as code.
 */
export function parseView(input) {
    if (input === null || input === undefined || input === "") {
        return undefined;
    }
    if (typeof input === "string") {
        if (input.length > MAX_VIEW_LENGTH) {
            return undefined;
        }
        try {
            return parseView(JSON.parse(input));
        } catch {
            return undefined;
        }
    }
    return typeof input === "object" && !Array.isArray(input) ? input : undefined;
}

/*
 * The templates of -Templates: { name, view, deletable }, keys in any case (PSU camelCases them), the
 * view an object or JSON. Entries without a name or a usable view are left out; the first of two
 * entries with the same name wins.
 */
export function readTemplates(list) {
    const out = [];
    const seen = new Set();
    for (const entry of Array.isArray(list) ? list : list ? [list] : []) {
        if (!entry || typeof entry !== "object") {
            continue;
        }
        const get = (key) => entry[Object.keys(entry).find((k) => k.toLowerCase() === key)];
        const name = get("name");
        const view = parseView(get("view"));
        if (typeof name !== "string" || !name.trim() || !view || seen.has(name)) {
            continue;
        }
        seen.add(name);
        out.push({ name, view, deletable: get("deletable") === true });
    }
    return out;
}

/*
 * The templates the report shows: the server's, then the ones the user saved since the page loaded
 * (until the server sends them itself), without the deleted ones. A saved template replaces a
 * deletable one of the same name, never a built-in one.
 */
export function mergeTemplates(server, saved, deleted) {
    const out = server.filter((t) => !deleted.has(t.name));
    for (const t of saved) {
        if (deleted.has(t.name)) {
            continue;
        }
        const i = out.findIndex((o) => o.name === t.name);
        if (i < 0) {
            out.push(t);
        } else if (out[i].deletable) {
            out[i] = t;
        }
    }
    return out;
}

/*
 * What -OnCellClick sends to the server as $EventData: the key paths of the cell with the fields they
 * belong to (filter: one { field, value } per level, rows first), the value as computed and as shown,
 * the number of source rows and the first EVENT_ROWS of them.
 */
export function cellEvent(cell, view, limit = EVENT_ROWS) {
    const rowFields = view && Array.isArray(view.rows) ? view.rows : [];
    const colFields = view && Array.isArray(view.cols) ? view.cols : [];
    const row = Array.isArray(cell.row) ? cell.row : [];
    const col = Array.isArray(cell.col) ? cell.col : [];
    const filter = [...row.map((value, i) => ({ field: rowFields[i] ?? null, value })), ...col.map((value, i) => ({ field: colFields[i] ?? null, value }))];
    const valueSpec = view && Array.isArray(view.values) && cell.valueIndex !== undefined ? view.values[cell.valueIndex] : undefined;
    return {
        row,
        col,
        rowFields: rowFields.slice(0, row.length),
        colFields: colFields.slice(0, col.length),
        filter,
        valueField: valueSpec ? (valueSpec.label ?? valueSpec.field ?? null) : null,
        value: cell.value === undefined ? null : cell.value,
        text: cell.text ?? null,
        count: cell.count ?? 0,
        rows: Array.isArray(cell.rows) ? cell.rows.slice(0, limit) : []
    };
}

// what the reader sees when the server failed without saying why
export const SERVER_ERROR = "the server reported an error";

/*
 * The answer of a PSU endpoint (-OnSaveTemplate, -OnDeleteTemplate) as an error message, or null when
 * it succeeded. PSU answers with the script block's output as JSON text; a script block that throws
 * answers with an error object, and one that returns @{ error = '...' } (or a hashtable with
 * success = $false and a message) refuses on purpose with that message.
 */
export function endpointError(response) {
    let value = response;
    if (typeof value === "string") {
        const text = value.trim();
        if (!text) {
            return null;
        }
        try {
            value = JSON.parse(text);
        } catch {
            return null;
        }
    }
    if (Array.isArray(value)) {
        value = value.length === 1 ? value[0] : null;
    }
    if (!value || typeof value !== "object") {
        return null;
    }
    const get = (key) => value[Object.keys(value).find((k) => k.toLowerCase() === key)];
    // a script block that threw: PSU answers [{ "type": "error", "errorRecords": [{ "location": "" }] }]
    // without the message (measured on PSU 2026.3.4); the message is in the PSU log
    if (get("type") === "error" || Array.isArray(get("errorrecords"))) {
        const record = Array.isArray(get("errorrecords")) ? get("errorrecords")[0] : null;
        const message = record && typeof record === "object" ? record.message ?? record.Message : null;
        return typeof message === "string" && message ? message : SERVER_ERROR;
    }
    const error = get("error");
    if (error) {
        if (typeof error === "string") {
            return error;
        }
        const message = typeof error === "object" ? error.message ?? error.Message : null;
        return typeof message === "string" && message ? message : "the server refused";
    }
    if (get("success") === false) {
        const message = get("message");
        return typeof message === "string" && message ? message : "the server refused";
    }
    return null;
}

/*
 * Calls a PSU endpoint and resolves when the server answered: rejects with the server's message when
 * endpointError finds one, or when no answer came within the timeout (PSU's promise resolves only on
 * an answer).
 */
export function callEndpoint(endpoint, payload, timeoutMs = ENDPOINT_TIMEOUT_MS) {
    return new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error("no answer from the server")), timeoutMs);
        Promise.resolve()
            .then(() => endpoint(payload))
            .then(
                (response) => {
                    clearTimeout(timer);
                    const error = endpointError(response);
                    if (error) {
                        reject(new Error(error));
                    } else {
                        resolve(response);
                    }
                },
                (e) => {
                    clearTimeout(timer);
                    reject(e instanceof Error ? e : new Error(String(e)));
                }
            );
    });
}

// on a phone the zones stack above the table: the report takes almost the whole window there (the
// page scrolls to it, the table scrolls inside it), as pivotkit-react's README advises
export const NARROW_HEIGHT = "calc(100svh - 24px)";
export const NARROW_QUERY = "(max-width: 639px)";

/* The report's height: -Height as given (a number is pixels), or the default for the window's width. */
export function heightOf(height, narrow = false) {
    if (typeof height === "number" && Number.isFinite(height) && height > 0) {
        return height;
    }
    if (typeof height === "string" && height.trim()) {
        return height.trim();
    }
    return narrow ? NARROW_HEIGHT : DEFAULT_HEIGHT;
}

/* "auto", "light" or "dark" (PSU sends the parameter as given). */
export function themeOf(theme) {
    const t = String(theme ?? "auto").toLowerCase();
    return t === "light" || t === "dark" ? t : "auto";
}
