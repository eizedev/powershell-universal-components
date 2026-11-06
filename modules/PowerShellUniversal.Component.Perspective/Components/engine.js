/*
 * Perspective's engine and web components. Loaded once per page (see index.js): the custom elements
 * (<perspective-viewer> and its plugins) can be defined only once.
 */
import perspective from "@finos/perspective";
import "@finos/perspective-viewer";
import "@finos/perspective-viewer-datagrid";
import "@finos/perspective-viewer-d3fc";
import "@finos/perspective-viewer/dist/css/themes.css";

export default perspective;
