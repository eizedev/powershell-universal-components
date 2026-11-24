/*
 * Text colour on a coloured fill (labels inside funnel stages, pie slices, treemap tiles): the darker
 * or the lighter of two text colours, whichever has the higher WCAG contrast ratio with the fill, so
 * a label stays readable on every palette colour. Pure functions, no DOM.
 */

export const DARK_TEXT = "#1f2430";
export const LIGHT_TEXT = "#ffffff";

// [r, g, b] 0..255 from #rgb, #rrggbb (#rrggbbaa: alpha ignored) or rgb()/rgba(); undefined otherwise
export function parseColor(value) {
    const s = String(value ?? "").trim().toLowerCase();
    let m = /^#([0-9a-f]{3})$/.exec(s);
    if (m) return [...m[1]].map((c) => parseInt(c + c, 16));
    m = /^#([0-9a-f]{6})([0-9a-f]{2})?$/.exec(s);
    if (m) return [0, 2, 4].map((i) => parseInt(m[1].slice(i, i + 2), 16));
    m = /^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)/.exec(s);
    if (m) return [m[1], m[2], m[3]].map((v) => Math.max(0, Math.min(255, Math.round(Number(v)))));
    return undefined;
}

// WCAG 2 relative luminance, 0 (black) .. 1 (white)
export function luminance(rgb) {
    const [r, g, b] = rgb.map((v) => {
        const c = v / 255;
        return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
    });
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

export function contrastRatio(a, b) {
    const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
    return (hi + 0.05) / (lo + 0.05);
}

// the text colour for a label on `fill`; undefined when the fill is not a colour this can read
// (a gradient object, a CSS name), so the caller leaves the label as it is
export function textOn(fill, dark = DARK_TEXT, light = LIGHT_TEXT) {
    const rgb = parseColor(fill);
    if (!rgb) return undefined;
    return contrastRatio(rgb, parseColor(dark)) >= contrastRatio(rgb, parseColor(light)) ? dark : light;
}

// `amount` (0..1) of the way to white, as ECharts lightens the deeper rings of a sunburst (zrender's
// lift(): rounded down)
export function lighten(color, amount) {
    const rgb = parseColor(color);
    if (!rgb) return color;
    const hex = rgb.map((c) => Math.floor(c + (255 - c) * amount).toString(16).padStart(2, "0")).join("");
    return `#${hex}`;
}
