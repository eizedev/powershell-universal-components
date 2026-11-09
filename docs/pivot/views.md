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
| `rows`, `cols` | Field names, outermost first. |
| `values` | `@{ field = 'Cost'; agg = 'sum'; format = 'currency:EUR' }`: aggregators `sum`, `count`, `countUnique`, `average`, `median`, `min`, `max`, `stdev`, `var`, `first`, `last`, ...; formats `number`, `number:2`, `integer`, `percent`, `currency:EUR`, `compact`, `bytes`, `duration:h`, `date`, `datetime`, `time`; `showAs = @{ type = 'percentOfGrandTotal' }` and the other "show as" types. |
| `filters` | `@{ field = 'Status'; type = 'include'; items = @('Open', 'Waiting') }`; also `exclude`, `label` (a rule on the names), `compare` (the item itself compared: `@{ field = 'Created (Year)'; type = 'compare'; op = '>='; value = 2022 }`, a date by its calendar day `'2025-01-01'`, `op` one of `=`, `!=`, `>`, `>=`, `<`, `<=`, `between`, `notBetween` with `value2`), `relative` (the last N years, months or days, today's included: `@{ field = 'Created'; type = 'relative'; unit = 'year'; count = 2 }`; `anchor = 'latest'` counts back from the latest date of the field's data instead of today), `top`, `value` (a rule on the total). |
| `derived` | Grouped dates and number ranges: `@{ name = 'Created (Month)'; field = 'Created'; by = 'yearMonth' }` (units `year`, `yearQuarter`, `yearMonth`, `yearWeek`, `day`, `quarter`, `month`, `week`, `weekday`, `hour`); the name then goes into `rows` or `cols`. |
| `sort` | `@{ field = 'Team'; by = 'value'; order = 'desc' }`. |
| `totals` | `@{ grandTotalRow = $true; grandTotalColumn = $true; rowSubtotals = $true; colSubtotals = $true }`. |
| `display`, `chart` | `'table'` or `'chart'`; `@{ type = 'bar'; stacked = $false; horizontal = $false }`, types `auto` (the default: lines over dates, bars otherwise), `bar`, `line`, `area`, `pie`, `donut`, `heatmap`; the Display settings `valueLabels` (`auto`, `off`, `value`, `percent`, `both`), `legend` (`auto`, `bottom`, `right`, `off`), `title`, `smooth`, `axisLabels` (`auto`, `all`, `nth`), `groupLabels` (`auto`, `on`, `off`) and, for a pie or donut, `labelPosition` (`outside`, `inside`). |

A `relative` filter and the quick choices of the Filter level keep a rule, not dates: "today" is read
when the report computes, in the browser, from the reader's clock at the wall time of `-TimeZone`
(pivotkit-core's `now` option; the module passes none, so a view saved today still shows "last 2
years" next year). A view with a `compare` or `relative` filter loaded by a report on pivotkit 0.2.0
(this module before 0.3.0) reports that filter as an unused part and leaves it out; views saved by
earlier versions load unchanged (the view file format stays version 1).

The simplest way to a view is to build it in the report and copy it: **Views, Share, Copy view as JSON** (a
[view file](templates.md#view-files); `-View` takes its `view`), or `$EventData.json` of `-OnViewChange`.
`-View` takes that JSON as it is.

`Reset` in the toolbar goes back to `-View`. `Set-UDElement -Id <id> -Properties @{ view = $view }`
shows another view (the reader can undo it), and `(Get-UDElement -Id <id>).view` is the view the reader
has now.

The browser tab keeps the reader's view: PSU builds the report anew when the app switches between
light and dark, and the report comes back with the same fields, table or chart, chart type and
collapsed groups. Undo and redo start over then; `Reset` still goes back to `-View`, and from then on
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

!!! warning "Filter values appear in the address"
    The view includes filter values: a customer name in a filter is then in the address, in the
    browser history, in every copied link, and in the page address PSU sends with its requests to the
    server (header `windowlocation`, measured on PSU 2026.3.4). For reports whose filter values are
    sensitive, use `-NoAddressBar`: the view stays in the tab's sessionStorage only, and a view in a
    link is ignored.

The view in a link is input like any other: the report checks it against the data and drops what does
not fit, and nothing in it runs as code.

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
and `Reset` goes back to `-View`. The difference matters because PSU's scopes are not per tab
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
[template store](templates.md#template-stores-templatestore) does), either on every change or with an
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
