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

// -Group with -TooltipMode Auto: hovering a bar in one chart shows that bar there and keeps the linked
// chart's tooltip in step through ECharts' own sync, without errors from the hover redraw
test.describe("linked charts on PSU", () => {
    test.skip(!base, "set PSU_URL to the showcase app to run these");
    test("hovering a bar in one linked chart shows the other chart's tooltip at the same time", async ({ page }) => {
        const errors = [];
        page.on("pageerror", (e) => errors.push(e.message));
        await page.goto(`${base.replace(/\/$/, "")}/technical`);
        const card = page.locator(".MuiCard-root", { hasText: "Linked charts" }).first();
        await card.scrollIntoViewIfNeeded();
        await expect.poll(() => card.evaluate((el) => [...el.querySelectorAll("div")].filter((d) => d.echarts).length), { timeout: 30000 }).toBe(2);
        const tips = () => card.evaluate((el) => [...el.querySelectorAll("div")].filter((d) => d.echarts).map((d) => {
            const t = [...d.querySelectorAll("div")].find((x) => x.style.zIndex === "9999999" && getComputedStyle(x).display !== "none" && getComputedStyle(x).opacity !== "0");
            return t ? t.innerText : "";
        }));
        // the middle of bar 100 in the second chart
        const p = await card.evaluate((el) => {
            const d = [...el.querySelectorAll("div")].filter((x) => x.echarts)[1];
            const c = d.echarts;
            const v = c.getOption().series[0].data[100];
            const value = v && typeof v === "object" && !Array.isArray(v) ? v.value : v;
            const [x, y] = c.convertToPixel({ seriesIndex: 0 }, [value[0], value[1] / 2]);
            const box = d.getBoundingClientRect();
            return { x: box.left + x, y: box.top + y };
        });
        await expect(async () => {
            await page.mouse.move(p.x - 10, p.y);
            await page.mouse.move(p.x, p.y, { steps: 3 });
            await expect.poll(async () => (await tips())[1], { timeout: 1000 }).toContain("Errors");
            await expect.poll(async () => (await tips())[0], { timeout: 1000 }).toContain("Requests");
        }).toPass({ timeout: 15000 });
        expect(errors).toEqual([]);
    });
});
