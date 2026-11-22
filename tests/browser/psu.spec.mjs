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

// Get-UDElement reads the last click and zoom from the browser (#159): the showcase's Basics page has
// a chart with -Id 'state-chart' and a button that writes what Get-UDElement returned
test.describe("Get-UDElement on PSU", () => {
    test.skip(!base, "set PSU_URL to the showcase app to run these");
    test("returns the last click and the zoom of a chart", async ({ page }) => {
        const errors = [];
        page.on("pageerror", (e) => errors.push(e.message));
        await page.goto(`${base.replace(/\/$/, "")}/basics`);
        const chart = page.locator("#state-chart");
        await chart.scrollIntoViewIfNeeded();
        await expect.poll(() => chart.evaluate((el) => [...el.querySelectorAll("div")].some((d) => d.echarts)), { timeout: 30000 }).toBe(true);
        const read = page.getByRole("button", { name: "Read the state (Get-UDElement)" });
        const log = page.locator("#state-log");
        // the middle of the bar "Mar", clicked with the mouse
        const p = await chart.evaluate((el) => {
            const d = [...el.querySelectorAll("div")].find((x) => x.echarts);
            const c = d.echarts;
            const v = c.getOption().series[0].data[2];
            const value = v && typeof v === "object" ? (Array.isArray(v) ? v[1] : v.value) : v;
            const [x, y] = c.convertToPixel({ seriesIndex: 0 }, ["Mar", value / 2]);
            const box = d.getBoundingClientRect();
            return { x: box.left + x, y: box.top + y };
        });
        await page.mouse.click(p.x, p.y);
        await read.click();
        await expect(log).toContainText('"name":"Mar"', { timeout: 15000 });
        await expect(log).toContainText('"zoom":null');
        // the mouse wheel zooms in (-Zoom Inside)
        await page.mouse.move(p.x, p.y);
        await page.mouse.wheel(0, -400);
        await expect.poll(() => chart.evaluate((el) => {
            const dz = [...el.querySelectorAll("div")].find((x) => x.echarts).echarts.getOption().dataZoom[0];
            return dz.end - dz.start;
        })).toBeLessThan(100);
        await read.click();
        await expect(log).toContainText(/"zoom":\{"from":"[A-Z][a-z]{2}","to":"[A-Z][a-z]{2}","start":[\d.]+,"end":[\d.]+\}/, { timeout: 15000 });
        expect(errors).toEqual([]);
    });
});
