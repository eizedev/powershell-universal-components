// The colours of pivotkit's colour scales, shared by the pivot specs (the documentation site and the
// showcase app on PSU): what a cell of a colour scale is painted with, a CSS colour as the browser
// resolves it, and the colour scales of a downloaded workbook.
import { strFromU8, unzipSync } from "fflate";

/**
 * The cells of a colour scale in a table region, by their number: how many, the colour of the lowest
 * and the highest (pivotkit paints a cell with its colour in --pk-cell-bg, mixed into the surface) and
 * whether every one is painted.
 */
export function colorScaleCells(table) {
    return table.evaluate((region) => {
        const cells = [...region.querySelectorAll("td.pk-has-scale")];
        const number = (td) => Number(td.textContent.replace(/[^\d]/g, ""));
        cells.sort((a, b) => number(a) - number(b));
        const colour = (td) => td && getComputedStyle(td).getPropertyValue("--pk-cell-bg").trim();
        return { count: cells.length, low: colour(cells[0]), high: colour(cells.at(-1)), painted: cells.every((td) => getComputedStyle(td).backgroundColor !== getComputedStyle(region).backgroundColor) };
    });
}

/** The colours of the colour scales in a downloaded workbook, as RRGGBB. */
export async function workbookScaleColors(download) {
    const chunks = [];
    for await (const chunk of await download.createReadStream()) chunks.push(chunk);
    const files = unzipSync(new Uint8Array(Buffer.concat(chunks)));
    const sheets = Object.keys(files).filter((name) => /^xl\/worksheets\/sheet\d+\.xml$/.test(name)).map((name) => strFromU8(files[name])).join("");
    return [...sheets.matchAll(/<colorScale>([\s\S]*?)<\/colorScale>/g)].flatMap((m) => [...m[1].matchAll(/rgb="(?:FF)?([0-9A-Fa-f]{6})"/g)].map((c) => c[1].toUpperCase()));
}

// a CSS colour as the browser resolves it, as "r,g,b" (a mix comes back as color(srgb ...), a token as
// rgb(...)), for comparing a token with a cell
export async function resolvedColor(report, value) {
    const text = await report.evaluate((root, v) => {
        const probe = root.ownerDocument.createElement("span");
        probe.style.color = v;
        root.appendChild(probe);
        const out = getComputedStyle(probe).color;
        probe.remove();
        return out;
    }, value);
    const srgb = /^color\(srgb ([\d.e-]+) ([\d.e-]+) ([\d.e-]+)/.exec(text);
    const parts = srgb ? srgb.slice(1).map((c) => Math.round(Number(c) * 255)) : (/^rgba?\((\d+), (\d+), (\d+)/.exec(text) || []).slice(1).map(Number);
    return parts.length === 3 ? parts.join(",") : text;
}
