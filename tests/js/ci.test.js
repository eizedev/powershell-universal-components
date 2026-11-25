// The GitHub workflows (.github/workflows), read as YAML (tests/js/workflow.js): which jobs run which
// steps in which order, on which events, with which permissions and secrets. A comment, a reordered
// key or another quoting style changes nothing; a step's `run` is text, read line by line.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { GUARD_NAMES } from "../../build/growth.js";
import { commandsOf, stringsOf, workflow, workflowFiles } from "./workflow.js";

const root = new URL("../../", import.meta.url);

/** A job of a workflow; fails when the workflow has none of that name. */
function jobOf(file, name) {
    const job = workflow(file).jobs?.[name];
    assert.ok(job, `${file} has no job ${name}`);
    return job;
}

/** The index of the first step whose `run` has a command that starts with `command`. */
const stepRunning = (steps, command) => steps.findIndex((step) => commandsOf(step).some((line) => line.startsWith(command)));

// The browser tests run in Playwright's container image: its browsers belong to one Playwright
// version, which must be the version of @playwright/test the tests are run with
test("the Playwright container image matches @playwright/test in package-lock.json", () => {
    const lock = JSON.parse(readFileSync(new URL("package-lock.json", root), "utf8"));
    const locked = lock.packages["node_modules/@playwright/test"].version;
    // every mention in any value: a job's container (as an object or a string), a service, a docker run
    const images = workflowFiles().flatMap((file) => stringsOf(workflow(file)).flatMap((text) => text.match(/mcr\.microsoft\.com\/playwright:\S+/g) ?? []));
    assert.ok(images.length > 0, "no job runs in the Playwright image");
    for (const image of images) {
        // the digest pins the image's content; a new tag needs its own digest
        const m = /^mcr\.microsoft\.com\/playwright:v([0-9][^-@\s]*)[^@\s]*@sha256:[0-9a-f]{64}$/.exec(image);
        assert.ok(m, `${image}: pin the image by tag and digest (@sha256:...)`);
        assert.equal(m[1], locked, `a workflow uses the Playwright image v${m[1]}, package-lock.json has @playwright/test ${locked}: raise both together`);
    }
});

test("the build job's matrix names every module in modules/", () => {
    const listed = [...jobOf("ci.yml", "build").strategy.matrix.module].sort();
    const folders = readdirSync(new URL("modules/", root), { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name).sort();
    assert.deepEqual(listed, folders, "add the module to the build matrix in ci.yml");
});

// one step per growth guard, so a failing guard names itself in the run's step list
test("CI runs every growth guard in a step of its own", () => {
    const commands = jobOf("ci.yml", "javascript").steps.map((step) => commandsOf(step));
    for (const name of GUARD_NAMES) {
        assert.ok(commands.some((lines) => lines.length === 1 && lines[0] === `node build/growth.js ${name}`), `ci.yml runs no step "node build/growth.js ${name}"`);
    }
});

// lint, unit tests and audit each have a step of their own after the install, and a failing one does
// not hide the result of the next
test("CI installs without scripts, then lints, tests and audits in steps of their own", () => {
    const steps = jobOf("ci.yml", "javascript").steps;
    const install = stepRunning(steps, "npm ci ");
    assert.ok(install !== -1, "the javascript job does not run npm ci");
    assert.match(commandsOf(steps[install])[0], /\s--ignore-scripts(\s|$)/, "npm ci runs install scripts");
    for (const command of ["npm run lint", "npm test"]) {
        const at = stepRunning(steps, command);
        assert.ok(at > install, `the javascript job does not run ${command} after the install`);
        assert.deepEqual(commandsOf(steps[at]), [command], `${command} has a step of its own`);
    }
    for (const command of ["npm test", "npm audit "]) {
        assert.equal(steps[stepRunning(steps, command)].if, "${{ !cancelled() }}", `the step of ${command} is skipped when an earlier step failed`);
    }
});

// npm audit reads one lock file: the repository's, each module's and the site's are audited, and one
// with findings does not stop the others from being read
test("CI audits every lock file of the repository at level high", () => {
    const steps = jobOf("ci.yml", "javascript").steps;
    const commands = commandsOf(steps[stepRunning(steps, "status=0")]);
    assert.ok(commands.includes("for lock in $(git ls-files '*package-lock.json'); do"), "the audit does not loop over every tracked package-lock.json");
    assert.ok(commands.includes('npm audit --audit-level=high --prefix "$(dirname "$lock")" || status=1'), "the audit is not npm audit --audit-level=high in each lock file's folder");
    assert.equal(commands.at(-1), 'exit "$status"', "the audit step does not fail when one lock file has findings");
});

// a newer push replaces the run of a pull request; a run of main always finishes, because a release
// needs the green run of its tagged commit
test("CI cancels outdated runs of a pull request, never a run of main", () => {
    const ci = workflow("ci.yml");
    // GitHub keeps one waiting run per group and cancels an older waiting one, also without
    // cancel-in-progress: a push to main gets a group of its own, its commit
    assert.equal(ci.concurrency?.group, "ci-${{ github.event_name == 'pull_request' && github.ref || github.sha }}");
    assert.equal(ci.concurrency?.["cancel-in-progress"], true);
    assert.deepEqual(ci.on.push?.branches, ["main"], "ci.yml does not run on a push to main, so a release finds no CI run");
});

// Only a pushed tag publishes. "Run workflow" (workflow_dispatch) runs the checks without publishing
test("the release runs on a pushed module tag or by hand, and publishes only for the tag", () => {
    const release = workflow("release.yml");
    assert.deepEqual(Object.keys(release.on).sort(), ["push", "workflow_dispatch"], "release.yml runs on other events");
    assert.deepEqual(release.on.push, { tags: ["*-v*"] }, "release.yml runs on a push of something other than a module tag");
    assert.deepEqual(Object.keys(release.jobs).sort(), ["prepare", "publish"], "release.yml has other jobs than prepare and publish");
    const publish = jobOf("release.yml", "publish");
    assert.equal(publish.if, "github.event_name == 'push'", "the publish job also runs by hand");
    assert.deepEqual([publish.needs].flat(), ["prepare"], "the publish job does not wait for prepare");
});

// The gallery key lives in the environment psgallery, which asks the maintainers for approval: only
// the publish job runs in it, reads the key and publishes. prepare runs the dependencies and gets no secret
test("only the publish job, behind the psgallery environment, gets the gallery key and publishes", () => {
    const release = workflow("release.yml");
    const publish = jobOf("release.yml", "publish");
    assert.equal(publish.environment, "psgallery", "the publish job does not wait for the psgallery environment");
    assert.equal(jobOf("release.yml", "prepare").environment, undefined, "prepare runs in an environment");
    assert.deepEqual(release.permissions, { contents: "read" }, "release.yml grants more than contents: read to every job");
    const others = Object.fromEntries(Object.entries(release.jobs).filter(([name]) => name !== "publish"));
    // any form: secrets.X, secrets['X'], toJSON(secrets)
    const outside = stringsOf({ ...release, jobs: others }).filter((text) => /\bsecrets\b/.test(text));
    assert.deepEqual(outside, [], "a secret is read outside the publish job");
    assert.deepEqual(stringsOf(publish).filter((text) => /\bsecrets\b/.test(text)), ["${{ secrets.PSGALLERY_API_KEY }}"], "the publish job reads another secret than PSGALLERY_API_KEY, or reads it another way");
    const publishing = (job) => job.steps.flatMap(commandsOf).filter((line) => /Publish-Module\.ps1\b.*\s-Publish\b/.test(line));
    assert.equal(publishing(publish).length, 1, "the publish job does not run Publish-Module.ps1 -Publish once");
    // prepare runs Publish-Module.ps1 only as its check, never another publishing command
    const prepareLines = jobOf("release.yml", "prepare").steps.flatMap(commandsOf);
    assert.deepEqual(publishing(jobOf("release.yml", "prepare")), [], "prepare publishes");
    assert.deepEqual(prepareLines.filter((line) => /\bPublish-(PSResource|Module)\b(?!\.ps1)|\bgh release\b/.test(line)), [], "prepare runs a publishing command");
});

// prepare checks that the tagged commit is on main and that CI passed for it before it installs or runs
// anything of the repository
test("the release needs the tagged commit on main and a green CI run of it, before it installs", () => {
    const prepare = jobOf("release.yml", "prepare");
    const steps = prepare.steps;
    const onMain = stepRunning(steps, 'git merge-base --is-ancestor "$GITHUB_SHA" origin/main');
    const gate = steps.findIndex((step) => commandsOf(step).some((line) => line.includes("actions/workflows/ci.yml/runs?")));
    const install = stepRunning(steps, "npm ci ");
    assert.ok(onMain !== -1, "prepare does not check that the tagged commit is on main");
    assert.ok(gate !== -1, "prepare does not look for the CI run of the tagged commit");
    assert.ok(install !== -1 && onMain < install && gate < install, "prepare installs before both checks");
    const query = commandsOf(steps[gate]).find((line) => line.includes("actions/workflows/ci.yml/runs?"));
    assert.match(query, /[?&]head_sha=\$GITHUB_SHA(&|")/, "the gate accepts a CI run of another commit");
    assert.match(query, /[?&]event=push(&|")/, "the gate accepts a pull request's CI run");
    assert.match(query, /[?&]status=success(&|")/, "the gate accepts a CI run that did not succeed");
    // these commands and no other: a change that weakens the gate needs a review here
    assert.deepEqual(commandsOf(steps[gate]), [
        query,
        'test "$runs" -gt 0 || { echo "::error::no successful CI run for $GITHUB_SHA on main; wait for it, then re-run this workflow."; exit 1; }',
    ]);
    assert.deepEqual(commandsOf(steps[onMain]), ['git merge-base --is-ancestor "$GITHUB_SHA" origin/main || { echo "::error::$GITHUB_SHA is not on main; tag the merge commit on main."; exit 1; }']);
    // nothing makes either check optional: no if, continue-on-error or working-directory
    assert.deepEqual(Object.keys(steps[gate]).sort(), ["env", "name", "run"]);
    assert.deepEqual(Object.keys(steps[onMain]).sort(), ["name", "run"]);
    assert.equal(prepare["continue-on-error"], undefined, "a failed prepare job would not stop the release");
    assert.equal(prepare.if, undefined, "prepare runs only under a condition");
    assert.deepEqual(prepare.permissions, { contents: "read", actions: "read" }, "prepare needs actions: read for the gate, and nothing more");
});

// The READMEs travel with each module: their links into the site are checked against the site the
// docs workflow just built, before it is published
test("the docs workflow checks the README links against the built site, after building it", () => {
    const steps = jobOf("docs.yml", "build").steps;
    const build = steps.findIndex((step) => String(step.uses ?? "").startsWith("eizedev/brand/docs-site@"));
    const check = stepRunning(steps, "node build/check-readme-links.js site");
    assert.ok(build !== -1, "docs.yml builds no site with eizedev/brand/docs-site");
    assert.ok(check > build, "docs.yml checks no README links against the built site after building it");
    const upload = steps.findIndex((step) => String(step.uses ?? "").startsWith("actions/upload-pages-artifact@"));
    assert.ok(check < upload, "docs.yml uploads the site before checking the README links");
});

// The whole-change check (build/whole-change-check.js) runs again when the description is edited,
// reads only, and gets the description, title and author through env: an expression in a `run` would
// put text whoever opens the pull request wrote into the shell script
test("the whole-change check runs on every pull request event that can fix it, reads only, and takes the pull request only through env", () => {
    const check = workflow("whole-change-check.yml");
    assert.deepEqual(Object.keys(check.on), ["pull_request"], "the check runs on another event than pull_request (pull_request_target would hold a write token)");
    assert.deepEqual([...check.on.pull_request.types].sort(), ["edited", "opened", "reopened", "synchronize"]);
    assert.equal(check.on.pull_request.paths ?? check.on.pull_request["paths-ignore"], undefined, "the script decides what needs the check");
    assert.deepEqual(check.on.pull_request.branches, workflow("ci.yml").on.pull_request.branches, "the check runs for other base branches than ci.yml");
    assert.deepEqual(check.permissions, { contents: "read" });
    assert.notEqual(check.concurrency.group, workflow("ci.yml").concurrency.group, "an edit of the description cancels CI");
    const steps = Object.values(check.jobs).flatMap((job) => {
        assert.equal(job.permissions, undefined, "a job of the check asks for more permissions");
        return job.steps;
    });
    for (const step of steps) assert.doesNotMatch(String(step.run ?? ""), /\$\{\{/, `"${step.name ?? step.uses}" has an expression in its run`);
    const run = steps.find((step) => commandsOf(step).includes("node build/whole-change-check.js"));
    assert.ok(run, "no step runs build/whole-change-check.js");
    assert.deepEqual(run.env, {
        PR_BODY: "${{ github.event.pull_request.body }}",
        PR_TITLE: "${{ github.event.pull_request.title }}",
        PR_AUTHOR: "${{ github.event.pull_request.user.login }}",
    });
    assert.ok(commandsOf(run).some((line) => /^CHANGED_FILES="\$\(git -c core\.quotepath=off diff --no-renames --name-only HEAD\^1 HEAD\)"$/.test(line)), "the changed files are not the merge commit's difference to its base");
    const checkout = steps.find((step) => String(step.uses).startsWith("actions/checkout@"));
    assert.equal(checkout.with["persist-credentials"], false);
    assert.equal(checkout.with["fetch-depth"], 2, "without the merge commit's parent there is nothing to compare with");
});
