import React, { useEffect, useRef, useState } from "react";
import { usePsuTheme, effectiveMode } from "../../../shared/js/psuTheme";
import { THEMES, viewerConfig, prepareRows, toolbarLabels, switchTarget, isChartPlugin, TABLE_PLUGIN } from "./prepare";

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
        // a failed start (e.g. a policy blocking workers) must not stick for the rest of the page
        window.__psuPerspectiveWorker.catch(() => {
            window.__psuPerspectiveWorker = null;
        });
    }
    return window.__psuPerspectiveWorker;
}

/*
 * Pro Dark inverts the plugin selector on hover (white background, dark text), which flashes white
 * in a dark app. The rule lives in the viewer's shadow root, so the override goes there: the hover
 * takes the theme's own highlight instead.
 */
// one class more than Perspective's rule (which has two ids), so it wins whatever order the sheets
// are in (Perspective adopts its sheet again after a theme change, behind this one)
const HOVER_SELECTOR = ":host #settings_panel #plugin_selector_container .plugin-select-item.plugin-select-item:hover";
const HOVER_FIX = `${HOVER_SELECTOR} { background-color: var(--psp-active--background, rgba(39, 113, 170, 0.5)); color: var(--psp--color, inherit); } ${HOVER_SELECTOR} > .icon { background-color: var(--psp--color, currentColor); }`;

let hoverSheet = null;

// idempotent: Perspective sets its own style sheets again (e.g. on a theme change), so the override is
// added whenever it is missing
function softenPluginHover(viewer) {
    const root = viewer && viewer.shadowRoot;
    if (!root || typeof CSSStyleSheet === "undefined" || !("adoptedStyleSheets" in root)) return;
    if (!hoverSheet) {
        hoverSheet = new CSSStyleSheet();
        hoverSheet.replaceSync(HOVER_FIX);
    }
    if (!root.adoptedStyleSheets.includes(hoverSheet)) root.adoptedStyleSheets = [...root.adoptedStyleSheets, hoverSheet];
}

// colours of the toolbar per mode (MUI's defaults, as PSU's own buttons use them)
const TOOLBAR_COLORS = {
    light: { text: "rgba(0, 0, 0, 0.87)", border: "rgba(0, 0, 0, 0.23)", accent: "#1976d2", pressed: "rgba(25, 118, 210, 0.12)" },
    dark: { text: "#ffffff", border: "rgba(255, 255, 255, 0.23)", accent: "#90caf9", pressed: "rgba(144, 202, 249, 0.16)" }
};

function ToolButton({ pressed, onClick, children, colors, grouped, first, last }) {
    const radius = grouped ? (first ? "4px 0 0 4px" : last ? "0 4px 4px 0" : 0) : 4;
    return (
        <button
            type="button"
            aria-pressed={pressed}
            onClick={onClick}
            style={{
                font: "inherit", fontSize: 13, fontWeight: 500, lineHeight: "20px", letterSpacing: "0.02em",
                padding: "4px 12px", cursor: "pointer", borderRadius: radius,
                border: `1px solid ${pressed ? colors.accent : colors.border}`, marginLeft: grouped && !first ? -1 : 0,
                position: "relative", zIndex: pressed ? 1 : 0,
                color: pressed ? colors.accent : colors.text, background: pressed ? colors.pressed : "transparent"
            }}
        >
            {children}
        </button>
    );
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
    // the mode when a load finishes, not when it started: PSU's theme switch can come in between
    const modeRef = useRef(mode);
    modeRef.current = mode;
    // toolbar: whether the configuration panel is open and which plugin the view shows, kept in step
    // with the viewer's own events (the reader can also change both in the panel)
    const [settingsOpen, setSettingsOpen] = useState(Boolean(props.settings));
    const [plugin, setPlugin] = useState(props.plugin || TABLE_PLUGIN);
    const lastChart = useRef(isChartPlugin(props.plugin) ? props.plugin : null);
    const labels = toolbarLabels(props.labels);
    const colors = TOOLBAR_COLORS[mode] || TOOLBAR_COLORS.light;

    // table: created once, replaced in place when the data changes (the view keeps its layout)
    useEffect(() => {
        let cancelled = false;
        (async () => {
            try {
                const worker = await sharedWorker();
                if (cancelled) return;
                setError(null);
                const schemaKey = JSON.stringify(prepared.schema);
                // same columns and types: replace the rows in place, the view keeps its layout
                if (tableRef.current && tableRef.current.schemaKey === schemaKey) {
                    await tableRef.current.table.replace(prepared.rows);
                    return;
                }
                // first load, or the columns changed (a table keeps its schema): a new table
                const table = await worker.table(prepared.schema);
                if (prepared.rows.length) await table.update(prepared.rows);
                if (cancelled) {
                    // unmounted or new data while this one was being built
                    await table.delete();
                    return;
                }
                const previous = tableRef.current;
                tableRef.current = { table, schemaKey };
                try {
                    if (viewerRef.current) {
                        await viewerRef.current.load(table);
                        // the viewer has its shadow root (and Perspective's styles) once it is defined
                        softenPluginHover(viewerRef.current);
                        // first load, or other columns: the reader's layout may name columns that are
                        // gone, so the view starts again from the parameters
                        const problems = [];
                        await viewerRef.current.restore(viewerConfig(latest.current, keys, modeRef.current, prepared.schema, problems));
                        if (problems.length && !cancelled) setError(problems.join("; "));
                    }
                } finally {
                    // the old table goes even when loading the new one failed
                    if (previous) await previous.table.delete().catch(() => {});
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
            viewer.restore({ theme: THEMES[mode] || THEMES.light }).then(() => softenPluginHover(viewer)).catch(() => {});
        }
    }, [mode]);

    useEffect(() => {
        const viewer = viewerRef.current;
        if (!viewer) return undefined;
        softenPluginHover(viewer);
        const onToggle = (e) => {
            setSettingsOpen(Boolean(e.detail));
            softenPluginHover(viewer);
        };
        // every change of the view, also restore() and the reader's choice in the panel, fires
        // perspective-config-update ("perspective-plugin-update" does not fire for restore)
        const onConfig = (e) => {
            let name;
            try {
                // getConfig is valid only while the event is dispatched
                const config = e.detail && typeof e.detail.getConfig === "function" ? e.detail.getConfig() : null;
                name = config && config.plugin;
            } catch (err) {
                name = undefined;
            }
            if (!name) return;
            setPlugin(name);
            if (isChartPlugin(name)) lastChart.current = name;
        };
        viewer.addEventListener("perspective-toggle-settings", onToggle);
        viewer.addEventListener("perspective-config-update", onConfig);
        return () => {
            viewer.removeEventListener("perspective-toggle-settings", onToggle);
            viewer.removeEventListener("perspective-config-update", onConfig);
        };
    }, []);

    const toggleEditor = () => {
        const viewer = viewerRef.current;
        if (viewer) viewer.toggleConfig().catch(() => {});
    };
    const showKind = (kind) => {
        const viewer = viewerRef.current;
        const next = switchTarget(kind, plugin, lastChart.current, latest.current.chartPlugin);
        if (viewer && next) viewer.restore({ plugin: next }).catch((e) => setError(String(e && e.message ? e.message : e)));
    };
    const chart = isChartPlugin(plugin);

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
        const current = tableRef.current;
        tableRef.current = null;
        (async () => {
            try {
                if (viewer) await viewer.delete();
                if (current) await current.table.delete();
            } catch (e) {
                // already gone with the page
            }
        })();
    }, []);

    return (
        <div id={props.id} className={props.className} style={{ ...(props.style || {}), width: props.width || (props.style && props.style.width) || "100%" }}>
            {error && <div role="alert" style={{ color: "#d32f2f", padding: 8 }}>Perspective: {error}</div>}
            {props.toolbar !== false && (
                <div role="toolbar" aria-label="Perspective" style={{ display: "flex", flexWrap: "wrap", gap: 8, alignItems: "center", marginBottom: 8 }}>
                    <ToolButton pressed={settingsOpen} onClick={toggleEditor} colors={colors}>{labels.editView}</ToolButton>
                    <span role="group" style={{ display: "inline-flex" }}>
                        <ToolButton grouped first pressed={!chart} onClick={() => showKind("table")} colors={colors}>{labels.table}</ToolButton>
                        <ToolButton grouped last pressed={chart} onClick={() => showKind("chart")} colors={colors}>{labels.chart}</ToolButton>
                    </span>
                </div>
            )}
            <perspective-viewer ref={viewerRef} style={{ display: "block", width: "100%", height: props.height || "480px" }} />
        </div>
    );
}
