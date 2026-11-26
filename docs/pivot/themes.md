---
title: Pivot themes and corporate design
description: "Theme New-UDPivotReport from the app's stylesheet: the same --psu-chart-* properties as the ECharts module plus --psu-pivot-* for the report, per light and dark mode."
---

# Themes and corporate design

The report follows the app's light and dark switch and takes PSU's colours: the neutral greys of PSU's
pages and MUI's primary blue. `-Theme Light` or `-Theme Dark` pins it.

A corporate design comes from the app's stylesheet: CSS custom properties per mode, on the page root
and on the report's light or dark theme.
The report reads the **same `--psu-chart-*` properties as the [ECharts module](../echarts/themes.md#css-custom-properties)**
(series colours, text, axis, grid, accent), so one stylesheet themes the charts and the pivot report
together. `--psu-pivot-*` properties set what only the report has (surfaces, totals, heatmap) or give
the report a value of its own; a `--psu-pivot-*` property wins over its `--psu-chart-*` counterpart.

## One stylesheet for ECharts and the pivot report

```css
/* corporate.css: dark blue and orange */
:root,
.ud-pivot-report [data-pk-theme="light"] {
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

:root[data-theme="dark"],
.ud-pivot-report [data-pk-theme="dark"] {
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

The first block is the light mode, the second the dark one. `:root` and `:root[data-theme="dark"]` serve
the ECharts charts, which follow the page; `.ud-pivot-report [data-pk-theme="light"]` and
`[data-pk-theme="dark"]` serve the theme the report shows. The exports need the second pair: the report
reads each mode's colours by showing that theme for a moment, and with the page's selectors alone it
would write the page's current mode both times. Colours are hex or `rgb()`/`rgba()`: the report's chart
hands the series colours to ECharts, which does not read every CSS colour syntax.

## Adding the stylesheet to an app

Put the file into a [published folder](https://docs.devolutions.net/powershell-universal/apps/themes/cascading-style-sheets)
and name it in `New-UDApp -Stylesheets`:

```powershell
# publishedFolders.ps1
New-PSUPublishedFolder -RequestPath '/assets' -Path 'C:\ProgramData\UniversalAutomation\Assets'

# the app
New-UDApp -Title 'Reports' -Stylesheets @('/assets/corporate.css') -Pages @( ... )
```

For a single page, or to try values out, a `<style>` element on the page works the same way. The
properties apply to every chart and report of the page, so this site shows no live example of them.

```powershell
New-UDHtml -Markup '<style>:root, .ud-pivot-report [data-pk-theme="light"] { --psu-chart-1: #003b6f; } :root[data-theme="dark"], .ud-pivot-report [data-pk-theme="dark"] { --psu-chart-1: #6fa8dc; }</style>'
```

## Properties

The series colours (`--psu-chart-1` ... `--psu-chart-8`) and the accent (`--psu-chart-accent` or
`--psu-pivot-accent`) carry a corporate design: the highlight, drop zone, note, tab and button colours
follow from the accent, and without one they keep PSU's values. Set `--psu-pivot-accent-text` whenever
the accent is light in the light mode or dark in the dark mode: the default text on the accent is white
in light mode and near-black in dark.

<details class="note" markdown="1">
<summary>Every property: what it falls back to when unset, and its default without a corporate stylesheet</summary>

| Property | Falls back to | What it sets in the report | Light | Dark |
| --- | --- | --- | --- | --- |
| `--psu-chart-1` ... `--psu-chart-8` | - | series colours of the report's chart, by position; positions without a property keep theirs | pivotkit's palette | pivotkit's palette |
| `--psu-pivot-text` | `--psu-chart-text` | text | `rgba(0, 0, 0, 0.87)` | `rgba(255, 255, 255, 0.87)` |
| `--psu-pivot-muted` | `--psu-chart-muted` | secondary text, chart labels | `rgba(0, 0, 0, 0.62)` | `rgba(255, 255, 255, 0.64)` |
| `--psu-pivot-border` | `--psu-chart-axis` | borders of buttons, chips, panels and menus; the chart's axis line, unless an app sets one of the next row | `#e0e0e0` | `#2e2e2e` |
| `--psu-pivot-chart-axis` | `--psu-chart-axis` | the chart's axis line, apart from the table's lines | as `--psu-pivot-border` | as `--psu-pivot-border` |
| `--psu-pivot-grid` | `--psu-chart-grid` | lines between table cells, chart grid lines | `#eeeeee` | `#232323` |
| `--psu-pivot-accent` | `--psu-chart-accent` | primary buttons, badges, links, opened menus | `#1976d2` | `#90caf9` |
| `--psu-pivot-accent-text` | - | text on the accent | `#ffffff` | `#0b1a2a` |
| `--psu-pivot-focus` | `--psu-pivot-accent`, `--psu-chart-accent` | keyboard focus ring | `#1976d2` | `#90caf9` |
| `--psu-pivot-accent-soft` | 12 % (dark 18 %) of the corporate accent over the surface | badges, opened buttons, focused inputs | `#e3effb` | `#1b2a38` |
| `--psu-pivot-drop` | 18 % (dark 32 %) of the corporate accent over the surface | a zone while a field is dragged over it | `#d6e7f9` | `#1e3a55` |
| `--psu-pivot-note` | 7 % (dark 10 %) of the corporate accent over the surface | notes and hints | `#eef5fc` | `#16212c` |
| `--psu-pivot-surface` | - | background of the report and of the zones | `#ffffff` | `#121212` |
| `--psu-pivot-surface-2` | - | the zones' section, table headers, the field list's panel | `#f5f6f8` | `#1a1a1a` |
| `--psu-pivot-surface-3` | - | hovered controls, the Table/Chart switch | `#eaecef` | `#262626` |
| `--psu-pivot-surface-raised` | - | menus, popovers, the drill-down table, chart tooltips | `#ffffff` | `#1f1f1f` |
| `--psu-pivot-border-strong` | - | frame of a zone, hovered buttons and chips, the switch track, the grand-total line, scroll bars | `#c4c4c4` | `#474747` |
| `--psu-pivot-drop-border` | - | edge of a zone while a field is dragged | `#8a8a8a` | `#7a7a7a` |
| `--psu-pivot-input-border` | - | edge of a text field or a select in a menu | `#808080` | `#858585` |
| `--psu-pivot-rule` | - | line between a menu's groups | `#808080` | `#858585` |
| `--psu-pivot-total` | - | subtotals | `#f5f6f8` | `#1a1a1a` |
| `--psu-pivot-total-strong` | - | the grand total | `#eaecef` | `#242424` |
| `--psu-pivot-heat-low` | - | heatmap chart, lowest value | `#eaf1fb` | `#1d2735` |
| `--psu-pivot-heat-high` | - | heatmap chart, highest value | `#2a78d6` | `#3987e5` |
| `--psu-pivot-chart-other` | - | the grey slice "Other (n)" a pie or donut without a legend puts its smallest slices into; without a value, in the light theme the muted text, in the dark a fixed grey | `rgba(0, 0, 0, 0.62)` | `#6b7280` |
| `--psu-pivot-scale-low` | `--psu-pivot-heat-low` | colour scale of a value without colours of its own, lowest | `#eaf1fb` | `#1d2735` |
| `--psu-pivot-scale-mid` | - | colour scale of a value, middle: set, the scale has three colours | none | none |
| `--psu-pivot-scale-high` | `--psu-pivot-heat-high` | colour scale of a value without colours of its own, highest | `#2a78d6` | `#3987e5` |
| `--psu-pivot-type-string`, `--psu-pivot-type-number`, `--psu-pivot-type-date`, `--psu-pivot-type-boolean` | `--psu-pivot-muted`, `--psu-chart-muted` | the icon of a text, number, date or yes/no field and its pill in the empty report | `rgba(0, 0, 0, 0.62)` | `rgba(255, 255, 255, 0.64)` |
| `--psu-pivot-zone-rows` | - | the Rows zone: its icons, its marks in the field list, its fields' names in the table's header | `#1d5fcc` | `#8db4ff` |
| `--psu-pivot-zone-columns` | - | the Columns zone, the same parts | `#a85a00` | `#f2b559` |
| `--psu-pivot-zone-values` | - | the Values zone, the same parts, also on the grand total | `#0b785c` | `#5fd6ac` |
| `--psu-pivot-zone-filters` | `--psu-pivot-muted`, `--psu-chart-muted` | the Filters zone, the same parts | `rgba(0, 0, 0, 0.62)` | `rgba(255, 255, 255, 0.64)` |
| `--psu-pivot-zone-tint` | - | how much of its zone's colour a chip's fill takes | `16%` | `16%` |
| `--psu-pivot-zone-tint-base` | `--psu-pivot-surface` | what a chip's fill mixes the zone's colour into | `#ffffff` | `#121212` |
| `--psu-pivot-control-icon` | `--psu-pivot-muted`, `--psu-chart-muted` | a chip's grip, menu arrow and remove button | `rgba(0, 0, 0, 0.62)` | `rgba(255, 255, 255, 0.64)` |
| `--psu-pivot-sort-arrow` | `--psu-pivot-text`, `--psu-chart-text` | the sort arrow of the sorted field | `rgba(0, 0, 0, 0.87)` | `rgba(255, 255, 255, 0.87)` |
| `--psu-pivot-field-hover` | `--psu-pivot-surface` | a field in the field list on hover | `#ffffff` | `#121212` |
| `--psu-pivot-chart-reference` | `--psu-pivot-muted`, `--psu-chart-muted` | the chart's reference lines that belong to no series | `rgba(0, 0, 0, 0.62)` | `rgba(255, 255, 255, 0.64)` |
| `--psu-pivot-tab-bg` | - | a tab not shown (Table, Chart): its background | `transparent` | `transparent` |
| `--psu-pivot-tab-text` | `--psu-pivot-muted`, `--psu-chart-muted` | a tab not shown: its text | `rgba(0, 0, 0, 0.62)` | `rgba(255, 255, 255, 0.64)` |
| `--psu-pivot-tab-selected-bg` | `--psu-pivot-surface` | the tab shown: its background | `#ffffff` | `#121212` |
| `--psu-pivot-tab-selected-text` | `--psu-pivot-accent`, `--psu-chart-accent` | the tab shown: its text | `#1976d2` | `#90caf9` |
| `--psu-pivot-icon-button-text` | `--psu-pivot-muted`, `--psu-chart-muted` | a button with only an icon (a field's menu, Close, folding the field list): the icon | `rgba(0, 0, 0, 0.62)` | `rgba(255, 255, 255, 0.64)` |
| `--psu-pivot-icon-button-hover-bg` | `--psu-pivot-surface-3` | such a button on hover and while its menu is open | `#eaecef` | `#262626` |
| `--psu-pivot-button-border` | `--psu-pivot-border`, `--psu-chart-axis` | the frame of a button (the toolbar's, Table settings, Enlarge, Full screen) | `#e0e0e0` | `#2e2e2e` |
| `--psu-pivot-button-border-hover` | `--psu-pivot-border-strong` | the frame of a button on hover | `#c4c4c4` | `#474747` |
| `--psu-pivot-primary-bg` | `--psu-pivot-accent`, `--psu-chart-accent` | the main action of a dialog (Apply, Save, Load): its fill and frame | `#1976d2` | `#90caf9` |
| `--psu-pivot-primary-text` | `--psu-pivot-accent-text` | the main action's text | `#ffffff` | `#0b1a2a` |
| `--psu-pivot-primary-hover-bg` | - | the main action's fill on hover | 88 % of its fill, mixed with the text colour | 88 % of its fill, mixed with the text colour |
| `--psu-pivot-radius` | - | corner radius of the report, panels, zones and popovers | `8px` | `8px` |
| `--psu-pivot-radius-sm` | - | corner radius of buttons, fields and notes | `4px` | `4px` |
| `--psu-pivot-font` | - | font family | the page's font | the page's font |
| `--psu-pivot-font-size` | - | base text size | `max(14px, 1em)` | `max(14px, 1em)` |
| `--psu-pivot-weight-normal` | - | plain text inside a bolder part (hints, table cells) | `400` | `400` |
| `--psu-pivot-weight-medium` | - | light emphasis (row labels, segmented buttons) | `500` | `500` |
| `--psu-pivot-weight-strong` | - | titles, field chips, buttons, subtotals, the admin panel's titles | `600` | `600` |
| `--psu-pivot-weight-bold` | - | grand totals, step numbers | `700` | `700` |

</details>

The report's chart has eight series colours. `--psu-chart-9` ... `--psu-chart-12`, `--psu-chart-tooltip`,
`--psu-chart-tooltip-border` and `--psu-chart-font-size` are ECharts only; the report's tooltips use
`--psu-pivot-surface-raised`.

Colour marks the zones, not the field types: the type icons are the muted text. The zone colours are
pivotkit's own; a corporate one needs 4.5:1 on `--psu-pivot-surface-2` (the values colour also on
`--psu-pivot-total-strong`) and 3:1 on its chips' fill.

A colour scale a reader adds without picking colours runs from light to strong blue, the heatmap's
colours: it says "more", not "good" or "bad", and the Excel export writes the same colours. For
Excel's red, yellow and green, set the three scale properties per mode:

```css
:root,
.ud-pivot-report [data-pk-theme="light"] {
    --psu-pivot-scale-low: #f8696b;
    --psu-pivot-scale-mid: #ffeb84;
    --psu-pivot-scale-high: #63be7b;
}

:root[data-theme="dark"],
.ud-pivot-report [data-pk-theme="dark"] {
    --psu-pivot-scale-low: #c2413f;
    --psu-pivot-scale-mid: #b39a2e;
    --psu-pivot-scale-high: #3f9a5c;
}
```

Set `--psu-pivot-scale-mid` in the dark block too: without it, the HTML report on a dark screen runs the scale between low and high.

A view whose colour scale has colours of its own keeps them. Readers pick such colours in a value's
menu, Highlight, Colour scale, **Colours**: **Low blue, high orange**, **Low blue, high red** or
**Low red, high green** ([the colours](views.md#the-start-view-view)). Only **Theme colours, light to
dark** follows the three properties above.

## Light and dark

Excel and print are light also from a dark app; the HTML report is light on paper and on a light screen
and dark on a dark one. The report takes light or dark from PSU's `<html data-theme>` and switches with the
app's toggle without a reload, keeping the reader's view ([Views](views.md#the-start-view-view)); undo
and redo start over. The theme it shows is `data-pk-theme="light"` or `"dark"` on its root, where the
stylesheet above sets the values, so a report pinned with `-Theme Light` or `-Theme Dark` takes its own
theme's values in either app mode. A property set only on `:root` reaches both modes: keep it to values
both share, as corners, font weights and the font. The admin panel of `-AdminRole` sits outside the
report's theme and takes `--psu-pivot-radius`, `--psu-pivot-radius-sm` and `--psu-pivot-weight-strong` from `:root`.

Next: [Views](views.md), [Templates, view files and roles](templates.md), [Events, security and limits](events.md), [Reference](reference.md).
