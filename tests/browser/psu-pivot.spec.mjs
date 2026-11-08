// Optional: the showcase app of the pivot module on a PSU instance, in all three browsers. Runs only
// when PSU_PIVOT_URL points at the app (e.g. PSU_PIVOT_URL=https://psu.example.com/pivot-report npx
// playwright test psu-pivot); skipped in CI. The app is modules/PowerShellUniversal.Component.Pivot/
// examples/showcase.ps1. The template test saves and deletes a template of the anonymous user.
import { test, expect } from "@playwright/test";

const base = (process.env.PSU_PIVOT_URL || "").replace(/\/$/, "");
// the report itself, never the placeholder the Tickets page shows while its data loads
const REPORT = ".ud-pivot-report:not(.ud-pivot-placeholder) .pk-root";

async function open(page, path) {
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    await page.goto(`${base}/${path}`);
    // the report itself, not the placeholder the Tickets page shows while the data loads
    await expect(page.locator(REPORT).first()).toBeVisible({ timeout: 30000 });
    await expect(page.locator(".ud-pivot-placeholder")).toHaveCount(0);
    return errors;
}

// PSU's own light/dark switch in the app bar
async function setTheme(page, mode) {
    if ((await page.evaluate(() => document.documentElement.dataset.theme)) !== mode) {
        await page.locator("header .MuiSwitch-input").click();
    }
    await expect.poll(() => page.evaluate(() => document.documentElement.dataset.theme)).toBe(mode);
}

// Reset in the toolbar, or in its More menu where the toolbar has no room for it (WebKit's wider font)
async function resetButton(report) {
    const button = report.locator("[data-testid=reset]");
    if (await button.isVisible()) return { button, close: async () => {} };
    await report.getByRole("button", { name: "More" }).click();
    const page = report.page();
    return { button: page.locator("[data-testid=more-reset]"), close: () => page.keyboard.press("Escape") };
}

async function reset(report) {
    await (await resetButton(report)).button.click();
}

// Views in the toolbar, or in its More menu where the toolbar has no room for it; returns the menu
// a toolbar menu: its button, or its entry under "More" when the report is too narrow for it
async function openToolbarMenu(report, id) {
    const page = report.page();
    if (await report.locator(`[data-testid=${id}]`).isVisible()) await report.locator(`[data-testid=${id}]`).click();
    else {
        await report.locator("[data-testid=more]").click();
        await page.locator(`[data-testid=more-${id}]`).click();
    }
}

async function openViews(report) {
    const page = report.page();
    await openToolbarMenu(report, "views");
    const menu = page.locator(".pk-popover").last();
    await expect(menu).toContainText("Share");
    return menu;
}

// Reset is disabled while the report shows its start view
async function expectAtStart(report) {
    const { button, close } = await resetButton(report);
    await expect(button).toBeDisabled();
    await close();
}

test.describe("pivot showcase on PSU", () => {
    test.skip(!base, "set PSU_PIVOT_URL to the pivot showcase app to run these");

    test("renders the DataTable with typed fields and totals", async ({ page }) => {
        const errors = await open(page, "tickets");
        const report = page.locator(REPORT);
        // dates of the DataTable are dates, DBNull leaves the column typed
        await expect(report.getByRole("button", { name: /^Drag Created$/ })).toBeVisible();
        await expect(report.getByRole("button", { name: "Drag Closed" }).locator("xpath=..")).toContainText("Date");
        await expect(report.getByRole("region", { name: "Table" })).toContainText("5,000");
        await expect(page.locator(".pk-issues")).toHaveCount(0);
        expect(errors).toEqual([]);
    });

    test("the placeholder shows the report's frame while the server builds the data, where the report will be", async ({ page }) => {
        const errors = [];
        page.on("pageerror", (e) => errors.push(e.message));
        // hold the report's data back for two seconds, as a slow server would
        await page.route(/\/api\/internal\/component\/element\/tickets-report/, async (route) => {
            await new Promise((resolve) => setTimeout(resolve, 2000));
            await route.continue();
        });
        await page.goto(`${base}/tickets`);
        const placeholder = page.locator(".ud-pivot-placeholder .pk-root");
        await expect(placeholder).toBeVisible({ timeout: 30000 });
        // pivotkit's own skeleton: a status screen readers hear once
        await expect(placeholder.getByRole("status")).toContainText("Loading the report");
        await expect(placeholder.locator(".pk-skel-zone")).toHaveCount(4);
        const before = await placeholder.boundingBox();
        const report = page.locator(REPORT);
        await expect(report.getByRole("region", { name: "Table" })).toContainText("5,000", { timeout: 30000 });
        await expect(placeholder).toHaveCount(0);
        // the report takes the placeholder's place and size: nothing on the page moves
        const after = await report.boundingBox();
        for (const key of ["x", "y", "width", "height"]) expect(Math.round(after[key]), key).toBe(Math.round(before[key]));
        expect(errors).toEqual([]);
    });

    test("field names, descriptions, links and orders from -Schema, -FieldDescriptions and -FieldDefaults", async ({ page }) => {
        const warnings = [];
        page.on("console", (m) => {
            if (m.type() === "warning" && /New-UDPivotReport|pivotkit/.test(m.text())) warnings.push(m.text());
        });
        const errors = await open(page, "fields");
        const report = page.locator(REPORT);
        await expect(report).toHaveAttribute("aria-label", "Tickets with field descriptions");
        // the schema's title is the name the reader sees; the data keeps the column's name
        const list = report.getByRole("complementary", { name: "Field list" });
        await expect(list.getByRole("button", { name: "Drag Support team" })).toBeVisible();
        await expect(list.getByRole("button", { name: "Drag Lead time (h)" })).toBeVisible();
        // the description of each source behind the field's "i": schema with its https link, -FieldDescriptions (SQL), -FieldDefaults
        const dialog = page.getByRole("dialog");
        const about = async (field, text, href) => {
            // found through the field search, which also searches labels and descriptions
            await list.getByRole("searchbox", { name: "Search fields" }).fill(text.slice(0, 12));
            await list.getByRole("button", { name: `About ${field}`, exact: true }).click();
            await expect(dialog).toContainText(text);
            if (href) await expect(dialog.getByRole("link", { name: "Learn more" })).toHaveAttribute("href", href);
            // closed before the next one: an open description covers the fields below it
            await page.keyboard.press("Escape");
            await expect(dialog).toHaveCount(0);
        };
        await about("Support team", "The team the ticket is assigned to.", "https://powershell-universal-components.eize.dev/pivot/fields/");
        await about("Customer", "The customer who reported the ticket.");
        await about("Priority", "P1 is the most urgent.");
        // the schema's enum orders Status on Columns: Open, Waiting, Closed (not A to Z)
        const head = await report.getByRole("region", { name: "Table" }).locator("thead").innerText();
        expect(head.indexOf("Open")).toBeLessThan(head.indexOf("Waiting"));
        expect(head.indexOf("Waiting")).toBeLessThan(head.indexOf("Closed"));
        expect(warnings).toEqual([]);
        expect(errors).toEqual([]);
    });

    test("a field dragged into Rows becomes a chip there", async ({ page }) => {
        await open(page, "tickets");
        const report = page.locator(REPORT);
        const handle = report.getByRole("button", { name: "Drag Customer" });
        const rows = report.getByRole("region", { name: "Rows" });
        const from = await handle.boundingBox();
        const to = await rows.boundingBox();
        await page.mouse.move(from.x + from.width / 2, from.y + from.height / 2);
        await page.mouse.down();
        // dnd-kit starts a drag after a few pixels of movement
        await page.mouse.move(from.x + 30, from.y + 10, { steps: 5 });
        await page.mouse.move(to.x + to.width - 40, to.y + to.height / 2, { steps: 15 });
        await page.mouse.up();
        await expect(rows.getByRole("button", { name: "Customer", exact: true })).toBeVisible();
    });

    test("exports an Excel workbook with the file name of -FileName", async ({ page }) => {
        await open(page, "tickets");
        await page.locator(`${REPORT} [data-testid=export]`).click();
        const [download] = await Promise.all([page.waitForEvent("download"), page.locator("[data-testid=export-xlsx]").click()]);
        expect(download.suggestedFilename()).toBe("tickets.xlsx");
        const stream = await download.createReadStream();
        const chunks = [];
        for await (const chunk of stream) chunks.push(chunk);
        const bytes = Buffer.concat(chunks);
        // a zip file (XLSX), not an error page
        expect(bytes.subarray(0, 2).toString()).toBe("PK");
        expect(bytes.length).toBeGreaterThan(1000);
    });

    test("a click on a value runs -OnCellClick on the server with its fields", async ({ page }) => {
        await open(page, "events");
        await page.locator(REPORT).getByRole("region", { name: "Table" }).getByRole("cell", { name: /^\d[\d,]*$/ }).first().click();
        const log = page.locator("#event-log");
        await expect(log).toContainText("OnCellClick", { timeout: 15000 });
        await expect(log).toContainText('"field":"Team"');
        await expect(log).toContainText('"field":"Priority"');
    });

    test("a view change runs -OnViewChange with the view as JSON", async ({ page }) => {
        await open(page, "events");
        await page.locator(`${REPORT} [data-testid=swap]`).click();
        const log = page.locator("#event-log");
        await expect(log).toContainText("OnViewChange", { timeout: 15000 });
        await expect(log).toContainText('"rows":["Priority"]');
    });

    test("templates: shared views from -Templates and view files, my views in the browser without sign-in", async ({ page }) => {
        const errors = await open(page, "templates");
        const report = page.locator(REPORT);
        const name = `Playwright ${test.info().project.name} ${Date.now()}`;
        const menu = await openViews(report);
        // -Templates, then the view files of -TemplatePath
        await expect(menu).toContainText("Shared views");
        await expect(menu.locator("[data-testid='saved-view-Tickets per team and priority']")).toBeVisible();
        await expect(menu.locator("[data-testid='saved-view-Open work per team']")).toBeVisible();
        await expect(menu.locator("[data-testid='saved-view-Cost per category (donut)']")).toBeVisible();
        // the app has no sign-in: the reader's own views stay in this browser, and the menu says so
        await expect(menu.locator("[data-testid=store-note]")).toBeVisible();
        await expect(menu.locator("[data-testid^=publish-view-]")).toHaveCount(0);
        await menu.locator("[data-testid=saved-view-name]").fill(name);
        // the Save button, not Enter: the lazily loaded menu may move the focus while it renders
        await menu.getByRole("button", { name: "Save", exact: true }).click();
        await expect(report.locator(".pk-toast-dock")).toContainText(`“${name}” saved`);
        await page.keyboard.press("Escape");
        // a view file of the folder loads its chart: a donut
        await page.reload();
        await expect(page.locator(REPORT)).toBeVisible({ timeout: 30000 });
        let again = await openViews(page.locator(REPORT));
        await again.locator("[data-testid='saved-view-Cost per category (donut)']").click();
        await expect(page.locator(`${REPORT} [data-testid=chart-type]`)).toContainText("Donut");
        // after the reload the saved view is still there, and it can be deleted
        again = await openViews(page.locator(REPORT));
        await again.locator(`[data-testid='delete-view-${name}']`).click();
        await again.locator("[data-testid=confirm-delete]").click();
        await expect(page.locator(`${REPORT} .pk-toast-dock`)).toContainText(`“${name}” deleted`);
        expect(errors).toEqual([]);
    });

    test("the menus load lazily from the module's one bundle", async ({ page }) => {
        const chunks = [];
        page.on("request", (r) => {
            if (/menus\.js|chunk-[A-Z0-9]+\.js|echarts\.js/.test(r.url())) chunks.push(r.url());
        });
        const errors = await open(page, "tickets");
        const report = page.locator(REPORT);
        for (const id of ["options", "export", "chart-type"]) {
            // Export stays in the toolbar; Options and the chart type move under "More" first
            if (id === "export") await report.locator("[data-testid=export]").click();
            else await openToolbarMenu(report, id);
            const panel = page.locator(".pk-popover").last();
            await expect(panel).toBeVisible();
            await expect(panel).not.toContainText("could not be loaded");
            await expect(panel.locator("button").first()).toBeVisible();
            await page.keyboard.press("Escape");
        }
        const views = await openViews(report);
        await expect(views).toContainText("Copy view as JSON");
        // PSU serves only the registered bundle: no file is fetched next to it
        expect(chunks).toEqual([]);
        expect(errors).toEqual([]);
    });

    test("Copy table and the drill-down's Copy work over the instance's address", async ({ page }) => {
        const errors = await open(page, "tickets");
        const report = page.locator(REPORT);
        await report.locator("[data-testid=export]").click();
        await page.locator(".pk-popover").last().locator("[data-testid=export-copy-table]").click();
        // without a secure context (plain http) the Clipboard API is missing; pivotkit's fallback copies
        await expect(report.locator(".pk-toast-dock")).toContainText("Table copied");
        await page.keyboard.press("Escape");
        await report.getByRole("region", { name: "Table" }).locator("td").filter({ hasText: /^\d/ }).first().click();
        const drill = report.locator("[data-testid=drill-enlarge]").locator("xpath=ancestor::*[contains(@class,'pk-drill')][1]");
        await expect(report.locator("[data-testid=drill-enlarge]")).toBeVisible();
        await drill.getByRole("button", { name: "Export" }).click();
        await page.locator("[data-testid=drill-copy]").click();
        await expect(report.locator(".pk-toast-dock, .pk-status-notes").first()).toContainText(/[Cc]opied/);
        expect(errors).toEqual([]);
    });

    test("Enlarge lets the result fill the report; Escape brings the fields and zones back", async ({ page }) => {
        const errors = await open(page, "tickets");
        const report = page.locator(REPORT);
        const fields = report.getByRole("complementary", { name: "Field list" });
        await expect(fields).toBeVisible();
        await expect(report.locator("[data-testid=full-screen]")).toBeVisible();
        await report.locator("[data-testid=enlarge]").click();
        await expect(fields).toBeHidden();
        await expect(report.getByRole("region", { name: "Rows" })).toBeHidden();
        await expect(report.getByRole("region", { name: "Table" })).toContainText("5,000");
        await report.getByRole("region", { name: "Table" }).click({ position: { x: 5, y: 5 } });
        await page.keyboard.press("Escape");
        await expect(fields).toBeVisible();
        expect(errors).toEqual([]);
    });

    test("a card of a fixed height keeps the whole report; the field list starts as a rail", async ({ page }) => {
        const errors = await open(page, "layouts");
        const card = page.locator("#fixed-card");
        const report = card.locator(".pk-root");
        await report.scrollIntoViewIfNeeded();
        await expect(report.locator(".pk-rail")).toBeVisible();
        const box = await card.boundingBox();
        const inner = await report.boundingBox();
        expect(inner.y + inner.height).toBeLessThanOrEqual(box.y + box.height + 1);
        // the table scrolls inside the report instead of growing it
        await expect(report.getByRole("region", { name: "Table" })).toBeVisible();
        expect(Math.round(inner.height)).toBe(440);
        expect(errors).toEqual([]);
    });

    test("follows PSU's light and dark theme with PSU's colours", async ({ page }) => {
        await open(page, "tickets");
        const report = page.locator(REPORT);
        await setTheme(page, "dark");
        await expect(report).toHaveAttribute("data-pk-theme", "dark");
        await expect(report).toHaveCSS("background-color", "rgb(18, 18, 18)");
        await setTheme(page, "light");
        await expect(report).toHaveAttribute("data-pk-theme", "light");
        await expect(report).toHaveCSS("background-color", "rgb(255, 255, 255)");
    });

    test("a corporate stylesheet on :root themes the report and its chart, per PSU mode", async ({ page }) => {
        await open(page, "tickets");
        // what an app's stylesheet sets: the ECharts module's properties, one value per mode
        await page.addStyleTag({
            content: ':root { --psu-chart-1: #003b6f; --psu-chart-accent: #b35c00; } :root[data-theme="dark"] { --psu-chart-1: #6fa8dc; --psu-chart-accent: #f6b26b; }'
        });
        const report = page.locator(REPORT);
        await report.locator("[data-testid=show-chart]").click();
        const canvas = report.locator("[data-testid=pivot-chart] canvas");
        await expect(canvas).toBeVisible({ timeout: 15000 });
        const token = (name) => report.evaluate((e, n) => getComputedStyle(e).getPropertyValue(n).trim(), name);
        // pixels of the chart drawn in exactly this colour (the first series' bars)
        const pixels = (hex) =>
            canvas.evaluate((c, rgb) => {
                const data = c.getContext("2d").getImageData(0, 0, c.width, c.height).data;
                let n = 0;
                for (let i = 0; i < data.length; i += 4) if (data[i] === rgb[0] && data[i + 1] === rgb[1] && data[i + 2] === rgb[2]) n++;
                return n;
            }, [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16)));
        for (const [mode, accent, series] of [["light", "#b35c00", "#003b6f"], ["dark", "#f6b26b", "#6fa8dc"]]) {
            // switched by PSU's toggle, without a reload
            await setTheme(page, mode);
            await expect(report).toHaveAttribute("data-pk-theme", mode);
            await expect.poll(() => token("--pk-accent")).toBe(accent);
            await expect.poll(() => token("--pk-chart-1")).toBe(series);
            await expect.poll(() => pixels(series), { timeout: 10000 }).toBeGreaterThan(100);
        }
    });

    // Inside New-UDDynamic with -LoadingComponent (the Tickets page) PSU keeps the report over the switch
    // (measured on PSU 2026.3.4); a report placed straight into the page is mounted anew, which the test
    // of the reports without -Id covers. The view must survive either way.
    test("the reader's view survives PSU's light/dark switch", async ({ page }) => {
        await open(page, "tickets");
        const report = page.locator(REPORT);
        await report.locator("[data-testid=show-chart]").click();
        await report.locator("[data-testid=chart-type]").click();
        await page.locator("[data-testid=chart-line]").click();
        await expect(report.locator("[data-testid=chart-type]")).toContainText("Lines");
        const stored = () => page.evaluate(() => JSON.parse(sessionStorage.getItem("psu-pivot-views") || "{}")[`${location.pathname}#tickets`]?.v);
        await expect.poll(stored).toMatchObject({ display: "chart", chart: { type: "line" } });
        const before = await stored();
        for (const mode of ["dark", "light"]) {
            await setTheme(page, mode);
            await expect(report).toHaveAttribute("data-pk-theme", mode);
            await expect(report.locator("[data-testid=show-chart]")).toHaveAttribute("aria-pressed", "true");
            await expect(report.locator("[data-testid=chart-type]")).toContainText("Lines");
            await expect(report.locator("[data-testid=pivot-chart] canvas")).toBeVisible({ timeout: 15000 });
        }
        expect(await stored()).toEqual(before);
    });

    test("two reports without -Id keep their own views over theme switches and a reload; Reset goes to -View", async ({ page }) => {
        await open(page, "without-id");
        const first = page.locator(REPORT).nth(0);
        const second = page.locator(REPORT).nth(1);
        const pressed = (report, id) => expect(report.locator(`[data-testid=${id}]`)).toHaveAttribute("aria-pressed", "true");
        const entries = () => page.evaluate(() => JSON.parse(sessionStorage.getItem("psu-pivot-views") || "{}"));
        // the first one shows a chart, the second one swaps rows and columns and stays a table
        await first.locator("[data-testid=show-chart]").click();
        await second.locator("[data-testid=swap]").click();
        await expect.poll(async () => Object.keys(await entries()).filter((k) => k.includes("#auto-")).length).toBe(2);
        const check = async () => {
            await pressed(first, "show-chart");
            await pressed(second, "show-table");
            await expect(second.getByRole("region", { name: "Columns" })).toContainText("Category");
            await expect(first.getByRole("region", { name: "Columns" })).toContainText("Priority");
        };
        const before = await entries();
        const mounted = await first.elementHandle();
        for (const mode of ["dark", "light"]) {
            await setTheme(page, mode);
            await expect(first).toHaveAttribute("data-pk-theme", mode);
            await check();
        }
        // PSU did mount the reports anew (new elements), and the views are the same as before
        expect(await mounted.evaluate((e) => e.isConnected)).toBe(false);
        expect(await entries()).toEqual(before);
        await page.reload();
        await expect(first).toBeVisible({ timeout: 30000 });
        await check();
        // Reset goes back to the server's -View, and that is what the tab keeps from now on
        await reset(first);
        await pressed(first, "show-table");
        await page.reload();
        await expect(first).toBeVisible({ timeout: 30000 });
        await pressed(first, "show-table");
        await expectAtStart(first);
        await expect(second.getByRole("region", { name: "Columns" })).toContainText("Category");
    });

    // PSU's $Session belongs to the browser (one cookie for all tabs); the Tickets page stores the last
    // view there and passes it as -SavedView, which must only start a new tab, never replace another's
    test("two tabs of one browser keep their own views over reloads, theme and language switches", async ({ page, browser }) => {
        const viewSaved = (p) => p.waitForResponse((r) => /tickets-onViewChange/.test(r.url()) && r.request().method() === "POST", { timeout: 15000 });
        const shows = async (p, { chart, columns }) => {
            const report = p.locator(REPORT);
            await expect(report.locator(`[data-testid=${chart ? "show-chart" : "show-table"}]`)).toHaveAttribute("aria-pressed", "true");
            await expect(report.getByRole("region", { name: /^(Columns|Spalten)$/ })).toContainText(columns);
        };
        const reload = async (p) => {
            await p.reload();
            await expect(p.locator(REPORT)).toBeVisible({ timeout: 30000 });
        };
        const a = page;
        const b = await page.context().newPage();
        await open(a, "tickets");
        await open(b, "tickets");
        // tab A: a chart; tab B: rows and columns swapped, a table; both reach the server's $Session
        let saved = viewSaved(a);
        await a.locator(`${REPORT} [data-testid=show-chart]`).click();
        await saved;
        saved = viewSaved(b);
        await b.locator(`${REPORT} [data-testid=swap]`).click();
        await saved;
        await reload(a);
        await shows(a, { chart: true, columns: "Priority" });
        await reload(b);
        await shows(b, { chart: false, columns: "Team" });
        for (const mode of ["dark", "light"]) {
            await setTheme(a, mode);
            await shows(a, { chart: true, columns: "Priority" });
        }
        // the language select rebuilds the report on the server (Sync-UDElement)
        await a.getByRole("combobox", { name: "Language" }).click();
        await a.getByRole("option", { name: "Deutsch" }).click();
        await expect(a.locator(REPORT).getByRole("region", { name: "Spalten" })).toBeVisible({ timeout: 30000 });
        await shows(a, { chart: true, columns: "Priority" });
        await a.getByRole("combobox", { name: "Language" }).click();
        await a.getByRole("option", { name: "English" }).click();
        await expect(a.locator(REPORT).getByRole("region", { name: "Columns" })).toBeVisible({ timeout: 30000 });
        await reload(b);
        await shows(b, { chart: false, columns: "Team" });
        // a new tab starts with the last view of the session (B's), and Reset there goes to -View
        const c = await page.context().newPage();
        await open(c, "tickets");
        await shows(c, { chart: false, columns: "Team" });
        await reset(c.locator(REPORT));
        await shows(c, { chart: false, columns: "Priority" });
        await expect(c.locator(REPORT).getByRole("region", { name: "Rows" })).toContainText("Team");
        // another browser (another PSU session) knows nothing of these views
        const other = await browser.newContext({ viewport: { width: 1440, height: 900 } });
        try {
            const d = await other.newPage();
            await open(d, "tickets");
            await shows(d, { chart: false, columns: "Priority" });
            await expectAtStart(d.locator(REPORT));
        } finally {
            await other.close();
        }
        await reload(a);
        await shows(a, { chart: true, columns: "Priority" });
    });

    test("the address bar carries the view: a copied link opens it elsewhere, no history entries", async ({ page, browser }) => {
        await page.goto(`${base}/events`);
        await expect(page.locator(REPORT)).toBeVisible({ timeout: 30000 });
        await open(page, "without-id");
        const historyBefore = await page.evaluate(() => history.length);
        const first = page.locator(REPORT).nth(0);
        const second = page.locator(REPORT).nth(1);
        const mounted = await first.elementHandle();
        await first.locator("[data-testid=show-chart]").click();
        await second.locator("[data-testid=swap]").click();
        // one entry per report, written without a navigation or a new history entry
        await expect.poll(() => page.evaluate(() => location.hash.slice(1).split("&").filter((p) => p.startsWith("pivot-auto-")).length)).toBe(2);
        expect(await page.evaluate(() => history.length)).toBe(historyBefore);
        expect(await mounted.evaluate((e) => e.isConnected)).toBe(true);
        const link = page.url();
        // another browser (no sessionStorage, another PSU session) opens the same views from the link
        const other = await browser.newContext({ viewport: { width: 1440, height: 900 } });
        try {
            const p = await other.newPage();
            await p.goto(link);
            await expect(p.locator(REPORT).nth(0).locator("[data-testid=show-chart]")).toHaveAttribute("aria-pressed", "true", { timeout: 30000 });
            await expect(p.locator(REPORT).nth(1).getByRole("region", { name: "Columns" })).toContainText("Category");
            expect(p.url()).toBe(link);
        } finally {
            await other.close();
        }
        // the light/dark switch mounts the reports anew and keeps the address bar
        await setTheme(page, "dark");
        await expect(first).toHaveAttribute("data-pk-theme", "dark");
        expect(page.url()).toBe(link);
        await setTheme(page, "light");
        // Reset: -View, also in the address bar, at once (a reload right after it keeps -View)
        await reset(first);
        await expect(first.locator("[data-testid=show-table]")).toHaveAttribute("aria-pressed", "true");
        await page.reload();
        await expect(first).toBeVisible({ timeout: 30000 });
        await expect(first.locator("[data-testid=show-table]")).toHaveAttribute("aria-pressed", "true");
        await expectAtStart(first);
        await expect(second.getByRole("region", { name: "Columns" })).toContainText("Category");
        // one step back leaves the page: the changes made no history entries
        await page.goBack();
        await expect(page).toHaveURL(new RegExp(`${base}/events$`));
    });

    test("-NoAddressBar: the view stays out of the address and a link's view is ignored; the tab still keeps it", async ({ page }) => {
        await open(page, "layouts");
        const card = page.locator("#layout-card .pk-root");
        await card.scrollIntoViewIfNeeded();
        const zones = () => Promise.all(["Rows", "Columns"].map((name) => card.getByRole("region", { name }).innerText()));
        const before = await zones();
        await card.locator("[data-testid=swap]").click();
        await expect.poll(() => page.evaluate(() => Boolean(JSON.parse(sessionStorage.getItem("psu-pivot-views") || "{}")[`${location.pathname}#layout-card`]))).toBe(true);
        const swapped = await zones();
        expect(swapped).not.toEqual(before);
        expect(await page.evaluate(() => location.hash)).not.toContain("pivot-layout-card");
        // a reload keeps it from sessionStorage
        await page.reload();
        await expect(card).toBeVisible({ timeout: 30000 });
        await expect.poll(zones).toEqual(swapped);
        // a view in a link is not read either
        const view = Buffer.from(JSON.stringify({ rows: ["Status"], values: [{ field: "Ticket", agg: "count" }] })).toString("base64url");
        const other = await page.context().newPage();
        await other.goto(`${base}/layouts#pivot-layout-card=${view}`);
        const otherCard = other.locator("#layout-card .pk-root");
        await expect(otherCard).toBeVisible({ timeout: 30000 });
        await expect(otherCard.getByRole("region", { name: "Rows" })).not.toContainText("Status");
    });

    test("without -Height the report is one screen: on screen whole when the page loads, its zones open", async ({ page }) => {
        // a desktop window; the Tickets page has a title line with a language select above the report
        await page.setViewportSize({ width: 1440, height: 900 });
        await open(page, "tickets");
        const box = await page.locator(REPORT).evaluate((e) => {
            const r = e.getBoundingClientRect();
            return { top: r.top, bottom: r.bottom, height: r.height, folded: e.hasAttribute("data-pk-layout") };
        });
        // the default: 900 - 160 pixels (prepare.js DEFAULT_HEIGHT)
        expect(Math.round(box.height)).toBe(740);
        expect(box.bottom, "the report's bottom on screen").toBeLessThanOrEqual(900);
        expect(box.folded, "the zones are open").toBe(false);
    });

    test("fits a phone-sized window without a horizontal page scroll", async ({ page }) => {
        await page.setViewportSize({ width: 390, height: 844 });
        await open(page, "tickets");
        await expect(page.locator(`${REPORT} [data-testid=show-fields]`)).toBeVisible();
        expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);
        const height = await page.locator(REPORT).evaluate((e) => e.getBoundingClientRect().height);
        expect(height).toBeGreaterThan(700);
    });
});

// Optional: examples/templates.ps1 as an app with sign-in (PSU_PIVOT_AUTH_URL), with two local
// identities: a reader (no role of -AdminRole) and an admin (Operator or Administrator), given as
// PSU_PIVOT_READER_USER/_PASSWORD and PSU_PIVOT_ADMIN_USER/_PASSWORD. The tests save, publish and
// delete views of their own names (the browser project and a time stamp in each).
const auth = {
    url: (process.env.PSU_PIVOT_AUTH_URL || "").replace(/\/$/, ""),
    reader: { user: process.env.PSU_PIVOT_READER_USER, password: process.env.PSU_PIVOT_READER_PASSWORD },
    admin: { user: process.env.PSU_PIVOT_ADMIN_USER, password: process.env.PSU_PIVOT_ADMIN_PASSWORD }
};

async function signIn(browser, who) {
    const context = await browser.newContext();
    const page = await context.newPage();
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    await page.goto(`${auth.url}/requests`);
    if (page.url().includes("/login")) {
        await page.locator("input[type=text]:visible, input:not([type]):visible").first().fill(who.user);
        await page.locator("input[type=password]:visible").first().fill(who.password);
        await page.getByRole("button", { name: /^Login$/ }).first().click();
        await page.waitForURL((u) => !u.pathname.startsWith("/login"), { timeout: 30000 });
        if (!page.url().includes("/requests")) await page.goto(`${auth.url}/requests`);
    }
    const report = page.locator(REPORT);
    await expect(report).toBeVisible({ timeout: 30000 });
    return { context, page, report, errors };
}

// Save over a view (#69): pivotkit's Save and Save as send a name that exists, the server replaces
// that view. These helpers wait for the server's answer, not for a toast (another may still show).
const answer = (page, event) => page.waitForResponse((r) => new RegExp(event).test(r.url()) && r.request().method() === "POST", { timeout: 15000 });

// the views of one name in the menu (shared views come before my views)
const entries = (menu, name) => menu.locator(`[data-testid='saved-view-${name}']`);

// Save as (or Save before a view is loaded) under a name; with replace, confirms "... exists. Replace it?"
async function saveAs(signedIn, name, { replace = false } = {}) {
    const menu = await openViews(signedIn.report);
    await menu.locator("[data-testid=saved-view-name]").fill(name);
    const answered = answer(signedIn.page, "onSaveTemplate");
    // the button, not Enter: the lazily loaded menu may move the focus while it renders
    await menu.getByRole("button", { name: /^Save( as)?$/ }).click();
    if (replace) {
        await expect(menu.locator("[data-testid=replace-confirm]")).toBeVisible();
        await menu.locator("[data-testid=confirm-replace]").click();
    }
    expect((await answered).ok()).toBe(true);
    await signedIn.page.keyboard.press("Escape");
}

// loads a view of the menu: the first entry of the name (a shared one before an own one)
async function load(signedIn, name) {
    const menu = await openViews(signedIn.report);
    await entries(menu, name).first().click();
    // a click on an entry closes the menu (the name shows next to Views, or in More on a narrow toolbar)
    await expect(menu).toBeHidden();
}

async function reloadReport(signedIn) {
    await signedIn.page.reload();
    signedIn.report = signedIn.page.locator(REPORT);
    await expect(signedIn.report).toBeVisible({ timeout: 30000 });
}

// deletes every view of these names the signed-in user may delete; for the end of a test, also after
// a failure, so it never throws
async function removeViews(signedIn, names) {
    for (const name of names) {
        for (let i = 0; i < 4; i++) {
            try {
                await reloadReport(signedIn);
                const menu = await openViews(signedIn.report);
                const button = menu.locator(`[data-testid='delete-view-${name}']`).first();
                if (!(await button.count())) break;
                await button.click();
                const answered = answer(signedIn.page, "onDeleteTemplate");
                await menu.locator("[data-testid=confirm-delete]").click();
                await answered;
            } catch {
                break;
            }
        }
    }
}

test.describe("pivot templates with sign-in on PSU", () => {
    test.skip(!auth.url || !auth.reader.user || !auth.admin.user, "set PSU_PIVOT_AUTH_URL and the two identities to run these");
    test.describe.configure({ mode: "serial" });

    test("own views on the server, publishing for -AdminRole only, refused on the server for a reader, the admin panel for admins", async ({ browser }) => {
        const stamp = `${test.info().project.name} ${Date.now()}`;
        const own = `Reader view ${stamp}`;
        const shared = `Admin view ${stamp}`;

        // the admin saves a view and publishes it
        const admin = await signIn(browser, auth.admin);
        await expect(admin.page.locator("[data-testid=pivot-admin]")).toBeVisible();
        let menu = await openViews(admin.report);
        await menu.locator("[data-testid=saved-view-name]").fill(shared);
        // the Save button, not Enter: the lazily loaded menu may move the focus while it renders
        await menu.getByRole("button", { name: "Save", exact: true }).click();
        await expect(admin.report.locator(".pk-toast-dock")).toContainText(`“${shared}” saved`, { timeout: 15000 });
        await admin.page.keyboard.press("Escape");
        menu = await openViews(admin.report);
        await menu.locator(`[data-testid='publish-view-${shared}']`).click();
        await menu.locator("[data-testid=confirm-publish]").click();
        await expect(admin.report.locator(".pk-toast-dock")).toContainText(`“${shared}” published`, { timeout: 15000 });
        // the admin panel: the columns as pivotkit reads them, and the view
        await admin.page.locator("[data-testid=pivot-admin] summary").click();
        await expect(admin.page.locator("[data-testid=pivot-admin-columns]")).toContainText("Opened");
        await expect(admin.page.locator("[data-testid=pivot-admin-columns]")).toContainText("date");
        await expect(admin.page.locator("[data-testid=pivot-admin-view]")).toContainText('"rows"');
        await expect(admin.page.locator("[data-testid=pivot-admin-server]")).toContainText("ms");

        // the reader: the shared view read-only, no publish, no admin panel; own views saved on the server
        const reader = await signIn(browser, auth.reader);
        await expect(reader.page.locator("[data-testid=pivot-admin]")).toHaveCount(0);
        menu = await openViews(reader.report);
        await expect(menu.locator(`[data-testid='saved-view-${shared}']`)).toBeVisible();
        await expect(menu.locator(`[data-testid='delete-view-${shared}']`)).toHaveCount(0);
        await expect(menu.locator("[data-testid^=publish-view-]")).toHaveCount(0);
        await expect(menu.locator("[data-testid=store-note]")).toHaveCount(0);
        await menu.locator("[data-testid=saved-view-name]").fill(own);
        // the Save button, not Enter: the lazily loaded menu may move the focus while it renders
        await menu.getByRole("button", { name: "Save", exact: true }).click();
        await expect(reader.report.locator(".pk-toast-dock")).toContainText(`“${own}” saved`, { timeout: 15000 });
        await reader.page.keyboard.press("Escape");
        // a forged request: the reader's delete sent for the shared view; the server refuses it
        await reader.page.route(/onDeleteTemplate/, (route) => route.continue({ postData: JSON.stringify({ name: shared, scope: "shared" }) }));
        menu = await openViews(reader.report);
        await menu.locator(`[data-testid='delete-view-${own}']`).click();
        await menu.locator("[data-testid=confirm-delete]").click();
        await expect(reader.report.locator(".pk-toast-dock")).toContainText("Only admins can change shared views.", { timeout: 15000 });
        await reader.page.unroute(/onDeleteTemplate/);
        // after a reload both are still there: the own view from the server, the shared one untouched
        await reader.page.reload();
        await expect(reader.page.locator(REPORT)).toBeVisible({ timeout: 30000 });
        menu = await openViews(reader.page.locator(REPORT));
        await expect(menu.locator(`[data-testid='saved-view-${shared}']`)).toBeVisible();
        await menu.locator(`[data-testid='delete-view-${own}']`).click();
        await menu.locator("[data-testid=confirm-delete]").click();
        await expect(reader.page.locator(`${REPORT} .pk-toast-dock`)).toContainText(`“${own}” deleted`, { timeout: 15000 });

        // the admin deletes the shared view and the own one
        await admin.page.reload();
        await expect(admin.page.locator(REPORT)).toBeVisible({ timeout: 30000 });
        // the shared view and the admin's own one have the same name: one after the other
        for (const left of [1, 0]) {
            menu = await openViews(admin.page.locator(REPORT));
            await menu.locator(`[data-testid='delete-view-${shared}']`).first().click();
            // the server's answer, not the toast: the first delete's toast may still be shown
            const answered = admin.page.waitForResponse((r) => /onDeleteTemplate/.test(r.url()), { timeout: 15000 });
            await menu.locator("[data-testid=confirm-delete]").click();
            expect((await answered).ok()).toBe(true);
            await expect(menu.locator(`[data-testid='saved-view-${shared}']`)).toHaveCount(left);
            await admin.page.keyboard.press("Escape");
        }
        // gone on the server too
        await admin.page.reload();
        await expect(admin.page.locator(REPORT)).toBeVisible({ timeout: 30000 });
        menu = await openViews(admin.page.locator(REPORT));
        await expect(menu.locator(`[data-testid='saved-view-${shared}']`)).toHaveCount(0);
        expect(admin.errors).toEqual([]);
        expect(reader.errors).toEqual([]);
        await admin.context.close();
        await reader.context.close();
    });
    test("Save and a confirmed Save as replace the reader's own view: one entry, the change kept", async ({ browser }) => {
        const name = `Saved over ${test.info().project.name} ${Date.now()}`;
        const reader = await signIn(browser, auth.reader);
        try {
            await saveAs(reader, name);
            await load(reader, name);
            // a change, then Save "..." of the loaded view
            await reader.report.locator("[data-testid=show-chart]").click();
            let menu = await openViews(reader.report);
            const saved = answer(reader.page, "onSaveTemplate");
            await menu.locator("[data-testid=save-loaded]").click();
            expect((await saved).ok()).toBe(true);
            await reloadReport(reader);
            menu = await openViews(reader.report);
            await expect(entries(menu, name)).toHaveCount(1);
            await reader.page.keyboard.press("Escape");
            await load(reader, name);
            await expect(reader.report.locator("[data-testid=show-chart]")).toHaveAttribute("aria-pressed", "true");

            // Save as with the same name asks first; Replace keeps one entry, with the new view
            await reader.report.locator("[data-testid=show-table]").click();
            await saveAs(reader, name, { replace: true });
            await reloadReport(reader);
            menu = await openViews(reader.report);
            await expect(entries(menu, name)).toHaveCount(1);
            await reader.page.keyboard.press("Escape");
            await load(reader, name);
            await expect(reader.report.locator("[data-testid=show-table]")).toHaveAttribute("aria-pressed", "true");
            expect(reader.errors).toEqual([]);
        } finally {
            await removeViews(reader, [name]);
            await reader.context.close();
        }
    });

    test("an admin's Save on a shared view asks, then replaces it for everyone: one shared entry, changed", async ({ browser }) => {
        const name = `Shared saved over ${test.info().project.name} ${Date.now()}`;
        const admin = await signIn(browser, auth.admin);
        try {
            await saveAs(admin, name);
            let menu = await openViews(admin.report);
            const published = answer(admin.page, "onPublishTemplate");
            await menu.locator(`[data-testid='publish-view-${name}']`).click();
            await menu.locator("[data-testid=confirm-publish]").click();
            expect((await published).ok()).toBe(true);
            await reloadReport(admin);
            // the shared view (listed first), changed, then Save "..." with the question for everyone
            await load(admin, name);
            await admin.report.locator("[data-testid=show-chart]").click();
            menu = await openViews(admin.report);
            await menu.locator("[data-testid=save-loaded]").click();
            await expect(menu.locator("[data-testid=replace-shared-confirm]")).toBeVisible();
            const replaced = answer(admin.page, "onPublishTemplate");
            await menu.locator("[data-testid=confirm-replace-shared]").click();
            expect((await replaced).ok()).toBe(true);

            // a reader sees one shared view of the name, with the change
            const reader = await signIn(browser, auth.reader);
            try {
                menu = await openViews(reader.report);
                await expect(entries(menu, name)).toHaveCount(1);
                await reader.page.keyboard.press("Escape");
                await load(reader, name);
                await expect(reader.report.locator("[data-testid=show-chart]")).toHaveAttribute("aria-pressed", "true");
                expect(reader.errors).toEqual([]);
            } finally {
                await reader.context.close();
            }
            // the admin: the shared view and the own one of the same name, no third
            await reloadReport(admin);
            menu = await openViews(admin.report);
            await expect(entries(menu, name)).toHaveCount(2);
            expect(admin.errors).toEqual([]);
        } finally {
            await removeViews(admin, [name]);
            await admin.context.close();
        }
    });

    test("names that differ only in case are two views", async ({ browser }) => {
        const stamp = `${test.info().project.name} ${Date.now()}`;
        const upper = `Case View ${stamp}`;
        const lower = `case view ${stamp}`;
        const reader = await signIn(browser, auth.reader);
        try {
            await saveAs(reader, upper);
            // no question: pivotkit compares names in their case, and so does the server
            await saveAs(reader, lower);
            await reloadReport(reader);
            const menu = await openViews(reader.report);
            await expect(entries(menu, upper)).toHaveCount(1);
            await expect(entries(menu, lower)).toHaveCount(1);
            expect(reader.errors).toEqual([]);
        } finally {
            await removeViews(reader, [upper, lower]);
            await reader.context.close();
        }
    });
});
