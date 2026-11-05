/*
 * HTML for ECharts tooltips. ECharts escapes its own tooltips but puts a formatter's return value in
 * as HTML, so every value taken from the data (names, columns of a REST result) must be escaped.
 * html`...` escapes every interpolation; markup lives only in the literal parts. A nested html`...`
 * (or an array of them) is inserted as is.
 */
class SafeHtml {
    constructor(text) {
        this.text = text;
    }

    toString() {
        return this.text;
    }
}

export function escapeHtml(value) {
    return String(value ?? "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}

function part(value) {
    if (value instanceof SafeHtml) {
        return value.text;
    }
    if (Array.isArray(value)) {
        return value.map(part).join("");
    }
    return escapeHtml(value);
}

export function html(strings, ...values) {
    let out = strings[0];
    values.forEach((v, i) => {
        out += part(v) + strings[i + 1];
    });
    return new SafeHtml(out);
}

// joins html`` pieces with trusted markup (e.g. "<br/>")
export function joinHtml(items, separator) {
    return new SafeHtml(items.map(part).join(separator));
}

// ECharts' own marker (a coloured dot) is markup it generated itself
export function trusted(markup) {
    return new SafeHtml(String(markup ?? ""));
}
