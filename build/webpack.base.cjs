const path = require("path");

/*
 * Webpack configuration shared by every module: one bundle index.<hash>.bundle.js, React, ReactDOM
 * and UniversalDashboard taken from PSU at runtime (React 18.3.1 in PSU 2026.3.4; bundling them again
 * breaks hooks), and the repository's shared/js compiled into each bundle, so every module installs
 * on its own.
 *
 * Babel options are inline (not .babelrc): a .babelrc only applies inside its own package, and the
 * shared code lives outside the module folder.
 */
module.exports = function config(moduleDir) {
    const repoRoot = path.resolve(__dirname, "..");
    return {
        mode: "production",
        devtool: "source-map",
        context: moduleDir,
        entry: { index: path.join(moduleDir, "Components", "index.js") },
        output: {
            path: path.join(moduleDir, "public"),
            filename: "[name].[contenthash].bundle.js",
            libraryTarget: "umd",
            clean: true
        },
        module: {
            rules: [
                {
                    test: /\.(js|jsx|mjs)$/,
                    include: [path.join(moduleDir, "Components"), path.join(repoRoot, "shared", "js")],
                    use: {
                        loader: "babel-loader",
                        options: {
                            babelrc: false,
                            configFile: false,
                            presets: [
                                ["@babel/preset-env", { targets: "> 0.5%, last 2 Chrome versions, last 2 Firefox versions, last 2 Safari versions, not dead" }],
                                "@babel/preset-react"
                            ]
                        }
                    }
                },
                { test: /\.css$/, use: ["style-loader", "css-loader"] },
                // ESM folders ("type": "module", for node --test) would require file extensions in
                // every import; webpack resolves them like in CommonJS
                { test: /\.(js|jsx|mjs)$/, resolve: { fullySpecified: false } }
            ]
        },
        resolve: {
            extensions: [".js", ".jsx", ".mjs"],
            // shared/js imports packages (fflate) from the module's node_modules
            modules: [path.join(moduleDir, "node_modules"), "node_modules"]
        },
        resolveLoader: { modules: [path.join(moduleDir, "node_modules"), "node_modules"] },
        externals: {
            UniversalDashboard: "UniversalDashboard",
            react: "react",
            "react-dom": "reactdom"
        },
        performance: { hints: false }
    };
};
