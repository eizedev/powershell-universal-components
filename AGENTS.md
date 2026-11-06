# AGENTS.md

Custom components for PowerShell Universal (PSU) apps, one PowerShell module per component, built
from one repository. Each module is a React bundle plus a PowerShell module that returns the
hashtable PSU renders; see [README.md](README.md).

## Layout

- `modules/<Module>/` - one component module: `Components/` (React/JavaScript), `<Module>.psm1`,
  `<Module>.psd1`, `package.json` + `package-lock.json`, `examples/`, `README.md`, `CHANGELOG.md`.
  A module without `package.json` is PowerShell only (the demo module with its app in `Apps/`).
- `shared/js/` - JavaScript used by several modules (PSU theme bridge, column matching, formats,
  CSV/XLSX export). Compiled into each module's bundle; never a runtime dependency between modules.
- `shared/powershell/` - PowerShell used by several modules (data conversion); copied into each built
  module's `Private/`.
- `build/` - `Build-Module.ps1` and the shared webpack configuration.
- `docs/site/` - the documentation site: `examples.ps1` (code and chart from one source, run with the
  real `New-UDEChart` by `Build-Site.ps1`), the page (`src/main.jsx`, `index.html`) and its own
  `package.json`. A new parameter or chart type gets an example there.
- `tests/js/` (node --test), `tests/browser/` (Playwright: the documentation site in Chromium, Firefox and
  WebKit; `psu.spec.mjs` runs the showcase app on a PSU instance when `PSU_URL` is set),
  `tests/powershell/` (Pester).

## Commands

```bash
npm ci && npm test                                   # JavaScript unit tests (repository root)
npx playwright install chromium firefox webkit && npm run test:browser   # after Build-Site.ps1
PSU_URL=<app url> npm run test:browser -- psu         # the showcase app on a PSU instance, all browsers
pwsh ./build/Build-Module.ps1 -Module PowerShellUniversal.Component.ECharts   # output/<Module>/<Version>
pwsh ./docs/site/Build-Site.ps1                      # output/site/index.html
pwsh ./build/Publish-Module.ps1 -Module <Module> -Version x.y.z   # release check and zip (CI publishes)
pwsh -c 'Invoke-Pester -Path tests/powershell'       # Pester 5 or 6
pwsh -c 'Get-ChildItem modules, shared, build, tests -Recurse -Include *.ps1, *.psm1, *.psd1 | Where-Object FullName -NotMatch "node_modules|public|output" | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Warning, Error }'   # as CI
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
- Docs describe the current state; history belongs in `CHANGELOG.md`, commits and pull requests.
- Conventional Commits; one change per pull request; every module keeps its own `CHANGELOG.md` and
  SemVer `ModuleVersion`.

## Do not

- Commit `node_modules/`, `public/` or `output/`.
- Add a module without the `PowerShellUniversal` tag in its manifest, a README and an example app.
- Put secrets, host names or anything about a particular installation into code, examples or tests.
