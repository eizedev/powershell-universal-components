import { formatter, labelFormatSpec } from "./formatters.js";
import { textsFor } from "./texts.js";

/*
 * The parts every chart builder of buildOption.js uses: value helpers, statistics, -Aggregate, the
 * title, legend, grid, zoom, toolbox and mark lines, and -Options merged over the result.
 */

export const LARGE = 20000;

export const CARTESIAN = new Set(["line", "area", "bar", "scatter", "step"]);

// translucent fills for areas and bands that sit behind the data
export const SHADE = "rgba(128,128,128,0.14)";

export const ISO_DATE = /^\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?)?$/;

// ---- helpers ----------------------------------------------------------------------------------

export function list(value) {
    if (value === undefined || value === null || value === "") {
        return [];
    }
    return Array.isArray(value) ? value : [value];
}

export function num(value) {
    if (value === null || value === undefined || value === "") {
        return null;
    }
    const n = typeof value === "number" ? value : Number(value);
    return isNaN(n) ? null : n;
}

export function isDateLike(value) {
    return typeof value === "string" && ISO_DATE.test(value);
}

export function axisTypeFor(values, requested, chartType) {
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

export function unique(values) {
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

export function isPlainObject(v) {
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
            // never merge into the prototype chain (a "__proto__" key from JSON)
            if (k === "__proto__" || k === "constructor" || k === "prototype") {
                continue;
            }
            out[k] = Object.prototype.hasOwnProperty.call(base, k) ? mergeOptions(base[k], v) : v;
        }
        return out;
    }
    return user;
}

// ---- common parts ------------------------------------------------------------------------------

export function valueFormatter(props, locale) {
    return formatter(props.format, locale);
}

// Value labels: -LabelFormat, else -Format with the short form for large numbers only, so
// 9.850.000,00 € becomes 9,9 Mio. € while 99,97 stays 99,97
export function labelFormatter(props, locale) {
    if (props.labelFormat) {
        return formatter(props.labelFormat, locale);
    }
    const full = formatter(props.format || "number", locale);
    const short = formatter(labelFormatSpec(props.format), locale);
    return (v) => (typeof v === "number" && Math.abs(v) >= 10000 ? short(v) : full(v));
}

export function titleOf(props) {
    if (!props.title && !props.subtitle) {
        return undefined;
    }
    return { text: props.title || "", subtext: props.subtitle || "", left: "center" };
}

export function legendOf(props, hasSeriesNames) {
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

export function gridOf(props, legend) {
    return {
        left: 12,
        // an x axis name sits right of the axis end: room for it (about 7 px per character)
        right: Math.max(String(props.zoomAxis || "x").toLowerCase() !== "x" && zoomMode(props).slider ? 40 : 24, props.xTitle && !props.horizontal ? 16 + 7 * String(props.xTitle).length : 0),
        // axis names sit above the axes: one more row so they stay clear of the toolbox
        // below title and toolbox: axis names sit above the plot, pins (-MarkPoint) reach 46 px above their point
        top: (props.title ? (props.subtitle ? 80 : 60) : legend.show && legend.top !== undefined ? 56 : props.toolbox === false ? 24 : 48) + (props.dataLabels ? 16 : 0) + (props.yTitle || props.secondaryTitle ? 24 : 0) + (props.markPoint ? 30 : 0),
        bottom: (legend.show && legend.bottom !== undefined ? 30 : 8) + (zoomMode(props).slider ? 34 : 0),
        containLabel: true
    };
}

/*
 * -Zoom Auto (default): wheel zoom everywhere, plus the slider with its data preview where there is
 * a lot to scroll through - a time axis or more than 60 categories. props.zoomAuto carries that
 * decision from the builder.
 */
export function zoomMode(props) {
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
export function dataZoomOf(props, horizontal, legendBottom = false) {
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

export function toolboxOf(props, cartesian, ctx = {}) {
    const exportIcons = ctx.exportIcons;
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
    if (exportIcons && exportIcons.onFullscreen) {
        feature.myFullscreen = { show: true, title: (ctx.texts ?? textsFor()).fullScreen, icon: exportIcons.fullscreen, onclick: exportIcons.onFullscreen };
    }
    return { show: true, right: 8, top: props.title ? 34 : 0, feature };
}

/*
 * -MarkArea: shaded ranges such as maintenance windows or outages:
 * @{ from = '2026-11-03T02:00'; to = '2026-11-03T04:00'; name = 'Maintenance'; color = '...' }
 * axis = 'y' shades a value range (e.g. the SLA corridor) instead.
 */
export function markAreaOf(props, xType, horizontal) {
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
 * @{ value = 48; name = 'SLA'; axis = 'y' } for a fixed line. Labels sit above the line's end;
 * placeStatisticLabels moves those of statistic lines that lie below another series' line.
 */
export function markLineOf(props, horizontal, fmt) {
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
        label: { formatter: (p) => `${p.name ? p.name + ": " : ""}${fmt ? fmt(p.value) : p.value}`, position: "insideEndTop" },
        lineStyle: { type: "dashed" },
        data
    };
}

// -MarkLine statistics belong to every series of a cartesian chart; fixed lines only to the first,
// which has them from markLineOf already
export function addStatisticLines(series, props, horizontal, fmt) {
    const statistics = list(props.markLine).filter((m) => typeof m === "string");
    if (statistics.length === 0) {
        return;
    }
    series.slice(1).forEach((s) => {
        s.markLine = markLineOf({ markLine: statistics }, horizontal, fmt);
    });
    placeStatisticLabels(series, horizontal);
}

// the value a statistic line is drawn at, as ECharts computes it (marker/markerHelper.js numCalculate)
const STATISTICS = {
    average: (v) => AGGREGATES.avg(v),
    median: (v) => quantile([...v].sort((a, b) => a - b), 0.5),
    min: (v) => AGGREGATES.min(v),
    max: (v) => AGGREGATES.max(v)
};

// a data item as built: a number, { value }, [x, y] or { value: [x, y] } ([y, x] for horizontal bars)
function pointOf(item, index, horizontal) {
    const point = item && typeof item === "object" && !Array.isArray(item) ? item.value : item;
    return Array.isArray(point) ? { x: point[horizontal ? 1 : 0], value: num(point[horizontal ? 0 : 1]) } : { x: index, value: num(point) };
}

// each series' values as drawn: a stacked series on top of the earlier ones of its stack with the same
// sign (ECharts' default stackStrategy), matched by x on a time or value axis, by position otherwise
function drawnValues(series, horizontal) {
    const stacks = new Map();
    return series.map((s) => {
        const sums = s.stack ? stacks.get(s.stack) ?? new Map() : null;
        if (sums) {
            stacks.set(s.stack, sums);
        }
        return (s.data || []).map((item, i) => {
            const { x, value } = pointOf(item, i, horizontal);
            if (!sums || value === null) {
                return value;
            }
            const key = `${x}|${value < 0 ? "-" : "+"}`;
            sums.set(key, (sums.get(key) ?? 0) + value);
            return sums.get(key);
        });
    });
}

// highest line: label above; lowest: below; one in between: away from its nearer neighbour
function labelSide(lines, rank) {
    if (rank === 0) {
        return "insideEndTop";
    }
    if (rank === lines.length - 1) {
        return "insideEndBottom";
    }
    const gapAbove = lines[rank - 1].value - lines[rank].value;
    const gapBelow = lines[rank].value - lines[rank + 1].value;
    return gapBelow <= gapAbove ? "insideEndTop" : "insideEndBottom";
}

/*
 * The labels of statistic lines of several series, by where the lines lie, so the labels of close
 * lines face away from each other. Each statistic is ordered on its own, among the series on the same
 * value axis; equal values keep the series order. A line alone there keeps the series' position (from
 * markLineOf or -Options); a position set here on a line item wins over the series' one.
 */
export function placeStatisticLabels(series, horizontal) {
    const drawn = drawnValues(series, horizontal);
    const groups = new Map();
    series.forEach((s, i) => {
        const values = drawn[i].filter((v) => v !== null);
        for (const item of (s.markLine && s.markLine.data) || []) {
            if (STATISTICS[item.type] && values.length) {
                const key = `${item.type}|${s.yAxisIndex ?? 0}`;
                groups.set(key, [...(groups.get(key) ?? []), { item, value: STATISTICS[item.type](values) }]);
            }
        }
    });
    for (const lines of [...groups.values()].filter((g) => g.length > 1)) {
        lines.sort((a, b) => b.value - a.value);
        lines.forEach((line, rank) => {
            line.item.label = { position: labelSide(lines, rank) };
        });
    }
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
export function markPointOf(props, seriesName, isFirst, fmt) {
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

// ---- -Aggregate: rows with the same key combined --------------------------------------------------

// every function gets the non-empty values and returns null for none (a gap, not a 0); loops instead of
// Math.min(...v), which overflows the call stack for groups of a few hundred thousand rows
export const AGGREGATES = {
    sum: (v) => (v.length ? v.reduce((a, b) => a + b, 0) : null),
    avg: (v) => (v.length ? v.reduce((a, b) => a + b, 0) / v.length : null),
    min: (v) => (v.length ? v.reduce((a, b) => (b < a ? b : a)) : null),
    max: (v) => (v.length ? v.reduce((a, b) => (b > a ? b : a)) : null)
};

export const maxOf = AGGREGATES.max;

export const minOf = AGGREGATES.min;

// values of the rows that share a key -> one value; without a mode the last row wins (as without -Aggregate)
export function aggregate(values, mode) {
    const name = String(mode || "").toLowerCase();
    // count counts rows, also those without a value
    if (name === "count") {
        return values.length;
    }
    const fn = AGGREGATES[name];
    if (!fn) {
        return values.length ? values[values.length - 1] : null;
    }
    return fn(values.filter((v) => v !== null && v !== undefined));
}

// rows grouped by key, in first-seen order: [{ key, values, rowIndex (first row), lastRowIndex }]
export function groupRows(rows, keyOf, valueOf, filter = () => true) {
    const groups = new Map();
    rows.forEach((r, rowIndex) => {
        if (!filter(r)) return;
        const key = keyOf(r);
        let g = groups.get(key);
        if (!g) {
            g = { key, values: [], rowIndex, lastRowIndex: rowIndex };
            groups.set(key, g);
        }
        g.values.push(valueOf(r));
        g.lastRowIndex = rowIndex;
    });
    return groups;
}

// ---- small statistics helpers --------------------------------------------------------------------

export function toTime(v) {
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

export function medianStep(sortedXs) {
    const steps = [];
    for (let i = 1; i < sortedXs.length; i++) steps.push(sortedXs[i] - sortedXs[i - 1]);
    steps.sort((a, b) => a - b);
    return steps.length ? steps[Math.floor(steps.length / 2)] : 0;
}

export function visualMapOf(values, props, ctx, extra) {
    const nums = values.filter((v) => v !== null);
    return {
        min: props.min ?? (nums.length ? minOf(nums) : 0),
        max: props.max ?? (nums.length ? maxOf(nums) : 1),
        calculable: true,
        orient: "horizontal",
        left: "center",
        bottom: 0,
        formatter: formatter(props.format, ctx.locale) || undefined,
        ...extra
    };
}

// Hierarchy from a list of path columns (-Path Region, Country, City) or a "/"-separated column
export function hierarchy(rows, pathKeys, vKey) {
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

/*
 * Removes undefined keys and makes every formatter return a string: ECharts calls string methods on
 * a formatter's result, and a number or null there throws ("t.replace is not a function").
 */
export function normalize(value) {
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
