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

test("readTemplates: keys in any case, views as objects or JSON, bad entries and duplicates left out", () => {
    const t = mod.readTemplates([
        { name: "A", view: { rows: ["Team"] } },
        { Name: "B", View: '{"cols":["Priority"]}', Deletable: true },
        { name: "A", view: { rows: ["Other"] } },
        { name: "", view: {} },
        { name: "C", view: "nope" },
        null
    ]);
    assert.deepEqual(t, [
        { name: "A", view: { rows: ["Team"] }, deletable: false },
        { name: "B", view: { cols: ["Priority"] }, deletable: true }
    ]);
    assert.deepEqual(mod.readTemplates(undefined), []);
});

test("mergeTemplates: saved ones appended or replacing deletable ones, never built-in ones; deleted ones gone", () => {
    const server = [{ name: "Built-in", view: {}, deletable: false }, { name: "Mine", view: { rows: ["A"] }, deletable: true }];
    const saved = [{ name: "Mine", view: { rows: ["B"] }, deletable: true }, { name: "Built-in", view: {}, deletable: true }, { name: "New", view: {}, deletable: true }];
    const merged = mod.mergeTemplates(server, saved, new Set());
    assert.deepEqual(merged.map((t) => t.name), ["Built-in", "Mine", "New"]);
    assert.deepEqual(merged[1].view, { rows: ["B"] });
    assert.equal(merged[0].deletable, false);
    assert.deepEqual(mod.mergeTemplates(server, saved, new Set(["Mine", "New"])).map((t) => t.name), ["Built-in"]);
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
