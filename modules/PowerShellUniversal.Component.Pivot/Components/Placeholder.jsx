import React, { useEffect, useRef, useState } from "react";
import "pivotkit-react/styles.css";
import "./psu.css";
import "./placeholder.css";
import { effectiveMode, usePsuTheme } from "../../../shared/js/psuTheme.js";
import { useNarrowWindow } from "./hooks";
import { heightOf, placeholderLabel, sizeOf, themeOf } from "./prepare";

// widths of the grey bars, so the placeholder reads as fields, buttons and numbers, not as stripes
const FIELDS = ["58%", "46%", "52%", "40%", "64%", "48%", "56%", "44%", "60%", "38%"];
const BUTTONS = ["9em", "8em", "4.5em", "6.5em", "7.5em", "6.5em"];
const ROWS = 7;
const COLUMNS = 5;

function Bone({ className = "", width, style }) {
    return <span className={`ud-pivot-bone ${className}`.trim()} style={{ width, ...style }} />;
}

/*
 * What New-UDPivotReportPlaceholder renders, as New-UDDynamic's -LoadingComponent: the report's frame in
 * its own look while the server builds the data. PSU loads this bundle for it at once, so the report's
 * code is ready when the data arrives. It has the report's height, theme and layout for its width; the
 * screen reader hears "Loading report" (role status, aria-busy).
 */
export default function PsuPivotPlaceholder(props) {
    const narrow = useNarrowWindow();
    const theme = effectiveMode(themeOf(props.theme), usePsuTheme());
    const root = useRef(null);
    const [size, setSize] = useState("wide");
    useEffect(() => {
        const el = root.current;
        if (!el || typeof ResizeObserver === "undefined") return undefined;
        let frame = 0;
        // in the next frame, not in the callback: WebKit reports a ResizeObserver loop otherwise
        const observer = new ResizeObserver(() => {
            cancelAnimationFrame(frame);
            frame = requestAnimationFrame(() => setSize(sizeOf(el.clientWidth)));
        });
        observer.observe(el);
        return () => {
            cancelAnimationFrame(frame);
            observer.disconnect();
        };
    }, []);
    const label = placeholderLabel(props.locale);

    return (
        <div id={props.id} className={["ud-pivot-report", "ud-pivot-placeholder", props.className].filter(Boolean).join(" ")} style={{ width: "100%", minWidth: 0, ...(props.style || {}) }}>
            <div ref={root} className="pk-root" data-pk-theme={theme} data-pk-size={size} lang={label.lang} role="status" aria-busy="true" style={{ height: heightOf(props.height, narrow) }}>
                <span className="pk-sr">{label.text}</span>
                <div className="pk-layout" aria-hidden="true">
                    <div className="pk-panel-slot">
                        <div className="pk-panel">
                            <Bone width="38%" style={{ height: "1.1em", margin: "0.4em 0" }} />
                            <Bone width="86%" />
                            <Bone className="ud-pivot-bone-button" width="100%" style={{ margin: "0.4em 0" }} />
                            {FIELDS.map((width, i) => (
                                <div key={i} className="ud-pivot-bone-field">
                                    <Bone className="ud-pivot-bone-icon" />
                                    <Bone width={width} />
                                </div>
                            ))}
                        </div>
                    </div>
                    <div className="pk-main">
                        <div className="pk-toolbar">
                            {BUTTONS.map((width, i) => (
                                <Bone key={i} className="ud-pivot-bone-button" width={width} />
                            ))}
                        </div>
                        <div className="pk-zones">
                            {["Filters", "Columns", "Rows", "Values"].map((zone, i) => (
                                <div key={zone} className="pk-zone">
                                    <Bone width="5.5em" />
                                    {i > 0 ? <Bone className="ud-pivot-bone-chip" /> : null}
                                </div>
                            ))}
                        </div>
                        <div className="pk-result">
                            <div className="ud-pivot-bone-table">
                                {Array.from({ length: (ROWS + 1) * COLUMNS }, (_, i) => {
                                    const head = i < COLUMNS;
                                    const first = i % COLUMNS === 0;
                                    return (
                                        <div key={i} className={`ud-pivot-bone-cell${head ? " ud-pivot-bone-head" : ""}`}>
                                            <Bone width={first ? "70%" : "55%"} style={first ? undefined : { marginLeft: "auto" }} />
                                        </div>
                                    );
                                })}
                            </div>
                        </div>
                        <div className="pk-status">
                            <Bone width="6em" />
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}
