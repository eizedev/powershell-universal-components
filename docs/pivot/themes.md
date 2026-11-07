---
title: Pivot themes and corporate design
description: "Theme New-UDPivotReport from the app's stylesheet: the same --psu-chart-* properties as the ECharts module plus --psu-pivot-* for the report, per light and dark mode."
---

# Themes and corporate design

The report follows the app's light and dark switch and takes PSU's colours: the neutral greys of PSU's
pages and MUI's primary blue. `-Theme Light` or `-Theme Dark` pins it.

A corporate design comes from the app's stylesheet: CSS custom properties on the page root, per mode.
The report reads the **same `--psu-chart-*` properties as the [ECharts module](../echarts/themes.md#css-custom-properties)**
(series colours, text, axis, grid, accent), so one stylesheet themes the charts and the pivot report
together. `--psu-pivot-*` properties set what only the report has (surfaces, totals, heatmap) or give
the report a value of its own; a `--psu-pivot-*` property wins over its `--psu-chart-*` counterpart.

## One stylesheet for ECharts and the pivot report

```css
/* corporate.css: dark blue and orange */
:root {
    --psu-chart-1: #003b6f;
    --psu-chart-2: #f28c28;
    --psu-chart-3: #5b8db8;
    --psu-chart-4: #b35c00;
    --psu-chart-text: #1f2430;
    --psu-chart-muted: #4a5263;
    --psu-chart-axis: #c5ccd6;
    --psu-chart-grid: #e6eaf0;
    --psu-chart-accent: #003b6f;
    --psu-pivot-total: #eef2f7;
    --psu-pivot-heat-high: #003b6f;
}

:root[data-theme="dark"] {
    --psu-chart-1: #6fa8dc;
    --psu-chart-2: #f6b26b;
    --psu-chart-3: #9fc5e8;
    --psu-chart-4: #e69138;
    --psu-chart-text: #e6e9ef;
    --psu-chart-muted: #a9b1bf;
    --psu-chart-axis: #3a4150;
    --psu-chart-grid: #262b33;
    --psu-chart-accent: #6fa8dc;
    --psu-pivot-total: #1a1f27;
    --psu-pivot-heat-high: #6fa8dc;
}
```

The first block is the light mode, the second the dark one. Each mode needs its own values: a
property set only in `:root` applies to both modes, and a dark text colour from the light block would
be unreadable on the dark report. Colours are hex or `rgb()`/`rgba()`: the report's chart hands the
series colours to ECharts, which does not read every CSS colour syntax.

## Adding the stylesheet to an app

Put the file into a [published folder](https://docs.devolutions.net/powershell-universal/apps/themes/cascading-style-sheets)
and name it in `New-UDApp -Stylesheets`:

```powershell
# publishedFolders.ps1
New-PSUPublishedFolder -RequestPath '/assets' -Path 'C:\ProgramData\UniversalAutomation\Assets'

# the app
New-UDApp -Title 'Reports' -Stylesheets @('/assets/corporate.css') -Pages @( ... )
```

For a single page, or to try values out, a `<style>` element on the page works the same way:

```powershell
New-UDHtml -Markup '<style>:root { --psu-chart-1: #003b6f; } :root[data-theme="dark"] { --psu-chart-1: #6fa8dc; }</style>'
```

The properties apply to every chart and report of the page, so this site shows no live example of them.

## Properties

The light and dark columns are the values without a corporate stylesheet. "Falls back to" is the
property used when the first one is not set; without either the default applies.

| Property | Falls back to | What it sets in the report | Light | Dark |
| --- | --- | --- | --- | --- |
| `--psu-chart-1` ... `--psu-chart-8` | - | series colours of the report's chart, by position; positions without a property keep theirs | pivotkit's palette | pivotkit's palette |
| `--psu-pivot-text` | `--psu-chart-text` | text | `rgba(0, 0, 0, 0.87)` | `rgba(255, 255, 255, 0.87)` |
| `--psu-pivot-muted` | `--psu-chart-muted` | secondary text, chart labels | `rgba(0, 0, 0, 0.62)` | `rgba(255, 255, 255, 0.64)` |
| `--psu-pivot-border` | `--psu-chart-axis` | borders of buttons, chips, panels and menus; chart axes | `#e0e0e0` | `#2e2e2e` |
| `--psu-pivot-grid` | `--psu-chart-grid` | lines between table cells, chart grid lines | `#eeeeee` | `#232323` |
| `--psu-pivot-accent` | `--psu-chart-accent` | primary buttons, badges, links, opened menus | `#1976d2` | `#90caf9` |
| `--psu-pivot-accent-text` | - | text on the accent | `#ffffff` | `#0b1a2a` |
| `--psu-pivot-focus` | `--psu-pivot-accent`, `--psu-chart-accent` | keyboard focus ring | `#1976d2` | `#90caf9` |
| `--psu-pivot-accent-soft` | 12 % (dark 18 %) of the corporate accent over the surface | badges, opened buttons, focused inputs | `#e3effb` | `#1b2a38` |
| `--psu-pivot-drop` | 18 % (dark 32 %) of the corporate accent over the surface | a zone while a field is dragged over it | `#d6e7f9` | `#1e3a55` |
| `--psu-pivot-note` | 7 % (dark 10 %) of the corporate accent over the surface | notes and hints | `#eef5fc` | `#16212c` |
| `--psu-pivot-surface` | - | background of the report | `#ffffff` | `#121212` |
| `--psu-pivot-surface-2` | - | zones, table headers, the field list's panel | `#f5f6f8` | `#1a1a1a` |
| `--psu-pivot-surface-3` | - | hovered controls, the Table/Chart switch | `#eaecef` | `#262626` |
| `--psu-pivot-surface-raised` | - | menus, popovers, the drill-down table, chart tooltips | `#ffffff` | `#1f1f1f` |
| `--psu-pivot-border-strong` | - | hovered buttons and chips, the switch track, the grand-total line, scroll bars | `#c4c4c4` | `#474747` |
| `--psu-pivot-drop-border` | - | edge of a zone | `#8a8a8a` | `#7a7a7a` |
| `--psu-pivot-total` | - | subtotals | `#f5f6f8` | `#1a1a1a` |
| `--psu-pivot-total-strong` | - | the grand total | `#eaecef` | `#242424` |
| `--psu-pivot-heat-low` | - | heatmap chart, lowest value | `#eaf1fb` | `#1d2735` |
| `--psu-pivot-heat-high` | - | heatmap chart, highest value | `#2a78d6` | `#3987e5` |
| `--psu-pivot-scale-low` | - | colour scale of a value, lowest | `#f8696b` | `#c2413f` |
| `--psu-pivot-scale-mid` | - | colour scale of a value, middle | `#ffeb84` | `#b39a2e` |
| `--psu-pivot-scale-high` | - | colour scale of a value, highest | `#63be7b` | `#3f9a5c` |
| `--psu-pivot-radius` | - | corner radius of the report, panels, zones and popovers | `8px` | `8px` |
| `--psu-pivot-radius-sm` | - | corner radius of buttons, fields and notes | `4px` | `4px` |
| `--psu-pivot-font` | - | font family | the page's font | the page's font |
| `--psu-pivot-font-size` | - | base text size | `max(14px, 1em)` | `max(14px, 1em)` |

The report's chart has eight series colours: `--psu-chart-9` ... `--psu-chart-12` colour only ECharts
charts. `--psu-chart-tooltip`, `--psu-chart-tooltip-border` and `--psu-chart-font-size` are ECharts
only as well; the report's tooltips use `--psu-pivot-surface-raised`.

Without a corporate accent the highlight, drop zone and note colours keep PSU's values; with one
(`--psu-pivot-accent` or `--psu-chart-accent`) they are mixed from it, so they match. Set
`--psu-pivot-accent-text` whenever the accent is light in the light mode or dark in the dark mode: the
default text on the accent is white in light mode and near-black in dark mode.

## Light and dark

The report takes light or dark from PSU's `<html data-theme>` and switches with the app's toggle, the
table and the chart at once, without a reload. The properties are inherited from the page root, so the
report sees the values of the page's current mode: those in `:root[data-theme="dark"]` while the app is
dark, those in `:root` while it is light.

A report pinned with `-Theme Light` or `-Theme Dark` still sees the values of the page's mode. To give
a pinned dark report its own values in a light app, set them on the report:

```css
.ud-pivot-report [data-pk-theme="dark"] { --psu-chart-text: #e6e9ef; --psu-chart-muted: #a9b1bf; --psu-chart-accent: #6fa8dc; }
```

Next: [Views and templates](views.md), [Events, security and limits](events.md), [Reference](reference.md).
