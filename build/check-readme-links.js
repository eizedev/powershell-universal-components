// Checks that every link to the documentation site in the READMEs (the root's and each module's) points
// at a page and heading anchor that exist in a built site. A published module carries its README, so
// these paths and anchors are a contract: a page or heading they name keeps its address. A link counts
// in Markdown, [text](url), and in HTML, href="url". The docs workflow runs it after the site build;
// it uses Node's own modules only, as that job runs no `npm ci`.
//
//   node build/check-readme-links.js site      # the directory `zensical build` wrote
//
// eizedev/pivotkit checks its READMEs the same way (scripts/check-readme-links.js).
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { readmes, root } from "./docs-files.js";

/** The site's address from `site_url` in zensical.toml, without a trailing slash. */
export function siteUrl(dir = root) {
    const url = /^site_url\s*=\s*"([^"]+)"/m.exec(readFileSync(join(dir, "zensical.toml"), "utf8"))?.[1];
    if (!url) throw new Error("check-readme-links: zensical.toml has no site_url");
    return url.replace(/\/$/, "");
}

/**
 * The links to `site` in a README's text, each once.
 * @param {string} text
 * @param {string} site  the site's address, without a trailing slash
 * @returns {string[]}
 */
export function siteLinks(text, site) {
    const escaped = site.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    // the site's address, then a path or an anchor: never a longer host name that starts the same
    const pattern = new RegExp(`\\]\\((${escaped}(?:[/#][^)\\s]*)?)\\)|href="(${escaped}(?:[/#][^"\\s]*)?)"`, "g");
    return [...new Set([...text.matchAll(pattern)].map((m) => m[1] ?? m[2]))];
}

/**
 * What is wrong with a link to the site, read from the built site, or null.
 * @param {string} url
 * @param {string} site
 * @param {string} siteDir  the built site
 * @returns {string | null}
 */
export function linkProblem(url, site, siteDir) {
    const [path, anchor] = url.slice(site.length).split("#");
    const file = join(siteDir, path === "" || path.endsWith("/") ? join(path, "index.html") : path);
    if (!existsSync(file)) return `no page for ${url}`;
    if (anchor && !readFileSync(file, "utf8").includes(`id="${anchor}"`)) return `no anchor for ${url}`;
    return null;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
    const siteDir = process.argv[2];
    if (!siteDir || !existsSync(join(siteDir, "index.html"))) {
        console.error("usage: node build/check-readme-links.js <built site directory>");
        process.exit(2);
    }
    const site = siteUrl();
    let checked = 0;
    const problems = [];
    for (const readme of readmes()) {
        for (const url of siteLinks(readFileSync(join(root, readme), "utf8"), site)) {
            checked++;
            const problem = linkProblem(url, site, siteDir);
            if (problem) problems.push(`${readme}: ${problem}`);
        }
    }
    console.log(`${checked} links to ${site} checked`);
    if (problems.length) {
        console.error(problems.join("\n"));
        process.exit(1);
    }
}
