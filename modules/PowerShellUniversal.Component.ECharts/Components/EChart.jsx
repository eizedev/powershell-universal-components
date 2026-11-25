import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import * as echarts from "echarts";
import { buildOption, dataRows, rowOf, responsive, optionForWidth, tooltipTracksHover, NARROW, TINY } from "./buildOption";
import { tooltipState } from "./tooltipMode";
import { ensureTheme, themeObject, pageFontSize } from "./themes";
import { scaleFonts } from "./fonts";
import { applyView, handOverView, setThemeKeepingView, takeHandedOverView } from "./viewState";
import { fitPlot, insideLabelColors, legendRows, needsFit } from "./layout";
import { registerLocales, echartsLocale } from "./locales";
import { usePsuTheme, effectiveMode } from "../../../shared/js/psuTheme";
import { defaultLocale } from "./formatters.js";
import { toCsv, toXlsxBytes, download, safeFileName } from "./exporter.js";
import { pickColumns } from "../../../shared/js/columns";
import { answerStateRequests } from "../../../shared/js/elementState";
import { useLatest } from "../../../shared/js/useLatest";

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

// CSV/Excel of the rows behind the chart (p: the chart's props), columns and types from -ExportColumns
function exportRows(kind, p) {
    const name = safeFileName(p.exportFileName || p.title, "chart");
    const data = p.data || [];
    if (kind === "csv") {
        download(`${name}.csv`, toCsv(data, p.exportColumns, defaultLocale(p.locale)), "text/csv;charset=utf-8");
    } else {
        download(`${name}.xlsx`, toXlsxBytes(data, p.exportColumns, p.title || "Data"), "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    }
}

// the chart (its outer element) alone on the whole screen and back (Esc or the button); zoom,
// selection and the hidden series stay, because it is the same chart
function toggleFullscreen(el) {
    if (!el) {
        return;
    }
    if (fullscreenElement() === el) {
        (document.exitFullscreen || document.webkitExitFullscreen).call(document);
    } else {
        (el.requestFullscreen || el.webkitRequestFullscreen).call(el);
    }
}

// whether the element is on the whole screen now (the button, Esc or the browser's own way out)
function useFullscreen(ref) {
    const [full, setFull] = useState(false);
    useEffect(() => {
        const onChange = () => setFull(fullscreenElement() === ref.current);
        document.addEventListener("fullscreenchange", onChange);
        document.addEventListener("webkitfullscreenchange", onChange);
        return () => {
            document.removeEventListener("fullscreenchange", onChange);
            document.removeEventListener("webkitfullscreenchange", onChange);
        };
    }, [ref]);
    return full;
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

export default function EChart(props) {
    const outer = useRef(null);
    const container = useRef(null);
    const chartRef = useRef(null);
    const full = useFullscreen(outer);
    const psuTheme = usePsuTheme();
    const mode = effectiveMode(props.theme, psuTheme);
    const locale = defaultLocale(props.locale);
    // -LightTheme / -DarkTheme: the corporate ECharts theme for the current mode
    const customProp = mode === "dark" ? props.darkTheme : props.lightTheme;
    const customKey = customProp ? JSON.stringify(customProp) : "";
    // one object per content: PSU sends the theme anew with every update of the props, which must
    // not set the theme again
    const customTheme = useMemo(() => (customKey ? JSON.parse(customKey) : undefined), [customKey]);
    // the latest props for event handlers registered once, the latest mode for the chart's disposal
    const latest = useLatest(props);
    const latestMode = useLatest(mode);
    // zoom, legend and brush of the chart this one replaces after PSU's light/dark switch (viewState.js)
    const handedView = useRef(null);
    // Get-UDElement: the last click, range and zoom, kept here because PSU asks for them synchronously
    // (shared/js/elementState.js). The component's state holds them too; the wrapper's late POST sends
    // that copy, which PSU ignores
    const elementState = useRef({});
    const remember = useCallback((part) => {
        elementState.current = { ...elementState.current, ...part };
        if (typeof latest.current.setState === "function") latest.current.setState(part);
    }, [latest]);
    useEffect(() => {
        const pubsub = typeof window !== "undefined" ? window.UniversalDashboard : undefined;
        elementState.current = {};
        // only these, never the props: they hold every row
        return answerStateRequests(pubsub, props.id, () => {
            const { selected, range, zoom } = elementState.current;
            return { id: props.id, selected, range, zoom };
        });
    }, [props.id]);
    // -TooltipMode Auto: the element under the pointer, read by the tooltip formatter
    const tipState = useRef(null);
    if (tipState.current === null) {
        tipState.current = tooltipState();
    }

    const option = useMemo(() => {
        try {
            const exportIcons = {
                ...EXPORT_ICONS,
                onCsv: props.export === false ? undefined : () => exportRows("csv", latest.current),
                onXlsx: props.export === false ? undefined : () => exportRows("xlsx", latest.current),
                onFullscreen: props.fullscreen === false || !canFullscreen() ? undefined : () => toggleFullscreen(outer.current)
            };
            // the option only keeps these: the buttons read the props and the element when clicked, the
            // tooltip formatter reads its state on hover, never during render
            // eslint-disable-next-line react-hooks/refs
            const base = buildOption(props, { locale, exportIcons, mode, tooltipState: tipState.current });
            return { value: base, rules: responsive(base, props, { locale }) };
        } catch (e) {
            return { error: e.message };
        }
    }, [props, locale, mode, latest]);

    // layout key of the container: the option is applied again only when the width crosses a rule's
    // limit, or - for charts without a grid, whose plot is placed by size (fitPlot) - when the size or
    // the number of legend lines changes noticeably
    const [layoutKey, setLayoutKey] = useState("wide");
    const latestOption = useLatest(option.value);
    const keyOf = (w, h) => {
        const base = w <= TINY ? "tiny" : w <= NARROW ? "narrow" : "wide";
        const o = latestOption.current;
        return o && needsFit(o) ? `${base}|${Math.round(w / 32)}|${Math.round(h / 16)}|${legendRows(o, w)}` : base;
    };

    // create once, dispose on unmount; follow the container's size
    useEffect(() => {
        registerLocales(echarts);
        const chart = echarts.init(container.current, ensureTheme(echarts, mode, psuTheme, customTheme), { renderer: props.renderer === "svg" ? "svg" : "canvas", locale: echartsLocale(locale) });
        chartRef.current = chart;
        handedView.current = takeHandedOverView(props.id, mode);
        // the ECharts instance on its element, for page scripts and tests: element.echarts.getOption()
        container.current.echarts = chart;
        // resize in the next frame: resizing inside the observer's callback changes the layout it is
        // reporting, and WebKit then reports "ResizeObserver loop completed with undelivered notifications"
        let frame = 0;
        const resize = new ResizeObserver((entries) => {
            const { width, height } = entries[0].contentRect;
            cancelAnimationFrame(frame);
            frame = requestAnimationFrame(() => {
                if (!chart.isDisposed()) {
                    chart.resize();
                    setLayoutKey(keyOf(width, height));
                }
            });
        });
        resize.observe(container.current);
        return () => {
            cancelAnimationFrame(frame);
            resize.disconnect();
            // the mode at disposal, not at creation: a value, not a node, so the rule's case does not apply
            // eslint-disable-next-line react-hooks/exhaustive-deps
            handOverView(props.id, latestMode.current, chart);
            chart.dispose();
            chartRef.current = null;
        };
        // made again only for another renderer or locale: the theme is the starting one, a new theme
        // goes to the living chart (next effect); zoom, legend and brush stay over both (viewState.js)
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [props.renderer, locale]);

    // theme follows PSU's light/dark switch
    useEffect(() => {
        const chart = chartRef.current;
        if (chart) {
            setThemeKeepingView(chart, ensureTheme(echarts, mode, psuTheme, customTheme));
        }
    }, [mode, psuTheme, customTheme]);

    // option: series, axes and datasets are replaced, zoom and legend state survive data updates.
    // After the width rules and the text sizes: the plot of a chart without a grid placed clear of title, toolbox and
    // legend, and labels on fills coloured for contrast with the palette of the current theme.
    useEffect(() => {
        const chart = chartRef.current;
        if (!chart || !option.value) {
            return;
        }
        const width = chart.getWidth();
        // text sizes from the app's stylesheet before the plot is placed, so the layout sees them
        const sized = scaleFonts(optionForWidth(option.value, option.rules, width), pageFontSize());
        const placed = fitPlot(sized, { width, height: chart.getHeight() }, props.options);
        const theme = themeObject(mode, psuTheme, customTheme);
        chart.setOption(insideLabelColors(placed, theme.color, theme.textStyle && theme.textStyle.color), { replaceMerge: REPLACED });
        applyView(chart, handedView.current);
        handedView.current = null;
        // the series are as built again (a toolbox switch to line, bar or stack is gone)
        tipState.current.live = null;
    }, [option, layoutKey, mode, psuTheme, customTheme, props.options]);

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
        // a chart made again (another renderer or locale) joins its group again
    }, [props.group, props.renderer, locale]);

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
            const data = dataRows(latest.current.data);
            const payload = {
                seriesName: p.seriesName,
                seriesIndex: p.seriesIndex,
                dataIndex: p.dataIndex,
                name: p.name,
                value: Array.isArray(p.value) ? p.value.map((v, i) => (i === 0 ? axisValue(chart, 0, v) : v)) : p.value,
                row: pickColumns(rowOf(data, p), latest.current.eventColumns)
            };
            remember({ selected: payload });
            call("onClick", payload);
        };
        const onBrush = (e) => {
            const area = (e.areas || [])[0];
            if (!area || !area.coordRange) {
                remember({ range: null });
                call("onSelect", { from: null, to: null });
                return;
            }
            const [a, b] = area.coordRange;
            const payload = { from: axisValue(chart, 0, a), to: axisValue(chart, 0, b) };
            remember({ range: payload });
            call("onSelect", payload);
        };
        const onZoom = () => {
            const dz = (chart.getOption().dataZoom || [])[0];
            if (!dz) {
                return;
            }
            const payload = { from: axisValue(chart, 0, dz.startValue), to: axisValue(chart, 0, dz.endValue), start: dz.start, end: dz.end };
            remember({ zoom: payload });
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
                const data = dataRows(latest.current.data);
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
                remember({ range: { filtered, count: rows.length } });
                call("onSelect", payload);
            }, 250);
        };
        // -TooltipMode Auto: remember the element under the pointer and redraw the tooltip at once
        // (ECharts computes the tooltip before it reports the new element); helper series without a
        // data index (a line's polyline, an area's fill) do not count as an element. Only charts whose
        // tooltip reads it (tooltipTracksHover) get these handlers; the others keep ECharts' own tooltip.
        const tip = tipState.current;
        tip.hover = null;
        const tracks = tooltipTracksHover(latest.current);
        const redraw = (e) => {
            const ev = e && e.event;
            if (ev && typeof ev.offsetX === "number") {
                // hideTip first: at the same axis position ECharts keeps the content it drew
                // (TooltipView _updateContentNotChangedOnAxis) and would not call the formatter again.
                // escapeConnect: charts of the same -Group have their own layout and hover state; they
                // follow through ECharts' own tooltip sync, not through these pixel positions
                chart.dispatchAction({ type: "hideTip", escapeConnect: true });
                chart.dispatchAction({ type: "showTip", x: ev.offsetX, y: ev.offsetY, escapeConnect: true });
            }
        };
        const onOver = (e) => {
            if (e.componentType === "series" && typeof e.dataIndex === "number") {
                tip.hover = { seriesIndex: e.seriesIndex, dataIndex: e.dataIndex };
                redraw(e);
            }
        };
        const onOut = (e) => {
            if (tip.hover) {
                tip.hover = null;
                redraw(e);
            }
        };
        const onGlobalOut = () => {
            tip.hover = null;
        };
        // the toolbox switched line, bar or stack: the tooltip follows the series as drawn now
        // (stack totals, the gap of stacked bars); Restore and every new option bring the built ones back
        const onMagicType = () => {
            tip.live = (chart.getOption().series || []).map((s) => ({ type: s.type, stack: s.stack || undefined }));
        };
        const onRestore = () => {
            tip.live = null;
        };
        if (tracks) {
            chart.on("mouseover", onOver);
            chart.on("mouseout", onOut);
            chart.on("globalout", onGlobalOut);
        }
        chart.on("magictypechanged", onMagicType);
        chart.on("restore", onRestore);
        chart.on("axisareaselected", onAxisArea);
        chart.on("click", onClick);
        chart.on("brushEnd", onBrush);
        chart.on("datazoom", onZoom);
        chart.on("legendselectchanged", onLegend);
        return () => {
            clearTimeout(areaTimer);
            chart.off("mouseover", onOver);
            chart.off("mouseout", onOut);
            chart.off("globalout", onGlobalOut);
            chart.off("magictypechanged", onMagicType);
            chart.off("restore", onRestore);
            chart.off("axisareaselected", onAxisArea);
            chart.off("click", onClick);
            chart.off("brushEnd", onBrush);
            chart.off("datazoom", onZoom);
            chart.off("legendselectchanged", onLegend);
        };
    }, [option, latest, remember]);

    return (
        // -ClassName and -Style as on PSU's own components; -Width wins over a width in -Style
        // full screen: the page's background behind the chart, which is transparent otherwise
        <div
            id={props.id}
            ref={outer}
            className={props.className}
            style={full
                ? { width: "100vw", height: "100vh", boxSizing: "border-box", padding: 16, background: psuTheme.background || (mode === "dark" ? "#121212" : "#fff") }
                : { ...(props.style || {}), width: props.width || (props.style && props.style.width) || "100%" }}
        >
            {option.error && <div role="alert" style={{ color: "#d32f2f", padding: 8 }}>EChart: {option.error}</div>}
            <div ref={container} style={{ width: "100%", height: full ? "100%" : props.height || "400px" }} />
        </div>
    );
}
