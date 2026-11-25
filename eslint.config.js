// `npm run lint`: ESLint's recommended rules, which find real errors (undefined names, unreachable
// code, unused variables), and the React hooks rules for the React code. Formatting is left to
// .editorconfig. Function length and complexity are no rules here: they are a ratchet in
// build/growth.js (`npm run growth`), because today's long functions would fail a rule. Both read the
// same code the same way (build/javascript-sources.js).
import js from "@eslint/js";
import reactHooks from "eslint-plugin-react-hooks";
import globals from "globals";
import { LANGUAGE_OPTIONS, SOURCES } from "./build/javascript-sources.js";

/** The code that runs in a browser page: the modules' components and the site's drawing code. */
const BROWSER = [...SOURCES, "docs/site/src/**"];

export default [
    // what is installed or generated (.gitignore)
    { ignores: ["**/node_modules/", "**/dist/", "output/", "site/", "docs/site/generated/", "docs/assets/charts/", "docs/assets/images/", "test-results/", "playwright-report/"] },
    js.configs.recommended,
    {
        files: ["**/*.{js,jsx,mjs}"],
        languageOptions: LANGUAGE_OPTIONS,
        rules: { "no-unused-vars": ["error", { argsIgnorePattern: "^_", varsIgnorePattern: "^React$" }] },
    },
    {
        // the webpack configurations are CommonJS
        files: ["**/*.cjs", "modules/*/webpack.config.js"],
        languageOptions: { sourceType: "commonjs", globals: { ...globals.node } },
    },
    {
        // build scripts and unit tests run in Node
        files: ["build/**", "tests/js/**", "playwright.config.mjs"],
        languageOptions: { globals: { ...globals.node } },
    },
    {
        // Playwright code: Node code that also hands functions to the page
        files: ["tests/browser/**", "docs/site/*.mjs"],
        languageOptions: { globals: { ...globals.node, ...globals.browser } },
    },
    {
        // PSU provides UniversalDashboard on the page; webpack provides require and the pivot
        // module's DefinePlugin the import worker's address (its webpack.config.js)
        files: BROWSER,
        languageOptions: { globals: { ...globals.browser, UniversalDashboard: "readonly", require: "readonly", __PIVOT_IMPORT_WORKER__: "readonly" } },
    },
    {
        // the plugin's recommended rules for React 18 code, with a missing effect dependency as an
        // error too: the rules of hooks and the React Compiler's checks (no ref read or written during
        // render, no setState in an effect body). Props that handlers registered once need are kept in a
        // ref written in an effect (shared/js/useLatest.js); a dependency left out on purpose is
        // disabled on its line with the reason
        files: BROWSER,
        plugins: { "react-hooks": reactHooks },
        rules: { ...reactHooks.configs["recommended-latest"].rules, "react-hooks/exhaustive-deps": "error" },
    },
];
