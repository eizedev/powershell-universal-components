# PowerShell Universal components

Custom components for [PowerShell Universal](https://devolutions.net/powershell-universal/) apps,
each one a PowerShell module you install on its own.

| Module | What it adds |
| --- | --- |
| [PowerShellUniversal.Component.ECharts](modules/PowerShellUniversal.Component.ECharts/README.md) | `New-UDEChart`: interactive [Apache ECharts](https://echarts.apache.org/) charts - 25 chart types, zoom, range selection, click events, linked charts, axis breaks, small multiples, light and dark theme, CSV and Excel export - fed straight from SQL DataTables, REST results and PowerShell objects. |

## Install

From the PowerShell Gallery (once published), in PSU under Platform > Modules, or:

```powershell
Install-PSResource -Name PowerShellUniversal.Component.ECharts
```

Or copy a built module (`output/<Module>/<Version>/`) into the `Modules/` folder of your PSU repository.
PSU adds that folder to `$env:PSModulePath`, so apps find the module without installing it.

## Build

Requires Node.js 20+ and PowerShell 7.4+.

```powershell
npm ci; npm test                                                  # JavaScript tests
./build/Build-Module.ps1 -Module PowerShellUniversal.Component.ECharts
Invoke-Pester -Path ./tests/powershell
```

The build writes `output/<Module>/<Version>/` with the bundle, the module, its manifest and the shared
PowerShell code.

## How it is put together

Each module is a React component registered with PSU (`UniversalDashboard.register`) and a PowerShell
function returning the hashtable PSU renders. Code several modules need - the bridge to PSU's light/dark
theme, column matching, number formats, CSV/Excel export, data conversion - lives once in `shared/` and is
compiled into every module, so modules never depend on each other at runtime. Details for contributors and
coding agents: [AGENTS.md](AGENTS.md), [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). Bundled libraries keep their own licenses (Apache ECharts: Apache-2.0; listed in each
bundle's `.LICENSE.txt`).
