// Tests for the pivot module's pure helpers and its PSU theme bridge. Run: node --test "tests/js/*.test.js"
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { contrastRatio, parseColor } from "../../shared/js/contrast.js";

const mod = await import("../../modules/PowerShellUniversal.Component.Pivot/Components/prepare.js");

test("restoreRows: PowerShell's column names back, values as they are", () => {
    // as PSU sends them: keys camelCased, the original names in columnNames
    const rows = [
        { ticket: 1, "lead hours": 2.5, created: "2026-08-16T17:31:00.0000000", agent: null },
        { ticket: 2, "lead hours": null, created: "2026-08-17T09:00:00.0000000+02:00", agent: "Kim" }
    ];
    const out = mod.restoreRows(rows, ["Ticket", "Lead hours", "Created", "Agent"]);
    assert.deepEqual(Object.keys(out[0]), ["Ticket", "Lead hours", "Created", "Agent"]);
    // pivotkit-core reads .NET's round-trip format as a date; the drill-down formats it
    assert.equal(out[0].Created, "2026-08-16T17:31:00.0000000");
    assert.equal(out[1].Created, "2026-08-17T09:00:00.0000000+02:00");
    assert.equal(out[0].Agent, null);
    assert.equal(out[1]["Lead hours"], null);
    assert.deepEqual(mod.restoreRows(null, []), []);
    assert.deepEqual(mod.restoreRows([1, "x", null, { a: 1 }], ["A"]), [{ A: 1 }]);
});

test("parseView: objects and JSON, nothing else; never evaluated", () => {
    assert.deepEqual(mod.parseView({ rows: ["Team"] }), { rows: ["Team"] });
    assert.deepEqual(mod.parseView('{"rows":["Team"]}'), { rows: ["Team"] });
    for (const bad of [null, undefined, "", "[1]", "not json", 3, ["rows"], "x".repeat(mod.MAX_VIEW_LENGTH + 1)]) {
        assert.equal(mod.parseView(bad), undefined, String(bad).slice(0, 20));
    }
});

test("readTemplates: keys in any case, views as objects or JSON, scopes, bad entries and duplicates left out", () => {
    const t = mod.readTemplates([
        { name: "A", view: { rows: ["Team"] } },
        { Name: "B", View: '{"cols":["Priority"]}', Deletable: true },
        { name: "A", view: { rows: ["Other"] } },
        // the same name in the other scope is another template
        { name: "A", view: { rows: ["Mine"] }, scope: "user", deletable: true },
        { name: "S", view: { rows: ["Team"] }, Scope: "SHARED", deletable: true },
        { name: "X", view: { rows: ["Team"] }, scope: "everyone" },
        { name: "", view: {} },
        { name: "C", view: "nope" },
        null
    ]);
    assert.deepEqual(t, [
        { name: "A", view: { rows: ["Team"] }, scope: "shared", deletable: false },
        // without a scope a deletable entry is the reader's own (pivotkit's rule)
        { name: "B", view: { cols: ["Priority"] }, scope: "user", deletable: true },
        { name: "A", view: { rows: ["Mine"] }, scope: "user", deletable: true },
        { name: "S", view: { rows: ["Team"] }, scope: "shared", deletable: true },
        { name: "X", view: { rows: ["Team"] }, scope: "shared", deletable: false }
    ]);
    assert.deepEqual(mod.readTemplates(undefined), []);
});

test("mergeTemplates: saved views appended or replacing deletable ones of their scope, published ones replacing shared ones; deleted ones gone by scope", () => {
    const server = [
        { name: "Built-in", view: {}, scope: "shared", deletable: false },
        { name: "Mine", view: { rows: ["A"] }, scope: "user", deletable: true }
    ];
    const saved = [
        { name: "Mine", view: { rows: ["B"] }, scope: "user", deletable: true },
        // a reader's own view of a shared view's name is a view of its own
        { name: "Built-in", view: { rows: ["U"] }, scope: "user", deletable: true },
        { name: "New", view: {}, scope: "user", deletable: true }
    ];
    const merged = mod.mergeTemplates(server, saved, new Set());
    assert.deepEqual(merged.map((t) => `${t.scope}:${t.name}`), ["shared:Built-in", "user:Mine", "user:Built-in", "user:New"]);
    assert.deepEqual(merged[1].view, { rows: ["B"] });
    assert.deepEqual(merged[0].view, {});
    // an admin published "Built-in": it replaces the shared one
    const published = mod.mergeTemplates(server, [{ name: "Built-in", view: { rows: ["P"] }, scope: "shared", deletable: true }], new Set());
    assert.deepEqual(published[0].view, { rows: ["P"] });
    const deleted = new Set([mod.templateKey("user", "Mine"), mod.templateKey("user", "New")]);
    assert.deepEqual(mod.mergeTemplates(server, saved, deleted).map((t) => `${t.scope}:${t.name}`), ["shared:Built-in", "user:Built-in"]);
    // deleting the shared one leaves the reader's view of that name
    assert.deepEqual(mod.mergeTemplates(server, saved, new Set([mod.templateKey("shared", "Built-in")])).map((t) => `${t.scope}:${t.name}`), ["user:Mine", "user:Built-in", "user:New"]);
});

test("sourceOf, schemaUrlOf, fieldListOf: the props of -SourceId, -SourceName, -SchemaUrl and -FieldList", () => {
    assert.deepEqual(mod.sourceOf({ id: " tickets ", name: "Tickets" }), { id: "tickets", name: "Tickets" });
    assert.deepEqual(mod.sourceOf({ id: "tickets", name: "" }), { id: "tickets" });
    assert.equal(mod.sourceOf({ name: "No id" }), undefined);
    assert.equal(mod.sourceOf("tickets"), undefined);
    assert.equal(mod.sourceOf({ id: "x".repeat(300) }).id.length, 256);
    assert.equal(mod.schemaUrlOf(undefined), undefined);
    assert.equal(mod.schemaUrlOf(""), null);
    assert.equal(mod.schemaUrlOf("https://example.org/view-file-1.json"), "https://example.org/view-file-1.json");
    assert.equal(mod.fieldListOf("Collapsed"), "collapsed");
    assert.equal(mod.fieldListOf("open"), "open");
    assert.equal(mod.fieldListOf("hidden"), undefined);
    assert.equal(mod.switchOf("Off"), "off");
});

test("importLimitsOf: -ImportLimit as pivotkit's importLimits, only known keys with whole numbers", () => {
    // as PSU sends -ImportLimit @{ fileBytes = 250MB; rows = 2000000 }
    assert.deepEqual(mod.importLimitsOf({ fileBytes: 262144000, rows: 2000000 }), { fileBytes: 262144000, rows: 2000000 });
    assert.deepEqual(mod.importLimitsOf({ columns: 50, importCells: Number.MAX_SAFE_INTEGER }), { columns: 50, importCells: Number.MAX_SAFE_INTEGER });
    assert.deepEqual(mod.importLimitsOf({ textLength: 100, archiveEntries: 50, unpackedBytes: 1073741824 }), { textLength: 100, archiveEntries: 50, unpackedBytes: 1073741824 });
    // pivotkit throws on an unknown limit or a value that is no whole number of at least 1: left out
    assert.deepEqual(mod.importLimitsOf({ rows: 10, groups: 5, toString: 1, fileBytes: 2.5, columns: 0, importCells: "100" }), { rows: 10 });
    assert.deepEqual(mod.importLimitsOf({ rows: Number.MAX_SAFE_INTEGER + 1, columns: -1, fileBytes: Infinity, importCells: NaN }), undefined);
    for (const bad of [undefined, null, "rows", 5, [1, 2], {}]) assert.equal(mod.importLimitsOf(bad), undefined, String(bad));
    // an inherited key is no limit of the host's
    assert.equal(mod.importLimitsOf(Object.create({ rows: 5 })), undefined);
});

test("importLimitsOf: the same keys as -ImportLimit in the module", () => {
    const psm1 = readFileSync(new URL("../../modules/PowerShellUniversal.Component.Pivot/PowerShellUniversal.Component.Pivot.psm1", import.meta.url), "utf8");
    const block = psm1.match(/\$Script:ImportLimitDefaults = \[ordered\]@\{([^}]*)\}/);
    assert.ok(block, "$Script:ImportLimitDefaults in the module");
    const keys = [...block[1].matchAll(/^\s*(\w+)\s*=/gm)].map((m) => m[1]);
    assert.deepEqual(keys, [...mod.IMPORT_LIMIT_KEYS]);
});

test("columnSummary and lastTimings: the admin panel's columns and timings", () => {
    const encoded = {
        columns: [
            { name: "Team", type: "string", dict: ["A", "B"], codes: Int32Array.from([0, 1, -1]) },
            { name: "Created (Month)", type: "string", dict: [], codes: Int32Array.from([]), derived: true },
            { name: "Hours", type: "number", dict: [1, 2, 3], codes: Int32Array.from([0, 1, 2]) }
        ]
    };
    assert.deepEqual(mod.columnSummary(encoded), [
        { name: "Team", type: "string", distinct: 2, blanks: 1 },
        { name: "Hours", type: "number", distinct: 3, blanks: 0 }
    ]);
    assert.deepEqual(mod.columnSummary(null), []);
    const entries = { "pivotkit:encode": [{ duration: 9.04 }, { duration: 4.26 }], "pivotkit:toGrid": [{ duration: 1 }] };
    assert.deepEqual(mod.lastTimings((n) => entries[n]), { encode: 4.3, toGrid: 1 });
});

test("cellEvent: the fields of each level, the value field and at most EVENT_ROWS rows", () => {
    const view = { rows: ["Team", "Customer"], cols: ["Priority"], values: [{ field: "Cost", agg: "sum", label: null }] };
    const rows = Array.from({ length: 250 }, (_, i) => ({ id: i }));
    const e = mod.cellEvent({ row: ["Network"], col: ["P2"], value: 12, valueIndex: 0, text: "12", count: 250, rows }, view);
    assert.deepEqual(e.filter, [{ field: "Team", value: "Network" }, { field: "Priority", value: "P2" }]);
    assert.deepEqual(e.rowFields, ["Team"]);
    assert.deepEqual(e.colFields, ["Priority"]);
    assert.equal(e.valueField, "Cost");
    assert.equal(e.rows.length, mod.EVENT_ROWS);
    // the grand total: empty paths, no fields
    const total = mod.cellEvent({ row: [], col: [], value: 1, count: 1, rows: [] }, view);
    assert.deepEqual(total.filter, []);
    assert.equal(total.valueField, null);
    assert.doesNotThrow(() => JSON.stringify(mod.cellEvent({}, undefined)));
});

test("endpointError: PSU's error answer, a deliberate refusal, and success", () => {
    // measured on PSU 2026.3.4: a script block that throws
    assert.equal(mod.endpointError('[{"errorRecords":[{"location":""}],"type":"error","refreshInterval":0}]'), mod.SERVER_ERROR);
    assert.equal(mod.endpointError('{"error":"Name taken"}'), "Name taken");
    assert.equal(mod.endpointError('[{"Error":"Name taken"}]'), "Name taken");
    assert.equal(mod.endpointError({ success: false, message: "No" }), "No");
    for (const ok of ["", "[]", "null", '{"name":"x"}', "plain text", undefined, '[{"a":1},{"b":2}]']) {
        assert.equal(mod.endpointError(ok), null, String(ok));
    }
});

test("callEndpoint: resolves on success, rejects with the server's message or on timeout", async () => {
    assert.equal(await mod.callEndpoint(async () => "[]", {}), "[]");
    await assert.rejects(mod.callEndpoint(async () => '{"error":"too big"}', {}), /too big/);
    await assert.rejects(mod.callEndpoint(() => { throw new Error("offline"); }, {}), /offline/);
    await assert.rejects(mod.callEndpoint(() => new Promise(() => {}), {}, 20), /no answer/);
});

test("parseJsonObject: JSON objects of at most max characters, nothing else", () => {
    assert.deepEqual(mod.parseJsonObject('{"LeadHours":{"label":"Lead time"}}', 100), { LeadHours: { label: "Lead time" } });
    for (const v of ["[1]", "1", '"x"', "{", "", null, undefined, { a: 1 }, '{"a":1}'.padEnd(200)]) {
        assert.equal(mod.parseJsonObject(v, 100), undefined, String(v));
    }
});

test("mergeFieldDefaults: the server over the schema key by key, names without regard to case, the data's spelling", () => {
    const schema = { leadHours: { label: "Lead (schema)", description: "From the schema", type: "number" }, Region: { order: ["North", "South"] } };
    const server = { LEADHOURS: { label: "Lead time", agg: "average" }, Team: { description: "Who" } };
    const out = mod.mergeFieldDefaults(schema, server, ["LeadHours", "Team"]);
    assert.deepEqual(out, {
        LeadHours: { label: "Lead time", description: "From the schema", type: "number", agg: "average" },
        Region: { order: ["North", "South"] },
        Team: { description: "Who" }
    });
    // without columnNames the server's spelling wins over the schema's
    assert.deepEqual(Object.keys(mod.mergeFieldDefaults(schema, server)), ["LEADHOURS", "Region", "Team"]);
    assert.equal(mod.mergeFieldDefaults(undefined, undefined, []), undefined);
    assert.equal(mod.mergeFieldDefaults({ a: 1, b: null, c: [] }, "x"), undefined);
    // a field named __proto__ stays a field and never reaches the prototype
    const odd = mod.mergeFieldDefaults(JSON.parse('{"__proto__":{"label":"x"}}'), undefined);
    assert.deepEqual(Object.getOwnPropertyDescriptor(odd, "__proto__").value, { label: "x" });
    assert.equal(Object.getPrototypeOf(odd), Object.prototype);
});

test("tipsOf and switchOf", () => {
    assert.equal(mod.tipsOf("off"), "off");
    assert.equal(mod.tipsOf("On"), "on");
    assert.equal(mod.tipsOf(undefined), "on");
    assert.deepEqual(mod.tipsOf(["values", "chartSeries"]), ["values", "chartSeries"]);
    assert.deepEqual(mod.tipsOf("values, cells"), ["values", "cells"]);
    assert.equal(mod.switchOf("Off"), "off");
    assert.equal(mod.switchOf("on"), "on");
    assert.equal(mod.switchOf("maybe"), undefined);
    assert.equal(mod.switchOf(undefined), undefined);
});

/** The pixels of a clamp(min, calc(100svh - offset), max) for a window `svh` pixels high. */
function defaultHeightAt(svh) {
    const m = /^clamp\((\d+)px, calc\(100svh - (\d+)px\), (\d+)px\)$/.exec(mod.DEFAULT_HEIGHT);
    assert.ok(m, `DEFAULT_HEIGHT has the documented form: ${mod.DEFAULT_HEIGHT}`);
    const [min, offset, max] = m.slice(1).map(Number);
    return { px: Math.min(max, Math.max(min, svh - offset)), min, offset, max };
}

test("the default height fills a desktop window below PSU's app bar and a page title", () => {
    // a 1080p screen: the browser shows about 940 pixels of page; a 1440 x 900 window: 900
    assert.equal(defaultHeightAt(940).px, 760);
    assert.equal(defaultHeightAt(900).px, 720);
    // a low window: enough for the open zones (pivotkit folds them below 600) and rows below them
    assert.equal(defaultHeightAt(700).px, 600);
    // a tall screen: the report stops growing
    assert.equal(defaultHeightAt(2160).px, 1400);
    // the help of -Height and the page that describes it give the same numbers
    const { min, offset, max } = defaultHeightAt(0);
    const psm1 = readFileSync(new URL("../../modules/PowerShellUniversal.Component.Pivot/PowerShellUniversal.Component.Pivot.psm1", import.meta.url), "utf8");
    const page = readFileSync(new URL("../../docs/pivot/index.md", import.meta.url), "utf8");
    for (const [name, text] of [["the help of -Height", psm1], ["docs/pivot/index.md", page]]) {
        assert.ok(text.includes(`minus ${offset} pixels`), `${name} names the ${offset} pixels`);
        assert.ok(text.includes(`between ${min} and ${max} pixels`), `${name} names ${min} and ${max}`);
    }
});

test("heightOf and themeOf", () => {
    assert.equal(mod.heightOf(500), 500);
    assert.equal(mod.heightOf(" 70vh "), "70vh");
    assert.equal(mod.heightOf(undefined), mod.DEFAULT_HEIGHT);
    assert.equal(mod.heightOf("", true), mod.NARROW_HEIGHT);
    assert.equal(mod.themeOf("Dark"), "dark");
    assert.equal(mod.themeOf(undefined), "auto");
    assert.equal(mod.themeOf("blue"), "auto");
});

// ---- the reader's view in the tab -----------------------------------------------------------------

function fakeStorage({ full = false } = {}) {
    const data = new Map();
    return {
        data,
        getItem: (k) => (data.has(k) ? data.get(k) : null),
        setItem: (k, v) => {
            if (full) throw new Error("QuotaExceededError");
            data.set(k, String(v));
        }
    };
}

test("stored view: comes back for the same -View, page and id; another -View wins and removes it", () => {
    const storage = fakeStorage();
    const key = mod.viewStoreKey("/pivot-report/tickets", "tickets");
    const server = JSON.stringify({ rows: ["Team"] });
    const reader = { rows: ["Team"], display: "chart", chart: { type: "line" }, collapsed: { rows: [["Ops"]] } };
    assert.equal(mod.readStoredView(storage, key, server), undefined);
    assert.equal(mod.writeStoredView(storage, key, server, reader), true);
    assert.deepEqual(mod.readStoredView(storage, key, server), reader);
    assert.equal(mod.readStoredView(storage, mod.viewStoreKey("/other", "tickets"), server), undefined);
    assert.equal(mod.readStoredView(storage, mod.viewStoreKey("/pivot-report/tickets", "other"), server), undefined);
    // a new -View from the server: the reader's view is dropped
    assert.equal(mod.readStoredView(storage, key, JSON.stringify({ rows: ["Priority"] })), undefined);
    assert.equal(mod.readStoredView(storage, key, server), undefined);
});

test("view in the address bar: one entry per report, other fragment parts kept, untrusted input refused", () => {
    const view = { rows: ["Team"], cols: ["Priority"], display: "chart", filters: [{ field: "Status", type: "include", items: ["Offen ü €"] }] };
    const hash = mod.writeLinkView("#section", "tickets", view);
    assert.match(hash, /^#section&pivot-tickets=[A-Za-z0-9_-]+$/);
    assert.deepEqual(mod.readLinkView(hash, "tickets"), view, "UTF-8 round trip");
    // a second report on the page, then the first one back to -View
    const both = mod.writeLinkView(hash, "auto-0011", { rows: ["Category"] });
    assert.deepEqual(mod.readLinkView(both, "auto-0011"), { rows: ["Category"] });
    assert.deepEqual(mod.readLinkView(both, "tickets"), view);
    const rest = mod.writeLinkView(both, "tickets", undefined);
    assert.equal(mod.readLinkView(rest, "tickets"), undefined);
    assert.ok(rest.startsWith("#section&pivot-auto-0011="));
    assert.equal(mod.writeLinkView(mod.writeLinkView("", "t", view), "t", undefined), "");
    // keys with characters of their own; a prefix of another key is not that key
    assert.deepEqual(mod.readLinkView(mod.writeLinkView("", "a&b=c", view), "a&b=c"), view);
    assert.equal(mod.readLinkView(mod.writeLinkView("", "tickets-2", view), "tickets"), undefined);
    // broken, foreign or oversized input: no view
    for (const bad of ["#pivot-t=", "#pivot-t=%%%", "#pivot-t=bm90IGpzb24", "#pivot-t=WyJhIl0", `#pivot-t=${"A".repeat(mod.MAX_LINK_VIEW_LENGTH + 4)}`, "#pivot-t=/w"]) {
        assert.equal(mod.readLinkView(bad, "t"), undefined, bad);
    }
    // a view too long for an address bar stays out of it
    const big = { rows: ["x".repeat(mod.MAX_LINK_VIEW_LENGTH)] };
    assert.equal(mod.encodeLinkView(big), undefined);
    assert.equal(mod.writeLinkView("#keep", "t", big), "#keep");
});

test("start view of a tab: its own view first, -SavedView only without one, else -View", () => {
    const storage = fakeStorage();
    const key = mod.viewStoreKey("/pivot-report/tickets", "tickets");
    const server = JSON.stringify({ rows: ["Team"] });
    const own = { rows: ["Team"], display: "chart" };
    // what another tab of the same PSU session stored on the server
    const saved = { rows: ["Priority"], cols: ["Team"] };
    assert.equal(mod.startViewOf(storage, key, server, undefined), undefined, "nothing: -View");
    assert.deepEqual(mod.startViewOf(storage, key, server, saved), { view: saved, from: "saved", inStorage: false }, "a new tab starts with -SavedView");
    assert.deepEqual(mod.startViewOf(storage, key, server, JSON.stringify(saved)), { view: saved, from: "saved", inStorage: false }, "-SavedView as JSON");
    mod.writeStoredView(storage, key, server, own);
    assert.deepEqual(mod.startViewOf(storage, key, server, saved), { view: own, from: "tab", inStorage: true }, "the tab's own view wins over -SavedView");
    // empty, broken or oversized -SavedView: -View
    for (const bad of [{}, "", "not json", "x".repeat(mod.MAX_VIEW_LENGTH + 1), ["rows"]]) {
        assert.equal(mod.startViewOf(fakeStorage(), key, server, bad), undefined);
    }
    // a new -View from the app still wins over the tab's view; -SavedView then starts the tab again
    assert.deepEqual(mod.startViewOf(storage, key, JSON.stringify({ rows: ["Status"] }), saved), { view: saved, from: "saved", inStorage: false });
    assert.equal(mod.startViewOf(null, key, server, undefined), undefined, "blocked storage");
    // the address bar (this tab's view, or a shared link) comes before everything else
    assert.deepEqual(mod.startViewOf(storage, key, server, saved, { rows: ["Status"] }), { view: { rows: ["Status"] }, from: "link", inStorage: false });
    mod.writeStoredView(storage, key, server, own);
    assert.deepEqual(mod.startViewOf(storage, key, server, saved, own), { view: own, from: "link", inStorage: true }, "the same view in both places");
    assert.deepEqual(mod.startViewOf(storage, key, server, saved, {}), { view: own, from: "tab", inStorage: true }, "an empty link view counts as none");
});

test("stored view: capped by entries and size, keys from storage never reach a prototype", () => {
    const storage = fakeStorage();
    for (let i = 0; i < mod.VIEW_STORE_ENTRIES + 5; i++) mod.writeStoredView(storage, `/p#${i}`, "null", { rows: [String(i)] }, i);
    const all = JSON.parse(storage.getItem(mod.VIEW_STORE));
    assert.equal(Object.keys(all).length, mod.VIEW_STORE_ENTRIES);
    assert.ok(!("/p#0" in all), "the oldest go first");
    assert.deepEqual(mod.readStoredView(storage, `/p#${mod.VIEW_STORE_ENTRIES + 4}`, "null"), { rows: [String(mod.VIEW_STORE_ENTRIES + 4)] });
    // a view larger than the whole store is not kept
    assert.equal(mod.writeStoredView(storage, "/big#1", "null", { rows: ["x".repeat(mod.MAX_VIEW_LENGTH)] }), false);
    assert.ok(JSON.stringify(JSON.parse(storage.getItem(mod.VIEW_STORE))).length <= mod.MAX_VIEW_LENGTH);
    storage.setItem(mod.VIEW_STORE, '{"__proto__": {"s": "x", "v": {"polluted": true}}}');
    mod.writeStoredView(storage, "/p#1", "null", { rows: [] });
    assert.equal({}.polluted, undefined);
});

test("stored view: blocked, full or broken storage is ignored", () => {
    assert.equal(mod.readStoredView(null, "/p#1", "null"), undefined);
    assert.equal(mod.writeStoredView(null, "/p#1", "null", {}), false);
    assert.equal(mod.writeStoredView(fakeStorage({ full: true }), "/p#1", "null", {}), false);
    const broken = fakeStorage();
    broken.setItem(mod.VIEW_STORE, "not json");
    assert.equal(mod.readStoredView(broken, "/p#1", "null"), undefined);
    assert.equal(mod.writeStoredView(broken, "/p#1", "null", { rows: ["A"] }), true);
    const throwing = { getItem: () => { throw new Error("SecurityError"); }, setItem: () => { throw new Error("SecurityError"); } };
    assert.equal(mod.readStoredView(throwing, "/p#1", "null"), undefined);
    assert.equal(mod.writeStoredView(throwing, "/p#1", "null", {}), false);
});

// ---- the PSU theme bridge ------------------------------------------------------------------------

const css = readFileSync(new URL("../../modules/PowerShellUniversal.Component.Pivot/Components/psu.css", import.meta.url), "utf8");
const themesDoc = readFileSync(new URL("../../docs/pivot/themes.md", import.meta.url), "utf8");
const LIGHT = ".ud-pivot-report .pk-root";
const DARK = '.ud-pivot-report .pk-root[data-pk-theme="dark"]';

// the custom properties of every block with exactly this selector, in source order
function declarations(selector) {
    const out = {};
    const source = css.replace(/\/\*[\s\S]*?\*\//g, "");
    for (let at = source.indexOf(`${selector} {`); at >= 0; at = source.indexOf(`${selector} {`, at + 1)) {
        const block = source.slice(at, source.indexOf("}", at));
        for (const m of block.matchAll(/(--[a-z0-9-]+):\s*([^;]+);/g)) out[m[1]] = m[2].trim();
    }
    assert.ok(Object.keys(out).length, selector);
    return out;
}

// the report's declarations in a mode: the dark block adds to the light one, as in the browser
function element(mode) {
    return mode === "dark" ? { ...declarations(LIGHT), ...declarations(DARK) } : declarations(LIGHT);
}

// var() substitution as CSS does it: a property without a value takes the fallback, a var() without
// either makes the whole value invalid (undefined here); `page` holds the values inherited from :root
function resolve(name, own, page, seen = new Set()) {
    if (seen.has(name)) return undefined;
    if (!(name in own)) return page[name];
    return substitute(own[name], own, page, new Set([...seen, name]));
}

function substitute(value, own, page, seen) {
    let out = "";
    let i = 0;
    while (i < value.length) {
        const at = value.indexOf("var(", i);
        if (at < 0) return out + value.slice(i);
        out += value.slice(i, at);
        let depth = 0;
        let end = at + 3;
        let comma = -1;
        for (; end < value.length; end++) {
            if (value[end] === "(") depth++;
            else if (value[end] === ")" && --depth === 0) break;
            else if (value[end] === "," && depth === 1 && comma < 0) comma = end;
        }
        const ref = value.slice(at + 4, comma < 0 ? end : comma).trim();
        let v = resolve(ref, own, page, seen);
        if (v === undefined && comma >= 0) v = substitute(value.slice(comma + 1, end).trim(), own, page, seen);
        if (v === undefined) return undefined;
        out += v;
        i = end + 1;
    }
    return out;
}

const tokenNames = (own) => Object.keys(own).filter((n) => n.startsWith("--pk-"));
const tokensOf = (mode, page = {}) => {
    const own = element(mode);
    return Object.fromEntries(tokenNames(own).map((n) => [n, resolve(n, own, page)]));
};

// the properties an app may set: every --psu-pivot-* and --psu-chart-* the bridge reads
const publicNames = () => [...new Set([...css.replace(/\/\*[\s\S]*?\*\//g, "").matchAll(/var\((--psu-(?:pivot|chart)-[a-z0-9-]+)/g)].map((m) => m[1]))].sort();

// the table in docs/pivot/themes.md: property, falls back to, what it sets, light, dark
function docRows() {
    return themesDoc.split("\n").filter((l) => l.startsWith("| `--psu-")).map((line) => {
        const cells = line.split("|").slice(1, -1).map((c) => c.trim());
        let names = [...cells[0].matchAll(/`(--psu-[a-z0-9-]+)`/g)].map((m) => m[1]);
        const range = /^`--psu-([a-z]+)-(\d+)` \.\.\. `--psu-\1-(\d+)`$/.exec(cells[0]);
        if (range) names = Array.from({ length: range[3] - range[2] + 1 }, (_, k) => `--psu-${range[1]}-${Number(range[2]) + k}`);
        const literal = (cell) => (/^`([^`]+)`$/.exec(cell) || [])[1];
        return { names, fallbacks: [...cells[1].matchAll(/`(--psu-[a-z0-9-]+)`/g)].map((m) => m[1]), light: literal(cells[3]), dark: literal(cells[4]) };
    });
}

// a colour with alpha over its background, as the browser draws it
function over(color, background) {
    const alpha = /rgba\([^)]*,\s*([\d.]+)\s*\)/.exec(color);
    const fg = parseColor(color);
    const bg = parseColor(background);
    const a = alpha ? Number(alpha[1]) : 1;
    return fg.map((v, i) => Math.round(v * a + bg[i] * (1 - a)));
}

for (const mode of ["light", "dark"]) {
    test(`theme bridge (${mode}): text 4.5:1 on every surface, accent and borders of controls 3:1`, () => {
        const t = tokensOf(mode);
        for (const surface of ["--pk-surface", "--pk-surface-2", "--pk-surface-3", "--pk-surface-raised", "--pk-total", "--pk-total-strong", "--pk-note", "--pk-accent-soft"]) {
            const bg = parseColor(t[surface]);
            assert.ok(contrastRatio(over(t["--pk-text"], t[surface]), bg) >= 4.5, `text on ${surface}`);
            assert.ok(contrastRatio(over(t["--pk-muted"], t[surface]), bg) >= 4.5, `muted text on ${surface}`);
        }
        assert.ok(contrastRatio(parseColor(t["--pk-accent-text"]), parseColor(t["--pk-accent"])) >= 4.5, "text on the accent");
        assert.ok(contrastRatio(parseColor(t["--pk-accent"]), parseColor(t["--pk-surface"])) >= 3, "accent on the surface");
        assert.ok(contrastRatio(parseColor(t["--pk-focus"]), parseColor(t["--pk-surface"])) >= 3, "focus ring");
        assert.ok(contrastRatio(parseColor(t["--pk-drop-border"]), parseColor(t["--pk-surface"])) >= 3, "edge of a zone");
    });

    test(`theme bridge (${mode}): every token has a value without a corporate stylesheet, except the font`, () => {
        const t = tokensOf(mode);
        for (const [name, value] of Object.entries(t)) {
            if (name === "--pk-font") assert.equal(value, undefined, "pivotkit inherits the page's font");
            else assert.ok(value && !value.includes("var("), `${name}: ${value}`);
        }
    });

    test(`theme bridge (${mode}): corporate values on :root win, --psu-pivot-* over --psu-chart-*`, () => {
        const chart = tokensOf(mode, { "--psu-chart-accent": "#f28c28", "--psu-chart-1": "#003b6f", "--psu-chart-text": "#1f2430" });
        assert.equal(chart["--pk-accent"], "#f28c28");
        assert.equal(chart["--pk-focus"], "#f28c28");
        assert.equal(chart["--pk-chart-1"], "#003b6f");
        assert.equal(chart["--pk-chart-2"], tokensOf(mode)["--pk-chart-2"], "positions without a property keep theirs");
        assert.equal(chart["--pk-text"], "#1f2430");
        // the highlight and the drop zone are tinted with the corporate accent
        assert.match(chart["--pk-accent-soft"], /^color-mix\(in srgb, #f28c28 \d+%, #[0-9a-f]{6}\)$/);
        assert.match(chart["--pk-drop"], /#f28c28/);
        const pivot = tokensOf(mode, { "--psu-chart-accent": "#f28c28", "--psu-pivot-accent": "#003b6f", "--psu-pivot-accent-soft": "#eeeeee" });
        assert.equal(pivot["--pk-accent"], "#003b6f");
        assert.equal(pivot["--pk-accent-soft"], "#eeeeee");
        assert.equal(tokensOf(mode, { "--psu-pivot-font": "Arial" })["--pk-font"], "Arial");
    });
}

test("theme bridge: docs/pivot/themes.md lists every property the bridge reads, with its fallbacks and defaults", () => {
    const rows = docRows();
    assert.deepEqual([...new Set(rows.flatMap((r) => [...r.names, ...r.fallbacks]))].sort(), publicNames());
    for (const row of rows) {
        for (const name of row.names) {
            // the property changes at least one token in both modes
            const changed = (mode, page) => {
                const base = tokensOf(mode);
                const t = tokensOf(mode, page);
                return tokenNames(element(mode)).filter((n) => t[n] !== base[n] && t[n] === "#123456");
            };
            for (const mode of ["light", "dark"]) {
                const tokens = changed(mode, { [name]: "#123456" });
                assert.ok(tokens.length, `${name} sets no token in ${mode}`);
                // each documented fallback reaches the same token when the property itself is not set
                for (const fallback of row.fallbacks) {
                    assert.ok(changed(mode, { [fallback]: "#123456" }).some((n) => tokens.includes(n)), `${name} falls back to ${fallback} (${mode})`);
                }
                const expected = mode === "light" ? row.light : row.dark;
                if (expected !== undefined) {
                    assert.equal(tokensOf(mode)[tokens[0]], expected, `default of ${name} (${mode})`);
                }
            }
        }
    }
});

test("dataLoadEvent: what -OnDataLoad sends - who, how much and the note codes, never a value of the file", () => {
    const columns = Array.from({ length: mod.EVENT_COLUMNS + 5 }, (_, i) => ({ name: `C${i}`, type: "number" }));
    columns[0] = { name: "x".repeat(mod.EVENT_TEXT_LENGTH + 10), type: "string" };
    columns[1] = { name: "Team\r\nINFO forged line\u202e", type: "string" };
    const out = mod.dataLoadEvent({
        cause: "load",
        source: { id: "tickets.csv#0123456789abcdef", name: "tickets.csv" },
        file: { name: "tickets.csv", size: 1234, type: "text/csv" },
        sheet: null,
        rows: 240,
        columns,
        notes: [{ code: "ENCODING", params: { encoding: "utf-8" }, message: "Read as UTF-8." }, { code: "SEPARATOR", params: { separator: ";" }, message: "x" }],
        // anything else pivotkit may add later stays in the browser
        data: [[1, 2, 3]]
    });
    assert.deepEqual(Object.keys(out), ["cause", "source", "file", "sheet", "rows", "columnCount", "columns", "notes"]);
    assert.equal(out.cause, "load");
    assert.deepEqual(out.file, { name: "tickets.csv", size: 1234, type: "text/csv" });
    assert.equal(out.rows, 240);
    assert.equal(out.columnCount, mod.EVENT_COLUMNS + 5);
    assert.equal(out.columns.length, mod.EVENT_COLUMNS);
    assert.equal(out.columns[0].name.length, mod.EVENT_TEXT_LENGTH);
    // no line breaks or direction characters from the file reach the server's log
    assert.equal(out.columns[1].name, "Team  INFO forged line ");
    assert.equal(mod.dataLoadEvent({ file: { name: "a\nb.csv", size: 1, type: "text/csv" } }).file.name, "a b.csv");
    assert.deepEqual(out.notes, ["ENCODING", "SEPARATOR"]);
    assert.ok(!JSON.stringify(out).includes("utf-8"), "no note parameters (they quote the file)");
    // the app's data again: no file
    const back = mod.dataLoadEvent({ cause: "original", source: { id: "tickets" }, file: null, sheet: null, rows: 10, columns: [], notes: [] });
    assert.equal(back.file, null);
    assert.deepEqual(back.source, { id: "tickets", name: null });
    // a report mounted again shows the file it had: reported as such
    assert.equal(mod.dataLoadEvent({ cause: "restore", file: { name: "t.csv", size: 1, type: "text/csv" } }).cause, "restore");
    // anything else is not trusted
    assert.equal(mod.dataLoadEvent({ cause: "<img>" }).cause, null);
    assert.equal(mod.dataLoadEvent(null).rows, 0);
});

test("import worker: its address is the bundle's, with the file name replaced and PSU's query kept", async () => {
    const w = await import("../../modules/PowerShellUniversal.Component.Pivot/Components/importWorker.js");
    const bundle = "https://psu.example.com/api/internal/javascript/index.0123abcd.bundle.js?dashboardId=12";
    const origin = "https://psu.example.com";
    assert.equal(w.workerUrlOf(bundle, "import-worker.ff00.js", origin), "https://psu.example.com/api/internal/javascript/import-worker.ff00.js?dashboardId=12");
    // only a module bundle's address of the page's origin: anything else gives no worker (pivotkit
    // then reads on the page)
    for (const bad of [null, "", "not a url", "https://psu.example.com/app/3f0d01ed.bundle.js", "https://psu.example.com/index.js", "https://cdn.example.net/x/index.0123abcd.bundle.js"]) {
        assert.equal(w.workerUrlOf(bad, "import-worker.ff00.js", origin), null, String(bad));
    }
    assert.equal(w.workerUrlOf(bundle, "", origin), null);
    assert.equal(w.workerUrlOf(bundle, "import-worker.ff00.js", "https://other.example.com"), null);
    // the script element: the one running, else a module bundle of the page; PSU's own bundles do not count
    const script = (src) => ({ src });
    assert.equal(w.bundleScriptOf({ currentScript: script(bundle), scripts: [] }), bundle);
    assert.equal(w.bundleScriptOf({ currentScript: null, scripts: [script("https://psu.example.com/app/3f0d01ed.bundle.js"), script(bundle)] }), bundle);
    assert.equal(w.bundleScriptOf({ currentScript: null, scripts: [script("https://psu.example.com/app/3f0d01ed.bundle.js")] }), null);
    assert.equal(w.bundleScriptOf(undefined), null);
    assert.equal(w.importWorkerOf(null), undefined);
});
