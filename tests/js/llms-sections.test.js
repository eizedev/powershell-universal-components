// llms.txt and llms-full.txt (zensical.toml, [project.plugins.llmstxt.sections]) hold only the pages a
// section names: a new page that no section matches would be missing from both without a warning.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { sitePages } from "../../build/docs-files.js";

const root = new URL("../../", import.meta.url);

/** The patterns of the llmstxt sections, in the order they are written; each section is a one-line array. */
function sectionPatterns() {
    const config = readFileSync(new URL("zensical.toml", root), "utf8");
    const start = config.indexOf("[project.plugins.llmstxt.sections]");
    assert.ok(start >= 0, "zensical.toml has no [project.plugins.llmstxt.sections]");
    const rest = config.slice(start).split("\n").slice(1);
    const end = rest.findIndex((line) => line.startsWith("["));
    const lines = end < 0 ? rest : rest.slice(0, end);
    return lines.flatMap((line) => {
        const list = line.match(/=\s*\[(.*)\]\s*$/);
        return list ? [...list[1].matchAll(/"([^"]+)"/g)].map((m) => m[1]) : [];
    });
}

// fnmatch as the plugin uses it: "*" matches any characters, "/" included
const matcher = (pattern) => new RegExp(`^${pattern.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*")}$`);

test("every page of the site is in exactly one llms.txt section", () => {
    const patterns = sectionPatterns().map((p) => ({ p, re: matcher(p) }));
    assert.ok(patterns.length > 0, "no section patterns found");
    const all = sitePages();
    assert.ok(all.includes("index.md") && all.includes("pivot/reference.md"), "the page list misses known pages");
    for (const page of all) {
        const hits = patterns.filter(({ re }) => re.test(page)).map(({ p }) => p);
        assert.equal(hits.length, 1, `${page} matches ${hits.length ? hits.join(", ") : "no section"} in zensical.toml`);
    }
    // a pattern that matches nothing is a section that silently lost its pages (a typo, a moved folder)
    for (const { p, re } of patterns) assert.ok(all.some((page) => re.test(page)), `"${p}" in zensical.toml matches no page`);
});
