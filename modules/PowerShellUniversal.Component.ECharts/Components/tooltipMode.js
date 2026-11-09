import { html, joinHtml, trusted } from "../../../shared/js/html.js";

/*
 * -TooltipMode: which items the tooltip of a cartesian chart (line, area, step, bar) covers.
 *
 *   auto  the element under the pointer wins: a bar, a bar segment or a line point shows that element
 *         only (stacked bars: plus the stack total); a position on the axis without an element shows
 *         all series there (stacked bars: the total only)
 *   item  always one element, nothing between them (ECharts trigger "item")
 *   axis  all series at the position (ECharts trigger "axis")
 *   none  no tooltip (every chart type)
 *
 * ECharts has no "item on an element, axis elsewhere" switch of its own. Auto keeps trigger "axis",
 * EChart.jsx tracks the hovered element in a state object (mouseover/mouseout, then showTip), and the
 * formatter built here reduces the axis items to the hovered one. The other chart types keep their
 * own tooltip; a mode they cannot honour is ignored, so a central default never breaks a chart.
 */

export const TOOLTIP_MODES = ["auto", "item", "axis", "none"];

/*
 * The mode for one chart: -TooltipMode is a mode name or a map of chart type to mode name, with '*'
 * for every other type ($PSDefaultParameterValues sets one value for all charts of an app). Keys and
 * values are matched case-insensitively; anything unknown falls back to auto.
 */
export function resolveTooltipMode(value, chartType) {
    const pick = (v) => {
        const m = typeof v === "string" ? v.toLowerCase() : undefined;
        return TOOLTIP_MODES.includes(m) ? m : undefined;
    };
    if (value && typeof value === "object" && !Array.isArray(value)) {
        const type = String(chartType || "").toLowerCase();
        let wildcard;
        for (const [k, v] of Object.entries(value)) {
            const key = k.toLowerCase();
            if (key === type && pick(v)) {
                return pick(v);
            }
            if (key === "*") {
                wildcard = pick(v);
            }
        }
        return wildcard || "auto";
    }
    return pick(value) || "auto";
}

/*
 * A fresh hover state per chart instance. EChart.jsx writes it, the formatter reads it:
 * hover { seriesIndex, dataIndex } of the element under the pointer, or null;
 * stacked true when the toolbox switched the bars to a stack at runtime.
 */
export function tooltipState() {
    return { hover: null, stacked: false };
}

/*
 * The tooltip formatter of a cartesian chart.
 *   mode       resolved mode (auto, item or axis)
 *   series     the option's series (helper series - trend, band - have tooltip.show false)
 *   stacked    the chart is stacked (-Stacked, -Normalize)
 *   isBar      the chart's series are bars (gaps show the total only when stacked)
 *   valueOf    item -> the number shown for it
 *   rowText    item -> the formatted value text (normalize: share and raw value)
 *   header     items -> the header text (category or x value)
 *   fmt        number formatter for the total
 *   state      tooltipState() of the chart, or undefined (no hover tracking: as axis)
 */
export function cartesianTooltipFormatter({ mode, series, stacked, isBar, valueOf, rowText, header, fmt, state, totalLabel = "Total" }) {
    const helper = new Set(series.map((s, i) => (s && s.tooltip && s.tooltip.show === false ? i : -1)).filter((i) => i >= 0));
    const stackOf = (i) => (series[i] && series[i].stack) || (state && state.stacked ? "__magic" : undefined);
    const isStacked = () => stacked || Boolean(state && state.stacked);
    const fmtTotal = (v) => (fmt ? fmt(v) : String(v));

    // the total of the stack the item belongs to, from every series at that position
    const totalOf = (item) => {
        const stack = stackOf(item.seriesIndex);
        if (!stack) {
            return undefined;
        }
        let sum = 0;
        let any = false;
        series.forEach((s, i) => {
            if (helper.has(i) || stackOf(i) !== stack) return;
            const d = Array.isArray(s.data) ? s.data[item.dataIndex] : undefined;
            const v = valueOf({ data: d, value: d && typeof d === "object" && !Array.isArray(d) ? d.value : d });
            if (typeof v === "number" && Number.isFinite(v)) {
                sum += v;
                any = true;
            }
        });
        return any ? sum : undefined;
    };
    const row = (p) => html`${trusted(p.marker || "")}${p.seriesName}: <b>${rowText(p)}</b>`;
    const totals = (items) => {
        // one total per stack among the items (two with -SecondaryY)
        const seen = new Map();
        items.forEach((p) => {
            const stack = stackOf(p.seriesIndex);
            if (stack && !seen.has(stack)) seen.set(stack, totalOf(p));
        });
        return [...seen.values()].filter((v) => v !== undefined).map((v) => html`${totalLabel}: <b>${fmtTotal(v)}</b>`);
    };

    const itemsOf = (params) => (Array.isArray(params) ? params : [params]).filter((p) => p && !helper.has(p.seriesIndex));
    /*
     * The items the tooltip covers: the hovered one (auto, pointer on an element), none for the gap
     * of a stacked bar chart (auto: the total only), all otherwise. Under trigger "item" ECharts
     * hands one item already. Exposed for -TooltipTemplate, which renders the same items.
     */
    const reduce = (params) => {
        const all = itemsOf(params);
        if (mode === "auto" && state && state.hover) {
            const hit = all.find((p) => p.seriesIndex === state.hover.seriesIndex && p.dataIndex === state.hover.dataIndex);
            if (hit) {
                return [hit];
            }
        }
        if (mode === "auto" && isBar && isStacked() && all.length > 1) {
            return [];
        }
        return all;
    };
    const format = (params) => {
        const all = itemsOf(params);
        if (all.length === 0) {
            return "";
        }
        const shown = reduce(all);
        const head = header(all);
        const out = shown.filter((p) => valueOf(p) !== null && valueOf(p) !== undefined).map(row);
        if (isStacked()) {
            out.push(...totals(shown.length ? shown : all));
        }
        return joinHtml([head !== undefined && head !== "" ? html`${head}` : "", ...out].filter((x) => x !== ""), "<br/>");
    };
    format.reduce = reduce;
    return format;
}
