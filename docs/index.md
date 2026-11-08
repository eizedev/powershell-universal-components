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

![The quick start app in the light theme: stacked bars of PowerShell commands per verb, cmdlets and functions](assets/images/screenshot-quickstart-light.png#only-light)
![The quick start app in the dark theme: stacked bars of PowerShell commands per verb, cmdlets and functions](assets/images/screenshot-quickstart-dark.png#only-dark)

[ECharts overview](echarts/index.md){ .md-button .md-button--primary }
[Showcase app (demo)](demo.md){ .md-button title="PowerShellUniversal.Component.ECharts.Demo: 14 pages of New-UDEChart examples" }

## Perspective

`New-UDPerspective` puts the [Perspective](https://perspective-dev.github.io/) datagrid, pivot table
and WebGL charts in one into an app; readers group, split, filter and sort themselves, and a
WebAssembly engine keeps large row counts fast.

```powershell
Install-PSResource -Name PowerShellUniversal.Component.Perspective
```

![The Perspective viewer in the light theme with its toolbar: Edit view, Table and Chart](assets/perspective-viewer-1-light.png#only-light)
![The Perspective viewer in the dark theme with its toolbar: Edit view, Table and Chart](assets/perspective-viewer-1-dark.png#only-dark)

[Perspective overview](perspective/index.md){ .md-button .md-button--primary }
[Using the viewer](perspective/using.md){ .md-button }

## Pivot

`New-UDPivotReport` is a pivot report builder on [pivotkit](https://www.npmjs.com/package/pivotkit-react):
readers drag fields into rows, columns, values and filters and get a table or a chart, with date
grouping, drill-down to the source rows, shared views and views readers keep (roles decide who
publishes), undo and Excel, CSV and PNG export; English and German; themed from the same stylesheet as
the charts.

```powershell
Install-PSResource -Name PowerShellUniversal.Component.Pivot
New-UDPivotReport -Id 'python' -Data (Invoke-RestMethod 'https://endoflife.date/api/python.json')
```

![The pivot report in the light theme: release cycles of nine products from endoflife.date per product and LTS, with the field list and the admin panel](assets/pivot-report-light.png#only-light)
![The pivot report in the dark theme: release cycles of nine products from endoflife.date per product and LTS, with the field list and the admin panel](assets/pivot-report-dark.png#only-dark)

<small>Release data by [endoflife.date](https://endoflife.date/), MIT licence, Copyright 2020 endoflife.date contributors ([sources and licence](https://github.com/eizedev/powershell-universal-components/blob/HEAD/docs/site/data/SOURCES.md)).</small>

[Pivot overview](pivot/index.md){ .md-button .md-button--primary }
[Templates, view files and roles](pivot/templates.md){ .md-button }

## Requirements

PowerShell Universal 2026 (PowerShell 7.4 or newer). Tested on PSU 2026.2.5 and 2026.3.4 in Chromium,
Firefox and WebKit (the engine of Safari; the Safari app and iOS are not tested).

## License

MIT. The bundled libraries keep their own licenses: Apache ECharts (Apache-2.0), ZRender
(BSD-3-Clause), fflate (MIT), tslib (0BSD), Perspective and regular-table (Apache-2.0), pivotkit and dnd-kit (MIT), PSU's
universal-dashboard helper (ISC), and, for two small helpers of Perspective's WebAssembly packaging
(`buffer-pipe`, `leb128`), MPL-2.0. The build writes their texts into each module's
`THIRD-PARTY-NOTICES.txt`. Icon and header are made in [eizedev/brand](https://github.com/eizedev/brand)
and licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
