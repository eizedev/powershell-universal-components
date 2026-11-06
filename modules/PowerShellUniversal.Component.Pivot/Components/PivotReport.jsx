import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { PivotReport as Report } from "pivotkit-react";
import "pivotkit-react/styles.css";
import "./psu.css";
import { callEndpoint, cellEvent, heightOf, mergeTemplates, NARROW_QUERY, parseView, readTemplates, restoreRows, themeOf, VIEW_EVENT_DELAY_MS } from "./prepare";

// true while the window is phone-sized (for the default height)
function useNarrowWindow() {
    const query = typeof window !== "undefined" && window.matchMedia ? window.matchMedia(NARROW_QUERY) : null;
    const [narrow, setNarrow] = useState(() => Boolean(query && query.matches));
    useEffect(() => {
        if (!query) return undefined;
        const onChange = () => setNarrow(query.matches);
        query.addEventListener("change", onChange);
        return () => query.removeEventListener("change", onChange);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);
    return narrow;
}

/*
 * pivotkit's report builder with the props New-UDPivotReport sends. The report runs controlled: this
 * component keeps the view, so a view the server sets later (Set-UDElement -Properties @{ view = ... })
 * becomes one undo step, Get-UDElement sees the current view, and -OnViewChange gets every change once
 * the user paused. Templates saved or deleted through the endpoints show up at once, after the server
 * confirmed them.
 */
export default function PsuPivotReport(props) {
    const rows = useMemo(() => restoreRows(props.data, props.columnNames), [props.data, props.columnNames]);
    const latest = useRef(props);
    latest.current = props;
    const narrow = useNarrowWindow();

    // ---- the view: the server's start view, then the user's ----------------------------------------
    const serverViewKey = JSON.stringify(parseView(props.view) ?? null);
    const [view, setView] = useState(() => parseView(props.view) ?? {});
    const shownKey = useRef(serverViewKey);
    useEffect(() => {
        // a view from the server that differs from the one shown (PSU echoes the view setState sent)
        if (serverViewKey !== shownKey.current) {
            shownKey.current = serverViewKey;
            setView(JSON.parse(serverViewKey) ?? {});
        }
    }, [serverViewKey]);

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

    const onViewChange = useCallback(
        (next) => {
            const key = JSON.stringify(next);
            shownKey.current = key;
            setView(next);
            // Get-UDElement reads the view from the component's state
            if (typeof latest.current.setState === "function") latest.current.setState({ view: next });
            if (typeof latest.current.onViewChange === "function") {
                if (pending.current) clearTimeout(pending.current.timer);
                pending.current = { next, timer: setTimeout(flush, VIEW_EVENT_DELAY_MS) };
            }
        },
        [flush]
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

    const onSaveTemplate = typeof props.onSaveTemplate === "function"
        ? async (name, current) => {
              await callEndpoint(latest.current.onSaveTemplate, { name, view: current, json: JSON.stringify(current) });
              setSaved((list) => [...list.filter((t) => t.name !== name), { name, view: current, deletable: true }]);
              setDeleted((set) => {
                  if (!set.has(name)) return set;
                  const next = new Set(set);
                  next.delete(name);
                  return next;
              });
          }
        : undefined;
    const onDeleteTemplate = typeof props.onDeleteTemplate === "function"
        ? async (name) => {
              await callEndpoint(latest.current.onDeleteTemplate, { name });
              setDeleted((set) => new Set(set).add(name));
          }
        : undefined;

    // ---- clicks ----------------------------------------------------------------------------------
    const viewRef = useRef(view);
    viewRef.current = view;
    const onCellClick = typeof props.onCellClick === "function"
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
                templates={templates}
                onSaveTemplate={onSaveTemplate}
                onDeleteTemplate={onDeleteTemplate}
                onCellClick={onCellClick}
                drillDown={props.drillDown !== false}
                fieldDefaults={props.fieldDefaults || undefined}
                labels={props.labels || undefined}
                locale={props.locale || "en-US"}
                timeZone={props.timeZone || "UTC"}
                theme={themeOf(props.theme)}
                height={heightOf(props.height, narrow)}
                fileName={props.fileName || "pivot"}
            />
        </div>
    );
}
