// Tests for shared/js: column matching, formats, CSV and XLSX export. Run: node --test tests/js/
import { test } from "node:test";
import assert from "node:assert/strict";
import { camelCase, resolveColumn, columnsOf } from "../../shared/js/columns.js";
import { formatter, formatDuration, formatBytes } from "../../shared/js/formatters.js";
import { toCsv, csvSeparator, exportColumns, toXlsxBytes } from "../../shared/js/exporter.js";

test("camelCase follows Newtonsoft's rules", () => {
    assert.equal(camelCase("Team"), "team");
    assert.equal(camelCase("ID"), "id");
    assert.equal(camelCase("XAxis"), "xAxis");
    assert.equal(camelCase("URLValue"), "urlValue");
    assert.equal(camelCase("leadTime"), "leadTime");
});

test("resolveColumn matches what PSU sent, whatever the user typed", () => {
    const keys = ["team", "leadTime", "id"];
    assert.equal(resolveColumn("Team", keys), "team");
    assert.equal(resolveColumn("LeadTime", keys), "leadTime");
    assert.equal(resolveColumn("ID", keys), "id");
    assert.equal(resolveColumn("missing", keys), undefined);
    assert.equal(resolveColumn("", keys), undefined);
});

test("columnsOf keeps first-seen order across rows", () => {
    assert.deepEqual(columnsOf([{ a: 1 }, { b: 2, a: 3 }, null]), ["a", "b"]);
});

test("formats", () => {
    assert.equal(formatter("number:1", "de-DE")(1234.56), "1.234,6");
    assert.equal(formatter("integer", "en-US")(1234.56), "1,235");
    assert.equal(formatter("percent", "en-US")(0.25), "25%");
    assert.equal(formatter("percent100", "en-US")(25), "25%");
    assert.match(formatter("currency:EUR", "de-DE")(1234.5), /1\.234,50\s€/);
    assert.equal(formatter("bytes", "en-US")(1536), "1.5 KB");
    assert.equal(formatter("duration:h", "en-US")(2.5), "2 h 30 min");
    assert.equal(formatter("text", "en-US")(null), "");
    assert.equal(formatter("number", "en-US")("abc"), "abc");
    assert.equal(formatter(undefined, "en-US"), null);
});

test("durations and bytes", () => {
    assert.equal(formatDuration(45, "en-US"), "45 s");
    assert.equal(formatDuration(3700, "en-US"), "1 h 1 min");
    assert.equal(formatDuration(90000, "en-US"), "1 d 1 h");
    assert.equal(formatDuration(-120, "en-US"), "-2 min");
    assert.equal(formatBytes(0, "en-US"), "0 B");
    assert.equal(formatBytes(5 * 1024 ** 3, "en-US"), "5 GB");
});

test("CSV: locale separator, quoting, formula injection, BOM", () => {
    assert.equal(csvSeparator("de-DE"), ";");
    assert.equal(csvSeparator("en-US"), ",");
    const rows = [{ name: 'Say "hi"; ok', value: 1234.5, note: "=SUM(A1)" }];
    const csv = toCsv(rows, null, "de-DE");
    assert.ok(csv.startsWith("﻿"));
    const line = csv.split("\r\n")[1];
    assert.equal(line, '"Say ""hi""; ok";1234,5;\'=SUM(A1)');
});

test("export columns: definition order, titles, unknown fields dropped", () => {
    const rows = [{ leadTime: 3, team: "OPS" }];
    const cols = exportColumns(rows, [{ field: "Team", title: "Team name" }, "LeadTime", "Missing"]);
    assert.deepEqual(cols.map((c) => [c.key, c.title]), [["team", "Team name"], ["leadTime", "LeadTime"]]);
    assert.equal(cols[1].type, "number");
});

test("XLSX is a zip with typed cells", () => {
    const bytes = toXlsxBytes([{ day: "2026-11-05T10:00:00", amount: 12.5, team: "<OPS>" }], [{ field: "amount", type: "currency", format: "currency:USD" }, "day", "team"], "Tickets");
    assert.equal(bytes[0], 0x50); // "PK"
    assert.equal(bytes[1], 0x4b);
    assert.ok(bytes.length > 500);
});

test("html: interpolations escaped, nested html and markers kept", async () => {
    const { html, joinHtml, trusted, escapeHtml } = await import("../../shared/js/html.js");
    assert.equal(escapeHtml('<img src=x onerror="a">'), "&lt;img src=x onerror=&quot;a&quot;&gt;");
    const name = "<script>x</script>";
    assert.equal(String(html`<b>${name}</b>`), "<b>&lt;script&gt;x&lt;/script&gt;</b>");
    assert.equal(String(html`${trusted("<span></span>")}${html`<i>${"&"}</i>`}`), "<span></span><i>&amp;</i>");
    assert.equal(String(joinHtml([html`${"a<"}`, "b>"], "<br/>")), "a&lt;<br/>b&gt;");
});

test("template: columns case-insensitive, formats, lists, escaping, unknown kept", async () => {
    const { compileTemplate, columnsTemplate } = await import("../../shared/js/template.js");
    const keys = ["name", "cpu", "ramGB", "tags"];
    const row = { name: "vm<1>", cpu: 4, ramGB: 16, tags: ["prod", "db"] };
    const t = compileTemplate("{Name}: {CPU} vCPU, {RamGB:integer} GB [{Tags}] {Nope}", keys, "en-US");
    assert.equal(t(row), "vm<1>: 4 vCPU, 16 GB [prod, db] {Nope}");
    assert.equal(compileTemplate("{Name}\n{Cpu}", keys, "en-US")(row, true), "vm&lt;1&gt;<br/>4");
    assert.equal(columnsTemplate(["Cpu", "RamGB:bytes"]), "Cpu: {Cpu}\nRamGB: {RamGB:bytes}");
    assert.equal(columnsTemplate(["Memory (GB)=RamGB:number:1"]), "Memory (GB): {RamGB:number:1}");
});
