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
        // padding 5, a main line of about 30 px (18 px bold), a sub line of 18 px
        top = Math.max(top, 5 + (title.text ? 30 : 0) + (title.subtext ? 18 : 0));
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

// charts whose plot fitPlot() places: their layout depends on the chart's size, so the component
// applies the option again when the size changes noticeably
export function needsFit(option) {
    return Boolean(option && (option.polar || option.radar || list(option.series).some((s) => RECT_BOX.has(s.type) || PIE_BOX.has(s.type) || CENTERED.has(s.type))));
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

/*
 * Labels drawn on a fill (funnel stages, pie slices with inside labels, treemap tiles,
 * sunburst rings) get the text colour with the higher contrast to that fill. The fills are the
 * palette colours ECharts assigns: per data item for funnel and pie, per top-level node for treemap
 * (children keep it) and sunburst (deeper rings lighter, as ECharts draws them).
 */
export function insideLabelColors(option, palette) {
    const colors = Array.isArray(option && option.color) && option.color.length ? option.color : palette;
    if (!option || !Array.isArray(colors) || !colors.length) return option;
    let changed = false;
    const series = list(option.series).map((s) => {
        if ((s.type === "funnel" || s.type === "pie") && Array.isArray(s.data)) {
            if (!isInside(s.label)) return s;
            const pick = paletteByName(colors);
            changed = true;
            return { ...s, data: s.data.map((d) => withLabelColor(d, textOn(itemColor(d) || pick(String(d && typeof d === "object" ? d.name : d))))) };
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
