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

They apply to the whole page, so this site shows no live example of them (it would recolour every
chart here).

## Order

The module's theme, then the CSS properties, then `-LightTheme`/`-DarkTheme`, then `-Palette` and
`-Options` of the single chart. The chart's background always stays transparent (it sits on the card),
so a theme's `backgroundColor` has no effect. CSS properties follow the page's mode, also for a chart
pinned with `-Theme Light` or `Dark`, and are read when the chart is created and when the mode changes.
