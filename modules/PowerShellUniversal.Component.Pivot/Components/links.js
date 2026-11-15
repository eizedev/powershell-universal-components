/*
 * Links into a report: the view in the page address when the report mounts. Besides the report's own
 * entry (#pivot-<key>=<view as base64url JSON>, written by this module on every change), it opens
 * pivotkit's share format (#pivot-<key>=1.<deflated view file>), which pivotkit's MCP tool create_link
 * and REST route /views/link write for a source whose `link` is this page and whose `linkKey` is the
 * report's -Id, and "#pivot=1...." from a source without a linkKey. Kept apart from prepare.js, which
 * needs no pivotkit (its unit tests run without the module's packages).
 */
import { linkFragment, readViewLink } from "pivotkit-core/link";
import { OUTSIDE_LIMITS, outsideLimits } from "pivotkit-core";
import { outsideView, parseView, readLinkView } from "./prepare.js";

export { OUTSIDE_LIMITS };

/*
 * The view of a link in `hash` for the report `key` of the data `sourceId`, or undefined
 * (`stored`: the view the tab's sessionStorage keeps for this report, if any):
 * { view, bare } - `bare`: it came from "#pivot=" (the caller removes that entry once the report
 * writes its own). Every view is kept to pivotkit's outside limits; a pivotkit link is read as a view
 * file with them (size, version). A pivotkit link made for other data (its source.id is not this
 * report's) is not loaded: it is said in the console, and the report starts as it would without it.
 */
export function readStartLink(hash, key, sourceId, stored) {
    const own = readLinkView(hash, key);
    if (own) {
        // the tab's own entry - the view its sessionStorage keeps, written by this report before a
        // reload or PSU's light/dark remount - is no input from outside: it keeps the app's limits
        if (stored && JSON.stringify(stored) === JSON.stringify(own)) return { view: own, bare: false };
        const view = outsideView(own, OUTSIDE_LIMITS);
        return view ? { view, bare: false } : undefined;
    }
    for (const [entry, bare] of [[key, false], [null, true]]) {
        // only pivotkit's share format here; the report's own entry was read above
        if (!String(linkFragment(hash, entry) ?? "").startsWith("1.")) continue;
        const read = readViewLink(hash, entry, { limits: outsideLimits() });
        if (!read.view) {
            console.warn("New-UDPivotReport: the link's view could not be read:", read.issues.map((i) => i.message).join("; "));
            continue;
        }
        if (read.src && sourceId && read.src.id !== sourceId) {
            console.warn(`New-UDPivotReport: the link's view was made for other data ("${String(read.src.id).slice(0, 80)}", this report shows "${sourceId.slice(0, 80)}"); it is not loaded.`);
            continue;
        }
        const view = outsideView(parseView(read.view), OUTSIDE_LIMITS);
        if (view) return { view, bare };
    }
    return undefined;
}
