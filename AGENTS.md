# AGENTS.md

Custom components for PowerShell Universal (PSU) apps, one PowerShell module per component, built
from one repository. Each module is a React bundle plus a PowerShell module that returns the
hashtable PSU renders; see [README.md](README.md).

## How we build

The modules form one product. Judge code, tests, docs and these rules as a whole.

- **Look at the whole.** Before and after a change, read the whole files, pages and flows it touches,
  as the people who use, run, and build on the modules. A change is done when the product is better.
- **Shape what exists.** Edit, merge, move or delete until the result reads as if written today.
  Adding is the last option.
- **One place per fact.** A rule, a fact or a piece of logic lives in one place. Others link or import it.
- **Small units.** A module's exported functions live one per file in `Public/`, helpers in `Private/`.
  The `.psm1` only loads them. A function does one job. C# goes into `.cs` files, never into here-strings.
  When a second place needs something, build the shared piece first.
- **Common practice first.** Write PowerShell, React and JavaScript the way their communities do.
  A deviation names its reason.
- **Say what does not fit.** Duplication, a growing function or a page nobody can read: name it in the
  pull request and propose the fix.

## Layout

- `modules/<Module>/` - one component module: `Components/` (React/JavaScript), `<Module>.psm1`,
  `<Module>.psd1`, `package.json` + `package-lock.json`, `examples/`, `README.md`, `CHANGELOG.md`.
  A split module (Pivot so far) has `Public/` and `Private/` with one function per file, its
  `$Script:` limits and state in `Private/Settings/` (loaded after the functions) and C# in `Private/*.cs`.
  A module without `package.json` is PowerShell only (the demo modules with their app in `Apps/`).
  A module's `Build.psd1` names files from elsewhere in the repository the build copies into it (the
  pivot demo carries the site's examples and data snapshots and the pivot showcase), so each is defined once.
- `shared/js/` - JavaScript used by several modules (PSU theme bridge, column matching, formats,
  CSV/XLSX export, text contrast on fills, the answer to `Get-UDElement` in `elementState.js`). Compiled into each module's bundle; never a runtime dependency between modules.
- `shared/powershell/` - PowerShell used by several modules (data conversion, asset registration);
  copied into each built module's `Private/` by `build/Copy-SharedCode.ps1`, which also writes
  `Private/SHARED.txt`: the content hashes of `shared/` the module was built from.
- `build/` - `Build-Module.ps1`, the shared webpack configuration and the growth guards in `growth.js`.
  Webpack writes a module's bundle to `modules/<Module>/dist/`; `Build-Module.ps1` copies it into `output/`.
- `docs/` - the documentation site (Zensical, `zensical.toml`, shared design of eizedev/brand): the pages
  as Markdown, the complete documentation of every module. `docs/site/` builds its live parts:
  `examples.ps1` (code and chart from one source, run with the real `New-UDEChart`/`New-UDPerspective`/`New-UDPivotReport`
  by `Build-Site.ps1`, which writes the snippets the pages include with `--8<-- "examples/<id>.md"`),
  `src/charts.jsx` (draws the modules' own components into the pages) and its own `package.json`. A new
  parameter or chart type belongs on the page that owns its topic, with an example there. Zensical's
  `llmstxt` plugin writes `llms.txt`, `llms-full.txt` and a Markdown file per page from the pages in the
  sections of `[project.plugins.llmstxt.sections]` (every page in exactly one, `tests/js/llms-sections.test.js`).
- `tests/js/` (node --test), `tests/browser/` (Playwright: the documentation site in three browsers, and
  the showcase apps on a PSU instance when their address is set; which spec needs which variable:
  [docs/development](docs/development/index.md#browser-tests-on-psu)), `tests/powershell/` (Pester).

## Commands

```bash
npm ci && npm test                                   # JavaScript unit tests (repository root)
npm run growth                                       # the growth guards, below
npx playwright install chromium firefox webkit && npm run test:browser   # after building the site
# browser tests against showcase apps on a PSU instance: docs/development/index.md#browser-tests-on-psu
pwsh ./build/Build-Module.ps1 -Module PowerShellUniversal.Component.ECharts   # output/<Module>/<Version>
pwsh ./docs/site/Build-Site.ps1                      # examples, reference, charts script for the site
uv run --with-requirements <eizedev/brand>/docs-site/requirements.txt zensical build   # site/ (copy site.css from there into docs/assets/ first)
pwsh ./build/Publish-Module.ps1 -Module <Module> -Version x.y.z   # release check and zip (CI publishes)
pwsh -c 'Invoke-Pester -Path tests/powershell'       # Pester 5 or 6
pwsh -c 'foreach ($f in "modules", "shared", "build", "tests") { Invoke-ScriptAnalyzer -Path $f -Recurse -Severity Warning, Error | Where-Object ScriptPath -NotMatch "node_modules|dist|output" }'   # as CI
```

`npm run growth` runs `build/growth.js`. It keeps code, tests, and docs from growing by appending.
The limits and their reasons are in that file. Each guard is a CI step:

- `powershell`: code lines per `.ps1`/`.psm1` file and per function, read with the PowerShell parser.
- `javascript`: lines and complexity per function in `modules/*/Components` and `shared/js`, read with ESLint.
- `duplication`: copied JavaScript in the same folders, over the threshold in `.jscpd.json`, found with jscpd.
- `docs`: lines per docs page and README by kind of page, and of all of them together.

The offenders over a limit are in `build/growth-baseline.json`. A new or grown one fails. A smaller one
fails until `node build/growth.js --update` lowers the baseline in the same pull request.

A change to a component is checked on a PSU test instance in a browser (light and dark theme, a
narrow and a wide window, the events it fires) before it is called done; unit tests do not cover
rendering.

## Rules that matter here

- PSU provides React 18.3.1, ReactDOM and `UniversalDashboard` at runtime: they are webpack externals.
  Never bundle them, never depend on a library that needs React 19 or its own MUI.
- PSU serves only the files a module registers, at `/api/internal/javascript/<file>?dashboardId=<n>`
  (500 without the query): lazy chunks are merged into the one bundle. A Web Worker is a file of its
  own next to the bundle, found from the bundle's script address (the pivot module's import worker,
  `Components/importWorker.js`); a page where it cannot start must still work without it.
- Props reach the browser camelCased by PSU's serializer (`Team` arrives as `team`): match column names
  case-insensitively (`shared/js/columns.js`), never by exact key.
- Data goes through `ConvertTo-PSUComponentData` (DataTable, DBNull, dates). An `[ordered]` dictionary
  arrives in the browser as key/value pairs; return PSCustomObjects.
- PowerShell sends no functions: formats are names resolved in `shared/js/formatters.js`. Never evaluate
  a string from props as code.
- Every package is pinned to an exact version with a lock file; chart libraries have been hijacked on npm
  (`echarts-for-react`, May 2026). Prefer a small own wrapper over a wrapper package.
- Light and dark mode follow `<html data-theme>`; every visible colour must work on both.
  The pivot module's `psu.css` writes its dark values for pivotkit's `[data-pk-theme="dark"]`, never for
  the page's `data-theme` (an export reads each theme from the report itself), and every visual value there is a token
  (literals only in the `--psu-default-*` blocks; `tests/js/pivot.test.js` checks both).
- PowerShell: approved verbs, advanced functions with comment-based help, ASCII-only `.ps1`/`.psm1`.
  In the pivot module:
  - A helper that needs many of a public command's parameters gets its `$PSBoundParameters` as `-Bound`.
    `tests/powershell/PivotModule.Tests.ps1` checks that every literal key a helper reads is a parameter
    of a public command.
  - A `catch` around an HTTP request or the reading of its answer calls
    `Remove-UDPivotErrorRecord -ErrorRecord $_` first, so no request, header or token stays in `$Error`.
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
- A demo module requires a minimum version of its component module: raise it when the showcase uses a
  new feature (a Pester test checks that the version exists).

## Do not

- Commit `node_modules/`, `dist/` or `output/`.
- Add a module without the `PowerShellUniversal` tag in its manifest, a README and an example app.
- Put secrets, host names or anything about a particular installation into code, examples or tests.
