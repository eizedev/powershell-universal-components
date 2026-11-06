---
title: Views and templates
description: "The start view of New-UDPivotReport, templates in the Templates menu, and how readers save their own templates - stored by your app, checked with ConvertFrom-UDPivotView."
---

# Views and templates

A **view** is what the report shows, as plain JSON: the fields on rows, columns, values and filters,
sorting, totals, table or chart. It is the start view, a template and an undo step at once. The report
checks every view against the data and drops what does not fit (an unknown field, an aggregator that
does not suit the field); a view never runs as code.

## The start view: -View

```powershell
New-UDPivotReport -Data $tickets -View @{
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

## Templates: -Templates

```powershell
New-UDPivotReport -Data $tickets -Templates @(
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
New-UDPivotReport -Data $tickets -Templates $templates -OnSaveTemplate {
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
variable.
