// Screenshots for the documentation, in the light and the dark theme. The files land in docs/assets/
// and are committed; look at them before committing.
//
// The live examples of the start page: each one is the example's element on the built site, drawn by
// the module's own component. Build and serve the site first (docs/development/), then:
//
//   node docs/site/screenshots.mjs [http://127.0.0.1:8765]
//
// The Pivot showcase app's pages for docs/pivot/demo.md (pivot-showcase-*): set PSU_PIVOT_DEMO_URL to
// the app on a PSU instance (New-UDPivotShowcase), as for tests/browser/psu-pivot-demo.spec.mjs. Only
// those are taken then:
//
//   PSU_PIVOT_DEMO_URL=https://psu.example.com/pivot-showcase node docs/site/screenshots.mjs
import { chromium, expect } from "@playwright/test";
import { fileURLToPath } from "node:url";
import { CSV, fileOf, pickFile } from "../../tests/browser/pivot-import.mjs";

const out = fileURLToPath(new URL("../assets/", import.meta.url));
const demo = (process.env.PSU_PIVOT_DEMO_URL || "").replace(/\/$/, "");

// ---- the site's live examples ----------------------------------------------------------------------
const base = process.argv[2] || "http://127.0.0.1:8765";
// page, example id and file name (without -light/-dark)
const SHOTS = [["/pivot/", "a-report-app-with-loading-views-per-reader-and-roles", "pivot-report"]];

async function siteShots(browser) {
    for (const scheme of ["light", "dark"]) {
        const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, colorScheme: scheme, deviceScaleFactor: 2 });
        for (const [path, id, name] of SHOTS) {
            await page.goto(base + path);
            const example = page.locator(`[data-example="${id}"]`);
            // the report has drawn its table
            await example.locator(".pk-result td").first().waitFor();
            await example.scrollIntoViewIfNeeded();
            // let fonts and the table's layout settle
            await page.waitForTimeout(500);
            await example.screenshot({ path: `${out}${name}-${scheme}.png`, animations: "disabled" });
            console.log(`${name}-${scheme}.png`);
        }
        await page.close();
    }
}

// ---- the Pivot showcase app on PSU -----------------------------------------------------------------
// costs per team and month: the file a reader loads on the page "Your data" (90 rows)
const TEAMS = ["Client", "Network", "Security", "Server", "Service Desk"];
function costsCsv() {
    const lines = ["Team,Monat,Kosten"];
    let seed = 7;
    const next = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
    for (let month = 1; month <= 6; month++) {
        for (const team of TEAMS) {
            for (let i = 0; i < 3; i++) lines.push(`${team},2026-0${month},${(400 + next() * 1200).toFixed(2)}`);
        }
    }
    return lines.join("\n") + "\n";
}

// a field dragged from the field list onto a zone with the mouse, as a reader does (dnd-kit starts a
// drag after a few pixels of movement)
async function dragField(report, field, zone) {
    const page = report.page();
    const from = await report.getByRole("button", { name: `Drag ${field}`, exact: true }).boundingBox();
    const to = await report.getByRole("region", { name: zone }).boundingBox();
    await page.mouse.move(from.x + from.width / 2, from.y + from.height / 2);
    await page.mouse.down();
    await page.mouse.move(from.x + 30, from.y + 10, { steps: 5 });
    await page.mouse.move(to.x + to.width - 40, to.y + to.height / 2, { steps: 15 });
    await page.mouse.up();
}

// PSU's own light/dark switch in the app bar, as a reader uses it
async function setTheme(page, mode) {
    await expect(async () => {
        if ((await page.evaluate(() => document.documentElement.dataset.theme)) !== mode) {
            await page.locator("header .MuiSwitch-input").click();
        }
        await expect.poll(() => page.evaluate(() => document.documentElement.dataset.theme), { timeout: 2000 }).toBe(mode);
    }).toPass({ timeout: 15000 });
}

async function demoShots(browser) {
    // the size of the app window the docs show; the report fills its height
    const page = await browser.newPage({ viewport: { width: 1280, height: 860 } });
    try {
        for (const mode of ["light", "dark"]) {
            await page.goto(`${demo}/weather`);
            const weather = page.locator(".ud-pivot-report .pk-root");
            await expect(weather.locator(".pk-result td").first()).toBeVisible({ timeout: 30000 });
            await setTheme(page, mode);
            await expect(weather).toHaveAttribute("data-pk-theme", mode);
            await page.waitForTimeout(800);
            await page.screenshot({ path: `${out}pivot-showcase-weather-${mode}.png`, animations: "disabled" });
            console.log(`pivot-showcase-weather-${mode}.png`);

            await page.goto(`${demo}/upload`);
            const report = page.locator(".ud-pivot-report .pk-root");
            await expect(report).toContainText("Load data to start", { timeout: 30000 });
            await pickFile(report, fileOf("kosten-2026.csv", CSV, costsCsv()));
            await page.getByRole("dialog", { name: "Load kosten-2026.csv" }).getByTestId("import-apply").click();
            await expect(report.getByTestId("source-line")).toContainText("kosten-2026.csv");
            // the reader's report: costs per team and month
            for (const [field, zone] of [["Team", "Rows"], ["Monat", "Columns"], ["Kosten", "Values"]]) {
                await dragField(report, field, zone);
                await expect(report.getByRole("region", { name: zone })).toContainText(field);
            }
            await expect(report.locator(".pk-result td").first()).toBeVisible();
            await setTheme(page, mode);
            await expect(report).toHaveAttribute("data-pk-theme", mode);
            // the "loaded" note goes by itself once the pointer is off it, so the table shows whole
            await page.mouse.move(0, 0);
            await expect(report.locator(".pk-toast")).toHaveCount(0, { timeout: 30000 });
            await page.waitForTimeout(800);
            // the line under the table ("only in this browser") sits just below the window's edge, as the
            // report fills the window: scrolled into view, PSU's app bar stays on top
            await report.getByTestId("source-line").scrollIntoViewIfNeeded();
            await page.waitForTimeout(300);
            await page.screenshot({ path: `${out}pivot-showcase-upload-${mode}.png`, animations: "disabled" });
            console.log(`pivot-showcase-upload-${mode}.png`);
        }
    } finally {
        await page.close();
    }
}

const browser = await chromium.launch();
try {
    if (demo) await demoShots(browser);
    else await siteShots(browser);
} finally {
    await browser.close();
}
