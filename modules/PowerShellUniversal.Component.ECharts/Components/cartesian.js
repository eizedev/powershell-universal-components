import { resolveColumn, resolveColumns } from "../../../shared/js/columns.js";
import { formatter } from "./formatters.js";
import { html } from "./html.js";
import { LARGE, CARTESIAN, SHADE, list, num, axisTypeFor, unique, displayName, isPlainObject, valueFormatter, labelFormatter, titleOf, legendOf, gridOf, dataZoomOf, toolboxOf, markAreaOf, markLineOf, markPointOf, axisBreaks, maxOf, minOf, aggregate, groupRows, toTime, linearFit, medianStep } from "./optionParts.js";
import { timeAxisLabel } from "./timeaxis.js";
import { cartesianTooltipFormatter, resolveTooltipMode } from "./tooltipMode.js";

// line, area, bar, scatter and step charts (buildOption.js), as one chart, a sparkline or small multiples

export function cartesian(props_, rows, keys, ctx) {
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
            // one point per category and series; -Aggregate combines rows with the same category,
            // otherwise the last row wins
            const byCat = groupRows(rows, (r) => String(r[xKey] ?? ""), (r) => num(r[def.y]), def.filter);
            data = categories.map((c) => {
                const g = byCat.get(c);
                if (!g) return { value: null };
                return props.aggregate ? { value: aggregate(g.values, props.aggregate), rowIndex: g.rowIndex } : { value: g.values[g.values.length - 1], rowIndex: g.lastRowIndex };
            });
            if (large) {
                data = data.map((d) => d.value);
            }
        } else {
            data = [];
            const timeGroups = new Map();
            rows.forEach((r, rowIndex) => {
                if (def.filter(r)) {
                    const point = horizontal ? [num(r[def.y]), r[xKey]] : [xType === "value" ? num(r[xKey]) : r[xKey], num(r[def.y])];
                    // -Aggregate on a time or value axis: rows with the same x become one point
                    // (bucket dates first, e.g. to the day, when events should be counted per day)
                    if (props.aggregate && !horizontal && !sizeKey) {
                        const key = String(point[0]);
                        const seen = timeGroups.get(key);
                        if (seen) {
                            seen.values.push(point[1]);
                            return;
                        }
                        timeGroups.set(key, { point, values: [point[1]], rowIndex });
                        return;
                    }
                    if (sizeKey) {
                        point.push(num(r[sizeKey]));
                    }
                    data.push(large ? point : { value: point, rowIndex });
                }
            });
            for (const g of timeGroups.values()) {
                const point = [g.point[0], aggregate(g.values, props.aggregate)];
                data.push(large ? point : { value: point, rowIndex: g.rowIndex });
            }
        }
        const s = {
            type: seriesType,
            name: def.name,
            data,
            // a bar lights up alone, as the tooltip names it alone; a line lights up as a whole
            emphasis: { focus: seriesType === "bar" ? "self" : "series" },
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
        // first row per category, looked up once (a find per category is quadratic)
        const rowOfCat = new Map();
        rows.forEach((x) => { const c = String(x[xKey] ?? ""); if (!rowOfCat.has(c)) rowOfCat.set(c, x); });
        const low = categories ? categories.map((c) => { const r = rowOfCat.get(c); return r ? num(r[lowKey]) : null; }) : rows.map((r) => point(r, num(r[lowKey])));
        const width = categories
            ? categories.map((c) => { const r = rowOfCat.get(c); return r && num(r[highKey]) !== null && num(r[lowKey]) !== null ? num(r[highKey]) - num(r[lowKey]) : null; })
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
                id: `__trend${series.length}`,
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
                // the date as a label below the target, the line down to the axis without text of its own
                t.markPoint = { symbol: "circle", symbolSize: 8, data: [{ coord: [hit, num(props.trendTarget)], value: when }], label: { show: true, position: "left", distance: 6, formatter: () => when, fontSize: 11, fontWeight: "bold", textBorderWidth: 0, color: "inherit" }, tooltip: { show: true, formatter: () => html`${s.name}: ${fmt ? fmt(num(props.trendTarget)) : props.trendTarget} ≈ ${when}` } };
                t.markLine = { symbol: "none", silent: true, label: { show: false }, data: [{ xAxis: hit }], lineStyle: { type: "dotted" } };
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
        // numbers in the page's language also without -Format (ECharts itself writes 1,200 everywhere)
        axisLabel: { formatter: (v) => pointerFmt(v) },
        splitLine: { show: index === 0 }
    });
    const categoryAxis = {
        type: xType,
        breaks: axisBreaks(props.breaks, xType),
        breakArea: props.breaks ? { itemStyle: { color: "rgba(128,128,128,0.12)", borderColor: "rgba(128,128,128,0.35)", borderWidth: 1 }, zigzagAmplitude: 2 } : undefined,
        name: props.xTitle,
        data: categories,
        boundaryGap: seriesType === "bar" || xType === "category" ? undefined : false,
        // -XFormat wins; a time axis without it gets dates at day boundaries (see timeaxis.js)
        axisLabel: xType === "time" ? timeAxisLabel(ctx.locale, props.xFormat && xFmt ? (v) => xFmt(v) : undefined) : props.xFormat && xFmt ? { formatter: (v) => xFmt(v), hideOverlap: true } : { hideOverlap: true }
    };
    const yAxes = secondary.size > 0 ? [valueAxis(0), valueAxis(1)] : [valueAxis(0)];
    if (props.normalize) {
        const pct100 = formatter("percent100:0", ctx.locale);
        yAxes[0] = { ...yAxes[0], max: (extent) => Math.max(100, extent.max), axisLabel: { formatter: (v) => pct100(v) } };
    }
    // -Thresholds on lines and areas: each stretch of the line in the colour of its band (red above
    // the SLA). Upper bounds ascending, as for the gauge; above the last bound the last colour stays.
    const stops = list(props.thresholds).filter(isPlainObject).map((t) => ({ value: num(t.value), color: t.color })).filter((t) => t.value !== null && t.color).sort((a, b) => a.value - b.value);
    let visualMap;
    if (stops.length && seriesType === "line" && !horizontal) {
        const lines = series.map((s, i) => (s.type === "line" && s.stack !== "__band" && !String(s.id || "").startsWith("__trend") ? i : -1)).filter((i) => i >= 0);
        const pieces = stops.map((t, i) => ({ gt: i === 0 ? undefined : stops[i - 1].value, lte: t.value, color: t.color }));
        pieces.push({ gt: stops[stops.length - 1].value, color: stops[stops.length - 1].color });
        visualMap = { type: "piecewise", show: false, dimension: 1, seriesIndex: lines, pieces, outOfRange: { color: stops[stops.length - 1].color } };
    }
    // -TooltipMode (tooltipMode.js); scatter has no axis position to show, so it is always item
    const tipMode = cartesianTooltipMode(props, ctx.tooltipMode);
    const cartesianTooltip = () => {
        const pctF = formatter("percent100:1", ctx.locale);
        const pick = (v) => (Array.isArray(v) ? v[horizontal ? 0 : 1] : v);
        // a 100 % stack keeps the original value on the item (only on a category axis, see -Normalize above)
        const rawOf = (p) => (props.normalize && p.data && typeof p.data === "object" && p.data.raw !== undefined ? p.data.raw : undefined);
        // the number behind an item: the original value in a 100 % stack, else the value on the value axis
        const valueOf = (p) => rawOf(p) ?? pick(p.value);
        // x of an item on a time or value axis, where every series holds only its own rows
        const xOf = (v) => (Array.isArray(v) ? v[horizontal ? 1 : 0] : undefined);
        // an unreadable date matches nothing (two of them would both read as null)
        const sameX = (a, b) => (xType === "time" ? toTime(a) !== null && toTime(a) === toTime(b) : String(a) === String(b));
        const pointAt = (i, ref) => {
            const data = Array.isArray(series[i].data) ? series[i].data : [];
            const valueOfData = (d) => (d && typeof d === "object" && !Array.isArray(d) ? d.value : d);
            const d = categories ? data[ref.dataIndex] : data.find((e) => sameX(xOf(valueOfData(e)), xOf(ref.value)));
            return d === undefined ? undefined : { data: d, value: valueOfData(d) };
        };
        const tip = {
            trigger: tipMode === "item" ? "item" : "axis",
            axisPointer: { type: seriesType === "bar" ? "shadow" : "cross", label: { formatter: (p) => String((horizontal ? p.axisDimension === "y" : p.axisDimension === "x") ? (xFmt && xType !== "category" ? xFmt(p.value) : p.value) : pointerFmt(p.value)) } },
            // scatter keeps ECharts' own text, which hands the formatter each value of the point
            valueFormatter: fmt ? (v) => fmt(Array.isArray(v) ? v[v.length - 1] : v) : undefined,
            confine: true
        };
        if (seriesType === "scatter" && !props.normalize) {
            // ECharts' own text for a point (x, y and -Size)
            return tip;
        }
        tip.formatter = cartesianTooltipFormatter({
            mode: tipMode,
            series,
            valueOf,
            pointAt,
            // normalized: the share and the original value
            rowText: (p) => (rawOf(p) !== undefined ? `${pctF(p.value)} (${fmt ? fmt(rawOf(p)) : rawOf(p)})` : pointerFmt(pick(p.value))),
            // with -SecondaryY two stacks can show: name the second by its axis
            totalLabel: (stack, several) => (several && stack === "secondary" ? ctx.texts.totalSecondary : ctx.texts.total),
            header: (items) => {
                const p = items[0];
                if (p.axisValueLabel !== undefined) return p.axisValueLabel;
                if (categories) return p.name;
                const x = Array.isArray(p.value) ? p.value[horizontal ? 1 : 0] : undefined;
                return x === undefined ? p.name : xFmt ? xFmt(x) : String(x);
            },
            fmt: pointerFmt,
            state: ctx.tooltipState
        });
        return tip;
    };
    const legend = legendOf(props, series.length > 1);
    return {
        title: titleOf(props),
        legend,
        visualMap,
        grid: gridOf(props, legend),
        tooltip: cartesianTooltip(),
        // auto: the axis position does not highlight every bar, only the one under the pointer lights up
        axisPointer: tipMode === "auto" && seriesType === "bar" ? { triggerEmphasis: false } : undefined,
        xAxis: horizontal ? yAxes : categoryAxis,
        yAxis: horizontal ? { ...categoryAxis, inverse: true } : yAxes,
        dataZoom: dataZoomOf(props, horizontal, legend.show && legend.bottom !== undefined),
        brush: props.brush ? { xAxisIndex: "all", brushLink: "all", brushType: "lineX", outOfBrush: { colorAlpha: 0.2 } } : undefined,
        toolbox: toolboxOf(props, true, ctx),
        series
    };
}

/*
 * The tooltip mode a cartesian chart uses: scatter is always item (no axis position to show),
 * sparklines and -Facet panels always axis (too small to hit, linked panels), else -TooltipMode
 * (none is applied by buildOption for every type). One place for buildOption and EChart.jsx.
 */
export function cartesianTooltipMode(props, resolved) {
    const type = String(props.chartType || "").toLowerCase();
    if (type === "scatter") return "item";
    if (props.sparkline || props.facet) return "axis";
    return resolved === "item" || resolved === "axis" ? resolved : "auto";
}

// whether a chart's tooltip reads the hovered element (EChart.jsx tracks it only then)
export function tooltipTracksHover(props) {
    const type = String(props.chartType || "line").toLowerCase();
    const resolved = resolveTooltipMode(props.tooltipMode, type);
    return CARTESIAN.has(type) && resolved !== "none" && cartesianTooltipMode({ ...props, chartType: type }, resolved) === "auto";
}

// ---- sparkline: a tiny trend without axes, for tiles and tables ----------------------------------

export function sparkline(props, rows, keys, ctx) {
    // too small to hit a point: always the values at the position
    const base = cartesian({ ...props, legend: "none", toolbox: false, zoom: "none", dataLabels: false, markLine: undefined }, rows, keys, { ...ctx, tooltipMode: "axis" });
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

export function facets(props, rows, keys, ctx) {
    const facetKey = resolveColumn(props.facet, keys);
    const values = unique(rows.map((r) => r[facetKey])).map(String);
    const columns = Math.max(1, Math.min(props.facetColumns || Math.min(4, values.length), values.length));
    const rowsOfGrid = Math.ceil(values.length / columns);
    // linked panels compare one position across all of them: always the values at the position
    const parts = values.map((v) => cartesian({ ...props, facet: undefined, title: undefined, toolbox: false, legend: "none", zoom: "none", brush: false }, rows.filter((r) => String(r[facetKey] ?? "") === v), keys, { ...ctx, tooltipMode: "axis" }));
    // one value scale for all: comparable at a glance
    const allValues = parts.flatMap((p) => p.series.flatMap((s) => s.data.map((d) => (d && typeof d === "object" && !Array.isArray(d) ? d.value : d)).map((v) => (Array.isArray(v) ? v[1] : v)))).filter((v) => typeof v === "number");
    const max = props.yMax ?? (allValues.length ? maxOf(allValues) : undefined);
    const min = props.yMin ?? (allValues.length && minOf(allValues) < 0 ? minOf(allValues) : 0);
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
        toolbox: toolboxOf({ ...props, brush: false }, false, ctx),
        series
    };
}
