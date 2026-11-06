# ECharts

`New-UDEChart` draws interactive [Apache ECharts](https://echarts.apache.org/) charts in PSU apps: name
the columns of the data, pick a type, and the chart comes with zoom, tooltips, range selection, click
events, light and dark theme and CSV/Excel export.

```powershell
Install-PSResource -Name PowerShellUniversal.Component.ECharts
```

## First charts

### A bar chart from any PowerShell objects

--8<-- "examples/a-bar-chart-from-any-powershell-objects.md"

### Long data: one series per group

--8<-- "examples/long-data-one-series-per-group.md"

## Chart types

| `-Type` | Columns | Notes | Examples |
| --- | --- | --- | --- |
| `line`, `area`, `step`, `bar`, `scatter` | `-X`, `-Y` (one or more), `-GroupBy` | `-Stacked`, `-Normalize` (100 %), `-Horizontal`, `-Smooth`, `-SecondaryY`, `-LogScale` | [Bars](bars.md), [Lines and time](lines-and-time.md) |
| `pie`, `donut`, `funnel` | `-X` (name), `-Y` (value) | labels with value and share | [Shares](shares.md) |
| `heatmap` | `-X`, `-Y` (categories), `-Value` | colour scale with `-Min`, `-Max` | [Heatmaps and calendars](heatmaps.md) |
| `calendar` | `-X` (date), `-Y` | one calendar per year, limited to the days with data | [Heatmaps and calendars](heatmaps.md) |
| `boxplot` | `-X` (group), `-Y` (values) | quartiles, whiskers and outliers are computed | [Distributions](distributions.md) |
| `histogram` | `-Y` (values), `-Bins` | median line unless `-MarkLine` says otherwise | [Distributions](distributions.md) |
| `candlestick` | `-X` (date), `-Open`, `-Close`, `-Low`, `-High`, `-Volume` | volume in its own panel | [Finance](finance.md) |
| `gauge` | `-Y` (first row), `-Min`, `-Max` | `-GaugeStyle Progress \| Ring \| Grade`, `-Thresholds` | [Operations](operations.md) |
| `radar` | `-X` (series name), `-Y` (axes) | | [Comparisons](comparisons.md) |
| `sankey` | `-Source`, `-Target`, `-Value` | | [Relations](relations.md) |
| `treemap`, `sunburst` | `-Path` (columns from the root, or one column "a/b/c"), `-Y` | click to zoom in | [Shares](shares.md) |
| `waterfall` | `-X` (step), `-Y` (change), `-Totals` | steps in `-Totals` show the running total | [Finance](finance.md) |
| `gantt` | `-X` (lane), `-Start`, `-End`, `-GroupBy` (colour), `-Value` (label) | backup windows, maintenance, on-call; zoom along time | [Operations](operations.md) |
| `graph` | `-Source`, `-Target`, `-GroupBy`, `-TargetGroup` | dependencies and topology; `-Layout Force \| Circular \| Layered`, `-EdgeLabel` (ports on the lines), `-Undirected` | [Relations](relations.md) |
| `tree` | `-Path` (levels, or one column "a/b/c") | folders, vCenter > cluster > host > VM; `-Orient LR \| TB \| Radial`, `-Depth`, `-RootName` | [Relations](relations.md) |
| `chord` | `-Source`, `-Target`, `-Value` | overlaps or hand-overs between the same set of things | [Relations](relations.md) |
| `parallel` | `-Y` (axes), `-X` (name), `-GroupBy` | many items across many measures; drag along an axis to filter | [Comparisons](comparisons.md) |
| `themeriver` | `-X` (date), `-GroupBy`, `-Y` | how a mix of categories changes over time | |
| `matrix` | `-Y` (rows), `-GroupBy` (columns), `-X` (inside a cell), `-Value`, `-CellType` | a table of sparklines, e.g. KPIs per customer; one scale per column | [Comparisons](comparisons.md) |
| `polar` | `-X` (around the circle), `-Y` or `-GroupBy` | hours of the day, weekdays; `-Stacked` | [Comparisons](comparisons.md) |
| `radialbar` | `-X` (one ring each), `-Y`, `-Max` | progress per customer or service; the longest ring is three quarters of the circle | [Comparisons](comparisons.md) |
| `bump` | `-X` (period), `-GroupBy` (item), `-Y` (value) | the rank of each item per period, highest value first | [Comparisons](comparisons.md) |

More: `-Facet <column>` draws one small chart per value with a shared scale (small multiples),
`-Sparkline` a tiny trend without axes for tiles (line, area, bar), `-Breaks`/`-YBreaks` cut ranges out
of an axis, `-Rose` turns a pie into a Nightingale chart, `-Band Low, High` shades a range, `-MarkArea`
marks a time window. Everything else in Apache ECharts is one [`-Options`](options.md) hashtable away;
[the gallery page](gallery.md) maps the Apache ECharts gallery to parameters.

All parameters: [Reference](reference.md).
