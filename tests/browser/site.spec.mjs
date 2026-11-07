// The documentation site in a real browser: every live example on every page must render, size itself
// to its container and draw values, follow the site's light/dark switch, turn a real mouse click into
// the payload PowerShell would get, and export its rows. Build first: docs/site/Build-Site.ps1, then
// zensical build (see docs/development/index.md).
import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";

// the pages of the built site, as paths ("/echarts/bars/")
const pages = [...readFileSync(new URL("../../site/sitemap.xml", import.meta.url), "utf8").matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => new URL(m[1]).pathname);

// every example placeholder with what the tests compare (the ECharts instance hangs on its element)
function examplesState(page) {
    return page.evaluate(() => [...document.querySelectorAll(".psu-example")].map((el) => {
        const id = el.getAttribute("data-example");
        if (el.querySelector("perspective-viewer")) {
            return { id, perspective: true };
        }
        // the pivot report's placeholder: the report's frame, busy
        if (el.querySelector(".ud-pivot-placeholder .pk-root[aria-busy=true]")) {
            return { id, placeholder: true };
        }
        // the pivot report: rendered once its table or chart region is there
        if (el.querySelector(".pk-root .pk-result")) {
            return { id, pivot: true, cells: el.querySelectorAll(".pk-result td").length, chart: Boolean(el.querySelector(".pk-result canvas")) };
        }
        const d = [...el.querySelectorAll("div")].find((x) => x.echarts);
        if (!d) {
            return { id, error: el.querySelector(".psu-example-error") ? el.textContent : null, pending: true };
        }
        const c = d.echarts;
        const o = c.getOption();
        return {
            id,
            width: d.clientWidth,
            canvasWidth: c.getWidth(),
            series: (o.series || []).length,
            // values the series draw: their own data, or the rows of a dataset they read
            points: (o.series || []).reduce((n, s) => n + [].concat(s.data || []).length, 0) + [].concat(o.dataset || []).reduce((n, x) => n + [].concat(x.source || []).length, 0),
            colors: (o.color || []).length,
            textColor: o.textStyle && o.textStyle.color,
            // the text an empty chart shows in place of series (-EmptyText)
            empty: [].concat(o.graphic || []).flatMap((g) => [].concat(g.elements || g)).map((g) => g.style && g.style.text).find(Boolean) || null
        };
    }));
}

// errors of the page itself; the repository facts in the header come from api.github.com, which may
// answer 404 or rate-limit without anything being wrong with the site
function collectErrors(page) {
    const errors = [];
    page.on("pageerror", (e) => errors.push(e.message));
    page.on("console", (m) => {
        if (m.type() === "error" && !/api\.github\.com|status of 40[34]/.test(m.text())) errors.push(m.text());
    });
    page.on("response", (r) => {
        if (r.status() >= 400 && !r.url().includes("api.github.com")) errors.push(`${r.status()} ${r.url()}`);
    });
    return errors;
}

async function openPage(page, path) {
    await page.goto(path);
    const count = await page.locator(".psu-example").count();
    // charts are created after examples.json is loaded; wait until every placeholder has one
    await expect.poll(async () => (await examplesState(page)).filter((e) => !e.pending).length, { timeout: 30000 }).toBe(count);
    return count;
}

test("the site has its pages", () => {
    expect(pages.length).toBeGreaterThan(20);
    expect(pages).toContain("/echarts/");
    expect(pages).toContain("/perspective/");
    expect(pages).toContain("/pivot/");
});

test("Pivot: the report holds the DataTable, follows the switch and shows the $EventData of a save", async ({ page }) => {
    const errors = collectErrors(page);
    await openPage(page, "/pivot/");
    const example = page.locator('[data-example="pivot-report-from-a-datatable"]');
    const report = example.locator(".pk-root");
    // 1200 rows: the grand total of the count
    await expect(report.getByRole("region", { name: "Table" })).toContainText("1,200");
    const theme = await report.getAttribute("data-pk-theme");
    await page.locator("[data-md-component=palette] label:visible").first().click();
    await expect(report).not.toHaveAttribute("data-pk-theme", theme);
    // in the page's content column the report is medium wide: Templates may sit in the More menu
    const more = report.locator("[data-testid=more]");
    if (await more.count()) {
        await more.click();
        await page.getByRole("menuitem", { name: "Templates" }).click();
    } else {
        await report.getByRole("button", { name: "Templates" }).click();
    }
    await page.getByRole("textbox", { name: "Template name" }).fill("Mine");
    await page.getByRole("textbox", { name: "Template name" }).press("Enter");
    await expect(page.locator(".psu-event")).toContainText("-OnSaveTemplate");
    await expect(page.locator(".psu-event")).toContainText('"name": "Mine"');
    await expect(report.getByRole("status").first()).toContainText("saved");
    expect(errors).toEqual([]);
});

test("Pivot: the placeholder shows the report's frame, tells screen readers it is loading and follows the switch", async ({ page }) => {
    const errors = collectErrors(page);
    await openPage(page, "/pivot/");
    const root = page.locator('[data-example="placeholder-while-the-data-loads"] .pk-root');
    await expect(root).toHaveAttribute("role", "status");
    await expect(root).toHaveAttribute("aria-busy", "true");
    await expect(root).toContainText("Loading report");
    // pivotkit's own frame: field list, four zones, a result area
    await expect(root.locator(".pk-panel-slot")).toHaveCount(1);
    await expect(root.locator(".pk-zone")).toHaveCount(4);
    await expect(root.locator(".pk-result")).toHaveCount(1);
    const box = await root.boundingBox();
    expect(Math.round(box.height)).toBe(420);
    const theme = await root.getAttribute("data-pk-theme");
    await page.locator("[data-md-component=palette] label:visible").first().click();
    await expect(root).not.toHaveAttribute("data-pk-theme", theme);
    expect(errors).toEqual([]);
});

test.describe("for readers who asked for reduced motion", () => {
    test.use({ reducedMotion: "reduce" });

    test("Pivot: the placeholder keeps still", async ({ page }) => {
        await openPage(page, "/pivot/");
        const bone = page.locator('[data-example="placeholder-while-the-data-loads"] .ud-pivot-bone').first();
        expect(await bone.evaluate((el) => getComputedStyle(el).animationName)).toBe("none");
    });
});

test("every example on every page renders and draws values, without errors", async ({ page }) => {
    test.setTimeout(240000);
    const errors = collectErrors(page);
    let total = 0;
    for (const path of pages) {
        total += await openPage(page, path);
        for (const e of await examplesState(page)) {
            if (e.perspective || e.placeholder) continue;
            if (e.pivot) {
                expect(e.cells + (e.chart ? 1 : 0), `${path} ${e.id} draws values`).toBeGreaterThan(0);
                continue;
            }
            // an example without rows shows its -EmptyText instead of series
            if (e.id === "when-there-is-nothing-to-show") expect(e.empty, e.id).toBe("No failed jobs today");
            else {
                expect(e.series, `${path} ${e.id}`).toBeGreaterThan(0);
                expect(e.points, `${path} ${e.id} draws values`).toBeGreaterThan(0);
            }
            expect(Math.abs(e.width - e.canvasWidth), `${e.id} canvas follows its container`).toBeLessThanOrEqual(2);
        }
        await expect(page.locator(".psu-example [role=alert], .psu-example-error")).toHaveCount(0);
    }
    // every example of examples.json is on a page (Build-Site.ps1 fails otherwise; this checks the built site)
    const all = await page.evaluate(() => fetch("/assets/charts/examples.json").then((r) => r.json()));
    expect(total).toBe(Object.keys(all).length);
    expect(errors).toEqual([]);
});

test("the charts follow the site's light/dark switch", async ({ page }) => {
    await openPage(page, "/echarts/");
    const before = await page.evaluate(() => document.documentElement.dataset.theme);
    const textBefore = (await examplesState(page))[0].textColor;
    await page.locator("[data-md-component=palette] label:visible").first().click();
    await expect.poll(() => page.evaluate(() => document.documentElement.dataset.theme)).not.toBe(before);
    await expect.poll(async () => (await examplesState(page))[0].textColor).not.toBe(textBefore);
    for (const e of await examplesState(page)) expect(e.colors, `${e.id} keeps a palette`).toBeGreaterThan(0);
});

test("pages opened without a reload get their charts", async ({ page }) => {
    await openPage(page, "/echarts/");
    await page.evaluate(() => {
        window.__samePage = true;
    });
    await page.locator("nav a[href$='shares/']").first().click();
    await expect(page).toHaveURL(/\/echarts\/shares\/$/);
    await expect.poll(async () => (await examplesState(page)).filter((e) => !e.pending).length, { timeout: 15000 }).toBe(3);
    // Zensical's instant navigation: the document stayed, only the content changed
    expect(await page.evaluate(() => window.__samePage)).toBe(true);
});

test("a mouse click on a bar gives the row, as $EventData would", async ({ page }) => {
    await openPage(page, "/echarts/interaction/");
    const example = page.locator('[data-example="click-and-range-selection"]');
    await example.scrollIntoViewIfNeeded();
    // pixel of the fourth bar's middle, from the chart itself
    const point = await example.evaluate((el) => {
        const d = [...el.querySelectorAll("div")].find((x) => x.echarts);
        const c = d.echarts;
        const item = c.getOption().series[0].data[3];
        const value = Array.isArray(item) ? item : item.value;
        const [x, y] = c.convertToPixel({ seriesIndex: 0 }, [value[0], value[1] / 2]);
        const box = d.getBoundingClientRect();
        return { x: box.left + x, y: box.top + y };
    });
    await page.mouse.click(point.x, point.y);
    // the payload shows right below the clicked example, not somewhere else on the page
    const panel = page.locator('[data-example="click-and-range-selection"] + .psu-event');
    await expect(panel).toContainText("-OnClick");
    await expect(panel).toContainText('"Opened": 42');
    await panel.getByRole("button", { name: "Close" }).click();
    await expect(panel).toHaveCount(0);
});

test("narrow window: charts shrink with the page", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await openPage(page, "/echarts/bars/");
    await expect.poll(async () => (await examplesState(page)).every((e) => e.width <= 390 && Math.abs(e.width - e.canvasWidth) <= 2), { timeout: 10000 }).toBe(true);
    // nothing makes the page scroll sideways
    expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(0);
});

test("CSV export downloads the rows", async ({ page }) => {
    await openPage(page, "/echarts/");
    const download = page.waitForEvent("download");
    await page.locator('[data-example="a-bar-chart-from-any-powershell-objects"]').evaluate((el) => {
        const d = [...el.querySelectorAll("div")].find((x) => x.echarts);
        d.echarts.getOption().toolbox[0].feature.myCsv.onclick();
    });
    const file = await download;
    expect(file.suggestedFilename()).toMatch(/\.csv$/);
    const text = await (await file.createReadStream()).toArray();
    const csv = Buffer.concat(text).toString("utf8");
    expect(csv).toContain("Month");
    expect(csv.split("\r\n").length).toBeGreaterThan(6);
});

test("Perspective: the grid holds the rows and follows the switch", async ({ page }) => {
    await openPage(page, "/perspective/");
    const viewer = page.locator('[data-example="datagrid-that-readers-rearrange"] perspective-viewer');
    // the element is defined once the lazy Perspective chunk has loaded, the table a moment later
    const rows = () => viewer.evaluate(async (v) => {
        try {
            return await (await v.getTable()).size();
        } catch {
            return -1; // not defined yet, or no table loaded yet
        }
    });
    await expect.poll(rows, { timeout: 30000 }).toBe(800);
    const theme = () => viewer.evaluate(async (v) => (await v.save()).theme);
    const before = await theme();
    await page.locator("[data-md-component=palette] label:visible").first().click();
    await expect.poll(theme).not.toBe(before);
});
