import React from "react";
import { PivotReport as Report } from "pivotkit-react";
import "pivotkit-react/styles.css";
import "./psu.css";
import { useNarrowWindow } from "./hooks";
import { heightOf, themeOf } from "./prepare";

const NO_ROWS = [];

/*
 * What New-UDPivotReportPlaceholder renders, as New-UDDynamic's -LoadingComponent: pivotkit's own
 * skeleton of the report (a report that is loading its data), with the report's height, theme and
 * language, so nothing moves when the report replaces it. PSU loads this bundle for it at once, so the
 * report's code is ready when the data arrives.
 */
export default function PsuPivotPlaceholder(props) {
    const narrow = useNarrowWindow();
    return (
        <div id={props.id} className={["ud-pivot-report", "ud-pivot-placeholder", props.className].filter(Boolean).join(" ")} style={{ width: "100%", minWidth: 0, ...(props.style || {}) }}>
            <Report loading data={NO_ROWS} locale={props.locale || "en-US"} theme={themeOf(props.theme)} height={heightOf(props.height, narrow)} label={props.label || undefined} />
        </div>
    );
}
