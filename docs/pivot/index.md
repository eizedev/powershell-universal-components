---
title: Pivot reports
description: "New-UDPivotReport - a pivot report builder for PSU apps: readers drag fields into rows, columns, values and filters and get a table or a chart, with drill-down, templates and Excel export."
---

# Pivot reports

`New-UDPivotReport` puts a pivot report builder into PSU apps, built on
[pivotkit](https://www.npmjs.com/package/pivotkit-react): readers drag fields from a searchable list into **Rows**,
**Columns**, **Values** and **Filters** and get a table with totals or a chart. Install the module,
pass the rows to `-Data`, and the report is there. Everything runs in the browser; the server is only
asked for what the [event parameters](events.md) do.

Install it from the PowerShell Gallery on the PSU server:

```powershell
Install-PSResource -Name PowerShellUniversal.Component.Pivot
```

In the PowerShell Gallery: [PowerShellUniversal.Component.Pivot](https://www.powershellgallery.com/packages/PowerShellUniversal.Component.Pivot).

To see it with data first, the [showcase app](demo.md) is a module of its own
(`New-UDPivotShowcase`): these examples, weather data, your own CSV and JSON files and a ticket report.

## Pivot report from a web API

--8<-- "examples/pivot-report-from-a-web-api.md"

Some products on endoflife.date mix dates and `true`/`false` in `eol`; the next example keeps the dates
only.

Then, depending on what the report needs:

| You want | Where |
| --- | --- |
| A start view, field names, a language, views in the Views menu | [the next example](#start-view-field-names-and-templates), [Views](views.md), [Field names and descriptions](fields.md) |
| The report while the server is still loading, readers' own views, roles | [the app example](#a-report-app-with-loading-views-per-reader-and-roles), [Templates, view files and roles](templates.md) |
| Data from SQL Server | [With your own data: SQL Server](#with-your-own-data-sql-server) |
| Your corporate colours | [Themes and corporate design](themes.md) |
| Readers download the rows behind the report | [Source data](#source-data-exportdata) |
| Open a view from a link pivotkit made | [Links from pivotkit](views.md#links-from-pivotkit-create_link) |
| The report as a file from an endpoint or a schedule | [Reports without a browser](reports.md) |
| Run code when readers click or change the view | [Events, security and limits](events.md) |
| Every parameter | [Commands and parameters](reference.md) |

## Start view, field names and templates

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
code while the server still builds the rows ([Loading and performance](#loading-and-performance)):

```powershell
New-UDDynamic -Id 'tickets-report' -LoadingComponent {
    New-UDPivotReportPlaceholder -Locale de-DE
} -Content {
    New-UDPivotReport -Id 'tickets' -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets') -Locale de-DE
}
```

### Pivot report from a DataTable

--8<-- "examples/pivot-report-from-a-datatable.md"

## What readers can do

| Part | What readers do |
| --- | --- |
| **Fields** | Search the list (by name, display name and description), drag a field into a zone, click it (numbers go to Values, the rest to Rows), or pick it with **+ Add** in a zone; every field has a menu with the same moves, for the keyboard too. The zones sit under **Fields in the report**, a heading that folds them into one line. An "i" next to a field explains it when the app describes its fields ([Field names and descriptions](fields.md)); an "i" next to each zone explains the zone. |
| **Values** | Sum, count, average, minimum, maximum and more statistics; "show as" a share of the total, of the row or column, a running total, a rank or the difference to the previous one; a number format; colour scales and data bars. |
| **Menus** | A chip's menu, Table settings and Chart settings are in levels: the first level says what is set per topic ("Filter · All", "Top items · Off"), a row opens the topic's level in place with ‹ Back, and every choice applies at once. A search above a chip's menu finds a choice of any level with its path, also a rule as words ("last 3 years", "from 2022"); "/" goes to it. |
| **Rows and columns** | Sort by label, by a value or in the field's own order, top or bottom N by any value, rules on the items and their totals ("Count of rows > 3", "from 2022"), number ranges. A date is grouped as soon as it is placed (by day, month, quarter or year, from the span of its values), and its menu groups along the time line or across years (month of the year, weekday, hour). |
| **Filters** | The Filter level of every chip starts with a summary card that stays in view: what the table shows of the field ("3 of 12 months shown") and why the rest does not, each reason with its count, and **Reset filter**. Below it, in sections that fold: **Quick choices** for a date (This year, Last N years, Last N months or days, each with the days it keeps and the data's share, counted back from today or from the latest record), **Years combined** instead for a grouping that repeats every year (month of the year, weekday), **Pick items** (the values with their row counts and a search) and **Rules** (the item itself compared, "is in the last N years", its total compared, a rule on its name), each with an "i" and a line that says what it keeps. A field in Filters opens the same level from its chip. |
| **Table or chart** | **Table** and **Chart** are tabs on top of the result, each with its settings beside it. Charts: bars, stacked or horizontal bars, lines, area, pie, donut, heatmap, or Automatic (lines over dates, bars otherwise). Chart settings, Display: value labels, legend, title, axis and group labels, a zoom slider for a long axis, the tooltip (the element under the pointer or every series, with each value's share), the colour of each series, stacks to 100 %, and reference lines (average, trend, a target). A click on the legend hides a series. Export, Copy chart image puts the chart on the clipboard. |
| **Enlarge, Full screen** | **Enlarge** lets the table or chart fill the report (the field list and the zones step aside; Escape brings them back), **Full screen** shows the report on the whole screen where the browser allows it. Neither is part of the view. |
| **Drill-down** | A click on a value or a chart point opens the source rows behind it, with its own Enlarge. With `-ExportData` or `-DrillDownExport` the panel has an Export menu (Copy for a spreadsheet, Copy as JSON, Download CSV and Excel). |
| **Source data** | With `-ExportData`: Export, Source data downloads every row behind the report as CSV or JSON, for the reader's own analysis or `pivotkit render` ([below](#source-data-exportdata)). |
| **Undo, Reset, Views, Export** | **Undo and redo** (Ctrl/Cmd+Z), **Reset** to the start view, **Views** with shared views and the reader's own, Save, Save as and New, empty report ([Templates, view files and roles](templates.md)), and its Share level with "Copy link", "Copy view as JSON", "Download view" (a view file) and "Load view…", and **Export** to Excel (XLSX with number formats and merged headers), the table as CSV, PNG, SVG and an HTML report, Print or save as PDF, or Copy table and Copy data as JSON. Excel and print are light also from a dark app; the HTML report is light on paper and a light screen and dark on a dark one ([Themes](themes.md#one-stylesheet-for-echarts-and-the-pivot-report)). |
| **Tips** | Above the result, for a layout that could be clearer: one at a time, each dismissible and remembered per report in the browser. `-Tips Off` or a list of tip ids limits them. More, Help has "Show tips" and "Show explanations" (every "i" next to fields, zones and settings); `-FieldInfo`, `-ZoneInfo` and `-SettingInfo` decide one kind for the reader. |
| **Own files** | With `-AllowImport`: drop a CSV, TSV, JSON or Excel file onto the report, or pick it under Data, check a preview with a type per column, and pivot it; read in the browser, never uploaded; views kept per file; Back to original data ([Readers' own files](import.md)). |
| **Field list** | « collapses it to a narrow rail (the reader's choice is remembered); `-FieldList Collapsed` or `Open` starts every reader so. |
| **Zones** | The heading **Fields in the report** folds the zones into one line that names what is placed, and opens them again. `-Zones Open` or `Folded` sets how they start; without it the report's height decides ([Theme and layout](#theme-and-layout)). |

### Source data (-ExportData)

`-ExportData` adds **Source data** to the Export menu: every row of `-Data`, before filters, grouping
and totals, as a CSV or JSON file. It is off by default. It also gives the drill-down panel its Export
menu. `-ExportDataColumn` keeps these files, and the drill-down panel's copies and files, to the
columns it names (matched without regard to case, checked against the columns of the first row); a
name that is no column of `-Data` is an error, so a typo never widens the export. The explanation next
to Source data then names those columns.

`-DrillDownExport` gives the drill-down panel its Export menu alone, with every column. Source data
stays off.

!!! warning "-ExportDataColumn is no access control"
    It narrows two kinds of download, nothing else. The field list, the drill-down panel itself, the
    exports of the result (a reader can place any field) and `$EventData.rows` of `-OnCellClick` still
    carry every column of `-Data`, and the browser holds them all. To keep a column away from readers,
    remove it before `-Data`: `$rows | Select-Object -ExcludeProperty Customer`, or leave it out of the
    SQL query.

--8<-- "examples/source-data-for-readers.md"

What each part hands out:

| Part | What a reader takes away | Turned off with |
| --- | --- | --- |
| Export (Excel, Table as CSV, HTML report, Print, PNG, SVG) | the result shown: groups, totals, the chart | - |
| Drill-down | up to 1,000 rows behind a clicked value (all rows behind the grand total); the panel shows every column. Its Export menu (copies and files) is there with `-ExportData`, holding only the columns of `-ExportDataColumn`, or with `-DrillDownExport`, holding every column | without `-ExportData` and `-DrillDownExport` (the default) its Export menu; `-NoDrillDown` the panel |
| Source data | every row and every column of `-Data` (or those of `-ExportDataColumn`), also the rows the filters leave out | without `-ExportData` (the default) |

All three are rows the browser holds already: its developer tools reach them. Turn Source data on only
where readers may take every row home, and leave columns readers must not have out of `-Data`
([security notes](events.md#security-notes), pivotkit's
[Source data](https://pivotkit.eize.dev/security/#source-data)). A CSV file and the report's view
file (Views, Download view) make the report again with pivotkit's command line:
`pivotkit render <view>.pivotkit.json --data <data>.csv -o report.html`.

The report adapts to its own width:

| Where | What changes |
| --- | --- |
| A narrow column or a phone | The field list opens as a drawer and the zones stack above the table. |
| Below 600 pixels of height (820 in the narrow layout) | The zones start folded into one line under **Fields in the report**; that heading opens them ([Theme and layout](#theme-and-layout)). |
| Several reports on one page | Each needs its own `-Label`, the name screen readers hear for the report. |

## Data

`-Data` takes a DataTable (`Invoke-Sqlcmd`, SqlClient, ODBC), DataRows, PSCustomObjects, hashtables or
a script block, like the other modules. The column names are the field names the reader sees, with
their PowerShell spelling. Every column gets a type from its values:

| Values | Type in the report |
| --- | --- |
| Numbers | number |
| `DateTime`, `DateTimeOffset` | date (see [Dates and time zones](#dates-and-time-zones)) |
| `$true`, `$false` | boolean |
| Everything else | text |
| `DBNull`, `$null` | empty: they count as rows but not in sums and averages, and show as "(blank)" in rows and filters |

`-FieldDefaults` with `Type` reads a column as another type, for example dates that arrive as text
([Field names and descriptions](fields.md)).

### Dates and time zones

| Value | Shown as |
| --- | --- |
| A `DateTime` from SQL (no time zone) | as it is, on every reader's screen the same |
| A `DateTimeOffset`, or a `DateTime` of kind `Local` or `Utc` (`Get-Date`, `[datetime]::UtcNow`) | an instant, at the wall clock of `-TimeZone`: the server's time zone by default (as an IANA name such as `Europe/Berlin`) |

Pass `-TimeZone UTC`, or the zone your readers are in, to fix it.

### Language and formats

| Parameter | What |
| --- | --- |
| `-Locale` | The language of the report (German for `de-*`, English for everything else) and how numbers, dates and sorting look. The default is `en-US` for every reader: the report never takes the browser's or the server's language on its own, so a report and its exports look the same for everyone. |
| `-Labels` | Replaces single texts: the keys of pivotkit-react's `LABELS`, e.g. `@{ zones = @{ values = 'Kennzahlen' }; tips = @{ values = '...' }; sharedViews = 'Team-Ansichten' }`. pivotkit-react's `pivotkit-react/labels` entry lists every key, the texts of the menus included. |

### Field names and descriptions

`-FieldDefaults`, `-FieldDescriptions` and `-Schema` give fields display names, descriptions with a
link, their own order of items, aggregators and formats - from your script, from SQL Server column
descriptions (`Get-UDPivotSqlColumnDescription`) or from a JSON Schema or an OpenAPI document:
[Field names and descriptions](fields.md).

### Chart options

`-ChartOptions` is plain JSON merged over the chart's Apache ECharts option, for what the reader
cannot set in Chart settings: `-ChartOptions @{ legend = @{ top = 0 }; grid = @{ left = 80 } }`.
It wins over the view's chart settings. pivotkit leaves out options that are markup or addresses
(`formatter` strings, `rich`, `link`, `image`) with a warning in the browser's console; at most 64 KB.

## Pivot report in German

--8<-- "examples/pivot-report-in-german.md"

## Theme and layout

| What | How |
| --- | --- |
| Light and dark | The report follows the app's light and dark switch and takes PSU's colours: the neutral greys of PSU's pages and MUI's primary blue. `-Theme Light` or `-Theme Dark` pins it. |
| Corporate design | From the app's stylesheet, the same one that themes the ECharts charts: [Themes and corporate design](themes.md). |
| Height | One screen: the window's height minus 180 pixels for PSU's app bar and a page title, between 600 and 1400 pixels (almost the whole window on a phone), so the whole report is on screen when the page loads and the table shows rows enough below the zones. `-Height` sets another one. Give it at least 600 pixels where readers build reports. The open zones take about 150 of them in the 2×2 grid of a wide report, more where their text wraps. Where the area next to the field list is narrower than 640 pixels, they stand in one column and take about 390. |
| Inside a fixed size | The report stays inside its height - in a card of a fixed size too: the table scrolls inside it, however small it gets (measured in a 560-pixel `New-UDCard` on PSU 2026.3.4). |
| Growing | `-Grow On` lets it grow past the height instead when the table would get too small, and the page scrolls. |
| Zones open or folded | Below 600 pixels of height (820 in the narrow layout) the zones start folded under **Fields in the report**, so the table keeps its room. `-Zones Open` keeps them open from the start (give the report about 700 pixels or more, or the table gets only a few rows); `-Zones Folded` starts them folded in any height. A report with no field placed starts with them open unless `-Zones` says otherwise. Readers fold and open them either way. |
| Containers | Inside `New-UDTabs`, `New-UDCard`, `New-UDStack` and expansion panels it fits its container and grows when a hidden tab is shown. |

## Reports as files

The views readers build here also run without a browser: `Invoke-UDPivotReport` renders a view over
rows into an Excel workbook, an HTML report, CSV, JSON or SVG, for an endpoint or a schedule, with
pivotkit's command line on the PSU server or a pivotkit-server. From a pivotkit-server it also returns
a link that expires instead of the file, and `Get-UDPivotSource` lists the server's sources
([Reports without a browser](reports.md)).

## Loading and performance

PSU draws a component once its properties have arrived, and the report's properties carry all of its
rows. Until then the page has nothing to show for it, and the browser does not even know that it will
need the module's code. Three parts take the time: the server converts the rows (`-Data`), PSU sends
them as JSON, and the browser builds the report.

`New-UDPivotReportPlaceholder` in `New-UDDynamic -LoadingComponent` (see
[With your own data: SQL Server](#with-your-own-data-sql-server) and the
[app example](#a-report-app-with-loading-views-per-reader-and-roles)) shows pivotkit's own skeleton of
the report while the server works:

| Placeholder | |
| --- | --- |
| What it shows | The field list, the toolbar, the zones and table rows as grey bars, in the report's colours, at the height you give it. |
| Parameters | The same `-Height`, `-Theme`, `-Locale` and `-Label` as the report, so nothing moves when the report replaces it. |
| Motion and screen readers | The bars move unless the reader asked the system for reduced motion; screen readers hear "Loading the report". |
| Why it is faster | The placeholder comes from the module, so the browser loads the module's code at once instead of after the data. |
| More than 10,000 rows | The report itself shows the same skeleton for a moment while the browser reads the data. |

--8<-- "examples/placeholder-while-the-data-loads.md"

The rows are converted without a call per cell. A DataTable of 1000 rows or more whose columns hold
text, numbers, booleans, GUIDs, dates or TimeSpans goes through a small C# class that the module
compiles with `Add-Type` the first time it needs it: about 2 seconds, once per PSU process (PSU runs
its apps in its own process, so once after PSU starts, not per app start). Where `Add-Type` is not
available, for example in constrained language mode, PowerShell does the same conversion more slowly.
The ECharts and Perspective modules convert their data the same way.

Measured on the test instance (PSU 2026.3.4 in a Linux container on a small NAS, 2026-11-07, Chromium;
approximate, your server and network differ), with the showcase's DataTable of 5000 rows and 12
columns:

| Step | Time |
| --- | --- |
| Converting the rows, compiled class | about 40 ms (PSU 2026.2.5: about 36 ms) |
| Converting the rows, PowerShell only | about 150 to 250 ms |
| The report's properties: 1.24 MB of JSON, built, sent and received | about 0.25 s |
| Placeholder on screen, after the page request started | about 0.22 s |
| The table on screen, after the page request started | about 0.46 s |
| The browser, from the data to the table (the module's code already loaded) | about 40 ms |

What makes it slower is the size of the data: every row and every column travels to the browser.
Select the columns readers need (`SELECT Team, Priority, Created ...` instead of `SELECT *`), and
aggregate in SQL where readers never look at single rows.

Next: [Field names and descriptions](fields.md), [Themes and corporate design](themes.md), [Views](views.md), [Templates, view files and roles](templates.md), [Events, security and limits](events.md), [Reference](reference.md).
