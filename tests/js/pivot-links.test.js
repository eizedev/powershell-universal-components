// Links into a pivot report: pivotkit's own share format, as create_link writes it, and the outside
// limits (#105, #116). These tests use the pivot module's packages (pivotkit-core, pivotkit-report):
// they run after `npm ci` in modules/PowerShellUniversal.Component.Pivot and are skipped without it
// (CI's unit-test job installs the root only; the pivot module's build job runs this file after
// its npm ci, and the browser job's site spec covers the built bundle).
import { test } from "node:test";
import assert from "node:assert/strict";
import { existsSync } from "node:fs";

const moduleDir = new URL("../../modules/PowerShellUniversal.Component.Pivot/", import.meta.url);
const installed = existsSync(new URL("node_modules/pivotkit-report/package.json", moduleDir));
const skip = installed ? false : "the pivot module's packages are not installed (npm ci in its folder)";

// a link as pivotkit's create_link makes it for a source whose link is the PSU page and whose
// linkKey is the report's -Id
async function createLink({ source = "tickets", key = "tickets", view }) {
    const { OPERATIONS } = await import(new URL("node_modules/pivotkit-report/src/operations.js", moduleDir));
    const { encode } = await import(new URL("node_modules/pivotkit-core/src/index.js", moduleDir));
    const rows = [{ Team: "A", Priority: "P1", Hours: 2 }, { Team: "B", Priority: "P2", Hours: 3 }];
    const env = { data: async (id) => ({ data: encode(rows), name: id }), link: async () => ({ url: "https://psu.example.com/pivot/tickets", key }) };
    const { result } = await OPERATIONS.create_link.run({ source, view, name: "Per team" }, env);
    assert.equal(result.ok, true, JSON.stringify(result.findings));
    return new URL(result.url);
}

test("the site spec's link fixtures are what create_link writes today", { skip }, async () => {
    const { readFileSync } = await import("node:fs");
    const fixtures = JSON.parse(readFileSync(new URL("../browser/fixtures/pivot-links.json", import.meta.url), "utf8"));
    const { OPERATIONS } = await import(new URL("node_modules/pivotkit-report/src/operations.js", moduleDir));
    const { encode } = await import(new URL("node_modules/pivotkit-core/src/index.js", moduleDir));
    const rows = [{ Ticket: 1, Created: "2026-05-01T08:00:00Z", Team: "Network", Priority: "P1", "Lead hours": 3 }];
    const make = async (source, key) => {
        const env = { data: async (id) => ({ data: encode(rows), name: id }), link: async () => ({ url: "http://127.0.0.1:8765/pivot/", key }) };
        return (await OPERATIONS.create_link.run({ source, view: fixtures.view, name: "From a link" }, env)).result.url;
    };
    assert.equal(fixtures.keyed, await make("pivot-datatable", "pivot-datatable"));
    assert.equal(fixtures.bare, await make("pivot-datatable", null));
    assert.equal(fixtures.other, await make("costs", "pivot-datatable"));
});

test("readStartLink: a create_link link with linkKey = -Id opens its view; one for other data does not", { skip }, async () => {
    const { readStartLink } = await import(new URL("Components/links.js", moduleDir));
    const view = { version: 2, rows: ["Team"], cols: ["Priority"], values: [{ field: "Hours", agg: "sum" }] };
    const url = await createLink({ view });
    assert.match(url.hash, /^#pivot-tickets=1\./);
    const read = readStartLink(url.hash, "tickets", "tickets");
    assert.deepEqual(read.view.rows, ["Team"]);
    assert.deepEqual(read.view.cols, ["Priority"]);
    assert.equal(read.bare, false);
    // the report of other data on the same page leaves it alone (and says so in the console)
    const warn = console.warn;
    const said = [];
    console.warn = (...a) => said.push(a.join(" "));
    try {
        assert.equal(readStartLink(url.hash, "tickets", "costs"), undefined);
    } finally {
        console.warn = warn;
    }
    assert.match(said.join("\n"), /made for other data \("tickets", this report shows "costs"\)/);
    // another report's key: not this report's link
    assert.equal(readStartLink(url.hash, "other", "tickets"), undefined);
});

test("readStartLink: a link without linkKey (#pivot=) is taken by the report of its data, marked bare", { skip }, async () => {
    const { readStartLink } = await import(new URL("Components/links.js", moduleDir));
    const url = await createLink({ key: null, view: { rows: ["Priority"] } });
    assert.match(url.hash, /^#pivot=1\./);
    const read = readStartLink(url.hash, "tickets", "tickets");
    assert.equal(read.bare, true);
    assert.deepEqual(read.view.rows, ["Priority"]);
});

test("readStartLink: the report's own entry first; pivotkit's outside limits for both forms (#105)", { skip }, async () => {
    const { readStartLink } = await import(new URL("Components/links.js", moduleDir));
    const { writeLinkView } = await import(new URL("Components/prepare.js", moduleDir));
    const { encodeViewLink, toViewFile } = await import(new URL("node_modules/pivotkit-core/src/link.js", moduleDir)).then(async (link) => ({ ...link, ...(await import(new URL("node_modules/pivotkit-core/src/index.js", moduleDir))) }));
    const filters = Array.from({ length: 60 }, (_, i) => ({ field: "Team", type: "text", op: "contains", value: `t${i}` }));
    // the module's own form, 60 filters: 50 kept
    const own = readStartLink(writeLinkView("", "tickets", { version: 2, rows: ["Team"], filters }), "tickets", "tickets");
    assert.equal(own.view.filters.length, 50);
    // pivotkit's form, 60 filters: 50 kept
    const text = encodeViewLink(toViewFile({ version: 2, rows: ["Team"], filters }, { source: { id: "tickets" } }, { link: true }));
    const shared = readStartLink(`#pivot-tickets=${text}`, "tickets", "tickets");
    assert.equal(shared.view.filters.length, 50);
    // a damaged pivotkit link opens nothing
    const warn = console.warn;
    console.warn = () => {};
    try {
        assert.equal(readStartLink("#pivot-tickets=1.AAAA", "tickets", "tickets"), undefined);
    } finally {
        console.warn = warn;
    }
});

test("readStartLink: the tab's own entry (the view its sessionStorage keeps) keeps the app's limits after a reload or a remount", { skip }, async () => {
    const { readStartLink } = await import(new URL("Components/links.js", moduleDir));
    const { writeLinkView, readStoredView, writeStoredView } = await import(new URL("Components/prepare.js", moduleDir));
    const filters = Array.from({ length: 60 }, (_, i) => ({ field: "Team", type: "text", op: "contains", value: `t${i}` }));
    const view = { version: 2, rows: ["Team"], filters };
    // the tab wrote its view to sessionStorage and the address bar before PSU mounted the report anew
    const items = new Map();
    const storage = { getItem: (k) => (items.has(k) ? items.get(k) : null), setItem: (k, v) => items.set(k, String(v)), removeItem: (k) => items.delete(k) };
    const serverKey = JSON.stringify({ rows: ["Team"] });
    assert.equal(writeStoredView(storage, "/pivot/#tickets", serverKey, view), true);
    const hash = writeLinkView("", "tickets", view);
    const stored = readStoredView(storage, "/pivot/#tickets", serverKey);
    assert.equal(readStartLink(hash, "tickets", "tickets", stored).view.filters.length, 60);
    // the same entry in another tab (a copied address, no stored view): outside input, 50 kept
    assert.equal(readStartLink(hash, "tickets", "tickets", undefined).view.filters.length, 50);
    // a stored view that is not the one in the address: the address is a shared link
    assert.equal(readStartLink(hash, "tickets", "tickets", { rows: ["Team"] }).view.filters.length, 50);
});
