/*
 * -ColorMap: a fixed colour per category name (Failed red, Success green), the same for every chart
 * type. New-UDEChart sends it as a list of { name, light, dark }; a name is a series name (a -Y column,
 * a -GroupBy value, a gantt group) or the name of a data item (pie and funnel slices, treemap and
 * sunburst nodes, sankey and graph nodes, graph categories). Names match without regard to case.
 * Everything not in the map keeps the palette.
 */

// colour strings only: hex, rgb()/rgba()/hsl()/hsla() and CSS colour names - never anything else
const COLOR = /^(#[0-9a-f]{3,8}|(rgb|rgba|hsl|hsla)\([0-9.,%\s/]+\)|[a-z]+)$/i;

export function isColor(value) {
    return typeof value === "string" && COLOR.test(value.trim());
}

// name (lower case) -> colour of the given mode; invalid entries are left out
export function colorMapOf(list, mode) {
    const out = new Map();
    if (!Array.isArray(list)) return out;
    for (const entry of list) {
        if (!entry || typeof entry !== "object" || entry.name === undefined || entry.name === null) continue;
        const color = mode === "dark" ? entry.dark ?? entry.light : entry.light ?? entry.dark;
        if (isColor(color)) out.set(String(entry.name).toLowerCase(), color.trim());
    }
    return out;
}

function colorFor(map, name) {
    return name === undefined || name === null ? undefined : map.get(String(name).toLowerCase());
}

// a data item (object or bare value) with its own fill; a colour the option already sets stays
function withItemColor(item, color) {
    if (!color || !item || typeof item !== "object" || Array.isArray(item)) return item;
    if (item.itemStyle && item.itemStyle.color) return item;
    return { ...item, itemStyle: { ...(item.itemStyle || {}), color } };
}

// data items and their children (treemap, sunburst, tree), by name
function mapItems(items, map) {
    if (!Array.isArray(items)) return items;
    return items.map((item) => {
        if (!item || typeof item !== "object" || Array.isArray(item)) return item;
        const own = withItemColor(item, colorFor(map, item.name));
        return Array.isArray(own.children) ? { ...own, children: mapItems(own.children, map) } : own;
    });
}

/*
 * The option with the mapped colours: series by name (bars, lines, areas, gantt groups - the legend
 * follows), data items, graph nodes and categories by name. Series that set their own colour keep it.
 */
export function applyColorMap(option, list, mode) {
    const map = colorMapOf(list, mode);
    if (!option || map.size === 0) return option;
    const one = (s) => {
        if (!s || typeof s !== "object") return s;
        let out = s;
        const color = colorFor(map, s.name);
        if (color && !s.color && !(s.itemStyle && s.itemStyle.color)) {
            out = { ...out, color, itemStyle: { ...(s.itemStyle || {}), color } };
            if (s.type === "line" || s.lineStyle) out.lineStyle = { ...(s.lineStyle || {}), color };
        }
        for (const key of ["data", "nodes", "categories"]) {
            if (Array.isArray(out[key])) out = { ...out, [key]: mapItems(out[key], map) };
        }
        return out;
    };
    return { ...option, series: Array.isArray(option.series) ? option.series.map(one) : one(option.series) };
}

