import { useInsertionEffect, useRef } from "react";

/*
 * A ref that holds the latest value, for event handlers and callbacks registered once (a chart's or a
 * viewer's listeners, pivotkit's callbacks). React 18 has no useEffectEvent, and a ref must not be
 * written during render (react.dev/reference/react/useRef). The insertion effect runs before every
 * layout and passive effect of the commit, also the children's, so a callback a child fires from its
 * own layout effect already reads the new value.
 */
export function useLatest(value) {
    const ref = useRef(value);
    useInsertionEffect(() => {
        ref.current = value;
    });
    return ref;
}
