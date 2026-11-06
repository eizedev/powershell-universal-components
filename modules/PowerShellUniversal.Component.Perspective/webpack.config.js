// Shared configuration of all modules (build/webpack.base.cjs), plus what Perspective needs:
// its plugins import "@finos/perspective" and "@finos/perspective-viewer", whose default entries load
// their WebAssembly from a URL next to the script. PSU serves only the registered bundle, so every
// import is pointed at the "inline" builds that carry the WebAssembly inside the JavaScript.
const path = require("path");
const config = require("../../build/webpack.base.cjs")(__dirname);
const finos = path.join(__dirname, "node_modules", "@finos");

config.resolve.alias = {
    ...(config.resolve.alias || {}),
    "@finos/perspective$": path.join(finos, "perspective", "dist", "esm", "perspective.inline.js"),
    "@finos/perspective-viewer$": path.join(finos, "perspective-viewer", "dist", "esm", "perspective-viewer.inline.js")
};
module.exports = config;
