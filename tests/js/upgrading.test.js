// docs/upgrading.md lists the breaks of each module's newest minor release and of the next release, as
// the CHANGELOGs mark them (**Breaking:**). The release pull request updates the page with the
// CHANGELOG (docs/development/release.md); this test fails until both agree in the number of breaks.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";

const root = new URL("../../", import.meta.url);
const PREFIX = "PowerShellUniversal.Component.";
const read = (path) => readFileSync(new URL(path, root), "utf8");

/**
 * The sections of a CHANGELOG by release ("Unreleased", "0.10.1"), newest first, with the number of
 * entries marked **Breaking:** in each.
 * @param {string} text
 * @returns {{ release: string, breaks: number }[]}
 */
function changelogReleases(text) {
    return text.split(/^(?=## \[)/m).slice(1).map((part) => ({
        release: /^## \[([^\]]+)\]/.exec(part)[1],
        breaks: (part.match(/^- \*\*Breaking:\*\*/gm) ?? []).length,
    }));
}

/**
 * The "### " sections of the upgrading page by heading, with their top-level list items.
 * @param {string} text
 * @returns {Map<string, number>}
 */
function upgradingSections(text) {
    const changes = text.slice(text.indexOf("\n## What changed"));
    return new Map(changes.split(/^(?=### )/m).slice(1).map((part) => [
        /^### (.+?)(?: \{ #[\w-]+ \})?$/m.exec(part)[1],
        (part.match(/^- /gm) ?? []).length,
    ]));
}

test("changelogReleases and upgradingSections read releases, headings and breaks", () => {
    const log = "# Changelog\n\n## [Unreleased]\n\n- **Breaking:** a\n  - Who\n\n## [0.2.0] - 2026-01-01\n\n- **Breaking:** b\n- c\n";
    assert.deepEqual(changelogReleases(log), [{ release: "Unreleased", breaks: 1 }, { release: "0.2.0", breaks: 1 }]);
    const page = "# U\n\n## What changed { #changes }\n\n### In the next release { #next }\n\n- **a**\n    - Who\n\n### Pivot 0.2 { #pivot }\n\n- **b**\n";
    assert.deepEqual([...upgradingSections(page)], [["In the next release", 1], ["Pivot 0.2", 1]]);
});

test("the upgrading page lists the breaks of each module's newest minor release and of the next release", () => {
    const expected = new Map();
    let next = 0;
    for (const folder of readdirSync(new URL("modules/", root)).filter((name) => name.startsWith(PREFIX)).sort()) {
        const releases = changelogReleases(read(`modules/${folder}/CHANGELOG.md`));
        next += releases.find((r) => r.release === "Unreleased")?.breaks ?? 0;
        const newest = releases.find((r) => r.release !== "Unreleased");
        if (!newest) continue;
        const minor = newest.release.split(".").slice(0, 2).join(".");
        const breaks = releases.filter((r) => r.release.startsWith(`${minor}.`)).reduce((sum, r) => sum + r.breaks, 0);
        if (breaks) expected.set(`${folder.slice(PREFIX.length)} ${minor}`, breaks);
    }
    if (next) expected.set("In the next release", next);
    const sections = upgradingSections(read("docs/upgrading.md"));
    sections.delete("Older releases");
    assert.deepEqual(Object.fromEntries(sections), Object.fromEntries(expected), "docs/upgrading.md: one section per module whose newest minor release has breaks, one item per break; release PR: docs/development/release.md");
});
