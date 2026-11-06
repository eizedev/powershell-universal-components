# Changelog

All notable changes to PowerShellUniversal.Component.ECharts. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

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
