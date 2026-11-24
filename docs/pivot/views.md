---
title: Views
description: "The start view of New-UDPivotReport, its keys, views per browser tab and in the address bar, -SavedView, and where templates come in."
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
- While a reader's own file is shown (`-AllowImport`), its view goes into neither the address bar
  nor sessionStorage ([Readers' own files](import.md#what-stays-in-the-browser)). The keys of both:
  [how ids and names are built](ids.md#ids).
- **sessionStorage** (per page and report), for a view that is not in the address bar. It returns
  after a reload as long as the page sends the same `-View`; a different `-View` from the server (the
  app chose another start view) wins. Closing the tab, or a browser that blocks storage, starts from
  `-View`.

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

### Links from pivotkit (create_link)

pivotkit's MCP tool `create_link` and its REST route `POST /views/link` make a link that opens a view
in a page; a model or a program that worked out a view with a pivotkit-server can hand a person that
link, and the person sees the view over the app's data with their own rights. The report opens such
a link when the pivotkit-server's source names the page and the report:

```json
{
  "sources": {
    "tickets": {
      "file": "data/tickets.csv",
      "link": "https://psu.example.com/tickets/report",
      "linkKey": "tickets"
    }
  }
}
```

```powershell
New-UDPivotReport -Id 'tickets' -SourceId 'tickets' -Data $tickets
```

- `link` is the address of the PSU page, `linkKey` the report's `-Id`: the link then ends in
  `#pivot-tickets=1.<view>` (pivotkit's share format). Without `linkKey` it ends in `#pivot=1.<view>`,
  which the report whose data the link names takes, and removes from the address.
- The link names the data it was made for (the source's id). The report opens it only when that is
  its own `-SourceId` (default its `-Id`); a link for other data is left alone, the report starts as
  without it, and the browser console says why. Give the PSU report the source's id as `-SourceId`.
  A link that names no data (a view file without `source.id`, made by hand) is loaded without that
  check: the report still checks its fields against the data, as for every view.
- Once the report shows the link's view, it writes its own entry in place of pivotkit's, so a
  reload, the light/dark switch and a copied address keep the view.
- The link holds the layout only, never data; the report checks the view against the rows the
  person may see, as for every link. `-NoAddressBar` ignores links, also these.

pivotkit's side: [create_link](https://pivotkit.eize.dev/reference/mcp/) and
[sources](https://pivotkit.eize.dev/reference/mcp/#configuration) (`sources.<id>.link`, `.linkKey`).

A source only the server can reach opens with the person's own rows: `New-UDPivotReport -Uri -Source`
fetches them on the PSU server, with the link's parameters from the page's query string
([rows from a server](server-rows.md)).

## Filters

Every filter of a view has one shape: `field`, `type`, the keys of its type, and `not` and `blanks`.
All filters apply together.

```powershell
New-UDPivotReport -Id 'tickets' -Data $tickets -View @{
    version = 2
    rows    = @('Team')
    values  = @(@{ field = 'Ticket'; agg = 'count' })
    filters = @(
        @{ field = 'Status'; type = 'in'; items = @('Closed'); not = $true; blanks = 'include' }
        @{ field = 'Host'; type = 'text'; op = 'contains'; value = 'test'; not = $true; blanks = 'exclude' }
        @{ field = 'Created'; type = 'relative'; unit = 'year'; count = 2; blanks = 'exclude' }
    )
}
```

| `type` | What |
| --- | --- |
| `in` | Keeps the listed `items`; with `not = $true` drops them. |
| `blank` | Keeps the blank items; with `not = $true` every other. |
| `text` | A rule on the names: `op` `equals`, `contains`, `beginsWith`, `endsWith` and `value` the text, case and runs of spaces ignored. `on = 'label'` compares the text the table shows (a number or a date as formatted). |
| `compare` | The item itself compared with `value`: `op` `=`, `>`, `>=`, `<`, `<=`, `between` (with `value2`); a date by its calendar day `'2025-01-01'`, or by `precision` `year`, `quarter`, `month`, `hour`. |
| `relative` | Dates of a range that moves with today: `@{ field = 'Created'; type = 'relative'; unit = 'year'; count = 2 }` (the last 2 years, this one included); `direction` `last`, `next`, `this`, `before`, units `hour` to `year`, `anchor = 'latest'` counts from the latest date of the field's data. |
| `value` | A rule on the total, `op` as `compare`'s, `by` the value: `@{ field = 'Team'; type = 'value'; op = '>'; value = 1000 }`. |
| `top` | The `count` largest items (`bottom = $true`: the smallest), `ties = 'all'` keeps every item tied at the cut. |

- `not = $true` turns the rule around for the items with a value: "is not", "does not contain" and
  "is not between" are `equals`, `contains`, `=` and `between` with `not`.
- `blanks` alone decides the blank items: `'exclude'` (the default) drops them, `'include'` keeps them
  too, `'only'` keeps only them. Write it on every filter, so the view says what it means.

The whole catalogue with every key: pivotkit's [Filters, top N and sorting](https://pivotkit.eize.dev/concepts/filters/).
A view of version 1 (without `version`) works too: its
`include`, `exclude` and `label` filters and the operators `!=`, `notBetween`, `notEquals` and
`notContains` are migrated to version 2 when the report reads them, with the same result
([pivotkit's table](https://pivotkit.eize.dev/concepts/views/#versions)). The report writes version 2,
so `-OnViewChange`, `Get-UDElement` and saved views carry it. `ConvertFrom-UDPivotView` passes the
filters of either version as they are; the report checks them against the data.

A `relative` filter and the quick choices of the Filter level keep a rule, not dates: "today" is read
when the report computes, in the browser, from the reader's clock at the wall time of `-TimeZone`
(pivotkit-core's `now` option; the module passes none, so a view saved today still shows "last 2
years" next year).

## Several tabs and keeping the reader's view

Every browser tab keeps its own view, also two tabs on the same page: nothing needs to be stored on
the server for a reload, a light/dark switch, a `Sync-UDElement` of a surrounding `New-UDDynamic` or a
shared link.

To keep the reader's view beyond the tab (a new tab, another day, another device), store it in
`-OnViewChange` and pass it back as `-SavedView`, never as `-View`:

```powershell
New-UDPivotReport -Id 'tickets' -Data $tickets -View $startView -SavedView $Session:PivotView -OnViewChange {
    Import-Module PowerShellUniversal.Component.Pivot
    $Session:PivotView = ConvertFrom-UDPivotView -InputObject $EventData.json
}
```

`-SavedView` starts a tab that has no view of its own yet; a tab that already shows a view keeps it,
and **Start over** goes back to `-View`. The difference matters because PSU's scopes are not per tab
(measured on PSU 2026.3.4):

| Scope | Shared by | Lifetime |
| --- | --- | --- |
| `$Session:` | all tabs of one browser (one session cookie) | until the session ends (idle timeout) |
| `$Page:` | one tab | until the tab reloads or closes; survives the light/dark switch and `Sync-UDElement` |
| a file or table per `$User` | all browsers and devices of the reader | until the app removes it |

`-View $Session:PivotView` would hand the last change of one tab to every other tab on its next
reload. `$Page:` is per tab but gone after a reload, which the address bar and the tab's storage
already cover.
For a view that follows the reader to other devices, store it per `$User` (as a
[template store](stores.md#template-stores-templatestore) does), either on every change or with an
explicit "save as my default", and pass it as `-SavedView`.

Without `-Id` the report is identified by its page and its place in the app script (the line of the
`New-UDPivotReport` call) together with its column names, so two reports on one page keep their own
views. Set `-Id` if reports are added or removed dynamically, or when one call builds several reports
(a loop): they would share one view otherwise.

## Templates

Named views in the **Views** menu - shared views your app ships (`-Templates`, view files from
`-TemplatePath`), the reader's own views (`-TemplateStore`), Save, Save as and New, and who may
publish shared ones (`-AdminRole`) - have a page of their own: [Templates, view files and roles](templates.md).
A view loaded from Views shows its name in the toolbar; `-SavedView` and the view of a tab bring
back the view, not its name.
