# Themes and corporate design

Light and dark follow the app's theme switch (`-Theme Auto`); `-Theme Light` or `Dark` pins one.
`-Palette` sets the series colours, `-Decal` adds patterns for colour-blind readers and print. The
charts on this site follow its light/dark switch the same way.

A corporate design comes in two ways, both optional.

## An ECharts theme per mode

`-LightTheme` and `-DarkTheme` take a hashtable or the path of a theme JSON file as the
[Apache ECharts theme builder](https://echarts.apache.org/en/theme-builder.html) downloads it
("Download theme", then JSON; the builder's project export is a different format). It is merged over
the module's own theme: what it sets wins, the rest stays (so a palette-only theme keeps the readable
axes).

--8<-- "examples/corporate-design.md"

For every chart of an app:

```powershell
$PSDefaultParameterValues['New-UDEChart:LightTheme'] = "/path/on/the/psu/server/corporate-light.json"
$PSDefaultParameterValues['New-UDEChart:DarkTheme'] = "/path/on/the/psu/server/corporate-dark.json"
```

## CSS custom properties

In the app's stylesheet: `--psu-chart-1` ... `--psu-chart-12` (the N-th series colour; positions
without a property keep theirs), `--psu-chart-text`, `--psu-chart-muted`, `--psu-chart-axis`,
`--psu-chart-grid`, `--psu-chart-tooltip`, `--psu-chart-tooltip-border`, `--psu-chart-accent`. Set them
per mode:

```css
:root { --psu-chart-1: #003b6f; --psu-chart-2: #f28c28; --psu-chart-text: #1f2430; }
:root[data-theme="dark"] { --psu-chart-1: #6fa8dc; --psu-chart-2: #f6b26b; --psu-chart-text: #e6e9ef; }
```

`--psu-chart-font-size` sets the base text size of every chart (ECharts' own is 12 px), in `px`, a bare
number or `rem`/`em`, between 8 and 32 px. Axis labels, legend, data labels, tooltips and titles grow
or shrink by the same factor (14 px: titles 21 px instead of 18), also the smaller sizes of narrow
charts ([Layout](layout.md)):

```css
:root { --psu-chart-font-size: 14px; }
```

The properties are read from the page root (`:root`), so they apply to every chart of the app. An app
sets them in its stylesheet (`New-UDApp -Stylesheets`, see [Pivot themes](../pivot/themes.md#adding-the-stylesheet-to-an-app)), or on the page with
`New-UDHtml -Markup '<style>:root { --psu-chart-font-size: 14px; }</style>'`. They apply to the whole
page, so this site shows no live example of them (it would restyle every chart here). The pivot report
reads the same properties, so one stylesheet themes both: [Pivot themes and corporate design](../pivot/themes.md).

## Fixed colours per category

Palette colours go by position, so a category's colour depends on which categories the data has.
`-ColorMap` fixes a colour per name, for every chart type: series names (`-Y` columns, `-GroupBy`
values, gantt groups) and data item names (pie, donut and funnel slices, treemap and sunburst nodes at
every level, sankey and graph nodes, radar areas, the rings of a radial bar with one `-Y`). Names match
without regard to case; categories not in the map keep the palette. Two colours give one per mode
(light, dark).

--8<-- "examples/fixed-colours-per-category.md"

Colours are hex, `rgb()`, `rgba()`, `hsl()`, `hsla()` or CSS names; anything else is refused. A name
that no category of the data has gives a warning that lists the categories. Labels on a mapped fill
(funnel, pie with inside labels, treemap, sunburst) take the text colour with the better contrast to it.

Without a map, palette colours follow the order of the series or items:

| Types | Order |
| --- | --- |
| line, area, step, bar, scatter, boxplot, gantt, parallel, themeriver, polar, radialbar with `-GroupBy` | `-GroupBy` values in natural order (P1, P2 ... P10), independent of the row order |
| the same types without `-GroupBy` | the `-Y` columns as given |
| pie, donut, funnel, treemap, sunburst, radar, bump, sankey, graph; radialbar with one `-Y` | first appearance in the rows |
| matrix | the `-GroupBy` columns in first appearance |

## Order

The module's theme, then the CSS properties, then `-LightTheme`/`-DarkTheme`, then `-Palette`,
`-ColorMap` and `-Options` of the single chart. The chart's background always stays transparent (it sits on the card),
so a theme's `backgroundColor` has no effect. CSS properties follow the page's mode, also for a chart
pinned with `-Theme Light` or `Dark`, and are read when the chart is created and when the mode changes.
