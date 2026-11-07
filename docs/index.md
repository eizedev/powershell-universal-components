---
title: Overview
description: Custom components for PowerShell Universal apps - interactive Apache ECharts charts, a Perspective datagrid, pivot and charts, and a pivot report builder, fed straight from SQL, REST and PowerShell objects.
---

# Components for PowerShell Universal apps

Custom components for [PowerShell Universal](https://devolutions.net/powershell-universal/) (PSU)
apps, each one a PowerShell module you install on its own. Pass the data as it comes - a DataTable
from SQL, objects from `Invoke-RestMethod` or any PowerShell command - name the columns, and the
component is drawn in the browser.

| Module | Command | What it adds |
| --- | --- | --- |
| [ECharts](echarts/index.md) | `New-UDEChart` | 29 chart types on [Apache ECharts](https://echarts.apache.org/), from bars and lines to gantt, rankings, radial bars, network graphs, trees and KPI matrices; zoom, range selection, click events that filter other elements, linked charts, trends with forecast, CSV/Excel/PNG export, full screen, light and dark theme, corporate themes. |
| [Perspective](perspective/index.md) | `New-UDPerspective` | [Perspective](https://perspective-dev.github.io/) datagrid, pivot table and WebGL charts in one, which readers group, split, filter and sort themselves; a WebAssembly engine for large row counts. |
| [Pivot](pivot/index.md) | `New-UDPivotReport` | A pivot report builder on [pivotkit](https://www.npmjs.com/package/pivotkit-react): readers drag fields into rows, columns, values and filters and get a table or a chart, with date grouping, drill-down to the source rows, templates they save, undo and Excel, CSV and PNG export; English and German; themed from the same stylesheet as the charts. |
| [Demo](demo.md) | `New-UDEChartShowcase` | The showcase app of the chart module as a module: 14 pages of examples to try the charts or copy from. |

Every chart on these pages is drawn by the module's own component, with the props that the PowerShell
next to it returns; events that would run a script block on the server show their `$EventData` instead.

![Data platform page of the showcase app: coverage heatmap of source systems and assets per number of sources](assets/images/screenshot-data-platform-dark.png)

## Requirements

PowerShell Universal 2026 (PowerShell 7.4 or newer). Tested on PSU 2026.2.5 and 2026.3.4 in Chromium,
Firefox and WebKit (the engine of Safari; the Safari app and iOS are not tested).

Start with [Getting started](getting-started.md).

## License

MIT. The bundled libraries keep their own licenses: Apache ECharts (Apache-2.0), ZRender
(BSD-3-Clause), fflate (MIT), tslib (0BSD), Perspective and regular-table (Apache-2.0), pivotkit and dnd-kit (MIT), PSU's
universal-dashboard helper (ISC), and, for two small helpers of Perspective's WebAssembly packaging
(`buffer-pipe`, `leb128`), MPL-2.0. The build writes their texts into each module's
`THIRD-PARTY-NOTICES.txt`. Icon and header are made in [eizedev/brand](https://github.com/eizedev/brand)
and licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
