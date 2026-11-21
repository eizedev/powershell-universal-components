// Optional: New-UDPivotReport -Uri -Source on a PSU instance with a pivotkit-server behind it. Runs only
// when PSU_PIVOT_ROWS_URL points at such a page with a link parameter in its query string, e.g.
// PSU_PIVOT_ROWS_URL='https://psu.example.com/reports/orders?customer=acme' npx playwright test
// psu-pivot-rows; skipped in CI. PSU_PIVOT_ROWS_WITHHELD (optional) names a field the server holds
// back from the signed-in person, and PSU_PIVOT_ROWS_PROBLEM_URL (optional) a page whose report the
// server refuses. The page's report needs -Id; the fragment it writes is #pivot-<id>=...
import { test, expect } from "@playwright/test";

const url = process.env.PSU_PIVOT_ROWS_URL || "";
const withheld = process.env.PSU_PIVOT_ROWS_WITHHELD || "";
const problemUrl = process.env.PSU_PIVOT_ROWS_PROBLEM_URL || "";
const REPORT = ".ud-pivot-report .pk-root";

test.describe("PSU: rows from a pivotkit-server", () => {
    test.skip(!url, "PSU_PIVOT_ROWS_URL is not set");

    test("the report shows the server's rows; a changed view keeps the link's query string, so a copied link still names it", async ({ page }) => {
        const errors = [];
        page.on("pageerror", (e) => errors.push(e.message));
        await page.goto(url);
        const report = page.locator(REPORT).first();
        await expect(report).toBeVisible({ timeout: 30000 });
        const search = new URL(url).search;
        expect(search).not.toBe("");
        // a field into Rows with + Add: the report writes the view into the fragment
        await report.getByTestId("add-field-rows").click();
        await page.locator("[data-testid^=add-pick-]").first().click();
        await expect.poll(() => page.evaluate(() => location.hash)).toMatch(/^#pivot-/);
        expect(await page.evaluate(() => location.search)).toBe(search);
        // the address a person copies opens the same rows: the query string and the view
        const copied = await page.evaluate(() => location.href);
        const again = await page.context().newPage();
        await again.goto(copied);
        await expect(again.locator(REPORT).first().getByRole("region", { name: "Rows" })).not.toContainText("Add or drop", { timeout: 30000 });
        expect(await again.evaluate(() => location.search)).toBe(search);
        expect(errors).toEqual([]);
    });

    test("a link's view that needs a field the server holds back says which one", async ({ page }) => {
        test.skip(!withheld, "PSU_PIVOT_ROWS_WITHHELD is not set");
        const id = await (async () => {
            await page.goto(url);
            await expect(page.locator(REPORT).first()).toBeVisible({ timeout: 30000 });
            return page.evaluate(() => document.querySelector(".ud-pivot-report").id);
        })();
        // the report's own entry: base64url JSON of the view, as the module writes it
        const view = Buffer.from(JSON.stringify({ rows: [], values: [{ field: withheld, agg: "sum" }] })).toString("base64url");
        await page.goto(`${url}#pivot-${id}=${view}`);
        // a new fragment alone loads nothing: the report reads the link when it mounts
        await page.reload();
        await expect(page.locator(REPORT).first()).toBeVisible({ timeout: 30000 });
        await expect(page.locator(".ud-pivot-withheld")).toContainText(withheld, { timeout: 30000 });
        await expect(page.locator(".ud-pivot-withheld")).toContainText("operator");
    });

    test("a refused request shows the reader a message, never the server's address or a token", async ({ page }) => {
        test.skip(!problemUrl, "PSU_PIVOT_ROWS_PROBLEM_URL is not set");
        await page.goto(problemUrl);
        const box = page.locator(".ud-pivot-problem[role=alert]");
        await expect(box).toBeVisible({ timeout: 30000 });
        await expect(box.locator("h3")).not.toBeEmpty();
        const text = await box.innerText();
        expect(text).not.toMatch(/https?:\/\//);
        expect(text).not.toMatch(/Bearer|eyJ/);
        // nor anywhere else on the page: PSU shows an error of a page as a toast, so the module writes
        // the operator's message as a warning (the toast comes a moment after the page)
        await page.waitForTimeout(2000);
        await expect(page.locator("body")).not.toContainText("pivotkit-server");
        await expect(page.locator("body")).not.toContainText("/api/v1");
    });
});
