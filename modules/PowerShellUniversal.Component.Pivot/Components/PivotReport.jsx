import React, { useMemo } from "react";
import { PivotReport as Report } from "pivotkit-react";
// Excel workbooks for -AllowImport: a small descriptor; its reader is imported on the first workbook
import xlsxReader from "pivotkit-xlsx";
import { bundleScriptOf, importWorkerOf, workerUrlOf } from "./importWorker";
import "pivotkit-react/styles.css";
import "./psu.css";
import { useNarrowWindow } from "./hooks";
import { useLatest } from "../../../shared/js/useLatest";
import { useStoredView } from "./useStoredView";
import { useLoadedFile } from "./useLoadedFile";
import { useTemplateEndpoints } from "./useTemplateEndpoints";
import { useReportOptions } from "./useReportOptions";
import AdminPanel from "./AdminPanel";
import { cellEvent, problemOf, problemText, recordsOf, withheldFieldsOf, withheldText, fieldListOf, heightOf, importLimitsOf, restoreRows, switchOf, themeOf, zonesOf } from "./prepare";

// the reader plugins of -AllowImport (CSV, TSV, text and JSON are built into pivotkit)
const IMPORT_PLUGINS = [xlsxReader];
// the worker that reads CSV and JSON files off the page, found next to this bundle while it runs
// (__PIVOT_IMPORT_WORKER__: its file name, defined by the module's webpack.config.js; a build without
// it, such as the documentation site's, reads files on the page)
const WORKER_FILE = typeof __PIVOT_IMPORT_WORKER__ === "string" ? __PIVOT_IMPORT_WORKER__ : "";
const importWorker = typeof document !== "undefined" && typeof location !== "undefined" ? importWorkerOf(workerUrlOf(bundleScriptOf(document), WORKER_FILE, location.origin)) : undefined;

/*
 * What the report says in place of itself when New-UDPivotReport -Uri got no rows from the server
 * (the problem prop), in the report's language. The details for the operator are in the app's log.
 */
function ProblemBox({ problem, locale }) {
    const t = problemText(problem, locale);
    return (
        <div className="ud-pivot-problem" role="alert" data-problem={problem.kind}>
            <h3>{t.title}</h3>
            <p>{t.text}</p>
            {t.reference ? <p className="ud-pivot-problem-reference">{t.reference}</p> : null}
        </div>
    );
}

/*
 * pivotkit's report builder with the props New-UDPivotReport sends. The report runs controlled: this
 * component keeps the view, so a view the server sets later (Set-UDElement -Properties @{ view = ... })
 * becomes one undo step, Get-UDElement sees the current view, and -OnViewChange gets every change once
 * the user paused. Templates saved, published or deleted through the endpoints show up at once, after
 * the server confirmed them.
 */
export default function PsuPivotReport(props) {
    // -Uri -Source: the server's answer as text, parsed here once (no PowerShell objects on the way);
    // else -Data's rows with the names PowerShell had
    const records = useMemo(() => recordsOf(props.records), [props.records]);
    const rows = useMemo(() => (records ? records.table : restoreRows(props.data, props.columnNames)), [records, props.data, props.columnNames]);
    // a text that does not parse is the server's fault, never a partial report
    const problem = problemOf(props.problem) ?? (typeof props.records === "string" && !records ? problemOf({ kind: "serverError" }) : undefined);
    const latest = useLatest(props);
    const narrow = useNarrowWindow();

    // the view, a file the reader loaded, the templates and the settings, in this order (hooks.js and use*.js)
    const { view, setView, remember, fileRef, hostView, shownKey } = useStoredView(props, latest);
    const { fileShown, onViewChange, onDataLoad } = useLoadedFile(latest, { setView, remember, fileRef, hostView, shownKey });
    const { shownTemplates, onSaveTemplate, onDeleteTemplate, onPublishTemplate } = useTemplateEndpoints(props, latest, fileShown);
    const { fieldDefaults, chartOptions, tips, source, schemaUrl, exportData, labels } = useReportOptions(props);

    // ---- clicks ----------------------------------------------------------------------------------
    const viewRef = useLatest(view);
    // the rows of a loaded file never go to the server: -OnCellClick runs on the app's data only
    const onCellClick = !fileShown && typeof props.onCellClick === "function"
        ? (cell) => {
              const handler = latest.current.onCellClick;
              if (typeof handler === "function") handler(cellEvent(cell, viewRef.current));
          }
        : undefined;

    // a view (a link's, -View) that needs fields the server held back from this person: said, not hidden
    const withheld = useMemo(() => (records && !fileShown ? withheldFieldsOf(view, records.withheld) : []), [records, view, fileShown]);

    if (problem) {
        return (
            <div id={props.id} className={["ud-pivot-report", props.className].filter(Boolean).join(" ")} style={{ width: "100%", minWidth: 0, ...(props.style || {}) }}>
                <ProblemBox problem={problem} locale={props.locale} />
            </div>
        );
    }
    return (
        <div id={props.id} className={["ud-pivot-report", props.className].filter(Boolean).join(" ")} style={{ width: "100%", minWidth: 0, ...(props.style || {}) }}>
            {withheld.length ? <div className="ud-pivot-withheld" role="status">{withheldText(withheld, props.locale)}</div> : null}
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
                // a loaded file's limits; the app's -Data keeps pivotkit's own
                importLimits={props.allowImport === true ? importLimitsOf(props.importLimits) : undefined}
                drillDown={props.drillDown !== false}
                // -DrillDownExport: the drill-down's copy and download while Source data is off
                drillDownExport={props.drillDownExport === true}
                // -ExportData: Export, Source data (and with columns, the drill-down's exports keep to them)
                exportData={exportData}
                fieldDefaults={fieldDefaults}
                chartOptions={chartOptions}
                tips={tips}
                fieldInfo={switchOf(props.fieldInfo)}
                zoneInfo={switchOf(props.zoneInfo)}
                settingInfo={switchOf(props.settingInfo)}
                fieldList={fieldListOf(props.fieldList)}
                zones={zonesOf(props.zones)}
                grow={switchOf(props.grow)}
                // dismissed tips are kept in localStorage per report; the view is kept by this
                // component (address bar and sessionStorage), so pivotkit's persistView and shareLink stay off
                storageKey={props.storageKey || props.id}
                label={props.label || undefined}
                labels={labels}
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
