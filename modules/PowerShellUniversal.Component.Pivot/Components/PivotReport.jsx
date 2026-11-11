import React, { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from "react";
import { fieldDefaultsFromSchema } from "pivotkit-core";
import { PivotReport as Report } from "pivotkit-react";
// Excel workbooks for -AllowImport: a small descriptor; its reader is imported on the first workbook
import xlsxReader from "pivotkit-xlsx";
import { bundleScriptOf, importWorkerOf, workerUrlOf } from "./importWorker";
import "pivotkit-react/styles.css";
import "./psu.css";
import { useNarrowWindow } from "./hooks";
import AdminPanel from "./AdminPanel";
import { callEndpoint, cellEvent, dataLoadEvent, fieldListOf, heightOf, MAX_OPTIONS_LENGTH, MAX_SCHEMA_LENGTH, mergeFieldDefaults, mergeTemplates, parseJsonObject, parseView, readLinkView, readTemplates, restoreRows, schemaUrlOf, sourceOf, startViewOf, switchOf, templateKey, themeOf, tipsOf, VIEW_EVENT_DELAY_MS, viewStoreKey, writeLinkView, writeStoredView } from "./prepare";

/*
 * What -Schema says about the fields (pivotkit-core's fieldDefaultsFromSchema: names, descriptions,
 * https links, types, orders), or undefined. A schema it cannot read is reported in the console and
 * left out; the report works without it.
 */
function schemaDefaults(text, name) {
    const schema = parseJsonObject(text, MAX_SCHEMA_LENGTH);
    if (!schema) return undefined;
    try {
        const { defaults, issues } = fieldDefaultsFromSchema(schema, typeof name === "string" && name ? { schema: name } : {});
        if (issues.length) console.warn("New-UDPivotReport -Schema:", issues.map((i) => `${i.path}: ${i.message}`).join("; "));
        return defaults;
    } catch (e) {
        console.warn("New-UDPivotReport -Schema left out:", e instanceof Error ? e.message : String(e));
        return undefined;
    }
}

// the reader plugins of -AllowImport (CSV, TSV, text and JSON are built into pivotkit)
const IMPORT_PLUGINS = [xlsxReader];
// the worker that reads CSV and JSON files off the page, found next to this bundle while it runs
// (__PIVOT_IMPORT_WORKER__: its file name, defined by the module's webpack.config.js; a build without
// it, such as the documentation site's, reads files on the page)
const WORKER_FILE = typeof __PIVOT_IMPORT_WORKER__ === "string" ? __PIVOT_IMPORT_WORKER__ : "";
const importWorker = typeof document !== "undefined" && typeof location !== "undefined" ? importWorkerOf(workerUrlOf(bundleScriptOf(document), WORKER_FILE, location.origin)) : undefined;

// sessionStorage, or null where the browser blocks it (the accessor itself can throw)
function sessionStorageOrNull() {
    try {
        return typeof window !== "undefined" && window.sessionStorage ? window.sessionStorage : null;
    } catch {
        return null;
    }
}

/*
 * pivotkit's report builder with the props New-UDPivotReport sends. The report runs controlled: this
 * component keeps the view, so a view the server sets later (Set-UDElement -Properties @{ view = ... })
 * becomes one undo step, Get-UDElement sees the current view, and -OnViewChange gets every change once
 * the user paused. Templates saved, published or deleted through the endpoints show up at once, after
 * the server confirmed them.
 */
export default function PsuPivotReport(props) {
    const rows = useMemo(() => restoreRows(props.data, props.columnNames), [props.data, props.columnNames]);
    const latest = useRef(props);
    latest.current = props;
    const narrow = useNarrowWindow();

    // ---- the view: the server's start view, then the user's ----------------------------------------
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
        if (latest.current.addressBar === false || !s.linkKey || typeof window === "undefined" || window.location.pathname !== s.path) return;
        try {
            const hash = writeLinkView(window.location.hash, s.linkKey, next);
            if (hash === window.location.hash || (hash === "" && !window.location.hash)) return;
            // replaceState: no navigation, no new history entry, PSU's router does not react (measured)
            window.history.replaceState(window.history.state, "", window.location.pathname + window.location.search + hash);
        } catch {
            // a browser that refuses (Safari limits replaceState calls): sessionStorage still has it
        }
    }, []);
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
        const link = typeof window !== "undefined" && props.addressBar !== false ? readLinkView(window.location.hash, id) : undefined;
        const start = startViewOf(s.storage, s.key, s.mountedWith, props.savedView, link);
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
            // Get-UDElement reads the restored view too
            if (typeof latest.current.setState === "function") latest.current.setState({ view: start.view });
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
        const handler = latest.current.onViewChange;
        if (typeof handler === "function") {
            handler({ view: next, json: JSON.stringify(next) });
        }
    }, []);
    useEffect(() => () => flush(), [flush]);

    // the view of the app's data leaves the component: remembered, in the state, to -OnViewChange
    const publish = useCallback(
        (next) => {
            hostView.current = next;
            remember(next);
            // Get-UDElement reads the view from the component's state
            if (typeof latest.current.setState === "function") latest.current.setState({ view: next });
            if (typeof latest.current.onViewChange === "function") {
                if (pending.current) clearTimeout(pending.current.timer);
                pending.current = { next, timer: setTimeout(flush, VIEW_EVENT_DELAY_MS) };
            }
        },
        [flush, remember]
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
        [publish]
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
            const handler = latest.current.onDataLoad;
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
        [flush, publish]
    );

    // ---- templates -------------------------------------------------------------------------------
    const templatesKey = JSON.stringify(props.templates ?? null);
    const serverTemplates = useMemo(() => readTemplates(JSON.parse(templatesKey)), [templatesKey]);
    const [saved, setSaved] = useState([]);
    const [deleted, setDeleted] = useState(() => new Set());
    useEffect(() => {
        // new templates from the server include what was saved and leave out what was deleted
        setSaved([]);
        setDeleted(new Set());
    }, [templatesKey]);
    const templates = useMemo(() => mergeTemplates(serverTemplates, saved, deleted), [serverTemplates, saved, deleted]);
    // while a file is shown, "My views" are the browser's views of that file: the reader's own views of
    // the app's data on the server stay out (they cannot be saved over or deleted from here)
    const shownTemplates = useMemo(() => (fileShown ? templates.filter((t) => t.scope !== "user") : templates), [fileShown, templates]);

    // a template the server confirmed: shown until the server sends the templates again
    const keep = useCallback((template) => {
        const key = templateKey(template.scope, template.name);
        setSaved((list) => [...list.filter((t) => templateKey(t.scope, t.name) !== key), template]);
        setDeleted((set) => {
            if (!set.has(key)) return set;
            const next = new Set(set);
            next.delete(key);
            return next;
        });
    }, []);
    // a file's views are kept by the browser's store (pivotkit keeps them per file), not by the server
    const serverSaves = !fileShown;
    const onSaveTemplate = serverSaves && typeof props.onSaveTemplate === "function"
        ? async (name, current) => {
              await callEndpoint(latest.current.onSaveTemplate, { name, view: current, json: JSON.stringify(current), scope: "user" });
              keep({ name, view: current, scope: "user", deletable: true });
          }
        : undefined;
    const onDeleteTemplate = serverSaves && typeof props.onDeleteTemplate === "function"
        ? async (name, how) => {
              const scope = how && how.scope === "shared" ? "shared" : "user";
              await callEndpoint(latest.current.onDeleteTemplate, { name, scope });
              setDeleted((set) => new Set(set).add(templateKey(scope, name)));
          }
        : undefined;
    // -AdminRole: the server sends canPublish only to readers with one of its roles, and checks again
    const onPublishTemplate = serverSaves && props.canPublish === true && typeof props.onPublishTemplate === "function"
        ? async (name, current) => {
              await callEndpoint(latest.current.onPublishTemplate, { name, view: current, json: JSON.stringify(current), scope: "shared" });
              keep({ name, view: current, scope: "shared", deletable: true });
          }
        : undefined;

    // ---- fields: -Schema, then -FieldDefaults and -FieldDescriptions over it ---------------------
    const columnsKey = JSON.stringify(props.columnNames ?? null);
    const fieldDefaults = useMemo(
        () => mergeFieldDefaults(schemaDefaults(props.schema, props.schemaName), parseJsonObject(props.fieldDefaults, MAX_SCHEMA_LENGTH), JSON.parse(columnsKey)),
        [props.schema, props.schemaName, props.fieldDefaults, columnsKey]
    );
    const chartOptions = useMemo(() => parseJsonObject(props.chartOptions, MAX_OPTIONS_LENGTH), [props.chartOptions]);
    const tipsKey = JSON.stringify(props.tips ?? null);
    const tips = useMemo(() => tipsOf(JSON.parse(tipsKey)), [tipsKey]);
    const sourceKey = JSON.stringify(props.source ?? null);
    const source = useMemo(() => sourceOf(JSON.parse(sourceKey)), [sourceKey]);
    const schemaUrl = schemaUrlOf(props.schemaUrl);

    // ---- clicks ----------------------------------------------------------------------------------
    const viewRef = useRef(view);
    viewRef.current = view;
    // the rows of a loaded file never go to the server: -OnCellClick runs on the app's data only
    const onCellClick = !fileShown && typeof props.onCellClick === "function"
        ? (cell) => {
              const handler = latest.current.onCellClick;
              if (typeof handler === "function") handler(cellEvent(cell, viewRef.current));
          }
        : undefined;

    return (
        <div id={props.id} className={["ud-pivot-report", props.className].filter(Boolean).join(" ")} style={{ width: "100%", minWidth: 0, ...(props.style || {}) }}>
            <Report
                data={rows}
                view={view}
                onViewChange={onViewChange}
                templates={shownTemplates}
                onSaveTemplate={onSaveTemplate}
                onDeleteTemplate={onDeleteTemplate}
                onPublishTemplate={onPublishTemplate}
                canPublish={Boolean(onPublishTemplate)}
                templateStore={fileShown || String(props.templateStore || "").toLowerCase() === "browser" ? "browser" : undefined}
                source={source}
                {...(schemaUrl !== undefined ? { schemaUrl } : {})}
                onCellClick={onCellClick}
                allowImport={props.allowImport === true}
                plugins={props.allowImport === true ? IMPORT_PLUGINS : undefined}
                onDataLoad={props.allowImport === true ? onDataLoad : undefined}
                importWorker={props.allowImport === true ? importWorker : undefined}
                drillDown={props.drillDown !== false}
                fieldDefaults={fieldDefaults}
                chartOptions={chartOptions}
                tips={tips}
                fieldInfo={switchOf(props.fieldInfo)}
                zoneInfo={switchOf(props.zoneInfo)}
                settingInfo={switchOf(props.settingInfo)}
                fieldList={fieldListOf(props.fieldList)}
                grow={switchOf(props.grow)}
                // dismissed tips are kept in localStorage per report; the view is kept by this
                // component (address bar and sessionStorage), so pivotkit's persistView and shareLink stay off
                storageKey={props.storageKey || props.id}
                label={props.label || undefined}
                labels={props.labels || undefined}
                locale={props.locale || "en-US"}
                timeZone={props.timeZone || "UTC"}
                theme={themeOf(props.theme)}
                height={heightOf(props.height, narrow)}
                fileName={props.fileName || "pivot"}
            />
            {props.admin ? <AdminPanel admin={props.admin} view={view} rows={rows} locale={props.locale} timeZone={props.timeZone || "UTC"} /> : null}
        </div>
    );
}
