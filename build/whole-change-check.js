// Whole-change check: a pull request that changes docs or code has a "## Whole-change check" section
// with text in its description. There its author says what they read whole and how the change
// reshaped it instead of appending (.github/PULL_REQUEST_TEMPLATE.md). The growth guards (growth.js)
// count lines; a number cannot judge sense, so this asks for the judgement, and the review judges it.
//
// .github/workflows/whole-change-check.yml runs it on every pull request, also when the description
// is edited. It reads everything from environment variables, never from the command line, because
// the description and title are written by whoever opens the pull request:
//
//   PR_BODY, PR_TITLE, PR_AUTHOR   the description, the title and the author's login
//   CHANGED_FILES                  the changed paths, one per line
//
// Exempt are Dependabot's pull requests and release pull requests (docs/development/release.md),
// known by their title: "chore(release): ..." or "chore(<scope>): release ...", the scope optional.
// eizedev/pivotkit has the same check in scripts/whole-change-check.js; both work alike.
import { fileURLToPath } from "node:url";

/** The heading the description needs, without its "## ". */
export const HEADING = "Whole-change check";

/**
 * The paths whose change needs the check: Markdown of the docs site, READMEs and the root, and code:
 * a module's components, functions and .psm1 (some modules keep their functions there), shared/ and build/.
 */
const SCOPE = [/^docs\/.*\.md$/, /(^|\/)README\.md$/, /^[^/]+\.md$/, /^modules\/[^/]+\/(Components|Public|Private)\//, /^modules\/[^/]+\/[^/]+\.psm1$/, /^shared\//, /^build\//];

/**
 * The changed paths that need the check.
 * @param {string[]} files
 */
export const inScope = (files) => files.filter((file) => SCOPE.some((re) => re.test(file)));

/**
 * The text of the description's whole-change check, without HTML comments (the template's prompts),
 * up to the next heading of level 1 or 2; null when the description has no such heading.
 * @param {string | null | undefined} body
 */
export function sectionText(body) {
    // an unclosed comment hides the rest of the description, on GitHub as here
    const lines = String(body ?? "").replace(/<!--[\s\S]*?(?:-->|$)/g, "").split(/\r?\n/);
    const start = lines.findIndex((line) => /^ {0,3}##\s+whole-change check\s*#*\s*$/i.test(line));
    if (start === -1) return null;
    const end = lines.findIndex((line, i) => i > start && /^ {0,3}#{1,2}\s/.test(line));
    return lines.slice(start + 1, end === -1 ? undefined : end).join("\n").trim();
}

/**
 * Why a pull request needs no whole-change check whatever it changes, or null.
 * @param {{ author?: string, title?: string }} pr
 */
export function exemption({ author = "", title = "" }) {
    if (author === "dependabot[bot]") return "a Dependabot pull request";
    if (/^chore(?:\(release\)!?:|(?:\([^)]*\))?!?:\s*release\b)/i.test(title)) return "a release pull request";
    return null;
}

/**
 * The verdict on a pull request, with the text to print.
 * @param {{ body?: string | null, title?: string, author?: string, files: string[] }} pr
 * @returns {{ ok: boolean, message: string }}
 */
export function check({ body, title, author, files }) {
    const exempt = exemption({ author, title });
    if (exempt) return { ok: true, message: `Whole-change check: not needed for ${exempt}.` };
    const touched = inScope(files);
    if (touched.length === 0) return { ok: true, message: "Whole-change check: not needed, no docs or code changed." };
    if (/[\p{L}\p{N}]/u.test(sectionText(body) ?? "")) return { ok: true, message: "Whole-change check: found in the description." };
    const shown = touched.slice(0, 10).join("\n  ") + (touched.length > 10 ? `\n  and ${touched.length - 10} more` : "");
    return {
        ok: false,
        message: [
            `This pull request changes docs or code:\n  ${shown}`,
            `Its description needs a "## ${HEADING}" section with text: what you read whole, and how you`,
            "reshaped it instead of appending. The prompts are in .github/PULL_REQUEST_TEMPLATE.md.",
            "Edit the description; the check runs again.",
        ].join("\n"),
    };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
    const { PR_BODY, PR_TITLE, PR_AUTHOR, CHANGED_FILES = "" } = process.env;
    const files = CHANGED_FILES.split("\n").map((line) => line.trim()).filter(Boolean);
    const { ok, message } = check({ body: PR_BODY, title: PR_TITLE, author: PR_AUTHOR, files });
    (ok ? console.log : console.error)(message);
    process.exitCode = ok ? 0 : 1;
}
