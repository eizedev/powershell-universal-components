---
title: Overview
description: Custom components for PowerShell Universal apps - interactive Apache ECharts charts, a Perspective datagrid, pivot and charts, and a pivot report builder, fed straight from SQL, REST and PowerShell objects.
---

# Components for PowerShell Universal apps

Custom components for [PowerShell Universal](https://devolutions.net/powershell-universal/) (PSU)
apps, each one a PowerShell module you install on its own. Pass the data as it comes - a DataTable
from SQL, objects from `Invoke-RestMethod` or any PowerShell command - name the columns, and the
component is drawn in the browser.

<div class="cards" markdown>

- [**ECharts**](echarts/index.md)<br>`New-UDEChart`: interactive charts, from bars and lines to gantt and network graphs.
- [**Perspective**](perspective/index.md)<br>`New-UDPerspective`: a datagrid, pivot table and WebGL charts that readers rearrange.
- [**Pivot**](pivot/index.md)<br>`New-UDPivotReport`: a pivot report builder with table, chart, views and Excel export.

</div>

Every chart on these pages is drawn by the module's own component, with the props that the PowerShell
next to it returns; events that would run a script block on the server show their `$EventData` instead.
Start with [Getting started](getting-started.md).

## ECharts

`New-UDEChart` draws 29 chart types on [Apache ECharts](https://echarts.apache.org/), from bars and
lines to gantt, rankings, radial bars, network graphs, trees and KPI matrices; zoom, range selection,
click events that filter other elements, linked charts, trends with forecast, CSV/Excel/PNG export,
full screen, light and dark theme, corporate themes.

```powershell
Install-PSResource -Name PowerShellUniversal.Component.ECharts
```

In the PowerShell Gallery: [PowerShellUniversal.Component.ECharts](https://www.powershellgallery.com/packages/PowerShellUniversal.Component.ECharts).

![ECharts in the light theme: monthly mean temperature of six cities in 2024 and 2025 as lines, with a zoom slider](assets/echarts-weather-light.png#only-light)
![ECharts in the dark theme: monthly mean temperature of six cities in 2024 and 2025 as lines, with a zoom slider](assets/echarts-weather-dark.png#only-dark)

[ECharts overview](echarts/index.md){ .md-button .md-button--primary }
[Showcase app (demo)](demo.md){ .md-button title="PowerShellUniversal.Component.ECharts.Demo: 14 pages of New-UDEChart examples" }

## Perspective

`New-UDPerspective` puts the [Perspective](https://perspective-dev.github.io/) datagrid, pivot table
and WebGL charts in one into an app; readers group, split, filter and sort themselves, and a
WebAssembly engine keeps large row counts fast.

```powershell
Install-PSResource -Name PowerShellUniversal.Component.Perspective
```

In the PowerShell Gallery: [PowerShellUniversal.Component.Perspective](https://www.powershellgallery.com/packages/PowerShellUniversal.Component.Perspective).

![The Perspective viewer in the light theme: a bar chart of the mean temperature of six cities, with the toolbar Edit view, Table and Chart](assets/perspective-weather-light.png#only-light)
![The Perspective viewer in the dark theme: a bar chart of the mean temperature of six cities, with the toolbar Edit view, Table and Chart](assets/perspective-weather-dark.png#only-dark)

[Perspective overview](perspective/index.md){ .md-button .md-button--primary }
[Using the viewer](perspective/using.md){ .md-button }

## Pivot

`New-UDPivotReport` is a pivot report builder on [pivotkit](https://www.npmjs.com/package/pivotkit-react):
readers drag fields into rows, columns, values and filters and get a table or a chart, with date
grouping, drill-down to the source rows, shared views and views readers keep (roles decide who
publishes), undo, Excel, CSV, PNG, SVG and HTML export and print, and readers' own CSV, JSON and Excel files read in the
browser ([`-AllowImport`](pivot/import.md)); English and German; themed from the same stylesheet as
the charts. `Invoke-UDPivotReport` renders the same views into Excel, HTML, CSV, JSON or SVG files
from endpoints and schedules, without a browser, or into a link that expires from a pivotkit-server
([Reports without a browser](pivot/reports.md)).

```powershell
Install-PSResource -Name PowerShellUniversal.Component.Pivot
New-UDPivotReport -Id 'python' -Data (Invoke-RestMethod 'https://endoflife.date/api/python.json')
```

In the PowerShell Gallery: [PowerShellUniversal.Component.Pivot](https://www.powershellgallery.com/packages/PowerShellUniversal.Component.Pivot).

![The pivot report in the light theme: mean temperature per month and city of six cities as a colour scale, with the tabs Table, Chart and Both](assets/pivot-weather-light.png#only-light)
![The pivot report in the dark theme: mean temperature per month and city of six cities as a colour scale, with the tabs Table, Chart and Both](assets/pivot-weather-dark.png#only-dark)

<small>The pictures on this page: weather data by [Open-Meteo.com](https://open-meteo.com/), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), with modified Copernicus Climate Change Service information ([sources and licences](https://github.com/eizedev/powershell-universal-components/blob/HEAD/docs/site/data/SOURCES.md)).</small>

[Pivot overview](pivot/index.md){ .md-button .md-button--primary }
[Templates, view files and roles](pivot/templates.md){ .md-button }
[Showcase app (demo)](pivot/demo.md){ .md-button title="PowerShellUniversal.Component.Pivot.Demo: weather, the examples, your own files, reports as files, rows from a server and a ticket report" }

## Requirements

- PowerShell Universal 2026.2 or 2026.3, with PowerShell 7.4 or later.
- Tested on PowerShell Universal 2026.2.5 and 2026.3.4.
- Tested in Chromium, Firefox and WebKit, the engine of Safari. The Safari app and iOS are not tested.

## Questions and stability

The modules are 0.x. A minor release can break things. Read the module's `CHANGELOG.md` before
you update. [Versioning](versioning.md) lists what the modules treat as public interface.

Ask questions and share ideas in [GitHub Discussions](https://github.com/eizedev/powershell-universal-components/discussions). Bugs go into
[issues](https://github.com/eizedev/powershell-universal-components/issues). Each release of a component module is announced in Discussions too.

## License

MIT. The bundled libraries keep their own licenses: Apache ECharts (Apache-2.0), ZRender
(BSD-3-Clause), fflate (MIT), tslib (0BSD), Perspective and regular-table (Apache-2.0), pivotkit and dnd-kit (MIT), PSU's
universal-dashboard helper (ISC), and, for two small helpers of Perspective's WebAssembly packaging
(`buffer-pipe`, `leb128`), MPL-2.0. The build writes their texts into each module's
`THIRD-PARTY-NOTICES.txt`. Icon and header are made in [eizedev/brand](https://github.com/eizedev/brand)
and licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
