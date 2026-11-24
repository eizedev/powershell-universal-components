import { CARTESIAN, mergeOptions, normalize } from "./optionParts.js";

// the rules that adapt a chart to its own width, applied on every resize (EChart.jsx)

// ---- responsive rules ----------------------------------------------------------------------------

/*
 * Rules for the chart's own width, applied again on every resize (window size, browser zoom, a card
 * that gets narrower; see optionForWidth). Below NARROW the chart keeps what it needs to be read and
 * drops what it cannot fit: outside labels of pie/donut become percentages inside the slices (names
 * stay in the legend and tooltip), bar labels go, toolbox and margins shrink.
 */
export const NARROW = 520;

export const TINY = 360;

export function responsive(option, props, ctx = {}) {
    const type = String(props.chartType || "line").toLowerCase();
    const series = Array.isArray(option.series) ? option.series : [];
    const pct = new Intl.NumberFormat(ctx.locale || "en-US", { style: "percent", maximumFractionDigits: 0 });
    const narrow = {
        toolbox: option.toolbox ? { itemSize: 13, itemGap: 6, feature: { magicType: { show: false }, dataZoom: { show: false }, brush: { show: false } } } : undefined,
        legend: option.legend && option.legend.show ? { itemGap: 6, itemWidth: 14, textStyle: { fontSize: 11 } } : undefined,
        title: option.title ? { textStyle: { fontSize: 14 }, subtextStyle: { fontSize: 11 } } : undefined
    };
    if (type === "pie" || type === "donut") {
        narrow.series = [{
            radius: type === "donut" ? ["38%", "78%"] : [0, "78%"],
            label: { show: true, position: "inside", formatter: (p) => (p.percent >= 6 ? pct.format(p.percent / 100) : ""), fontSize: 11 },
            labelLine: { show: false }
        }];
        narrow.legend = { ...(narrow.legend || {}), show: true, type: "scroll", bottom: 0 };
    } else if (CARTESIAN.has(type) || type === "histogram" || type === "waterfall" || type === "boxplot") {
        narrow.grid = { left: 4, right: 8 };
        narrow.xAxis = { axisLabel: { fontSize: 10 } };
        narrow.yAxis = { axisLabel: { fontSize: 10 }, nameTextStyle: { fontSize: 10 } };
        // value labels go only when the chart is tiny (see below); the tooltip still shows them
        if (props.dataLabels && type !== "waterfall") {
            narrow.series = series.map(() => ({ label: { fontSize: 10 } }));
        }
    } else if (type === "heatmap") {
        narrow.xAxis = { axisLabel: { rotate: 45, fontSize: 9 } };
        narrow.yAxis = { axisLabel: { fontSize: 9 } };
        // values in the cells only as small text; they overlap on a phone otherwise
        narrow.series = [{ label: { fontSize: 8 } }];
    } else if (type === "tree" || type === "graph") {
        narrow.series = [{ label: { fontSize: 9 }, left: type === "tree" ? 60 : undefined, right: type === "tree" ? 90 : undefined }];
    } else if (type === "chord") {
        narrow.series = [{ radius: ["52%", "60%"], label: { fontSize: 9 } }];
    } else if (type === "parallel") {
        narrow.parallel = { left: 20, right: 30 };
        narrow.parallelAxis = { nameTextStyle: { fontSize: 9 }, axisLabel: { fontSize: 9 } };
    } else if (type === "matrix") {
        narrow.matrix = { x: { label: { fontSize: 9 } }, y: { label: { fontSize: 9 }, levelSize: 70 } };
    } else if (type === "treemap") {
        narrow.series = [{ upperLabel: { show: false }, label: { fontSize: 10 } }];
    } else if (type === "sunburst") {
        narrow.series = [{ label: { fontSize: 9, minAngle: 12 } }];
    } else if (type === "radar") {
        narrow.radar = { radius: "55%", axisName: { fontSize: 9 } };
    } else if (type === "sankey") {
        narrow.series = [{ label: { fontSize: 9 }, nodeGap: 6, left: 4, right: 60 }];
    } else if (type === "gauge") {
        narrow.series = [{ detail: { fontSize: 18 }, axisLabel: { fontSize: 9, distance: 18 } }];
    }
    const tiny = {
        legend: option.legend && option.legend.show ? { textStyle: { fontSize: 10 }, itemWidth: 10, itemHeight: 8 } : undefined,
        toolbox: option.toolbox ? { show: false } : undefined,
        series: props.dataLabels && (CARTESIAN.has(type) || type === "histogram") ? series.map(() => ({ label: { show: false } })) : undefined
    };
    return [
        { maxWidth: NARROW, option: normalize(narrow) },
        { maxWidth: TINY, option: normalize(tiny) }
    ];
}

/*
 * The option for a chart of the given width: the base option with every rule whose maxWidth the
 * width is below merged over it. (ECharts' own media queries do not combine with replaceMerge,
 * which live updates need, so the component applies the rules itself on resize.)
 */
export function optionForWidth(option, rules, width) {
    return rules.filter((r) => width > 0 && width <= r.maxWidth).reduce((o, r) => mergeOptions(o, r.option), option);
}
