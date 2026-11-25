// The screenshots of the docs and the READMEs: every one is shown somewhere, comes as a light and a dark
// one, and is shown with alt text. On the site each one carries the fragment that shows it in its theme
// only (#only-light, #only-dark); a README shows a pair as a <picture> whose <source> holds the dark one.
// eizedev/pivotkit has the same checks (tests/screenshots.test.js).
//
// The screenshots live in two places: docs/assets/ (the pages and the READMEs show them from there) and
// assets/screenshot-* (the README's quick start and the showcase app; docs/site/Build-Site.ps1 copies
// them into docs/assets/images/ for the site, which is build output and not committed).
import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join, relative, sep } from "node:path";
import { readmes, root, sitePages } from "../../build/docs-files.js";

const IMAGE = /\.(png|webp|jpe?g|gif|svg|avif)$/i;
const posix = (path) => relative(root, path).split(sep).join("/");

/** Every screenshot of the repository, as repository paths. */
const files = [
    // docs/assets/ also holds examples.css, and after a site build site.css, charts/ and images/
    ...readdirSync(join(root, "docs/assets"), { withFileTypes: true }).filter((e) => e.isFile() && IMAGE.test(e.name)).map((e) => `docs/assets/${e.name}`),
    ...readdirSync(join(root, "assets")).filter((name) => name.startsWith("screenshot-")).map((name) => `assets/${name}`),
];

// Single screenshots of the ECharts showcase app (docs/demo.md). Their partners need new screenshots
// from the app on a PowerShell Universal instance: #213. The site shows them without a theme fragment,
// so they stay visible in both themes. Remove an entry when its partner is there; the test fails until then.
const SINGLES = new Set(["assets/screenshot-data-platform-dark.png", "assets/screenshot-ticket-report-dark.png", "assets/screenshot-service-review-light.png"]);

/**
 * The repository path an image address of `page` points to, or null for an image elsewhere (a badge).
 * A page's assets/images/ is the copy of the root's assets/ that Build-Site.ps1 makes.
 * @param {string} page  repository path
 * @param {string} src
 */
function resolve(page, src) {
    if (/^[a-z]+:/i.test(src)) return null;
    const path = posix(join(root, dirname(page), src.split("#")[0]));
    return path.startsWith("docs/assets/images/") ? `assets/${path.slice("docs/assets/images/".length)}` : path;
}

/** The Markdown images of a text: { src, alt, fragment }. */
const markdownImages = (text) => [...text.matchAll(/!\[([^\]]*)\]\(([^)\s#]+)(#[\w-]+)?\)/g)].map((m) => ({ alt: m[1], src: m[2], fragment: m[3] ?? "" }));

/** The <picture> elements of a text: { dark, light, alt } from its <source> srcset and its <img>. */
const pictures = (text) =>
    [...text.matchAll(/<picture>([\s\S]*?)<\/picture>/g)].map((m) => ({
        dark: /<source media="\(prefers-color-scheme: dark\)" srcset="([^"]+)"/.exec(m[1])?.[1] ?? "",
        light: /<img [^>]*src="([^"]+)"/.exec(m[1])?.[1] ?? "",
        alt: /<img [^>]*alt="([^"]*)"/.exec(m[1])?.[1] ?? "",
    }));

const pages = sitePages().map((page) => `docs/${page}`);
/** Every screenshot shown: { file, page, alt, fragment, picture }. */
const shown = [...pages, ...readmes()].flatMap((page) => {
    const text = readFileSync(join(root, page), "utf8");
    const images = markdownImages(text).map((image) => ({ ...image, file: resolve(page, image.src), page }));
    const fromPictures = pictures(text).flatMap(({ dark, light, alt }) => [
        { file: resolve(page, dark), page, alt, fragment: "", picture: "dark" },
        { file: resolve(page, light), page, alt, fragment: "", picture: "light" },
    ]);
    return [...images, ...fromPictures].filter((s) => s.file && /^(docs\/)?assets\//.test(s.file) && IMAGE.test(s.file));
});

/** "light" or "dark" from a screenshot's name, or undefined. */
const themeOf = (file) => /-(light|dark)\.\w+$/.exec(file)?.[1];

test("the screenshot list and the shown screenshots are found", () => {
    assert.ok(files.includes("docs/assets/pivot-weather-light.png") && files.includes("assets/screenshot-quickstart-dark.png"), "known screenshots missing");
    assert.ok(shown.some((s) => s.page === "README.md" && s.picture) && shown.some((s) => s.page === "docs/index.md"), "known shown screenshots missing");
});

test("every screenshot is shown on a page or in a README", () => {
    const used = new Set(shown.map((s) => s.file));
    assert.deepEqual(files.filter((f) => !used.has(f)), [], "show these screenshots or delete them");
});

test("every screenshot comes as a light and a dark one, apart from the listed singles", () => {
    const pairs = new Map();
    for (const f of files) {
        assert.ok(themeOf(f), `${f}: name it <name>-light or <name>-dark`);
        const name = f.replace(/-(light|dark)(\.\w+)$/, "$2");
        pairs.set(name, [...(pairs.get(name) ?? []), f]);
    }
    const unpaired = [...pairs.values()].filter((group) => group.length !== 2).flat();
    assert.deepEqual(unpaired.filter((f) => !SINGLES.has(f)), [], "add the other theme's screenshot");
    assert.deepEqual([...SINGLES].filter((f) => !unpaired.includes(f)), [], "these singles have a partner or are gone: remove them from SINGLES");
});

test("a shown screenshot exists and has alt text; on the site it carries the fragment of its theme", () => {
    const wrong = shown.filter((s) => {
        if (!existsSync(join(root, s.file)) || s.alt.trim() === "") return true;
        if (s.picture) return themeOf(s.file) !== s.picture;
        if (!s.page.startsWith("docs/")) return false;
        return s.fragment !== (SINGLES.has(s.file) ? "" : `#only-${themeOf(s.file)}`);
    });
    assert.deepEqual(wrong.map((s) => `${s.page}: ${s.file}${s.fragment}${s.picture ? ` (<picture> ${s.picture})` : ""}`), []);
});
