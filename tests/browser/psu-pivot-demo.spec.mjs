// Optional: the Pivot demo module's showcase (PowerShellUniversal.Component.Pivot.Demo, New-UDPivotShowcase)
// on a PSU instance. Runs only when PSU_PIVOT_DEMO_URL points at the app (e.g.
// PSU_PIVOT_DEMO_URL=https://psu.example.com/pivot-showcase npx playwright test psu-pivot-demo); skipped in CI.
import { test, expect } from "@playwright/test";

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
});
