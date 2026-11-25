// The JavaScript each module ships and how it is parsed, defined once for `npm run lint`
// (eslint.config.js) and the javascript growth guard (build/growth.js). No imports: the growth guards
// load it without ESLint's plugins.

/** How the JavaScript is parsed: modern ES modules with JSX. */
export const LANGUAGE_OPTIONS = Object.freeze({ ecmaVersion: "latest", sourceType: "module", parserOptions: Object.freeze({ ecmaFeatures: Object.freeze({ jsx: true }) }) });

/** The code each module ships to the browser: its components and what the modules share. .jscpd.json names the same folders. */
export const SOURCES = Object.freeze(["modules/*/Components/**/*.{js,jsx}", "shared/js/**/*.js"]);
