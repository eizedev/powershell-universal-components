---
title: Views and templates
description: "The start view of New-UDPivotReport, views per browser tab and -SavedView, templates in the Templates menu, and how readers save their own templates - stored by your app, checked with ConvertFrom-UDPivotView."
---

# Views and templates

A **view** is what the report shows, as plain JSON: the fields on rows, columns, values and filters,
sorting, totals, table or chart. It is the start view, a template and an undo step at once. The report
checks every view against the data and drops what does not fit (an unknown field, an aggregator that
does not suit the field); a view never runs as code.

## The start view: -View

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
| `filters` | `@{ field = 'Status'; type = 'include'; items = @('Open', 'Waiting') }`; also `exclude`, `label` (text conditions), `top`, `value`. |
| `derived` | Grouped dates and number ranges: `@{ name = 'Created (Month)'; field = 'Created'; by = 'yearMonth' }` (units `year`, `yearQuarter`, `yearMonth`, `yearWeek`, `day`, `quarter`, `month`, `week`, `weekday`, `hour`); the name then goes into `rows` or `cols`. |
| `sort` | `@{ field = 'Team'; by = 'value'; order = 'desc' }`. |
| `totals` | `@{ grandTotalRow = $true; grandTotalColumn = $true; rowSubtotals = $true; colSubtotals = $true }`. |
| `display`, `chart` | `'table'` or `'chart'`; `@{ type = 'bar'; stacked = $false; horizontal = $false }`, types `bar`, `line`, `area`, `pie`, `heatmap`. |

The simplest way to a view is to build it in the report, save it as a template and copy the JSON
(`$EventData.json` of `-OnSaveTemplate` or `-OnViewChange`). `-View` takes that JSON as it is.

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
For a view that follows the reader to other devices, store it per `$User` (as the
[templates](#templates-readers-save) below), either on every change or with an explicit "save as my
default", and pass it as `-SavedView`.

Without `-Id` the report is identified by its page and its place in the app script (the line of the
`New-UDPivotReport` call) together with its column names, so two reports on one page keep their own
views. Set `-Id` if reports are added or removed dynamically, or when one call builds several reports
(a loop): they would share one view otherwise.

## Templates: -Templates

```powershell
New-UDPivotReport -Id 'tickets' -Data $tickets -Templates @(
    @{ Name = 'Tickets per team'; View = @{ rows = @('Team'); values = @(@{ field = 'Ticket'; agg = 'count' }) } }
    @{ Name = 'Lead time per month'; View = (Get-Content -LiteralPath ./lead-time.json -Raw) }
)
```

The Templates menu lists them; the first three are also offered on an empty report.

## Templates readers save

`-OnSaveTemplate` shows "Save current view" in the menu; `-OnDeleteTemplate` a delete button on every
template marked `Deletable = $true`. The module only raises the events: your app decides where
templates go - a file per user, a database table, `$Cache` for everyone. The report shows a saved
template (or removes a deleted one) once the script block finished without an error.

The view comes from the browser: treat it as untrusted input. `ConvertFrom-UDPivotView` is the check
before it is stored. It accepts JSON, a hashtable or an object, goes through one
`ConvertTo-Json`/`ConvertFrom-Json` round trip (nothing is evaluated), refuses anything that is not
a view of at most 64 KB and eight levels, keeps only the keys of a view and returns it as an object,
or with `-AsJson` as compact JSON to store. Check the name too, and never build a file path from it.

```powershell
New-UDPivotReport -Id 'tickets' -Data $tickets -Templates $templates -OnSaveTemplate {
    try {
        $name = ([string]$EventData.name).Trim()
        if ($name.Length -gt 80) { throw 'A template name has at most 80 characters.' }
        $json = ConvertFrom-UDPivotView -InputObject $EventData.view -AsJson
        # store $name and $json for $User: a database row, or a file named after a hash of $User
    }
    catch {
        # the reader sees this text in the report; nothing was stored
        @{ error = $_.Exception.Message }
    }
} -OnDeleteTemplate {
    # remove $EventData.name of $User
}
```

A script block that throws refuses too, but the reader then sees only "the server reported an error"
(PSU does not pass the message on); return `@{ error = '...' }` to say why.

The [showcase app](https://github.com/eizedev/powershell-universal-components/blob/main/modules/PowerShellUniversal.Component.Pivot/examples/showcase.ps1)
keeps templates as one JSON file per user next to the PSU repository, with built-in templates no user
template may replace, a limit per user, a lock against two saves at once, and every stored view checked
again when it is read.

Event handlers run in a runspace of their own: functions defined in the app script are not there, and
PSU does not load the module by itself. Call `Import-Module PowerShellUniversal.Component.Pivot` in a
handler that uses `ConvertFrom-UDPivotView`, and keep shared code in a module or a script block
variable. A script block defined in the app script runs where it was defined: it does not see `$User`
and `$Roles` of the page or the event that calls it (measured on PSU 2026.2.5 and 2026.3.4, an app
with authentication). Pass them as parameters, as the showcase passes `-UserName $User` to its store.
