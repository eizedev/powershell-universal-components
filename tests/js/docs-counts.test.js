// Counts the docs and READMEs name ("14 pages", "29 chart types") against the code they count, so a
// new chart type or showcase page cannot leave a stale number behind.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const root = new URL("../../", import.meta.url);
const read = (path) => readFileSync(new URL(path, root), "utf8");
const WORDS = { fourteen: 14, fifteen: 15, sixteen: 16 };
const numberOf = (text) => (/^\d+$/.test(text) ? Number(text) : WORDS[text.toLowerCase()]);

test("the chart type count in the docs is the number of -Type values", () => {
    const command = read("modules/PowerShellUniversal.Component.ECharts/Public/New-UDEChart.ps1");
    const set = /\[ValidateSet\(([^)]*)\)\]\s*\[string\]\$Type\b/.exec(command);
    assert.ok(set, "the ValidateSet of -Type in New-UDEChart.ps1");
    const types = set[1].split(",").length;
    for (const path of ["README.md", "docs/index.md", "modules/PowerShellUniversal.Component.ECharts/README.md"]) {
        const named = [...read(path).matchAll(/\b(\d+) (?:\[[^\]]*\]\([^)]*\) )?chart types\b/g)].map((m) => Number(m[1]));
        assert.ok(named.length > 0, `${path} names the chart types`);
        for (const n of named) assert.equal(n, types, `${path}: ${n} chart types, -Type has ${types}`);
    }
});

test("the page count of the ECharts showcase in the docs is the number of its pages", () => {
    const pages = (read("modules/PowerShellUniversal.Component.ECharts.Demo/Apps/Showcase.ps1").match(/\bNew-UDPage\b/g) || []).length;
    const places = [
        "README.md",
        "docs/demo.md",
        "docs/getting-started.md",
        "docs/index.md",
        "modules/PowerShellUniversal.Component.ECharts.Demo/README.md",
        "modules/PowerShellUniversal.Component.ECharts.Demo/PowerShellUniversal.Component.ECharts.Demo.psm1"
    ];
    for (const path of places) {
        const named = [...read(path).matchAll(/\b(\d+|fourteen|fifteen|sixteen) pages\b/gi)].map((m) => numberOf(m[1]));
        assert.ok(named.length > 0, `${path} names the pages`);
        for (const n of named) assert.equal(n, pages, `${path}: ${n} pages, Showcase.ps1 has ${pages}`);
    }
});
