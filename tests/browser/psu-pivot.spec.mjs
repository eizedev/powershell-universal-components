// Optional: the showcase app of the pivot module on a PSU instance, in all three browsers. Runs only
// when PSU_PIVOT_URL points at the app (e.g. PSU_PIVOT_URL=https://psu.example.com/pivot-report npx
// playwright test psu-pivot); skipped in CI. The app is modules/PowerShellUniversal.Component.Pivot/
// examples/showcase.ps1. The template test saves and deletes a template of the anonymous user.
import { test, expect } from "@playwright/test";

const base = (process.env.PSU_PIVOT_URL || "").replace(/\/$/, "");

async function open(page, path) {
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    await page.goto(`${base}/${path}`);
    await expect(page.locator(".pk-root").first()).toBeVisible({ timeout: 30000 });
    return errors;
}

// PSU's own light/dark switch in the app bar
async function setTheme(page, mode) {
    if ((await page.evaluate(() => document.documentElement.dataset.theme)) !== mode) {
        await page.locator("header .MuiSwitch-input").click();
    }
    await expect.poll(() => page.evaluate(() => document.documentElement.dataset.theme)).toBe(mode);
}

test.describe("pivot showcase on PSU", () => {
    test.skip(!base, "set PSU_PIVOT_URL to the pivot showcase app to run these");

    test("renders the DataTable with typed fields and totals", async ({ page }) => {
        const errors = await open(page, "tickets");
        const report = page.locator(".pk-root");
        // dates of the DataTable are dates, DBNull leaves the column typed
        await expect(report.getByRole("button", { name: /^Drag Created$/ })).toBeVisible();
        await expect(report.getByRole("button", { name: "Drag Closed" }).locator("xpath=..")).toContainText("Date");
        await expect(report.getByRole("region", { name: "Table" })).toContainText("5,000");
        await expect(page.locator(".pk-issues")).toHaveCount(0);
        expect(errors).toEqual([]);
    });

    test("a field dragged into Rows becomes a chip there", async ({ page }) => {
        await open(page, "tickets");
        const report = page.locator(".pk-root");
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
        await page.locator(".pk-root [data-testid=export]").click();
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
        await page.locator(".pk-root").getByRole("region", { name: "Table" }).getByRole("cell", { name: /^\d[\d,]*$/ }).first().click();
        const log = page.locator("#event-log");
        await expect(log).toContainText("OnCellClick", { timeout: 15000 });
        await expect(log).toContainText('"field":"Team"');
        await expect(log).toContainText('"field":"Priority"');
    });

    test("a view change runs -OnViewChange with the view as JSON", async ({ page }) => {
        await open(page, "events");
        await page.locator(".pk-root [data-testid=swap]").click();
        const log = page.locator("#event-log");
        await expect(log).toContainText("OnViewChange", { timeout: 15000 });
        await expect(log).toContainText('"rows":["Priority"]');
    });

    test("templates are saved on the server, refused with its message, and deleted", async ({ page }) => {
        await open(page, "tickets");
        const report = page.locator(".pk-root");
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
        const report = page.locator(".pk-root");
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
        const report = page.locator(".pk-root");
        const canvas = report.locator("[data-testid=pivot-chart] canvas");
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
            // PSU mounts the page's components anew when its theme switches, so the report is back at its
            // start view (a table): show the chart in this mode
            await report.locator("[data-testid=show-chart]").click();
            await expect(canvas).toBeVisible({ timeout: 15000 });
            await expect.poll(() => pixels(series), { timeout: 10000 }).toBeGreaterThan(100);
        }
    });

    test("fits a phone-sized window without a horizontal page scroll", async ({ page }) => {
        await page.setViewportSize({ width: 390, height: 844 });
        await open(page, "tickets");
        await expect(page.locator(".pk-root [data-testid=show-fields]")).toBeVisible();
        expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(390);
        const height = await page.locator(".pk-root").evaluate((e) => e.getBoundingClientRect().height);
        expect(height).toBeGreaterThan(700);
    });
});
