// Loading a file into the pivot report in the browser (New-UDPivotReport -AllowImport), shared by the
// PSU specs of the pivot module (psu-pivot.spec.mjs) and of its demo (psu-pivot-demo.spec.mjs).
// Files are real: CSV text and Excel workbooks built here with fflate, as Excel writes them (shared
// strings, a date format on date cells). A drop is a real DataTransfer holding a File, dispatched as
// dragenter, dragover and drop; a pick goes through the browser's file chooser.
import { expect } from "@playwright/test";
import { strToU8, zipSync } from "fflate";

export const CSV = "text/csv";
export const XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

// German Excel's CSV: semicolons, decimal commas, day-first dates, a postcode with a leading zero
// (stays text), an empty line (left out)
export const TICKETS_CSV = "Id;Team;Opened;Hours;Zip\n1001;Network;10.11.2026;1,5;01067\n1002;Server;11.11.2026;2,25;10115\n1003;Network;12.11.2026;4;01067\n\n1004;Client;13.11.2026;0,5;20095\n";

const XML = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n';
const NS = 'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"';
const REL = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
const esc = (t) => String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
const letter = (c) => String.fromCharCode(65 + c);

/**
 * A workbook: sheets of rows; a cell is a number, a string or { date: Date } (a serial with Excel's
 * date format 14, as Excel saves a date).
 * @param {Array<{ name: string, rows: Array<Array<number | string | { date: Date }>> }>} sheets
 * @returns {Uint8Array}
 */
export function makeXlsx(sheets) {
    const strings = [];
    const shared = (t) => (strings.includes(t) ? strings.indexOf(t) : strings.push(t) - 1);
    const files = {};
    sheets.forEach((sheet, k) => {
        const rows = sheet.rows
            .map((cells, r) => `<row r="${r + 1}">${cells.map((v, c) => {
                const ref = `${letter(c)}${r + 1}`;
                if (typeof v === "number") return `<c r="${ref}"><v>${v}</v></c>`;
                if (typeof v === "string") return `<c r="${ref}" t="s"><v>${shared(v)}</v></c>`;
                return `<c r="${ref}" s="1"><v>${v.date.getTime() / 86_400_000 + 25_569}</v></c>`;
            }).join("")}</row>`)
            .join("");
        files[`xl/worksheets/sheet${k + 1}.xml`] = strToU8(`${XML}<worksheet ${NS}><sheetData>${rows}</sheetData></worksheet>`);
    });
    const list = sheets.map((s, k) => `<sheet name="${esc(s.name)}" sheetId="${k + 1}" r:id="rId${k + 1}"/>`).join("");
    const rels = sheets.map((_, k) => `<Relationship Id="rId${k + 1}" Type="${REL}/worksheet" Target="worksheets/sheet${k + 1}.xml"/>`).join("");
    const n = sheets.length;
    files["xl/workbook.xml"] = strToU8(`${XML}<workbook ${NS}><sheets>${list}</sheets></workbook>`);
    files["xl/_rels/workbook.xml.rels"] = strToU8(`${XML}<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">${rels}<Relationship Id="rId${n + 1}" Type="${REL}/styles" Target="styles.xml"/><Relationship Id="rId${n + 2}" Type="${REL}/sharedStrings" Target="sharedStrings.xml"/></Relationships>`);
    files["xl/styles.xml"] = strToU8(`${XML}<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts><fills count="1"><fill><patternFill patternType="none"/></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="14" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs></styleSheet>`);
    files["xl/sharedStrings.xml"] = strToU8(`${XML}<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${strings.length}" uniqueCount="${strings.length}">${strings.map((t) => `<si><t xml:space="preserve">${esc(t)}</t></si>`).join("")}</sst>`);
    const overrides = sheets.map((_, k) => `<Override PartName="/xl/worksheets/sheet${k + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`).join("");
    files["[Content_Types].xml"] = strToU8(`${XML}<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>${overrides}</Types>`);
    files["_rels/.rels"] = strToU8(`${XML}<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="${REL}/officeDocument" Target="xl/workbook.xml"/></Relationships>`);
    return zipSync(files, { level: 6 });
}

/** An asset list as a workbook: the sheet Assets (Asset, Kind, Bought as dates, Price) and a second one. */
export function assetsXlsx() {
    const kinds = ["Laptop", "Phone", "Screen"];
    const rows = [["Asset", "Kind", "Bought", "Price"]];
    for (let i = 0; i < 30; i++) rows.push([`A${100 + i}`, kinds[i % 3], { date: new Date(Date.UTC(2025, i % 12, 1 + (i % 28))) }, 100 + i * 10]);
    return makeXlsx([{ name: "Assets", rows }, { name: "Legend", rows: [["Kind", "Meaning"], ["Laptop", "Notebook computer"]] }]);
}

/** A file for the page: its name, type and content (text, or bytes). */
export const fileOf = (name, type, content) => ({ name, type, ...(typeof content === "string" ? { text: content } : { base64: Buffer.from(content).toString("base64") }) });

/**
 * Drags files over the target and drops them, as a browser does with files from the desktop:
 * dragenter, dragover (pivotkit's overlay shows), then drop, all with one DataTransfer.
 */
export async function dropFiles(page, target, files) {
    const dt = await page.evaluateHandle((list) => {
        const t = new DataTransfer();
        for (const f of list) {
            const content = f.text ?? Uint8Array.from(atob(f.base64), (c) => c.charCodeAt(0));
            t.items.add(new File([content], f.name, { type: f.type }));
        }
        return t;
    }, files);
    const box = await target.boundingBox();
    const at = { clientX: box.x + box.width / 2, clientY: box.y + box.height / 2 };
    await target.dispatchEvent("dragenter", { dataTransfer: dt, ...at });
    await target.dispatchEvent("dragover", { dataTransfer: dt, ...at });
    await expect(page.getByTestId("drop-overlay")).toBeVisible();
    await target.dispatchEvent("drop", { dataTransfer: dt, ...at });
    await expect(page.getByTestId("drop-overlay")).toHaveCount(0);
}

/** Opens the Data menu: its own button, or its entry under "More" on a narrow report. */
export async function openDataMenu(report) {
    const page = report.page();
    const own = report.getByTestId("data");
    // a click within a moment of a field's drop can be taken by dnd-kit still settling it: again
    await expect(async () => {
        if (await own.isVisible()) await own.click();
        else {
            await report.getByTestId("more").click();
            await page.getByTestId("more-data").click();
        }
        await expect(page.getByTestId("data-menu")).toBeVisible({ timeout: 2000 });
    }).toPass({ timeout: 10000 });
}

/** Picks a file through Data, Load data… and the browser's file chooser. */
export async function pickFile(report, file) {
    const page = report.page();
    await openDataMenu(report);
    const chooser = page.waitForEvent("filechooser");
    await page.getByTestId("load-file").click();
    await (await chooser).setFiles({ name: file.name, mimeType: file.type, buffer: file.base64 ? Buffer.from(file.base64, "base64") : Buffer.from(file.text) });
}

/** The preview table of the import dialog: column names, types and body rows as texts. */
export async function preview(dialog) {
    await expect(dialog.getByTestId("import-preview")).toBeVisible();
    return dialog.getByTestId("import-preview").evaluate((box) => ({
        columns: [...box.querySelectorAll("thead th")].map((th) => th.firstChild.textContent),
        types: [...box.querySelectorAll("thead select")].map((s) => s.value),
        rows: [...box.querySelectorAll("tbody tr")].map((tr) => [...tr.children].map((td) => td.textContent))
    }));
}

/** The field names of the report's field list. */
export const fieldNames = (report) => report.locator(".pk-field-list [data-field]").evaluateAll((els) => els.map((e) => e.getAttribute("data-field")));
