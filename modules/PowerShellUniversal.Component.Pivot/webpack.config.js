// Shared configuration of all modules (build/webpack.base.cjs), with one change for pivotkit-react:
// it loads Apache ECharts, the XLSX export and the link codec with import() on first use. PSU serves
// only the registered bundle, not chunks next to it, so every chunk is merged into the one bundle; the
// imports still run only when a chart, an export or a link is first needed.
const webpack = require("webpack");
const config = require("../../build/webpack.base.cjs")(__dirname);

config.plugins = [...(config.plugins || []), new webpack.optimize.LimitChunkCountPlugin({ maxChunks: 1 })];
module.exports = config;
