// Waiting for the charts of a PSU app page, shared by the showcase spec (psu.spec.mjs) and the
// showcase screenshots (docs/site/screenshots.mjs). Each drawn chart is a div with its ECharts instance.
import { expect } from "@playwright/test";

/** The number of charts on the page. */
export const chartCount = (page) => page.evaluate(() => [...document.querySelectorAll("div")].filter((d) => d.echarts).length);

/** Waits until the page has charts and stops adding them (dynamic regions render after the first ones). */
export async function waitForCharts(page) {
    await expect.poll(() => chartCount(page), { timeout: 30000 }).toBeGreaterThan(0);
    let last = -1;
    await expect.poll(async () => {
        const n = await chartCount(page);
        const stable = n === last;
        last = n;
        return stable;
    }, { timeout: 30000, intervals: [1000] }).toBe(true);
}
