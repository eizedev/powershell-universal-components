import { columnsOf, getter, resolveColumn, resolveColumns } from "../../../shared/js/columns.js";
import { formatter } from "../../../shared/js/formatters.js";

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
    const legend = { show: true, type: "scroll" };
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
        right: 24,
        top: (props.title ? (props.subtitle ? 80 : 60) : legend.show && legend.top !== undefined ? 50 : 36) + (props.dataLabels ? 16 : 0),
        bottom: (legend.show && legend.bottom !== undefined ? 30 : 8) + (zoomMode(props).slider ? 34 : 0),
        containLabel: true
    };
}

function zoomMode(props) {
    const mode = String(props.zoom || "inside").toLowerCase();
    return { inside: mode === "inside" || mode === "both", slider: mode === "slider" || mode === "both" };
}

function dataZoomOf(props, horizontal, legendBottom = false) {
    const mode = zoomMode(props);
    const axis = horizontal ? { yAxisIndex: 0 } : { xAxisIndex: [0] };
    const zooms = [];
    if (mode.inside) {
        zooms.push({ type: "inside", ...axis, filterMode: "none" });
    }
    if (mode.slider) {
        zooms.push({ type: "slider", ...axis, filterMode: "none", height: 22, bottom: horizontal ? undefined : legendBottom ? 34 : 8 });
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
 * markLine entries from PowerShell: "median", "average", "min", "max" (of each series) or
 * @{ value = 48; name = 'SLA'; axis = 'y' } for a fixed line.
 */
function markLineOf(props, horizontal, fmt) {
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

// ---- cartesian: line, area, bar, scatter, step --------------------------------------------------

function cartesian(props, rows, keys, ctx) {
    const type = String(props.chartType).toLowerCase();
    const horizontal = Boolean(props.horizontal) && type === "bar";
    const xKey = resolveColumn(props.x, keys) ?? keys[0];
    const yKeys = resolveColumns(props.y, keys);
    const groupKey = resolveColumn(props.groupBy, keys);
    const secondary = new Set(resolveColumns(props.secondaryY, keys));
    if (yKeys.length === 0) {
        // all numeric columns except x and the group
        keys.filter((k) => k !== xKey && k !== groupKey && rows.some((r) => typeof r[k] === "number")).forEach((k) => yKeys.push(k));
    }
    const xValues = rows.map((r) => r[xKey]);
    const xType = axisTypeFor(xValues, props.xAxisType, type);
    const fmt = valueFormatter(props, ctx.locale);
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
        for (const g of unique(rows.map((r) => r[groupKey]))) {
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
        if (seriesType === "scatter") {
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
                    return v === null || v === undefined ? "" : fmt ? fmt(v) : String(v);
                }
            };
        }
        if (props.negativeColor && seriesType === "bar") {
            s.itemStyle = {
                color: (p) => {
                    const v = Array.isArray(p.value) ? p.value[horizontal ? 0 : 1] : p.value;
                    return v < 0 ? props.negativeColor : p.color;
                }
            };
        }
        if (i === 0) {
            const ml = markLineOf(props, horizontal, fmt);
            if (ml) {
                s.markLine = ml;
            }
        }
        return s;
    });
    // markLine statistics belong to every series, fixed lines once
    if (list(props.markLine).some((m) => typeof m === "string")) {
        series.slice(1).forEach((s) => {
            s.markLine = markLineOf({ markLine: list(props.markLine).filter((m) => typeof m === "string") }, horizontal, fmt);
        });
    }

    const valueAxis = (index) => ({
        type: props.logScale ? "log" : "value",
        min: index === 0 ? props.yMin : undefined,
        max: index === 0 ? props.yMax : undefined,
        name: index === 0 ? props.yTitle : props.secondaryTitle,
        axisLabel: fmt ? { formatter: (v) => fmt(v) } : {},
        splitLine: { show: index === 0 }
    });
    const categoryAxis = {
        type: xType,
        name: props.xTitle,
        data: categories,
        boundaryGap: seriesType === "bar" || xType === "category" ? undefined : false,
        axisLabel: props.xFormat && xFmt ? { formatter: (v) => xFmt(v), hideOverlap: true } : { hideOverlap: true }
    };
    const yAxes = secondary.size > 0 ? [valueAxis(0), valueAxis(1)] : [valueAxis(0)];
    const legend = legendOf(props, series.length > 1);
    return {
        title: titleOf(props),
        legend,
        grid: gridOf(props, legend),
        tooltip: {
            trigger: seriesType === "scatter" ? "item" : "axis",
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

// ---- name / value: pie, donut, funnel ----------------------------------------------------------

function nameValue(props, rows, keys, ctx) {
    const type = String(props.chartType).toLowerCase();
    const nameKey = resolveColumn(props.x, keys) ?? keys[0];
    const valueKey = resolveColumns(props.y, keys)[0] ?? resolveColumn(props.value, keys) ?? keys.find((k) => k !== nameKey && rows.some((r) => typeof r[k] === "number"));
    const fmt = valueFormatter(props, ctx.locale);
    const data = rows.map((r, rowIndex) => ({ name: String(r[nameKey] ?? ""), value: num(r[valueKey]), rowIndex }));
    const legend = legendOf(props, true);
    const pct = new Intl.NumberFormat(ctx.locale, { style: "percent", maximumFractionDigits: 1 });
    const label = props.dataLabels === false ? { show: false } : {
        show: true,
        formatter: (p) => `${p.name}\n${fmt ? fmt(p.value) : p.value} (${pct.format((p.percent || 0) / 100)})`
    };
    const series = type === "funnel"
        ? { type: "funnel", data, sort: "descending", gap: 2, label: { ...label, position: "inside" }, emphasis: { focus: "self" }, left: "10%", width: "80%", top: props.title ? 70 : 20, bottom: 40 }
        : {
            type: "pie",
            data,
            radius: type === "donut" ? ["45%", "72%"] : [0, "72%"],
            center: ["50%", props.title ? "55%" : "50%"],
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
        tooltip: { position: "top", confine: true, formatter: (p) => `${xs[p.value[0]]} · ${ys[p.value[1]]}<br/><b>${fmt ? fmt(p.value[2]) : p.value[2]}</b>` },
        grid: { left: 12, right: 24, top: props.title ? 60 : 20, bottom: 60, containLabel: true },
        xAxis: { type: "category", data: xs, splitArea: { show: true } },
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
    const years = unique(days.map((d) => d.slice(0, 4)));
    const data = rows.map((r, rowIndex) => ({ value: [String(r[dKey] ?? "").slice(0, 10), num(r[vKey])], rowIndex }));
    const fmt = valueFormatter(props, ctx.locale);
    const calendars = years.map((y, i) => ({ range: y, top: (props.title ? 70 : 30) + i * 170, left: 40, right: 20, cellSize: ["auto", 16], yearLabel: { show: true } }));
    return {
        title: titleOf(props),
        tooltip: { confine: true, formatter: (p) => `${p.value[0]}<br/><b>${fmt ? fmt(p.value[1]) : p.value[1]}</b>` },
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
    const groups = groupKey ? unique(rows.map((r) => r[groupKey])).map(String) : [vKey];
    const stats = groups.map((g) => boxStats(rows.filter((r) => !groupKey || String(r[groupKey] ?? "") === g).map((r) => num(r[vKey]))));
    const fmt = valueFormatter(props, ctx.locale);
    const f = (v) => (v === null || v === undefined ? "" : fmt ? fmt(v) : v);
    const horizontal = Boolean(props.horizontal);
    const cat = { type: "category", data: groups };
    const val = { type: "value", name: props.yTitle, axisLabel: fmt ? { formatter: (v) => fmt(v) } : {} };
    return {
        title: titleOf(props),
        tooltip: {
            trigger: "item",
            confine: true,
            formatter: (p) => (p.seriesType === "boxplot"
                ? `<b>${p.name}</b><br/>Max: ${f(p.value[5])}<br/>Q3: ${f(p.value[4])}<br/>Median: ${f(p.value[3])}<br/>Q1: ${f(p.value[2])}<br/>Min: ${f(p.value[1])}`
                : `${groups[p.value[horizontal ? 1 : 0]]}: ${f(p.value[horizontal ? 0 : 1])}`)
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
    const legend = legendOf(props, Boolean(volumeKey));
    const grids = volumeKey
        ? [{ left: 12, right: 24, top: props.title ? 60 : 30, height: "55%", containLabel: true }, { left: 12, right: 24, top: "75%", height: "13%", containLabel: true }]
        : [gridOf(props, legend)];
    const xAxis = grids.map((_, i) => ({ type: "category", data: xs, gridIndex: i, axisLabel: { show: i === grids.length - 1, hideOverlap: true }, boundaryGap: true }));
    const yAxis = grids.map((_, i) => ({ type: "value", gridIndex: i, scale: true, axisLabel: i === 0 && fmt ? { formatter: (v) => fmt(v) } : {}, splitNumber: i === 0 ? 5 : 2 }));
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

function gauge(props, rows, keys, ctx) {
    const vKey = resolveColumns(props.y, keys)[0] ?? resolveColumn(props.value, keys) ?? keys.find((k) => rows.some((r) => typeof r[k] === "number"));
    const nameKey = resolveColumn(props.x, keys);
    const fmt = valueFormatter(props, ctx.locale);
    const data = rows.slice(0, 1).map((r) => ({ value: num(r[vKey]), name: nameKey ? String(r[nameKey]) : props.title || "" }));
    return {
        tooltip: { formatter: (p) => `${p.name}: ${fmt ? fmt(p.value) : p.value}` },
        series: [{
            type: "gauge",
            min: props.min ?? 0,
            max: props.max ?? 100,
            progress: { show: true, width: 14 },
            axisLine: { lineStyle: { width: 14 } },
            detail: { valueAnimation: true, formatter: (v) => (fmt ? fmt(v) : String(v)), fontSize: 24, offsetCenter: [0, "70%"] },
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
        radar: { indicator: indicators.map((k) => ({ name: k, max: max ?? Math.max(...rows.map((r) => num(r[k]) || 0)) * 1.1 })), radius: "65%" },
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
        tooltip: { confine: true, formatter: (p) => `${(p.treePathInfo || []).slice(1).map((t) => t.name).join(" / ") || p.name}: <b>${fmt ? fmt(p.value) : p.value}</b>` },
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
        tooltip: { trigger: "axis", axisPointer: { type: "shadow" }, confine: true, formatter: (ps) => { const p = ps.find((x) => x.seriesIndex === 1); return p ? `${p.name}: <b>${fmt ? fmt(p.data.label) : p.data.label}</b>` : ""; } },
        grid: { left: 12, right: 24, top: props.title ? 76 : 56, bottom: 20, containLabel: true },
        xAxis: { type: "category", data: rows.map((r) => String(r[xKey] ?? "")), axisLabel: { hideOverlap: true } },
        yAxis: { type: "value", axisLabel: fmt ? { formatter: (v) => fmt(v) } : {} },
        toolbox: toolboxOf(props, false, ctx.exportIcons),
        series: [
            { type: "bar", stack: "w", silent: true, itemStyle: { color: "transparent", borderColor: "transparent" }, emphasis: { disabled: true }, data: base, tooltip: { show: false } },
            { type: "bar", stack: "w", data: bars, label: { show: props.dataLabels !== false, position: "top", formatter: (p) => (fmt ? fmt(p.data.label) : p.data.label) } }
        ]
    };
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
    waterfall
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
    if (CARTESIAN.has(type)) {
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
    return mergeOptions(normalize(option), props.options);
}
