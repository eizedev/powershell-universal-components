// Shared configuration of all modules (build/webpack.base.cjs), with two changes for pivotkit-react:
// - It loads Apache ECharts and the XLSX export with import() on first use. PSU serves only the
//   registered bundle, not chunks next to it, so every chunk is merged into the one bundle; the
//   imports still run only when a chart or an export is first needed.
// - WORKAROUND (pivotkit-react 0.1.0): its namespace imports of echarts/charts, echarts/components and
//   echarts/renderers would bundle every chart of ECharts; they resolve to Components/echarts-parts.js,
//   which exports only the parts the report uses.
const path = require("path");
const webpack = require("webpack");
const config = require("../../build/webpack.base.cjs")(__dirname);

const parts = path.join(__dirname, "Components", "echarts-parts.js");
config.resolve.alias = { ...(config.resolve.alias || {}), "echarts/charts$": parts, "echarts/components$": parts, "echarts/renderers$": parts };
config.plugins = [...(config.plugins || []), new webpack.optimize.LimitChunkCountPlugin({ maxChunks: 1 })];
module.exports = config;
