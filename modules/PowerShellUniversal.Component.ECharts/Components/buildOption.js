import { columnsOf, resolveColumn } from "../../../shared/js/columns.js";
import { cartesian, sparkline, facets } from "./cartesian.js";
import { applyColorMap } from "./colormap.js";
import { nameValue, heatmap, calendar, boxplot, histogram, waterfall } from "./distribution.js";
import { html, joinHtml, trusted } from "./html.js";
import { sankey, graph, matrixChart, treeChart, gantt, treeDiagram, chord, parallel, themeRiver } from "./network.js";
import { LARGE, CARTESIAN, list, mergeOptions, normalize } from "./optionParts.js";
import { candlestick, gauge, radar, polarChart, bump } from "./polar.js";
import { compileTemplate, columnsTemplate } from "./template.js";
import { textsFor } from "./texts.js";
import { resolveTooltipMode } from "./tooltipMode.js";

/*
 * Turns the simple parameters of New-UDEChart (chartType, x, y, groupBy, ...) and the rows into an
 * Apache ECharts option. The user's own -Options are merged over the result afterwards (mergeOptions),
 * so anything ECharts can do stays reachable. Pure function: no DOM, no ECharts instance, testable
 * with node --test.
 *
 * Series data items carry rowIndex (the row they came from) so events can hand the row back to
 * PowerShell; above LARGE points they are plain arrays for speed and events carry values only.
 */

export { LARGE, quantile, boxStats, displayName, mergeOptions, axisBreaks, linearFit, toolboxOf, aggregate } from "./optionParts.js";
export { tooltipTracksHover } from "./cartesian.js";
export { NARROW, TINY, responsive, optionForWidth } from "./responsive.js";
export { uprightRingLabels } from "./polar.js";

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
                    const r = rowOf(rows, p);
                    if (r) return render(r);
                    return typeof previous === "function" ? previous(p) : p.name;
                }
            };
        });
    }
    if (tooltipTemplate !== undefined) {
        const render = compileTemplate(tooltipTemplate, keys, ctx.locale);
        const previous = option.tooltip && option.tooltip.formatter;
        // -TooltipMode Auto: the template covers the same items as the chart's own text (the hovered
        // one); none left (the gap of a stacked bar chart) means the chart's own text, the total
        const reduce = previous && typeof previous.reduce === "function" ? previous.reduce : (items) => items;
        const one = (p) => {
            const r = rowOf(rows, p);
            if (!r) return undefined;
            const head = p.name !== undefined && p.name !== "" ? html`<b>${p.name}</b><br/>` : "";
            return html`${head}${trusted(render(r, true))}`;
        };
        option.tooltip = {
            ...(option.tooltip || {}),
            formatter: (p) => {
                const items = reduce(Array.isArray(p) ? p : [p]);
                if (items.length === 0 && typeof previous === "function") return previous(p);
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

// parameters that name columns: a name that matches no column is an error, not a silently different chart
const COLUMN_PROPS = ["x", "y", "groupBy", "value", "source", "target", "path", "size", "secondaryY", "open", "close", "low", "high", "volume", "start", "end", "band", "facet", "labelColumn", "targetGroup", "edgeLabel", "eventColumns"];

function checkColumns(props, rows, keys) {
    if (rows.length === 0) {
        return;
    }
    const missing = [];
    for (const name of COLUMN_PROPS) {
        list(props[name]).forEach((c) => {
            if (c !== null && c !== undefined && c !== "" && resolveColumn(c, keys) === undefined) {
                missing.push(`-${name.charAt(0).toUpperCase()}${name.slice(1)} ${c}`);
            }
        });
    }
    if (missing.length) {
        throw new Error(`no column for ${missing.join(", ")}. Columns in the data: ${keys.join(", ")}`);
    }
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
    matrix: matrixChart,
    polar: polarChart,
    radialbar: polarChart,
    bump
};

export const CHART_TYPES = [...CARTESIAN, ...Object.keys(BUILDERS)];

/*
 * ctx: { locale, exportIcons, mode } - exportIcons { csv, xlsx (SVG paths), onCsv, onXlsx (handlers) }
 * turn on the CSV/Excel toolbox buttons; mode ("light" or "dark") picks the -ColorMap colours.
 */
// the rows a chart draws: objects only; a row's rowIndex (the click and selection events) counts these
export function dataRows(data) {
    return Array.isArray(data) ? data.filter((r) => r && typeof r === "object") : [];
}

// the row behind an event's data item, from the rows dataRows returned
export function rowOf(rows, params) {
    const data = params && params.data;
    const index = data && typeof data === "object" && !Array.isArray(data) ? data.rowIndex : undefined;
    return index === undefined ? undefined : rows[index];
}

export function buildOption(props, ctx = {}) {
    const rows = dataRows(props.data);
    const keys = columnsOf(rows);
    checkColumns(props, rows, keys);
    const type = String(props.chartType || "line").toLowerCase();
    // tooltipState: the hover state EChart.jsx keeps for -TooltipMode Auto (tooltipMode.js)
    const tooltipMode = resolveTooltipMode(props.tooltipMode, type);
    const context = { locale: ctx.locale || "en-US", texts: textsFor(ctx.locale || "en-US"), exportIcons: ctx.exportIcons, tooltipMode, tooltipState: ctx.tooltipState };
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
    // fixed colours per category name, over the palette; -Options can still override them
    option = applyColorMap(option, props.colorMap, ctx.mode === "dark" ? "dark" : "light");
    option.backgroundColor = "transparent";
    option.animation = rows.length <= LARGE;
    option.aria = { enabled: true, decal: { show: Boolean(props.decal) } };
    applyTemplates(option, props, rows, keys, context);
    if (tooltipMode === "none") {
        option.tooltip = { ...(Array.isArray(option.tooltip) ? {} : option.tooltip || {}), show: false };
    }
    if (rows.length === 0 && !option.graphic) {
        // an empty chart says so instead of showing bare axes
        option.graphic = { type: "text", left: "center", top: "middle", silent: true, style: { text: props.emptyText || context.texts.noData, fontSize: 14, fill: "#8a8f98" } };
    }
    return mergeOptions(normalize(option), props.options);
}
