const path = require("path");

/*
 * The live examples of the documentation site: charts.js mounts the modules' own React components (the
 * same files PSU loads) into the Zensical pages, with React and ReactDOM bundled here - in PSU they come
 * from the page. Perspective and the pivot report are lazy chunks (perspective.js, pivot.js), loaded only
 * by a page that shows them. Packages resolve from this folder first, then from the modules' own
 * node_modules (Perspective and its CSS loaders, pivotkit), so every package keeps the version pinned in
 * its module's lock file.
 */
const repoRoot = path.resolve(__dirname, "..", "..");
const siteModules = path.join(__dirname, "node_modules");
const perspectiveModules = path.join(repoRoot, "modules", "PowerShellUniversal.Component.Perspective", "node_modules");
const pivotModules = path.join(repoRoot, "modules", "PowerShellUniversal.Component.Pivot", "node_modules");

module.exports = {
    mode: "production",
    devtool: false,
    context: __dirname,
    entry: { charts: path.join(__dirname, "src", "charts.jsx") },
    output: {
        path: process.env.SITE_OUT || path.join(repoRoot, "docs", "assets", "charts"),
        filename: "[name].js",
        chunkFilename: "[name].js",
        clean: true
    },
    module: {
        rules: [
            {
                test: /\.(js|jsx|mjs)$/,
                include: [path.join(__dirname, "src"), path.join(repoRoot, "modules"), path.join(repoRoot, "shared", "js")],
                exclude: /node_modules/,
                use: {
                    loader: "babel-loader",
                    options: {
                        babelrc: false,
                        configFile: false,
                        presets: [
                            ["@babel/preset-env", { targets: "> 0.5%, last 2 Chrome versions, last 2 Firefox versions, last 2 Safari versions, not dead" }],
                            ["@babel/preset-react", { runtime: "classic" }]
                        ]
                    }
                }
            },
            { test: /\.(js|jsx|mjs)$/, resolve: { fullySpecified: false } },
            // Perspective: its WebAssembly inline (Components/engine.js decodes it), its themes as CSS
            { test: /\.wasm$/, type: "asset/inline" },
            { test: /\.css$/, use: ["style-loader", "css-loader"] }
        ]
    },
    experiments: { asyncWebAssembly: false, syncWebAssembly: false },
    resolve: { extensions: [".js", ".jsx", ".mjs"], modules: [siteModules, perspectiveModules, pivotModules, "node_modules"] },
    resolveLoader: { modules: [siteModules, perspectiveModules, "node_modules"] },
    performance: { hints: false }
};
