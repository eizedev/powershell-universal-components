---
title: Pivot theme properties
description: "Every CSS custom property New-UDPivotReport reads from the app's stylesheet: what it falls back to when unset, what it sets in the report, and its default in light and dark mode."
---

# Theme properties

The properties an app's stylesheet sets for the report, per light and dark mode, as
[Themes and corporate design](themes.md) shows. A property without a value falls back to the next one
in its row; without any, the report keeps the default of its mode. The rows from
`--psu-pivot-zone-rows` to `--psu-pivot-field-hover` take effect with pivotkit 0.11.0 or later in the
module; with an older pivotkit they set nothing. `--psu-pivot-chart-reference`, after them, needs no
minimum.

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
| `--psu-pivot-sort-arrow` | `--psu-pivot-accent`, `--psu-chart-accent` | the arrow behind the name of the sorted header and on its chip | `#1976d2` | `#90caf9` |
| `--psu-pivot-sort-arrow-rest` | `--psu-pivot-muted`, `--psu-chart-muted` | the up-down mark behind every other header that sorts | `rgba(0, 0, 0, 0.62)` | `rgba(255, 255, 255, 0.64)` |
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
| `--psu-pivot-radius-sm` | - | corner radius of buttons, chips, notes, the fields in the field list and their hover, and a field's name in the table's header; pivotkit's smaller corners (links, a chip's grip, badges, a field's type icon) follow it. `4px` is PSU's own corner; pivotkit's is `7px`. Chips and the table's field names follow it with pivotkit 0.11.0 or later | `4px` | `4px` |
| `--psu-pivot-font` | - | font family | the page's font | the page's font |
| `--psu-pivot-font-size` | - | base text size | `max(14px, 1em)` | `max(14px, 1em)` |
| `--psu-pivot-weight-normal` | - | plain text inside a bolder part (hints, table cells) | `400` | `400` |
| `--psu-pivot-weight-medium` | - | light emphasis (row labels, segmented buttons) | `500` | `500` |
| `--psu-pivot-weight-strong` | - | titles, field chips, buttons, subtotals, the admin panel's titles | `600` | `600` |
| `--psu-pivot-weight-bold` | - | grand totals, step numbers | `700` | `700` |

The report's chart has eight series colours. `--psu-chart-9` ... `--psu-chart-12`, `--psu-chart-tooltip`,
`--psu-chart-tooltip-border` and `--psu-chart-font-size` are ECharts only; the report's tooltips use
`--psu-pivot-surface-raised`.

Next: [Themes and corporate design](themes.md), [Commands and parameters](reference.md).
