// build/whole-change-check.js: which changes need the description's whole-change check, what counts
// as one, and who is exempt. The workflow that runs it is checked in tests/js/ci.test.js.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { check, exemption, inScope, sectionText } from "../../build/whole-change-check.js";

const template = readFileSync(new URL("../../.github/PULL_REQUEST_TEMPLATE.md", import.meta.url), "utf8");
const pr = (body, files = ["docs/echarts/themes.md"], more = {}) => check({ body, title: "docs: themes", author: "someone", files, ...more });

test("docs, READMEs, root Markdown, module code, shared/ and build/ need the check; the rest does not", () => {
    const M = "modules/PowerShellUniversal.Component.Pivot";
    const needed = ["docs/echarts/themes.md", "docs/development/index.md", "README.md", `${M}/README.md`, "AGENTS.md", "CONTRIBUTING.md", `${M}/Components/pivot.jsx`, `${M}/Public/New-UDPivotReport.ps1`, `${M}/Private/Settings/Limits.ps1`, `${M}/Private/RowConverter.cs`, "modules/PowerShellUniversal.Component.Perspective/PowerShellUniversal.Component.Perspective.psm1", "shared/js/columns.js", "shared/powershell/ConvertTo-PSUComponentData.ps1", "build/growth.js"];
    const not = ["docs/site/examples.ps1", "docs/site/src/charts.jsx", `${M}/CHANGELOG.md`, `${M}/package.json`, `${M}/${M.split("/")[1]}.psd1`, `${M}/examples/app.ps1`, "tests/js/ci.test.js", ".github/workflows/ci.yml", "package-lock.json"];
    assert.deepEqual(inScope([...needed, ...not]), needed);
});

test("the template as it is fails: its prompts are a comment", () => {
    assert.equal(sectionText(template), "");
    assert.equal(pr(template).ok, false);
});

test("the template with an answer under the heading passes", () => {
    const filled = template.replace(/(## Whole-change check\s*<!--[\s\S]*?-->)/, "$1\n\nthemes.md: read whole; moved the token table to the reference page.");
    assert.equal(pr(filled).ok, true);
});

test("a missing, empty or only-comment section fails, and the message says what to add", () => {
    for (const body of [null, undefined, "", "## Summary\n\nText.", "## Whole-change check\n\n## Test plan\n\nRan it.", "## Whole-change check\n<!-- later -->\n", "## Whole-change check\n\n- [ ]\n"]) {
        const result = pr(body);
        assert.equal(result.ok, false, JSON.stringify(body));
        assert.match(result.message, /docs\/echarts\/themes\.md/);
        assert.match(result.message, /"## Whole-change check" section with text/);
        assert.match(result.message, /PULL_REQUEST_TEMPLATE\.md/);
    }
});

test("the section ends at the next heading of level 1 or 2, not at a sub-heading", () => {
    assert.equal(sectionText("## Whole-change check\r\nRead it whole.\r\n## Test plan\r\nRan."), "Read it whole.");
    assert.equal(sectionText("## Summary\n\nx\n\n## Whole-change check\n\n### Docs\nRead it whole."), "### Docs\nRead it whole.");
    assert.equal(sectionText("# Title\n## whole-change check ##\nok\n# Next"), "ok");
    // a heading inside a comment or within a line does not count
    assert.equal(sectionText("<!-- ## Whole-change check\nnot here -->"), null);
    assert.equal(sectionText("Text about ## Whole-change check"), null);
});

test("an unclosed comment hides the rest, as GitHub renders it", () => {
    assert.equal(sectionText("## Whole-change check\n<!-- started\nhidden text"), "");
});

test("a pull request without docs or code passes without the check", () => {
    const result = pr("", ["package-lock.json", "tests/js/ci.test.js"]);
    assert.deepEqual(result, { ok: true, message: "Whole-change check: not needed, no docs or code changed." });
});

test("Dependabot and release pull requests are exempt; other titles and authors are not", () => {
    assert.equal(exemption({ author: "dependabot[bot]", title: "build(deps): Bump x" }), "a Dependabot pull request");
    for (const title of ["chore(pivot): release Pivot 0.10.1", "chore(pivot): release Pivot.Demo 0.3.0", "chore(release): ECharts 0.2.0", "chore: release 0.1.0"]) {
        assert.equal(exemption({ author: "someone", title }), "a release pull request", title);
    }
    for (const [author, title] of [["dependabot", "x"], ["someone", "ci(release): release only commits that are on main"], ["someone", "feat: release notes page"], ["someone", "chore: released files"]]) {
        assert.equal(exemption({ author, title }), null, `${author} ${title}`);
    }
    assert.equal(pr("", ["build/growth.js"], { author: "dependabot[bot]" }).ok, true);
    assert.equal(pr("", ["build/growth.js"], { title: "chore(pivot): release Pivot 0.10.1" }).ok, true);
});
