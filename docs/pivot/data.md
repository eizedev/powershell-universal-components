---
title: Data and loading
description: "What New-UDPivotReport takes as -Data, the type of each column, dates and time zones, language and formats, chart options, and how the report loads large data with a placeholder."
---

# Data and loading


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

Instead of `-Data`, `-Uri -Source -Token` show the rows of a pivotkit-server source for the signed-in
person. The server hands them out, PowerShell passes them on as text, and a link with parameters opens
on them ([rows from a server](server-rows.md)).

## Dates and time zones

| Value | Shown as |
| --- | --- |
| A `DateTime` from SQL (no time zone) | as it is, on every reader's screen the same |
| A `DateTimeOffset`, or a `DateTime` of kind `Local` or `Utc` (`Get-Date`, `[datetime]::UtcNow`) | an instant, at the wall clock of `-TimeZone`: the server's time zone by default (as an IANA name such as `Europe/Berlin`) |

Pass `-TimeZone UTC`, or the zone your readers are in, to fix it.

## Language and formats

- `-Locale`: The language of the report (German for `de-*`, English for everything else) and how
  numbers, dates and sorting look. The default is `en-US` for every reader: the report never takes the
  browser's or the server's language on its own, so a report and its exports look the same for everyone.
- `-Labels`: Replaces single texts: the keys of pivotkit-react's `LABELS`, e.g. `@{ zones = @{ values =
  'Kennzahlen' }; tips = @{ values = '...' }; sharedViews = 'Team-Ansichten' }`. pivotkit-react's
  `pivotkit-react/labels` entry lists every key, the texts of the menus included.

## Field names and descriptions

`-FieldDefaults`, `-FieldDescriptions` and `-Schema` give fields display names, descriptions with a
link, their own order of items, aggregators and formats - from your script, from SQL Server column
descriptions (`Get-UDPivotSqlColumnDescription`) or from a JSON Schema or an OpenAPI document:
[Field names and descriptions](fields.md).

## Chart options

`-ChartOptions` is plain JSON merged over the chart's Apache ECharts option, for what the reader
cannot set in Chart settings: `-ChartOptions @{ legend = @{ top = 0 }; grid = @{ left = 80 } }`.
It wins over the view's chart settings. pivotkit leaves out options that are markup or addresses
(`formatter` strings, `rich`, `link`, `image`) with a warning in the browser's console; at most 64 KB.

## Loading and performance

PSU draws a component once its properties have arrived, and the report's properties carry all of its
rows. Until then the page has nothing to show for it, and the browser does not even know that it will
need the module's code. Three parts take the time: the server converts the rows (`-Data`), PSU sends
them as JSON, and the browser builds the report.

`New-UDPivotReportPlaceholder` in `New-UDDynamic -LoadingComponent` (see
[With your own data: SQL Server](index.md#with-your-own-data-sql-server) and the
[app example](index.md#a-report-app-with-loading-views-per-reader-and-roles)) shows pivotkit's own skeleton of
the report while the server works:

| Placeholder | |
| --- | --- |
| What it shows | The field list, the toolbar, the zones and table rows as grey bars, in the report's colours, at the height you give it. |
| Parameters | The same `-Height`, `-Theme`, `-Locale` and `-Label` as the report, so nothing moves when the report replaces it. |
| Motion and screen readers | The bars move unless the reader asked the system for reduced motion; screen readers hear "Loading the report". |
| Why it is faster | The placeholder comes from the module, so the browser loads the module's code at once instead of after the data. |
| More than 10,000 rows | The report itself shows the same skeleton for a moment while the browser reads the data. |

--8<-- "examples/placeholder-while-the-data-loads.md"

The rows are converted as in every module: [How the modules convert data](../getting-started.md#how-the-modules-convert-data).

Measured on the test instance (PSU 2026.3.4 in a Linux container, 2026-11-07, Chromium;
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
