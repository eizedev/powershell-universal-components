// Tests for the pivot module's pure helpers and its PSU theme bridge. Run: node --test "tests/js/*.test.js"
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { contrastRatio, parseColor } from "../../shared/js/contrast.js";

const mod = await import("../../modules/PowerShellUniversal.Component.Pivot/Components/prepare.js");

test("restoreRows: PowerShell's column names back, dates readable and still ISO", () => {
    // as PSU sends them: keys camelCased, the original names in columnNames
    const rows = [
        { ticket: 1, "lead hours": 2.5, created: "2026-08-16T17:31:00.0000000", day: "2026-08-16T00:00:00.0000000", agent: null },
        { ticket: 2, "lead hours": null, created: "2026-08-17T09:00:00.0000000+02:00", day: "2026-08-17T00:00:00.0000000", agent: "Kim" }
    ];
    const out = mod.restoreRows(rows, ["Ticket", "Lead hours", "Created", "Day", "Agent"]);
    assert.deepEqual(Object.keys(out[0]), ["Ticket", "Lead hours", "Created", "Day", "Agent"]);
    assert.equal(out[0].Created, "2026-08-16 17:31:00");
    assert.equal(out[0].Day, "2026-08-16");
    assert.equal(out[1].Created, "2026-08-17 09:00:00+02:00");
    assert.equal(out[0].Agent, null);
    assert.equal(out[1]["Lead hours"], null);
    assert.deepEqual(mod.restoreRows(null, []), []);
    assert.deepEqual(mod.restoreRows([1, "x", null, { a: 1 }], ["A"]), [{ A: 1 }]);
});

test("readableDate: only .NET's round-trip dates change; a fraction that is not zero stays", () => {
    assert.equal(mod.readableDate("2026-08-16T17:31:59.9990000"), "2026-08-16 17:31:59.9990000");
    assert.equal(mod.readableDate("2026-08-16T00:00:00.0000000Z"), "2026-08-16 00:00:00Z");
    for (const v of ["2026-08-16", "Team 2026-08-16T17:31:00", 42, null, "2026-13-99T99:99:99.0x"]) {
        assert.equal(mod.readableDate(v), v);
    }
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

test("heightOf and themeOf", () => {
    assert.equal(mod.heightOf(500), 500);
    assert.equal(mod.heightOf(" 70vh "), "70vh");
    assert.equal(mod.heightOf(undefined), mod.DEFAULT_HEIGHT);
    assert.equal(mod.heightOf("", true), mod.NARROW_HEIGHT);
    assert.equal(mod.themeOf("Dark"), "dark");
    assert.equal(mod.themeOf(undefined), "auto");
    assert.equal(mod.themeOf("blue"), "auto");
});

// ---- the PSU theme bridge ------------------------------------------------------------------------

const css = readFileSync(new URL("../../modules/PowerShellUniversal.Component.Pivot/Components/psu.css", import.meta.url), "utf8");

function tokens(selector) {
    const start = css.indexOf(`${selector} {`);
    assert.ok(start >= 0, selector);
    const block = css.slice(start, css.indexOf("}", start));
    return Object.fromEntries([...block.matchAll(/(--pk-[a-z0-9-]+):\s*([^;]+);/g)].map((m) => [m[1], m[2].trim()]));
}

// a colour with alpha over its background, as the browser draws it
function over(color, background) {
    const alpha = /rgba\([^)]*,\s*([\d.]+)\s*\)/.exec(color);
    const fg = parseColor(color);
    const bg = parseColor(background);
    const a = alpha ? Number(alpha[1]) : 1;
    return fg.map((v, i) => Math.round(v * a + bg[i] * (1 - a)));
}

for (const [mode, selector] of [["light", ".ud-pivot-report .pk-root"], ["dark", '.ud-pivot-report .pk-root[data-pk-theme="dark"]']]) {
    test(`theme bridge (${mode}): text 4.5:1 on every surface, accent and borders of controls 3:1`, () => {
        const t = { ...tokens(".ud-pivot-report .pk-root"), ...tokens(selector) };
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
}
