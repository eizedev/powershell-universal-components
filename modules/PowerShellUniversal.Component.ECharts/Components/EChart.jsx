import React, { useEffect, useMemo, useRef, useState } from "react";
import * as echarts from "echarts";
import { buildOption, responsive, optionForWidth, NARROW, TINY } from "./buildOption";
import { ensureTheme } from "./themes";
import { registerLocales, echartsLocale } from "./locales";
import { usePsuTheme, effectiveMode } from "../../../shared/js/psuTheme";
import { defaultLocale } from "../../../shared/js/formatters";
import { toCsv, toXlsxBytes, download, safeFileName } from "../../../shared/js/exporter";
import { pickColumns } from "../../../shared/js/columns";

// components replaced (not merged) on every update, so a live update that changes the shape of the
// chart leaves no stale axes or coordinate systems behind; zoom and legend state are kept
const REPLACED = ["series", "xAxis", "yAxis", "grid", "dataset", "visualMap", "calendar", "radar", "parallel", "parallelAxis", "singleAxis", "matrix", "polar", "angleAxis", "radiusAxis", "markArea"];

// Toolbox icons (SVG paths, 0..24 box): a sheet with "CSV" lines and a grid for Excel
const EXPORT_ICONS = {
    csv: "path://M6 2h9l5 5v15H6z M14 2v6h6 M9 13h8 M9 17h8 M9 9h3",
    xlsx: "path://M4 4h16v16H4z M4 9h16 M4 14h16 M10 4v16",
    fullscreen: "path://M3 9V3h6 M15 3h6v6 M21 15v6h-6 M9 21H3v-6"
};

// element full screen (not on iPhone Safari, which allows it only for videos)
function canFullscreen() {
    return typeof document !== "undefined" && Boolean(document.fullscreenEnabled || document.webkitFullscreenEnabled);
}

function fullscreenElement() {
    return document.fullscreenElement || document.webkitFullscreenElement || null;
}

/*
 * Values from ECharts events turned into something PowerShell can use: time axis values (epoch ms)
 * become ISO strings, category indices become the category names.
 */
function axisValue(chart, axisIndex, value) {
    const option = chart.getOption();
    const axes = option.xAxis || [];
    const axis = axes[axisIndex || 0] || {};
    if (axis.type === "time" && typeof value === "number") {
        return new Date(value).toISOString();
    }
    if (axis.type === "category" && Array.isArray(axis.data) && typeof value === "number") {
        const item = axis.data[Math.max(0, Math.min(axis.data.length - 1, Math.round(value)))];
        return item && typeof item === "object" ? item.value : item;
    }
    return value;
}

function rowOf(rows, params) {
    const data = params && params.data;
    const index = data && typeof data === "object" && !Array.isArray(data) ? data.rowIndex : undefined;
    return index === undefined ? undefined : rows[index];
}

export default function EChart(props) {
    const outer = useRef(null);
    const container = useRef(null);
    const [full, setFull] = useState(false);
    const chartRef = useRef(null);
    const psuTheme = usePsuTheme();
    const mode = effectiveMode(props.theme, psuTheme);
    const locale = defaultLocale(props.locale);
    const rows = Array.isArray(props.data) ? props.data : [];
    // the latest props for event handlers registered once
    const latest = useRef(props);
    latest.current = props;

    const option = useMemo(() => {
        try {
            const exportIcons = {
                ...EXPORT_ICONS,
                onCsv: props.export === false ? undefined : () => exportAs("csv"),
                onXlsx: props.export === false ? undefined : () => exportAs("xlsx"),
                onFullscreen: props.fullscreen === false || !canFullscreen() ? undefined : () => toggleFullscreen()
            };
            const base = buildOption(props, { locale, exportIcons });
            return { value: base, rules: responsive(base, props, { locale }) };
        } catch (e) {
            return { error: e.message };
        }
    }, [props, locale]);

    // CSV/Excel of the rows behind the chart, columns and types from -ExportColumns
    function exportAs(kind) {
        const p = latest.current;
        const name = safeFileName(p.exportFileName || p.title, "chart");
        const data = p.data || [];
        if (kind === "csv") {
            download(`${name}.csv`, toCsv(data, p.exportColumns, defaultLocale(p.locale)), "text/csv;charset=utf-8");
        } else {
            download(`${name}.xlsx`, toXlsxBytes(data, p.exportColumns, p.title || "Data"), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        }
    }

    // the chart alone on the whole screen and back (Esc or the button); zoom, selection and the
    // hidden series stay, because it is the same chart
    function toggleFullscreen() {
        const el = outer.current;
        if (!el) {
            return;
        }
        if (fullscreenElement() === el) {
            (document.exitFullscreen || document.webkitExitFullscreen).call(document);
        } else {
            (el.requestFullscreen || el.webkitRequestFullscreen).call(el);
        }
    }
    useEffect(() => {
        const onChange = () => setFull(fullscreenElement() === outer.current);
        document.addEventListener("fullscreenchange", onChange);
        document.addEventListener("webkitfullscreenchange", onChange);
        return () => {
            document.removeEventListener("fullscreenchange", onChange);
            document.removeEventListener("webkitfullscreenchange", onChange);
        };
    }, []);

    // width class of the container: the option is rebuilt only when it crosses a rule's limit
    const [widthClass, setWidthClass] = useState("wide");
    const classOf = (w) => (w <= TINY ? "tiny" : w <= NARROW ? "narrow" : "wide");

    // create once, dispose on unmount; follow the container's size
    useEffect(() => {
        registerLocales(echarts);
        const chart = echarts.init(container.current, ensureTheme(echarts, mode, psuTheme), { renderer: props.renderer === "svg" ? "svg" : "canvas", locale: echartsLocale(locale) });
        chartRef.current = chart;
        // the ECharts instance on its element, for page scripts and tests: element.echarts.getOption()
        container.current.echarts = chart;
        const resize = new ResizeObserver((entries) => {
            chart.resize();
            setWidthClass(classOf(entries[0].contentRect.width));
        });
        resize.observe(container.current);
        return () => {
            resize.disconnect();
            chart.dispose();
            chartRef.current = null;
        };
    }, [props.renderer, locale]);

    // theme follows PSU's light/dark switch
    useEffect(() => {
        const chart = chartRef.current;
        if (chart) {
            chart.setTheme(ensureTheme(echarts, mode, psuTheme));
        }
    }, [mode, psuTheme.text]);

    // option: series, axes and datasets are replaced, zoom and legend state survive data updates
    useEffect(() => {
        const chart = chartRef.current;
        if (!chart || !option.value) {
            return;
        }
        const width = container.current ? container.current.clientWidth : 0;
        chart.setOption(optionForWidth(option.value, option.rules, width), { replaceMerge: REPLACED });
    }, [option, widthClass]);

    // linked charts: same -Group share tooltip, zoom and legend; a removed group unlinks the chart
    useEffect(() => {
        const chart = chartRef.current;
        if (!chart) {
            return;
        }
        if (props.group) {
            chart.group = String(props.group);
            echarts.connect(chart.group);
        } else {
            chart.group = "";
        }
    }, [props.group]);

    // events to PowerShell and the export buttons
    useEffect(() => {
        const chart = chartRef.current;
        if (!chart) {
            return undefined;
        }
        const call = (name, payload) => {
            const handler = latest.current[name];
            if (typeof handler === "function") {
                handler(payload);
            }
        };
        const onClick = (p) => {
            const data = latest.current.data || [];
            const payload = {
                seriesName: p.seriesName,
                seriesIndex: p.seriesIndex,
                dataIndex: p.dataIndex,
                name: p.name,
                value: Array.isArray(p.value) ? p.value.map((v, i) => (i === 0 ? axisValue(chart, 0, v) : v)) : p.value,
                row: pickColumns(rowOf(data, p), latest.current.eventColumns)
            };
            latest.current.setState({ selected: payload });
            call("onClick", payload);
        };
        const onBrush = (e) => {
            const area = (e.areas || [])[0];
            if (!area || !area.coordRange) {
                call("onSelect", { from: null, to: null });
                return;
            }
            const [a, b] = area.coordRange;
            const payload = { from: axisValue(chart, 0, a), to: axisValue(chart, 0, b) };
            latest.current.setState({ range: payload });
            call("onSelect", payload);
        };
        const onZoom = () => {
            const dz = (chart.getOption().dataZoom || [])[0];
            if (!dz) {
                return;
            }
            const payload = { from: axisValue(chart, 0, dz.startValue), to: axisValue(chart, 0, dz.endValue), start: dz.start, end: dz.end };
            latest.current.setState({ zoom: payload });
            call("onZoom", payload);
        };
        const onLegend = (e) => {
            const payload = { name: e.name, selected: e.selected };
            call("onLegendChange", payload);
        };
        // parallel: dragging along an axis keeps lines in that range; -OnSelect gets their rows
        let areaTimer;
        const onAxisArea = () => {
            clearTimeout(areaTimer);
            areaTimer = setTimeout(() => {
                const data = latest.current.data || [];
                const rows = [];
                let filtered = false;
                chart.getModel().eachSeriesByType("parallel", (series) => {
                    const raw = series.getRawData();
                    const inactive = series.getRawIndicesByActiveState("inactive");
                    filtered = filtered || inactive.length > 0;
                    series.getRawIndicesByActiveState("active").forEach((i) => {
                        const item = raw.getRawDataItem(i);
                        if (item && item.rowIndex !== undefined && data[item.rowIndex]) rows.push(pickColumns(data[item.rowIndex], latest.current.eventColumns));
                    });
                });
                // rows: the selected data rows (all rows when nothing is selected); at most 1000
                const payload = { filtered, count: rows.length, rows: rows.slice(0, 1000) };
                latest.current.setState({ range: { filtered, count: rows.length } });
                call("onSelect", payload);
            }, 250);
        };
        chart.on("axisareaselected", onAxisArea);
        chart.on("click", onClick);
        chart.on("brushEnd", onBrush);
        chart.on("datazoom", onZoom);
        chart.on("legendselectchanged", onLegend);
        return () => {
            clearTimeout(areaTimer);
            chart.off("axisareaselected", onAxisArea);
            chart.off("click", onClick);
            chart.off("brushEnd", onBrush);
            chart.off("datazoom", onZoom);
            chart.off("legendselectchanged", onLegend);
        };
    }, [option]);

    return (
        // -ClassName and -Style as on PSU's own components; -Width wins over a width in -Style
        // full screen: the page's background behind the chart, which is transparent otherwise
        <div
            id={props.id}
            ref={outer}
            className={props.className}
            style={full
                ? { width: "100vw", height: "100vh", boxSizing: "border-box", padding: 16, background: getComputedStyle(document.body).backgroundColor || (mode === "dark" ? "#121212" : "#fff") }
                : { ...(props.style || {}), width: props.width || (props.style && props.style.width) || "100%" }}
        >
            {option.error && <div role="alert" style={{ color: "#d32f2f", padding: 8 }}>EChart: {option.error}</div>}
            <div ref={container} style={{ width: "100%", height: full ? "100%" : props.height || "400px" }} />
        </div>
    );
}
