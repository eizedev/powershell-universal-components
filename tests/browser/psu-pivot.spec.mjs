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

    test("templates are saved on the server, refused with its message, and deleted", async ({ page }) => {
        await open(page, "tickets");
        const report = page.locator(REPORT);
        const name = `Playwright ${test.info().project.name} ${Date.now()}`;
        const templates = () => report.getByRole("button", { name: "Templates" }).click();
        await templates();
        await page.getByRole("textbox", { name: "Template name" }).fill(name);
        await page.getByRole("textbox", { name: "Template name" }).press("Enter");
        await expect(report.getByRole("status").first()).toContainText(`“${name}” saved`, { timeout: 15000 });
        // a built-in name: the server refuses with its own words
        await templates();
        await page.getByRole("textbox", { name: "Template name" }).fill("Lead time per customer");
        await page.getByRole("textbox", { name: "Template name" }).press("Enter");
        await expect(report).toContainText("is a built-in template", { timeout: 15000 });
        // after a reload the saved one comes from the server, and it can be deleted
        await page.reload();
        await expect(report).toBeVisible({ timeout: 30000 });
        await templates();
        await page.getByRole("button", { name: `Delete ${name}` }).click();
        await page.locator("[data-testid=confirm-delete]").click();
        await expect(report.getByRole("status").first()).toContainText(`“${name}” deleted`, { timeout: 15000 });
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

    test("fits a phone-sized window without a horizontal page scroll", async ({ page }) => {
        await page.setViewportSize({ width: 390, height: 844 });
        await open(page, "tickets");
        await expect(page.locator(`${REPORT} [data-testid=show-fields]`)).toBeVisible();
        expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);
        const height = await page.locator(REPORT).evaluate((e) => e.getBoundingClientRect().height);
        expect(height).toBeGreaterThan(700);
    });
});
