// Optional: the showcase app on a PSU instance in all three browsers. Runs only when PSU_URL points
// at the app (e.g. PSU_URL=https://psu.example.com/echarts npx playwright test psu); skipped in CI.
import { test, expect } from "@playwright/test";

const base = process.env.PSU_URL;
// "public" calls public web APIs (slow, outside our control), "live" and "benchmark" redraw on a timer
// or on demand - left out so a run is repeatable
const pages = ["basics", "bars", "tickets", "finance", "msp", "operations", "calendar", "intraday", "dataplatform", "public", "layouts", "technical", "live", "benchmark"];

test.describe("showcase on PSU", () => {
    test.skip(!base, "set PSU_URL to the showcase app to run these");
    for (const name of pages) {
        test(name, async ({ page }) => {
            const errors = [];
            page.on("pageerror", (e) => errors.push(e.message));
            await page.goto(`${base.replace(/\/$/, "")}/${name}`);
            await expect.poll(() => page.evaluate(() => [...document.querySelectorAll("div")].filter((d) => d.echarts).length), { timeout: 30000 }).toBeGreaterThan(0);
            // wait until the page stops adding charts (dynamic regions render after the first ones)
            let last = -1;
            await expect.poll(async () => {
                const n = await page.evaluate(() => [...document.querySelectorAll("div")].filter((d) => d.echarts).length);
                const stable = n === last;
                last = n;
                return stable;
            }, { timeout: 30000, intervals: [1000] }).toBe(true);
            await expect(page.locator("[role=alert]")).toHaveCount(0);
            const charts = await page.evaluate(() => [...document.querySelectorAll("div")].filter((d) => d.echarts && d.offsetParent !== null).map((d) => ({ w: d.clientWidth, cw: d.echarts.getWidth() })));
            for (const c of charts) expect(Math.abs(c.w - c.cw)).toBeLessThanOrEqual(2);
            expect(errors).toEqual([]);
        });
    }
});
