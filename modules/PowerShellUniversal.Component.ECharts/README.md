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

More: `-Facet <column>` draws one small chart per value with a shared scale (small multiples),
`-Sparkline` a tiny trend without axes for tiles, `-Breaks`/`-YBreaks` cut ranges out of an axis.

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

## Formats

`-Format` applies to axis, tooltip and labels; `-LabelFormat` to value labels only (default: the short
form of `-Format` for numbers of 10,000 and more). Numbers and dates use the browser's language or
`-Locale` (e.g. `de-DE`).

`number`, `number:2`, `integer`, `currency`, `currency:USD`, `compactcurrency:EUR`, `percent` (0.25 ->
25 %), `percent100` (25 -> 25 %), `compact` (1.2M), `bytes`, `duration` (seconds), `duration:min`,
`duration:h`, `date`, `datetime`, `time`, `text`.

## Reference lines

`-MarkLine 'median', 'average'` per series, or fixed lines: `@{ value = 48; name = 'SLA'; color = '#e53935' }`
(`axis = 'x'` for a vertical line).

## Axis breaks

Cut nights and weekends out of a time axis, so business hours fill the chart:

```powershell
$breaks = New-UDEChartTimeBreak -From $from -To $to -DayStart '07:00' -DayEnd '19:00' -Weekends
New-UDEChart -Data $samples -Type line -X Time -Y ResponseMs -Breaks $breaks -MarkLine @{ value = 600; name = 'SLA' }
```

`-YBreaks @{ start = 120; end = 1750 }` keeps small bars readable next to one huge one.

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

[examples/showcase.ps1](examples/showcase.ps1) is a complete app with ten pages: basics, every bar
variant, a ticket report (lead time distribution with SLA, boxplots per team, previous period,
calendar, weekday x hour, sankey, click and range filters on a table), finance (waterfall, plan vs
actual, YTD, treemap, candlestick), managed services (VMware, storage, network, backup, availability),
calendar heatmaps, intraday charts with axis breaks and small multiples, public APIs, PowerShell and
DataTable data, live data and a benchmark.

## Limits

- Keyboard navigation inside a chart is not supported by Apache ECharts; the data stays reachable
  through export and tooltips.
- PSU provides React 18.3.1; the module does not bundle React.
- Above 20,000 points per chart, points are drawn with sampling (LTTB) and click events carry values
  but no row.

## License

MIT. Includes Apache ECharts (Apache-2.0) and fflate (MIT).
