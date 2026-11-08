// Screenshots of the live examples for the start page, in the light and the dark theme: each one is
// the example's element on the built site, drawn by the module's own component. Build and serve the
// site first (docs/development/), then:
//
//   node docs/site/screenshots.mjs [http://127.0.0.1:8765]
//
// The files land in docs/assets/ and are committed; look at them before committing.
import { chromium } from "@playwright/test";
import { fileURLToPath } from "node:url";

const base = process.argv[2] || "http://127.0.0.1:8765";
const out = fileURLToPath(new URL("../assets/", import.meta.url));
// page, example id and file name (without -light/-dark)
const SHOTS = [["/pivot/", "a-report-app-with-loading-views-per-reader-and-roles", "pivot-report"]];

const browser = await chromium.launch();
try {
    for (const scheme of ["light", "dark"]) {
        const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, colorScheme: scheme, deviceScaleFactor: 2 });
        for (const [path, id, name] of SHOTS) {
            await page.goto(base + path);
            const example = page.locator(`[data-example="${id}"]`);
            // the report has drawn its table
            await example.locator(".pk-result td").first().waitFor();
            await example.scrollIntoViewIfNeeded();
            // let fonts and the table's layout settle
            await page.waitForTimeout(500);
            await example.screenshot({ path: `${out}${name}-${scheme}.png`, animations: "disabled" });
            console.log(`${name}-${scheme}.png`);
        }
        await page.close();
    }
} finally {
    await browser.close();
}
