// pivotkit's menus in levels (pivotkit-react 0.3.0 and later), shared by the pivot specs: the documentation site
// (site.spec.mjs) and the showcase on a PSU instance (psu-pivot.spec.mjs). A report is the locator of
// its .pk-root; the menus are rendered next to it (on the site inside the example's shadow root), so
// they are found from the page.
import { expect } from "@playwright/test";

// a toolbar menu: its button, or its entry under "More" when the report is too narrow for it
export async function openToolbarMenu(report, id) {
    const page = report.page();
    if (await report.locator(`[data-testid=${id}]`).isVisible()) await report.locator(`[data-testid=${id}]`).click();
    else {
        await report.locator("[data-testid=more]").click();
        await page.locator(`[data-testid=more-${id}]`).click();
    }
}

// the Views menu: a flat first level (This view, Shared views, My views, Share this view); Save as,
// Share and the questions before a delete or a publish open levels of their own. Returns the menu.
export async function openViews(report) {
    const page = report.page();
    await openToolbarMenu(report, "views");
    const menu = page.locator(".pk-popover").last();
    await expect(menu).toContainText("Share");
    return menu;
}

// a topic's level in an open menu in levels: its row on the first level, then the level itself
export async function openLevel(menu, topic) {
    await menu.locator(`[data-testid=topic-${topic}]`).click();
    await expect(menu.locator(`[data-testid=level-${topic}]`)).toBeVisible();
}

// the Save as level of an open Views menu ("Save current view…" before a view is loaded, "Save as…" after)
export async function openSaveAs(menu) {
    await menu.locator("[data-testid=save-as]").click();
    await expect(menu.locator("[data-testid=saved-view-name]")).toBeVisible();
}

// the group "Share this view" of an open Views menu (Copy link, Copy view as JSON, Download view,
// Open view file…): on its first level since pivotkit's Views menu was regrouped
export async function openShare(menu) {
    await expect(menu.locator("[data-testid=topic-share]")).toBeVisible();
    await expect(menu.locator("[data-testid=copy-json]")).toBeVisible();
}

// the menu of a chip (by its text) and, with a topic ("filter", "top", ...), that topic's level
export async function chipMenu(report, chip, topic) {
    await report.locator(`[data-testid='chip-menu-${chip}']`).click();
    const menu = report.page().locator(".pk-chip-menu");
    await expect(menu.locator(".pk-levels")).toBeVisible();
    if (topic) await openLevel(menu, topic);
    return menu;
}
