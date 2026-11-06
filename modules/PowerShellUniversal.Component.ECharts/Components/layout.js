import { textOn, lighten } from "../../../shared/js/contrast.js";

/*
 * Room for title, toolbox and legend in charts without a cartesian grid. A grid keeps its plot clear
 * of them through grid.top/bottom; funnels, treemaps, pies, sunbursts, gauges and polar/radar charts
 * are laid out by their own box or by a centre and radius relative to the whole chart, so they ran
 * under the toolbox or a legend that wraps over several lines in a narrow container.
 *
 * fitPlot() runs where the chart's size is known (EChart.jsx, after the width rules): it estimates the
 * bands title, toolbox and legend take from the option itself and moves or shrinks the plot out of
 * them. What the user set in -Options for a series or a coordinate system is kept.
 */

const RECT_BOX = new Set(["funnel", "treemap"]);
const PIE_BOX = new Set(["pie"]);
const CENTERED = new Set(["sunburst", "gauge"]);
const GAP = 6;

function list(v) {
    return Array.isArray(v) ? v : v ? [v] : [];
}

function pct(value, of) {
    if (typeof value === "number") return value;
    const s = String(value ?? "").trim();
    if (s.endsWith("%")) return (parseFloat(s) / 100) * of;
    const n = parseFloat(s);
    return Number.isFinite(n) ? n : undefined;
}

// the user's -Options part for element i of a generated array (series[i]), or for every element
function userPart(user, key, i) {
    const part = user && user[key];
    if (Array.isArray(part)) return part[i] || {};
    return part && typeof part === "object" ? part : {};
}

function setsAny(part, keys) {
    return keys.some((k) => Object.prototype.hasOwnProperty.call(part, k));
}

// ---- legend ------------------------------------------------------------------------------------

function legendNames(option, legend) {
    if (Array.isArray(legend.data)) return legend.data.map((d) => (d && typeof d === "object" ? d.name : d));
    const names = [];
    for (const s of list(option.series)) {
        if (s.type === "pie" || s.type === "funnel") for (const d of list(s.data)) names.push(d && typeof d === "object" ? d.name : d);
        else if (s.name !== undefined) names.push(s.name);
    }
    return names.map((n) => String(n ?? ""));
}

/*
 * Lines a horizontal legend takes at this width: always one for "scroll" (it pages instead), for
 * "plain" the items packed line by line. Text width is estimated (0.6 em per character), on the safe
 * side for proportional fonts.
 */
export function legendRows(option, width) {
    const legend = list(option.legend)[0];
    if (!legend || legend.show === false || legend.orient === "vertical") return 0;
    if (legend.type !== "plain") return 1;
    const font = (legend.textStyle && legend.textStyle.fontSize) || 12;
    const icon = legend.itemWidth ?? 25;
    const gap = legend.itemGap ?? 10;
    const room = Math.max(1, width - 20);
    let rows = 1;
    let used = 0;
    for (const name of legendNames(option, legend)) {
        const item = icon + 5 + name.length * font * 0.6;
        if (used > 0 && used + item > room) {
            rows += 1;
            used = 0;
        }
        used += item + gap;
    }
    return rows;
}

function legendHeight(rows, legend) {
    const item = Math.max(legend.itemHeight ?? 14, ((legend.textStyle && legend.textStyle.fontSize) || 12) + 2);
    return 10 + rows * item + (rows - 1) * (legend.itemGap ?? 10);
}

// ---- bands ---------------------------------------------------------------------------------------

/*
 * The bands at the top and bottom of the chart that the plot must stay out of, in px from the top
 * and from the bottom, and the toolbox's rectangle (it sits top right, so a round plot may pass it).
 */
export function plotBands(option, width) {
    let top = 0;
    let bottom = 0;
    const title = list(option.title)[0];
    if (title && title.show !== false && (title.text || title.subtext)) {
        // padding 5, a main line of about 30 px (18 px bold), a sub line of 18 px (12 px), both growing
        // with the text size (--psu-chart-font-size, fonts.js)
        const main = (title.textStyle && title.textStyle.fontSize) || 18;
        const sub = (title.subtextStyle && title.subtextStyle.fontSize) || 12;
        top = Math.max(top, 5 + (title.text ? Math.round(main * 5 / 3) : 0) + (title.subtext ? Math.round(sub * 1.5) : 0));
    }
    const legend = list(option.legend)[0];
    const rows = legend ? legendRows(option, width) : 0;
    if (rows) {
        if (legend.bottom !== undefined) bottom = Math.max(bottom, (pct(legend.bottom, 0) || 0) + legendHeight(rows, legend));
        else if (typeof legend.top === "number") top = Math.max(top, legend.top + legendHeight(rows, legend));
    }
    let toolbox = null;
    const tb = list(option.toolbox)[0];
    if (tb && tb.show !== false) {
        const size = tb.itemSize ?? 15;
        const gap = tb.itemGap ?? 10;
        const shown = Object.values(tb.feature || {}).filter((f) => f && f.show !== false).length;
        const y = typeof tb.top === "number" ? tb.top : 0;
        // measured (ECharts 6.1): 5 icons of 15 px with gaps of 10 take 133 px, of 13 px with gaps of
        // 6 take 108 px, ending 15 px left of `right`; the icons run 15 px below `top`
        const w = shown * (size + gap) + 13;
        toolbox = { x: width - (tb.right ?? 8) - 15 - w, y, w: w + 15, h: 20 + size + 5 };
    }
    return { top, bottom, toolbox };
}

// a circle closer than GAP to the rectangle counts as touching it
function circleHitsRect(cx, cy, r, rect) {
    const nx = Math.max(rect.x, Math.min(cx, rect.x + rect.w));
    const ny = Math.max(rect.y, Math.min(cy, rect.y + rect.h));
    return (cx - nx) ** 2 + (cy - ny) ** 2 < (r + GAP) ** 2;
}

/*
 * A round plot (centre cx/cy, outer radius r in px) inside the band [top, height - bottom]: moved down
 * past the toolbox when it would run under it, shrunk only when it does not fit otherwise.
 * Returns { cy, scale } or null when it fits as it is.
 */
function fitCircle(cx, cy, r, bands, height) {
    let top = bands.top;
    if (bands.toolbox && circleHitsRect(cx, cy, r, bands.toolbox)) top = Math.max(top, bands.toolbox.y + bands.toolbox.h);
    const bottom = height - bands.bottom;
    if (cy - r >= top + GAP && cy + r <= bottom - GAP) return null;
    const room = Math.max(10, bottom - top - 2 * GAP);
    const nr = Math.min(r, room / 2);
    const ny = Math.min(Math.max(cy, top + GAP + nr), bottom - GAP - nr);
    return { cy: ny, scale: nr / r };
}

// a component or series laid out by centre and radius relative to the whole chart (sunburst, gauge,
// polar, radar): the new centre and radius in px; gauges with one centre (rings) move together
function fitCentered(items, bands, width, height) {
    const groups = new Map();
    for (const item of items) {
        const center = list(item.obj.center).length ? item.obj.center : ["50%", "50%"];
        const key = JSON.stringify(center);
        if (!groups.has(key)) groups.set(key, []);
        groups.get(key).push(item);
    }
    for (const [key, group] of groups) {
        const center = JSON.parse(key);
        const cx = pct(center[0], width);
        const cy = pct(center[1], height);
        const size = Math.min(width, height) / 2;
        const radii = group.map((g) => {
            const r = Array.isArray(g.obj.radius) ? g.obj.radius : [0, g.obj.radius ?? g.fallback];
            return [pct(r[0], size) || 0, pct(r[1], size)];
        });
        const outer = Math.max(...radii.map((r) => r[1] || 0));
        if (!(outer > 0) || cx === undefined || cy === undefined) continue;
        const fit = fitCircle(cx, cy, outer, bands, height);
        if (!fit) continue;
        group.forEach((g, i) => {
            if (g.locked) return;
            g.set({ center: [center[0], Math.round(fit.cy)], radius: [Math.round(radii[i][0] * fit.scale), Math.round(radii[i][1] * fit.scale)] });
        });
    }
}

// ---- text ---------------------------------------------------------------------------------------

// estimated size of a label in px: 0.6 em per character (on the safe side for proportional fonts),
// 1.25 em per line
function textSize(text, font) {
    const lines = String(text ?? "").split("\n");
    return { w: Math.max(...lines.map((l) => l.length)) * font * 0.6, h: lines.length * font * 1.25 };
}

// ---- funnel labels -------------------------------------------------------------------------------

/*
 * The stages of a vertical funnel as ECharts lays them out (funnelLayout: the value range [min, max]
 * maps to [minSize, maxSize] of the box width; a stage runs from its own width at the top to the next
 * stage's width at the bottom, the last one to the smallest size).
 */
export function funnelStages(s, width, height, left = pct(s.left, width) ?? 0, boxW = pct(s.width, width) ?? width - left - (pct(s.right, width) ?? 0)) {
    const data = list(s.data).map((d) => (d && typeof d === "object" ? d : { value: d }));
    const value = (d) => (typeof d.value === "number" ? d.value : 0);
    const order = data.map((d, i) => i);
    if (s.sort !== "none") order.sort((a, b) => (s.sort === "ascending" ? value(data[a]) - value(data[b]) : value(data[b]) - value(data[a])));
    const values = data.map(value);
    const min = s.min ?? Math.min(0, ...values);
    const max = s.max ?? Math.max(...values);
    const lo = pct(s.minSize ?? "0%", boxW) ?? 0;
    const hi = pct(s.maxSize ?? "100%", boxW) ?? boxW;
    const size = (v) => (max > min ? lo + ((Math.min(Math.max(v, min), max) - min) / (max - min)) * (hi - lo) : hi);
    const top = pct(s.top, height) ?? 0;
    const boxH = height - top - (pct(s.bottom, height) ?? 0);
    const gap = s.gap || 0;
    const stageH = (boxH - gap * (data.length - 1)) / Math.max(1, data.length);
    // ascending: the smallest stage on top, the funnel widens downwards
    const next = (i) => (i + 1 < order.length ? size(value(data[order[i + 1]])) : lo);
    return order.map((index, i) => ({ index, top: size(value(data[index])), bottom: next(i), height: stageH }));
}

function labelText(s, d, sum) {
    const f = d.label && d.label.formatter !== undefined ? d.label.formatter : s.label && s.label.formatter;
    const p = { name: d.name, value: d.value, percent: sum ? (d.value / sum) * 100 : 0, data: d };
    if (typeof f === "function") return String(f(p));
    if (typeof f === "string") return f.replace(/\{b\}/g, String(d.name ?? "")).replace(/\{c\}/g, String(d.value ?? "")).replace(/\{d\}/g, p.percent.toFixed(2));
    return String(d.name ?? "");
}

/*
 * Labels inside funnel stages that are too small for them (the last stages, or every stage of a low
 * chart with many of them) go to the right of the funnel on one line, with a label line; the funnel
 * gets narrower to make room. When even that leaves no room, they are hidden (the tooltip and the
 * legend still name the stage). A label that sticks out of its stage would otherwise be dark text on
 * the page background in dark mode, or cover the neighbouring labels.
 */
export function fitFunnelLabels(s, width, height) {
    if (s.orient === "horizontal" || !isInside(s.label) || !Array.isArray(s.data)) return s;
    const font = s.label.fontSize || 12;
    const data = s.data.map((d) => (d && typeof d === "object" ? d : { value: d }));
    const sum = data.reduce((a, d) => a + (typeof d.value === "number" ? d.value : 0), 0);
    const texts = data.map((d) => labelText(s, d, sum));
    const fits = (stage) => {
        const t = textSize(texts[stage.index], font);
        if (t.h > stage.height - 2) return false;
        // the width at the lower edge of the text (stages narrow downwards)
        const at = stage.top + (stage.bottom - stage.top) * Math.min(1, (stage.height + t.h) / 2 / stage.height);
        return t.w + 8 <= Math.min(at, stage.top);
    };
    let misfits = funnelStages(s, width, height).filter((st) => !fits(st)).map((st) => st.index);
    if (!misfits.length) return s;
    const oneLine = (t) => t.replace(/\n/g, " ");
    const lineLength = 20;
    const room = Math.max(...misfits.map((i) => textSize(oneLine(texts[i]), font).w)) + lineLength + 5 + GAP;
    const left = Math.max(8, Math.round(width * 0.04));
    const boxW = width - left - room - GAP;
    const out = { ...s };
    if (boxW >= width * 0.45) {
        out.left = left;
        out.width = Math.round(boxW);
        // narrower: a stage that fitted may not fit any more
        misfits = funnelStages(out, width, height).filter((st) => !fits(st)).map((st) => st.index);
        const base = s.label.formatter;
        const single = typeof base === "function" ? (p) => oneLine(String(base(p))) : base;
        out.data = data.map((d, i) => (misfits.includes(i) ? { ...d, label: { ...(d.label || {}), position: "right", formatter: single }, labelLine: { show: true, length: lineLength, ...(d.labelLine || {}) } } : d));
        // outside labels of thin neighbouring stages may still touch
        out.labelLayout = { hideOverlap: true, ...(s.labelLayout || {}) };
    } else {
        out.data = data.map((d, i) => (misfits.includes(i) ? { ...d, label: { ...(d.label || {}), show: false } } : d));
    }
    return out;
}

// ---- layered network graph -----------------------------------------------------------------------

function isPlacedGraph(s) {
    return s.type === "graph" && s.layout === "none" && list(s.data).some((d) => d && typeof d.x === "number");
}

/*
 * A layered graph's box below title, legend and toolbox and above the bottom, with room for the
 * largest node and the labels under the nodes; the node coordinates rescaled to the box's ratio.
 */
function fitGraph(s, bands, width, height, mine) {
    const data = list(s.data);
    const symbol = Math.max(10, ...data.map((d) => (typeof d.symbolSize === "number" ? d.symbolSize : 10)));
    const font = (s.label && s.label.fontSize) || 12;
    const labelled = s.label && s.label.show !== false;
    const longest = labelled ? Math.max(0, ...data.map((d) => textSize(d.name, font).w)) : 0;
    const reach = bands.toolbox ? Math.max(bands.top, bands.toolbox.y + bands.toolbox.h) : bands.top;
    const side = Math.round(Math.max(symbol / 2, longest / 2) + GAP);
    if (!setsAny(mine, ["top"])) s.top = Math.round(reach + symbol / 2 + GAP);
    if (!setsAny(mine, ["bottom"])) s.bottom = Math.round(bands.bottom + symbol / 2 + (labelled ? font * 1.25 + 5 : 0) + GAP);
    if (!setsAny(mine, ["left"])) s.left = side;
    if (!setsAny(mine, ["right"])) s.right = side;
    const boxW = width - pct(s.left, width) - pct(s.right, width);
    const boxH = height - pct(s.top, height) - pct(s.bottom, height);
    // ECharts maps the extent of the coordinates onto the box: scaled so that the extents have the
    // box's ratio, x and y stretch alike and the nodes stay round
    const span = (key) => {
        const v = data.map((d) => d[key]).filter((n) => typeof n === "number");
        return Math.max(...v) - Math.min(...v);
    };
    const spanX = span("x");
    const spanY = span("y");
    if (boxW > 0 && boxH > 0 && spanX > 0 && spanY > 0 && !setsAny(mine, ["data"])) {
        const k = (boxH / boxW) * (spanX / spanY);
        s.data = data.map((d) => (typeof d.y === "number" ? { ...d, y: d.y * k } : d));
    }
}

// ---- radial bars ---------------------------------------------------------------------------------

/*
 * radialbar: the ring names sit right-aligned next to where the rings start (12 o'clock); the round
 * cap of each ring reaches half the ring's width past that line, so the names keep that distance.
 * A ring is at most 80 % of its band (ECharts' barCategoryGap of 20 %).
 */
function fitRingNames(option, width, height, user) {
    const axis = option.radiusAxis;
    if (!axis || axis.type !== "category" || !option.angleAxis || option.angleAxis.type !== "value") return;
    if (setsAny(userPart(user, "radiusAxis", 0).axisLabel || {}, ["margin"])) return;
    const polar = list(option.polar)[0] || {};
    const size = Math.min(width, height) / 2;
    const r = Array.isArray(polar.radius) ? polar.radius : [0, polar.radius ?? "75%"];
    const inner = pct(r[0], size) || 0;
    const outer = pct(r[1], size) || size;
    const rings = Math.max(1, list(axis.data).length);
    const cap = ((outer - inner) / rings) * 0.8 / 2;
    option.radiusAxis = { ...axis, axisLabel: { ...(axis.axisLabel || {}), margin: Math.round(cap + GAP) } };
}

// charts whose plot fitPlot() places: their layout depends on the chart's size, so the component
// applies the option again when the size changes noticeably
export function needsFit(option) {
    return Boolean(option && (option.polar || option.radar || list(option.series).some((s) => RECT_BOX.has(s.type) || PIE_BOX.has(s.type) || CENTERED.has(s.type) || isPlacedGraph(s))));
}

/*
 * The option with the plot of a non-grid chart moved out of the bands of title, toolbox and legend.
 * size: { width, height } of the chart in px; user: the -Options of the chart.
 */
export function fitPlot(option, size, user) {
    const width = size && size.width;
    const height = size && size.height;
    if (!(width > 0 && height > 0) || !option) return option;
    if (!needsFit(option)) return option;
    const series = list(option.series);
    const bands = plotBands(option, width);
    const out = { ...option, series: series.map((s) => ({ ...s })) };
    const centered = [];
    out.series.forEach((s, i) => {
        const mine = userPart(user, "series", i);
        if (RECT_BOX.has(s.type)) {
            // a funnel's widest stage and a treemap span the width: below title, toolbox and top legend
            const reach = bands.toolbox ? Math.max(bands.top, bands.toolbox.y + bands.toolbox.h) : bands.top;
            if (!setsAny(mine, ["top"])) s.top = Math.max(pct(s.top, height) || 0, reach + GAP);
            if (!setsAny(mine, ["bottom"])) s.bottom = Math.max(pct(s.bottom, height) || 0, bands.bottom + GAP);
            if (s.type === "funnel") Object.assign(s, fitFunnelLabels(s, width, height));
        } else if (isPlacedGraph(s)) {
            fitGraph(s, bands, width, height, mine);
        } else if (PIE_BOX.has(s.type)) {
            if (setsAny(mine, ["top", "bottom", "center", "radius"])) return;
            // the pie sits in its box (top/bottom); centre and radius relative to that box
            const boxTop = pct(s.top, height) || 0;
            const boxBottom = Math.max(pct(s.bottom, height) || 0, bands.bottom + GAP);
            const boxH = height - boxTop - boxBottom;
            const center = list(s.center).length ? s.center : ["50%", "50%"];
            const r = Array.isArray(s.radius) ? s.radius : [0, s.radius ?? "50%"];
            const outer = pct(r[1], Math.min(width, boxH) / 2);
            const cx = pct(center[0], width);
            const cy = boxTop + pct(center[1], boxH);
            s.bottom = boxBottom;
            const fit = outer > 0 ? fitCircle(cx, cy, outer, { ...bands, bottom: boxBottom }, height) : null;
            if (fit) s.top = Math.max(boxTop, Math.round(fit.cy - outer * fit.scale - GAP));
        } else if (CENTERED.has(s.type)) {
            centered.push({ obj: s, fallback: s.type === "gauge" ? "75%" : "100%", locked: setsAny(mine, ["center", "radius"]), set: (v) => Object.assign(s, v) });
        }
    });
    for (const key of ["polar", "radar"]) {
        if (!option[key]) continue;
        const parts = list(option[key]).map((p) => ({ ...p }));
        parts.forEach((p, i) => centered.push({ obj: p, fallback: key === "radar" ? "75%" : "100%", locked: setsAny(userPart(user, key, i), ["center", "radius"]), set: (v) => Object.assign(p, v) }));
        out[key] = Array.isArray(option[key]) ? parts : parts[0];
    }
    fitCentered(centered, bands, width, height);
    fitRingNames(out, width, height, user);
    return out;
}

// ---- labels on fills -----------------------------------------------------------------------------

function itemColor(item) {
    return item && typeof item === "object" && item.itemStyle && typeof item.itemStyle.color === "string" ? item.itemStyle.color : undefined;
}

function withLabelColor(item, color) {
    if (!color) return item;
    const base = item && typeof item === "object" ? item : { value: item };
    // a colour the user gave the label stays
    if (base.label && base.label.color) return base;
    return { ...base, label: { ...(base.label || {}), color } };
}

// palette colour per name in order of first appearance, as ECharts picks it per series
function paletteByName(palette) {
    const seen = new Map();
    return (name) => {
        if (!seen.has(name)) seen.set(name, palette[seen.size % palette.length]);
        return seen.get(name);
    };
}

// only labels placed on the shape: ECharts' default for pie and funnel labels is outside
function isInside(label) {
    return Boolean(label && label.show !== false && (String(label.position).startsWith("inside") || label.position === "center"));
}

// the label of one data item: its own position wins over the series'
function itemLabel(series, item) {
    const own = item && typeof item === "object" && item.label;
    return own ? { ...(series.label || {}), ...own } : series.label;
}

/*
 * Labels drawn on a fill (funnel stages, pie slices with inside labels, treemap tiles,
 * sunburst rings) get the text colour with the higher contrast to that fill. The fills are the
 * palette colours ECharts assigns: per data item for funnel and pie, per top-level node for treemap
 * (children keep it) and sunburst (deeper rings lighter, as ECharts draws them).
 */
export function insideLabelColors(option, palette, text) {
    const colors = Array.isArray(option && option.color) && option.color.length ? option.color : palette;
    if (!option || !Array.isArray(colors) || !colors.length) return option;
    let changed = false;
    const series = list(option.series).map((s) => {
        if ((s.type === "funnel" || s.type === "pie") && Array.isArray(s.data)) {
            if (!isInside(s.label)) return s;
            const pick = paletteByName(colors);
            changed = true;
            return {
                ...s,
                data: s.data.map((d) => {
                    const fill = itemColor(d) || pick(String(d && typeof d === "object" ? d.name : d));
                    // a label moved out of its stage (fitFunnelLabels) sits on the page: page text colour
                    if (isInside(itemLabel(s, d))) return withLabelColor(d, textOn(fill));
                    const item = withLabelColor(d, text);
                    return text && item.labelLine && item.labelLine.show ? { ...item, labelLine: { ...item.labelLine, lineStyle: { color: text, opacity: 0.5, ...((item.labelLine && item.labelLine.lineStyle) || {}) } } } : item;
                })
            };
        }
        if (s.type === "treemap" || s.type === "sunburst") {
            const pick = paletteByName(colors);
            const height = (nodes) => (nodes || []).reduce((h, n) => Math.max(h, 1 + height(n.children)), 0);
            const treeHeight = height(s.data);
            const walk = (nodes, depth, inherited) => (nodes || []).map((n, i) => {
                let fill = itemColor(n) || (depth === 1 ? pick(String(n.name ?? i)) : inherited);
                const own = fill;
                // ECharts: sunburst rings below the first are lighter by depth (its tree height counts
                // the root it adds above the data; measured: the second of two rings 25 % lighter)
                if (s.type === "sunburst" && depth > 1 && !itemColor(n)) fill = lighten(inherited, ((depth - 1) / treeHeight) * 0.5);
                // (a treemap's group headers sit on the gap colour of the theme, not on the fill: left alone)
                const node = withLabelColor(n, textOn(fill));
                return n.children ? { ...node, children: walk(n.children, depth + 1, s.type === "sunburst" ? own : fill) } : node;
            });
            changed = true;
            return { ...s, data: walk(s.data, 1) };
        }
        return s;
    });
    return changed ? { ...option, series: Array.isArray(option.series) ? series : series[0] } : option;
}
