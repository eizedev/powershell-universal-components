# Apache ECharts gallery and this module

How the examples of the [Apache ECharts gallery](https://echarts.apache.org/examples/en/index.html)
(about 300, ECharts 6.1) map to `New-UDEChart`. The module bundles all of Apache ECharts, so every
series type and option is available through `-Options`; the parameters cover what is needed often.

- **Parameter**: a parameter of `New-UDEChart` does it.
- **-Options**: possible with `-Options` on top of a chart type; *tested* means a showcase chart uses it.
- **Server side**: done in PowerShell before the data reaches the chart.
- **Not included**: needs something the module does not ship, or does not fit an app; the reason is given.

## Line and area

| Gallery | How |
| --- | --- |
| basic, smooth, step, stacked, stacked area, gradient area | Parameter: `-Type line/area/step`, `-Smooth`, `-Stacked` |
| time axis, large area with zoom (area-simple) | Parameter: time axis is detected; `-Zoom` |
| log axis | Parameter: `-LogScale` |
| marker lines, average/min/max (line-marker, line-markline) | Parameter: `-MarkLine`, `-MarkPoint` |
| sections and pieces coloured by value (line-sections, area-pieces) | Parameter: `-Thresholds` |
| confidence band | Parameter: `-Band Low, High` |
| intraday with breaks | Parameter: `-Breaks`, `New-UDEChartTimeBreak` |
| several y axes (multiple-y-axis) | Parameter: `-SecondaryY` (two axes) |
| sparklines in a table (matrix-sparkline) | Parameter: `-Type matrix` |
| bump chart (rank over time) | Parameter: `-Type bump` |
| line on a category y axis (line-y-category) | -Options |
| two grids linked (grid-multiple), several x axes | Parameter: two charts with the same `-Group` |
| dynamic data, line race | Parameter: `Set-UDEChartData` (live updates); the race animation via -Options |
| polar lines (line-polar) | -Options (polar coordinate system); polar bars: `-Type polar` |
| line-function, line-draggable, line-pen, fisheye, easing, line-graphic | Not included: drawing and animation demos, no data use in an app |

## Bar

| Gallery | How |
| --- | --- |
| basic, horizontal, stacked, negative, labels, rotation, background, data colour | Parameter: `-Horizontal`, `-Stacked`, `-DataLabels`, `-NegativeColor`, `-Palette` |
| normalized stack (bar-stack-normalization) | Parameter: `-Normalize` |
| waterfall | Parameter: `-Type waterfall` |
| brush select (bar-brush) | Parameter: `-Brush`, `-OnSelect` |
| mix line and bar, zoom on value (mix-zoom-on-value) | Parameter: `-SecondaryY`, `-ZoomAxis Y`; -Options for the series type (tested) |
| axis breaks (bar-breaks-simple, bar-breaks-brush) | Parameter: `-YBreaks` |
| large bars | Parameter: sampling and large mode above 20,000 points |
| sorted bars (data-transform-sort-bar) | Server side: `Sort-Object` |
| drill-down (bar-drilldown, bar-multi-drilldown) | Server side: `-OnClick` plus `Set-UDEChartData` with the level below |
| rich text labels, rounded stacks, gradient | -Options (`itemStyle`, `label.rich`); rounded bars tested |
| bar race | -Options (`realtimeSort`) with `Set-UDEChartData` |
| polar and radial bars (bar-polar-*, polar-roundCap) | Parameter: `-Type polar` (categories around), `-Type radialbar` (rings with round caps) |
| animation delay, watermark, timeline finance | Not included as parameters: decoration; timeline via -Options |

## Pie, funnel, gauge

| Gallery | How |
| --- | --- |
| pie, doughnut, rose, rounded, pad angle, legend, label alignment | Parameter: `-Type pie/donut`, `-Rose`, `-Legend`, `-LegendType` |
| half donut | -Options (`startAngle`, `endAngle`), tested |
| nested pie (pie-nest), several pies (data-transform-multiple-pie) | Parameter: several charts, or -Options for a second series |
| pattern fill (pie-pattern) | Parameter: `-Decal` |
| funnel, aligned and several funnels | Parameter: `-Type funnel`; several via -Options |
| gauge, progress, ring, grade, stage, multi-title | Parameter: `-Type gauge`, `-GaugeStyle`, `-Thresholds` |
| speedometer, clock, car, barometer, temperature | -Options; no parameter, these are styling variants |

## Scatter

| Gallery | How |
| --- | --- |
| scatter, bubble, large scatter | Parameter: `-Type scatter`, `-Size` |
| linear regression | Parameter: `-Trend Linear` (with `-Forecast`, `-TrendTarget`) |
| exponential, logarithmic, polynomial regression, clustering | Server side: compute in PowerShell and pass the fitted line as a series; not built in |
| punch card (weekday x hour) | Parameter: `-Type heatmap` or a bubble scatter |
| single axis scatter, scatter matrix (SPLOM), jitter | -Options, untested |
| effect scatter (ripples) | -Options (`type = 'effectScatter'`), untested |
| scatter on maps (scatter-map, effectScatter-bmap) | Not included: needs map data (see Maps) |

## Statistics and finance

| Gallery | How |
| --- | --- |
| boxplot, several boxplots | Parameter: `-Type boxplot` (quartiles computed) |
| histogram | Parameter: `-Type histogram`, `-Bins` |
| candlestick with volume, brush, large | Parameter: `-Type candlestick`, `-Volume` |
| OHLC bars (custom-ohlc), error bars (custom-error-bar) | Not included: custom series need a JavaScript `renderItem` function, which PowerShell cannot send |

## Heatmap and calendar

| Gallery | How |
| --- | --- |
| cartesian heatmap, large heatmap, piecewise colours | Parameter: `-Type heatmap`; piecewise via -Options (`visualMap`) |
| correlation and confusion matrix (matrix-correlation-heatmap, matrix-confusion) | Parameter: `-Type heatmap` |
| calendar heatmap, vertical and horizontal | Parameter: `-Type calendar` |
| calendar with pies, graphs or icons in the days, lunar calendar | Not included: decoration and Chinese calendar |
| heatmap on a map (heatmap-map, heatmap-bmap) | Not included: needs map data |

## Relations and hierarchies

| Gallery | How |
| --- | --- |
| graph force, circular, labels, dynamic | Parameter: `-Type graph`, `-Layout Force/Circular/Layered`, `-EdgeLabel` |
| dependency graphs (graph-webkit-dep, graph-npm) | Parameter: `-Type graph`; thousands of nodes are slow in a force layout |
| sankey, vertical, node alignment, levels | Parameter: `-Type sankey`; orientation and alignment via -Options |
| chord | Parameter: `-Type chord` |
| tree: basic, orient, radial, legend, polyline | Parameter: `-Type tree`, `-Orient`, `-Depth`; polyline edges via -Options (`edgeShape`) |
| treemap, drill-down, show parent, sunburst | Parameter: `-Type treemap/sunburst` |
| treemap-sunburst transition | Not included: animation demo |
| parallel coordinates | Parameter: `-Type parallel`, selection fires `-OnSelect` |
| theme river | Parameter: `-Type themeriver` |
| radar, several radars | Parameter: `-Type radar` |

## Matrix (new in ECharts 6)

| Gallery | How |
| --- | --- |
| sparklines and mini bars per cell (matrix-sparkline, matrix-mini-bar-data-collection) | Parameter: `-Type matrix`, `-CellType Line/Area/Bar` |
| correlation, covariance, confusion | Parameter: `-Type heatmap` |
| pies, graphs or stock charts in cells, grid layout, periodic table, MBTI | -Options for the matrix itself; charts in cells other than lines and bars are not built in |
| mini bars on a map (matrix-mini-bar-geo) | Not included: needs map data |

## Gantt and custom series

| Gallery | How |
| --- | --- |
| gantt (custom-gantt-flight) | Parameter: `-Type gantt` (built in, no JavaScript needed) |
| profile, hexbin, wind, flame graph, polar heatmap, spiral, parliament, circle packing | Not included: custom series need a JavaScript `renderItem` function; a dedicated chart type can be added on request |

## Maps and geo

`map`, `geo`, `lines` (flight routes) and everything with `bmap` are **not included**: a map needs its
GeoJSON or SVG registered in the browser with `echarts.registerMap`, which the module does not ship and
PowerShell cannot call; `bmap` needs the Baidu Maps API online. A parameter that takes GeoJSON from
PowerShell (sites, data centres, customers per country) is a possible extension.

## 3D, globe, GL

Not included: they need the separate `echarts-gl` package, and they rarely help to read operational data.

## Data handling (dataset, transform)

Server side: shape the data in PowerShell (`Sort-Object`, `Where-Object`, `Group-Object`) and pass the
result; `dataset` and `transform` are used through -Options only if needed.

## Interaction and decoration

| Gallery | How |
| --- | --- |
| data zoom (inside, slider, on value) | Parameter: `-Zoom`, `-ZoomAxis` |
| touch tooltips (line-tooltip-touch, candlestick-touch) | Parameter: tooltips are on; `confine` keeps them inside the chart |
| rich text labels | -Options (`label.rich`) |
| graphic elements, loading, stroke and wave animations, symbol morphing | Not included: decoration |
