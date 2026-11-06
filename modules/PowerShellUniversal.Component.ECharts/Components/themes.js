/*
 * ECharts themes that sit on PSU's page: transparent background, text and lines in the colours of
 * the current mode. ECharts' own "dark" theme paints a dark grey background box that does not match
 * PSU's black dark mode, so both modes are defined here.
 *
 * A corporate design comes in two ways, both optional: CSS custom properties on the page (a PSU app
 * stylesheet sets them, per mode with [data-theme="dark"]), and an ECharts theme object per mode
 * (-LightTheme/-DarkTheme, e.g. the JSON the ECharts theme builder downloads), merged last.
 */

// light: ECharts' own default palette (a theme without "color" would leave series without colour)
const LIGHT = { text: "#303133", muted: "#6e7079", axis: "#c9cdd4", split: "#e8eaef", tooltip: "#ffffff", tooltipBorder: "#e4e7ed", accent: "#1976d2", palette: ["#5070dd", "#b6d634", "#505372", "#ff994d", "#0ca8df", "#ffd10a", "#fb628b", "#785db0", "#3fbe95"] };
// dark: ECharts' default palette, but its third colour (#505372, grey-violet) almost vanishes on a dark card
const DARK = { text: "#e5e7eb", muted: "#a3a8b3", axis: "#4b5058", split: "#2a2d33", tooltip: "#2c2f35", tooltipBorder: "#3a3d44", accent: "#64b5f6", palette: ["#5070dd", "#b6d634", "#9aa0d0", "#ff994d", "#0ca8df", "#ffd10a", "#fb628b", "#a58be0", "#3fbe95"] };

// CSS custom properties read from <html>; --psu-chart-1 ... --psu-chart-12 are the series colours
import { parseFontSize } from "./fonts.js";

const TOKENS = { text: "--psu-chart-text", muted: "--psu-chart-muted", axis: "--psu-chart-axis", split: "--psu-chart-grid", tooltip: "--psu-chart-tooltip", tooltipBorder: "--psu-chart-tooltip-border", accent: "--psu-chart-accent" };

export function readCssTokens(read) {
    const out = {};
    for (const [key, name] of Object.entries(TOKENS)) {
        const v = read(name);
        if (v) out[key] = v;
    }
    // --psu-chart-N replaces the N-th series colour only; positions without a property keep theirs
    const palette = [];
    for (let i = 1; i <= 12; i++) {
        const v = read(`--psu-chart-${i}`);
        if (v) palette[i - 1] = v;
    }
    if (palette.length) out.palette = palette;
    // --psu-chart-font-size: the base text size of every chart (see fonts.js)
    const fontSize = parseFontSize(read("--psu-chart-font-size"), parseFloat(read("font-size")) || 16);
    if (fontSize) out.fontSize = fontSize;
    return out;
}

// the base text size the page's stylesheet asks for, or undefined (ECharts' 12 px)
export function pageFontSize(tokens = tokensOfPage()) {
    return tokens.fontSize;
}

function tokensOfPage() {
    if (typeof document === "undefined") return {};
    const style = getComputedStyle(document.documentElement);
    return readCssTokens((name) => style.getPropertyValue(name).trim());
}

// objects merge key by key, everything else (arrays such as a palette) replaces
function deepMerge(base, over) {
    if (!over || typeof over !== "object" || Array.isArray(over)) return over === undefined ? base : over;
    const out = { ...(base && typeof base === "object" && !Array.isArray(base) ? base : {}) };
    for (const [k, v] of Object.entries(over)) {
        if (k === "__proto__" || k === "constructor" || k === "prototype") continue;
        out[k] = v && typeof v === "object" && !Array.isArray(v) ? deepMerge(out[k], v) : v;
    }
    return out;
}

function hash(text) {
    let h = 5381;
    for (let i = 0; i < text.length; i++) h = ((h * 33) ^ text.charCodeAt(i)) >>> 0;
    return h.toString(36);
}

function themeFor(c, psu) {
    // a text colour from the corporate stylesheet wins over the one PSU computed for the page
    const text = c.textToken || (psu && psu.text) || c.text;
    // splitArea: ECharts' default greys glare on a dark page (heatmap cells without a value)
    const axis = { axisLine: { lineStyle: { color: c.axis } }, axisTick: { lineStyle: { color: c.axis } }, axisLabel: { color: c.muted }, splitLine: { lineStyle: { color: c.split } }, splitArea: { areaStyle: { color: ["transparent", c.split] } }, nameTextStyle: { color: c.muted } };
    return {
        color: c.palette,
        backgroundColor: "transparent",
        textStyle: { color: text, fontFamily: psu && psu.fontFamily ? psu.fontFamily : undefined, fontSize: c.fontSize },
        title: { textStyle: { color: text }, subtextStyle: { color: c.muted } },
        legend: { textStyle: { color: text }, pageTextStyle: { color: c.muted } },
        tooltip: { backgroundColor: c.tooltip, borderColor: c.tooltipBorder, textStyle: { color: text } },
        categoryAxis: axis,
        valueAxis: axis,
        timeAxis: axis,
        logAxis: axis,
        // parallel axes and the theme river's single axis are themed separately from the grid axes
        parallelAxis: { ...axis, nameTextStyle: { color: text }, areaSelectStyle: { color: c.accent, borderColor: c.accent, opacity: 0.25 } },
        singleAxis: axis,
        // the button name shown on hover: page text on a contrasting chip, icon in the accent colour
        toolbox: {
            iconStyle: { borderColor: c.muted },
            emphasis: { iconStyle: { borderColor: c.accent, textFill: text, textBackgroundColor: c.tooltip, textPadding: [3, 6], textBorderRadius: 3, textPosition: "bottom" } }
        },
        dataZoom: { textStyle: { color: c.muted }, borderColor: c.axis },
        visualMap: { textStyle: { color: text } },
        calendar: { dayLabel: { color: c.muted }, monthLabel: { color: c.muted }, yearLabel: { color: c.muted }, itemStyle: { color: "transparent", borderColor: c.split }, splitLine: { lineStyle: { color: c.axis } } },
        markLine: { label: { color: text } },
        // labels outside a shape take the page's text colour, without the light outline ECharts draws
        pie: { label: { color: text, textBorderWidth: 0 } },
        funnel: { label: { textBorderWidth: 0 } },
        bar: { label: { color: text, textBorderWidth: 0 } },
        line: { label: { color: text, textBorderWidth: 0 }, endLabel: { color: text, textBorderWidth: 0 } },
        scatter: { label: { color: text, textBorderWidth: 0 } },
        sankey: { label: { color: text, textBorderWidth: 0 } },
        graph: { label: { color: text, textBorderWidth: 0 }, edgeLabel: { color: c.muted, textBorderWidth: 0 }, lineStyle: { color: c.muted } },
        tree: { label: { color: text, textBorderWidth: 0 }, lineStyle: { color: c.axis }, itemStyle: { borderColor: c.accent } },
        chord: { label: { color: text, textBorderWidth: 0 } },
        matrix: { x: { label: { color: text }, itemStyle: { borderColor: c.axis } }, y: { label: { color: text }, itemStyle: { borderColor: c.axis } }, body: { itemStyle: { borderColor: c.split } }, backgroundStyle: { borderColor: c.axis } },
        sunburst: { label: { textBorderWidth: 0 } },
        gauge: { axisLabel: { color: c.muted }, detail: { color: text }, title: { color: c.muted }, splitLine: { lineStyle: { color: c.muted } }, axisTick: { lineStyle: { color: c.muted } } },
        // ECharts fills boxplot boxes white, which glares on a dark page
        boxplot: { itemStyle: { color: c.tooltip, borderWidth: 1.5 } },
        heatmap: { label: { color: text, textBorderWidth: 0 } },
        // ECharts' radar fills its rings with light greys that glare on a dark page
        radar: { axisName: { color: c.muted }, axisLine: { lineStyle: { color: c.axis } }, splitLine: { lineStyle: { color: c.axis } }, splitArea: { areaStyle: { color: ["transparent", c.split] } } },
        // gaps and header bars between treemap tiles in the page colour, not white
        treemap: { label: { textBorderWidth: 0 }, upperLabel: { color: text, textBorderWidth: 0 }, itemStyle: { borderColor: c.tooltip }, breadcrumb: { itemStyle: { color: c.split, textStyle: { color: text } } } }
    };
}

/*
 * Registers the theme for a mode and returns its name: psu-light / psu-dark, or a name per
 * corporate variant (tokens and custom theme hashed), re-registered when PSU's colours change.
 * `tokens` defaults to the page's CSS custom properties; tests pass their own.
 */
export function themeObject(mode, psuTheme, custom, tokens = tokensOfPage()) {
    const base = mode === "dark" ? DARK : LIGHT;
    const palette = tokens.palette
        ? Array.from({ length: Math.max(base.palette.length, tokens.palette.length) }, (_, i) => tokens.palette[i] || base.palette[i % base.palette.length])
        : base.palette;
    const c = { ...base, ...tokens, palette, textToken: tokens.text };
    const theme = themeFor(c, psuTheme);
    return custom && typeof custom === "object" ? deepMerge(theme, custom) : theme;
}

export function ensureTheme(echarts, mode, psuTheme, custom, tokens = tokensOfPage()) {
    const variant = (custom && typeof custom === "object") || Object.keys(tokens).length ? `-${hash(JSON.stringify([tokens, custom || null]))}` : "";
    const name = `psu-${mode === "dark" ? "dark" : "light"}${variant}`;
    echarts.registerTheme(name, themeObject(mode, psuTheme, custom, tokens));
    return name;
}
