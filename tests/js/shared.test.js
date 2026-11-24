// Tests for shared/js: column matching and the answer to Get-UDElement. Run: node --test tests/js/
import { test } from "node:test";
import assert from "node:assert/strict";
import { camelCase, resolveColumn, columnsOf } from "../../shared/js/columns.js";

test("camelCase follows Newtonsoft's rules", () => {
    assert.equal(camelCase("Team"), "team");
    assert.equal(camelCase("ID"), "id");
    assert.equal(camelCase("XAxis"), "xAxis");
    assert.equal(camelCase("URLValue"), "urlValue");
    assert.equal(camelCase("leadTime"), "leadTime");
});

test("resolveColumn matches what PSU sent, whatever the user typed", () => {
    const keys = ["team", "leadTime", "id"];
    assert.equal(resolveColumn("Team", keys), "team");
    assert.equal(resolveColumn("LeadTime", keys), "leadTime");
    assert.equal(resolveColumn("ID", keys), "id");
    assert.equal(resolveColumn("missing", keys), undefined);
    assert.equal(resolveColumn("", keys), undefined);
});

test("columnsOf keeps first-seen order across rows", () => {
    assert.deepEqual(columnsOf([{ a: 1 }, { b: 2, a: 3 }, null]), ["a", "b"]);
});

test("pickColumns: only the named columns, case-insensitive; whole row without a list", async () => {
    const { pickColumns } = await import("../../shared/js/columns.js");
    const row = { name: "vm-01", cpu: 4, ramGB: 16, secretNote: "x" };
    assert.deepEqual(pickColumns(row, ["Name", "RAMgb", "missing"]), { name: "vm-01", ramGB: 16 });
    assert.equal(pickColumns(row, undefined), row);
    assert.equal(pickColumns(undefined, ["Name"]), undefined);
});

// Get-UDElement (#158, #159): PSU's hub takes the state only from a synchronous callback on the
// "requestState" message; it returns "null" when nobody answered in the same call
function fakePubsub() {
    const subs = new Map();
    let next = 0;
    return {
        subscribe(topic, fn) {
            const token = `uid_${++next}`;
            subs.set(token, { topic, fn });
            return token;
        },
        unsubscribe(token) {
            subs.delete(token);
        },
        publish(topic, data) {
            for (const { topic: t, fn } of [...subs.values()]) if (t === topic) fn(topic, data);
        },
        get count() {
            return subs.size;
        }
    };
}
function requestState(pubsub, id) {
    let state = "null";
    pubsub.publish(id, { type: "requestState", requestId: "r1", callback: (s) => { state = s; } });
    return JSON.stringify(state);
}

test("answerStateRequests answers Get-UDElement in the same call with the current state", async () => {
    const { answerStateRequests } = await import("../../shared/js/elementState.js");
    const pubsub = fakePubsub();
    let zoom;
    answerStateRequests(pubsub, "chart", () => ({ id: "chart", zoom }));
    assert.equal(requestState(pubsub, "chart"), '{"id":"chart"}');
    zoom = { start: 10, end: 60 };
    assert.equal(requestState(pubsub, "chart"), '{"id":"chart","zoom":{"start":10,"end":60}}');
    // another element's request is not answered
    assert.equal(requestState(pubsub, "other"), '"null"');
});

test("answerStateRequests ignores other messages; its result ends the subscription; no id or pubsub does nothing", async () => {
    const { answerStateRequests } = await import("../../shared/js/elementState.js");
    const pubsub = fakePubsub();
    let reads = 0;
    const stop = answerStateRequests(pubsub, "chart", () => { reads += 1; return {}; });
    pubsub.publish("chart", { type: "setState", state: {} });
    pubsub.publish("chart", { type: "requestState", requestId: "r1" });
    pubsub.publish("chart", undefined);
    assert.equal(reads, 0);
    assert.equal(pubsub.count, 1);
    stop();
    assert.equal(pubsub.count, 0);
    assert.equal(requestState(pubsub, "chart"), '"null"');
    for (const [p, id] of [[pubsub, ""], [pubsub, undefined], [undefined, "chart"], [{}, "chart"]]) {
        const none = answerStateRequests(p, id, () => ({}));
        assert.equal(typeof none, "function");
        none();
    }
    assert.equal(pubsub.count, 0);
});
