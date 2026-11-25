---
title: What readers can do
description: "What readers do in New-UDPivotReport (fields, values, filters, table and chart, drill-down, views, exports, their own files), what they can take away, and how the report fits the page."
---

# What readers can do

For app authors: what the report offers your readers, and which parameters decide it.

The report is pivotkit's interface, and pivotkit's guide [Use a report](https://pivotkit.eize.dev/use/)
explains it to readers, one page per task. Link it from your app, or point readers to pivotkit's
[live demo](https://pivotkit.eize.dev/demo/) to try it. This page covers only what the module and your
app decide.

| Readers | pivotkit's guide | What the app decides |
| --- | --- | --- |
| Place fields, read the table | [Fields, zones and the table](https://pivotkit.eize.dev/use/fields/) | Names and descriptions of fields ([Field names and descriptions](fields.md)), `-FieldList`, `-Zones` |
| Sum, count, show as, formats | [Values and formats](https://pivotkit.eize.dev/use/values/) | The start view ([Views](views.md)), `-Locale` |
| Filter, top N, sort | [Filters, top N and sorting](https://pivotkit.eize.dev/use/filters/) | The start view's filters ([Views](views.md)) |
| Charts | [Charts](https://pivotkit.eize.dev/use/charts/) | The start view's chart ([Views](views.md)) |
| The rows behind a number | [The rows behind a number](https://pivotkit.eize.dev/use/drill-down/) | `-NoDrillDown`, `-DrillDownExport`, `-ExportData` ([below](#source-data-exportdata)) |
| Save, pick and share views | [Views, saving and sharing](https://pivotkit.eize.dev/use/views/) | Shared views, readers' own views and roles ([Templates, view files and roles](templates.md)) |
| Export and print | [Export and copy](https://pivotkit.eize.dev/use/export/) | Source data with `-ExportData` ([below](#source-data-exportdata)), the colours ([Themes](themes.md#one-stylesheet-for-echarts-and-the-pivot-report)) |
| Load their own file | [Load your own data](https://pivotkit.eize.dev/use/load-data/) | `-AllowImport` ([Readers' own files](import.md)) |
| Tips, small screens | [Small screens, menus and tips](https://pivotkit.eize.dev/use/layout/) | `-Tips`, `-Height`, `-Zones` ([below](#size-and-layout)) |

Tips appear above the result for a layout that could be clearer, one at a time; readers dismiss each
one. `-Tips Off` turns them off, a list of tip ids keeps only those; the help of `-Tips` lists the ids,
and an unknown id is refused. `-FieldInfo`, `-ZoneInfo` and `-SettingInfo` decide whether the "i"
explanations next to fields, zones and settings show.

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
  columns of `-ExportDataColumn`, or with `-DrillDownExport`, holding every column. The Export menu
  is off by default: turn it on with `-ExportData` or `-DrillDownExport`. `-NoDrillDown` turns the
  panel off.
- **Source data**: every row and every column of `-Data`, or only the columns of `-ExportDataColumn`,
  also the rows the filters leave out. Off without `-ExportData`, the default.

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
