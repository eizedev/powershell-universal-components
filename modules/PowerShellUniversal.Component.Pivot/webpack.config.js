// Shared configuration of all modules (build/webpack.base.cjs), with two changes for pivotkit-react:
//
// 1. It loads Apache ECharts, the XLSX export, the link codec and the import UI with import() on first
//    use. PSU serves only registered files, so every chunk is merged into the one bundle; the imports
//    still run only when a chart, an export, a link or a file to load is first needed.
// 2. -AllowImport reads CSV and JSON files in a Web Worker, so a large file does not block the page:
//    pivotkit-react/import-worker is built as a second file of its own (import-worker.<hash>.js, with
//    its readers merged in). The module registers it with PSU like the bundle; the bundle finds its
//    address next to its own (Components/importWorker.js). Where it cannot start (a
//    Content-Security-Policy without worker-src for it), pivotkit reads the file on the page.
const fs = require("fs");
const path = require("path");
const webpack = require("webpack");
const base = require("../../build/webpack.base.cjs");

const WORKER_PATTERN = /^import-worker\.[0-9a-f]+\.js$/;
const oneChunk = () => new webpack.optimize.LimitChunkCountPlugin({ maxChunks: 1 });

const worker = base(__dirname);
worker.name = "worker";
worker.entry = { "import-worker": require.resolve("pivotkit-react/import-worker") };
worker.target = "webworker";
// built first, into the same folder: it removes only its own old files
worker.output = { ...worker.output, filename: "[name].[contenthash].js", libraryTarget: undefined, clean: { keep: (file) => !WORKER_PATTERN.test(file) } };
worker.externals = {};
worker.plugins = [oneChunk()];

const main = base(__dirname);
main.name = "main";
main.dependencies = ["worker"];
main.output = { ...main.output, clean: { keep: (file) => WORKER_PATTERN.test(file) } };
main.plugins = [
    ...(main.plugins || []),
    oneChunk(),
    // the worker's file name, read once the worker is built (its content hash changes with pivotkit)
    new webpack.DefinePlugin({
        __PIVOT_IMPORT_WORKER__: webpack.DefinePlugin.runtimeValue(() => {
            const names = fs.readdirSync(main.output.path).filter((f) => WORKER_PATTERN.test(f));
            if (names.length !== 1) throw new Error(`expected one import worker in ${main.output.path}, found ${names.length}`);
            return JSON.stringify(names[0]);
        }, true)
    })
];

module.exports = [worker, main];
