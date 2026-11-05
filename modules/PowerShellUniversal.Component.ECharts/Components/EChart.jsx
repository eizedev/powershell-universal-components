import React, { useEffect, useMemo, useRef } from "react";
import * as echarts from "echarts";
import { buildOption } from "./buildOption";
import { ensureTheme } from "./themes";
import { usePsuTheme, effectiveMode } from "../../../shared/js/psuTheme";
import { defaultLocale } from "../../../shared/js/formatters";
import { toCsv, toXlsxBytes, download, safeFileName } from "../../../shared/js/exporter";

// Toolbox icons (SVG paths, 0..24 box): a sheet with "CSV" lines and a grid for Excel
const EXPORT_ICONS = {
    csv: "path://M6 2h9l5 5v15H6z M14 2v6h6 M9 13h8 M9 17h8 M9 9h3",
    xlsx: "path://M4 4h16v16H4z M4 9h16 M4 14h16 M10 4v16"
};

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
    const container = useRef(null);
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
            const exportIcons = props.export === false ? undefined : { ...EXPORT_ICONS, onCsv: () => exportAs("csv"), onXlsx: () => exportAs("xlsx") };
            return { value: buildOption(props, { locale, exportIcons }) };
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

    // create once, dispose on unmount; follow the container's size
    useEffect(() => {
        const chart = echarts.init(container.current, ensureTheme(echarts, mode, psuTheme), { renderer: props.renderer === "svg" ? "svg" : "canvas" });
        chartRef.current = chart;
        const resize = new ResizeObserver(() => chart.resize());
        resize.observe(container.current);
        return () => {
            resize.disconnect();
            chart.dispose();
            chartRef.current = null;
        };
    }, [props.renderer]);

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
        chart.setOption(option.value, { replaceMerge: ["series", "xAxis", "yAxis", "grid", "dataset", "visualMap", "calendar", "radar"] });
    }, [option]);

    // linked charts: same -Group share tooltip, zoom and legend
    useEffect(() => {
        const chart = chartRef.current;
        if (chart && props.group) {
            chart.group = String(props.group);
            echarts.connect(chart.group);
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
                row: rowOf(data, p)
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
        chart.on("click", onClick);
        chart.on("brushEnd", onBrush);
        chart.on("datazoom", onZoom);
        chart.on("legendselectchanged", onLegend);
        return () => {
            chart.off("click", onClick);
            chart.off("brushEnd", onBrush);
            chart.off("datazoom", onZoom);
            chart.off("legendselectchanged", onLegend);
        };
    }, [option]);

    return (
        <div id={props.id} style={{ width: props.width || "100%" }}>
            {option.error && <div role="alert" style={{ color: "#d32f2f", padding: 8 }}>EChart: {option.error}</div>}
            <div ref={container} style={{ width: "100%", height: props.height || "400px" }} />
        </div>
    );
}
