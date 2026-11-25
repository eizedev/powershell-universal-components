// The decision records in docs/decisions/ (build/decisions.js): every record passes the rules, and
// the committed index is what the script builds (run `node build/decisions.js` after a change).
import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { REPOSITORY, STATUSES, checkRecords, indexText, parseRecords, readRecords } from "../../build/decisions.js";

const INDEX = new URL("../../docs/decisions/index.md", import.meta.url);
const ISSUE = `${REPOSITORY}/issues/1`;

/** A record's text with the given front matter fields and heading. */
const record = ({ title = "A decision", status = "accepted", date = "2026-11-25", extra = "", heading = `# 0001 ${title}`, body = `Source: [#1](${ISSUE})` } = {}) =>
    `---\ntitle: ${title}\ndescription: What it decides.\nstatus: ${status}\ndate: ${date}\n${extra}---\n\n${heading}\n\n${body}\n`;

test("every decision record passes the rules", () => {
    const records = parseRecords(readRecords());
    assert.ok(records.length > 0, "docs/decisions/ holds no record");
    assert.deepEqual(checkRecords(records), []);
});

test("the committed index is what build/decisions.js builds", () => {
    assert.ok(existsSync(INDEX), "docs/decisions/index.md is missing: node build/decisions.js");
    assert.equal(readFileSync(INDEX, "utf8"), indexText(parseRecords(readRecords())), "docs/decisions/index.md is stale: node build/decisions.js");
});

test("the index lists every record with its link and status", () => {
    const records = parseRecords(readRecords());
    const index = indexText(records);
    for (const r of records) assert.match(index, new RegExp(`\\| \\[${r.file.slice(0, 4)}\\]\\(${r.file}\\) \\| .+ \\| ${r.status} \\| ${r.date} \\|`));
});

test("a gap or a repeat in the numbers is refused", () => {
    const gap = parseRecords({ "0001-a.md": record(), "0003-c.md": record({ heading: "# 0003 A decision" }) });
    assert.deepEqual(checkRecords(gap), ["0003-c.md: expected number 0002; numbers start at 0001 and leave no gap"]);
    const twice = parseRecords({ "0001-a.md": record(), "0001-b.md": record() });
    assert.match(checkRecords(twice).join("\n"), /0001-b\.md: expected number 0002/);
});

test("a bad name, status, date, heading or missing source link is refused", () => {
    assert.match(checkRecords(parseRecords({ "1-a.md": record() })).join("\n"), /1-a\.md: name it NNNN-<slug>\.md/);
    assert.match(checkRecords(parseRecords({ "0001-a.md": record({ status: "done" }) })).join("\n"), /status "done" is none of accepted, proposed, superseded/);
    assert.match(checkRecords(parseRecords({ "0001-a.md": record({ date: "25.11.2026" }) })).join("\n"), /date "25\.11\.2026" is not YYYY-MM-DD/);
    assert.match(checkRecords(parseRecords({ "0001-a.md": record({ heading: "# Another title" }) })).join("\n"), /the heading is "Another title", expected "# 0001 A decision"/);
    assert.match(checkRecords(parseRecords({ "0001-a.md": record({ body: "No link." }) })).join("\n"), /links no issue or pull request/);
    // a link into another repository is no source of this one
    assert.match(checkRecords(parseRecords({ "0001-a.md": record({ body: "[#1](https://github.com/eizedev/pivotkit/issues/1)" }) })).join("\n"), /links no issue or pull request/);
    assert.match(checkRecords(parseRecords({ "0001-a.md": "# 0001 No front matter\n" })).join("\n"), /the front matter has no title/);
});

test("a superseded record and its successor link each other", () => {
    const old = (body) => record({ status: "superseded", extra: "superseded_by: 0002-b.md\n", body: `Source: [#1](${ISSUE}). ${body}` });
    const next = (body) => record({ heading: "# 0002 A decision", body: `Source: [#1](${ISSUE}). ${body}` });
    assert.deepEqual(checkRecords(parseRecords({ "0001-a.md": old("[0002](0002-b.md)"), "0002-b.md": next("[0001](0001-a.md)") })), []);
    assert.deepEqual(checkRecords(parseRecords({ "0001-a.md": old(""), "0002-b.md": next("") })), [
        "0001-a.md: superseded by 0002-b.md, but does not link it",
        "0002-b.md: supersedes 0001-a.md, but does not link it",
    ]);
    assert.match(checkRecords(parseRecords({ "0001-a.md": record({ status: "superseded" }) })).join("\n"), /superseded_by names no record/);
    assert.match(checkRecords(parseRecords({ "0001-a.md": record({ extra: "superseded_by: 0002-b.md\n" }) })).join("\n"), /superseded_by is set, but the status is "accepted"/);
});

test("record 0001 and the index give each status the same meaning", () => {
    const rules = readFileSync(new URL("../../docs/decisions/0001-record-decisions.md", import.meta.url), "utf8");
    const index = readFileSync(INDEX, "utf8");
    for (const [status, meaning] of Object.entries(STATUSES)) {
        assert.match(rules, new RegExp(`^\\| ${status} \\| ${meaning}\\b`, "m"), `0001 does not give ${status} the meaning "${meaning}"`);
        assert.match(index, new RegExp(`^- \\*\\*${status}\\*\\*: ${meaning}$`, "m"), `the index does not give ${status} the meaning "${meaning}"`);
    }
});
