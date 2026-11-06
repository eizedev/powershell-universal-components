// Shared configuration of all modules (build/webpack.base.cjs), plus what Perspective needs: its
// WebAssembly binaries. PSU serves only the registered bundle, so the binaries are inlined into it as
// data: URLs (asset/inline) and handed to Perspective's init() in Components/engine.js - Perspective's
// bundling guide, "Inline builds with a bundler". Webpack's own WebAssembly handling stays off.
const config = require("../../build/webpack.base.cjs")(__dirname);

config.module.rules.push({ test: /\.wasm$/, type: "asset/inline" });
config.experiments = { ...(config.experiments || {}), asyncWebAssembly: false, syncWebAssembly: false };
module.exports = config;
