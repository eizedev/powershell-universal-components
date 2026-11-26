---
title: Pivot reports
description: "New-UDPivotReport - a pivot report builder for PSU apps: readers drag fields into rows, columns, values and filters and get a table or a chart, with drill-down, templates and Excel export."
---

# Pivot reports

`New-UDPivotReport` puts a pivot report builder into PSU apps, built on
[pivotkit](https://pivotkit.eize.dev/).

!!! info "Where to read what"
    - **These pages**, for app authors: install and update, `New-UDPivotReport` and its parameters,
      data from SQL, REST and DataTables, themes, roles, template stores, `Invoke-UDPivotReport`.
    - **pivotkit's guide [Use a report](https://pivotkit.eize.dev/use/)**, for your readers: fields,
      values, filters, charts, views and export. Try it in the [live demo](https://pivotkit.eize.dev/demo/).
    - **[pivotkit's docs](https://pivotkit.eize.dev/)**, for the report itself: the view format,
      sharing, limits, the command line and REST reference, security,
      [versioning](https://pivotkit.eize.dev/versioning/) and
      [upgrading](https://pivotkit.eize.dev/getting-started/upgrading/).

Install it on the PSU server, pass the rows to `-Data`, and the report is there. Everything runs in
the browser; the server is only asked for what the [event parameters](events.md) do.

```powershell
Install-PSResource -Name PowerShellUniversal.Component.Pivot
New-UDPivotReport -Id 'tickets' -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets')
```

| You want | Where |
| --- | --- |
| A start view, field names, a language, views in the Views menu | [the example](#start-view-field-names-and-templates), [Views](views.md), [Field names and descriptions](fields.md) |
| The report while the server is still loading, readers' own views, roles | [the app example](#a-report-app-with-loading-views-per-reader-and-roles), [Templates, view files and roles](templates.md) |
| Data from SQL Server | [With your own data: SQL Server](#with-your-own-data-sql-server) |
| Your corporate colours | [Themes and corporate design](themes.md) |
| Readers download the rows behind the report | [Source data](readers.md#source-data-exportdata) |
| Open a view from a link pivotkit made | [Links from pivotkit](links.md#links-from-pivotkit-create_link) |
| Rows only a pivotkit-server can reach, for the signed-in person | [Rows from a server](server-rows.md) |
| The report as a file from an endpoint or a schedule | [Reports without a browser](reports.md) |
| Run code when readers click or change the view | [Events, security and limits](events.md) |
| What readers get, and what the app decides for them | [Readers and your app](readers.md) |
| What `-Data` takes, large data | [Data and loading](data.md) |
| Every parameter | [Commands and parameters](reference.md) |
| Move an app from `New-UDPivot` | [Coming from UniversalDashboard.Pivot](#coming-from-universaldashboardpivot) |

Readers drag fields from a searchable list into **Rows**, **Columns**, **Values** and **Filters** and
get a table with totals or a chart, with date grouping, drill-down to the source rows, shared views and
views readers keep (roles decide who publishes), undo, Excel, CSV, PNG, SVG and HTML export and print,
and their own CSV, JSON and Excel files read in the browser ([`-AllowImport`](import.md)); English and
German; themed from the same stylesheet as the charts. `Invoke-UDPivotReport` renders the same views
into Excel, HTML, CSV, JSON or SVG files from endpoints and schedules, without a browser, or into a
link that expires from a pivotkit-server ([Reports without a browser](reports.md)).

To see it with data first, the [showcase app](demo.md) is a module of its own
(`New-UDPivotShowcase`): these examples, weather data, your own CSV and JSON files and a ticket report.

## Pivot report from a web API

--8<-- "examples/pivot-report-from-a-web-api.md"

## Weather of six cities

--8<-- "examples/weather-of-six-cities.md"

## Start view, field names and templates

Some products on endoflife.date mix dates and `true` or `false` in `eol`. This example keeps the dates
only.

--8<-- "examples/start-view-field-names-and-templates.md"

## A report app with loading, views per reader and roles

--8<-- "examples/a-report-app-with-loading-views-per-reader-and-roles.md"

## With your own data: SQL Server

The same call takes what `Invoke-Sqlcmd` returns:

```powershell
New-UDPivotReport -Id 'tickets' -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets') -Locale de-DE
```

With thousands of rows, put the report into `New-UDDynamic` and give it `New-UDPivotReportPlaceholder` as
`-LoadingComponent`. The page then shows the report's frame at once, and the browser loads the module's
code while the server still builds the rows ([Loading and performance](data.md#loading-and-performance)):

```powershell
New-UDDynamic -Id 'tickets-report' -LoadingComponent {
    New-UDPivotReportPlaceholder -Locale de-DE
} -Content {
    New-UDPivotReport -Id 'tickets' -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets') -Locale de-DE
}
```

### Pivot report from a DataTable

--8<-- "examples/pivot-report-from-a-datatable.md"

## Pivot report in German

--8<-- "examples/pivot-report-in-german.md"

## Coming from UniversalDashboard.Pivot { #coming-from-universaldashboardpivot }

`New-UDPivotReport` replaces `New-UDPivot` of [UniversalDashboard.Pivot](https://github.com/eizedev/UniversalDashboard.Pivot),
which wraps react-pivottable. Check the PowerShell and PSU versions on [Compatibility](../compatibility.md).
The start view moves from parameters into one `-View` ([Views](views.md#the-start-view-view)). The
same rows, before and after:

```powershell
$data = @(
    @{ Team = 'OPS'; Status = 'Open'; Priority = 'High'; Hours = 5 }
    @{ Team = 'OPS'; Status = 'Closed'; Priority = 'Low'; Hours = 2 }
    @{ Team = 'OPS'; Status = 'Closed'; Priority = 'High'; Hours = 4 }
    @{ Team = 'DEV'; Status = 'Open'; Priority = 'High'; Hours = 8 }
    @{ Team = 'DEV'; Status = 'Closed'; Priority = 'Medium'; Hours = 3 }
    @{ Team = 'DEV'; Status = 'Open'; Priority = 'Low'; Hours = 6 }
    @{ Team = 'QA'; Status = 'Open'; Priority = 'Medium'; Hours = 1 }
    @{ Team = 'QA'; Status = 'Closed'; Priority = 'High'; Hours = 7 }
)
# before
New-UDPivot -Id 'tickets-before' -Data $data -Rows 'Team' -Cols 'Status' -Vals 'Hours' -AggregatorName 'Sum' -RowOrder 'value_z_to_a' -ValueFilter @{ Priority = @{ Low = $true } }
# after
New-UDPivotReport -Id 'tickets-after' -Data $data -View @{
    rows    = @('Team')
    cols    = @('Status')
    values  = @(@{ field = 'Hours'; agg = 'sum' })
    filters = @(@{ field = 'Priority'; type = 'in'; items = @('Low'); not = $true; blanks = 'include' })
    sort    = @(@{ field = 'Team'; by = 'value'; order = 'desc' })
}
```

Both show the sum of hours without the Low tickets, the teams by their total, highest first: DEV 11,
OPS 9, QA 8.

| `New-UDPivot` | `New-UDPivotReport` |
| --- | --- |
| `-Id`, `-Data` | `-Id`, `-Data`: also a script block, and a DataTable ([Data and loading](data.md)) |
| `-Rows`, `-Cols` | `rows`, `cols` in `-View` |
| `-Vals`, `-AggregatorName` | `values`, each with its field and `agg`. `Count` is `count` on a field: it counts the rows where the field has a value. `Count Unique Values`, `List Unique Values`: `countUnique`, `listUnique`. `Sum`, `Integer Sum`: `sum` (with `format = 'integer'`). `Average`, `Median`, `Minimum`, `Maximum`, `First`, `Last`: `average`, `median`, `min`, `max`, `first`, `last`. `Sample Variance`, `Sample Standard Deviation`: `var`, `stdev`. `Sum` or `Count as Fraction of Total`, `of Rows`, `of Columns`: `sum` or `count` with `showAs = @{ type = 'percentOfGrandTotal' }`, `'percentOfRowTotal'`, `'percentOfColumnTotal'`. No counterpart: `Sum over Sum`, `80% Upper Bound`, `80% Lower Bound`. |
| `-RendererName` | `Table`: the default. `Table Heatmap`: `conditional = @{ type = 'colorScale' }` on the value. `Grouped Column Chart`, `Stacked Column Chart`: `display = 'chart'; chart = @{ type = 'bar' }`, with `stacked = $true`; `Grouped Bar Chart`, `Stacked Bar Chart` add `horizontal = $true`. `Line Chart`, `Area Chart`: `type = 'line'`, `'area'`. `Exportable TSV`: the reader's export copies the table as tab-separated text. No counterpart: `Table Row Heatmap`, `Table Col Heatmap`, `Dot Chart`, `Scatter Chart`, `Multiple Pie Chart` (`type = 'pie'` draws one pie of the row totals). |
| `-RowOrder`, `-ColOrder` | `key_a_to_z`: the default. `value_a_to_z`, `value_z_to_a`: `sort = @(@{ field = 'Team'; by = 'value'; order = 'asc' })` or `'desc'`, per row or column field. |
| `-ValueFilter` | `filters`: the listed items with `type = 'in'; not = $true; blanks = 'include'` ([Filters](filters.md)). |
| `-HiddenAttributes` | No counterpart: leave the column out of the rows you pass to `-Data` (`Select-Object -ExcludeProperty` for objects), so it does not reach the browser either. |
| `-HiddenFromAggregators`, `-HiddenFromDragDrop`, `-MenuLimit`, `-UnusedOrientationCutoff` | No counterpart. |

Next: [Readers and your app](readers.md), [Data and loading](data.md), [Field names and descriptions](fields.md), [Themes and corporate design](themes.md), [Views](views.md), [Templates, view files and roles](templates.md), [Events, security and limits](events.md), [Reference](reference.md).
