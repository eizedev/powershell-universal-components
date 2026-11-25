import { useCallback, useEffect, useLayoutEffect, useRef, useState } from "react";
import { answerStateRequests } from "../../../shared/js/elementState.js";
import { parseView, readStoredView, sourceOf, startViewOf, viewStoreKey, withoutBareLink, writeLinkView, writeStoredView } from "./prepare";
import { readStartLink } from "./links";

// sessionStorage, or null where the browser blocks it (the accessor itself can throw)
function sessionStorageOrNull() {
    try {
        return typeof window !== "undefined" && window.sessionStorage ? window.sessionStorage : null;
    } catch {
        return null;
    }
}

/*
 * The report's view: the server's start view (-View), then the reader's. The reader's view of this tab
 * is kept in the address bar and in sessionStorage, restored on mount, and answers Get-UDElement.
 * latestRef: a ref to the current props (named ...Ref in these hooks, so the React Compiler rules of the lint
 * see a ref, not a value). Returns the view and what useLoadedFile needs of it.
 */
export function useStoredView(props, latestRef) {
    const serverViewKey = JSON.stringify(parseView(props.view) ?? null);
    // the reader's view of this tab survives PSU mounting the component anew (its light/dark switch)
    // and a reload: in the address bar (#pivot-<key>=...) and in sessionStorage, the fallback for a
    // view too long for the address bar
    const store = useRef({ storage: sessionStorageOrNull(), key: null, linkKey: null, path: null, mountedWith: serverViewKey });
    // written at once, not debounced: a reload right after a change must not find an older view in
    // the address bar than in sessionStorage (the address bar wins on mount)
    const showInLink = useCallback((next) => {
        const s = store.current;
        // -NoAddressBar; and only on the page the report was mounted on (PSU's menu may have moved on)
        if (latestRef.current.addressBar === false || !s.linkKey || typeof window === "undefined" || window.location.pathname !== s.path) return;
        try {
            const hash = writeLinkView(window.location.hash, s.linkKey, next);
            if (hash === window.location.hash || (hash === "" && !window.location.hash)) return;
            // replaceState: no navigation, no new history entry, PSU's router does not react (measured)
            window.history.replaceState(window.history.state, "", window.location.pathname + window.location.search + hash);
        } catch {
            // a browser that refuses (Safari limits replaceState calls): sessionStorage still has it
        }
    }, [latestRef]);
    const remember = useCallback((next) => {
        const s = store.current;
        if (!s.key) return;
        writeStoredView(s.storage, s.key, s.mountedWith, next);
        showInLink(next);
    }, [showInLink]);
    // pivotkit's Reset goes back to the view of the first render: always -View, never a restored one
    const [view, setView] = useState(() => parseView(props.view) ?? {});
    // -AllowImport: whether a reader's file is shown, and the app's view while it is (what comes back
    // when pivotkit no longer keeps it)
    const fileRef = useRef(false);
    const hostView = useRef(view);
    const shownKey = useRef(serverViewKey);
    const lastServerKey = useRef(serverViewKey);
    useLayoutEffect(() => {
        // the view in the address bar, else the tab's sessionStorage, else -SavedView replaces the
        // start view before the browser paints;
        // storageKey is -Id, or without one the module's key from the call site and the columns (the
        // id is a new GUID per build). -SavedView is read only here: a later one (a new render of the
        // page with $Session from another tab) never replaces what this tab shows.
        const s = store.current;
        const id = props.storageKey || props.id;
        s.linkKey = id;
        s.path = typeof window !== "undefined" ? window.location.pathname : "";
        s.key = viewStoreKey(s.path, id);
        // with -NoAddressBar a view in the link is ignored too: the report never reads what it never writes
        // the report's own entry, or a pivotkit link (create_link) for this report's data
        const link = typeof window !== "undefined" && props.addressBar !== false ? readStartLink(window.location.hash, id, sourceOf(props.source)?.id, readStoredView(s.storage, s.key, s.mountedWith)) : undefined;
        if (link && link.bare) {
            // "#pivot=" names no report: once this report took it, its own entry stands for it
            try {
                window.history.replaceState(window.history.state, "", window.location.pathname + window.location.search + withoutBareLink(window.location.hash));
            } catch {
                // the view still opens; a reload would read the link again
            }
        }
        // the tab's own view (sessionStorage) keeps the app's limits; only a link gets pivotkit's
        // limits for views from outside (readStartLink)
        const start = startViewOf(s.storage, s.key, s.mountedWith, props.savedView, link && link.view);
        if (start && JSON.stringify(start.view) !== serverViewKey) {
            hostView.current = start.view;
            // pivotkit restored a loaded file in its own layout effect, before this one (onDataLoad
            // "restore", then the file's view): the app's view waits for Back to original data
            if (!fileRef.current) {
                shownKey.current = JSON.stringify(start.view);
                setView(start.view);
            }
            // from now on the tab keeps it in both places, whatever -SavedView a later render of the
            // page brings; storage that has it already is left as it is
            if (start.inStorage) showInLink(start.view);
            else remember(start.view);
            // the component's state holds the restored view too (withComponentFeatures passes it back as props.view)
            if (typeof latestRef.current.setState === "function") latestRef.current.setState({ view: start.view });
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);
    useEffect(() => {
        // a new -View from the server that differs from the one shown (PSU echoes the view setState sent)
        if (serverViewKey === lastServerKey.current) return;
        lastServerKey.current = serverViewKey;
        if (serverViewKey !== shownKey.current) {
            const next = JSON.parse(serverViewKey) ?? {};
            hostView.current = next;
            // while a reader's file is shown, the server's view waits for the app's data
            if (fileRef.current) return;
            shownKey.current = serverViewKey;
            setView(next);
            remember(next);
        }
    }, [serverViewKey, remember]);

    // Get-UDElement: the view of the app's data, also while a reader's file is shown. Only the view and
    // the id: the props hold every row, and this answer travels back in one hub message. (The wrapper of
    // universal-dashboard 1.1.2 still POSTs its whole state, rows included, which PSU ignores.)
    useEffect(() => {
        const pubsub = typeof window !== "undefined" ? window.UniversalDashboard : undefined;
        return answerStateRequests(pubsub, props.id, () => ({ id: props.id, view: hostView.current }));
    }, [props.id]);
    return { view, setView, remember, fileRef, hostView, shownKey };
}
