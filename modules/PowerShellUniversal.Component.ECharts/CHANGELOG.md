# Changelog

All notable changes to PowerShellUniversal.Component.ECharts. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

### Fixed

- A heatmap, faceted charts, a radar and a matrix of more than about 125,000 values no longer fail
  with "Maximum call stack size exceeded": their scale is found with a loop, as `-Aggregate`
  already did.
- The CSV export builds its number format once per export, not once per cell; a large export was
  about 60 times slower than needed.
- `-Format currency:<code>` with a code the browser does not know, such as `currency:EURO`, shows
  plain numbers, as an unknown format name does. Before, the chart showed an error, and the export of such a
  column failed.
- Full screen paints PSU's page background behind the chart. On a page whose body is transparent the
  browser's black backdrop showed.
- A chart with `-Group` stays linked to its group after the module draws it again for another
  `-Renderer` or locale.
- `-OnClick` and `-OnSelect` hand back the row behind the clicked point also when the chart's data
  holds entries that are no objects, such as `$null`. Before, the row came from the wrong place in the
  data. `New-UDEChart` and `Set-UDEChartData` never send such entries. This affects only an app that
  sets the data another way, such as `Set-UDElement -Properties @{ data = ... }`.

### Changed

- **Breaking:** the chart's own texts follow `-Locale`, or the browser's language without it, as
  ECharts' texts do: the toolbox buttons, "Total" in a stack's tooltip, the box plot statistics and its
  "Outliers" series, the histogram's "Count" axis, the candlestick's "Price" and "Volume" series, and
  "No data". Before, they were English in every language.
  - Who is affected: an app with a `-ColorMap` entry or a click handler that names "Outliers",
    "Volume" or "Price".
  - What to do: set `-Locale` on that chart and name the series in that language, or set
    `-Locale en-US` to keep the English names.
- `ConvertTo-PSUComponentData`, the data conversion all modules share, keeps its C# converter in
  `RowConverter.cs` and its helpers one function per file. The rows it returns are unchanged.
- The module's code is one function per file in `Public/` and `Private/`; the `.psm1` only loads them.
  `New-UDEChart` runs its steps through helpers. Commands, parameters, help and output are unchanged
  ([#169](https://github.com/eizedev/powershell-universal-components/issues/169)).
- The help of `-Value`, `-Path`, `-Source` and `-Target` names every chart type that reads them.

## [0.3.1] - 2026-11-22

### Fixed

- `Get-UDElement -Id <chart id>` returns the last click (`.selected`), range (`.range`) and zoom
  (`.zoom`), as documented. It returned the string `"null"` on PSU 2026.3.4. It returns only
  these and the id, not the chart's data
  ([#159](https://github.com/eizedev/powershell-universal-components/issues/159)).
  The answer comes from `shared/js/elementState.js`, new in the repository's shared code.

## [0.3.0] - 2026-11-09

### Added

- `-TooltipMode Auto | Item | Axis | None`, or a hashtable per chart type (`@{ line = 'Axis'; '*' = 'Auto' }`)
  to set it for every chart of an app with `$PSDefaultParameterValues`.
- `Private/SHARED.txt` in the built module: the content hashes of the repository's `shared/` code it was
  built from, to compare two builds or releases.

### Changed

- **Breaking:** tooltips of bar, line, area and step charts show the element under the pointer: a bar,
  a stacked segment (with the stack total) or a line point alone; between them all series at that
  position, between stacked bars the total only. Before, every series at the position was listed, also
  when the pointer was on one segment.
  - Who is affected: readers who compare the series of a position in the tooltip.
  - What to do: `-TooltipMode Axis` lists every series at the position as before.
- Stacked tooltips have a total row in every mode (with `-SecondaryY` one per axis); switching line,
  bar or stack in the toolbox is followed, Restore goes back. The tooltip text of these charts is the
  module's own now: one line per series (`Name: value`), series without a value at that position left
  out (ECharts showed "-").
- A hovered bar or polar bar lights up alone instead of its whole series, matching the tooltip.
- Data conversion is about ten times faster (a DataTable of 5000 rows and 12 columns: 2.4 to 2.9 s
  before, about 40 ms now, measured on a PSU test instance): no function call per cell, and large
  DataTables go through a small class compiled on first use (Add-Type, once per PSU process). The rows
  the component gets are the same as before.

## [0.2.0] - 2026-11-06

### Added

- `-ColorMap @{ Failed = '#E3000F'; Success = '#287233' }`: a fixed colour per category name for series,
  data items and gantt groups of every chart type, optionally one per mode; the documentation lists
  the palette order per type.
- `--psu-chart-font-size` in the app's stylesheet sets the base text size of every chart: axis labels,
  legend, data labels, tooltips and titles grow or shrink by the same factor, also in narrow charts.

### Fixed

- The first and last label of a time axis are aligned inwards: a tick at the edge of a narrow chart
  is no longer cut ("07:0").
- Radial bar values at the end of rings on the lower half of the circle read upright instead of upside
  down.
- Time axes without `-XFormat` (line, area, bar, gantt, themeriver) write the date where a day starts
  ("5 Nov" in the chart's locale) instead of the bare day number, and times and month names in
  `-Locale`.
- Funnel stages too small for their label (the last stages, or all stages of a low chart with many of
  them) put the label on one line right of a narrower funnel, in the page's text colour, instead of
  letting it run out of the stage (dark text on the page background in dark mode) or over the
  neighbouring labels; hidden only when there is no room at all.
- Layered network graphs (`-Layout Layered`) stay clear of legend and toolbox and keep their nodes and
  labels inside the chart in narrow containers; their nodes stay round at every chart shape.
- Radial bar names no longer run under the round ends of the rings.

## [0.1.0] - 2026-11-06

### Added

- `New-UDEChart` with 29 chart types on Apache ECharts 6.1: line, area, step, bar, scatter, pie, donut,
  funnel, heatmap, calendar, boxplot, histogram, candlestick, gauge, radar, sankey, treemap, sunburst,
  waterfall, gantt, graph (force, circular or layered, with edge labels), tree, chord, parallel,
  themeriver, matrix (sparklines per row and column), polar, radialbar, bump.
- Labels and tooltips from the row behind a point (`-LabelColumn`, `-LabelTemplate`,
  `-TooltipColumns`, `-TooltipTemplate`) with named formats; tooltip values HTML-escaped.
- Pins (`-MarkPoint`), linear trends with forecast and target date (`-Trend`, `-Forecast`,
  `-TrendTarget`), shaded bands (`-Band`), time windows (`-MarkArea`), gauge styles and thresholds,
  rose charts, bubble size (`-Size`), legend placement and type (`-Legend`, `-LegendType`),
  `-Thresholds` colouring line stretches, `-ClassName` and `-Style`, a full screen button.
- An error naming the data's columns when a column parameter matches none; "No data" for empty data
  (`-EmptyText`); a warning for parameters the chart type does not read.
- Chart types `polar`, `radialbar` and `bump`; `-Aggregate Sum | Avg | Count | Min | Max`.
- `-EventColumns`: only these columns of a row travel back with click and selection events.
- Corporate design: `-LightTheme`/`-DarkTheme` (hashtable or theme builder JSON) and CSS custom
  properties `--psu-chart-*`.
- Data straight from DataTables (DBNull as null), PowerShell objects, REST results and script blocks;
  column names matched without regard to case.
- Zoom (wheel, box, slider; on the value axis with `-ZoomAxis`), range selection (`-Brush`), linked
  charts (`-Group`), legend toggles, hover highlighting, toolbox with PNG, CSV and Excel export
  (`-ExportColumns` with titles and types).
- Events `-OnClick`, `-OnSelect`, `-OnZoom`, `-OnLegendChange` with `$EventData`.
- Light and dark theme following the app's switch; layout rules for narrow containers.
- Named formats (`-Format`, `-LabelFormat`): number, currency, percent, compact, bytes, duration, dates.
- Reference lines (`-MarkLine`: median, average, min, max or fixed values), second value axis,
  `-Stacked`, `-Normalize` (100 %), `-Horizontal`, `-LogScale`, `-NegativeColor`.
- Axis breaks (`-Breaks`, `-YBreaks`) and `New-UDEChartTimeBreak` for nights and weekends; small
  multiples (`-Facet`); sparklines (`-Sparkline`).
- `Set-UDEChartData` for live updates that keep zoom and hidden series.
- `-Options` with the full Apache ECharts option, merged over the generated one.

### Fixed

- Resizing waits for the next frame, so WebKit (Safari) no longer reports a ResizeObserver loop.
- Charts without a grid (funnel, treemap, pie, donut, sunburst, gauge, polar, radialbar, radar) keep
  their plot clear of title, toolbox and legend at every size: a legend that wraps over several lines
  (`-LegendType Plain`) no longer covers the lowest funnel stage, the toolbox no longer sits on a
  treemap, sunburst or funnel. Boxplots start below the toolbox as the other cartesian charts do.
- Labels inside funnel stages, pie slices, treemap tiles and sunburst rings take dark or white text,
  whichever contrasts more with the fill, so they stay readable on palettes with dark and light colours.

[Unreleased]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.ECharts-v0.3.1...HEAD
[0.3.1]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.ECharts-v0.3.0...PowerShellUniversal.Component.ECharts-v0.3.1
[0.3.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.ECharts-v0.2.0...PowerShellUniversal.Component.ECharts-v0.3.0
[0.2.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.ECharts-v0.1.0...PowerShellUniversal.Component.ECharts-v0.2.0
[0.1.0]: https://github.com/eizedev/powershell-universal-components/releases/tag/PowerShellUniversal.Component.ECharts-v0.1.0
