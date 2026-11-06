<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/header-dark.svg">
    <img src="assets/header-light.svg" alt="powershell-universal-components" height="90">
  </picture>
</p>

<p align="center">
  Custom components for <a href="https://devolutions.net/powershell-universal/">PowerShell Universal</a> apps,
  each one a PowerShell module you install on its own - starting with interactive
  <a href="https://echarts.apache.org/">Apache ECharts</a> charts fed straight from SQL, REST and PowerShell.
</p>

| Build | Platform | Project |
| --- | --- | --- |
| [![CI](https://github.com/eizedev/powershell-universal-components/actions/workflows/ci.yml/badge.svg)](https://github.com/eizedev/powershell-universal-components/actions/workflows/ci.yml) [![Docs site](https://github.com/eizedev/powershell-universal-components/actions/workflows/docs.yml/badge.svg)](https://github.com/eizedev/powershell-universal-components/actions/workflows/docs.yml) | ![PowerShell Universal 2026.2-2026.3](https://img.shields.io/badge/PowerShell%20Universal-2026.2%E2%80%932026.3-0078d4) ![PowerShell 7.4+](https://img.shields.io/badge/PowerShell-7.4%2B-5391fe) ![Apache ECharts 6.1](https://img.shields.io/badge/Apache%20ECharts-6.1-aa344d) ![Perspective 5.7](https://img.shields.io/badge/Perspective-5.7-242526) | [![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE) [![Changelog](https://img.shields.io/badge/changelog-keep%20a%20changelog-orange)](modules/PowerShellUniversal.Component.ECharts/CHANGELOG.md) |

<p align="center">
  <img src="assets/screenshot-data-platform-dark.png" alt="Data platform page: coverage heatmap of source systems and assets per number of sources, dark theme" width="49%">
  <img src="assets/screenshot-service-review-light.png" alt="Service review page: KPI matrix of sparklines per customer, light theme" width="49%">
</p>

## Modules

| Module | What it adds |
| --- | --- |
| [PowerShellUniversal.Component.ECharts](modules/PowerShellUniversal.Component.ECharts/README.md) | `New-UDEChart`: 29 chart types, from bars and lines to gantt, rankings, radial bars, network graphs, trees and KPI matrices; zoom, range selection, click events that filter other elements, linked charts, trends with forecast, `-Aggregate`, `-EventColumns`, CSV/Excel/PNG export, full screen, light and dark theme, corporate themes (`-LightTheme`/`-DarkTheme`, CSS variables). |
| [PowerShellUniversal.Component.ECharts.Demo](modules/PowerShellUniversal.Component.ECharts.Demo/README.md) | `New-UDEChartShowcase`: the showcase app of the chart module as a module - 14 pages of examples with generated and public data, to try the charts or copy from. |
| [PowerShellUniversal.Component.Perspective](modules/PowerShellUniversal.Component.Perspective/README.md) | `New-UDPerspective`: [Perspective](https://perspective-dev.github.io/) datagrid, pivot table and WebGL charts in one, which readers group, split, filter and sort themselves; WebAssembly engine for large row counts. |

Tested on PowerShell Universal 2026.2.5 and 2026.3.4 in Chromium, Firefox and WebKit (the engine of
Safari; the Safari app and iOS are not tested).

## Quick start

```powershell
Install-PSResource -Name PowerShellUniversal.Component.ECharts   # or copy the built module into Modules/
```

A first app that runs on any PSU server, without a database or an API: the PowerShell commands of the
server per verb, split into cmdlets and functions. A click on a bar shows a toast. The same app is in
[examples/quickstart.ps1](modules/PowerShellUniversal.Component.ECharts/examples/quickstart.ps1).

```powershell
New-UDApp -Title 'Commands' -Content {
    New-UDCard -Title 'PowerShell commands per verb' -Content {
        $commands = Get-Command -CommandType Cmdlet, Function | Where-Object Verb
        $top = $commands | Group-Object Verb | Sort-Object Count -Descending | Select-Object -First 10 -ExpandProperty Name
        $rows = $commands | Where-Object Verb -In $top | Group-Object Verb, CommandType | ForEach-Object {
            [pscustomobject]@{ Verb = $_.Group[0].Verb; Type = "$($_.Group[0].CommandType)"; Commands = $_.Count }
        } | Sort-Object { [array]::IndexOf($top, $_.Verb) }   # most commands first
        New-UDEChart -Data $rows -Type bar -X Verb -Y Commands -GroupBy Type -Stacked -Height 360px -OnClick {
            Show-UDToast -Message "$($EventData.name): $($EventData.value) $($EventData.seriesName)s"
        }
    }
}
```

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/screenshot-quickstart-dark.png">
    <img src="assets/screenshot-quickstart-light.png" alt="The quick start app: stacked bars of PowerShell commands per verb, cmdlets and functions" width="80%">
  </picture>
</p>

With your own data it is the same call. From SQL Server, for example:

```powershell
$byTeam = Invoke-Sqlcmd -Query 'SELECT Team, Priority, COUNT(*) AS Tickets FROM Tickets GROUP BY Team, Priority'
New-UDEChart -Data $byTeam -Type bar -X Team -Y Tickets -GroupBy Priority -Stacked
```

DataTables, `Invoke-RestMethod` results and PowerShell objects go in as they are; column names are
matched without regard to case. Empty data shows "No data" (`-EmptyText` for your own text), and a
column name that matches no column shows the columns the data has instead of a chart.

## Charts

| Kind | Types |
| --- | --- |
| Comparison and time | `line`, `area`, `step`, `bar` (stacked, normalized, horizontal), `scatter` (bubbles), `bump` (rankings over time), `polar` (bars around a circle), small multiples, sparklines |
| Distribution | `histogram`, `boxplot`, `heatmap`, `calendar` |
| Share | `pie`, `donut` (rose), `funnel`, `treemap`, `sunburst` |
| Finance | `waterfall`, `candlestick` with volume, `gauge`, `radialbar` (progress rings) |
| Operations | `gantt`, trend to a limit (`-Trend Linear -TrendTarget 100`), thresholds, axis breaks for business hours |
| Relations | `sankey`, `graph` (force, circular, layered network paths), `tree`, `chord` |
| Many measures | `radar`, `parallel`, `themeriver`, `matrix` (sparklines per row and column) |

Everything else in Apache ECharts is one `-Options` hashtable away; [what maps to what](modules/PowerShellUniversal.Component.ECharts/docs/gallery.md)
lists the gallery examples.

<p align="center">
  <img src="assets/screenshot-ticket-report-dark.png" alt="Ticket report page: SLA gauge, opened per day against the previous period, lead time histogram with median and SLA, boxplot per team" width="80%">
</p>

## Documentation

- [ECharts module README](modules/PowerShellUniversal.Component.ECharts/README.md): data, chart types, interaction, formats, labels and tooltips, layout, themes, security notes.
- [Demo module README](modules/PowerShellUniversal.Component.ECharts.Demo/README.md): installing the showcase app.
- [Perspective module README](modules/PowerShellUniversal.Component.Perspective/README.md): data and types, the starting view, events, security notes.
- Documentation site: `./docs/site/Build-Site.ps1` builds every example as code next to the chart it draws, plus the parameter reference, into `output/site/`.
- [Showcase app](modules/PowerShellUniversal.Component.ECharts.Demo/Apps/Showcase.ps1) (module PowerShellUniversal.Component.ECharts.Demo): 14 pages - ticket report, finance, managed services, operations, a data platform that combines many source systems, layouts, live data.

## Build

Requires Node.js 22.18 or newer (Babel 8; CI tests the latest 22.x) and PowerShell 7.4+.

```powershell
npm ci; npm test
./build/Build-Module.ps1 -Module <Module>   # any folder in modules/; output/<Module>/<Version>
Invoke-Pester -Path ./tests/powershell
# browser tests (Chromium, Firefox, WebKit) on the docs site, after ./docs/site/Build-Site.ps1
npx playwright install chromium firefox webkit; npm run test:browser
# the showcase app on a PSU instance, in all three browsers
$env:PSU_URL = '<app url>'; npm run test:browser -- psu
```

Releases (tag, PowerShell Gallery, GitHub release): [CONTRIBUTING.md](CONTRIBUTING.md).

Each module is a React component registered with PSU and a PowerShell function returning the hashtable
PSU renders. Code several modules need - the bridge to PSU's light/dark theme, column matching, number
formats, HTML escaping, CSV/Excel export, data conversion - lives once in `shared/` and is compiled into
every module, so component modules never depend on each other at runtime (the demo module requires
the chart module). Contributors and coding agents:
[AGENTS.md](AGENTS.md), [CONTRIBUTING.md](CONTRIBUTING.md); security reports: [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE). Bundled libraries keep their own licenses (Apache ECharts: Apache-2.0, ZRender:
BSD-3-Clause, fflate: MIT, tslib: 0BSD, Perspective and regular-table: Apache-2.0, PSU's universal-dashboard
helper: ISC); the build writes their
texts and notices into each module's `THIRD-PARTY-NOTICES.txt`. Icon, header and social preview in `assets/`
are generated in [eizedev/brand](https://github.com/eizedev/brand) and licensed
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
