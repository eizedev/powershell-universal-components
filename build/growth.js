// Growth guards: code, tests and docs may not grow by appending. Four checks:
//
//   powershell   code lines per .ps1/.psm1 file and per function (build/Measure-PowerShellSize.ps1)
//   javascript   ESLint's max-lines-per-function and complexity over modules/*/Components and shared/js
//   duplication  copied JavaScript in the same folders (jscpd, a fixed threshold in .jscpd.json)
//   docs         lines per docs page and README, by kind of page, and the size of all of them together
//
//   node build/growth.js [guard...]                    check (all four without a name)
//   node build/growth.js --update                      lower the baseline to what is measured now
//   node build/growth.js --update --accept-growth      write the baseline even where it grew
//
// powershell, javascript and docs are ratchets: the offenders of the day they came in are in
// build/growth-baseline.json with their numbers. A check fails when an offender grows or a new one
// appears. It also fails when an offender shrank or went: the baseline must follow in the same pull
// request (--update), or the room it left could be filled again unseen. --update never raises an
// entry by itself. Raising one is --accept-growth, and the pull request says why.
// eizedev/pivotkit has the same guards in scripts/growth.js; both work alike.
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { basename, join, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { LANGUAGE_OPTIONS, SOURCES } from "../eslint.config.js";

const root = fileURLToPath(new URL("../", import.meta.url));
const BASELINE = new URL("growth-baseline.json", import.meta.url);
const UPDATE = "node build/growth.js --update";

/** The baseline before the first one is written: everything found counts as grown. */
const EMPTY = Object.freeze({ powershell: { files: {}, functions: {} }, javascript: { lines: {}, complexity: {} }, docs: { pages: {}, totalLines: 0 } });

/**
 * The limits for PowerShell, in code lines: lines with code, so blank lines and comment-based help
 * cost nothing. PSScriptAnalyzer has no rule for the length of a file or a function, and there is no
 * common number for PowerShell; ESLint's default for a function is 50 lines. A ratchet starts where
 * the outliers begin: the four longest functions are above 100, the next one has 93. A module keeps one
 * function per file (AGENTS.md, "Small units"), so 300 lines leaves room for any of them; the
 * files above it are the monolithic module file, the test files and the app scripts.
 */
export const POWERSHELL_LIMITS = Object.freeze({ file: 300, function: 100 });

/**
 * The limits for a JavaScript function, as eizedev/pivotkit has them. ESLint's defaults are 50 lines
 * and a complexity of 20; these name the outliers, not half of the code. Blank lines and comments do
 * not count: the why-comments this repository asks for should cost nothing.
 */
export const FUNCTION_LIMITS = Object.freeze({ lines: 120, complexity: 25 });

/**
 * The most lines a page of each kind may have. An overview (index.md) leads to the topic pages; a
 * topic page explains one topic, its examples included from generated files; a reference page
 * includes the generated parameter tables; a README says what a module is, how to install it and
 * links to the pages (AGENTS.md).
 */
export const DOCS_LIMITS = Object.freeze({ overview: 150, topic: 200, reference: 100, readme: 80 });

/** How far the lines of all pages together may drift from the baseline, in percent, before it is updated. */
export const DOCS_TOTAL_MARGIN = 2;

/** What to do when a guard fails, said once per guard. */
const ADVICE = {
    powershell: `Split the function into smaller ones, one job each, and the file into one file per function (AGENTS.md, "Small units"). Limits: ${POWERSHELL_LIMITS.function} code lines per function, ${POWERSHELL_LIMITS.file} per file; blank lines and comments do not count.`,
    javascript: `Split the function into smaller ones, one job each (AGENTS.md, "Small units"). Limits: ${FUNCTION_LIMITS.lines} lines without blank lines and comments, complexity ${FUNCTION_LIMITS.complexity}.`,
    duplication: "Move the copied code into one function or module that both places import (AGENTS.md, \"One place per fact\"; shared/js once a second module needs it). The threshold is in .jscpd.json.",
    docs: "Shorten the page, or split it into pages with one topic each; rewrite instead of appending (AGENTS.md, \"Shape what exists\"). When all pages together grew, make room in the pages the change touches.",
};

/** The way out when the growth is right, said under every guard that grew. */
const ACCEPT = `If the growth is right, raise the baseline with ${UPDATE} --accept-growth and say why in the pull request.`;

const posix = (path, base = root) => relative(base, path).split(sep).join("/");

/**
 * Adds `value` to the list under `key`, kept in descending order. Several functions under one key
 * (anonymous functions of a file, PowerShell functions of one name) compare as a sorted list.
 * @param {Record<string, number[]>} map
 * @param {string} key
 * @param {number} value
 */
function addSorted(map, key, value) {
    (map[key] ??= []).push(value);
    map[key].sort((a, b) => b - a);
}

/**
 * The PowerShell files and functions over POWERSHELL_LIMITS. A function is keyed by its name alone,
 * so moving it into a file of its own (Public/, Private/) keeps its entry.
 * @param {{ files: { path: string, lines: number }[], functions: { path: string, name: string, lines: number }[] }} measured
 * @returns {{ files: Record<string, number[]>, functions: Record<string, number[]> }}
 */
export function powershellOffenders(measured) {
    if (!Array.isArray(measured?.files) || !Array.isArray(measured?.functions)) throw new Error("growth: Measure-PowerShellSize.ps1 returned no files and functions");
    const found = { files: {}, functions: {} };
    for (const { path, lines } of measured.files) if (lines > POWERSHELL_LIMITS.file) addSorted(found.files, path, lines);
    for (const { name, lines } of measured.functions) if (lines > POWERSHELL_LIMITS.function) addSorted(found.functions, name, lines);
    return found;
}

/**
 * Measures the repository's PowerShell with build/Measure-PowerShellSize.ps1 (needs pwsh).
 * @param {string} [cwd]
 */
export function measurePowerShell(cwd = root) {
    const script = join(root, "build", "Measure-PowerShellSize.ps1");
    const result = spawnSync("pwsh", ["-NoProfile", "-NonInteractive", "-File", script, "-Path", cwd], { encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
    if (result.error) throw new Error(`growth: pwsh could not start (${result.error.message}); the powershell guard needs PowerShell 7.4+`);
    if (result.status !== 0) throw new Error(`growth: Measure-PowerShellSize.ps1 failed (${result.status}):\n${result.stderr || result.stdout}`);
    return powershellOffenders(JSON.parse(result.stdout));
}

/**
 * The name and number of an ESLint message of max-lines-per-function or complexity, as
 * "Arrow function 'onClick'" and 140. Throws on any other wording: a guard that reads nothing
 * must not report nothing.
 * @param {{ ruleId: string | null, message: string }} message
 * @returns {{ metric: "lines" | "complexity", name: string, value: number }}
 */
export function parseFunctionMessage({ ruleId, message }) {
    const pattern = ruleId === "max-lines-per-function" ? /^(.+) has too many lines \((\d+)\)\./ : ruleId === "complexity" ? /^(.+) has a complexity of (\d+)\./ : null;
    const match = pattern?.exec(message);
    if (!match) throw new Error(`growth: unexpected ESLint message (${ruleId}): ${message}`);
    return { metric: ruleId === "complexity" ? "complexity" : "lines", name: match[1], value: Number(match[2]) };
}

/**
 * The JavaScript functions over FUNCTION_LIMITS, as "Function 'name'" (or "<file> Arrow function" for
 * an anonymous one) -> numbers per metric. ESLint
 * runs with these two rules only and ignores eslint-disable comments, so a comment cannot hide a
 * function from the guard. It reads SOURCES with LANGUAGE_OPTIONS of eslint.config.js (`npm run lint`),
 * but not that file's rules; .jscpd.json names the same folders.
 * @param {string} [cwd]
 * @returns {Promise<{ lines: Record<string, number[]>, complexity: Record<string, number[]> }>}
 */
export async function measureJavaScript(cwd = root) {
    const { ESLint } = await import("eslint");
    const rules = {
        "max-lines-per-function": ["error", { max: FUNCTION_LIMITS.lines, skipBlankLines: true, skipComments: true }],
        complexity: ["error", { max: FUNCTION_LIMITS.complexity }],
    };
    const eslint = new ESLint({ cwd, overrideConfigFile: true, allowInlineConfig: false, overrideConfig: { files: ["**/*.{js,jsx}"], languageOptions: LANGUAGE_OPTIONS, rules } });
    const results = await eslint.lintFiles([...SOURCES]);
    const found = { lines: {}, complexity: {} };
    for (const result of results) {
        for (const message of result.messages) {
            if (message.fatal) throw new Error(`growth: ${posix(result.filePath, cwd)}: ${message.message}`);
            const { metric, name, value } = parseFunctionMessage(message);
            // a named function by its name alone, so moving it into another file keeps its entry;
            // an anonymous one by its file
            addSorted(found[metric], /'.+'/.test(name) ? name : `${posix(result.filePath, cwd)} ${name}`, value);
        }
    }
    return found;
}

/**
 * The kind of a page, by its name: README.md, index.md and reference.md, every other page a topic.
 * @param {string} page  repository path
 */
export function docsKind(page) {
    const name = basename(page);
    if (name === "README.md") return "readme";
    if (name === "index.md") return "overview";
    if (name === "reference.md") return "reference";
    return "topic";
}

/** Counts the lines of a text, a last line without a line break included. */
const lineCount = (text) => text.split("\n").length - (text.endsWith("\n") ? 1 : 0);

/**
 * Lines of every docs page (docs/**\/*.md without docs/site/, which builds the site) and every README
 * (the repository's and each module's), as repository path -> lines.
 * @param {string} [dir]  the repository
 * @returns {Record<string, number>}
 */
export function docsPages(dir = root) {
    const pages = {};
    const add = (path) => {
        if (existsSync(join(dir, path))) pages[path] = lineCount(readFileSync(join(dir, path), "utf8"));
    };
    for (const entry of readdirSync(join(dir, "docs"), { recursive: true, withFileTypes: true })) {
        if (!entry.isFile() || !entry.name.endsWith(".md")) continue;
        const path = posix(join(entry.parentPath, entry.name), dir);
        if (!path.startsWith("docs/site/")) add(path);
    }
    add("README.md");
    for (const module of readdirSync(join(dir, "modules"), { withFileTypes: true })) if (module.isDirectory()) add(`modules/${module.name}/README.md`);
    return pages;
}

/**
 * The pages over the limit of their kind and the lines of all pages together.
 * @param {Record<string, number>} pages
 * @returns {{ pages: Record<string, number[]>, totalLines: number }}
 */
export function measureDocs(pages = docsPages()) {
    const over = {};
    let totalLines = 0;
    for (const [page, lines] of Object.entries(pages)) {
        totalLines += lines;
        if (lines > DOCS_LIMITS[docsKind(page)]) over[page] = [lines];
    }
    return { pages: over, totalLines };
}

/**
 * Compares numbers per key with the baseline's. Returns what grew or is new, and what shrank or
 * went (the baseline is then stale). Under one key each number is matched to the smallest baseline
 * number that still covers it, so a new offender between two old ones counts once and the old ones
 * stay matched.
 * @param {Record<string, number[]>} baseline
 * @param {Record<string, number[]>} current
 * @param {string} unit  e.g. "lines"
 * @returns {{ grew: string[], stale: string[] }}
 */
export function compareCounts(baseline, current, unit) {
    const grew = [];
    const stale = [];
    for (const key of new Set([...Object.keys(baseline), ...Object.keys(current)])) {
        const was = [...(baseline[key] ?? [])].sort((a, b) => a - b);
        const unmatched = [];
        for (const value of [...(current[key] ?? [])].sort((a, b) => b - a)) {
            const fit = was.findIndex((w) => w >= value);
            if (fit === -1) {
                unmatched.push(value);
                continue;
            }
            const [old] = was.splice(fit, 1);
            if (old > value) stale.push(`${key}: ${value} ${unit}, baseline ${old}`);
        }
        // what is left on both sides: an old offender that grew, a new one, or one that went
        was.reverse();
        unmatched.forEach((value, i) => grew.push(i < was.length ? `${key}: ${value} ${unit}, baseline ${was[i]}` : `${key}: ${value} ${unit}, new`));
        for (const old of was.slice(unmatched.length)) stale.push(`${key}: ${old} ${unit} in the baseline, now within the limit`);
    }
    return { grew, stale };
}

/**
 * Compares the lines of all pages with the baseline's, within DOCS_TOTAL_MARGIN.
 * @param {number} baseline
 * @param {number} current
 */
export function compareTotal(baseline, current) {
    const margin = (baseline * DOCS_TOTAL_MARGIN) / 100;
    const text = `all docs pages and READMEs: ${current} lines, baseline ${baseline} (margin ${DOCS_TOTAL_MARGIN} %)`;
    if (current > baseline + margin) return { grew: [text], stale: [] };
    if (current < baseline - margin) return { grew: [], stale: [text] };
    return { grew: [], stale: [] };
}

/** The duplication check: jscpd with .jscpd.json, which fails above its threshold. */
function checkDuplication(dir = root) {
    const result = spawnSync(process.execPath, [join(root, "node_modules", "jscpd", "run-jscpd.js"), "--no-colors"], { cwd: dir, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
    if (result.error) throw result.error;
    if (result.status === 0) return { grew: [], stale: [] };
    const reason = /ERROR: .*/.exec(result.stdout + result.stderr)?.[0];
    if (!reason) throw new Error(`growth: jscpd failed (${result.status}):\n${result.stderr || result.stdout}`);
    // the console reporter has listed each clone above the error
    return { grew: [`${result.stdout.trim()}\n${reason}`], stale: [] };
}

function merge(...results) {
    return { grew: results.flatMap((r) => r.grew), stale: results.flatMap((r) => r.stale) };
}

/** Each guard: what it measures now (for the baseline) and how that compares. */
const GUARDS = {
    powershell: {
        measure: async (dir) => ({ powershell: measurePowerShell(dir) }),
        compare: (base, now) => merge(compareCounts(base.powershell.files, now.powershell.files, "code lines"), compareCounts(base.powershell.functions, now.powershell.functions, "code lines")),
    },
    javascript: {
        measure: async (dir) => ({ javascript: await measureJavaScript(dir) }),
        compare: (base, now) => merge(compareCounts(base.javascript.lines, now.javascript.lines, "lines"), compareCounts(base.javascript.complexity, now.javascript.complexity, "complexity")),
    },
    duplication: {
        // no baseline: its threshold is in .jscpd.json, and --accept-growth does not raise it
        fixed: true,
        measure: async () => ({}),
        compare: (base, now, dir) => checkDuplication(dir),
    },
    docs: {
        measure: async (dir) => ({ docs: measureDocs(docsPages(dir)) }),
        compare: (base, now) => merge(compareCounts(base.docs.pages, now.docs.pages, "lines"), compareTotal(base.docs.totalLines, now.docs.totalLines)),
    },
};

/** The guards' names, as CI's steps and the command line call them. */
export const GUARD_NAMES = Object.freeze(Object.keys(GUARDS));

/**
 * The baseline as JSON with one entry per line, sorted, so a pull request's diff shows each change
 * on its own line and two pull requests rarely touch the same one.
 * @param {object} baseline
 */
export function formatBaseline(baseline) {
    const sortKeys = (value) => (Array.isArray(value) || typeof value !== "object" || value === null ? value : Object.fromEntries(Object.keys(value).sort().map((k) => [k, sortKeys(value[k])])));
    return `${JSON.stringify(sortKeys(baseline), null, 4).replace(/\[\s+([\d,\s]+?)\s+\]/g, (_, numbers) => `[${numbers.split(/,\s*/).join(", ")}]`)}\n`;
}

/**
 * Runs the guards named in argv (all without a name) and sets process.exitCode.
 * @param {string[]} argv  guard names, --update, --accept-growth
 * @param {{ dir?: string, baselineFile?: string }} [options]  the repository and the baseline (tests)
 */
export async function main(argv, { dir = root, baselineFile = fileURLToPath(BASELINE) } = {}) {
    const update = argv.includes("--update");
    const acceptGrowth = argv.includes("--accept-growth");
    const names = argv.filter((a) => !a.startsWith("--"));
    for (const name of names) if (!(name in GUARDS)) throw new Error(`growth: no guard "${name}"; the guards are ${GUARD_NAMES.join(", ")}`);
    const chosen = names.length > 0 ? names : GUARD_NAMES;
    const baseline = { ...EMPTY, ...(existsSync(baselineFile) ? JSON.parse(readFileSync(baselineFile, "utf8")) : {}) };
    const next = { ...baseline };
    let failed = false;
    for (const name of chosen) {
        const now = await GUARDS[name].measure(dir);
        const { grew, stale } = GUARDS[name].compare(baseline, now, dir);
        Object.assign(next, now);
        if (grew.length > 0) {
            if (!(update && acceptGrowth) || GUARDS[name].fixed) failed = true;
            console.error(`\n${name}: grew\n  ${grew.join("\n  ")}\n${ADVICE[name]}${GUARDS[name].fixed ? "" : `\n${ACCEPT}`}`);
        }
        if (stale.length > 0 && !update) {
            failed = true;
            console.error(`\n${name}: smaller than the baseline\n  ${stale.join("\n  ")}\nLower the baseline in this pull request: ${UPDATE}`);
        }
        if (grew.length === 0 && stale.length === 0) console.log(`${name}: ok`);
    }
    if (update && !failed) {
        writeFileSync(baselineFile, formatBaseline(next));
        console.log(`wrote ${posix(baselineFile)}`);
    } else if (update) {
        console.error(`\nThe baseline was not written: something grew. Fix that, or raise the baseline with ${UPDATE} --accept-growth and say why in the pull request.`);
    }
    process.exitCode = failed ? 1 : 0;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) await main(process.argv.slice(2));
