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

/*
 * Rows with the column names PowerShell had: PSU camelCases the keys of the rows on their way to the
 * browser, New-UDPivotReport sends the original names along (columnNames). Values stay as they are:
 * pivotkit-core reads .NET's round-trip dates ("2026-08-16T17:31:00.0000000") as dates.
 */
export function restoreRows(rows, columnNames) {
    const list = Array.isArray(rows) ? rows.filter((r) => r && typeof r === "object" && !Array.isArray(r)) : [];
    const keys = columnsOf(list);
    const original = originalNames(keys, columnNames);
    const names = keys.map((k) => [k, original.get(k) ?? k]);
    return list.map((r) => {
        const o = {};
        for (const [k, name] of names) {
            o[name] = r[k];
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
 * The reader's view in the browser tab (sessionStorage), so it survives PSU mounting the component
 * anew: PSU does that on its light/dark switch, and the component then gets the -View it was created
 * with. One entry per page path and component id, with a hash of the -View the component was mounted
 * with: a different -View from the server (a new render of the page) wins over the stored one. At most
 * VIEW_STORE_ENTRIES entries and MAX_VIEW_LENGTH characters in all, the oldest go first. Storage that
 * is blocked or full is ignored; the report then starts from -View as before.
 */
export const VIEW_STORE = "psu-pivot-views";
export const VIEW_STORE_ENTRIES = 20;

export function viewStoreKey(path, id) {
    return `${path || "/"}#${id || ""}`;
}

export function hashText(text) {
    let h = 5381;
    const s = String(text);
    for (let i = 0; i < s.length; i++) h = ((h * 33) ^ s.charCodeAt(i)) >>> 0;
    return h.toString(36);
}

// the stored entries as a Map (no object keys from storage end up on a prototype)
function readStore(storage) {
    try {
        const parsed = JSON.parse(storage.getItem(VIEW_STORE) || "{}");
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return new Map();
        return new Map(Object.entries(parsed).filter(([, e]) => e && typeof e === "object" && typeof e.s === "string"));
    } catch {
        return new Map();
    }
}

// the stored view of this component, or undefined; an entry of another -View is removed
export function readStoredView(storage, key, serverKey) {
    if (!storage) return undefined;
    const entries = readStore(storage);
    const entry = entries.get(key);
    if (!entry) return undefined;
    if (entry.s !== hashText(serverKey)) {
        writeStoredView(storage, key, serverKey, undefined);
        return undefined;
    }
    return parseView(entry.v);
}

// stores the view (undefined removes it); returns false when the storage refused it
export function writeStoredView(storage, key, serverKey, view, now = Date.now()) {
    if (!storage) return false;
    try {
        const entries = readStore(storage);
        entries.delete(key);
        const list = [...entries].sort((a, b) => (b[1].t || 0) - (a[1].t || 0));
        if (view !== undefined) list.unshift([key, { s: hashText(serverKey), v: view, t: now }]);
        let kept = list.slice(0, VIEW_STORE_ENTRIES);
        let text = JSON.stringify(Object.fromEntries(kept));
        while (text.length > MAX_VIEW_LENGTH && kept.length) {
            kept = kept.slice(0, -1);
            text = JSON.stringify(Object.fromEntries(kept));
        }
        storage.setItem(VIEW_STORE, text);
        return kept.some(([k]) => k === key) || view === undefined;
    } catch {
        return false;
    }
}

/*
 * The reader's view in the address bar: one entry per report in the URL fragment,
 * #pivot-<storageKey>=<view>, several joined with "&"; other parts of the fragment stay as they are.
 * The fragment belongs to the tab (a reload and PSU's light/dark switch keep it, measured on PSU
 * 2026.3.4) and travels with a copied link, so the address bar shares the report. The view is compact
 * JSON as base64url (UTF-8); a view longer than MAX_LINK_VIEW_LENGTH stays out of the address bar
 * (the tab's sessionStorage still keeps it). What comes from a link is untrusted: it goes through
 * parseView like every view, and the report checks it against the data.
 */
export const LINK_PREFIX = "pivot-";
export const MAX_LINK_VIEW_LENGTH = 8000;

function toBase64Url(text) {
    const bytes = new TextEncoder().encode(text);
    let binary = "";
    for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromBase64Url(text) {
    if (!/^[A-Za-z0-9_-]*$/.test(text)) return undefined;
    try {
        const binary = atob(text.replace(/-/g, "+").replace(/_/g, "/"));
        return new TextDecoder("utf-8", { fatal: true }).decode(Uint8Array.from(binary, (c) => c.charCodeAt(0)));
    } catch {
        return undefined;
    }
}

// the view as it goes into the fragment, or undefined when it is too long for an address bar
export function encodeLinkView(view) {
    const text = toBase64Url(JSON.stringify(view));
    return text.length <= MAX_LINK_VIEW_LENGTH ? text : undefined;
}

export function decodeLinkView(text) {
    if (typeof text !== "string" || !text || text.length > MAX_LINK_VIEW_LENGTH) return undefined;
    const json = fromBase64Url(text);
    return json === undefined ? undefined : parseView(json);
}

function linkName(key) {
    return LINK_PREFIX + encodeURIComponent(key || "");
}

// the view of report `key` in a fragment ("#a&pivot-x=..."), or undefined
export function readLinkView(hash, key) {
    const name = linkName(key) + "=";
    const part = String(hash || "").replace(/^#/, "").split("&").find((p) => p.startsWith(name));
    return part === undefined ? undefined : decodeLinkView(part.slice(name.length));
}

// the fragment with the view of report `key` set (undefined removes it), other parts kept in place
export function writeLinkView(hash, key, view) {
    const name = linkName(key) + "=";
    const parts = String(hash || "").replace(/^#/, "").split("&").filter((p) => p !== "");
    const text = view === undefined ? undefined : encodeLinkView(view);
    const at = parts.findIndex((p) => p.startsWith(name));
    if (text === undefined) {
        if (at >= 0) parts.splice(at, 1);
    } else if (at >= 0) {
        parts[at] = name + text;
    } else {
        parts.push(name + text);
    }
    return parts.length ? "#" + parts.join("&") : "";
}

/*
 * The view a report starts with in this tab, or undefined for -View, in this order: the view in the
 * address bar (from: "link" - this tab's own, or a link someone shared), the tab's sessionStorage
 * (kept under the -View it was mounted with, from: "tab"), the reader's view the server sent as
 * -SavedView (from: "saved"). A -SavedView is only a starting point for a tab without a view of its
 * own: PSU's $Session belongs to the browser, not the tab, so a view stored there may come from
 * another tab and must never replace the view this tab shows. An empty view counts as none.
 */
export function startViewOf(storage, key, serverKey, savedView, linkView) {
    const usable = (v) => Boolean(v && typeof v === "object" && Object.keys(v).length > 0);
    const stored = readStoredView(storage, key, serverKey);
    // inStorage: sessionStorage holds this view already (nothing to write)
    if (usable(linkView)) return { view: linkView, from: "link", inStorage: usable(stored) && JSON.stringify(stored) === JSON.stringify(linkView) };
    if (usable(stored)) return { view: stored, from: "tab", inStorage: true };
    const saved = parseView(savedView);
    return usable(saved) ? { view: saved, from: "saved", inStorage: false } : undefined;
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

/*
 * Props New-UDPivotReport sends as JSON text: -FieldDefaults (with -FieldDescriptions), -Schema and
 * -ChartOptions. PSU camelCases the keys of objects in props on their way to the browser, which would
 * turn the field names in them ("LeadHours") and a schema's names ("Release") into other names; it
 * leaves strings alone. The server has checked them; this only refuses what is not a JSON object or
 * longer than `max` characters.
 */
export const MAX_SCHEMA_LENGTH = 1024 * 1024;
export const MAX_OPTIONS_LENGTH = 64 * 1024;

export function parseJsonObject(text, max) {
    if (typeof text !== "string" || !text || text.length > max) {
        return undefined;
    }
    try {
        const value = JSON.parse(text);
        return value && typeof value === "object" && !Array.isArray(value) ? value : undefined;
    } catch {
        return undefined;
    }
}

/*
 * The fieldDefaults the report gets: what the schema says about each field (pivotkit-core's
 * fieldDefaultsFromSchema), with the server's -FieldDefaults and -FieldDescriptions over it, key by key.
 * Field names match without regard to case; an entry takes the spelling of the data's column when there
 * is one (columnNames), else the server's, else the schema's. Undefined when there is nothing.
 */
export function mergeFieldDefaults(schemaDefaults, serverDefaults, columnNames) {
    const isEntry = (e) => e && typeof e === "object" && !Array.isArray(e);
    const spelling = new Map((Array.isArray(columnNames) ? columnNames : []).map((n) => [String(n).toLowerCase(), String(n)]));
    const out = new Map();
    for (const source of [schemaDefaults, serverDefaults]) {
        if (!isEntry(source)) continue;
        for (const [name, entry] of Object.entries(source)) {
            if (!isEntry(entry)) continue;
            const key = name.toLowerCase();
            const before = out.get(key);
            // the server's entry comes second: its spelling wins over the schema's
            out.set(key, { name: spelling.get(key) ?? name, entry: { ...(before?.entry ?? {}), ...entry } });
        }
    }
    if (!out.size) return undefined;
    const result = {};
    // defineProperty: a field named "__proto__" stays a field
    for (const { name, entry } of out.values()) Object.defineProperty(result, name, { value: entry, enumerable: true });
    return result;
}

/* -Tips as pivotkit takes it: "on", "off", or the tip ids allowed. Anything else is "on". */
export function tipsOf(tips) {
    const list = (Array.isArray(tips) ? tips : typeof tips === "string" ? tips.split(",") : []).map((t) => String(t).trim()).filter(Boolean);
    if (!list.length) return "on";
    if (list.length === 1 && /^(on|off)$/i.test(list[0])) return list[0].toLowerCase();
    return list;
}

/* "on" or "off" for -FieldInfo and -ZoneInfo, else undefined (the reader decides in Options). */
export function switchOf(value) {
    const v = String(value ?? "").toLowerCase();
    return v === "on" || v === "off" ? v : undefined;
}
