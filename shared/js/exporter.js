import { zipSync, strToU8 } from "fflate";
import { columnsOf, resolveColumn } from "./columns.js";
import { formatter } from "./formatters.js";

/*
 * Export of the data behind a component as CSV or Excel (.xlsx), built in the browser.
 *
 * Columns come from an export definition (PowerShell -ExportColumns) or, without one, from the data:
 *   [{ field: "leadTime", title: "Lead time (h)", type: "number", format: "number:1" }, ...]
 * type: text | number | integer | currency | percent | date | datetime | boolean
 * Excel gets real typed cells (numbers stay numbers, dates are dates with a date format), so sorting,
 * filtering and formulas work. CSV uses the locale's separator (";" where "," is the decimal comma),
 * quotes every text field and doubles quotes inside it, and starts with a BOM for Excel.
 */

export function exportColumns(rows, definition) {
    const keys = columnsOf(rows);
    if (!Array.isArray(definition) || definition.length === 0) {
        return keys.map((k) => ({ key: k, title: k, type: guessType(rows, k) }));
    }
    return definition
        .map((d) => (typeof d === "string" ? { field: d } : d))
        .map((d) => {
            const key = resolveColumn(d.field, keys);
            return key === undefined ? null : { key, title: d.title || d.field, type: (d.type || guessType(rows, key)).toLowerCase(), format: d.format };
        })
        .filter(Boolean);
}

function guessType(rows, key) {
    for (const row of rows) {
        const v = row ? row[key] : undefined;
        if (v === null || v === undefined || v === "") {
            continue;
        }
        if (typeof v === "number") {
            return "number";
        }
        if (typeof v === "boolean") {
            return "boolean";
        }
        if (typeof v === "string" && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/.test(v)) {
            return "datetime";
        }
        if (typeof v === "string" && /^\d{4}-\d{2}-\d{2}$/.test(v)) {
            return "date";
        }
        return "text";
    }
    return "text";
}

// The decimal separator of the locale decides the CSV separator, as Excel does.
export function csvSeparator(locale) {
    const decimal = new Intl.NumberFormat(locale).formatToParts(1.5).find((p) => p.type === "decimal");
    return decimal && decimal.value === "," ? ";" : ",";
}

function csvValue(value, column, locale, separator) {
    if (value === null || value === undefined) {
        return "";
    }
    if (column.type === "number" || column.type === "integer" || column.type === "currency" || column.type === "percent") {
        const n = typeof value === "number" ? value : Number(value);
        if (!isNaN(n)) {
            // plain digits with the locale's decimal mark, no grouping: Excel reads it as a number
            return new Intl.NumberFormat(locale, { useGrouping: false, maximumFractionDigits: 10 }).format(n);
        }
    }
    const text = column.format ? formatter(column.format, locale)(value) : String(value);
    // a leading = + - @ would make Excel evaluate the cell as a formula (CSV injection): prefix a quote
    const safe = /^[=+\-@\t]/.test(text) ? `'${text}` : text;
    const needsQuotes = /["\r\n]/.test(safe) || safe.includes(separator);
    return needsQuotes ? `"${safe.replace(/"/g, '""')}"` : safe;
}

export function toCsv(rows, definition, locale) {
    const columns = exportColumns(rows, definition);
    const sep = csvSeparator(locale);
    const head = columns.map((c) => csvValue(c.title, { type: "text" }, locale, sep)).join(sep);
    const body = rows.map((row) => columns.map((c) => csvValue(row ? row[c.key] : null, c, locale, sep)).join(sep));
    return "﻿" + [head, ...body].join("\r\n") + "\r\n";
}

// ---- XLSX (Office Open XML, the smallest workbook Excel, LibreOffice and Numbers open) ----

function xmlEscape(text) {
    return String(text)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        // characters XML 1.0 does not allow
        .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, "");
}

function cellRef(col, row) {
    let s = "";
    let n = col + 1;
    while (n > 0) {
        const m = (n - 1) % 26;
        s = String.fromCharCode(65 + m) + s;
        n = Math.floor((n - 1) / 26);
    }
    return `${s}${row + 1}`;
}

// Excel serial date: days since 1899-12-30, local wall-clock time kept as written
function excelDate(value) {
    const d = value instanceof Date ? value : new Date(value);
    if (isNaN(d.getTime())) {
        return null;
    }
    const wall = Date.UTC(d.getFullYear(), d.getMonth(), d.getDate(), d.getHours(), d.getMinutes(), d.getSeconds(), d.getMilliseconds());
    return wall / 86400000 + 25569;
}

// Fixed style ids in styles.xml below; currencies get their own ids from CURRENCY_BASE on.
const STYLE = { text: 0, header: 1, number: 2, integer: 3, percent: 4, date: 5, datetime: 6 };
const CURRENCY_BASE = 7;

function currencyOf(column) {
    const m = /^currency:([A-Za-z]{3})$/.exec(column.format || "");
    return (m ? m[1] : "EUR").toUpperCase();
}

function stylesXml(currencies) {
    const fmts = [`<numFmt numFmtId="164" formatCode="yyyy-mm-dd"/>`, `<numFmt numFmtId="165" formatCode="yyyy-mm-dd hh:mm"/>`]
        .concat(currencies.map((code, i) => `<numFmt numFmtId="${166 + i}" formatCode="#,##0.00 &quot;${code}&quot;"/>`));
    const xfs = [
        `<xf/>`, `<xf fontId="1" applyFont="1"/>`, `<xf numFmtId="4" applyNumberFormat="1"/>`, `<xf numFmtId="3" applyNumberFormat="1"/>`,
        `<xf numFmtId="10" applyNumberFormat="1"/>`, `<xf numFmtId="164" applyNumberFormat="1"/>`, `<xf numFmtId="165" applyNumberFormat="1"/>`
    ].concat(currencies.map((_, i) => `<xf numFmtId="${166 + i}" applyNumberFormat="1"/>`));
    return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="${fmts.length}">${fmts.join("")}</numFmts><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf/></cellStyleXfs><cellXfs count="${xfs.length}">${xfs.join("")}</cellXfs></styleSheet>`;
}

function cellXml(ref, value, type, style) {
    if (value === null || value === undefined || value === "") {
        return "";
    }
    if (type === "boolean") {
        return `<c r="${ref}" t="b"><v>${value ? 1 : 0}</v></c>`;
    }
    if (type === "date" || type === "datetime") {
        const serial = excelDate(value);
        if (serial !== null) {
            return `<c r="${ref}" s="${style}"><v>${serial}</v></c>`;
        }
    }
    if (["number", "integer", "currency", "percent"].includes(type)) {
        const n = typeof value === "number" ? value : Number(value);
        if (!isNaN(n)) {
            return `<c r="${ref}" s="${style}"><v>${n}</v></c>`;
        }
    }
    return `<c r="${ref}" t="inlineStr"><is><t xml:space="preserve">${xmlEscape(value)}</t></is></c>`;
}

export function toXlsxBytes(rows, definition, sheetName = "Data") {
    const columns = exportColumns(rows, definition);
    const currencies = [...new Set(columns.filter((c) => c.type === "currency").map(currencyOf))];
    columns.forEach((c) => {
        c.style = c.type === "currency" ? CURRENCY_BASE + currencies.indexOf(currencyOf(c)) : STYLE[c.type] ?? STYLE.text;
    });
    const header = `<row r="1">${columns.map((c, i) => `<c r="${cellRef(i, 0)}" t="inlineStr" s="${STYLE.header}"><is><t>${xmlEscape(c.title)}</t></is></c>`).join("")}</row>`;
    const body = rows
        .map((row, r) => `<row r="${r + 2}">${columns.map((c, i) => cellXml(cellRef(i, r + 1), row ? row[c.key] : null, c.type, c.style)).join("")}</row>`)
        .join("");
    const widths = columns
        .map((c, i) => {
            const longest = Math.max(String(c.title).length, ...rows.slice(0, 200).map((row) => String(row && row[c.key] !== null && row[c.key] !== undefined ? row[c.key] : "").length));
            return `<col min="${i + 1}" max="${i + 1}" width="${Math.min(60, Math.max(8, longest + 2))}" customWidth="1"/>`;
        })
        .join("");
    const lastRef = cellRef(Math.max(columns.length - 1, 0), rows.length);
    const sheet = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><cols>${widths}</cols><sheetData>${header}${body}</sheetData><autoFilter ref="A1:${lastRef}"/></worksheet>`;
    const safeName = xmlEscape(String(sheetName).replace(/[\\/?*[\]:]/g, " ").slice(0, 31) || "Data");
    const files = {
        "[Content_Types].xml": `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>`,
        "_rels/.rels": `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>`,
        "xl/workbook.xml": `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="${safeName}" sheetId="1" r:id="rId1"/></sheets><definedNames><definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">'${safeName.replace(/'/g, "''")}'!$A$1:$${lastRef.replace(/\d+$/, "")}$${rows.length + 1}</definedName></definedNames></workbook>`,
        "xl/_rels/workbook.xml.rels": `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>`,
        "xl/styles.xml": stylesXml(currencies),
        "xl/worksheets/sheet1.xml": sheet
    };
    const zipped = {};
    for (const [name, text] of Object.entries(files)) {
        zipped[name] = strToU8(text);
    }
    return zipSync(zipped, { level: 6 });
}

// Offers a file to the browser for download.
export function download(fileName, data, mime) {
    const blob = data instanceof Blob ? data : new Blob([data], { type: mime });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = fileName;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export function safeFileName(name, fallback = "export") {
    const clean = String(name || fallback).replace(/[\\/:*?"<>|\u0000-\u001F]+/g, "_").trim();
    return clean || fallback;
}
