import React, { useEffect, useMemo, useState } from "react";
import { encode } from "pivotkit-core";
import { columnSummary, lastTimings } from "./prepare";

const TEXTS = {
    en: {
        title: "Admin: view and diagnostics",
        note: "Shown to the roles of -AdminRole only.",
        view: "Current view (JSON)",
        columns: "Columns",
        column: "Column",
        type: "Type",
        distinct: "Distinct",
        blanks: "Blank",
        timings: "Timings",
        server: "Server: data conversion {convert} ms, New-UDPivotReport {total} ms",
        browser: "Browser, last change: encode {encode} ms, pivot {computePivot} ms, grid {toGrid} ms",
        size: "{rows} rows, {columns} columns, {templates} templates, store: {store}",
        none: "none"
    },
    de: {
        title: "Admin: Ansicht und Diagnose",
        note: "Nur für die Rollen aus -AdminRole sichtbar.",
        view: "Aktuelle Ansicht (JSON)",
        columns: "Spalten",
        column: "Spalte",
        type: "Typ",
        distinct: "Verschieden",
        blanks: "Leer",
        timings: "Zeiten",
        server: "Server: Datenumwandlung {convert} ms, New-UDPivotReport {total} ms",
        browser: "Browser, letzte Änderung: encode {encode} ms, Pivot {computePivot} ms, Raster {toGrid} ms",
        size: "{rows} Zeilen, {columns} Spalten, {templates} Vorlagen, Speicher: {store}",
        none: "keiner"
    }
};

const fill = (text, values) => text.replace(/\{(\w+)\}/g, (_, k) => (values[k] === undefined || values[k] === null ? "–" : String(values[k])));

function timingsNow() {
    if (typeof performance === "undefined" || typeof performance.getEntriesByName !== "function") return {};
    return lastTimings((name) => performance.getEntriesByName(name, "measure"));
}

/*
 * The admin panel under the report (New-UDPivotReport -AdminRole): the view as JSON, the columns as
 * pivotkit reads them, and how long the server and the browser took. pivotkit has no place for host
 * content in its menus, so it is the module's own disclosure under the report. The columns are encoded
 * only while it is open.
 */
export default function AdminPanel({ admin, view, rows, locale, timeZone }) {
    const t = TEXTS[String(locale || "").toLowerCase().startsWith("de") ? "de" : "en"];
    const [open, setOpen] = useState(false);
    const [timings, setTimings] = useState({});
    const viewText = useMemo(() => JSON.stringify(view ?? {}, null, 2), [view]);
    const columns = useMemo(() => {
        if (!open) return [];
        try {
            return columnSummary(encode(rows, { timeZone }));
        } catch {
            return [];
        }
    }, [open, rows, timeZone]);
    useEffect(() => {
        if (!open) return undefined;
        // after pivotkit drew the change
        const id = setTimeout(() => setTimings(timingsNow()), 50);
        return () => clearTimeout(id);
    }, [open, viewText]);
    const a = admin || {};
    return (
        <details className="ud-pivot-admin" data-testid="pivot-admin" onToggle={(e) => setOpen(e.currentTarget.open)}>
            <summary>{t.title}</summary>
            {open ? (
                <div className="ud-pivot-admin-body">
                    <p className="ud-pivot-admin-note">{t.note}</p>
                    <p>{fill(t.size, { rows: a.rows, columns: a.columns, templates: a.templates, store: a.store || t.none })}</p>
                    <h3>{t.timings}</h3>
                    <p data-testid="pivot-admin-server">{fill(t.server, { convert: a.convertMs, total: a.serverMs })}</p>
                    <p data-testid="pivot-admin-browser">{fill(t.browser, timings)}</p>
                    <h3>{t.columns}</h3>
                    <div className="ud-pivot-admin-scroll">
                        <table data-testid="pivot-admin-columns">
                            <thead>
                                <tr>
                                    <th scope="col">{t.column}</th>
                                    <th scope="col">{t.type}</th>
                                    <th scope="col">{t.distinct}</th>
                                    <th scope="col">{t.blanks}</th>
                                </tr>
                            </thead>
                            <tbody>
                                {columns.map((c) => (
                                    <tr key={c.name}>
                                        <td>{c.name}</td>
                                        <td>{c.type}</td>
                                        <td>{c.distinct}</td>
                                        <td>{c.blanks}</td>
                                    </tr>
                                ))}
                            </tbody>
                        </table>
                    </div>
                    <h3>{t.view}</h3>
                    <pre data-testid="pivot-admin-view" tabIndex={0}>{viewText}</pre>
                </div>
            ) : null}
        </details>
    );
}
