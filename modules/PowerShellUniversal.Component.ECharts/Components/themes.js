/*
 * ECharts themes that sit on PSU's page: transparent background, text and lines in the colours of
 * the current mode. ECharts' own "dark" theme paints a dark grey background box that does not match
 * PSU's black dark mode, so both modes are defined here (palette stays ECharts' default unless
 * -Palette is given).
 */

const LIGHT = { text: "#303133", muted: "#6e7079", axis: "#c9cdd4", split: "#e8eaef", tooltip: "#ffffff", tooltipBorder: "#e4e7ed" };
const DARK = { text: "#e5e7eb", muted: "#a3a8b3", axis: "#4b5058", split: "#2a2d33", tooltip: "#1f2125", tooltipBorder: "#3a3d44" };

function themeFor(c, psu) {
    const text = (psu && psu.text) || c.text;
    const axis = { axisLine: { lineStyle: { color: c.axis } }, axisTick: { lineStyle: { color: c.axis } }, axisLabel: { color: c.muted }, splitLine: { lineStyle: { color: c.split } }, nameTextStyle: { color: c.muted } };
    return {
        backgroundColor: "transparent",
        textStyle: { color: text, fontFamily: psu && psu.fontFamily ? psu.fontFamily : undefined },
        title: { textStyle: { color: text }, subtextStyle: { color: c.muted } },
        legend: { textStyle: { color: text }, pageTextStyle: { color: c.muted } },
        tooltip: { backgroundColor: c.tooltip, borderColor: c.tooltipBorder, textStyle: { color: text } },
        categoryAxis: axis,
        valueAxis: axis,
        timeAxis: axis,
        logAxis: axis,
        toolbox: { iconStyle: { borderColor: c.muted } },
        dataZoom: { textStyle: { color: c.muted }, borderColor: c.axis },
        visualMap: { textStyle: { color: text } },
        calendar: { dayLabel: { color: c.muted }, monthLabel: { color: c.muted }, yearLabel: { color: c.muted }, itemStyle: { color: "transparent", borderColor: c.split }, splitLine: { lineStyle: { color: c.axis } } },
        markLine: { label: { color: text } },
        // labels outside a shape take the page's text colour, without the light outline ECharts draws
        pie: { label: { color: text, textBorderWidth: 0 } },
        funnel: { label: { textBorderWidth: 0 } },
        bar: { label: { color: text, textBorderWidth: 0 } },
        line: { label: { color: text, textBorderWidth: 0 } },
        scatter: { label: { color: text, textBorderWidth: 0 } },
        sankey: { label: { color: text, textBorderWidth: 0 } },
        sunburst: { label: { textBorderWidth: 0 } },
        treemap: { label: { textBorderWidth: 0 } }
    };
}

// Registers psu-light / psu-dark (re-registered when PSU's colours change) and returns the name.
export function ensureTheme(echarts, mode, psuTheme) {
    const name = mode === "dark" ? "psu-dark" : "psu-light";
    echarts.registerTheme(name, themeFor(mode === "dark" ? DARK : LIGHT, psuTheme));
    return name;
}
