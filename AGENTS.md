# AGENTS.md

Custom components for PowerShell Universal (PSU) apps, one PowerShell module per component, built
from one repository. Each module is a React bundle plus a PowerShell module that returns the
hashtable PSU renders; see [README.md](README.md).

## Layout

- `modules/<Module>/` - one component module: `Components/` (React/JavaScript), `<Module>.psm1`,
  `<Module>.psd1`, `package.json` + `package-lock.json`, `examples/`, `README.md`, `CHANGELOG.md`.
  A module without `package.json` is PowerShell only (the demo module with its app in `Apps/`).
- `shared/js/` - JavaScript used by several modules (PSU theme bridge, column matching, formats,
  CSV/XLSX export, text contrast on fills). Compiled into each module's bundle; never a runtime dependency between modules.
- `shared/powershell/` - PowerShell used by several modules (data conversion, asset registration);
  copied into each built module's `Private/` by `build/Copy-SharedCode.ps1`, which also writes
  `Private/SHARED.txt`: the content hashes of `shared/` the module was built from.
- `build/` - `Build-Module.ps1` and the shared webpack configuration.
- `docs/` - the documentation site (Zensical, `zensical.toml`, shared design of eizedev/brand): the pages
  as Markdown, the complete documentation of every module. `docs/site/` builds its live parts:
  `examples.ps1` (code and chart from one source, run with the real `New-UDEChart`/`New-UDPerspective`/`New-UDPivotReport`
  by `Build-Site.ps1`, which writes the snippets the pages include with `--8<-- "examples/<id>.md"`),
  `src/charts.jsx` (draws the modules' own components into the pages) and its own `package.json`. A new
  parameter or chart type gets its description on the matching page and an example there.
- `tests/js/` (node --test), `tests/browser/` (Playwright: the documentation site in Chromium, Firefox and
  WebKit; `psu.spec.mjs` runs the showcase app on a PSU instance when `PSU_URL` is set, `psu-pivot.spec.mjs`
  the pivot module's showcase when `PSU_PIVOT_URL` is set, and its template roles against `examples/templates.ps1`
  with two identities when `PSU_PIVOT_AUTH_URL` is set),
  `tests/powershell/` (Pester).

## Commands

```bash
npm ci && npm test                                   # JavaScript unit tests (repository root)
npx playwright install chromium firefox webkit && npm run test:browser   # after building the site
PSU_URL=<app url> npm run test:browser -- tests/browser/psu.spec   # the showcase app on a PSU instance, all browsers
PSU_PIVOT_URL=<app url> npm run test:browser -- tests/browser/psu-pivot.spec   # the pivot module's showcase
# plus PSU_PIVOT_AUTH_URL=<templates.ps1 app with sign-in> PSU_PIVOT_READER_USER/_PASSWORD PSU_PIVOT_ADMIN_USER/_PASSWORD for the role tests
pwsh ./build/Build-Module.ps1 -Module PowerShellUniversal.Component.ECharts   # output/<Module>/<Version>
pwsh ./docs/site/Build-Site.ps1                      # examples, reference, charts script for the site
uv run --with-requirements <eizedev/brand>/docs-site/requirements.txt zensical build   # site/ (copy site.css from there into docs/assets/ first)
pwsh ./build/Publish-Module.ps1 -Module <Module> -Version x.y.z   # release check and zip (CI publishes)
pwsh -c 'Invoke-Pester -Path tests/powershell'       # Pester 5 or 6
pwsh -c 'foreach ($f in "modules", "shared", "build", "tests") { Invoke-ScriptAnalyzer -Path $f -Recurse -Severity Warning, Error | Where-Object ScriptPath -NotMatch "node_modules|public|output" }'   # as CI
```

A change to a component is checked on a PSU test instance in a browser (light and dark theme, a
narrow and a wide window, the events it fires) before it is called done; unit tests do not cover
rendering.

## Rules that matter here

- PSU provides React 18.3.1, ReactDOM and `UniversalDashboard` at runtime: they are webpack externals.
  Never bundle them, never depend on a library that needs React 19 or its own MUI.
- Props reach the browser camelCased by PSU's serializer (`Team` arrives as `team`): match column names
  case-insensitively (`shared/js/columns.js`), never by exact key.
- Data goes through `ConvertTo-PSUComponentData` (DataTable, DBNull, dates). An `[ordered]` dictionary
  arrives in the browser as key/value pairs; return PSCustomObjects.
- PowerShell sends no functions: formats are names resolved in `shared/js/formatters.js`. Never evaluate
  a string from props as code.
- Every package is pinned to an exact version with a lock file; chart libraries have been hijacked on npm
  (`echarts-for-react`, May 2026). Prefer a small own wrapper over a wrapper package.
- Light and dark mode follow `<html data-theme>`; every visible colour must work on both.
- PowerShell: approved verbs, advanced functions with comment-based help, ASCII-only `.ps1`/`.psm1`.
- Behaviour is documented on the site pages in `docs/`; the root README and the module READMEs stay
  short (what it is, install, a quick example, links to the pages).
- Docs describe the current state; history belongs in `CHANGELOG.md`, commits and pull requests.
- Conventional Commits; one change per pull request; every module keeps its own `CHANGELOG.md` and
  SemVer `ModuleVersion`.
- A change in `shared/` reaches every module that uses it only with that module's next release: give
  each of them a CHANGELOG entry, and a patch release for a fix. Code moves into `shared/` only once a
  second module needs it; until then it stays in its module. No common runtime module: each module
  stays installable on its own.
- The theme tokens (`--psu-chart-*`, read by `shared/js/psuTheme.js` and documented on
  `docs/echarts/themes.md`) are the contract between the modules and an app's stylesheet: a token is
  added to the page and the reader together, and renaming or removing one is a breaking change in
  every module.
- CI runs the browser tests in Playwright's container image: a new `@playwright/test` version (also a
  Dependabot pull request) raises the image tag and digest in `ci.yml` with it; `tests/js/ci.test.js` fails
  until both match.
- The demo module requires a minimum chart module version: raise it when the showcase uses a new
  chart feature (a Pester test checks that the version exists).

## Do not

- Commit `node_modules/`, `public/` or `output/`.
- Add a module without the `PowerShellUniversal` tag in its manifest, a README and an example app.
- Put secrets, host names or anything about a particular installation into code, examples or tests.
