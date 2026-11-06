// The documentation site in a real browser: every example chart must render, size itself to its
// container, keep a palette in both themes, turn a real mouse click into the payload PowerShell would
// get, and export its rows.
import { test, expect } from "@playwright/test";

// all chart containers (the ECharts instance hangs on its element) with what the tests compare
function chartsState(page) {
    return page.evaluate(() => [...document.querySelectorAll("div")].filter((d) => d.echarts).map((d) => {
        const c = d.echarts;
        const o = c.getOption();
        return {
            id: d.closest("section") ? d.closest("section").id : "",
            width: d.clientWidth,
            canvasWidth: c.getWidth(),
            series: (o.series || []).length,
            colors: (o.color || []).length,
            // the text an empty chart shows in place of series (-EmptyText)
            empty: [].concat(o.graphic || []).flatMap((g) => [].concat(g.elements || g)).map((g) => g.style && g.style.text).find(Boolean) || null
        };
    }));
}

async function openSite(page) {
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    page.on("console", (m) => {
        if (m.type() === "error") errors.push(m.text());
    });
    await page.goto("/");
    await expect(page.locator("section.example").first()).toBeVisible();
    // charts are created in effects; wait until every example has one
    const examples = await page.locator("section.example").count();
    await expect.poll(async () => (await chartsState(page)).length, { timeout: 20000 }).toBe(examples);
    return errors;
}

test("every example renders without errors", async ({ page }) => {
    const errors = await openSite(page);
    await expect(page.locator("[role=alert]")).toHaveCount(0);
    const charts = await chartsState(page);
    for (const c of charts) {
        // an example without rows shows its -EmptyText instead of series
        if (c.id === "when-there-is-nothing-to-show") expect(c.empty, c.id).toBe("No failed jobs today");
        else expect(c.series, c.id).toBeGreaterThan(0);
        expect(Math.abs(c.width - c.canvasWidth), `${c.id} canvas follows its container`).toBeLessThanOrEqual(2);
    }
    expect(errors).toEqual([]);
});

test("both themes keep a palette and switch live", async ({ page }) => {
    await openSite(page);
    const before = await page.evaluate(() => document.documentElement.dataset.theme);
    const textColor = () => page.evaluate(() => [...document.querySelectorAll("div")].find((d) => d.echarts).echarts.getOption().textStyle.color);
    const textBefore = await textColor();
    // a palette is always there (a chart with -Palette brings its own, shorter one)
    for (const c of await chartsState(page)) expect(c.colors, c.id).toBeGreaterThan(0);
    await page.locator("nav .theme").click();
    await expect.poll(() => page.evaluate(() => document.documentElement.dataset.theme)).not.toBe(before);
    for (const c of await chartsState(page)) expect(c.colors, `${c.id} after the switch`).toBeGreaterThan(0);
    // the charts follow: the text colour of the theme changes with the mode
    await expect.poll(textColor).not.toBe(textBefore);
});

test("a mouse click on a bar gives the row, as $EventData would", async ({ page }) => {
    await openSite(page);
    const section = page.locator("#click-and-range-selection");
    await section.scrollIntoViewIfNeeded();
    // pixel of the fourth bar's middle, from the chart itself
    const point = await section.evaluate((s) => {
        const el = [...s.querySelectorAll("div")].find((d) => d.echarts);
        const c = el.echarts;
        const item = c.getOption().series[0].data[3];
        const value = Array.isArray(item) ? item : item.value;
        const [x, y] = c.convertToPixel({ seriesIndex: 0 }, [value[0], value[1] / 2]);
        const box = el.getBoundingClientRect();
        return { x: box.left + x, y: box.top + y };
    });
    await page.mouse.click(point.x, point.y);
    const toast = page.locator(".toast");
    await expect(toast).toContainText("-OnClick");
    await expect(toast).toContainText('"Opened": 42');
});

test("narrow window: charts shrink with the page", async ({ page }) => {
    await openSite(page);
    await page.setViewportSize({ width: 420, height: 900 });
    await expect.poll(async () => {
        const charts = await chartsState(page);
        return charts.every((c) => c.width <= 420 && Math.abs(c.width - c.canvasWidth) <= 2);
    }, { timeout: 10000 }).toBe(true);
});

test("CSV export downloads the rows", async ({ page }) => {
    await openSite(page);
    const download = page.waitForEvent("download");
    await page.locator("#a-bar-chart-from-any-powershell-objects").evaluate((s) => {
        const el = [...s.querySelectorAll("div")].find((d) => d.echarts);
        el.echarts.getOption().toolbox[0].feature.myCsv.onclick();
    });
    const file = await download;
    expect(file.suggestedFilename()).toMatch(/\.csv$/);
    const text = await (await file.createReadStream()).toArray();
    const csv = Buffer.concat(text).toString("utf8");
    expect(csv).toContain("Month");
    expect(csv.split("\r\n").length).toBeGreaterThan(6);
});
