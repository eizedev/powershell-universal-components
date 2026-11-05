const path = require("path");

/*
 * The documentation site renders the modules' own React components (the same files PSU loads), with
 * React and ReactDOM bundled here - in PSU they come from the page. Packages resolve from this
 * folder first, so the site builds without installing the modules.
 */
const repoRoot = path.resolve(__dirname, "..", "..");
const siteModules = path.join(__dirname, "node_modules");

module.exports = {
    mode: "production",
    devtool: false,
    context: __dirname,
    entry: { site: path.join(__dirname, "src", "main.jsx") },
    output: {
        path: process.env.SITE_OUT || path.join(repoRoot, "output", "site"),
        filename: "[name].js"
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
            { test: /\.(js|jsx|mjs)$/, resolve: { fullySpecified: false } }
        ]
    },
    resolve: { extensions: [".js", ".jsx", ".mjs"], modules: [siteModules, "node_modules"] },
    resolveLoader: { modules: [siteModules, "node_modules"] },
    performance: { hints: false }
};
