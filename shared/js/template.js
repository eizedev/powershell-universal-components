/*
 * Label and tooltip texts from the row behind a point: "{Name} ({Cpu} vCPU, {RamGB:bytes})".
 * A placeholder is a column (matched case-insensitively, like everywhere else) and an optional
 * format from formatters.js. Nothing is evaluated: the template is split once, then only filled in.
 */
import { resolveColumn } from "./columns.js";
import { formatter } from "./formatters.js";
import { escapeHtml } from "./html.js";

const PLACEHOLDER = /\{([^{}:]+)(?::([^{}]+))?\}/g;

function show(value) {
    if (Array.isArray(value)) {
        return value.join(", ");
    }
    return value === null || value === undefined ? "" : String(value);
}

// returns (row, escape) => text; escape = true for HTML (tooltips)
export function compileTemplate(template, keys, locale) {
    const parts = [];
    let last = 0;
    for (const m of String(template ?? "").matchAll(PLACEHOLDER)) {
        parts.push({ text: template.slice(last, m.index) });
        const key = resolveColumn(m[1].trim(), keys);
        const fmt = m[2] ? formatter(m[2].trim(), locale) : null;
        parts.push({ key, fmt, raw: m[0] });
        last = m.index + m[0].length;
    }
    parts.push({ text: String(template ?? "").slice(last) });
    return (row, escape = false) => parts.map((p) => {
        let out;
        if (p.text !== undefined) {
            out = p.text;
        } else if (p.key === undefined) {
            // unknown column: keep the placeholder visible, so the mistake shows
            out = p.raw;
        } else {
            const v = row ? row[p.key] : undefined;
            out = p.fmt && v !== null && v !== undefined && !Array.isArray(v) ? p.fmt(v) : show(v);
        }
        return escape ? escapeHtml(out).replace(/\n/g, "<br/>") : out;
    }).join("");
}

// "Cpu", "RamGB:bytes", "Memory (GB)=RamGB:integer" -> a tooltip template with one
// "Label: value" line per entry; the label defaults to the column name
export function columnsTemplate(columns) {
    return (Array.isArray(columns) ? columns : [columns])
        .filter((c) => c !== null && c !== undefined && String(c).trim() !== "")
        .map((c) => {
            const text = String(c);
            const eq = text.indexOf("=");
            const label = eq >= 0 ? text.slice(0, eq).trim() : undefined;
            const [name, ...fmt] = (eq >= 0 ? text.slice(eq + 1) : text).split(":");
            // braces in a label would be read as placeholders
            const shown = (label ?? name.trim()).replace(/[{}]/g, "");
            return `${shown}: {${name.trim()}${fmt.length ? ":" + fmt.join(":").trim() : ""}}`;
        })
        .join("\n");
}
