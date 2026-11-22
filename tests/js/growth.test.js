// The growth guards of build/growth.js: how they read ESLint, the PowerShell measurement and the docs,
// and how a ratchet compares with its baseline. CI runs the guards themselves (.github/workflows/ci.yml);
// tests/powershell/Growth.Tests.ps1 tests the PowerShell measurement.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
    DOCS_LIMITS, FUNCTION_LIMITS, GUARD_NAMES, POWERSHELL_LIMITS, compareCounts, compareTotal, docsKind, docsPages,
    formatBaseline, measureDocs, measureJavaScript, parseFunctionMessage, powershellOffenders,
} from "../../build/growth.js";

/** A temporary folder, removed after the test. */
function tempDir(t, name) {
    const dir = mkdtempSync(join(tmpdir(), `growth-${name}-`));
    t.after(() => rmSync(dir, { recursive: true, force: true }));
    return dir;
}

test("ESLint's messages give each function's name and numbers, and an eslint-disable comment hides nothing", async (t) => {
    const dir = tempDir(t, "eslint");
    mkdirSync(join(dir, "modules/A/Components"), { recursive: true });
    mkdirSync(join(dir, "shared/js"), { recursive: true });
    const statements = (n) => Array.from({ length: n }, (_, i) => `    if (x > ${i}) x -= 1;`).join("\n");
    writeFileSync(join(dir, "modules/A/Components/View.jsx"), [
        "/* eslint-disable max-lines-per-function, complexity */",
        `export function View({ x }) {\n${statements(FUNCTION_LIMITS.lines + 5)}\n    return <div>{x}</div>;\n}`,
        "export const small = (x) => x + 1;",
    ].join("\n"));
    writeFileSync(join(dir, "shared/js/branched.js"), `export const branched = (x) => {\n${statements(FUNCTION_LIMITS.complexity + 1)}\n    return x;\n};\n`);
    // outside the folders the guard reads
    writeFileSync(join(dir, "modules/A/webpack.config.js"), `export function config(x) {\n${statements(FUNCTION_LIMITS.lines + 5)}\n}\n`);
    const found = await measureJavaScript(dir);
    // the head, the statements, the return and the closing brace
    assert.deepEqual(found.lines, { "modules/A/Components/View.jsx Function 'View'": [FUNCTION_LIMITS.lines + 5 + 3] });
    // one path plus one per if; complexity names an arrow function without its variable
    assert.deepEqual(found.complexity, {
        "modules/A/Components/View.jsx Function 'View'": [FUNCTION_LIMITS.lines + 5 + 1],
        "shared/js/branched.js Arrow function": [FUNCTION_LIMITS.complexity + 2],
    });
});

test("a message in other words fails instead of counting nothing", () => {
    assert.deepEqual(parseFunctionMessage({ ruleId: "complexity", message: "Method 'x' has a complexity of 30. Maximum allowed is 25." }), { metric: "complexity", name: "Method 'x'", value: 30 });
    assert.throws(() => parseFunctionMessage({ ruleId: "complexity", message: "Method 'x' is too complex (30)." }), /unexpected ESLint message/);
    assert.throws(() => parseFunctionMessage({ ruleId: "no-undef", message: "'x' is not defined." }), /unexpected ESLint message/);
});

test("PowerShell offenders: files by path, functions by name, so moving a function into a file of its own keeps its entry", () => {
    const over = POWERSHELL_LIMITS.function + 50;
    const before = powershellOffenders({
        files: [{ path: "M/M.psm1", lines: POWERSHELL_LIMITS.file + 1 }, { path: "M/small.ps1", lines: POWERSHELL_LIMITS.file }],
        functions: [{ path: "M/M.psm1", name: "New-Thing", lines: over }, { path: "M/M.psm1", name: "Get-Small", lines: POWERSHELL_LIMITS.function }],
    });
    assert.deepEqual(before, { files: { "M/M.psm1": [POWERSHELL_LIMITS.file + 1] }, functions: { "New-Thing": [over] } });
    const after = powershellOffenders({
        files: [{ path: "M/M.psm1", lines: 10 }, { path: "M/Public/New-Thing.ps1", lines: over }],
        functions: [{ path: "M/Public/New-Thing.ps1", name: "New-Thing", lines: over }],
    });
    // the function did not grow; only the file that shrank asks for a lower baseline
    assert.deepEqual(compareCounts(before.functions, after.functions, "code lines"), { grew: [], stale: [] });
    assert.deepEqual(compareCounts(before.files, after.files, "code lines"), { grew: [], stale: [`M/M.psm1: ${POWERSHELL_LIMITS.file + 1} code lines in the baseline, now within the limit`] });
    assert.throws(() => powershellOffenders({}), /no files and functions/);
});

test("compareCounts: growth and new offenders fail as grown, shrinking and going as stale", () => {
    const baseline = { "a.js f": [200], "a.js g": [150], "a.js Arrow function": [300, 130] };
    assert.deepEqual(compareCounts(baseline, baseline, "lines"), { grew: [], stale: [] });
    const { grew, stale } = compareCounts(baseline, { "a.js f": [210], "a.js Arrow function": [300, 130], "b.js h": [121] }, "lines");
    assert.deepEqual(grew, ["a.js f: 210 lines, baseline 200", "b.js h: 121 lines, new"]);
    assert.deepEqual(stale, ["a.js g: 150 lines in the baseline, now within the limit"]);
    assert.deepEqual(compareCounts(baseline, { ...baseline, "a.js f": [190] }, "lines").stale, ["a.js f: 190 lines, baseline 200"]);
});

test("compareCounts: functions under one key compare by their sorted numbers, not by position", () => {
    const baseline = { "a.js Arrow function": [300, 130] };
    assert.deepEqual(compareCounts(baseline, { "a.js Arrow function": [300, 200, 130] }, "lines"), { grew: ["a.js Arrow function: 200 lines, new"], stale: [] });
    assert.deepEqual(compareCounts(baseline, { "a.js Arrow function": [300, 140] }, "lines"), { grew: ["a.js Arrow function: 140 lines, baseline 130"], stale: [] });
    assert.deepEqual(compareCounts(baseline, { "a.js Arrow function": [300, 130] }, "lines"), { grew: [], stale: [] });
});

test("compareTotal allows a drift within the margin", () => {
    assert.deepEqual(compareTotal(1000, 1020), { grew: [], stale: [] });
    assert.equal(compareTotal(1000, 1021).grew.length, 1);
    assert.equal(compareTotal(1000, 979).stale.length, 1);
});

test("docs pages and READMEs count their lines by kind; docs/site/ is not a page", (t) => {
    const dir = tempDir(t, "docs");
    for (const folder of ["docs/a", "docs/site/data", "modules/M"]) mkdirSync(join(dir, folder), { recursive: true });
    writeFileSync(join(dir, "docs/a/long.md"), "x\n".repeat(DOCS_LIMITS.topic + 1));
    writeFileSync(join(dir, "docs/a/index.md"), "x\ny");
    writeFileSync(join(dir, "docs/site/data/SOURCES.md"), "x\n".repeat(1000));
    writeFileSync(join(dir, "modules/M/README.md"), "x\n".repeat(DOCS_LIMITS.readme + 1));
    const pages = docsPages(dir);
    assert.deepEqual(pages, { "docs/a/long.md": DOCS_LIMITS.topic + 1, "docs/a/index.md": 2, "modules/M/README.md": DOCS_LIMITS.readme + 1 });
    assert.deepEqual(measureDocs(pages), {
        pages: { "docs/a/long.md": [DOCS_LIMITS.topic + 1], "modules/M/README.md": [DOCS_LIMITS.readme + 1] },
        totalLines: DOCS_LIMITS.topic + DOCS_LIMITS.readme + 4,
    });
    assert.deepEqual(["README.md", "docs/index.md", "docs/pivot/reference.md", "docs/pivot/views.md"].map(docsKind), ["readme", "overview", "reference", "topic"]);
});

test("the committed baseline is sorted, one entry per line, as --update writes it", () => {
    const text = readFileSync(new URL("../../build/growth-baseline.json", import.meta.url), "utf8");
    assert.equal(formatBaseline(JSON.parse(text)), text, "build/growth-baseline.json was edited by hand: run node build/growth.js --update");
});

test("CI runs every guard in a step of its own", () => {
    const ci = readFileSync(new URL("../../.github/workflows/ci.yml", import.meta.url), "utf8");
    for (const name of GUARD_NAMES) assert.match(ci, new RegExp(`^ {8}run: node build/growth\\.js ${name}$`, "m"), `ci.yml runs no step "node build/growth.js ${name}"`);
});
