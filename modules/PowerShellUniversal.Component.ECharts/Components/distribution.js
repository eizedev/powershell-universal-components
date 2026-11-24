import { resolveColumn, resolveColumns } from "../../../shared/js/columns.js";
import { formatter } from "./formatters.js";
import { html } from "./html.js";
import { list, num, unique, quantile, boxStats, displayName, isPlainObject, valueFormatter, labelFormatter, titleOf, legendOf, dataZoomOf, toolboxOf, aggregate, groupRows, visualMapOf } from "./optionParts.js";

// pie, donut and funnel, heatmaps and calendars, boxplot, histogram and waterfall (buildOption.js)

// ---- name / value: pie, donut, funnel ----------------------------------------------------------

export function nameValue(props, rows, keys, ctx) {
    const type = String(props.chartType).toLowerCase();
    const nameKey = resolveColumn(props.x, keys) ?? keys[0];
    const valueKey = resolveColumns(props.y, keys)[0] ?? resolveColumn(props.value, keys) ?? keys.find((k) => k !== nameKey && rows.some((r) => typeof r[k] === "number"));
    const fmt = valueFormatter(props, ctx.locale);
    const data = props.aggregate
        ? [...groupRows(rows, (r) => String(r[nameKey] ?? ""), (r) => num(r[valueKey])).values()].map((g) => ({ name: g.key, value: aggregate(g.values, props.aggregate), rowIndex: g.rowIndex }))
        : rows.map((r, rowIndex) => ({ name: String(r[nameKey] ?? ""), value: num(r[valueKey]), rowIndex }));
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
            // never run into the legend (fitPlot in layout.js adds the lines a wrapping legend takes)
            top: props.title ? 56 : 28,
            bottom: legend.show && legend.bottom !== undefined ? 40 : 8,
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
        toolbox: toolboxOf(props, false, ctx),
        series: [series]
    };
}

// ---- heatmap (x, y, value) and calendar heatmap (date, value) ---------------------------------

export function heatmap(props, rows, keys, ctx) {
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
        // up to 12 columns every one is labelled (long names wrap); with more (24 hours) ECharts thins them out
        xAxis: { type: "category", data: xs, splitArea: { show: true }, axisLabel: xs.length <= 12 ? { interval: 0, hideOverlap: false, overflow: "break", width: Math.max(48, Math.floor(900 / Math.max(1, xs.length))) } : { hideOverlap: true } },
        yAxis: { type: "category", data: ys, splitArea: { show: true } },
        visualMap: visualMapOf(data.map((d) => d.value[2]), props, ctx),
        toolbox: toolboxOf(props, false, ctx),
        series: [{ type: "heatmap", data, label: { show: Boolean(props.dataLabels), formatter: (p) => (fmt ? fmt(p.value[2]) : p.value[2]) }, emphasis: { itemStyle: { shadowBlur: 8 } } }]
    };
}

export function calendar(props, rows, keys, ctx) {
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
        toolbox: toolboxOf(props, false, ctx),
        series: years.map((y, i) => ({ type: "heatmap", coordinateSystem: "calendar", calendarIndex: i, data: data.filter((d) => d.value[0].startsWith(y)) }))
    };
}

// ---- boxplot and histogram: distributions --------------------------------------------------------

export function boxplot(props, rows, keys, ctx) {
    const groupKey = resolveColumn(props.x, keys) ?? resolveColumn(props.groupBy, keys);
    const vKey = resolveColumns(props.y, keys)[0] ?? resolveColumn(props.value, keys) ?? keys.find((k) => rows.some((r) => typeof r[k] === "number"));
    const groups = groupKey ? unique(rows.map((r) => r[groupKey])).map(String).sort((a, b) => a.localeCompare(b, undefined, { numeric: true })) : [vKey];
    const stats = groups.map((g) => boxStats(rows.filter((r) => !groupKey || String(r[groupKey] ?? "") === g).map((r) => num(r[vKey]))));
    const fmt = valueFormatter(props, ctx.locale);
    const t = ctx.texts;
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
                ? html`<b>${p.name}</b><br/>${t.max}: ${f(p.value[5])}<br/>Q3: ${f(p.value[4])}<br/>${t.median}: ${f(p.value[3])}<br/>Q1: ${f(p.value[2])}<br/>${t.min}: ${f(p.value[1])}`
                : html`${groups[p.value[horizontal ? 1 : 0]]}: ${f(p.value[horizontal ? 0 : 1])}`)
        },
        // below the toolbox (top right), as gridOf() places the cartesian charts
        grid: { left: 12, right: 24, top: props.title ? 60 : props.toolbox === false ? 20 : 44, bottom: 20, containLabel: true },
        xAxis: horizontal ? val : cat,
        yAxis: horizontal ? cat : val,
        dataZoom: dataZoomOf({ zoom: props.zoom ?? "none" }, horizontal),
        toolbox: toolboxOf(props, false, ctx),
        series: [
            { type: "boxplot", name: vKey, data: stats.map((s) => s.box), emphasis: { focus: "self" } },
            { type: "scatter", name: t.outliers, data: stats.flatMap((s, i) => s.outliers.map((o) => (horizontal ? [o, i] : [i, o]))), symbolSize: 6 }
        ]
    };
}

export function histogram(props, rows, keys, ctx) {
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
        yAxis: { type: "value", name: props.yTitle || ctx.texts.count, minInterval: 1 },
        toolbox: toolboxOf(props, false, ctx),
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

/*
 * Waterfall (bridge): each row is a change; rows whose x matches -Totals (or a "total" column that
 * is true) show the running total instead. Built as an invisible base plus visible rise/fall bars.
 */
export function waterfall(props, rows, keys, ctx) {
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
        toolbox: toolboxOf(props, false, ctx),
        series: [
            { type: "bar", stack: "w", silent: true, itemStyle: { color: "transparent", borderColor: "transparent" }, emphasis: { disabled: true }, data: base, tooltip: { show: false } },
            { type: "bar", stack: "w", data: bars, labelLayout: { hideOverlap: true }, label: { show: props.dataLabels !== false, position: "top", formatter: (p) => lfmt(p.data.label) } }
        ]
    };
}
