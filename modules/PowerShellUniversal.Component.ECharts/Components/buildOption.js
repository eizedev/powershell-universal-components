import { columnsOf, getter, resolveColumn, resolveColumns } from "../../../shared/js/columns.js";
import { formatter, labelFormatSpec } from "../../../shared/js/formatters.js";
import { html, joinHtml, trusted } from "../../../shared/js/html.js";
import { compileTemplate, columnsTemplate } from "../../../shared/js/template.js";

/*
 * Turns the simple parameters of New-UDEChart (chartType, x, y, groupBy, ...) and the rows into an
 * Apache ECharts option. The user's own -Options are merged over the result afterwards (mergeOptions),
 * so anything ECharts can do stays reachable. Pure function: no DOM, no ECharts instance, testable
 * with node --test.
 *
 * Series data items carry rowIndex (the row they came from) so events can hand the row back to
 * PowerShell; above LARGE points they are plain arrays for speed and events carry values only.
 */

export const LARGE = 20000;

const CARTESIAN = new Set(["line", "area", "bar", "scatter", "step"]);

// translucent fills for areas and bands that sit behind the data
const SHADE = "rgba(128,128,128,0.14)";
const ISO_DATE = /^\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?)?$/;

// ---- helpers ----------------------------------------------------------------------------------

function list(value) {
    if (value === undefined || value === null || value === "") {
        return [];
    }
    return Array.isArray(value) ? value : [value];
}

function num(value) {
    if (value === null || value === undefined || value === "") {
        return null;
    }
    const n = typeof value === "number" ? value : Number(value);
    return isNaN(n) ? null : n;
}

function isDateLike(value) {
    return typeof value === "string" && ISO_DATE.test(value);
}

function axisTypeFor(values, requested, chartType) {
    if (requested && requested !== "auto") {
        return requested;
    }
    const sample = values.find((v) => v !== null && v !== undefined && v !== "");
    if (isDateLike(sample)) {
        return "time";
    }
    if (chartType === "scatter" && typeof sample === "number") {
        return "value";
    }
    return "category";
}

function unique(values) {
    const seen = new Set();
    const out = [];
    for (const v of values) {
        const key = v === null || v === undefined ? "" : String(v);
        if (!seen.has(key)) {
            seen.add(key);
            out.push(v === null || v === undefined ? "" : v);
        }
    }
    return out;
}

export function quantile(sorted, q) {
    if (sorted.length === 0) {
        return null;
    }
    const pos = (sorted.length - 1) * q;
    const lo = Math.floor(pos);
    const hi = Math.ceil(pos);
    return lo === hi ? sorted[lo] : sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}

// Tukey boxplot: [min, Q1, median, Q3, max] within 1.5 IQR, plus the outliers beyond
export function boxStats(values) {
    const sorted = values.filter((v) => v !== null).sort((a, b) => a - b);
    if (sorted.length === 0) {
        return { box: [null, null, null, null, null], outliers: [] };
    }
    const q1 = quantile(sorted, 0.25);
    const q2 = quantile(sorted, 0.5);
    const q3 = quantile(sorted, 0.75);
    const iqr = q3 - q1;
    const lowFence = q1 - 1.5 * iqr;
    const highFence = q3 + 1.5 * iqr;
    const inside = sorted.filter((v) => v >= lowFence && v <= highFence);
    return {
        box: [inside[0], q1, q2, q3, inside[inside.length - 1]],
        outliers: sorted.filter((v) => v < lowFence || v > highFence)
    };
}

// The name to show for a column: as the user wrote it (-Y Opened), not as PSU camelCased it (opened)
export function displayName(key, requested) {
    for (const r of list(requested)) {
        if (typeof r === "string" && r.toLowerCase() === String(key).toLowerCase()) {
            return r;
        }
    }
    return key;
}

function isPlainObject(v) {
    return v !== null && typeof v === "object" && !Array.isArray(v);
}

/*
 * Deep merge of the user's -Options over the generated option. Objects merge key by key; arrays
 * merge element by element (series[0] of the user changes the first generated series); an object
 * given where the option has an array is merged into every element (yAxis: {...} for both axes).
 * Anything else replaces.
 */
export function mergeOptions(base, user) {
    if (user === undefined || user === null) {
        return base;
    }
    if (Array.isArray(base) && Array.isArray(user)) {
        const out = base.slice();
        user.forEach((u, i) => {
            out[i] = i < base.length ? mergeOptions(base[i], u) : u;
        });
        return out;
    }
    if (Array.isArray(base) && isPlainObject(user)) {
        return base.map((b) => mergeOptions(b, user));
    }
    if (isPlainObject(base) && isPlainObject(user)) {
        const out = { ...base };
        for (const [k, v] of Object.entries(user)) {
            out[k] = k in base ? mergeOptions(base[k], v) : v;
        }
        return out;
    }
    return user;
}

// ---- common parts ------------------------------------------------------------------------------

function valueFormatter(props, locale) {
    return formatter(props.format, locale);
}

// Value labels: -LabelFormat, else -Format with the short form for large numbers only, so
// 9.850.000,00 € becomes 9,9 Mio. € while 99,97 stays 99,97
function labelFormatter(props, locale) {
    if (props.labelFormat) {
        return formatter(props.labelFormat, locale);
    }
    const full = formatter(props.format || "number", locale);
    const short = formatter(labelFormatSpec(props.format), locale);
    return (v) => (typeof v === "number" && Math.abs(v) >= 10000 ? short(v) : full(v));
}

function titleOf(props) {
    if (!props.title && !props.subtitle) {
        return undefined;
    }
    return { text: props.title || "", subtext: props.subtitle || "", left: "center" };
}

function legendOf(props, hasSeriesNames) {
    const position = (props.legend || (hasSeriesNames ? "bottom" : "none")).toLowerCase();
    if (position === "none") {
        return { show: false };
    }
    // scroll (default): one line with paging arrows; plain: wraps over as many lines as needed
    const legend = { show: true, type: String(props.legendType || "scroll").toLowerCase() === "plain" ? "plain" : "scroll" };
    if (position === "top") {
        legend.top = props.title ? 50 : 10;
    } else if (position === "left" || position === "right") {
        legend[position] = 10;
        legend.orient = "vertical";
        legend.top = "middle";
    } else {
        legend.bottom = 0;
    }
    return legend;
}

function gridOf(props, legend) {
    return {
        left: 12,
        // an x axis name sits right of the axis end: room for it (about 7 px per character)
        right: Math.max(String(props.zoomAxis || "x").toLowerCase() !== "x" && zoomMode(props).slider ? 40 : 24, props.xTitle && !props.horizontal ? 16 + 7 * String(props.xTitle).length : 0),
        // axis names sit above the axes: one more row so they stay clear of the toolbox
        top: (props.title ? (props.subtitle ? 80 : 60) : legend.show && legend.top !== undefined ? 56 : props.toolbox === false ? 24 : 48) + (props.dataLabels ? 16 : 0) + (props.yTitle || props.secondaryTitle ? 14 : 0),
        bottom: (legend.show && legend.bottom !== undefined ? 30 : 8) + (zoomMode(props).slider ? 34 : 0),
        containLabel: true
    };
}

/*
 * -Zoom Auto (default): wheel zoom everywhere, plus the slider with its data preview where there is
 * a lot to scroll through - a time axis or more than 60 categories. props.zoomAuto carries that
 * decision from the builder.
 */
function zoomMode(props) {
    let mode = String(props.zoom || "auto").toLowerCase();
    if (mode === "auto") {
        mode = props.zoomAuto ? "both" : "inside";
    }
    return { inside: mode === "inside" || mode === "both", slider: mode === "slider" || mode === "both" };
}

/*
 * -ZoomAxis: X zooms the axis the data runs along (default; for horizontal bars the vertical one),
 * Y the value axis (to look into small bars next to large ones), Both both. On the value axis the
 * mouse wheel needs Shift, so it does not fight the category zoom.
 */
function dataZoomOf(props, horizontal, legendBottom = false) {
    const mode = zoomMode(props);
    const which = String(props.zoomAxis || "x").toLowerCase();
    const axes = [];
    if (which === "x" || which === "both") {
        axes.push({ axis: horizontal ? { yAxisIndex: 0 } : { xAxisIndex: [0] }, vertical: horizontal, value: false });
    }
    if (which === "y" || which === "both") {
        axes.push({ axis: horizontal ? { xAxisIndex: [0] } : { yAxisIndex: [0] }, vertical: !horizontal, value: true });
    }
    const zooms = [];
    for (const { axis, vertical, value } of axes) {
        if (mode.inside) {
            zooms.push({ type: "inside", ...axis, filterMode: "none", zoomOnMouseWheel: value && which === "both" ? "shift" : true, moveOnMouseMove: !(value && which === "both") });
        }
        if (mode.slider) {
            zooms.push(vertical
                ? { type: "slider", ...axis, filterMode: "none", width: 16, right: 4, orient: "vertical" }
                : { type: "slider", ...axis, filterMode: "none", height: 22, bottom: legendBottom ? 34 : 8 });
        }
    }
    return zooms;
}

export function toolboxOf(props, cartesian, exportIcons) {
    if (props.toolbox === false) {
        return undefined;
    }
    const feature = {};
    if (cartesian) {
        feature.dataZoom = { yAxisIndex: "none" };
        if (props.brush) {
            feature.brush = { type: ["lineX", "clear"] };
        }
        feature.magicType = { type: ["line", "bar", "stack"] };
    }
    feature.restore = {};
    feature.saveAsImage = { name: props.exportFileName || props.title || "chart", pixelRatio: 2 };
    // custom features need their onclick in the very first setOption, or ECharts fails to bind it
    if (exportIcons && exportIcons.onCsv && exportIcons.onXlsx) {
        feature.myCsv = { show: true, title: "CSV", icon: exportIcons.csv, onclick: exportIcons.onCsv };
        feature.myXlsx = { show: true, title: "Excel", icon: exportIcons.xlsx, onclick: exportIcons.onXlsx };
    }
    return { show: true, right: 8, top: props.title ? 34 : 0, feature };
}

/*
 * -MarkArea: shaded ranges such as maintenance windows or outages:
 * @{ from = '2026-11-03T02:00'; to = '2026-11-03T04:00'; name = 'Maintenance'; color = '...' }
 * axis = 'y' shades a value range (e.g. the SLA corridor) instead.
 */
function markAreaOf(props, xType, horizontal) {
    const items = list(props.markArea).filter(isPlainObject);
    if (items.length === 0) {
        return undefined;
    }
    const value = (v, axis) => (axis === "x" && xType === "time" && typeof v === "string" ? Date.parse(v) : v);
    return {
        silent: false,
        label: { position: "insideTop", fontSize: 11 },
        data: items.map((m) => {
            const axis = (m.axis || "x").toLowerCase();
            const key = (axis === "x") !== horizontal ? "xAxis" : "yAxis";
            return [
                { name: m.name || "", [key]: value(m.from, axis), itemStyle: { color: m.color || SHADE } },
                { [key]: value(m.to, axis) }
            ];
        })
    };
}

/*
 * markLine entries from PowerShell: "median", "average", "min", "max" (of each series) or
 * @{ value = 48; name = 'SLA'; axis = 'y' } for a fixed line.
 */
function markLineOf(props, horizontal, fmt, seriesIndex = 0) {
    const items = list(props.markLine);
    if (items.length === 0) {
        return undefined;
    }
    const data = [];
    for (const item of items) {
        if (typeof item === "string") {
            const t = item.toLowerCase();
            if (["median", "average", "min", "max"].includes(t)) {
                data.push({ type: t, name: t.charAt(0).toUpperCase() + t.slice(1) });
            }
        } else if (isPlainObject(item) && item.value !== undefined) {
            const axis = (item.axis || (horizontal ? "x" : "y")).toLowerCase();
            const line = { name: item.name || "", [axis === "x" ? "xAxis" : "yAxis"]: item.value };
            if (item.color) {
                line.lineStyle = { color: item.color };
            }
            data.push(line);
        }
    }
    return {
        symbol: ["none", "none"],
        label: { formatter: (p) => `${p.name ? p.name + ": " : ""}${fmt ? fmt(p.value) : p.value}`, position: seriesIndex % 2 === 0 ? "insideEndTop" : "insideEndBottom" },
        lineStyle: { type: "dashed" },
        data
    };
}

// ---- axis breaks -----------------------------------------------------------------------------------

/*
 * -Breaks / -YBreaks: @{ start; end; gap } from PowerShell. On a time axis start and end may be ISO
 * dates; ECharts wants epoch milliseconds there. gap defaults to a thin '1%' so the cut stays visible.
 */
/*
 * -MarkPoint: pins on single values. 'min', 'max', 'average' pin that value of every series;
 * @{ x = 'Thu'; y = 306; label = 'Outage' } pins a given point (on -Series, or the first series).
 */
function markPointOf(props, seriesName, isFirst, fmt) {
    const data = [];
    for (const item of list(props.markPoint)) {
        if (typeof item === "string") {
            const t = item.toLowerCase();
            if (["min", "max", "average"].includes(t)) {
                data.push({ type: t, name: t.charAt(0).toUpperCase() + t.slice(1) });
            }
        } else if (isPlainObject(item) && item.x !== undefined && item.y !== undefined) {
            const target = item.series === undefined ? isFirst : String(item.series) === seriesName;
            if (target) {
                data.push({ coord: [item.x, item.y], value: item.label ?? item.y, name: item.label ?? "" });
            }
        }
    }
    if (data.length === 0) {
        return undefined;
    }
    return {
        symbol: "pin",
        symbolSize: 46,
        label: { color: "#fff", fontSize: 11, formatter: (p) => (typeof p.value === "number" ? (fmt ? fmt(p.value) : String(Math.round(p.value * 100) / 100)) : String(p.value ?? "")) },
        data
    };
}

export function axisBreaks(list_, axisType) {
    const items = list(list_);
    if (items.length === 0 || axisType === "category") {
        return undefined;
    }
    const toValue = (v) => (axisType === "time" && typeof v === "string" ? Date.parse(v) : num(v));
    const out = items
        .filter(isPlainObject)
        .map((b) => ({ start: toValue(b.start), end: toValue(b.end), gap: b.gap ?? "1%" }))
        .filter((b) => b.start !== null && b.end !== null && !isNaN(b.start) && !isNaN(b.end) && b.end > b.start);
    // ECharts does not allow mixing percentage and absolute gaps within one axis
    if (out.some((b) => typeof b.gap === "string") && out.some((b) => typeof b.gap !== "string")) {
        out.forEach((b) => {
            b.gap = typeof b.gap === "string" ? b.gap : "1%";
        });
    }
    return out.length ? out : undefined;
}

// ---- cartesian: line, area, bar, scatter, step --------------------------------------------------

// ---- small statistics helpers --------------------------------------------------------------------

function toTime(v) {
    if (typeof v === "number") return v;
    const t = Date.parse(v);
    return Number.isNaN(t) ? null : t;
}

// least squares y = slope * x + intercept; undefined with fewer than two distinct x
export function linearFit(points) {
    const n = points.length;
    if (n < 2) return undefined;
    // centred on the means: timestamps squared would lose all precision
    const mx = points.reduce((a, p) => a + p[0], 0) / n;
    const my = points.reduce((a, p) => a + p[1], 0) / n;
    let sxx = 0, sxy = 0;
    for (const [x, y] of points) {
        sxx += (x - mx) * (x - mx);
        sxy += (x - mx) * (y - my);
    }
    if (sxx === 0) return undefined;
    const slope = sxy / sxx;
    return { slope, intercept: my - slope * mx };
}

function medianStep(sortedXs) {
    const steps = [];
    for (let i = 1; i < sortedXs.length; i++) steps.push(sortedXs[i] - sortedXs[i - 1]);
    steps.sort((a, b) => a - b);
    return steps.length ? steps[Math.floor(steps.length / 2)] : 0;
}

function cartesian(props_, rows, keys, ctx) {
    // -Normalize is a stack that sums to 100 %: everything that applies to stacks applies
    let props = props_.normalize ? { ...props_, stacked: true } : props_;
    const type = String(props.chartType).toLowerCase();
    const horizontal = Boolean(props.horizontal) && type === "bar";
    const xKey = resolveColumn(props.x, keys) ?? keys[0];
    const yKeys = resolveColumns(props.y, keys);
    const groupKey = resolveColumn(props.groupBy, keys);
    const secondary = new Set(resolveColumns(props.secondaryY, keys));
    const sizeKey = resolveColumn(props.size, keys);
    if (yKeys.length === 0) {
        // all numeric columns except x and the group
        keys.filter((k) => k !== xKey && k !== groupKey && rows.some((r) => typeof r[k] === "number")).forEach((k) => yKeys.push(k));
    }
    const xValues = rows.map((r) => r[xKey]);
    const xType = axisTypeFor(xValues, props.xAxisType, type);
    // decided here because it depends on the axis: see zoomMode
    props = { ...props, zoomAuto: xType === "time" || unique(xValues).length > 60 };
    const fmt = valueFormatter(props, ctx.locale);
    const lfmt = labelFormatter(props, ctx.locale);
    // the axis pointer shows the exact value under the mouse: never a raw float
    const pointerFmt = fmt || formatter("number", ctx.locale);
    const xFmt = formatter(props.xFormat || (xType === "time" ? "date" : undefined), ctx.locale);
    const large = rows.length > LARGE;
    const seriesType = type === "area" || type === "step" ? "line" : type;
    const categories = xType === "category" ? unique(xValues).map(String) : undefined;

    // one series per y column, or per group value when -GroupBy is given (long data)
    const seriesDefs = [];
    if (groupKey) {
        const y = yKeys[0];
        // groups in natural order (P1, P2 ... P10), so legend and colours do not depend on row order
        const groups = unique(rows.map((r) => r[groupKey])).sort((a, b) => String(a).localeCompare(String(b), undefined, { numeric: true }));
        for (const g of groups) {
            seriesDefs.push({ name: String(g), y, filter: (r) => String(r[groupKey] ?? "") === String(g) });
        }
    } else {
        for (const y of yKeys) {
            seriesDefs.push({ name: displayName(y, props.y), y, filter: () => true });
        }
    }

    const series = seriesDefs.map((def, i) => {
        let data;
        if (categories) {
            // aligned to the categories; missing combinations stay empty (null)
            const byCat = new Map();
            rows.forEach((r, rowIndex) => {
                if (def.filter(r)) {
                    byCat.set(String(r[xKey] ?? ""), { value: num(r[def.y]), rowIndex });
                }
            });
            data = categories.map((c) => byCat.get(c) ?? { value: null });
            if (large) {
                data = data.map((d) => d.value);
            }
        } else {
            data = [];
            rows.forEach((r, rowIndex) => {
                if (def.filter(r)) {
                    const point = horizontal ? [num(r[def.y]), r[xKey]] : [xType === "value" ? num(r[xKey]) : r[xKey], num(r[def.y])];
                    if (sizeKey) {
                        point.push(num(r[sizeKey]));
                    }
                    data.push(large ? point : { value: point, rowIndex });
                }
            });
        }
        const s = {
            type: seriesType,
            name: def.name,
            data,
            emphasis: { focus: "series" },
            yAxisIndex: secondary.has(def.y) ? 1 : 0
        };
        if (seriesType === "line") {
            s.smooth = Boolean(props.smooth);
            s.showSymbol = !large && data.length <= 200;
            if (type === "area") {
                s.areaStyle = { opacity: 0.25 };
            }
            if (type === "step") {
                s.step = "end";
            }
            if (large) {
                s.sampling = "lttb";
            }
        }
        if (seriesType === "bar" && large) {
            s.large = true;
        }
        if (seriesType === "scatter" && sizeKey) {
            // bubble: area grows with -Size (square root scale, 6 to 48 px)
            const sizes = rows.map((r) => num(r[sizeKey])).filter((v) => v !== null && v >= 0);
            const maxSize = Math.max(1, ...sizes);
            s.symbolSize = (v) => 6 + 42 * Math.sqrt(Math.max(0, (Array.isArray(v) ? v[2] : 0) || 0) / maxSize);
            s.itemStyle = { opacity: 0.75 };
            s.emphasis = { focus: "series", label: { show: true, formatter: (p) => p.seriesName, position: "top" } };
        } else if (seriesType === "scatter") {
            s.symbolSize = 8;
            if (large) {
                s.large = true;
            }
        }
        if (props.stacked && seriesType !== "scatter") {
            s.stack = secondary.has(def.y) ? "secondary" : "total";
        }
        if (props.dataLabels) {
            s.label = {
                show: true,
                position: seriesType === "bar" ? (props.stacked ? "inside" : horizontal ? "right" : "top") : "top",
                // inside a coloured bar the page's text colour can be unreadable
                color: seriesType === "bar" && props.stacked ? "#fff" : undefined,
                formatter: (p) => {
                    const v = Array.isArray(p.value) ? p.value[horizontal ? 0 : 1] : p.value;
                    // in a 100 % stack, a label in a sliver below 4 % only collides with its neighbours
                    if (props.normalize && typeof v === "number" && v < 4) {
                        return "";
                    }
                    return v === null || v === undefined ? "" : lfmt(v);
                }
            };
            s.labelLayout = { hideOverlap: true };
        }
        if (props.negativeColor && seriesType === "bar") {
            s.itemStyle = {
                color: (p) => {
                    const v = Array.isArray(p.value) ? p.value[horizontal ? 0 : 1] : p.value;
                    return v < 0 ? props.negativeColor : p.color;
                }
            };
        }
        const mp = props.markPoint ? markPointOf(props, def.name, i === 0, fmt) : undefined;
        if (mp && !horizontal) {
            s.markPoint = mp;
        }
        if (i === 0) {
            const ml = markLineOf(props, horizontal, fmt);
            if (ml) {
                s.markLine = ml;
            }
            const ma = markAreaOf(props, xType, horizontal);
            if (ma) {
                s.markArea = ma;
            }
        }
        return s;
    });
    // -Band Lower, Upper: a shaded range (forecast, confidence, normal operating range) behind the
    // series, drawn as an invisible base plus the stacked difference
    const band = resolveColumns(props.band, keys);
    if (band.length === 2 && !horizontal) {
        const [lowKey, highKey] = band;
        const point = (r, v) => (categories ? v : [xType === "value" ? num(r[xKey]) : r[xKey], v]);
        const low = categories ? categories.map((c) => { const r = rows.find((x) => String(x[xKey] ?? "") === c); return r ? num(r[lowKey]) : null; }) : rows.map((r) => point(r, num(r[lowKey])));
        const width = categories
            ? categories.map((c) => { const r = rows.find((x) => String(x[xKey] ?? "") === c); return r && num(r[highKey]) !== null && num(r[lowKey]) !== null ? num(r[highKey]) - num(r[lowKey]) : null; })
            : rows.map((r) => point(r, num(r[highKey]) !== null && num(r[lowKey]) !== null ? num(r[highKey]) - num(r[lowKey]) : null));
        const bandName = props.bandName || `${displayName(lowKey, props.band)} - ${displayName(highKey, props.band)}`;
        series.unshift(
            { type: "line", name: bandName, data: width, stack: "__band", lineStyle: { opacity: 0 }, symbol: "none", areaStyle: { color: SHADE }, tooltip: { show: false }, emphasis: { disabled: true }, silent: true },
            { type: "line", name: bandName, data: low, stack: "__band", lineStyle: { opacity: 0 }, symbol: "none", tooltip: { show: false }, emphasis: { disabled: true }, silent: true }
        );
        // the base must come first in the stack: ECharts stacks in series order
        const [w, l] = series.splice(0, 2);
        series.unshift(l, w);
    }

    // -Normalize: every category sums to 100 %; the original value stays on the item for the tooltip
    if (props.normalize && categories) {
        const valueOf = (d) => (d && typeof d === "object" ? d.value : d);
        const totals = categories.map((_, i) => series.reduce((sum, s) => sum + Math.abs(valueOf(s.data[i]) || 0), 0));
        series.forEach((s) => {
            s.stack = "total";
            s.data = s.data.map((d, i) => {
                const raw = valueOf(d);
                // unrounded: rounded shares can sum to 100.01, and ECharts clips a bar beyond the axis max
                const share = raw === null || raw === undefined || totals[i] === 0 ? null : (raw / totals[i]) * 100;
                return { ...(d && typeof d === "object" ? d : {}), value: share, raw };
            });
        });
    }

    // -Trend Linear: a least-squares line per series; on a time or value axis it runs on for -Forecast
    // steps, or until it reaches -TrendTarget (a full datastore, a licence limit), marked with the date
    if (String(props.trend || "").toLowerCase() === "linear" && !horizontal && !props.normalize) {
        const valueOf = (d) => (d && typeof d === "object" ? d.value : d);
        series.slice().forEach((s) => {
            if (s.stack === "__band") {
                return;
            }
            const pts = [];
            s.data.forEach((d, i) => {
                const v = valueOf(d);
                if (categories) {
                    if (num(v) !== null) pts.push([i, num(v)]);
                } else if (Array.isArray(v)) {
                    const x = xType === "time" ? toTime(v[0]) : num(v[0]);
                    if (x !== null && num(v[1]) !== null) pts.push([x, num(v[1])]);
                }
            });
            const fit = linearFit(pts);
            if (!fit) {
                return;
            }
            const xs = pts.map((p) => p[0]).sort((a, b) => a - b);
            const first = xs[0];
            let last = xs[xs.length - 1];
            let hit;
            if (!categories) {
                const step = medianStep(xs);
                if (props.forecast > 0 && step > 0) {
                    last += step * props.forecast;
                }
                const target = num(props.trendTarget);
                if (target !== null && fit.slope !== 0) {
                    const at = (target - fit.intercept) / fit.slope;
                    // only ahead of the data and within five times its span
                    if (at > xs[xs.length - 1] && at - first <= 5 * Math.max(1, xs[xs.length - 1] - first)) {
                        hit = at;
                        last = Math.max(last, at);
                    }
                }
            }
            const line = categories
                ? categories.map((_, i) => fit.slope * i + fit.intercept)
                : [[first, fit.slope * first + fit.intercept], [last, fit.slope * last + fit.intercept]];
            const t = {
                type: "line",
                name: props.trendName || `${s.name} (trend)`,
                data: line,
                yAxisIndex: s.yAxisIndex,
                symbol: "none",
                smooth: false,
                lineStyle: { type: "dashed", width: 1.5 },
                emphasis: { disabled: true },
                tooltip: { show: false },
                z: 1
            };
            if (hit !== undefined) {
                const when = formatter(xType === "time" ? "date" : "number", ctx.locale)(hit);
                t.markPoint = { symbol: "pin", symbolSize: 36, data: [{ coord: [hit, num(props.trendTarget)], value: when, label: { show: false } }], label: { show: false }, tooltip: { show: true, formatter: () => html`${s.name}: ${fmt ? fmt(num(props.trendTarget)) : props.trendTarget} ≈ ${when}` } };
                t.markLine = { symbol: "none", silent: true, label: { formatter: () => when, position: "insideEndTop" }, data: [{ xAxis: hit }], lineStyle: { type: "dotted" } };
            }
            series.push(t);
        });
    }

    // markLine statistics belong to every series, fixed lines once
    if (list(props.markLine).some((m) => typeof m === "string")) {
        series.slice(1).forEach((s, i) => {
            s.markLine = markLineOf({ markLine: list(props.markLine).filter((m) => typeof m === "string") }, horizontal, fmt, i + 1);
        });
    }

    const valueAxis = (index) => ({
        type: props.logScale ? "log" : "value",
        breaks: index === 0 ? axisBreaks(props.yBreaks, "value") : undefined,
        breakArea: index === 0 && props.yBreaks ? { itemStyle: { color: "rgba(128,128,128,0.12)", borderColor: "rgba(128,128,128,0.35)", borderWidth: 1 }, zigzagAmplitude: 2 } : undefined,
        min: index === 0 ? props.yMin : undefined,
        max: index === 0 ? props.yMax : undefined,
        name: index === 0 ? props.yTitle : props.secondaryTitle,
        axisLabel: fmt ? { formatter: (v) => fmt(v) } : {},
        splitLine: { show: index === 0 }
    });
    const categoryAxis = {
        type: xType,
        breaks: axisBreaks(props.breaks, xType),
        breakArea: props.breaks ? { itemStyle: { color: "rgba(128,128,128,0.12)", borderColor: "rgba(128,128,128,0.35)", borderWidth: 1 }, zigzagAmplitude: 2 } : undefined,
        name: props.xTitle,
        data: categories,
        boundaryGap: seriesType === "bar" || xType === "category" ? undefined : false,
        axisLabel: props.xFormat && xFmt ? { formatter: (v) => xFmt(v), hideOverlap: true } : { hideOverlap: true }
    };
    const yAxes = secondary.size > 0 ? [valueAxis(0), valueAxis(1)] : [valueAxis(0)];
    if (props.normalize) {
        const pct100 = formatter("percent100:0", ctx.locale);
        yAxes[0] = { ...yAxes[0], max: (extent) => Math.max(100, extent.max), axisLabel: { formatter: (v) => pct100(v) } };
    }
    const legend = legendOf(props, series.length > 1);
    return {
        title: titleOf(props),
        legend,
        grid: gridOf(props, legend),
        tooltip: {
            trigger: seriesType === "scatter" ? "item" : "axis",
            // normalized: the share and the original value
            formatter: props.normalize
                ? (ps) => {
                    const pctF = formatter("percent100:1", ctx.locale);
                    const items = Array.isArray(ps) ? ps : [ps];
                    return html`${items[0] ? items[0].name : ""}<br/>${joinHtml(items.map((p) => html`${trusted(p.marker)}${p.seriesName}: <b>${pctF(p.value)}</b> (${fmt ? fmt(p.data.raw) : p.data.raw})`), "<br/>")}`;
                }
                : undefined,
            axisPointer: { type: seriesType === "bar" ? "shadow" : "cross", label: { formatter: (p) => String((horizontal ? p.axisDimension === "y" : p.axisDimension === "x") ? (xFmt && xType !== "category" ? xFmt(p.value) : p.value) : pointerFmt(p.value)) } },
            valueFormatter: fmt ? (v) => fmt(Array.isArray(v) ? v[v.length - 1] : v) : undefined,
            confine: true
        },
        xAxis: horizontal ? yAxes : categoryAxis,
        yAxis: horizontal ? { ...categoryAxis, inverse: true } : yAxes,
        dataZoom: dataZoomOf(props, horizontal, legend.show && legend.bottom !== undefined),
        brush: props.brush ? { xAxisIndex: "all", brushLink: "all", brushType: "lineX", outOfBrush: { colorAlpha: 0.2 } } : undefined,
        toolbox: toolboxOf(props, true, ctx.exportIcons),
        series
    };
}

// ---- sparkline: a tiny trend without axes, for tiles and tables ----------------------------------

function sparkline(props, rows, keys, ctx) {
    const base = cartesian({ ...props, legend: "none", toolbox: false, zoom: "none", dataLabels: false, markLine: undefined }, rows, keys, ctx);
    const last = (data) => {
        for (let i = data.length - 1; i >= 0; i--) {
            const v = data[i] && typeof data[i] === "object" && !Array.isArray(data[i]) ? data[i].value : data[i];
            if (v !== null && v !== undefined) {
                return i;
            }
        }
        return -1;
    };
    base.series.forEach((s) => {
        s.smooth = props.smooth !== false;
        s.showSymbol = false;
        s.symbolSize = 6;
        s.lineStyle = { width: 1.5 };
        if (s.type === "line" && props.chartType !== "line") {
            s.areaStyle = { opacity: 0.2 };
        }
        const i = last(s.data);
        if (i >= 0) {
            // the latest value stands out
            s.markPoint = { symbol: "circle", symbolSize: 6, label: { show: false }, data: [{ coord: Array.isArray(s.data[i].value) ? s.data[i].value : [i, s.data[i].value ?? s.data[i]] }] };
        }
    });
    const hide = (axis) => ({ ...axis, show: false, name: undefined });
    return {
        ...base,
        title: undefined,
        grid: { left: 2, right: 6, top: 4, bottom: 2, containLabel: false },
        xAxis: Array.isArray(base.xAxis) ? base.xAxis.map(hide) : hide(base.xAxis),
        yAxis: Array.isArray(base.yAxis) ? base.yAxis.map((a) => ({ ...hide(a), scale: true })) : { ...hide(base.yAxis), scale: true },
        tooltip: { ...base.tooltip, axisPointer: { type: "line" }, position: (pt) => [pt[0] + 10, 0] },
        dataZoom: [],
        toolbox: undefined,
        brush: undefined
    };
}

// ---- small multiples: one small chart per value of -Facet, shared scale ------------------------

function facets(props, rows, keys, ctx) {
    const facetKey = resolveColumn(props.facet, keys);
    const values = unique(rows.map((r) => r[facetKey])).map(String);
    const columns = Math.max(1, Math.min(props.facetColumns || Math.min(4, values.length), values.length));
    const rowsOfGrid = Math.ceil(values.length / columns);
    const parts = values.map((v) => cartesian({ ...props, facet: undefined, title: undefined, toolbox: false, legend: "none", zoom: "none", brush: false }, rows.filter((r) => String(r[facetKey] ?? "") === v), keys, ctx));
    // one value scale for all: comparable at a glance
    const allValues = parts.flatMap((p) => p.series.flatMap((s) => s.data.map((d) => (d && typeof d === "object" && !Array.isArray(d) ? d.value : d)).map((v) => (Array.isArray(v) ? v[1] : v)))).filter((v) => typeof v === "number");
    const max = props.yMax ?? (allValues.length ? Math.max(...allValues) : undefined);
    const min = props.yMin ?? (allValues.length && Math.min(...allValues) < 0 ? Math.min(...allValues) : 0);
    // layout in percent of the chart height (ECharts has no calc()); -Height in px gives the scale
    const heightPx = parseInt(String(props.height || "400"), 10) || 400;
    const pct = (px) => (px / heightPx) * 100;
    const headPct = pct((props.title ? 50 : 8) + (props.toolbox === false ? 0 : 28));
    const legendPct = parts[0] && parts[0].series.length > 1 ? pct(30) : pct(6);
    const labelPct = pct(18); // the small title above each cell
    const cellH = (100 - headPct - legendPct) / rowsOfGrid;
    const cellW = 100 / columns;
    const grids = [];
    const xAxis = [];
    const yAxis = [];
    const series = [];
    const titles = props.title ? [titleOf(props)] : [];
    parts.forEach((p, i) => {
        const col = i % columns;
        const row = Math.floor(i / columns);
        const cellTop = headPct + row * cellH;
        grids.push({ left: `${col * cellW + 1}%`, width: `${cellW - 3}%`, top: `${cellTop + labelPct}%`, height: `${Math.max(5, cellH - labelPct - pct(28))}%`, containLabel: true });
        xAxis.push({ ...p.xAxis, gridIndex: i, axisLabel: { ...(p.xAxis.axisLabel || {}), fontSize: 10, hideOverlap: true } });
        yAxis.push({ ...p.yAxis[0], gridIndex: i, min, max, axisLabel: { ...(p.yAxis[0].axisLabel || {}), fontSize: 10, show: col === 0 }, name: undefined, splitNumber: 3 });
        p.series.forEach((s) => series.push({ ...s, xAxisIndex: i, yAxisIndex: i }));
        titles.push({ text: values[i], textStyle: { fontSize: 12, fontWeight: "normal" }, left: `${col * cellW + 1.5}%`, top: `${cellTop}%` });
    });
    const names = unique(series.map((s) => s.name));
    return {
        title: titles,
        legend: names.length > 1 ? { show: true, type: "scroll", bottom: 0, data: names } : { show: false },
        tooltip: { trigger: "axis", confine: true, valueFormatter: parts[0] ? parts[0].tooltip.valueFormatter : undefined },
        axisPointer: { link: [{ xAxisIndex: "all" }] },
        grid: grids,
        xAxis,
        yAxis,
        toolbox: toolboxOf({ ...props, brush: false }, false, ctx.exportIcons),
        series
    };
}

// ---- name / value: pie, donut, funnel ----------------------------------------------------------

function nameValue(props, rows, keys, ctx) {
    const type = String(props.chartType).toLowerCase();
    const nameKey = resolveColumn(props.x, keys) ?? keys[0];
    const valueKey = resolveColumns(props.y, keys)[0] ?? resolveColumn(props.value, keys) ?? keys.find((k) => k !== nameKey && rows.some((r) => typeof r[k] === "number"));
    const fmt = valueFormatter(props, ctx.locale);
    const data = rows.map((r, rowIndex) => ({ name: String(r[nameKey] ?? ""), value: num(r[valueKey]), rowIndex }));
    const legend = legendOf(props, true);
    const pct = new Intl.NumberFormat(ctx.locale, { style: "percent", maximumFractionDigits: 1 });
    const lfmt = labelFormatter(props, ctx.locale);
    const label = props.dataLabels === false ? { show: false } : {
        show: true,
        formatter: (p) => `${p.name}\n${lfmt(p.value)} (${pct.format((p.percent || 0) / 100)})`
    };
    const series = type === "funnel"
        ? { type: "funnel", data, sort: "descending", gap: 2, label: { ...label, position: "inside" }, emphasis: { focus: "self" }, left: "10%", width: "80%", top: props.title ? 70 : 20, bottom: 40 }
        : {
            type: "pie",
            data,
            radius: type === "donut" ? ["45%", "72%"] : [0, "72%"],
            roseType: props.rose ? "radius" : undefined,
            // the pie lives in a box that leaves room for title and legend, so outside labels
            // never run into the legend
            top: props.title ? 56 : 28,
            bottom: legend.show && legend.bottom !== undefined ? (legend.type === "plain" ? 16 + 22 * Math.ceil(data.length / 4) : 40) : 8,
            labelLayout: { hideOverlap: true },
            itemStyle: { borderRadius: type === "donut" ? 4 : 0, borderWidth: 1 },
            label,
            labelLine: { show: label.show !== false },
            emphasis: { focus: "self", scale: true, scaleSize: 6 }
        };
    return {
        title: titleOf(props),
        legend,
        tooltip: { trigger: "item", valueFormatter: fmt || undefined, confine: true },
        toolbox: toolboxOf(props, false, ctx.exportIcons),
        series: [series]
    };
}

// ---- heatmap (x, y, value) and calendar heatmap (date, value) ---------------------------------

function visualMapOf(values, props, ctx, extra) {
    const nums = values.filter((v) => v !== null);
    return {
        min: props.min ?? (nums.length ? Math.min(...nums) : 0),
        max: props.max ?? (nums.length ? Math.max(...nums) : 1),
        calculable: true,
        orient: "horizontal",
        left: "center",
        bottom: 0,
        formatter: formatter(props.format, ctx.locale) || undefined,
        ...extra
    };
}

function heatmap(props, rows, keys, ctx) {
    const xKey = resolveColumn(props.x, keys) ?? keys[0];
    const yKey = resolveColumns(props.y, keys)[0] ?? keys[1];
    const vKey = resolveColumn(props.value, keys) ?? keys[2];
    const xs = unique(rows.map((r) => r[xKey])).map(String);
    const ys = unique(rows.map((r) => r[yKey])).map(String);
    const data = rows.map((r, rowIndex) => ({ value: [xs.indexOf(String(r[xKey] ?? "")), ys.indexOf(String(r[yKey] ?? "")), num(r[vKey])], rowIndex }));
    const fmt = valueFormatter(props, ctx.locale);
    return {
        title: titleOf(props),
        tooltip: { position: "top", confine: true, formatter: (p) => html`${xs[p.value[0]]} · ${ys[p.value[1]]}<br/><b>${fmt ? fmt(p.value[2]) : p.value[2]}</b>` },
        // room below the axis labels for the colour scale and its end values
        grid: { left: 12, right: 24, top: props.title ? 60 : props.toolbox === false ? 20 : 44, bottom: 84, containLabel: true },
        // every column labelled; long names wrap within the column instead of being dropped
        xAxis: { type: "category", data: xs, splitArea: { show: true }, axisLabel: { interval: 0, hideOverlap: false, overflow: "break", width: Math.max(48, Math.floor(900 / Math.max(1, xs.length))) } },
        yAxis: { type: "category", data: ys, splitArea: { show: true } },
        visualMap: visualMapOf(data.map((d) => d.value[2]), props, ctx),
        toolbox: toolboxOf(props, false, ctx.exportIcons),
        series: [{ type: "heatmap", data, label: { show: Boolean(props.dataLabels), formatter: (p) => (fmt ? fmt(p.value[2]) : p.value[2]) }, emphasis: { itemStyle: { shadowBlur: 8 } } }]
    };
}

function calendar(props, rows, keys, ctx) {
    const dKey = resolveColumn(props.x, keys) ?? keys[0];
    const vKey = resolveColumns(props.y, keys)[0] ?? resolveColumn(props.value, keys) ?? keys[1];
    const days = rows.map((r) => String(r[dKey] ?? "").slice(0, 10)).filter((d) => d.length === 10).sort();
    const data = rows.map((r, rowIndex) => ({ value: [String(r[dKey] ?? "").slice(0, 10), num(r[vKey])], rowIndex }));
    const fmt = valueFormatter(props, ctx.locale);
    // one calendar per year, each limited to the days that have data
    const years = unique(days.map((d) => d.slice(0, 4)));
    const calendars = years.map((y, i) => {
        const inYear = days.filter((d) => d.startsWith(y));
        return { range: [inYear[0], inYear[inYear.length - 1]], top: (props.title ? 80 : 56) + i * 170, left: 50, right: 20, cellSize: ["auto", 16], yearLabel: { show: years.length > 1 } };
    });
    return {
        title: titleOf(props),
        tooltip: { confine: true, formatter: (p) => html`${p.value[0]}<br/><b>${fmt ? fmt(p.value[1]) : p.value[1]}</b>` },
        visualMap: visualMapOf(data.map((d) => d.value[1]), props, ctx, { top: undefined }),
        calendar: calendars.length ? calendars : [{ range: new Date().getFullYear() }],
        toolbox: toolboxOf(props, false, ctx.exportIcons),
        series: years.map((y, i) => ({ type: "heatmap", coordinateSystem: "calendar", calendarIndex: i, data: data.filter((d) => d.value[0].startsWith(y)) }))
    };
}

// ---- boxplot and histogram: distributions --------------------------------------------------------

function boxplot(props, rows, keys, ctx) {
    const groupKey = resolveColumn(props.x, keys) ?? resolveColumn(props.groupBy, keys);
    const vKey = resolveColumns(props.y, keys)[0] ?? resolveColumn(props.value, keys) ?? keys.find((k) => rows.some((r) => typeof r[k] === "number"));
    const groups = groupKey ? unique(rows.map((r) => r[groupKey])).map(String).sort((a, b) => a.localeCompare(b, undefined, { numeric: true })) : [vKey];
    const stats = groups.map((g) => boxStats(rows.filter((r) => !groupKey || String(r[groupKey] ?? "") === g).map((r) => num(r[vKey]))));
    const fmt = valueFormatter(props, ctx.locale);
    const f = (v) => (v === null || v === undefined ? "" : fmt ? fmt(v) : v);
    const horizontal = Boolean(props.horizontal);
    const cat = { type: "category", data: groups };
    const val = { type: props.logScale ? "log" : "value", name: props.yTitle, axisLabel: fmt ? { formatter: (v) => fmt(v) } : {} };
    return {
        title: titleOf(props),
        tooltip: {
            trigger: "item",
            confine: true,
            formatter: (p) => (p.seriesType === "boxplot"
                ? html`<b>${p.name}</b><br/>Max: ${f(p.value[5])}<br/>Q3: ${f(p.value[4])}<br/>Median: ${f(p.value[3])}<br/>Q1: ${f(p.value[2])}<br/>Min: ${f(p.value[1])}`
                : html`${groups[p.value[horizontal ? 1 : 0]]}: ${f(p.value[horizontal ? 0 : 1])}`)
        },
        grid: { left: 12, right: 24, top: props.title ? 60 : 20, bottom: 20, containLabel: true },
        xAxis: horizontal ? val : cat,
        yAxis: horizontal ? cat : val,
        dataZoom: dataZoomOf({ zoom: props.zoom ?? "none" }, horizontal),
        toolbox: toolboxOf(props, false, ctx.exportIcons),
        series: [
            { type: "boxplot", name: vKey, data: stats.map((s) => s.box), emphasis: { focus: "self" } },
            { type: "scatter", name: "Outliers", data: stats.flatMap((s, i) => s.outliers.map((o) => (horizontal ? [o, i] : [i, o]))), symbolSize: 6 }
        ]
    };
}

function histogram(props, rows, keys, ctx) {
    const vKey = resolveColumns(props.y, keys)[0] ?? resolveColumn(props.value, keys) ?? resolveColumn(props.x, keys) ?? keys.find((k) => rows.some((r) => typeof r[k] === "number"));
    const values = rows.map((r) => num(r[vKey])).filter((v) => v !== null);
    const fmt = valueFormatter(props, ctx.locale) || formatter("number:1", ctx.locale);
    const sorted = values.slice().sort((a, b) => a - b);
    const binCount = props.bins || Math.max(5, Math.min(50, Math.ceil(Math.log2(values.length || 1) + 1)));
    const min = sorted[0] ?? 0;
    const max = sorted[sorted.length - 1] ?? 1;
    const width = (max - min) / binCount || 1;
    const counts = new Array(binCount).fill(0);
    values.forEach((v) => {
        counts[Math.min(binCount - 1, Math.floor((v - min) / width))]++;
    });
    const label = (i) => `${fmt(min + i * width)} – ${fmt(min + (i + 1) * width)}`;
    const median = quantile(sorted, 0.5);
    const lines = list(props.markLine).length ? props.markLine : ["median"];
    const markData = [];
    for (const m of lines) {
        const t = typeof m === "string" ? m.toLowerCase() : null;
        const v = t === "median" ? median : t === "average" ? values.reduce((a, b) => a + b, 0) / (values.length || 1) : isPlainObject(m) ? m.value : null;
        if (v !== null && v !== undefined) {
            // position on the category axis: fractional bin index
            const line = { xAxis: Math.min(binCount - 0.5, (v - min) / width - 0.5), name: isPlainObject(m) ? m.name || "" : t.charAt(0).toUpperCase() + t.slice(1), valueLabel: fmt(v) };
            if (isPlainObject(m) && m.color) {
                line.lineStyle = { color: m.color };
            }
            markData.push(line);
        }
    }
    return {
        title: titleOf(props),
        tooltip: { trigger: "axis", axisPointer: { type: "shadow" }, confine: true },
        grid: { left: 12, right: 24, top: props.title ? 70 : 50, bottom: 20, containLabel: true },
        xAxis: { type: "category", data: counts.map((_, i) => label(i)), name: props.xTitle || displayName(vKey, props.y), nameLocation: "middle", nameGap: 28, axisLabel: { hideOverlap: true } },
        yAxis: { type: "value", name: props.yTitle || "Count", minInterval: 1 },
        toolbox: toolboxOf(props, false, ctx.exportIcons),
        series: [{
            type: "bar",
            name: displayName(vKey, props.y),
            data: counts,
            barCategoryGap: "4%",
            label: { show: Boolean(props.dataLabels), position: "top" },
            markLine: markData.length ? { symbol: ["none", "none"], lineStyle: { type: "dashed" }, label: { formatter: (p) => `${p.data.name}: ${p.data.valueLabel}` }, data: markData } : undefined
        }]
    };
}

// ---- finance and others --------------------------------------------------------------------------

function candlestick(props, rows, keys, ctx) {
    const xKey = resolveColumn(props.x, keys) ?? keys[0];
    const g = (name, fallback) => getter(props[name] ?? fallback, keys);
    const open = g("open", "open");
    const close = g("close", "close");
    const low = g("low", "low");
    const high = g("high", "high");
    const volumeKey = resolveColumn(props.volume ?? "volume", keys);
    const xs = rows.map((r) => r[xKey]);
    const fmt = valueFormatter(props, ctx.locale);
    const legend = legendOf({ ...props, legend: props.legend || "top" }, Boolean(volumeKey));
    const compact = formatter("compact", ctx.locale);
    const grids = volumeKey
        ? [{ left: 12, right: 24, top: props.title ? 76 : 56, height: "52%", containLabel: true }, { left: 12, right: 24, top: "74%", height: "12%", containLabel: true }]
        : [gridOf(props, legend)];
    const xAxis = grids.map((_, i) => ({ type: "category", data: xs, gridIndex: i, axisLabel: { show: i === grids.length - 1, hideOverlap: true }, boundaryGap: true }));
    const yAxis = grids.map((_, i) => ({ type: "value", gridIndex: i, scale: true, axisLabel: i === 0 ? (fmt ? { formatter: (v) => fmt(v) } : {}) : { formatter: (v) => compact(v) }, splitNumber: i === 0 ? 5 : 2 }));
    const series = [{
        type: "candlestick",
        name: props.title || "Price",
        data: rows.map((r, rowIndex) => ({ value: [num(open(r)), num(close(r)), num(low(r)), num(high(r))], rowIndex })),
        markLine: markLineOf(props, false, fmt)
    }];
    if (volumeKey) {
        series.push({ type: "bar", name: "Volume", xAxisIndex: 1, yAxisIndex: 1, data: rows.map((r) => num(r[volumeKey])) });
    }
    return {
        title: titleOf(props),
        legend,
        tooltip: { trigger: "axis", axisPointer: { type: "cross" }, confine: true, valueFormatter: fmt || undefined },
        axisPointer: { link: [{ xAxisIndex: "all" }] },
        grid: grids,
        xAxis,
        yAxis,
        dataZoom: zoomMode(props).inside || zoomMode(props).slider ? [{ type: "inside", xAxisIndex: grids.map((_, i) => i) }, { type: "slider", xAxisIndex: grids.map((_, i) => i), bottom: 8, height: 20 }] : [],
        toolbox: toolboxOf(props, false, ctx.exportIcons),
        series
    };
}

/*
 * -GaugeStyle Progress (default): one value as a progress arc.
 * Ring: one concentric ring per row (e.g. availability per service), names in the legend.
 * Grade: the arc coloured by -Thresholds @{ value = 95; color = '#e53935' }, ... (upper bounds,
 * ascending), with a needle.
 */
function gauge(props, rows, keys, ctx) {
    const vKey = resolveColumns(props.y, keys)[0] ?? resolveColumn(props.value, keys) ?? keys.find((k) => rows.some((r) => typeof r[k] === "number"));
    const nameKey = resolveColumn(props.x, keys);
    const fmt = valueFormatter(props, ctx.locale);
    const f = (v) => (fmt ? fmt(v) : String(v));
    const min = props.min ?? 0;
    const max = props.max ?? 100;
    const style = String(props.gaugeStyle || "progress").toLowerCase();
    if (style === "ring") {
        const items = rows.map((r, i) => ({ value: num(r[vKey]), name: nameKey ? String(r[nameKey]) : `#${i + 1}`, rowIndex: i }));
        const step = Math.min(14, 60 / Math.max(1, items.length));
        return {
            title: titleOf(props),
            legend: { show: true, type: "scroll", bottom: 0, data: items.map((d) => d.name) },
            tooltip: { formatter: (p) => html`${p.name}: ${f(p.value)}` },
            series: items.map((d, i) => ({
                type: "gauge",
                name: d.name,
                startAngle: 90,
                endAngle: -270,
                min,
                max,
                radius: `${88 - i * step}%`,
                center: ["50%", props.title ? "54%" : "48%"],
                pointer: { show: false },
                progress: { show: true, roundCap: true, width: step * 0.7 + 4 },
                axisLine: { lineStyle: { width: step * 0.7 + 4, opacity: 0.15 } },
                splitLine: { show: false },
                axisTick: { show: false },
                axisLabel: { show: false },
                title: { show: false },
                detail: { show: i === 0 && items.length === 1, formatter: f, fontSize: 22, offsetCenter: [0, 0] },
                data: [d]
            }))
        };
    }
    const data = rows.slice(0, 1).map((r) => ({ value: num(r[vKey]), name: nameKey ? String(r[nameKey]) : props.title || "" }));
    if (style === "grade") {
        const stops = list(props.thresholds).filter(isPlainObject).map((t) => ({ value: num(t.value), color: t.color })).filter((t) => t.value !== null).sort((a, b) => a.value - b.value);
        const colors = stops.length
            ? stops.map((t) => [Math.min(1, Math.max(0, (t.value - min) / (max - min || 1))), t.color || "#5470c6"]).concat(stops[stops.length - 1].value < max ? [[1, stops[stops.length - 1].color || "#5470c6"]] : [])
            : [[1, "#5470c6"]];
        return {
            title: titleOf(props),
            tooltip: { formatter: (p) => html`${p.name}: ${f(p.value)}` },
            series: [{
                type: "gauge",
                min,
                max,
                axisLine: { lineStyle: { width: 18, color: colors } },
                pointer: { itemStyle: { color: "auto" }, width: 5 },
                axisTick: { distance: -18, length: 6, lineStyle: { color: "#fff", width: 1 } },
                splitLine: { distance: -18, length: 18, lineStyle: { color: "#fff", width: 2 } },
                axisLabel: { distance: 26, fontSize: 11, formatter: (v) => f(v) },
                detail: { valueAnimation: true, formatter: f, fontSize: 22, offsetCenter: [0, "70%"], color: "inherit" },
                title: { offsetCenter: [0, "95%"] },
                data
            }]
        };
    }
    return {
        tooltip: { formatter: (p) => html`${p.name}: ${f(p.value)}` },
        series: [{
            type: "gauge",
            min,
            max,
            progress: { show: true, width: 14 },
            axisLine: { lineStyle: { width: 14 } },
            detail: { valueAnimation: true, formatter: (v) => f(v), fontSize: 24, offsetCenter: [0, "70%"] },
            title: { offsetCenter: [0, "95%"] },
            data
        }]
    };
}

function radar(props, rows, keys, ctx) {
    const nameKey = resolveColumn(props.x, keys) ?? keys[0];
    const dims = resolveColumns(props.y, keys);
    const indicators = (dims.length ? dims : keys.filter((k) => k !== nameKey && rows.some((r) => typeof r[k] === "number")));
    const max = props.max;
    return {
        title: titleOf(props),
        legend: legendOf(props, true),
        tooltip: { trigger: "item", confine: true, valueFormatter: valueFormatter(props, ctx.locale) || undefined },
        radar: { indicator: indicators.map((k) => ({ name: displayName(k, props.y), max: max ?? Math.max(...rows.map((r) => num(r[k]) || 0)) * 1.1 })), radius: "65%" },
        series: [{ type: "radar", emphasis: { focus: "self" }, areaStyle: { opacity: 0.15 }, data: rows.map((r, rowIndex) => ({ name: String(r[nameKey] ?? ""), value: indicators.map((k) => num(r[k])), rowIndex })) }]
    };
}

function sankey(props, rows, keys, ctx) {
    const sKey = resolveColumn(props.source ?? "source", keys) ?? keys[0];
    const tKey = resolveColumn(props.target ?? "target", keys) ?? keys[1];
    const vKey = resolveColumn(props.value ?? "value", keys) ?? keys[2];
    const names = unique(rows.flatMap((r) => [String(r[sKey] ?? ""), String(r[tKey] ?? "")]));
    return {
        title: titleOf(props),
        tooltip: { trigger: "item", confine: true, valueFormatter: valueFormatter(props, ctx.locale) || undefined },
        series: [{
            type: "sankey",
            top: props.title ? 60 : 20,
            emphasis: { focus: "adjacency" },
            lineStyle: { color: "gradient", curveness: 0.5, opacity: 0.4 },
            data: names.map((name) => ({ name })),
            links: rows.map((r, rowIndex) => ({ source: String(r[sKey] ?? ""), target: String(r[tKey] ?? ""), value: num(r[vKey]), rowIndex }))
        }]
    };
}

/*
 * graph: nodes and links from -Source/-Target (like sankey), force layout, drag and zoom with the
 * mouse, neighbours highlighted on hover (what does an outage of X affect?). -GroupBy colours nodes:
 * a column of the source rows naming the source node's group. Node size grows with its links.
 */
function graph(props, rows, keys, ctx) {
    const sKey = resolveColumn(props.source ?? "source", keys) ?? keys[0];
    const tKey = resolveColumn(props.target ?? "target", keys) ?? keys[1];
    const vKey = resolveColumn(props.value, keys);
    const groupKey = resolveColumn(props.groupBy, keys);
    const targetGroupKey = resolveColumn(props.targetGroup, keys);
    const names = unique(rows.flatMap((r) => [String(r[sKey] ?? ""), String(r[tKey] ?? "")])).filter((n) => n !== "");
    const groupOf = new Map();
    rows.forEach((r) => {
        if (groupKey && !groupOf.has(String(r[sKey]))) groupOf.set(String(r[sKey]), String(r[groupKey] ?? ""));
        if (targetGroupKey && !groupOf.has(String(r[tKey]))) groupOf.set(String(r[tKey]), String(r[targetGroupKey] ?? ""));
    });
    const categories = unique([...groupOf.values()]).filter((g) => g !== "");
    const degree = new Map(names.map((n) => [n, 0]));
    rows.forEach((r) => {
        degree.set(String(r[sKey]), (degree.get(String(r[sKey])) || 0) + 1);
        degree.set(String(r[tKey]), (degree.get(String(r[tKey])) || 0) + 1);
    });
    const maxDegree = Math.max(1, ...degree.values());
    const edgeLabelKey = resolveColumn(props.edgeLabel, keys);
    // layered: sources without incoming links on the left, every node one column right of its
    // furthest predecessor (firewall > core > access port > ESXi uplink > port group > VM)
    const layered = String(props.layout || "").toLowerCase() === "layered";
    const position = new Map();
    if (layered) {
        const incoming = new Map(names.map((n) => [n, []]));
        rows.forEach((r) => {
            const t = String(r[tKey] ?? "");
            if (incoming.has(t)) incoming.get(t).push(String(r[sKey] ?? ""));
        });
        const depth = new Map();
        const depthOf = (n, seen = new Set()) => {
            if (depth.has(n)) return depth.get(n);
            if (seen.has(n)) return 0; // a cycle: break it here
            seen.add(n);
            const preds = incoming.get(n) || [];
            const d = preds.length ? 1 + Math.max(...preds.map((p) => depthOf(p, seen))) : 0;
            depth.set(n, d);
            return d;
        };
        names.forEach((n) => depthOf(n));
        const columns = new Map();
        names.forEach((n) => {
            const d = depth.get(n);
            if (!columns.has(d)) columns.set(d, []);
            columns.get(d).push(n);
        });
        // coordinates in about the shape of a wide card (height / width 0.42): the box stretches
        // them to fit, and a very different shape would turn the round nodes into ellipses
        const height = Math.max(1, columns.size - 1) * 200 * 0.42;
        columns.forEach((col, d) => col.forEach((n, i) => position.set(n, { x: d * 200, y: ((i + 0.5) * height) / col.length })));
    }
    // legend top-left (the toolbox sits top-right): a force layout is not bounded and would run over a bottom legend
    const legend = categories.length ? { show: true, type: "scroll", top: props.title ? 34 : 4, left: 0, right: 140, data: categories } : { show: false };
    return {
        title: titleOf(props),
        legend,
        tooltip: { confine: true, formatter: (p) => (p.dataType === "edge" ? html`${p.data.source} → ${p.data.target}${p.data.value !== undefined ? ": " + p.data.value : ""}` : html`${p.name}${p.data.category !== undefined && categories[p.data.category] ? " (" + categories[p.data.category] + ")" : ""}`) },
        toolbox: toolboxOf(props, false, ctx.exportIcons),
        series: [{
            type: "graph",
            layout: layered ? "none" : String(props.layout || "force").toLowerCase(),
            roam: true,
            draggable: true,
            top: (props.title ? 34 : 4) + (legend.show ? 48 : 24),
            bottom: layered ? 36 : 16,
            // layered: all four sides fixed, so the columns stretch over the box; with a free side
            // ECharts keeps the aspect ratio and a wide layout runs out of the chart
            left: layered ? 60 : undefined,
            right: layered ? 60 : undefined,
            categories: categories.map((name) => ({ name })),
            data: names.map((name) => ({ name, value: degree.get(name), category: groupOf.has(name) && categories.indexOf(groupOf.get(name)) >= 0 ? categories.indexOf(groupOf.get(name)) : undefined, symbolSize: 10 + 26 * Math.sqrt(degree.get(name) / maxDegree), ...(position.get(name) || {}) })),
            links: rows.map((r, rowIndex) => ({
                source: String(r[sKey] ?? ""),
                target: String(r[tKey] ?? ""),
                value: vKey ? num(r[vKey]) : undefined,
                rowIndex,
                // -EdgeLabel: e.g. the ports of a connection, written on the line
                label: edgeLabelKey && r[edgeLabelKey] !== null && r[edgeLabelKey] !== undefined && r[edgeLabelKey] !== "" ? { show: true, formatter: String(r[edgeLabelKey]), fontSize: 10, position: "middle" } : undefined
            })),
            label: { show: names.length <= 60, position: layered ? "bottom" : "right", fontSize: 11 },
            labelLayout: { hideOverlap: true },
            edgeSymbol: ["none", props.directed === false ? "none" : "arrow"],
            edgeSymbolSize: 6,
            lineStyle: { opacity: 0.6, curveness: layered ? 0 : 0.1 },
            emphasis: { focus: "adjacency", lineStyle: { width: 3 } },
            force: { repulsion: Math.max(60, 600 / Math.sqrt(names.length || 1)), edgeLength: [40, 140], gravity: 0.1, initLayout: "circular" }
        }]
    };
}

/*
 * matrix: a table of small charts - one per row value (-Y, e.g. customer) and column value
 * (-GroupBy, e.g. KPI) - each showing -Value over -X (time or category). Every column has one value
 * scale, so a cell compares with the cells above and below it. -CellType Line (default), Area or Bar;
 * the last value is written at the end of each line.
 */
function matrixChart(props, rows, keys, ctx) {
    const rowKey = resolveColumns(props.y, keys)[0] ?? keys[0];
    const colKey = resolveColumn(props.groupBy, keys) ?? keys[1];
    const xKey = resolveColumn(props.x, keys) ?? keys[2];
    const vKey = resolveColumn(props.value, keys) ?? keys.find((k) => ![rowKey, colKey, xKey].includes(k) && rows.some((r) => typeof r[k] === "number"));
    const rowCats = unique(rows.map((r) => String(r[rowKey] ?? "")));
    const colCats = unique(rows.map((r) => String(r[colKey] ?? "")));
    const xType = axisTypeFor(rows.map((r) => r[xKey]), props.xAxisType, "line");
    const cellType = String(props.cellType || "line").toLowerCase();
    const fmt = valueFormatter(props, ctx.locale);
    const lfmt = labelFormatter(props, ctx.locale);
    const palette = Array.isArray(props.palette) && props.palette.length ? props.palette : undefined;
    // one value scale per column
    const extent = new Map(colCats.map((c) => [c, [Infinity, -Infinity]]));
    rows.forEach((r) => {
        const v = num(r[vKey]);
        if (v === null) return;
        const e = extent.get(String(r[colKey] ?? ""));
        e[0] = Math.min(e[0], v);
        e[1] = Math.max(e[1], v);
    });
    const grid = [];
    const xAxis = [];
    const yAxis = [];
    const series = [];
    rowCats.forEach((rc) => {
        colCats.forEach((cc, ci) => {
            const cell = rows.map((r, rowIndex) => ({ r, rowIndex })).filter(({ r }) => String(r[rowKey] ?? "") === rc && String(r[colKey] ?? "") === cc);
            if (cell.length === 0) return;
            const i = grid.length;
            const [lo, hi] = extent.get(cc);
            grid.push({ coordinateSystem: "matrix", coord: [cc, rc], left: 6, right: cellType === "bar" ? 6 : 44, top: 6, bottom: 6 });
            xAxis.push({ gridIndex: i, type: xType === "time" ? "time" : "category", show: false, boundaryGap: cellType === "bar" });
            // bars start at zero; lines use the column's range, so 96 % vs 99 % is visible
            const pad = hi > lo ? (hi - lo) * 0.15 : Math.abs(hi) * 0.05 || 1;
            yAxis.push(cellType === "bar"
                ? { gridIndex: i, type: "value", show: false, min: Math.min(0, lo), max: hi }
                : { gridIndex: i, type: "value", show: false, min: lo - pad, max: hi + pad });
            const data = cell.map(({ r, rowIndex }) => ({ value: [r[xKey], num(r[vKey])], rowIndex }));
            const last = data[data.length - 1].value[1];
            series.push({
                type: cellType === "bar" ? "bar" : "line",
                name: cc,
                xAxisIndex: i,
                yAxisIndex: i,
                data,
                showSymbol: false,
                smooth: Boolean(props.smooth),
                areaStyle: cellType === "area" ? { opacity: 0.2 } : undefined,
                color: palette ? palette[ci % palette.length] : undefined,
                lineStyle: { width: 1.5 },
                endLabel: cellType === "bar" ? undefined : { show: true, fontSize: 11, formatter: () => (last === null ? "" : lfmt(last)) },
                emphasis: { focus: "none" },
                tooltip: { valueFormatter: fmt || undefined }
            });
        });
    });
    return {
        title: titleOf(props),
        tooltip: { trigger: "axis", confine: true, axisPointer: { type: "line" } },
        toolbox: toolboxOf(props, false, ctx.exportIcons),
        matrix: {
            top: props.title ? 60 : 40,
            left: 8,
            right: 8,
            bottom: 8,
            x: { data: colCats, levelSize: 30 },
            y: { data: rowCats, levelSize: Math.min(220, 24 + 7 * Math.max(...rowCats.map((c) => c.length))) }
        },
        grid,
        xAxis,
        yAxis,
        series
    };
}

// Hierarchy from a list of path columns (-Path Region, Country, City) or a "/"-separated column
function hierarchy(rows, pathKeys, vKey) {
    const root = { children: [] };
    rows.forEach((r, rowIndex) => {
        const parts = pathKeys.length === 1 ? String(r[pathKeys[0]] ?? "").split("/").filter(Boolean) : pathKeys.map((k) => String(r[k] ?? ""));
        let node = root;
        parts.forEach((part, depth) => {
            node.children = node.children || [];
            let child = node.children.find((c) => c.name === part);
            if (!child) {
                child = { name: part };
                node.children.push(child);
            }
            if (depth === parts.length - 1) {
                child.value = (child.value || 0) + (num(r[vKey]) || 0);
                child.rowIndex = rowIndex;
            }
            node = child;
        });
    });
    return root.children;
}

function treeChart(props, rows, keys, ctx) {
    const type = String(props.chartType).toLowerCase();
    const pathKeys = resolveColumns(props.path ?? props.x, keys);
    const vKey = resolveColumns(props.y, keys)[0] ?? resolveColumn(props.value, keys) ?? keys.find((k) => rows.some((r) => typeof r[k] === "number"));
    const data = hierarchy(rows, pathKeys.length ? pathKeys : [keys[0]], vKey);
    const fmt = valueFormatter(props, ctx.locale);
    const series = type === "sunburst"
        ? { type: "sunburst", data, radius: [0, "90%"], center: ["50%", props.title ? "55%" : "50%"], emphasis: { focus: "ancestor" }, label: { rotate: "radial", minAngle: 6 } }
        : { type: "treemap", data, top: props.title ? 60 : 10, bottom: 40, leafDepth: pathKeys.length > 2 ? 2 : undefined, label: { show: true, formatter: (p) => `${p.name}\n${fmt ? fmt(p.value) : p.value}` }, upperLabel: { show: true, height: 22 }, roam: false };
    return {
        title: titleOf(props),
        tooltip: { confine: true, formatter: (p) => html`${(p.treePathInfo || []).slice(1).map((t) => t.name).join(" / ") || p.name}: <b>${fmt ? fmt(p.value) : p.value}</b>` },
        toolbox: toolboxOf(props, false, ctx.exportIcons),
        series: [series]
    };
}

/*
 * Waterfall (bridge): each row is a change; rows whose x matches -Totals (or a "total" column that
 * is true) show the running total instead. Built as an invisible base plus visible rise/fall bars.
 */
function waterfall(props, rows, keys, ctx) {
    const xKey = resolveColumn(props.x, keys) ?? keys[0];
    const vKey = resolveColumns(props.y, keys)[0] ?? resolveColumn(props.value, keys) ?? keys[1];
    const totalKey = resolveColumn("total", keys);
    const totals = new Set(list(props.totals).map(String));
    const fmt = valueFormatter(props, ctx.locale);
    const lfmt = labelFormatter(props, ctx.locale);
    const up = props.positiveColor || "#3ba272";
    const down = props.negativeColor || "#ee6666";
    const totalColor = props.totalColor || "#5470c6";
    let running = 0;
    const base = [];
    const bars = [];
    rows.forEach((r, rowIndex) => {
        const v = num(r[vKey]) || 0;
        const isTotal = totals.has(String(r[xKey])) || (totalKey && r[totalKey] === true);
        if (isTotal) {
            base.push(0);
            bars.push({ value: running, rowIndex, itemStyle: { color: totalColor }, label: running });
        } else {
            const start = running;
            running += v;
            base.push(Math.min(start, running));
            bars.push({ value: Math.abs(v), rowIndex, itemStyle: { color: v < 0 ? down : up }, label: v });
        }
    });
    return {
        title: titleOf(props),
        tooltip: { trigger: "axis", axisPointer: { type: "shadow" }, confine: true, formatter: (ps) => { const p = ps.find((x) => x.seriesIndex === 1); return p ? html`${p.name}: <b>${fmt ? fmt(p.data.label) : p.data.label}</b>` : ""; } },
        grid: { left: 12, right: 24, top: props.title ? 76 : 56, bottom: 20, containLabel: true },
        // every step is named: all labels, slanted when there are many
        xAxis: { type: "category", data: rows.map((r) => String(r[xKey] ?? "")), axisLabel: { interval: 0, rotate: rows.length > 6 ? 30 : 0 } },
        yAxis: { type: "value", axisLabel: { formatter: (v) => lfmt(v) } },
        toolbox: toolboxOf(props, false, ctx.exportIcons),
        series: [
            { type: "bar", stack: "w", silent: true, itemStyle: { color: "transparent", borderColor: "transparent" }, emphasis: { disabled: true }, data: base, tooltip: { show: false } },
            { type: "bar", stack: "w", data: bars, labelLayout: { hideOverlap: true }, label: { show: props.dataLabels !== false, position: "top", formatter: (p) => lfmt(p.data.label) } }
        ]
    };
}

// ---- responsive rules ----------------------------------------------------------------------------

/*
 * Rules for the chart's own width, applied again on every resize (window size, browser zoom, a card
 * that gets narrower; see optionForWidth). Below NARROW the chart keeps what it needs to be read and
 * drops what it cannot fit: outside labels of pie/donut become percentages inside the slices (names
 * stay in the legend and tooltip), bar labels go, toolbox and margins shrink.
 */
export const NARROW = 520;
export const TINY = 360;

export function responsive(option, props, ctx = {}) {
    const type = String(props.chartType || "line").toLowerCase();
    const series = Array.isArray(option.series) ? option.series : [];
    const pct = new Intl.NumberFormat(ctx.locale || "en-US", { style: "percent", maximumFractionDigits: 0 });
    const narrow = {
        toolbox: option.toolbox ? { itemSize: 13, itemGap: 6, feature: { magicType: { show: false }, dataZoom: { show: false }, brush: { show: false } } } : undefined,
        legend: option.legend && option.legend.show ? { itemGap: 6, itemWidth: 14, textStyle: { fontSize: 11 } } : undefined,
        title: option.title ? { textStyle: { fontSize: 14 }, subtextStyle: { fontSize: 11 } } : undefined
    };
    if (type === "pie" || type === "donut") {
        narrow.series = [{
            radius: type === "donut" ? ["38%", "78%"] : [0, "78%"],
            label: { show: true, position: "inside", formatter: (p) => (p.percent >= 6 ? pct.format(p.percent / 100) : ""), fontSize: 11 },
            labelLine: { show: false }
        }];
        narrow.legend = { ...(narrow.legend || {}), show: true, type: "scroll", bottom: 0 };
    } else if (CARTESIAN.has(type) || type === "histogram" || type === "waterfall" || type === "boxplot") {
        narrow.grid = { left: 4, right: 8 };
        narrow.xAxis = { axisLabel: { fontSize: 10 } };
        narrow.yAxis = { axisLabel: { fontSize: 10 }, nameTextStyle: { fontSize: 10 } };
        // value labels go only when the chart is tiny (see below); the tooltip still shows them
        if (props.dataLabels && type !== "waterfall") {
            narrow.series = series.map(() => ({ label: { fontSize: 10 } }));
        }
    } else if (type === "heatmap") {
        narrow.xAxis = { axisLabel: { rotate: 45, fontSize: 9 } };
        narrow.yAxis = { axisLabel: { fontSize: 9 } };
    } else if (type === "treemap") {
        narrow.series = [{ upperLabel: { show: false }, label: { fontSize: 10 } }];
    } else if (type === "sunburst") {
        narrow.series = [{ label: { fontSize: 9, minAngle: 12 } }];
    } else if (type === "radar") {
        narrow.radar = { radius: "55%", axisName: { fontSize: 9 } };
    } else if (type === "sankey") {
        narrow.series = [{ label: { fontSize: 9 }, nodeGap: 6, left: 4, right: 60 }];
    } else if (type === "gauge") {
        narrow.series = [{ detail: { fontSize: 18 }, axisLabel: { fontSize: 9, distance: 18 } }];
    }
    const tiny = {
        legend: option.legend && option.legend.show ? { textStyle: { fontSize: 10 }, itemWidth: 10, itemHeight: 8 } : undefined,
        toolbox: option.toolbox ? { show: false } : undefined,
        series: props.dataLabels && (CARTESIAN.has(type) || type === "histogram") ? series.map(() => ({ label: { show: false } })) : undefined
    };
    return [
        { maxWidth: NARROW, option: normalize(narrow) },
        { maxWidth: TINY, option: normalize(tiny) }
    ];
}

/*
 * The option for a chart of the given width: the base option with every rule whose maxWidth the
 * width is below merged over it. (ECharts' own media queries do not combine with replaceMerge,
 * which live updates need, so the component applies the rules itself on resize.)
 */
export function optionForWidth(option, rules, width) {
    return rules.filter((r) => width > 0 && width <= r.maxWidth).reduce((o, r) => mergeOptions(o, r.option), option);
}

// ---- gantt: bars from -Start to -End per row (maintenance windows, job runs, on-call shifts) -----

function gantt(props, rows, keys, ctx) {
    const rowKey = resolveColumn(props.x, keys) ?? keys[0];
    const startKey = resolveColumn(props.start ?? "start", keys);
    const endKey = resolveColumn(props.end ?? "end", keys);
    const groupKey = resolveColumn(props.groupBy, keys);
    const labelKey = resolveColumn(props.value, keys);
    const lanes = unique(rows.map((r) => r[rowKey])).map(String);
    const groups = groupKey ? unique(rows.map((r) => r[groupKey])).map(String).sort((a, b) => a.localeCompare(b, undefined, { numeric: true })) : [displayName(rowKey, props.x)];
    const dt = formatter("datetime", ctx.locale);
    const ms = (v) => (typeof v === "number" ? v : Date.parse(v));
    // each bar: [lane index, start ms, end ms, label]
    const renderItem = (params, api) => {
        const lane = api.value(0);
        const from = api.coord([api.value(1), lane]);
        const to = api.coord([api.value(2), lane]);
        const height = api.size([0, 1])[1] * 0.62;
        return {
            type: "rect",
            shape: { x: from[0], y: from[1] - height / 2, width: Math.max(2, to[0] - from[0]), height, r: 3 },
            style: api.style(),
            textContent: { style: { text: api.value(3) || "", fill: "#fff", fontSize: 11, overflow: "truncate", width: Math.max(0, to[0] - from[0] - 6) } },
            textConfig: { position: "insideLeft" }
        };
    };
    const legend = legendOf(props, groups.length > 1);
    const series = groups.map((g, i) => ({
        type: "custom",
        name: g,
        markArea: i === 0 ? markAreaOf(props, "time", false) : undefined,
        renderItem,
        clip: true,
        encode: { x: [1, 2], y: 0 },
        emphasis: { focus: "series" },
        data: rows
            .map((r, rowIndex) => ({ r, rowIndex }))
            .filter(({ r }) => !groupKey || String(r[groupKey] ?? "") === g)
            .map(({ r, rowIndex }) => ({ value: [lanes.indexOf(String(r[rowKey] ?? "")), ms(r[startKey]), ms(r[endKey]), labelKey ? String(r[labelKey] ?? "") : ""], rowIndex }))
            .filter((d) => !isNaN(d.value[1]) && !isNaN(d.value[2]))
    }));
    return {
        title: titleOf(props),
        legend,
        tooltip: {
            confine: true,
            formatter: (p) => {
                const [lane, a, b, label] = p.value;
                const minutes = Math.round((b - a) / 60000);
                const dur = formatter("duration:min", ctx.locale)(minutes);
                return html`<b>${lanes[lane]}</b>${label ? " · " + label : ""}<br/>${trusted(p.marker)}${p.seriesName}<br/>${dt(a)} – ${dt(b)} (${dur})`;
            }
        },
        grid: gridOf({ ...props, dataLabels: false }, legend),
        xAxis: { type: "time", position: "top", splitLine: { show: true }, axisLabel: { hideOverlap: true } },
        yAxis: { type: "category", data: lanes, inverse: true, axisTick: { show: false }, splitLine: { show: true } },
        dataZoom: dataZoomOf({ ...props, zoomAuto: true }, false, legend.show && legend.bottom !== undefined),
        toolbox: toolboxOf(props, false, ctx.exportIcons),
        series
    };
}


/*
 * tree: a hierarchy from -Path columns (vCenter, Cluster, Host, VM) as a collapsible tree; click a
 * node to open or close it. -Orient LR (default), TB or Radial; -Depth levels open at the start.
 */
function treeDiagram(props, rows, keys, ctx) {
    const pathKeys = resolveColumns(props.path ?? props.x, keys);
    const vKey = resolveColumns(props.y, keys)[0] ?? resolveColumn(props.value, keys);
    let data = hierarchy(rows, pathKeys.length ? pathKeys : [keys[0]], vKey);
    // a tree has one root; several top-level values get a common one
    if (data.length !== 1) {
        data = [{ name: props.rootName || props.title || "", children: data }];
    }
    const orient = String(props.orient || "LR").toUpperCase();
    const radial = orient === "RADIAL";
    const fmt = valueFormatter(props, ctx.locale);
    const vertical = orient === "TB" || orient === "BT";
    return {
        title: titleOf(props),
        tooltip: { trigger: "item", confine: true, formatter: (p) => html`${(p.treeAncestors || []).slice(1).map((t) => t.name).filter(Boolean).join(" / ") || p.name}${typeof p.value === "number" && vKey ? html`: <b>${fmt ? fmt(p.value) : p.value}</b>` : ""}` },
        toolbox: toolboxOf(props, false, ctx.exportIcons),
        series: [{
            type: "tree",
            data,
            layout: radial ? "radial" : "orthogonal",
            orient: radial ? undefined : orient,
            top: props.title ? 60 : 24,
            bottom: 24,
            left: radial ? undefined : vertical ? 24 : 110,
            right: radial ? undefined : vertical ? 24 : 160,
            roam: true,
            symbolSize: 9,
            initialTreeDepth: props.depth ?? 2,
            expandAndCollapse: true,
            emphasis: { focus: "descendant" },
            label: radial ? { fontSize: 11 } : vertical
                ? { position: "top", rotate: 0, verticalAlign: "middle", align: "center", fontSize: 11 }
                : { position: "left", verticalAlign: "middle", align: "right", fontSize: 11 },
            leaves: { label: radial ? {} : vertical ? { position: "bottom", rotate: 0, align: "center" } : { position: "right", align: "left" } },
            labelLayout: { hideOverlap: true },
            animationDuration: 300
        }]
    };
}

/*
 * chord: flows or overlaps between the same set of things (systems that share assets, teams that
 * hand tickets to each other). Rows like sankey: -Source, -Target, -Value.
 */
function chord(props, rows, keys, ctx) {
    const sKey = resolveColumn(props.source ?? "source", keys) ?? keys[0];
    const tKey = resolveColumn(props.target ?? "target", keys) ?? keys[1];
    const vKey = resolveColumn(props.value ?? "value", keys) ?? keys[2];
    const names = unique(rows.flatMap((r) => [String(r[sKey] ?? ""), String(r[tKey] ?? "")])).filter((n) => n !== "");
    const fmt = valueFormatter(props, ctx.locale);
    return {
        title: titleOf(props),
        legend: props.legend === "none" ? { show: false } : { show: true, type: "scroll", bottom: 0 },
        tooltip: { trigger: "item", confine: true, formatter: (p) => (p.dataType === "edge" ? html`${p.data.source} ↔ ${p.data.target}: <b>${fmt ? fmt(p.data.value) : p.data.value}</b>` : html`${p.name}: <b>${fmt ? fmt(p.value) : p.value}</b>`) },
        toolbox: toolboxOf(props, false, ctx.exportIcons),
        series: [{
            type: "chord",
            center: ["50%", props.title ? "52%" : "48%"],
            radius: ["62%", "70%"],
            padAngle: 2,
            minAngle: 2,
            lineStyle: { color: "source", opacity: 0.3 },
            emphasis: { focus: "adjacency", lineStyle: { opacity: 0.7 } },
            label: { show: true, position: "outside", fontSize: 11 },
            data: names.map((name) => ({ name })),
            links: rows.map((r, rowIndex) => ({ source: String(r[sKey] ?? ""), target: String(r[tKey] ?? ""), value: num(r[vKey]), rowIndex }))
        }]
    };
}

/*
 * parallel: each row is a line across several axes (-Y: CPU, RAM, disk, backup age, ...); drag on an
 * axis to keep only the lines in that range. -GroupBy colours the lines; text columns become
 * category axes.
 */
function parallel(props, rows, keys, ctx) {
    const nameKey = resolveColumn(props.x, keys);
    const groupKey = resolveColumn(props.groupBy, keys);
    let dims = resolveColumns(props.y, keys);
    if (dims.length === 0) {
        dims = keys.filter((k) => k !== nameKey && k !== groupKey && rows.some((r) => typeof r[k] === "number"));
    }
    const axes = dims.map((k, dim) => {
        const numeric = rows.every((r) => r[k] === null || r[k] === undefined || typeof r[k] === "number");
        return numeric
            ? { dim, name: displayName(k, props.y), type: "value", scale: true, nameTextStyle: { fontSize: 11 } }
            : { dim, name: displayName(k, props.y), type: "category", data: unique(rows.map((r) => String(r[k] ?? ""))), nameTextStyle: { fontSize: 11 } };
    });
    const valueOf = (r) => dims.map((k, i) => (axes[i].type === "value" ? num(r[k]) : String(r[k] ?? "")));
    const groups = groupKey ? unique(rows.map((r) => String(r[groupKey] ?? ""))).sort((a, b) => a.localeCompare(b, undefined, { numeric: true })) : [""];
    const series = groups.map((g) => ({
        type: "parallel",
        name: g || undefined,
        smooth: Boolean(props.smooth),
        lineStyle: { width: 1.5, opacity: rows.length > 200 ? 0.25 : 0.55 },
        emphasis: { lineStyle: { width: 3, opacity: 1 } },
        inactiveOpacity: 0.04,
        activeOpacity: 1,
        data: rows.map((r, rowIndex) => ({ r, rowIndex })).filter(({ r }) => !groupKey || String(r[groupKey] ?? "") === g).map(({ r, rowIndex }) => ({ value: valueOf(r), name: nameKey ? String(r[nameKey] ?? "") : undefined, rowIndex }))
    }));
    const legend = legendOf(props, groupKey !== undefined);
    return {
        title: titleOf(props),
        legend,
        tooltip: { trigger: "item", confine: true, formatter: (p) => html`${p.name || p.seriesName || ""}<br/>${joinHtml(dims.map((k, i) => html`${displayName(k, props.y)}: <b>${p.value[i]}</b>`), "<br/>")}` },
        toolbox: toolboxOf(props, false, ctx.exportIcons),
        parallel: { left: 40, right: 70, top: props.title ? 100 : 76, bottom: legend.show && legend.bottom !== undefined ? 50 : 30, parallelAxisDefault: { nameLocation: "end", nameGap: 16, axisLabel: { hideOverlap: true } } },
        parallelAxis: axes,
        series
    };
}

/*
 * themeriver: how the mix of categories changes over time (tickets per category per week), as
 * streams around a centre line. Long rows: -X date, -GroupBy category, -Y value.
 */
function themeRiver(props, rows, keys, ctx) {
    const xKey = resolveColumn(props.x, keys) ?? keys[0];
    const groupKey = resolveColumn(props.groupBy, keys) ?? keys[1];
    const yKey = resolveColumns(props.y, keys)[0] ?? keys.find((k) => k !== xKey && k !== groupKey && rows.some((r) => typeof r[k] === "number"));
    const names = unique(rows.map((r) => String(r[groupKey] ?? ""))).sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
    const fmt = valueFormatter(props, ctx.locale);
    const legend = legendOf(props, true);
    return {
        title: titleOf(props),
        legend: { ...legend, data: names },
        tooltip: { trigger: "axis", confine: true, axisPointer: { type: "line" }, valueFormatter: fmt || undefined },
        toolbox: toolboxOf(props, false, ctx.exportIcons),
        singleAxis: { type: axisTypeFor(rows.map((r) => r[xKey]), props.xAxisType, "line") === "time" ? "time" : "category", top: props.title ? 70 : 40, bottom: legend.show && legend.bottom !== undefined ? 60 : 30, axisPointer: { animation: true, label: { show: true } }, splitLine: { show: true, lineStyle: { type: "dashed", opacity: 0.3 } } },
        series: [{
            type: "themeRiver",
            emphasis: { focus: "series" },
            label: { show: false },
            data: rows.map((r) => [r[xKey], num(r[yKey]) ?? 0, String(r[groupKey] ?? "")])
        }]
    };
}

/*
 * -LabelColumn / -LabelTemplate and -TooltipColumns / -TooltipTemplate for every chart type: the text
 * comes from the row behind the point (items carry its rowIndex). Points without a row (aggregated
 * nodes, a tree's folders, large data) keep the chart's own text.
 */
function applyTemplates(option, props, rows, keys, ctx) {
    const labelTemplate = props.labelTemplate ?? (props.labelColumn ? `{${props.labelColumn}}` : undefined);
    const tooltipTemplate = props.tooltipTemplate ?? (props.tooltipColumns ? columnsTemplate(props.tooltipColumns) : undefined);
    if (labelTemplate === undefined && tooltipTemplate === undefined) {
        return option;
    }
    const rowOf = (p) => {
        const i = p && p.data && typeof p.data === "object" ? p.data.rowIndex : undefined;
        return i === undefined ? undefined : rows[i];
    };
    const seriesList = Array.isArray(option.series) ? option.series : option.series ? [option.series] : [];
    if (labelTemplate !== undefined) {
        const render = compileTemplate(labelTemplate, keys, ctx.locale);
        // only series drawn from the rows: not trend lines, bands or helper series
        const fromRows = (s) => (Array.isArray(s.data) ? s.data : []).some(function hasRow(d) {
            return d && typeof d === "object" && (d.rowIndex !== undefined || (Array.isArray(d.children) && d.children.some(hasRow)));
        });
        seriesList.filter(fromRows).forEach((s) => {
            const previous = s.label && s.label.formatter;
            s.label = {
                ...(s.label || {}),
                show: true,
                formatter: (p) => {
                    const r = rowOf(p);
                    if (r) return render(r);
                    return typeof previous === "function" ? previous(p) : p.name;
                }
            };
        });
    }
    if (tooltipTemplate !== undefined) {
        const render = compileTemplate(tooltipTemplate, keys, ctx.locale);
        const previous = option.tooltip && option.tooltip.formatter;
        const one = (p) => {
            const r = rowOf(p);
            if (!r) return undefined;
            const head = p.name !== undefined && p.name !== "" ? html`<b>${p.name}</b><br/>` : "";
            return html`${head}${trusted(render(r, true))}`;
        };
        option.tooltip = {
            ...(option.tooltip || {}),
            formatter: (p) => {
                const items = Array.isArray(p) ? p : [p];
                const parts = items.map(one);
                if (parts.some((x) => x !== undefined)) {
                    return joinHtml(parts.map((x, i) => x ?? html`${trusted(items[i].marker)}${items[i].seriesName}`), "<br/>");
                }
                if (typeof previous === "function") return previous(p);
                // ECharts' default text for the points without a row
                return joinHtml(items.map((x) => html`${trusted(x.marker)}${x.seriesName ? x.seriesName + ": " : ""}${x.name}`), "<br/>");
            }
        };
    }
    return option;
}

// ---- entry point ---------------------------------------------------------------------------------

const BUILDERS = {
    pie: nameValue,
    donut: nameValue,
    funnel: nameValue,
    heatmap,
    calendar,
    boxplot,
    histogram,
    candlestick,
    gauge,
    radar,
    sankey,
    treemap: treeChart,
    sunburst: treeChart,
    waterfall,
    gantt,
    graph,
    tree: treeDiagram,
    chord,
    parallel,
    themeriver: themeRiver,
    matrix: matrixChart
};

export const CHART_TYPES = [...CARTESIAN, ...Object.keys(BUILDERS)];

/*
 * Removes undefined keys and makes every formatter return a string: ECharts calls string methods on
 * a formatter's result, and a number or null there throws ("t.replace is not a function").
 */
function normalize(value) {
    if (Array.isArray(value)) {
        return value.map(normalize);
    }
    if (isPlainObject(value)) {
        const out = {};
        for (const [k, v] of Object.entries(value)) {
            if (v === undefined) {
                continue;
            }
            out[k] = k === "formatter" && typeof v === "function"
                ? (...args) => {
                    const r = v(...args);
                    return r === null || r === undefined ? "" : String(r);
                }
                : normalize(v);
        }
        return out;
    }
    return value;
}

/*
 * ctx: { locale, exportIcons } - exportIcons { csv, xlsx (SVG paths), onCsv, onXlsx (handlers) } turn
 * on the CSV/Excel toolbox buttons.
 */
export function buildOption(props, ctx = {}) {
    const rows = Array.isArray(props.data) ? props.data.filter((r) => r && typeof r === "object") : [];
    const keys = columnsOf(rows);
    const type = String(props.chartType || "line").toLowerCase();
    const context = { locale: ctx.locale || "en-US", exportIcons: ctx.exportIcons };
    let option;
    if (CARTESIAN.has(type) && props.sparkline) {
        option = sparkline({ ...props, chartType: type }, rows, keys, context);
    } else if (CARTESIAN.has(type) && props.facet && resolveColumn(props.facet, keys) !== undefined) {
        option = facets({ ...props, chartType: type }, rows, keys, context);
    } else if (CARTESIAN.has(type)) {
        option = cartesian({ ...props, chartType: type }, rows, keys, context);
    } else if (BUILDERS[type]) {
        option = BUILDERS[type]({ ...props, chartType: type }, rows, keys, context);
    } else {
        throw new Error(`Unknown chart type "${props.chartType}". Known: ${CHART_TYPES.join(", ")}`);
    }
    if (Array.isArray(props.palette) && props.palette.length) {
        option.color = props.palette;
    }
    option.backgroundColor = "transparent";
    option.animation = rows.length <= LARGE;
    option.aria = { enabled: true, decal: { show: Boolean(props.decal) } };
    applyTemplates(option, props, rows, keys, context);
    return mergeOptions(normalize(option), props.options);
}
