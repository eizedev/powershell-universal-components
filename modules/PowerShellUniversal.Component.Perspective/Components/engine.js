/*
 * Perspective's engine and web components. Loaded once per page (see index.js): the custom elements
 * (<perspective-viewer> and its plugins) can be defined only once, and init() registers the
 * WebAssembly binaries page-wide.
 */
import perspective from "@perspective-dev/client";
import perspective_viewer from "@perspective-dev/viewer";
import "@perspective-dev/viewer-datagrid";
import "@perspective-dev/viewer-charts";
import "@perspective-dev/viewer/dist/css/themes.css";
// data: URLs (webpack asset/inline, see webpack.config.js). Only the 32-bit engine: the Memory64 build
// would add 2.6 MB for heaps above 4 GB, far beyond what a PSU app sends to a browser.
import SERVER_WASM from "@perspective-dev/server/dist/wasm/perspective-server.wasm";
import VIEWER_WASM from "@perspective-dev/viewer/dist/wasm/perspective-viewer.wasm";

// decoded here rather than fetch()ed, so a Content-Security-Policy without data: in connect-src
// does not block it
function bytes(dataUrl) {
    const binary = atob(dataUrl.slice(dataUrl.indexOf(",") + 1));
    const out = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) out[i] = binary.charCodeAt(i);
    return out;
}

await perspective_viewer.init({ server: () => Promise.resolve(bytes(SERVER_WASM)), viewer: () => Promise.resolve(bytes(VIEWER_WASM)) });

export default perspective;
