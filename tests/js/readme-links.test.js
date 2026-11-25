// build/check-readme-links.js: which links of a README it reads and how it checks them against a built
// site. The docs workflow runs it on the real site (.github/workflows/docs.yml).
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { linkProblem, siteLinks, siteUrl } from "../../build/check-readme-links.js";

const SITE = "https://docs.example.org";

test("siteLinks reads Markdown and HTML links to the site, each once, and no other host", () => {
    const text = [
        `[a](${SITE}/pivot/) and [b](${SITE}/#requirements) and [a again](${SITE}/pivot/)`,
        `<a href="${SITE}/echarts/data/#tables">c</a> and [root](${SITE})`,
        `[other](https://docs.example.org.evil/x) [plain](https://example.org/)`,
    ].join("\n");
    assert.deepEqual(siteLinks(text, SITE), [`${SITE}/pivot/`, `${SITE}/#requirements`, `${SITE}/echarts/data/#tables`, `${SITE}`]);
});

test("linkProblem finds a missing page and a missing anchor in a built site", (t) => {
    const dir = mkdtempSync(join(tmpdir(), "readme-links-"));
    t.after(() => rmSync(dir, { recursive: true, force: true }));
    mkdirSync(join(dir, "pivot"));
    writeFileSync(join(dir, "index.html"), '<h2 id="requirements">Requirements</h2>');
    writeFileSync(join(dir, "pivot/index.html"), "<h1>Pivot</h1>");
    assert.equal(linkProblem(`${SITE}/#requirements`, SITE, dir), null);
    assert.equal(linkProblem(SITE, SITE, dir), null);
    assert.equal(linkProblem(`${SITE}/pivot/`, SITE, dir), null);
    assert.equal(linkProblem(`${SITE}/pivot/#views`, SITE, dir), `no anchor for ${SITE}/pivot/#views`);
    assert.equal(linkProblem(`${SITE}/echarts/`, SITE, dir), `no page for ${SITE}/echarts/`);
});

test("siteUrl is the site_url of zensical.toml without its trailing slash", () => {
    assert.match(siteUrl(), /^https:\/\/[^/]+$/);
});
