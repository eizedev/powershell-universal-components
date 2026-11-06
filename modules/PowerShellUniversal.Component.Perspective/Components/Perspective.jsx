import React, { useEffect, useRef, useState } from "react";
import { usePsuTheme, effectiveMode } from "../../../shared/js/psuTheme";
import { THEMES, viewerConfig, prepareRows } from "./prepare";

/*
 * <perspective-viewer> with the rows New-UDPerspective sends: a datagrid, pivot and chart that users
 * re-arrange themselves (group, split, filter, sort, plugin) - the configuration panel is the
 * interface. The data lives in a Perspective table inside a Web Worker (WebAssembly, bundled inline),
 * so large row counts stay fast.
 */

// one worker per page, shared by every viewer (and by every run of this bundle, see index.js)
function sharedWorker() {
    if (!window.__psuPerspectiveWorker) {
        window.__psuPerspectiveWorker = window.__psuPerspective.then((perspective) => perspective.worker());
    }
    return window.__psuPerspectiveWorker;
}

export default function Perspective(props) {
    const viewerRef = useRef(null);
    const tableRef = useRef(null);
    const [error, setError] = useState(null);
    const psuTheme = usePsuTheme();
    const mode = effectiveMode(props.theme, psuTheme);
    const prepared = React.useMemo(() => prepareRows(Array.isArray(props.data) ? props.data : [], props.columnNames), [props.data, props.columnNames]);
    const keys = prepared.columns;
    const latest = useRef(props);
    latest.current = props;

    // table: created once, replaced in place when the data changes (the view keeps its layout)
    useEffect(() => {
        let cancelled = false;
        (async () => {
            try {
                const worker = await sharedWorker();
                if (cancelled) return;
                if (tableRef.current) {
                    await tableRef.current.replace(prepared.rows);
                    return;
                }
                // the schema first fixes every column's type (dates as dates), then the rows
                const table = await worker.table(prepared.schema);
                if (prepared.rows.length) await table.update(prepared.rows);
                tableRef.current = table;
                if (viewerRef.current) {
                    await viewerRef.current.load(table);
                    await viewerRef.current.restore(viewerConfig(latest.current, keys, mode));
                }
            } catch (e) {
                if (!cancelled) setError(String(e && e.message ? e.message : e));
            }
        })();
        return () => {
            cancelled = true;
        };
    }, [props.data]);

    // theme follows PSU's light/dark switch without resetting what the user arranged
    useEffect(() => {
        const viewer = viewerRef.current;
        if (viewer && tableRef.current) {
            viewer.restore({ theme: THEMES[mode] || THEMES.light }).catch(() => {});
        }
    }, [mode]);

    // clicks: the row under the pointer and the group/split values that lead to it, as $EventData
    useEffect(() => {
        const viewer = viewerRef.current;
        if (!viewer) return undefined;
        const onClick = (e) => {
            const handler = latest.current.onClick;
            if (typeof handler !== "function") return;
            const d = e.detail || {};
            handler({ row: d.row || null, columnNames: d.column_names || [], filter: (d.config && d.config.filter) || [] });
        };
        viewer.addEventListener("perspective-click", onClick);
        return () => viewer.removeEventListener("perspective-click", onClick);
    }, []);

    // free the viewer and the table when the component leaves the page
    useEffect(() => () => {
        const viewer = viewerRef.current;
        const table = tableRef.current;
        tableRef.current = null;
        (async () => {
            try {
                if (viewer) await viewer.delete();
                if (table) await table.delete();
            } catch (e) {
                // already gone with the page
            }
        })();
    }, []);

    return (
        <div id={props.id} className={props.className} style={{ ...(props.style || {}), width: props.width || (props.style && props.style.width) || "100%" }}>
            {error && <div role="alert" style={{ color: "#d32f2f", padding: 8 }}>Perspective: {error}</div>}
            <perspective-viewer ref={viewerRef} style={{ display: "block", width: "100%", height: props.height || "480px" }} />
        </div>
    );
}
