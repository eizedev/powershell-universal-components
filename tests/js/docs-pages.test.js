// Checks beyond what the site build checks: on every page of the site, a list starts after a blank line
// and the front matter has a description; the current-state docs (READMEs, guides and pages outside
// docs/decisions/) name no release of pivotkit or of a module. eizedev/pivotkit has the same checks (tests/docs-lists.test.js, tests/ci.test.js).
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { currentStateDocs, root, sitePages } from "../../build/docs-files.js";

const read = (path) => readFileSync(join(root, path), "utf8");

// A list needs a blank line before it. Python-Markdown (Zensical) lets no list interrupt a paragraph:
// a "- " or "1. " line right after a paragraph that is not a list item, such as an indented paragraph
// inside an item, becomes part of that paragraph's text. The strict build does not warn. A line right
// after a table becomes another table row. Inside a blockquote, the check reads the lines without
// their "> ". It does not follow a blockquote's lazy lines that have no "> ".
const LIST_ITEM = /^\s*(?:[-*+]|\d+\.)\s+\S/;
const FENCE = /^\s*(`{3,}|~{3,})/;
// Lines that are a block of their own, so the next line starts a new block: a heading, an
// admonition's or a content tab's title, an HTML line or a rule.
const OWN_BLOCK = /^\s*(?:#|!!!|\?\?\?|===|<|(?:-{3,}|\*{3,}|_{3,})\s*$)/;
const QUOTE = /^\s*(?:>\s?)+/;

/**
 * The list items of a Markdown text that follow a paragraph or a table row without a blank line, as
 * 1-based line numbers. Code fences and front matter are skipped.
 * @param {string} text
 * @returns {number[]}
 */
function swallowedListItems(text) {
    const found = [];
    let fence = null;
    /** The first line of the paragraph the previous line belongs to, or null after a block's end. */
    let paragraphStart = null;
    const lines = text.split("\n");
    const bodyStart = lines[0] === "---" ? lines.indexOf("---", 1) + 1 : 0;
    lines.forEach((source, index) => {
        if (index < bodyStart) return;
        const line = source.replace(QUOTE, "");
        const marker = line.match(FENCE)?.[1];
        if (fence) {
            if (marker && marker[0] === fence[0] && marker.length >= fence.length) fence = null;
            return;
        }
        if (marker) {
            fence = marker;
            paragraphStart = null;
            return;
        }
        if (!line.trim() || OWN_BLOCK.test(line)) {
            paragraphStart = null;
            return;
        }
        if (LIST_ITEM.test(line)) {
            if (paragraphStart !== null && !LIST_ITEM.test(paragraphStart)) found.push(index + 1);
            paragraphStart = line;
            return;
        }
        paragraphStart ??= line;
    });
    return found;
}

/** Each case: a Markdown text and the line numbers swallowedListItems reports. */
const LIST_CASES = [
    { name: "a list right after a paragraph", lines: ["Intro:", "- item"], found: [2] },
    { name: "a numbered list right after a paragraph", lines: ["Intro:", "1. item"], found: [2] },
    { name: "a list after a blank line", lines: ["Intro:", "", "- item", "1. item"], found: [] },
    { name: "an item with a wrapped line and a nested list", lines: ["- item", "  wrapped", "    - nested"], found: [] },
    { name: "an item after an indented paragraph in the item above", lines: ["- item", "", "    Indented paragraph", "- next item"], found: [4] },
    { name: "a list right after a heading", lines: ["## Heading", "- item"], found: [] },
    { name: "a list in a code fence", lines: ["Text", "```", "text", "- in code", "```"], found: [] },
    { name: "a list in an admonition", lines: ["!!! note", "    - item", "    1. numbered"], found: [] },
    { name: "a list in a fold", lines: ['<details class="note" markdown="1">', "<summary>More</summary>", "- item"], found: [] },
    { name: "a list after a table", lines: ["| a | b |", "| --- | --- |", "| 1 | 2 |", "", "- item"], found: [] },
    // Python-Markdown takes the line as another table row.
    { name: "a list right after a table", lines: ["| a | b |", "| --- | --- |", "- item"], found: [3] },
    { name: "a list right after a paragraph in a blockquote", lines: ["> Intro:", "> - item"], found: [2] },
    { name: "a list in a blockquote after a blank line", lines: ["> Intro:", ">", "> - item"], found: [] },
    { name: "front matter", lines: ["---", "title: Page", "hide:", "  - toc", "---"], found: [] },
    // Flagged on purpose: the page shows it as text, but the source reads like a list. Rewrap the line.
    { name: "a wrapped line that starts with a number and a dot", lines: ["Since version", "2. it works"], found: [2] },
];

for (const { name, lines, found } of LIST_CASES) {
    test(`swallowedListItems: ${name}`, () => {
        assert.deepEqual(swallowedListItems(lines.join("\n")), found);
    });
}

test("every list in the docs starts after a blank line", () => {
    const pages = sitePages();
    assert.ok(pages.includes("index.md") && pages.includes("pivot/reference.md"), "the page list misses known pages");
    const problems = pages.flatMap((page) => swallowedListItems(read(`docs/${page}`)).map((line) => `docs/${page}:${line}`));
    assert.deepEqual(problems, [], "add a blank line before these list items");
});

/**
 * The description in a page's front matter, or undefined.
 * @param {string} text
 */
function descriptionOf(text) {
    const front = /^---\n([\s\S]*?)\n---\n/.exec(text)?.[1];
    return front && /^description:[ \t]*(\S.*)$/m.exec(front)?.[1];
}

test("descriptionOf reads the description of the front matter only", () => {
    assert.equal(descriptionOf("---\ntitle: T\ndescription: What the page covers.\n---\n\n# T\n"), "What the page covers.");
    assert.equal(descriptionOf("---\ndescription:\n---\n"), undefined);
    assert.equal(descriptionOf("# T\n\ndescription: not front matter\n"), undefined);
});

// The description goes into the page's meta and Open Graph tags (overrides/main.html) and llms.txt;
// without one, search engines and link previews show the site's description for every page.
test("every page of the site has a description in its front matter", () => {
    assert.deepEqual(sitePages().filter((page) => !descriptionOf(read(`docs/${page}`))), []);
});

// A release named as a fact of the present ("pivotkit 0.8 does not know it") is wrong for the next
// reader, and a release leaves it behind. The docs say what a feature needs as one minimum
// ("pivotkit-server 0.4.0 or later") and otherwise describe what an older version does, without its
// number. The pattern names pivotkit and its packages, the modules by their full name, "Pivot" and
// "<name> module"; "ECharts 6.1" or "Perspective 5.7" name a bundled library, not a module.
const RELEASE_NAME = /\b(?:pivotkit(?:-[a-z]+)?|PowerShellUniversal\.Component\.[A-Za-z.]*[A-Za-z]|Pivot|(?:ECharts|Perspective|Pivot) module)`?[ @]\(?v?\d+\.\d+(?:\.\d+)?(?!\.?\d)(?!\)?\s+or\s+(?:later|newer))/g;

/**
 * Where a current-state page may name releases: the whole file, or one section of it (its "## "
 * heading). Changelogs, decision records and the reference generated from the commands' help are
 * not current-state pages (build/docs-files.js).
 */
const RELEASE_NAMES_ALLOWED = [
    { file: "docs/versioning.md" },
    // the breaks of each module's newest release, by release
    { file: "docs/upgrading.md" },
    // the versions the modules support and were tested with
    { file: "docs/compatibility.md" },
];

/**
 * The release names in a text, without the allowed sections.
 * @param {string} text
 * @param {string[]} [sections]  the "## " headings whose sections may name releases
 * @returns {string[]}
 */
function releaseNames(text, sections = []) {
    const kept = text.split(/^(?=## )/m).filter((part) => !sections.some((s) => part.startsWith(`## ${s}\n`)));
    return kept.flatMap((part) => [...part.matchAll(RELEASE_NAME)].map((m) => m[0]));
}

test("releaseNames finds a release named as a fact and leaves minimums and allowed sections alone", () => {
    assert.deepEqual(releaseNames("pivotkit 0.8 does not know it. Pivot 0.10.0 changed it."), ["pivotkit 0.8", "Pivot 0.10.0"]);
    assert.deepEqual(releaseNames("Tag pivotkit-server@0.4.0 or PowerShellUniversal.Component.Pivot.Demo 0.3."), ["pivotkit-server@0.4.0", "PowerShellUniversal.Component.Pivot.Demo 0.3"]);
    assert.deepEqual(releaseNames("Since `pivotkit-cli` 0.8 it works."), ["pivotkit-cli` 0.8"]);
    assert.deepEqual(releaseNames("needs pivotkit-server 0.4.0 or\nlater; a pivotkit-server (0.3.0 or later)"), []);
    assert.deepEqual(releaseNames("Apache ECharts 6.1 and Perspective 5.7, the ECharts module 0.3"), ["ECharts module 0.3"]);
    assert.deepEqual(releaseNames("## Requirements\n\nTested with pivotkit-cli 0.6.0.\n\n## Next\n\npivotkit 0.9\n", ["Requirements"]), ["pivotkit 0.9"]);
});

test("current-state docs name no release of pivotkit or a module outside the allowed places", () => {
    const docs = currentStateDocs();
    for (const { file, section } of RELEASE_NAMES_ALLOWED) {
        assert.ok(docs.includes(file), `${file} is no current-state page: update RELEASE_NAMES_ALLOWED`);
        if (section) assert.ok(read(file).includes(`\n## ${section}\n`), `${file} has no section "## ${section}": update RELEASE_NAMES_ALLOWED`);
    }
    const problems = docs.flatMap((file) => {
        const allowed = RELEASE_NAMES_ALLOWED.filter((a) => a.file === file);
        if (allowed.some((a) => !a.section)) return [];
        return releaseNames(read(file), allowed.map((a) => a.section)).map((name) => `${file}: ${name}`);
    });
    assert.deepEqual(problems, [], "say what the feature needs as a minimum (\"0.4.0 or later\") or what an older version does, without its number");
});
