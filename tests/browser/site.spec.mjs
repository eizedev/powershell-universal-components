// The documentation site in a real browser: every live example on every page must render, size itself
// to its container and draw values, follow the site's light/dark switch, turn a real mouse click into
// the payload PowerShell would get, and export its rows. Build first: docs/site/Build-Site.ps1, then
// zensical build (see docs/development/index.md).
import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import { openSaveAs, openViews } from "./pivot-menus.mjs";

// the pages of the built site, as paths ("/echarts/bars/")
const pages = [...readFileSync(new URL("../../site/sitemap.xml", import.meta.url), "utf8").matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => new URL(m[1]).pathname);

// every example placeholder with what the tests compare (the ECharts instance hangs on its element)
function examplesState(page) {
    return page.evaluate(() => [...document.querySelectorAll(".psu-example")].map((el) => {
        const id = el.getAttribute("data-example");
        if (el.querySelector("perspective-viewer")) {
            return { id, perspective: true };
        }
        // the pivot report and its placeholder are drawn into a shadow root of the example
        const pivot = el.shadowRoot;
        // the pivot report's placeholder: the report's frame, busy
        if (pivot && pivot.querySelector(".ud-pivot-placeholder .pk-skeleton")) {
            return { id, placeholder: true };
        }
        // the pivot report: rendered once its table or chart region is there
        if (pivot && pivot.querySelector(".pk-root .pk-result")) {
            return { id, pivot: true, cells: pivot.querySelectorAll(".pk-result td").length, chart: Boolean(pivot.querySelector(".pk-result canvas")), firstSteps: Boolean(pivot.querySelector(".pk-result .pk-empty")) };
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

// saves the report's view under a name through the Views menu's Save as level (pivot-menus.mjs)
async function saveView(report, name) {
    const menu = await openViews(report);
    await openSaveAs(menu);
    await menu.locator("[data-testid=saved-view-name]").fill(name);
    await menu.locator("[data-testid=saved-view-name]").press("Enter");
}

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
    await saveView(report, "Mine");
    await expect(page.locator(".psu-event")).toContainText("-OnSaveTemplate");
    await expect(page.locator(".psu-event")).toContainText('"name": "Mine"');
    await expect(report.locator(".pk-toast-dock")).toContainText("saved");
    expect(errors).toEqual([]);
});

test("Pivot: the one-line example gets the API's rows; a click on a field puts it into Rows", async ({ page }) => {
    const errors = collectErrors(page);
    await openPage(page, "/pivot/");
    const report = page.locator('[data-example="pivot-report-from-a-web-api"] .pk-root');
    // the snapshot of https://endoflife.date/api/python.json: one row per release cycle
    await report.locator(".pk-field[data-field=cycle] .pk-field-name").click();
    await expect(report.getByRole("region", { name: "Table" })).toContainText("3.14");
    expect(errors).toEqual([]);
});

test("Pivot: the start view, field labels and both templates of the medium example", async ({ page }) => {
    const errors = collectErrors(page);
    await openPage(page, "/pivot/");
    const report = page.locator('[data-example="start-view-field-names-and-templates"] .pk-root');
    await expect(report.getByRole("region", { name: "Table" })).toContainText("End of life (year)");
    // -FieldDefaults labels in the field list
    await expect(report.locator(".pk-field-list")).toContainText("Release cycle");
    await expect(report.locator(".pk-field-list")).toContainText("Latest version");
    const menu = await openViews(report);
    await expect(menu).toContainText("End of life per year and product");
    await expect(menu).toContainText("Releases per year");
    expect(errors).toEqual([]);
});

test("Pivot: in the app example a saved view is listed under My views, its $EventData shows, and the admin panel is there", async ({ page }) => {
    const errors = collectErrors(page);
    await openPage(page, "/pivot/");
    const example = page.locator('[data-example="a-report-app-with-loading-views-per-reader-and-roles"]');
    const report = example.locator(".pk-root");
    await expect(report.getByRole("region", { name: "Table" })).toContainText("windows-server");
    // the reader has the role of -AdminRole
    await expect(example.locator("[data-testid=pivot-admin]")).toBeVisible();
    await saveView(report, "Mine");
    // the store's own event handler, registered by the module
    await expect(page.locator('[data-example="a-report-app-with-loading-views-per-reader-and-roles"] + .psu-event')).toContainText("-OnSaveTemplate");
    const menu = await openViews(report);
    await expect(menu).toContainText("My views");
    await expect(menu).toContainText("Mine");
    expect(errors).toEqual([]);
});

test("Pivot: menus open inside the report's shadow root, styled, never on the page's body", async ({ page }) => {
    await openPage(page, "/pivot/templates/");
    const example = page.locator('[data-example="shared-views-and-my-views"]');
    await openViews(example.locator(".pk-root"));
    const state = await example.evaluate((el) => {
        const popover = el.shadowRoot && el.shadowRoot.querySelector(".pk-popover");
        return {
            inShadow: Boolean(popover),
            // pivotkit's own stylesheet reached it: a popover is positioned fixed over the report
            position: popover ? getComputedStyle(popover).position : null,
            onBody: document.querySelectorAll("body > .pk-popover").length
        };
    });
    expect(state).toEqual({ inShadow: true, position: "fixed", onBody: 0 });
});

test("Pivot: shared views and my views; a reader with -AdminRole publishes and the page shows the $EventData", async ({ page }) => {
    const errors = collectErrors(page);
    await openPage(page, "/pivot/templates/");
    const report = page.locator('[data-example="shared-views-and-my-views"] .pk-root');
    await expect(report.getByRole("region", { name: "Table" })).toContainText("400");
    const menu = await openViews(report);
    await expect(menu).toContainText("Shared views");
    await expect(menu).toContainText("Lead time per priority");
    await expect(menu).toContainText("My views");
    await expect(menu).toContainText("My priorities");
    // Publish next to the entry asks in a level of the menu
    await menu.locator("[data-testid='publish-view-My priorities']").click();
    await menu.locator("[data-testid=confirm-publish]").click();
    await expect(page.locator(".psu-event")).toContainText("-OnPublishTemplate");
    await expect(page.locator(".psu-event")).toContainText('"name": "My priorities"');
    await expect(report.locator(".pk-toast-dock")).toContainText("published");
    expect(errors).toEqual([]);
});

test("Pivot: the placeholder shows the report's skeleton, tells screen readers it is loading and follows the switch", async ({ page }) => {
    const errors = collectErrors(page);
    await openPage(page, "/pivot/");
    const root = page.locator('[data-example="placeholder-while-the-data-loads"] .pk-root');
    await expect(root.getByRole("status")).toContainText("Loading the report");
    // pivotkit's own skeleton: field list, toolbar, four zones
    await expect(root.locator(".pk-skel-panel")).toHaveCount(1);
    await expect(root.locator(".pk-skel-zone")).toHaveCount(4);
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
        const bone = page.locator('[data-example="placeholder-while-the-data-loads"] .pk-skel').first();
        // pivotkit's rule for reduced motion: one run of a millisecond, then still
        const style = await bone.evaluate((el) => ({ duration: getComputedStyle(el).animationDuration, count: getComputedStyle(el).animationIterationCount }));
        expect(parseFloat(style.duration)).toBeLessThanOrEqual(0.001);
        expect(style.count).toBe("1");
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
                // the one-line example has no start view: the report shows its first steps instead of values
                if (e.id === "pivot-report-from-a-web-api") expect(e.firstSteps, `${path} ${e.id} shows its first steps`).toBe(true);
                else expect(e.cells + (e.chart ? 1 : 0), `${path} ${e.id} draws values`).toBeGreaterThan(0);
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

// -TooltipMode Auto with a real mouse: the segment under the pointer, the total between the stacks
// the ECharts instance of an example and the page pixel of a value
async function chartPoint(example, seriesIndex, dataIndex, part = 0.5) {
    return example.evaluate((el, [si, di, f]) => {
        const d = [...el.querySelectorAll("div")].find((x) => x.echarts);
        const c = d.echarts;
        const box = d.getBoundingClientRect();
        const s = c.getOption().series;
        // the middle of segment si: the sum of the segments below it plus a share of its own value
        const valueAt = (i) => { const v = s[i].data[di]; return v && typeof v === "object" ? v.value : v; };
        let below = 0;
        for (let i = 0; i < si; i++) below += valueAt(i) || 0;
        const [x, y] = c.convertToPixel({ seriesIndex: si }, [di, below + f * (valueAt(si) || 0)]);
        return { x: box.left + x, y: box.top + y, name: s[si].name, names: s.map((x) => x.name) };
    }, [seriesIndex, dataIndex, part]);
}
async function tooltipText(example) {
    return example.evaluate((el) => {
        const d = [...el.querySelectorAll("div")].find((x) => x.echarts);
        // ECharts' tooltip is the HTML element it adds to the chart, shown with opacity 1
        const tip = [...d.querySelectorAll("div")].find((x) => x.style.zIndex === "9999999" && getComputedStyle(x).display !== "none" && getComputedStyle(x).opacity !== "0");
        return tip ? tip.innerText : "";
    });
}

test("tooltip on a stacked bar: the hovered segment and the total, between the stacks the total only", async ({ page }) => {
    await openPage(page, "/echarts/labels/");
    const example = page.locator('[data-example="tooltip-on-the-hovered-segment"]');
    await example.scrollIntoViewIfNeeded();
    const seg = await chartPoint(example, 5, 2);
    // the bars grow into place while the chart animates in: point again until it has settled
    await expect(async () => {
        await page.mouse.move(seg.x - 30, seg.y + 4);
        await page.mouse.move(seg.x, seg.y, { steps: 4 });
        await expect.poll(() => tooltipText(example), { timeout: 1000 }).toContain(seg.name);
        await expect.poll(() => tooltipText(example), { timeout: 1000 }).not.toContain(seg.names.find((n) => n !== seg.name));
    }).toPass({ timeout: 15000 });
    const onSegment = await tooltipText(example);
    expect(onSegment).toContain("Total");
    // no other department in the tooltip
    for (const other of seg.names.filter((n) => n !== seg.name)) expect(onSegment).not.toContain(other);
    // the same height, between the third and fourth stack
    const next = await chartPoint(example, 5, 3);
    await page.mouse.move((seg.x + next.x) / 2, seg.y, { steps: 4 });
    await expect.poll(() => tooltipText(example)).not.toContain(seg.name);
    const gap = await tooltipText(example);
    expect(gap).toContain("Total");
    for (const n of seg.names) expect(gap).not.toContain(n);
});

test("tooltip on a line: the hovered point alone, between the points every series", async ({ page }) => {
    await openPage(page, "/echarts/lines-and-time/");
    const example = page.locator('[data-example="pins-on-single-values"]');
    await example.scrollIntoViewIfNeeded();
    const at = (si, x) => example.evaluate((el, [s, xi]) => {
        const d = [...el.querySelectorAll("div")].find((n) => n.echarts);
        const c = d.echarts;
        const box = d.getBoundingClientRect();
        const series = c.getOption().series;
        const v = series[s].data[Math.round(xi)];
        const [px, py] = c.convertToPixel({ seriesIndex: s }, [xi, v && typeof v === "object" ? v.value : v]);
        return { x: box.left + px, y: box.top + py, names: series.map((n) => n.name) };
    }, [si, x]);
    const point = await at(1, 4);
    const [windows, linux] = point.names;
    // the symbols move into place while the chart animates in: point again until it has settled
    await expect(async () => {
        await page.mouse.move(point.x - 20, point.y - 20);
        await page.mouse.move(point.x, point.y, { steps: 4 });
        await expect.poll(() => tooltipText(example), { timeout: 1000 }).not.toContain(windows);
    }).toPass({ timeout: 15000 });
    expect(await tooltipText(example)).toContain(linux);
    // halfway to the next week, clear of both lines
    const next = await at(1, 5);
    await page.mouse.move((point.x + next.x) / 2, Math.min(point.y, next.y) - 60, { steps: 4 });
    await expect.poll(() => tooltipText(example)).toContain(windows);
    expect(await tooltipText(example)).toContain(linux);
});

test("tooltip after the toolbox stacks grouped bars: between the stacks the total only", async ({ page }) => {
    await openPage(page, "/echarts/");
    const example = page.locator('[data-example="a-bar-chart-from-any-powershell-objects"]');
    await example.scrollIntoViewIfNeeded();
    // the toolbox's Stack button, found by its title in the chart's own drawing
    const stackButton = await example.evaluate((el) => {
        const d = [...el.querySelectorAll("div")].find((n) => n.echarts);
        const box = d.getBoundingClientRect();
        const icon = d.echarts.getZr().storage.getDisplayList().find((e) => e.__title === "Stack");
        const r = icon.getBoundingRect().clone();
        r.applyTransform(icon.getComputedTransform());
        return { x: box.left + r.x + r.width / 2, y: box.top + r.y + r.height / 2 };
    });
    await page.mouse.click(stackButton.x, stackButton.y);
    await expect.poll(() => example.evaluate((el) => [...el.querySelectorAll("div")].find((n) => n.echarts).echarts.getOption().series[0].stack)).toBeTruthy();
    const a = await chartPoint(example, 0, 1);
    const b = await chartPoint(example, 0, 2);
    await expect(async () => {
        await page.mouse.move(a.x, a.y);
        await page.mouse.move((a.x + b.x) / 2, a.y, { steps: 4 });
        await expect.poll(() => tooltipText(example), { timeout: 1000 }).toContain("Total");
    }).toPass({ timeout: 15000 });
    for (const n of a.names) expect(await tooltipText(example)).not.toContain(n);
});
