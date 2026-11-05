# PowerShellUniversal.Component.ECharts

Interactive [Apache ECharts](https://echarts.apache.org/) charts for PowerShell Universal apps. Pass the
data as it comes - a DataTable from SQL, objects from `Invoke-RestMethod` or any PowerShell command -
name the columns, and the chart is drawn in the browser with zoom, tooltips, range selection, click
events, light and dark theme and CSV/Excel export.

```powershell
New-UDEChart -Data (Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, CPU) -Type bar -X Name -Y CPU
```

Requires PowerShell Universal 2026 (PowerShell 7.4+). Tested on PSU 2026.3.4.

## Install

```powershell
Install-PSResource -Name PowerShellUniversal.Component.ECharts
```

or copy the built module folder into `Modules/PowerShellUniversal.Component.ECharts/<version>/` of your
PSU repository. Then use `New-UDEChart` in any app.

## Data

`-Data` takes a `System.Data.DataTable` or `DataView` (SqlClient, ODBC), DataRows, PSCustomObjects,
hashtables, or a script block returning any of these. `DBNull` becomes an empty value, dates become ISO
8601 (the time axis picks them up), TimeSpans become seconds. Column names are matched without regard to
case, so `-X Team` finds `team`.

Wide data has one column per series (`-Y Opened, Closed`); long data has one row per series and point
(`-Y Tickets -GroupBy Team` draws one series per team).

## Chart types

| `-Type` | Columns | Notes |
| --- | --- | --- |
| `line`, `area`, `step`, `bar`, `scatter` | `-X`, `-Y` (one or more), `-GroupBy` | `-Stacked`, `-Normalize` (100 %), `-Horizontal`, `-Smooth`, `-SecondaryY`, `-LogScale` |
| `pie`, `donut`, `funnel` | `-X` (name), `-Y` (value) | labels with value and share |
| `heatmap` | `-X`, `-Y` (categories), `-Value` | colour scale with `-Min`, `-Max` |
| `calendar` | `-X` (date), `-Y` | one calendar per year, limited to the days with data |
| `boxplot` | `-X` (group), `-Y` (values) | quartiles, whiskers and outliers are computed |
| `histogram` | `-Y` (values), `-Bins` | median line unless `-MarkLine` says otherwise |
| `candlestick` | `-X` (date), `-Open`, `-Close`, `-Low`, `-High`, `-Volume` | volume in its own panel |
| `gauge` | `-Y` (first row), `-Min`, `-Max` | |
| `radar` | `-X` (series name), `-Y` (axes) | |
| `sankey` | `-Source`, `-Target`, `-Value` | |
| `treemap`, `sunburst` | `-Path` (columns from the root, or one column "a/b/c"), `-Y` | click to zoom in |
| `waterfall` | `-X` (step), `-Y` (change), `-Totals` | steps in `-Totals` show the running total |
| `gantt` | `-X` (lane), `-Start`, `-End`, `-GroupBy` (colour), `-Value` (label) | backup windows, maintenance, on-call; zoom along time |
| `graph` | `-Source`, `-Target`, `-GroupBy`, `-TargetGroup` | dependencies and topology; `-Layout Force \| Circular \| Layered`, `-EdgeLabel` (ports on the lines), `-Undirected` |
| `tree` | `-Path` (levels, or one column "a/b/c") | folders, vCenter > cluster > host > VM, repository > job > VM; `-Orient LR \| TB \| Radial`, `-Depth`, `-RootName` |
| `chord` | `-Source`, `-Target`, `-Value` | overlaps or hand-overs between the same set of things |
| `parallel` | `-Y` (axes), `-X` (name), `-GroupBy` | many items across many measures; drag along an axis to filter |
| `themeriver` | `-X` (date), `-GroupBy`, `-Y` | how a mix of categories changes over time |

More: `-Facet <column>` draws one small chart per value with a shared scale (small multiples),
`-Sparkline` a tiny trend without axes for tiles (line, area, bar), `-Breaks`/`-YBreaks` cut ranges out
of an axis, `-GaugeStyle Progress | Ring | Grade` and `-Thresholds` shape a gauge, `-Rose` turns a pie
into a Nightingale chart, `-Band Low, High` shades a range, `-MarkArea` marks a time window.

## Interaction

On by default: tooltips, hover highlighting, legend toggles, zoom with the mouse wheel, and a toolbox with
box zoom, line/bar/stack switch, restore, PNG, CSV and Excel. Options:

| Parameter | Effect |
| --- | --- |
| `-Zoom Inside \| Slider \| Both \| None` | wheel/drag zoom, a slider, both or none |
| `-ZoomAxis X \| Y \| Both` | zoom along the data (X) or the value axis (Y); with Both, Shift + wheel zooms Y |
| `-Brush` | select a range with the mouse (toolbox button) |
| `-Group <name>` | charts with the same group share tooltip, zoom and legend |
| `-NoToolbox`, `-NoExport` | hide the toolbox or its CSV/Excel buttons |
| `-ExportColumns` | export columns in order, with `title`, `type` (text, number, integer, currency, percent, date, datetime, boolean) and `format` |

Events run a script block on the server; `$EventData` holds what happened:

```powershell
New-UDEChart -Data $byTeam -Type bar -X Team -Y Tickets -GroupBy Priority -Stacked -OnClick {
    # $EventData: seriesName, seriesIndex, dataIndex, name, value, row (the clicked data row)
    $Session:Filter = @{ Team = $EventData.name; Priority = $EventData.seriesName }
    Sync-UDElement -Id 'ticket-table'
}

New-UDEChart -Data $daily -Type bar -X Day -Y Opened -Brush -OnSelect {
    # $EventData: from, to (ISO dates on a time axis, category names on a category axis)
    Show-UDToast -Message "$($EventData.from) .. $($EventData.to)"
}
```

`-OnZoom` gets `from`, `to`, `start`, `end`; `-OnLegendChange` gets `name` and `selected`. The last click,
range and zoom are also in the component's state (`Get-UDElement`).

## Labels and tooltips

Labels and tooltips can come from the row behind each point, for every chart type:

```powershell
New-UDEChart -Data $vms -Type tree -Path Folder -LabelTemplate '{Name} ({Cpu} vCPU)' `
    -TooltipColumns 'vCPU=Cpu', 'Memory (GB)=RamGB:integer', 'Disk=DiskBytes:bytes', 'PowerState'
New-UDEChart -Data $links -Type graph -Source From -Target To `
    -TooltipTemplate "{From} > {To}`nVLAN: {Vlan}`nLoad: {Load:percent100:0}"
```

A placeholder `{Column}` or `{Column:format}` takes any format of `-Format`; a list column is joined with
commas; `` `n `` starts a new line. `-LabelColumn Name` is the short form of `-LabelTemplate '{Name}'`.
`-TooltipColumns` entries are `Column`, `Column:format` or `Label=Column:format`. Points without a row of
their own (a tree's folders, aggregated nodes) keep their name. Values are HTML-escaped in tooltips.

`-Legend Bottom | Top | Left | Right | None` places the legend; `-LegendType Scroll` (default) pages
through entries that do not fit, `Plain` wraps them over several lines.

## Formats

`-Format` applies to axis, tooltip and labels; `-LabelFormat` to value labels only (default: the short
form of `-Format` for numbers of 10,000 and more). Numbers and dates use the browser's language or
`-Locale` (e.g. `de-DE`).

`number`, `number:2`, `integer`, `currency`, `currency:USD`, `compactcurrency:EUR`, `percent` (0.25 ->
25 %), `percent100` (25 -> 25 %), `compact` (1.2M), `bytes`, `duration` (seconds), `duration:min`,
`duration:h`, `date`, `datetime`, `time`, `text`.

## Reference lines, pins and trends

`-MarkLine 'median', 'average'` per series, or fixed lines: `@{ value = 48; name = 'SLA'; color = '#e53935' }`
(`axis = 'x'` for a vertical line).

`-MarkPoint 'max', 'min'` pins those values on every series; `@{ x = 'Thu'; y = 306; label = 'Outage' }`
pins one point (add `series = 'Mail'` for another series than the first).

`-Trend Linear` adds a dashed least-squares line per series. On a time or value axis, `-Forecast 6`
continues it six steps of the data, and `-TrendTarget 100` continues it until it reaches 100 and marks the
date - when a datastore is full or a licence count is used up:

```powershell
New-UDEChart -Data $fill -Type line -X Day -Y Used -Format 'percent100:0' -Trend Linear -TrendTarget 100
```

## Axis breaks

Cut nights and weekends out of a time axis, so business hours fill the chart:

```powershell
$breaks = New-UDEChartTimeBreak -From $from -To $to -DayStart '07:00' -DayEnd '19:00' -Weekends
New-UDEChart -Data $samples -Type line -X Time -Y ResponseMs -Breaks $breaks -MarkLine @{ value = 600; name = 'SLA' }
```

`-YBreaks @{ start = 120; end = 1750 }` keeps small bars readable next to one huge one.

## Layout

`-Height` (default `400px`, also `100%` inside a container with a fixed height) and `-Width` (default:
the container's width) size the chart; `-Id`, `-ClassName` and `-Style` work as on PSU's own components.
The chart follows its container's size, also when it was created hidden and shown later: tested in
`New-UDStack`, `New-UDGrid`, `New-UDPaper`, `New-UDTabs` (with and without `-RenderOnActive`),
`New-UDExpansionPanel`, `Show-UDModal` and `New-UDDynamic -AutoRefresh` (showcase page "Layouts"). In a
row of a flex container (`New-UDStack -Direction row`), the items share the row with
`-Style @{ flex = '1 1 0'; minWidth = 0 }` on their `New-UDPaper` (as on the showcase page).

## Theme

Light and dark follow the app's theme switch (`Theme Auto`); `-Theme Light` or `Dark` pins one.
`-Palette` sets the series colours, `-Decal` adds patterns for colour-blind readers and print.

## Everything else: -Options

`-Options` takes any [Apache ECharts option](https://echarts.apache.org/en/option.html) and is merged
over what the parameters generated: objects key by key, arrays element by element (`series[0]` changes the
first series), an object given for an array (`yAxis = @{...}`) applies to every element.

```powershell
New-UDEChart -Data $rows -Type bar -X Month -Y Tickets, SLA -SecondaryY SLA -Options @{
    series = @(@{ itemStyle = @{ borderRadius = 4 } }, @{ type = 'line'; smooth = $true })
}
```

The ECharts instance is reachable in the browser as `document.getElementById('<id>').querySelector('div').echarts`.

## Live updates

```powershell
New-UDEChart -Id 'cpu' -Data @() -Type line -X Time -Y Load
New-UDElement -Tag div -AutoRefresh -RefreshInterval 5 -Endpoint {
    Set-UDEChartData -Id 'cpu' -Data (Get-MyCounters)    # zoom and hidden series stay
}
```

## Examples

[examples/showcase.ps1](examples/showcase.ps1) is a complete app: basics, every bar variant, a ticket
report (lead time distribution with SLA, boxplots per team, previous period, calendar, weekday x hour,
sankey, click and range filters on a table), finance (waterfall, plan vs actual, YTD, treemap,
candlestick), managed services (VMware, storage, network, backup, availability), operations (backup
gantt, maintenance windows, capacity forecast, dependencies), a data platform that combines many source
systems (coverage matrix with a gap table, sources per asset, backup and EDR gaps, shared assets,
freshness, findings over time, servers across all measures, VM folders, backup jobs, network path,
asset 360, datastore trend), calendar heatmaps, intraday charts with axis breaks and small multiples,
public APIs, PowerShell and DataTable data, live data and a benchmark.

## Apache ECharts gallery

[docs/gallery.md](docs/gallery.md) maps the examples of the Apache ECharts gallery to parameters,
`-Options`, PowerShell-side preparation, or says why one is not included (maps, 3D, custom series).

## Limits

- Keyboard navigation inside a chart is not supported by Apache ECharts; the data stays reachable
  through export and tooltips.
- PSU provides React 18.3.1; the module does not bundle React.
- Above 20,000 points per chart, points are drawn with sampling (LTTB) and click events carry values
  but no row.

## License

MIT. Includes Apache ECharts (Apache-2.0) and fflate (MIT).
