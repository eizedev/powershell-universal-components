---
title: Views
description: "The start view of New-UDPivotReport (-View) and its keys, chart settings, the view in the address bar, and where filters, the reader's view across tabs and templates are explained."
---

# Views

A **view** is what the report shows, as plain JSON: the fields on rows, columns, values and filters,
sorting, totals, table or chart. It is the start view, a template and an undo step at once. The report
checks every view against the data and drops what does not fit (an unknown field, an aggregator that
does not suit the field); a view never runs as code.

## The start view: `-View`

```powershell
New-UDPivotReport -Id 'tickets' -Data $tickets -View @{
    rows   = @('Team')
    cols   = @('Priority')
    values = @(@{ field = 'Ticket'; agg = 'count' })
}
```

The keys of a view:

| Key | What |
| --- | --- |
| `version` | The view format's version: `2`. Write it in a view with filters; a view without it is read as version 1 and migrated ([Filters](#filters)). |
| `rows`, `cols` | Field names, outermost first. |
| `values` | `@{ field = 'Cost'; agg = 'sum'; format = 'currency:EUR' }`: aggregators `sum`, `count`, `countUnique`, `average`, `median`, `min`, `max`, `stdev`, `var`, `first`, `last`, ...; formats `number`, `number:2`, `integer`, `percent`, `currency:EUR`, `compact`, `bytes`, `duration:h`, `date`, `datetime`, `time`; `showAs = @{ type = 'percentOfGrandTotal' }` and the other "show as" types; `conditional = @{ type = 'colorScale'; colors = @('#2a78d6', '#f2f2f2', '#eb6834') }` (two or three colours, low to high; without `colors` the theme's scale) or `@{ type = 'dataBar' }`. The **Colours** row of the value menu writes these colours: blue to orange `#2a78d6`, `#f2f2f2`, `#eb6834`; blue to red `#2a78d6`, `#f2f2f2`, `#e34948`; red to green `#e34948`, `#f2d16b`, `#1baf7a` (pivotkit-core's `COLOR_SCALES`). |
| `filters` | `@{ field = 'Status'; type = 'in'; items = @('Open', 'Waiting'); blanks = 'exclude' }`; the types, `not` and `blanks` are under [Filters](#filters). |
| `derived` | Grouped dates and number ranges: `@{ name = 'Created (Month)'; field = 'Created'; by = 'yearMonth' }` (units `year`, `yearQuarter`, `yearMonth`, `yearWeek`, `day`, `quarter`, `month`, `week`, `weekday`, `hour`); the name then goes into `rows` or `cols`. |
| `sort` | `@{ field = 'Team'; by = 'value'; order = 'desc' }`. A row field sorted by a value can follow one column: `column = @('Jul')`, the column's items, outermost first (a click on a column's name in the table writes it). |
| `totals` | `@{ grandTotalRow = $true; grandTotalColumn = $true; rowSubtotals = $true; colSubtotals = $true }`. A key left out keeps the default: both grand totals and the row subtotals on, the column subtotals off; a view with two or more fields in `cols` that should show their subtotals sets `colSubtotals = $true`. The report writes all four into every view it saves or shares. |
| `display` | `'table'`, `'chart'` or `'both'` (the table and the chart side by side on a wide report, the table on a narrow one). |
| `chart` | `@{ type = 'bar'; stacked = $false; horizontal = $false }` and the other [chart settings](#chart-settings). |
| `fieldLabels` | Names of the report's own for fields, by the field's name: `@{ Cust = 'Customer' }`. The chips, the table, the chart and the exports show them; a reader sets them with **Name** in a field's menu. A view without them has no `fieldLabels`. |

--8<-- "examples/chart-settings-in-a-view.md"

--8<-- "examples/bars-and-lines.md"

The simplest way to a view is to build it in the report and copy it: **Views, Share, Copy view as JSON** (a
[view file](templates.md#view-files); `-View` takes its `view`), or `$EventData.json` of `-OnViewChange`.
`-View` takes that JSON as it is.

**Start over** in the toolbar goes back to `-View`. `Set-UDElement -Id <id> -Properties @{ view = $view }`
shows another view (the reader can undo it), and `(Get-UDElement -Id <id>).view` is the view the reader
has now. `Get-UDElement` returns only `id` and `view`, not the rows.

The browser tab keeps the reader's view: PSU builds the report anew when the app switches between
light and dark, and the report comes back with the same fields, table or chart, chart type and
collapsed groups. Undo and redo start over then; **Start over** still goes back to `-View`, and from then on
the tab keeps `-View`. The view is kept in two places of the tab:

- **The address bar.** Every change writes the view into the URL fragment, one entry per report:
  `#pivot-<id>=...` (the `-Id`, or the key the module derives without one), several joined with `&`.
  It is written in place (no new history entry: one step back leaves the page). A reload keeps it,
  and a copied address opens the same views for someone else - with their own data and permissions,
  since only the layout is in the link. A view in the address bar wins over `-View`; a view too long
  for it (more than 8000 characters) stays out. `-NoAddressBar` turns this off.
- **sessionStorage** (per page and report), for a view that is not in the address bar. It returns
  after a reload as long as the page sends the same `-View`; a different `-View` from the server (the
  app chose another start view) wins. Closing the tab, or a browser that blocks storage, starts from
  `-View`.

The keys of both: [how the module builds ids and names](ids.md#ids). While the report shows a
reader's own file with `-AllowImport`, its view goes into neither the address bar nor sessionStorage:
[Readers' own files](import.md#what-stays-in-the-browser).

!!! warning "Filter values appear in the address"
    The view includes filter values: a customer name in a filter is then in the address, in the
    browser history, in every copied link, and in the page address PSU sends with its requests to the
    server (header `windowlocation`, measured on PSU 2026.3.4). For reports whose filter values are
    sensitive, use `-NoAddressBar`: the view stays in the tab's sessionStorage only, and a view in a
    link is ignored.

The view in a link is input like any other: the report checks it against the data and drops what does
not fit, and nothing in it runs as code. A view from a link is held to pivotkit's limits for views
from outside: at most 50 filters (the rest are left out) and 1,000,000 characters. The tab's own view
(the one its sessionStorage keeps, also when the same view is in the address bar after a reload or the
light/dark switch) keeps the app's limits.

### Chart settings

The keys of `chart`. From `valueLabels` on, they are the Display settings of **Chart settings** in the report.

| Key | What |
| --- | --- |
| `type` | `auto`, `bar`, `line`, `area`, `pie`, `donut`, `heatmap`, `combo` (bars and lines: the first value as bars, every other value as a line on an axis of its own), `treemap` (a tile per category). `auto` is the default: lines over dates, bars otherwise. |
| `stacked`, `horizontal` | `$true` or `$false`. |
| `valueLabels` | `auto`, `off`, `value`, `percent`, `both`. |
| `legend` | `auto`, `bottom`, `right`, `off`. |
| `title` | The chart's title, a text. |
| `smooth` | `$true`: smooth lines. |
| `axisLabels` | `auto`, `all`, `nth`. |
| `groupLabels` | `auto`, `on`, `off`. |
| `labelPosition` | A pie or donut: `outside`, `inside`. |
| `tooltip` | Bars, lines and areas: `auto` shows the element under the pointer, `axis` every series. |
| `zoom` | Bars, lines and areas: the zoom slider, `auto`, `on` or `off`. |
| `referenceLines` | Bars, lines and areas: `@{ average = $true; trend = $true; target = 250; extremes = $true }`. `extremes` marks each series' highest and lowest value. |
| `stackPercent` | Stacked bars and areas: `$true` stacks to 100 %. |
| `hidden` | The series or slices hidden in the legend, by name. |
| `colors` | `@(@{ name = 'North'; color = '#1f77b4' })`. |
| `tooltipShare` | `$true`: each value's share in the tooltip. |

### Links into the report

A link pivotkit made, or one with parameters of a server source, opens a view: [Links into a report](links.md).

## Filters

Every filter of a view has one shape: `field`, `type`, the keys of its type, and `not` and `blanks`.
The types and their keys: [Filters in a view](filters.md).

## Several tabs and keeping the reader's view

Every browser tab keeps its own view. To keep the reader's view beyond the tab, store it in
`-OnViewChange` and pass it back as `-SavedView`: [Several tabs and the reader's view](saved-view.md).

## Templates

Named views in the **Views** menu - shared views your app ships (`-Templates`, view files from
`-TemplatePath`), the reader's own views (`-TemplateStore`), Save, Save as and New, and who may
publish shared ones (`-AdminRole`) - have a page of their own: [Templates, view files and roles](templates.md).
A view loaded from Views shows its name in the toolbar; `-SavedView` and the view of a tab bring
back the view, not its name.
