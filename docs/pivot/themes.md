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

Every property, what it falls back to when unset and its default without a corporate stylesheet:
[Theme properties](theme-properties.md).

With pivotkit 0.11.0 or later in the module, colour marks the zones, not the field types: the type
icons are the muted text. The zone colours are pivotkit's own; a corporate one needs 4.5:1 on `--psu-pivot-surface-2` (the values colour also on
`--psu-pivot-total-strong`) and 3:1 on its chips' fill. For coloured type icons, as the report had
before, set the four type properties per mode:

```css
:root, .ud-pivot-report [data-pk-theme="light"] { --psu-pivot-type-string: #6250d6; --psu-pivot-type-number: #1a7f5a; --psu-pivot-type-date: #b5560b; --psu-pivot-type-boolean: #a3367a; }
:root[data-theme="dark"], .ud-pivot-report [data-pk-theme="dark"] { --psu-pivot-type-string: #a99dff; --psu-pivot-type-number: #5fd3a3; --psu-pivot-type-date: #f2a65a; --psu-pivot-type-boolean: #f08cc6; }
```

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
