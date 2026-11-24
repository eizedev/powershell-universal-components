import { resolveColumn, resolveColumns } from "../../../shared/js/columns.js";
import { formatter } from "./formatters.js";
import { html, joinHtml, trusted } from "./html.js";
import { num, axisTypeFor, unique, displayName, valueFormatter, labelFormatter, titleOf, legendOf, gridOf, dataZoomOf, toolboxOf, markAreaOf, maxOf, hierarchy } from "./optionParts.js";
import { timeAxisLabel } from "./timeaxis.js";

// sankey, graph, matrix, treemap and sunburst, tree, chord, parallel, themeriver and gantt (buildOption.js)

export function sankey(props, rows, keys, ctx) {
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
export function graph(props, rows, keys, ctx) {
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
        // coordinates in about the shape of a wide card (height / width 0.42): ECharts stretches them
        // over the box; fitPlot() (layout.js) scales them to the box's own shape once its size is known
        const height = Math.max(1, columns.size - 1) * 200 * 0.42;
        columns.forEach((col, d) => col.forEach((n, i) => position.set(n, { x: d * 200, y: ((i + 0.5) * height) / col.length })));
    }
    // legend top-left (the toolbox sits top-right): a force layout is not bounded and would run over a bottom legend
    // ECharts drops "right" next to "left", so the width keeps the legend clear of the toolbox
    const legend = categories.length ? { show: true, type: "scroll", top: props.title ? 34 : 4, left: 0, width: props.toolbox === false ? "95%" : "60%", data: categories } : { show: false };
    return {
        title: titleOf(props),
        legend,
        tooltip: { confine: true, formatter: (p) => (p.dataType === "edge" ? html`${p.data.source} → ${p.data.target}${p.data.value !== undefined ? ": " + p.data.value : ""}` : html`${p.name}${p.data.category !== undefined && categories[p.data.category] ? " (" + categories[p.data.category] + ")" : ""}`) },
        toolbox: toolboxOf(props, false, ctx),
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
export function matrixChart(props, rows, keys, ctx) {
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
        toolbox: toolboxOf(props, false, ctx),
        matrix: {
            top: props.title ? 60 : 40,
            left: 8,
            right: 8,
            bottom: 8,
            x: { data: colCats, levelSize: 30 },
            y: { data: rowCats, levelSize: Math.min(220, 24 + 7 * (maxOf(rowCats.map((c) => c.length)) ?? 0)) }
        },
        grid,
        xAxis,
        yAxis,
        series
    };
}

export function treeChart(props, rows, keys, ctx) {
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
        toolbox: toolboxOf(props, false, ctx),
        series: [series]
    };
}

// ---- gantt: bars from -Start to -End per row (maintenance windows, job runs, on-call shifts) -----

export function gantt(props, rows, keys, ctx) {
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
        // room for the zoom slider below the last lane
        grid: gridOf({ ...props, dataLabels: false, zoomAuto: true }, legend),
        xAxis: { type: "time", position: "top", splitLine: { show: true }, axisLabel: timeAxisLabel(ctx.locale) },
        yAxis: { type: "category", data: lanes, inverse: true, axisTick: { show: false }, splitLine: { show: true } },
        dataZoom: dataZoomOf({ ...props, zoomAuto: true }, false, legend.show && legend.bottom !== undefined),
        toolbox: toolboxOf(props, false, ctx),
        series
    };
}

/*
 * tree: a hierarchy from -Path columns (vCenter, Cluster, Host, VM) as a collapsible tree; click a
 * node to open or close it. -Orient LR (default), TB or Radial; -Depth levels open at the start.
 */
export function treeDiagram(props, rows, keys, ctx) {
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
        toolbox: toolboxOf(props, false, ctx),
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
export function chord(props, rows, keys, ctx) {
    const sKey = resolveColumn(props.source ?? "source", keys) ?? keys[0];
    const tKey = resolveColumn(props.target ?? "target", keys) ?? keys[1];
    const vKey = resolveColumn(props.value ?? "value", keys) ?? keys[2];
    const names = unique(rows.flatMap((r) => [String(r[sKey] ?? ""), String(r[tKey] ?? "")])).filter((n) => n !== "");
    const fmt = valueFormatter(props, ctx.locale);
    return {
        title: titleOf(props),
        legend: props.legend === "none" ? { show: false } : { show: true, type: "scroll", bottom: 0 },
        tooltip: { trigger: "item", confine: true, formatter: (p) => (p.dataType === "edge" ? html`${p.data.source} ↔ ${p.data.target}: <b>${fmt ? fmt(p.data.value) : p.data.value}</b>` : html`${p.name}: <b>${fmt ? fmt(p.value) : p.value}</b>`) },
        toolbox: toolboxOf(props, false, ctx),
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
export function parallel(props, rows, keys, ctx) {
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
        toolbox: toolboxOf(props, false, ctx),
        parallel: { left: 40, right: 70, top: props.title ? 100 : 76, bottom: legend.show && legend.bottom !== undefined ? 50 : 30, parallelAxisDefault: { nameLocation: "end", nameGap: 16, axisLabel: { hideOverlap: true } } },
        parallelAxis: axes,
        series
    };
}

/*
 * themeriver: how the mix of categories changes over time (tickets per category per week), as
 * streams around a centre line. Long rows: -X date, -GroupBy category, -Y value.
 */
export function themeRiver(props, rows, keys, ctx) {
    const xKey = resolveColumn(props.x, keys) ?? keys[0];
    const groupKey = resolveColumn(props.groupBy, keys) ?? keys[1];
    const yKey = resolveColumns(props.y, keys)[0] ?? keys.find((k) => k !== xKey && k !== groupKey && rows.some((r) => typeof r[k] === "number"));
    const names = unique(rows.map((r) => String(r[groupKey] ?? ""))).sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
    const fmt = valueFormatter(props, ctx.locale);
    const legend = legendOf(props, true);
    const riverTime = axisTypeFor(rows.map((r) => r[xKey]), props.xAxisType, "line") === "time";
    return {
        title: titleOf(props),
        legend: { ...legend, data: names },
        tooltip: { trigger: "axis", confine: true, axisPointer: { type: "line" }, valueFormatter: fmt || undefined },
        toolbox: toolboxOf(props, false, ctx),
        singleAxis: { type: riverTime ? "time" : "category", axisLabel: riverTime ? timeAxisLabel(ctx.locale) : undefined, top: props.title ? 70 : 40, bottom: legend.show && legend.bottom !== undefined ? 60 : 30, axisPointer: { animation: true, label: { show: true } }, splitLine: { show: true, lineStyle: { type: "dashed", opacity: 0.3 } } },
        series: [{
            type: "themeRiver",
            emphasis: { focus: "series" },
            label: { show: false },
            data: rows.map((r) => [r[xKey], num(r[yKey]) ?? 0, String(r[groupKey] ?? "")])
        }]
    };
}
