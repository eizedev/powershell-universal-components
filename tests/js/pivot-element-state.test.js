// Get-UDElement for the pivot report (#158): PSU's hub takes the state only from a synchronous
// callback on the "requestState" message, never from a later answer.
import { test } from "node:test";
import assert from "node:assert/strict";
import { answerStateRequests } from "../../modules/PowerShellUniversal.Component.Pivot/Components/elementState.js";

// the part of PSU's pubsub (UniversalDashboard.subscribe/unsubscribe/publish) the module uses
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

// what PSU's hub does for Get-UDElement: "null" unless a subscriber answered in the same call
function requestState(pubsub, id) {
    let state = "null";
    pubsub.publish(id, { type: "requestState", requestId: "r1", callback: (s) => { state = s; } });
    return JSON.stringify(state);
}

test("answerStateRequests: Get-UDElement gets the current state in the same call", () => {
    const pubsub = fakePubsub();
    let view = { rows: ["Team"] };
    answerStateRequests(pubsub, "tickets", () => ({ id: "tickets", view }));
    assert.equal(requestState(pubsub, "tickets"), '{"id":"tickets","view":{"rows":["Team"]}}');
    view = { rows: ["Priority"] };
    assert.equal(requestState(pubsub, "tickets"), '{"id":"tickets","view":{"rows":["Priority"]}}');
    // another element's request is not answered by this report
    assert.equal(requestState(pubsub, "other"), '"null"');
});

test("answerStateRequests: other messages and a request without a callback are ignored", () => {
    const pubsub = fakePubsub();
    let reads = 0;
    answerStateRequests(pubsub, "tickets", () => { reads += 1; return {}; });
    pubsub.publish("tickets", { type: "setState", state: { view: {} } });
    pubsub.publish("tickets", { type: "requestState", requestId: "r1" });
    pubsub.publish("tickets", undefined);
    assert.equal(reads, 0);
});

test("answerStateRequests: the returned function ends the subscription; no id or no pubsub does nothing", () => {
    const pubsub = fakePubsub();
    const stop = answerStateRequests(pubsub, "tickets", () => ({ view: {} }));
    assert.equal(pubsub.count, 1);
    stop();
    assert.equal(pubsub.count, 0);
    assert.equal(requestState(pubsub, "tickets"), '"null"');
    for (const [p, id] of [[pubsub, ""], [pubsub, undefined], [undefined, "tickets"], [{}, "tickets"]]) {
        const none = answerStateRequests(p, id, () => ({}));
        assert.equal(typeof none, "function");
        none();
    }
    assert.equal(pubsub.count, 0);
});
