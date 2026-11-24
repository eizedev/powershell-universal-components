import { getter, resolveColumn, resolveColumns } from "../../../shared/js/columns.js";
import { formatter } from "./formatters.js";
import { html } from "./html.js";
import { list, num, unique, displayName, isPlainObject, valueFormatter, titleOf, legendOf, gridOf, zoomMode, toolboxOf, markLineOf, maxOf, aggregate, groupRows } from "./optionParts.js";

// candlestick, gauge, radar, polar and radial bars, and bump charts (buildOption.js)

// ---- finance and others --------------------------------------------------------------------------

export function candlestick(props, rows, keys, ctx) {
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
        name: props.title || ctx.texts.price,
        data: rows.map((r, rowIndex) => ({ value: [num(open(r)), num(close(r)), num(low(r)), num(high(r))], rowIndex })),
        markLine: markLineOf(props, false, fmt)
    }];
    if (volumeKey) {
        series.push({ type: "bar", name: ctx.texts.volume, xAxisIndex: 1, yAxisIndex: 1, data: rows.map((r) => num(r[volumeKey])) });
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
        toolbox: toolboxOf(props, false, ctx),
        series
    };
}

/*
 * -GaugeStyle Progress (default): one value as a progress arc.
 * Ring: one concentric ring per row (e.g. availability per service), names in the legend.
 * Grade: the arc coloured by -Thresholds @{ value = 95; color = '#e53935' }, ... (upper bounds,
 * ascending), with a needle.
 */
export function gauge(props, rows, keys, ctx) {
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

export function radar(props, rows, keys, ctx) {
    const nameKey = resolveColumn(props.x, keys) ?? keys[0];
    const dims = resolveColumns(props.y, keys);
    const indicators = (dims.length ? dims : keys.filter((k) => k !== nameKey && rows.some((r) => typeof r[k] === "number")));
    const max = props.max;
    return {
        title: titleOf(props),
        legend: legendOf(props, true),
        tooltip: { trigger: "item", confine: true, valueFormatter: valueFormatter(props, ctx.locale) || undefined },
        radar: { indicator: indicators.map((k) => ({ name: displayName(k, props.y), max: max ?? (maxOf(rows.map((r) => num(r[k]) || 0)) ?? 0) * 1.1 })), radius: "65%" },
        series: [{ type: "radar", emphasis: { focus: "self" }, areaStyle: { opacity: 0.15 }, data: rows.map((r, rowIndex) => ({ name: String(r[nameKey] ?? ""), value: indicators.map((k) => num(r[k])), rowIndex })) }]
    };
}

/*
 * polar: categories around a circle (hours of the day, weekdays, months), bars outward; -Y columns or
 * -GroupBy give series, -Stacked stacks them. radialbar: one ring per category, its length the value
 * (-Max is the longest ring, three quarters of the circle; default the largest value) - progress per
 * service or customer.
 */
// the longest ring: the largest value, or the largest stack total when the series are stacked
export function ringMax(series, stacked) {
    const length = series.length ? series[0].data.length : 0;
    let max = 0;
    for (let i = 0; i < length; i++) {
        const values = series.map((s) => num(s.data[i] && s.data[i].value) || 0);
        const v = stacked ? values.reduce((a, b) => a + b, 0) : values.reduce((a, b) => (b > a ? b : a), 0);
        if (v > max) max = v;
    }
    return max > 0 ? max : 1;
}

/*
 * The value at a ring's end runs along the ring (ECharts rotates it with the tangent), so on the lower
 * half of the circle it stands upside down. Such a label is turned by half a turn and aligned to the
 * other side, so it still starts at the ring's end and reads upright. The ring starts at the top
 * (startAngle 90) and runs clockwise over angleMax; a stacked ring ends where its stack ends. ECharts
 * takes a polar bar label's numeric rotate in radians (sectorLabel.js, setSectorTextRotation).
 */
export function uprightRingLabels(series, angleMax, stacked) {
    const ends = [];
    for (const s of series) {
        if (!s.label || !s.label.show) continue;
        s.data.forEach((d, i) => {
            const v = num(d.value);
            if (v === null) return;
            ends[i] = (stacked ? ends[i] || 0 : 0) + v;
            // the end's angle on screen: from the top, clockwise; ECharts turns the text by 1.5 pi minus it
            const anchor = -Math.PI / 2 + (ends[i] / (angleMax || 1)) * 2 * Math.PI;
            const turn = (((1.5 * Math.PI - anchor) % (2 * Math.PI)) + 2 * Math.PI) % (2 * Math.PI);
            if (turn > Math.PI / 2 + 1e-9 && turn < 1.5 * Math.PI - 1e-9) {
                d.label = { ...(d.label || {}), rotate: turn - Math.PI, align: "right" };
            }
        });
    }
    return series;
}

export function polarChart(props, rows, keys, ctx) {
    const type = String(props.chartType).toLowerCase();
    const xKey = resolveColumn(props.x, keys) ?? keys[0];
    const groupKey = resolveColumn(props.groupBy, keys);
    let yKeys = resolveColumns(props.y, keys);
    if (yKeys.length === 0) yKeys = keys.filter((k) => k !== xKey && k !== groupKey && rows.some((r) => typeof r[k] === "number"));
    const categories = unique(rows.map((r) => String(r[xKey] ?? "")));
    const defs = groupKey
        ? unique(rows.map((r) => String(r[groupKey] ?? ""))).sort((a, b) => a.localeCompare(b, undefined, { numeric: true })).map((g) => ({ name: g, y: yKeys[0], filter: (r) => String(r[groupKey] ?? "") === g }))
        : yKeys.map((y) => ({ name: displayName(y, props.y), y, filter: () => true }));
    const fmt = valueFormatter(props, ctx.locale);
    const series = defs.map((def) => {
        const byCat = groupRows(rows, (r) => String(r[xKey] ?? ""), (r) => num(r[def.y]), def.filter);
        return {
            type: "bar",
            name: def.name,
            coordinateSystem: "polar",
            stack: props.stacked ? "total" : undefined,
            roundCap: type === "radialbar" && !props.stacked,
            emphasis: { focus: "self" },
            // radialbar: one colour per ring, the value at the ring's end
            colorBy: type === "radialbar" && defs.length === 1 ? "data" : undefined,
            label: type === "radialbar" ? { show: props.dataLabels !== false, position: "end", fontSize: 11, formatter: (p) => (fmt ? fmt(p.value) : String(p.value ?? "")) } : undefined,
            data: categories.map((c) => {
                const g = byCat.get(c);
                // rings coloured per category: the category is the item's name, which -ColorMap matches
                const named = type === "radialbar" && defs.length === 1 ? { name: c } : {};
                if (!g) return { value: null, ...named };
                return { value: props.aggregate ? aggregate(g.values, props.aggregate) : g.values[g.values.length - 1], ...named, rowIndex: props.aggregate ? g.rowIndex : g.lastRowIndex };
            })
        };
    });
    const angleMax = (props.max ?? ringMax(series, props.stacked)) * 4 / 3;
    if (type === "radialbar") uprightRingLabels(series, angleMax, props.stacked);
    const legend = legendOf(props, series.length > 1);
    const center = ["50%", props.title ? "55%" : "52%"];
    const valueAxis = { type: "value", max: props.max, min: props.min, axisLabel: fmt ? { formatter: (v) => fmt(v) } : {}, splitLine: { show: true } };
    const categoryAxis = { type: "category", data: categories, axisLabel: { interval: 0 } };
    return {
        title: titleOf(props),
        legend,
        tooltip: { trigger: "item", confine: true, valueFormatter: fmt || undefined },
        toolbox: toolboxOf(props, false, ctx),
        polar: { center, radius: type === "radialbar" ? ["18%", "72%"] : ["12%", "70%"] },
        // radialbar: categories are the rings, the value runs around; the full value (-Max) fills three
        // quarters of the circle, so the ring names fit into the free quarter next to where the rings start.
        // polar: categories around, value outward
        angleAxis: type === "radialbar" ? { type: "value", min: 0, max: angleMax, startAngle: 90, show: false } : { ...categoryAxis, startAngle: 90 },
        radiusAxis: type === "radialbar" ? { ...categoryAxis, z: 10, axisLabel: { interval: 0, align: "right", margin: 10, fontSize: 11 }, axisLine: { show: false }, axisTick: { show: false } } : valueAxis,
        series
    };
}

/*
 * bump: the rank of each item (-GroupBy) per period (-X) by its value (-Y, highest first), as lines
 * that cross when items overtake each other - top customers by tickets per month, busiest hosts per
 * week. Periods keep the order of the data; equal values rank in the order the items first appear;
 * an item without a value in a period leaves a gap. The tooltip shows rank and value.
 */
export function bump(props, rows, keys, ctx) {
    const xKey = resolveColumn(props.x, keys) ?? keys[0];
    const groupKey = resolveColumn(props.groupBy, keys) ?? keys[1];
    const yKey = resolveColumns(props.y, keys)[0] ?? keys.find((k) => k !== xKey && k !== groupKey && rows.some((r) => typeof r[k] === "number"));
    const periods = unique(rows.map((r) => String(r[xKey] ?? "")));
    const items = unique(rows.map((r) => String(r[groupKey] ?? "")));
    const fmt = valueFormatter(props, ctx.locale);
    // value and first row per period and item
    const cell = new Map();
    rows.forEach((r, rowIndex) => {
        const k = `${r[xKey]}\u0000${r[groupKey]}`;
        const v = num(r[yKey]);
        const c = cell.get(k);
        if (c) c.values.push(v);
        else cell.set(k, { values: [v], rowIndex });
    });
    const rank = new Map();
    periods.forEach((p) => {
        const ranked = items
            .map((item) => ({ item, c: cell.get(`${p}\u0000${item}`) }))
            .filter((x) => x.c)
            .map((x) => ({ ...x, value: aggregate(x.c.values, props.aggregate || "sum") }))
            .filter((x) => x.value !== null)
            .sort((a, b) => b.value - a.value);
        ranked.forEach((x, i) => rank.set(`${p}\u0000${x.item}`, { rank: i + 1, value: x.value, rowIndex: x.c.rowIndex }));
    });
    const series = items.map((item) => ({
        type: "line",
        name: item,
        smooth: true,
        symbolSize: 10,
        emphasis: { focus: "series" },
        endLabel: { show: true, formatter: (p) => p.seriesName, distance: 8 },
        data: periods.map((p) => {
            const r = rank.get(`${p}\u0000${item}`);
            return r ? { value: r.rank, raw: r.value, rowIndex: r.rowIndex } : { value: null };
        })
    }));
    const legend = legendOf(props, true);
    return {
        title: titleOf(props),
        legend,
        grid: { ...gridOf(props, legend), right: 24 + 7 * Math.min(24, Math.max(0, ...items.map((i) => i.length))) },
        tooltip: { trigger: "item", confine: true, formatter: (p) => html`${p.seriesName} · ${p.name}<br/>#${p.value}: <b>${fmt ? fmt(p.data.raw) : p.data.raw}</b>` },
        toolbox: toolboxOf(props, false, ctx),
        xAxis: { type: "category", data: periods, boundaryGap: false, axisLabel: { hideOverlap: true } },
        yAxis: { type: "value", inverse: true, min: 1, max: Math.max(1, items.length), interval: 1, axisLabel: { formatter: (v) => `#${v}` }, splitLine: { show: true } },
        series
    };
}
