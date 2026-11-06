// Tests for the Perspective module's pure helpers. Run: node --test "tests/js/*.test.js"
import { test } from "node:test";
import assert from "node:assert/strict";

const mod = await import("../../modules/PowerShellUniversal.Component.Perspective/Components/prepare.js");

test("prepareRows: original column names, types for every column, dates as dates", () => {
    const rows = [
        { id: 1, created: "2026-11-06T18:00:00.0000000+01:00", day: "2026-11-06", team: "Network", ok: true, lead: 1.5 },
        { id: 2, created: "2026-11-05T09:30:00.0000000+01:00", day: "2026-11-05", team: "Server", ok: false, lead: 3 }
    ];
    const p = mod.prepareRows(rows, ["Id", "Created", "Day", "Team", "OK", "Lead"]);
    assert.deepEqual(p.columns, ["Id", "Created", "Day", "Team", "OK", "Lead"]);
    assert.deepEqual(p.schema, { Id: "integer", Created: "datetime", Day: "date", Team: "string", OK: "boolean", Lead: "float" });
    assert.equal(p.rows[0].Created, Date.parse("2026-11-06T18:00:00.0000000+01:00"));
    assert.equal(p.rows[0].Day, Date.UTC(2026, 10, 6));
});

test("viewerConfig: names resolved, sort and filter parsed, -Config wins", () => {
    const keys = ["Team", "Priority", "Id"];
    const c = mod.viewerConfig({ groupBy: ["team"], splitBy: "PRIORITY", sort: ["id desc"], filter: ["team == Network", "Id > 5"], aggregates: { id: "count" }, config: { plugin: "Y Bar" } }, keys, "dark");
    assert.deepEqual(c.group_by, ["Team"]);
    assert.deepEqual(c.split_by, ["Priority"]);
    assert.deepEqual(c.sort, [["Id", "desc"]]);
    assert.deepEqual(c.filter, [["Team", "==", "Network"], ["Id", ">", 5]]);
    assert.deepEqual(c.aggregates, { Id: "count" });
    assert.equal(c.theme, "Pro Dark");
    assert.equal(c.plugin, "Y Bar");
});
