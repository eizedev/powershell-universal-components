// Optional: the Pivot demo module's showcase (PowerShellUniversal.Component.Pivot.Demo, New-UDPivotShowcase)
// on a PSU instance. Runs only when PSU_PIVOT_DEMO_URL points at the app (e.g.
// PSU_PIVOT_DEMO_URL=https://psu.example.com/pivot-showcase npx playwright test psu-pivot-demo); skipped in CI.
import { test, expect } from "@playwright/test";
import { assetsXlsx, CSV, dropFiles, fieldNames, fileOf, openDataMenu, pickFile, preview, TICKETS_CSV, XLSX } from "./pivot-import.mjs";

const base = (process.env.PSU_PIVOT_DEMO_URL || "").replace(/\/$/, "");

test.describe("pivot demo showcase on PSU", () => {
    test.skip(!base, "PSU_PIVOT_DEMO_URL is not set");

    test("only the Live data switch and its label toggle it, not the free space beside them", async ({ page }) => {
        await page.goto(`${base}/release-cycles`);
        const input = page.locator('input[id$="-live"]');
        await expect(input).toHaveCount(1, { timeout: 30000 });
        const label = page.locator("label", { has: input });
        const box = await label.boundingBox();
        const before = await input.isChecked();
        // well to the right of the label, on the same line
        await page.mouse.click(box.x + box.width + 200, box.y + box.height / 2);
        await expect(input).toBeChecked({ checked: before });
        expect(box.width).toBeLessThan(400);
    });

    test("Your data: the reader's files are read in the browser, nothing goes to the server; views are kept per file", async ({ page }) => {
        const errors = [];
        page.on("pageerror", (e) => errors.push(e.message));
        // what the page sends to the server while files are loaded: none of their content
        const posted = [];
        page.on("request", (r) => {
            if (r.method() !== "GET") posted.push(`${r.url()} ${r.postData() || ""}`);
        });
        await page.goto(`${base}/upload`);
        const report = page.locator(".ud-pivot-report .pk-root");
        await expect(report).toBeVisible({ timeout: 30000 });
        // no data of the app: the report asks for a file
        await expect(report).toContainText("Load data to start");
        // an Excel workbook dropped onto the report
        await dropFiles(page, report, [fileOf("assets.xlsx", XLSX, assetsXlsx())]);
        const dialog = page.getByRole("dialog", { name: "Load assets.xlsx" });
        expect((await preview(dialog)).columns).toEqual(["Asset", "Kind", "Bought", "Price"]);
        await dialog.getByTestId("import-apply").click();
        await expect.poll(() => fieldNames(report)).toEqual(["Asset", "Kind", "Bought", "Price"]);
        // a view of the workbook, saved in this browser
        const name = `Assets ${test.info().project.name} ${Date.now()}`;
        await report.locator("[data-testid=views]").click();
        const menu = page.locator(".pk-popover").last();
        await menu.locator("[data-testid=save-as]").click();
        await menu.locator("[data-testid=saved-view-name]").fill(name);
        await menu.getByRole("button", { name: "Save", exact: true }).click();
        await expect(report.locator(".pk-toast-dock")).toContainText(`“${name}” saved`);
        // a CSV picked under Data: another file, the workbook's view is not offered for it
        await pickFile(report, fileOf("tickets.csv", CSV, TICKETS_CSV));
        await page.getByRole("dialog", { name: "Load tickets.csv" }).getByTestId("import-apply").click();
        await expect.poll(() => fieldNames(report)).toEqual(["Id", "Team", "Opened", "Hours", "Zip"]);
        await report.locator("[data-testid=views]").click();
        await expect(page.locator(".pk-popover").last().locator(`[data-testid='saved-view-${name}']`)).toHaveCount(0);
        await page.keyboard.press("Escape");
        // the workbook again: its view is there
        await dropFiles(page, report, [fileOf("assets.xlsx", XLSX, assetsXlsx())]);
        await page.getByRole("dialog", { name: "Load assets.xlsx" }).getByTestId("import-apply").click();
        await expect.poll(() => fieldNames(report)).toEqual(["Asset", "Kind", "Bought", "Price"]);
        await report.locator("[data-testid=views]").click();
        const views = page.locator(".pk-popover").last();
        await expect(views.locator(`[data-testid='saved-view-${name}']`)).toHaveCount(1);
        await views.locator(`[data-testid='delete-view-${name}']`).click();
        await views.locator("[data-testid=confirm-delete]").click();
        // Back to original data: the empty report of the page
        await openDataMenu(report);
        await page.getByTestId("back-to-original").click();
        await expect(report).toContainText("Load data to start");
        // nothing of the files reached the server
        for (const text of ["A100", "Laptop", "01067", "Network", "assets.xlsx", "tickets.csv"]) {
            expect(posted.filter((p) => p.includes(text)), text).toEqual([]);
        }
        expect(errors).toEqual([]);
    });

    test("Your data: the loaded file stays when the language switch draws the report again (Sync-UDElement)", async ({ page }) => {
        const errors = [];
        page.on("pageerror", (e) => errors.push(e.message));
        await page.goto(`${base}/upload`);
        const report = page.locator(".ud-pivot-report .pk-root");
        await expect(report).toBeVisible({ timeout: 30000 });
        await dropFiles(page, report, [fileOf("tickets.csv", CSV, TICKETS_CSV)]);
        await page.getByRole("dialog", { name: "Load tickets.csv" }).getByTestId("import-apply").click();
        await expect.poll(() => fieldNames(report)).toEqual(["Id", "Team", "Opened", "Hours", "Zip"]);
        // a mark on the report's element: gone after the switch shows that the report was mounted anew
        await report.evaluate((el) => el.setAttribute("data-test-mark", "before"));
        // the page's language select: New-UDDynamic draws the report again with -Locale de-DE
        await page.getByRole("combobox", { name: "Language" }).click();
        await page.getByRole("option", { name: "Deutsch" }).click();
        const again = page.locator(".ud-pivot-report .pk-root");
        // German now: the report was drawn again
        await expect(again.getByRole("region", { name: "Zeilen" })).toBeVisible({ timeout: 30000 });
        await expect(page.locator("[data-test-mark]")).toHaveCount(0);
        await expect.poll(() => fieldNames(again)).toEqual(["Id", "Team", "Opened", "Hours", "Zip"]);
        await expect(again.getByTestId("source-line")).toContainText("tickets.csv");
        // back to English for the other tests (the language is kept per session)
        await page.getByRole("combobox", { name: "Language" }).click();
        await page.getByRole("option", { name: "English" }).click();
        expect(errors).toEqual([]);
    });
});
