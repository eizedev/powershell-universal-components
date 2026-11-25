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

The first block is the light mode, the second the dark one. Each mode needs its own values: a
property set only in `:root` applies to both modes, and a dark text colour from the light block would
be unreadable on the dark report. Each block names two selectors: `:root` and `:root[data-theme="dark"]`
for the ECharts charts, which follow the page, and `.ud-pivot-report [data-pk-theme="light"]` and
`[data-pk-theme="dark"]` for the theme the report shows. The second pair matters for the exports.
The Excel export is light (black text in Excel). The HTML report carries both modes: light for paper
and a light screen, dark for a reader whose screen is dark. The report reads each mode's colours by
showing that theme for a moment. With the page's selectors alone, it would inherit the page's current
mode both times and write that mode's values into the file. Colours are hex or `rgb()`/`rgba()`: the report's chart hands the
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
New-UDHtml -Markup '<style>:root, .ud-pivot-report [data-pk-theme="light"] { --psu-chart-1: #003b6f; } :root[data-theme="dark"], .ud-pivot-report [data-pk-theme="dark"] { --psu-chart-1: #6fa8dc; }</style>'
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
| `--psu-pivot-type-string` | - | the icon of a text field and its pill in the empty report | `#6250d6` | `#a99dff` |
| `--psu-pivot-type-number` | - | the icon of a number field and its pill | `#1a7f5a` | `#5fd3a3` |
| `--psu-pivot-type-date` | - | the icon of a date field and its pill | `#b5560b` | `#f2a65a` |
| `--psu-pivot-type-boolean` | - | the icon of a yes/no field and its pill | `#a3367a` | `#f08cc6` |
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

The report's chart has eight series colours: `--psu-chart-9` ... `--psu-chart-12` colour only ECharts
charts. `--psu-chart-tooltip`, `--psu-chart-tooltip-border` and `--psu-chart-font-size` are ECharts
only as well; the report's tooltips use `--psu-pivot-surface-raised`.

The field type colours are pivotkit's own: a corporate palette sets them per mode, so each stays
readable on its mode's surface. The tab and button properties fall back to the general ones, so a
corporate accent already reaches the shown tab and the main action of a dialog. Set them only where a
part needs a colour of its own.

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

Without a corporate accent the highlight, drop zone and note colours keep PSU's values; with one
(`--psu-pivot-accent` or `--psu-chart-accent`) they are mixed from it, so they match. Set
`--psu-pivot-accent-text` whenever the accent is light in the light mode or dark in the dark mode: the
default text on the accent is white in light mode and near-black in dark mode.

## Light and dark

Excel and print are light also from a dark app; the HTML report is light on paper and on a light screen
and dark on a dark one.

The report takes light or dark from PSU's `<html data-theme>` and switches with the app's toggle, the
table and the chart at once, without a reload, and keeps the reader's view ([Views](views.md#the-start-view-view));
undo and redo start over. The theme the report shows is `data-pk-theme="light"` or `"dark"` on its
root; the stylesheet above sets the values on it, so a report pinned with `-Theme Light` or
`-Theme Dark` takes the values of its own theme, also in an app of the other mode. Properties set only
on the page root (`:root`, `:root[data-theme="dark"]`) reach the report by inheritance in the page's
current mode; they are fine for a value that is the same in both modes. Set corners, font weights and
the font on `:root`: the admin panel of `-AdminRole` sits next to the report, outside its theme, and
takes `--psu-pivot-radius`, `--psu-pivot-radius-sm` and `--psu-pivot-weight-strong` from there.

Next: [Views](views.md), [Templates, view files and roles](templates.md), [Events, security and limits](events.md), [Reference](reference.md).
