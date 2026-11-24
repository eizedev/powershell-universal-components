// The browser tests run in Playwright's container image (.github/workflows/ci.yml): its browsers belong
// to one Playwright version, which must be the version of @playwright/test the tests are run with.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";

const root = new URL("../../", import.meta.url);

test("the Playwright container image matches @playwright/test in package-lock.json", () => {
    const lock = JSON.parse(readFileSync(new URL("package-lock.json", root), "utf8"));
    const locked = lock.packages["node_modules/@playwright/test"].version;
    const ci = readFileSync(new URL(".github/workflows/ci.yml", root), "utf8");
    const images = [...ci.matchAll(/mcr\.microsoft\.com\/playwright:v([0-9][^-@\s]*)(\S*)/g)];
    assert.ok(images.length > 0, "no Playwright image in ci.yml");
    for (const [image, v, rest] of images) {
        assert.equal(v, locked, `ci.yml uses the Playwright image v${v}, package-lock.json has @playwright/test ${locked}: raise both together`);
        // the digest pins the image's content; a new tag needs its own digest
        assert.match(rest, /@sha256:[0-9a-f]{64}$/, `${image}: pin the image's digest (@sha256:...) with its tag`);
    }
});

test("the build job's matrix names every module in modules/", () => {
    const ci = readFileSync(new URL(".github/workflows/ci.yml", root), "utf8");
    const matrix = /^\s+module: \[(.*)\]$/m.exec(ci);
    assert.ok(matrix, "no module matrix in ci.yml");
    const listed = JSON.parse(`[${matrix[1]}]`).sort();
    const folders = readdirSync(new URL("modules/", root), { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name).sort();
    assert.deepEqual(listed, folders, "add the module to the build matrix in ci.yml");
});
