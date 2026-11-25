// `npm run lint`: ESLint's recommended rules, which find real errors (undefined names, unreachable
// code, unused variables), and the rules of hooks for the React code. Formatting is left to
// .editorconfig. Function length and complexity are no rules here: they are a ratchet in
// build/growth.js (`npm run growth`), because today's long functions would fail a rule. That guard
// reads SOURCES with LANGUAGE_OPTIONS from this file, so both parse the same code the same way.
import js from "@eslint/js";
import reactHooks from "eslint-plugin-react-hooks";
import globals from "globals";

/** How the JavaScript is parsed: modern ES modules with JSX. */
export const LANGUAGE_OPTIONS = Object.freeze({ ecmaVersion: "latest", sourceType: "module", parserOptions: Object.freeze({ ecmaFeatures: Object.freeze({ jsx: true }) }) });

/** The code each module ships to the browser: its components and what the modules share. */
export const SOURCES = Object.freeze(["modules/*/Components/**/*.{js,jsx}", "shared/js/**/*.js"]);

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
        // a broken rule of hooks fails. A missing effect dependency only warns: the components keep
        // the latest props in a ref for event handlers registered once, which this rule cannot see
        files: BROWSER,
        plugins: { "react-hooks": reactHooks },
        rules: { "react-hooks/rules-of-hooks": "error", "react-hooks/exhaustive-deps": "warn" },
    },
];
