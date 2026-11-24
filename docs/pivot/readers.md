---
title: What readers can do
description: "What readers do in New-UDPivotReport (fields, values, filters, table and chart, drill-down, views, exports, their own files), what they can take away, and how the report fits the page."
---

# What readers can do

The report is pivotkit's interface. Readers use these parts:

- **Fields**: Search the list (by name, display name and description), drag a field into a zone, click
  it (numbers go to Values, the rest to Rows), or pick it with **+ Add** in a zone; every field has a
  menu with the same moves, for the keyboard too. **Name** in the menu of a field in Rows, Columns or
  Filters gives it a name of the report's own; the chip, the table, the chart and the exports show it,
  and the view keeps it (`fieldLabels`). The zones sit under **Fields in the report**, a heading that
  folds them into one line. An "i" next to a field explains it when the app describes its fields ([Field
  names and descriptions](fields.md)); an "i" next to each zone explains the zone.
- **Values**: Sum, count, average, minimum, maximum and more statistics; "show as" a share of the total,
  of the row or column, a running total, a rank or the difference to the previous one; a number format;
  colour scales and data bars. A colour scale's **Colours** row offers **Theme colours, light to dark**
  and three fixed scales: **Low blue, high orange**, **Low blue, high red** and **Low red, high green**.
  A fixed scale goes into the view as the value's own colours.
- **Menus**: A chip's menu, Table settings and Chart settings are in levels: the first level says what
  is set per topic ("Filter · All", "Top items · Off"), a row opens the topic's level in place with ‹
  Back, and every choice applies at once. A search above a chip's menu finds a choice of any level with
  its path, also a rule as words ("last 3 years", "from 2022"); "/" goes to it.
- **Rows and columns**: Sort by label, by a value or in the field's own order, top or bottom N by any
  value, rules on the items and their totals ("Count of rows > 3", "from 2022"), number ranges. A click
  on a column's name in the table sorts the rows by that column; a column field's name sorts that field.
  A date is grouped as soon as it is placed (by day, month, quarter or year, from the span of its
  values), and its menu groups along the time line or across years (month of the year, weekday, hour).
- **Filters**: The Filter level of every chip starts with a summary card that stays in view: what the
  table shows of the field ("3 of 12 months shown") and why the rest does not, each reason with its
  count, and **Reset filter**. Below it, in sections that fold: **Quick choices** for a date (This year,
  Last N years, Last N months or days, each with the days it keeps and the data's share, counted back
  from today or from the latest record), **Years combined** instead for a grouping that repeats every
  year (month of the year, weekday), **Pick items** (the values with their row counts and a search) and
  **Rules** (the item itself compared, "is in the last N years", its total compared, a rule on its
  name), each with an "i" and a line that says what it keeps. A field in Filters opens the same level
  from its chip, and a date there has **Group** in its menu too.
- **Table or chart**: **Table**, **Chart** and **Both** are tabs on top of the result, each with its
  settings beside it. **Both** shows the table and the chart side by side on a wide report, with a
  divider to drag; a narrower report shows the table. Charts: bars, stacked or horizontal bars, lines,
  area, pie, donut, heatmap, bars and lines, treemap, or Automatic (lines over dates, bars otherwise). A
  pie without a legend puts its smallest slices into one slice "Other (n)" when their labels have no
  room. Chart settings, Display: value labels, legend, title, axis and group labels, a zoom slider for a
  long axis, the tooltip (the element under the pointer or every series, with each value's share), the
  colour of each series, stacks to 100 %, and reference lines (average, trend, a target, the high and
  low points). A click on the legend hides a series. Export, Copy chart image puts the chart on the
  clipboard.
- **Enlarge, Full screen**: **Enlarge** lets the table or chart fill the report (the field list and the
  zones step aside; Escape brings them back), **Full screen** shows the report on the whole screen where
  the browser allows it. Neither is part of the view.
- **Drill-down**: A click on a value opens the source rows behind it. A click on a bar, a point or a
  heatmap cell opens a menu at it: **Show the rows**, **Only …** and **Without …** (a double click opens
  the rows at once). The panel has its own Enlarge. With `-ExportData` or `-DrillDownExport` the panel
  has an Export menu (Copy for a spreadsheet, Copy as JSON, Download CSV and Excel).
- **Source data**: With `-ExportData`: Export, Source data downloads every row behind the report as CSV
  or JSON, for the reader's own analysis or `pivotkit render` ([below](#source-data-exportdata)).
- **Undo, Start over, Views, Export**: **Undo and redo** (Ctrl/Cmd+Z), **Start over** back to the start
  view, **Views** with shared views and the reader's own, Save, Save as and New, empty report
  ([Templates, view files and roles](templates.md)), and its Share level with "Copy link", "Copy view as
  JSON", "Download view" (a view file) and "Load view…", and **Export** to Excel (XLSX with number
  formats and merged headers), the table as CSV, PNG, SVG and an HTML report, Print or save as PDF, or
  Copy table and Copy data as JSON. Excel and print are light also from a dark app; the HTML report is
  light on paper and a light screen and dark on a dark one
  ([Themes](themes.md#one-stylesheet-for-echarts-and-the-pivot-report)).
- **Tips**: Above the result, for a layout that could be clearer: one at a time, each dismissible and
  remembered per report in the browser. `-Tips Off` or a list of tip ids limits them. The help of
  `-Tips` lists the ids; an unknown id is refused. More, Help has "Show tips" and "Show explanations"
  (every "i" next to fields, zones and settings); `-FieldInfo`, `-ZoneInfo` and `-SettingInfo` decide
  one kind for the reader.
- **Own files**: With `-AllowImport`: drop a CSV, TSV, JSON or Excel file onto the report, or pick it
  under Data, check a preview with a type per column, and pivot it; read in the browser, never uploaded;
  views kept per file; Back to original data ([Readers' own files](import.md)).
- **Field list**: « collapses it to a narrow rail (the reader's choice is remembered); `-FieldList
  Collapsed` or `Open` starts every reader so.
- **Zones**: The heading **Fields in the report** folds the zones into one line that names what is
  placed, and opens them again. `-Zones Open` or `Folded` sets how they start; without it the report's
  height decides ([Size and layout](#size-and-layout)).

## Source data (-ExportData)

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

- **Export (Excel, Table as CSV, HTML report, Print, PNG, SVG)**: the result shown: groups, totals, the
  chart.
- **Drill-down**: up to 1,000 rows behind a clicked value (all rows behind the grand total); the panel
  shows every column. Its Export menu (copies and files) is there with `-ExportData`, holding only the
  columns of `-ExportDataColumn`, or with `-DrillDownExport`, holding every column. Turned off: without
  `-ExportData` and `-DrillDownExport` (the default) its Export menu; `-NoDrillDown` the panel.
| Source data | every row and every column of `-Data` (or those of `-ExportDataColumn`), also the rows the filters leave out | without `-ExportData` (the default) |

All three are rows the browser holds already: its developer tools reach them. Turn Source data on only
where readers may take every row home, and leave columns readers must not have out of `-Data`
([security notes](events.md#security-notes), pivotkit's
[Source data](https://pivotkit.eize.dev/security/#source-data)). A CSV file and the report's view
file (Views, Download view) make the report again with pivotkit's command line:
`pivotkit render <view>.pivotkit.json --data <data>.csv -o report.html`.

## Size and layout

The report adapts to its own width:

| Where | What changes |
| --- | --- |
| A narrow column or a phone | The field list opens as a drawer and the zones stack above the table. |
| A touch screen | Every button and menu row is at least 44 by 44 pixels. The toolbar, the tabs and the chips are taller, so the table has about a seventh less room on a phone. |
| Below 600 pixels of height (820 in the narrow layout) | The zones start folded into one line under **Fields in the report**; that heading opens them (**Zones open or folded** below). |
| Several reports on one page | Each needs its own `-Label`, the name screen readers hear for the report. |

What the app sets:

- **Light and dark**: The report follows the app's light and dark switch and takes PSU's colours: the
  neutral greys of PSU's pages and MUI's primary blue. `-Theme Light` or `-Theme Dark` pins it.
- **Corporate design**: From the app's stylesheet, the same one that themes the ECharts charts: [Themes
  and corporate design](themes.md).
- **Height**: One screen: the window's height minus 180 pixels for PSU's app bar and a page title,
  between 600 and 1400 pixels (almost the whole window on a phone), so the whole report is on screen
  when the page loads and the table shows rows enough below the zones. `-Height` sets another one. Give
  it at least 600 pixels where readers build reports. The open zones take about 150 of them in the 2×2
  grid of a wide report, more where their text wraps. Where the area next to the field list is narrower
  than 640 pixels, they stand in one column and take about 390.
- **Inside a fixed size**: The report stays inside its height - in a card of a fixed size too: the table
  scrolls inside it, however small it gets (measured in a 560-pixel `New-UDCard` on PSU 2026.3.4).
- **Growing**: `-Grow On` lets it grow past the height instead when the table would get too small, and
  the page scrolls.
- **Zones open or folded**: Below 600 pixels of height (820 in the narrow layout) the zones start folded
  under **Fields in the report**, so the table keeps its room. `-Zones Open` keeps them open from the
  start (give the report about 700 pixels or more, or the table gets only a few rows); `-Zones Folded`
  starts them folded in any height. A report with no field placed starts with them open unless `-Zones`
  says otherwise. Readers fold and open them either way.
- **Containers**: Inside `New-UDTabs`, `New-UDCard`, `New-UDStack` and expansion panels it fits its
  container and grows when a hidden tab is shown.
