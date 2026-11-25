import { useCallback, useEffect, useRef, useState } from "react";
import { dataLoadEvent, VIEW_EVENT_DELAY_MS } from "./prepare";

/*
 * -AllowImport and -OnViewChange: which data pivotkit shows (the app's or a file the reader loaded),
 * and the view changes of the app's data, passed on after the reader paused.
 * latestRef: a ref to the current props; stored: what useStoredView returned.
 */
export function useLoadedFile(latestRef, stored) {
    const { setView, remember, fileRef, hostView, shownKey } = stored;
    // ---- a file the reader loaded (-AllowImport) ---------------------------------------------------
    // While a file's data is shown, its view, its cells and its saved views stay in the browser: the
    // address bar, sessionStorage, Get-UDElement, -OnViewChange and -OnCellClick keep to the app's data,
    // and saving goes to the browser's store under the file's source id instead of the server's.
    const [fileShown, setFileShown] = useState(false);
    // the last view pivotkit reported; the one in the same task as onDataLoad (pivotkit's own view of
    // the data it switches to)
    const lastView = useRef(null);
    const recentView = useRef(null);

    const pending = useRef(null);
    const flush = useCallback(() => {
        if (!pending.current) return;
        const { next } = pending.current;
        clearTimeout(pending.current.timer);
        pending.current = null;
        const handler = latestRef.current.onViewChange;
        if (typeof handler === "function") {
            handler({ view: next, json: JSON.stringify(next) });
        }
    }, [latestRef]);
    useEffect(() => () => flush(), [flush]);

    // the view of the app's data leaves the component: remembered, in the state, to -OnViewChange
    const publish = useCallback(
        (next) => {
            hostView.current = next;
            remember(next);
            // the component's state holds the view (withComponentFeatures passes it back as props.view)
            if (typeof latestRef.current.setState === "function") latestRef.current.setState({ view: next });
            if (typeof latestRef.current.onViewChange === "function") {
                if (pending.current) clearTimeout(pending.current.timer);
                pending.current = { next, timer: setTimeout(flush, VIEW_EVENT_DELAY_MS) };
            }
        },
        [flush, remember, hostView, latestRef]
    );
    const onViewChange = useCallback(
        (next) => {
            shownKey.current = JSON.stringify(next);
            lastView.current = next;
            recentView.current = next;
            setView(next);
            // pivotkit shows the view of another data set (Undo, Redo, Back to original data) before it
            // says which data that is (onDataLoad, in the same call): decide once both are known
            queueMicrotask(() => {
                if (recentView.current === next) recentView.current = null;
                if (!fileRef.current && lastView.current === next) publish(next);
            });
        },
        [publish, fileRef, setView, shownKey]
    );
    const onDataLoad = useCallback(
        (detail) => {
            const file = Boolean(detail && detail.file);
            if (file && !fileRef.current && pending.current) {
                // a change of the app's view still waiting for -OnViewChange: send it now, before the file's
                flush();
            }
            fileRef.current = file;
            setFileShown(file);
            if (!file) {
                // back on the app's data. pivotkit shows its view again in the same task, before this
                // call, while it still keeps that data's step (Undo keeps three); once that step is
                // let go it shows the file's view on the app's data: then the app's last view comes back
                let shown = recentView.current;
                if (!shown) {
                    shown = hostView.current;
                    shownKey.current = JSON.stringify(shown);
                    lastView.current = shown;
                    setView(shown);
                }
                queueMicrotask(() => {
                    if (!fileRef.current && lastView.current === shown) publish(shown);
                });
            }
            const handler = latestRef.current.onDataLoad;
            try {
                if (typeof handler === "function") handler(dataLoadEvent(detail));
            } catch (error) {
                // never into pivotkit: an error there would refuse a file this component already shows
                setTimeout(() => {
                    throw error;
                }, 0);
            }
            // never false: the server is told, it cannot refuse a file (pivotkit does not wait for it)
            return undefined;
        },
        [flush, publish, fileRef, hostView, latestRef, setView, shownKey]
    );
    return { fileShown, onViewChange, onDataLoad };
}
