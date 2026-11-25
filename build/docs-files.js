// The Markdown files of the documentation, defined once for the growth guards (build/growth.js), the
// docs checks in tests/js/ and the README link check (build/check-readme-links.js): the pages of the
// site, the READMEs, and the files a reader takes as the current state. No imports beyond Node's own:
// the docs workflow runs the link check without `npm ci`.
import { existsSync, readdirSync } from "node:fs";
import { join, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";

/** The repository's root directory. */
export const root = fileURLToPath(new URL("../", import.meta.url));

/** A path relative to `base`, with forward slashes. */
const posix = (base, path) => relative(base, path).split(sep).join("/");

/**
 * The pages of the docs site, relative to docs/ ("pivot/views.md"), sorted. docs/site/ builds the site
 * (exclude_docs in zensical.toml) and holds no pages.
 * @param {string} [dir]  the repository
 * @returns {string[]}
 */
export function sitePages(dir = root) {
    const docs = join(dir, "docs");
    return readdirSync(docs, { recursive: true, withFileTypes: true })
        .filter((entry) => entry.isFile() && entry.name.endsWith(".md"))
        .map((entry) => posix(docs, join(entry.parentPath, entry.name)))
        .filter((page) => !page.startsWith("site/"))
        .sort();
}

/**
 * The READMEs a reader of the repository or a module sees: the root's and each module's, as
 * repository paths.
 * @param {string} [dir]  the repository
 * @returns {string[]}
 */
export function readmes(dir = root) {
    const modules = readdirSync(join(dir, "modules"), { withFileTypes: true })
        .filter((entry) => entry.isDirectory())
        .map((entry) => `modules/${entry.name}/README.md`)
        .sort();
    return ["README.md", ...modules].filter((path) => existsSync(join(dir, path)));
}

/** The guides at the root that describe the repository as it is now. */
const GUIDES = ["CONTRIBUTING.md", "PRODUCT.md", "RELEASING.md", "SECURITY.md", "ACCESSIBILITY.md", "AGENTS.md"];

/**
 * The Markdown a reader takes as the current state, as repository paths: the READMEs, the root's
 * guides and the site's pages outside docs/decisions/. Changelogs and decision records keep history,
 * so they are not here.
 * @param {string} [dir]  the repository
 * @returns {string[]}
 */
export function currentStateDocs(dir = root) {
    return [
        ...readmes(dir),
        ...GUIDES.filter((path) => existsSync(join(dir, path))),
        ...sitePages(dir).filter((page) => !page.startsWith("decisions/")).map((page) => `docs/${page}`),
    ];
}
