---
title: Pivot reports
description: "New-UDPivotReport - a pivot report builder for PSU apps: readers drag fields into rows, columns, values and filters and get a table or a chart, with drill-down, templates and Excel export."
---

# Pivot reports

`New-UDPivotReport` puts a pivot report builder into PSU apps, built on
[pivotkit](https://www.npmjs.com/package/pivotkit-react): readers drag fields from a searchable list into **Rows**,
**Columns**, **Values** and **Filters** and get a table with totals or a chart. Everything runs in the
browser; the server is only asked for what the [event parameters](events.md) do.

```powershell
Install-PSResource -Name PowerShellUniversal.Component.Pivot
```

```powershell
New-UDPivotReport -Id 'tickets' -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets') -Locale de-DE
```

With thousands of rows, put the report into `New-UDDynamic` and give it `New-UDPivotReportPlaceholder` as
`-LoadingComponent`. The page then shows the report's frame at once, and the browser loads the module's
code while the server still builds the rows ([Loading and performance](#loading-and-performance)):

```powershell
New-UDDynamic -Id 'tickets-report' -LoadingComponent {
    New-UDPivotReportPlaceholder -Height 640px -Locale de-DE
} -Content {
    New-UDPivotReport -Id 'tickets' -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets') -Height 640px -Locale de-DE
}
```

## Pivot report from a DataTable

--8<-- "examples/pivot-report-from-a-datatable.md"

## What readers can do

- **Fields**: search the list, drag a field into a zone, or click it (numbers go to Values, the rest to
  Rows); every field has a menu with the same moves, for the keyboard too.
- **Values**: sum, count, average, minimum, maximum and more statistics; "show as" a share of the total,
  of the row or column, a running total, a rank or the difference to the previous one; a number format;
  colour scales and data bars.
- **Rows and columns**: sort by label or by value, top or bottom N, number ranges; a date is grouped as
  soon as it is placed (by day, month, quarter or year, from the span of its values), and its menu
  groups along the time line or across years (month of the year, weekday, hour).
- **Filters**: the values of a field with their row counts, search, "only this value", text conditions.
- **Table or chart**: bars, stacked or horizontal bars, lines, area, pie, heatmap.
- **Drill-down**: a click on a value or a chart point opens the source rows behind it.
- **Undo and redo** (Ctrl/Cmd+Z), **Reset** to the start view, **Templates**, and **Export** to Excel
  (XLSX with number formats and merged headers), CSV and PNG.

The report adapts to its own width: in a narrow column or on a phone the field list opens as a drawer
and the zones stack above the table.

## Data

`-Data` takes a DataTable (`Invoke-Sqlcmd`, SqlClient, ODBC), DataRows, PSCustomObjects, hashtables or
a script block, like the other modules. The column names are the field names the reader sees, with
their PowerShell spelling. Every column gets a type from its values: numbers, dates, `$true`/`$false`
and text. `DBNull` and `$null` are empty values: they count as rows but not in sums and averages, and
show as "(blank)" in rows and filters.

### Dates and time zones

A `DateTime` from SQL has no time zone; it is shown as it is, on every reader's screen the same. A
`DateTimeOffset`, or a `DateTime` of kind `Local` or `Utc` (`Get-Date`, `[datetime]::UtcNow`), is an
instant: it is shown at the wall clock of `-TimeZone`, the server's time zone by default (as an IANA
name such as `Europe/Berlin`). Pass `-TimeZone UTC`, or the zone your readers are in, to fix it.

### Language and formats

`-Locale` sets the language of the report (German for `de-*`, English for everything else) and how
numbers, dates and sorting look. The default is `en-US` for every reader: the report never takes the
browser's or the server's language on its own, so a report and its exports look the same for
everyone. `-Labels` replaces single texts.

## Pivot report in German

--8<-- "examples/pivot-report-in-german.md"

## Theme and layout

The report follows the app's light and dark switch and takes PSU's colours: the neutral greys of PSU's
pages and MUI's primary blue. `-Theme Light` or `-Theme Dark` pins it. A corporate design comes from the
app's stylesheet, the same one that themes the ECharts charts: [Themes and corporate design](themes.md). Its height is the window's
height minus the app bar and a page title (between 480 and 1400 pixels, almost the whole window on a
phone); `-Height` sets another one. Give it at least 600 pixels where readers build reports: the zones
take about 300 of them. Inside `New-UDTabs`, `New-UDCard`, `New-UDStack` and expansion panels it fits
its container and grows when a hidden tab is shown.

## Loading and performance

PSU draws a component once its properties have arrived, and the report's properties carry all of its
rows. Until then the page has nothing to show for it, and the browser does not even know that it will
need the module's code. Three parts take the time: the server converts the rows (`-Data`), PSU sends
them as JSON, and the browser builds the report.

`New-UDPivotReportPlaceholder` in `New-UDDynamic -LoadingComponent` (see the top of this page) shows the
report's frame while the server works: the field list, the toolbar, the zones and a few table rows as
grey bars, in the report's colours and layout, at the height you give it. Give it the same `-Height`,
`-Theme` and `-Locale` as the report, so nothing moves when the report replaces it. The bars pulse
unless the reader asked the system for reduced motion; screen readers hear "Loading report". Because
the placeholder comes from the module, the browser loads the module's code at once instead of after
the data.

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

Next: [Themes and corporate design](themes.md), [Views and templates](views.md), [Events, security and limits](events.md), [Reference](reference.md).
