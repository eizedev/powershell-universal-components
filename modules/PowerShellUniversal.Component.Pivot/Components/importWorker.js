/*
 * The import worker of -AllowImport (webpack.config.js builds pivotkit-react/import-worker into a file
 * of its own, import-worker.<hash>.js). PSU serves a module's registered files under the address of
 * its bundle (/api/internal/javascript/<file>?dashboardId=<n>; without the query PSU answers 500), so
 * the worker's address is the bundle's own with the file name replaced. Pure, apart from reading the
 * page's scripts once.
 */

// the bundle as PSU serves it: index.<hash>.bundle.js
const BUNDLE_PATTERN = /\/index\.[0-9a-f]+\.bundle\.js$/;

/**
 * The worker's address next to the bundle's, or null when the bundle's address is unknown.
 * @param {string | null | undefined} bundleUrl  the src of the bundle's script element
 * @param {string} workerFile  import-worker.<hash>.js
 */
export function workerUrlOf(bundleUrl, workerFile) {
    if (typeof bundleUrl !== "string" || !workerFile) return null;
    let url;
    try {
        url = new URL(bundleUrl);
    } catch {
        return null;
    }
    if (!BUNDLE_PATTERN.test(url.pathname)) return null;
    url.pathname = url.pathname.replace(BUNDLE_PATTERN, `/${workerFile}`);
    return url.href;
}

/**
 * The src of the bundle's script element: document.currentScript while the bundle runs, else a
 * module bundle of the page (PSU serves every module's registered files under the same address and
 * query, and runs a bundle again for every component, when currentScript is another one).
 * @param {Document | undefined} doc
 */
export function bundleScriptOf(doc) {
    if (!doc) return null;
    const isBundle = (src) => {
        try {
            return typeof src === "string" && BUNDLE_PATTERN.test(new URL(src).pathname);
        } catch {
            return false;
        }
    };
    if (doc.currentScript && isBundle(doc.currentScript.src)) return doc.currentScript.src;
    return [...(doc.scripts || [])].map((s) => s.src).find(isBundle) || null;
}

/**
 * pivotkit's importWorker: a function that starts the worker, or undefined where there is no address
 * or no Worker. A worker that does not start (a Content-Security-Policy) leaves the read to the page.
 * @param {string | null} url
 */
export function importWorkerOf(url) {
    if (!url || typeof Worker === "undefined") return undefined;
    return () => new Worker(url, { name: "pivot-import" });
}
