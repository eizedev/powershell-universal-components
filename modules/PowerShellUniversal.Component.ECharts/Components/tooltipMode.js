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
 * A fresh state per chart instance. EChart.jsx writes it, the formatter reads it:
 *   hover  { seriesIndex, dataIndex } of the element under the pointer, or null
 *   live   [{ type, stack }] per series after the toolbox switched line/bar/stack at runtime, or null
 *          while the series are as built (cleared on restore and whenever the option is applied)
 */
export function tooltipState() {
    return { hover: null, live: null };
}

/*
 * The tooltip formatter of a cartesian chart.
 *   mode        resolved mode (auto, item or axis)
 *   series      the option's series (helper series - trend, band - have tooltip.show false)
 *   valueOf     item -> the number behind it (a 100 % stack: the original value)
 *   rowText     item -> the formatted value text (normalize: share and raw value)
 *   header      items -> the header text (category or x value)
 *   pointAt     (seriesIndex, item) -> that series' item at the same x as item, or undefined; on a
 *               time or value axis series hold only their own rows, so a data index is no position
 *   totalLabel  stack name -> the label of its total row ("Total"; two stacks with -SecondaryY)
 *   fmt         number formatter for the total
 *   state       tooltipState() of the chart, or undefined (no hover tracking: as axis)
 */
export function cartesianTooltipFormatter({ mode, series, valueOf, rowText, header, pointAt, totalLabel, fmt, state }) {
    const helper = new Set(series.map((s, i) => (s && s.tooltip && s.tooltip.show === false ? i : -1)).filter((i) => i >= 0));
    // type and stack as drawn now: the toolbox may have switched them since the option was built
    const live = (i) => (state && state.live ? state.live[i] : undefined);
    const typeOf = (i) => (live(i) ? live(i).type : series[i] && series[i].type);
    const stackOf = (i) => (live(i) ? live(i).stack : series[i] && series[i].stack) || undefined;
    const fmtTotal = (v) => (fmt ? fmt(v) : String(v));

    // the total of the stack the item belongs to: every series of that stack at the item's x
    const totalOf = (item) => {
        const stack = stackOf(item.seriesIndex);
        let sum = 0;
        let any = false;
        series.forEach((_, i) => {
            if (helper.has(i) || stackOf(i) !== stack) return;
            const point = pointAt(i, item);
            const v = point ? valueOf(point) : undefined;
            if (typeof v === "number" && Number.isFinite(v)) {
                sum += v;
                any = true;
            }
        });
        return any ? sum : undefined;
    };
    const row = (p) => html`${trusted(p.marker || "")}${p.seriesName}: <b>${rowText(p)}</b>`;
    const totals = (items) => {
        // one total per stack among the items (two with -SecondaryY, then named by their axis)
        const seen = new Map();
        items.forEach((p) => {
            const stack = stackOf(p.seriesIndex);
            if (stack && !seen.has(stack)) seen.set(stack, totalOf(p));
        });
        const several = seen.size > 1;
        return [...seen.entries()].filter(([, v]) => v !== undefined).map(([stack, v]) => html`${totalLabel(stack, several)}: <b>${fmtTotal(v)}</b>`);
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
        if (mode === "auto" && all.length > 1 && all.every((p) => typeOf(p.seriesIndex) === "bar" && stackOf(p.seriesIndex))) {
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
        out.push(...totals(shown.length ? shown : all));
        return joinHtml([head !== undefined && head !== "" ? html`${head}` : "", ...out].filter((x) => x !== ""), "<br/>");
    };
    format.reduce = reduce;
    return format;
}
