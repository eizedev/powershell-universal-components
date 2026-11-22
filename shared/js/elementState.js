/*
 * Answers Get-UDElement for one component id.
 *
 * Get-UDElement asks the page through PSU's hub: PSU publishes { type: "requestState", requestId,
 * callback } on the topic of the element id, and returns what a subscriber passes to callback in the
 * same call. Without a synchronous answer the hub returns "null" (PSU 2026.2.5 and 2026.3.4, measured).
 * withComponentFeatures of the npm package universal-dashboard 1.1.2 answers later with a POST to
 * /api/internal/component/element/sessionState/<requestId>, which PSU no longer waits for.
 *
 * pubsub is UniversalDashboard (subscribe(topic, fn(topic, data)) returns a token, unsubscribe(token));
 * read returns the state to send. Keep it small: the answer travels back in one hub message, so send
 * what the docs promise, never the rows of the props. Returns the function that ends the subscription.
 */
export function answerStateRequests(pubsub, id, read) {
    if (!id || !pubsub || typeof pubsub.subscribe !== "function") return () => {};
    const token = pubsub.subscribe(id, (_topic, event) => {
        if (event && event.type === "requestState" && typeof event.callback === "function") event.callback(read());
    });
    return () => {
        if (typeof pubsub.unsubscribe === "function") pubsub.unsubscribe(token);
    };
}
