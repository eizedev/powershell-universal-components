---
title: Coming from UniversalDashboard.Pivot
description: "Move an app from New-UDPivot of UniversalDashboard.Pivot to New-UDPivotReport: what each parameter becomes, and one report before and after."
---

# Coming from UniversalDashboard.Pivot

`New-UDPivotReport` replaces `New-UDPivot` of [UniversalDashboard.Pivot](https://github.com/eizedev/UniversalDashboard.Pivot),
which wraps react-pivottable.

## Requirements

- PowerShell 7.4 or later, in the PSU environment the app runs in. UniversalDashboard.Pivot also ran
  on Windows PowerShell 5.1; this module does not load there.
- PowerShell Universal 2026.2 or 2026.3, tested with 2026.2.5 and 2026.3.4.

[Compatibility](../compatibility.md) has the details and how each version is tested.

## One report before and after

The start view moves from parameters into one `-View` ([Views](views.md#the-start-view-view)). The
same rows, before and after:

```powershell
$data = @(
    @{ Team = 'OPS'; Status = 'Open'; Priority = 'High'; Hours = 5 }
    @{ Team = 'OPS'; Status = 'Closed'; Priority = 'Low'; Hours = 2 }
    @{ Team = 'OPS'; Status = 'Closed'; Priority = 'High'; Hours = 4 }
    @{ Team = 'DEV'; Status = 'Open'; Priority = 'High'; Hours = 8 }
    @{ Team = 'DEV'; Status = 'Closed'; Priority = 'Medium'; Hours = 3 }
    @{ Team = 'DEV'; Status = 'Open'; Priority = 'Low'; Hours = 6 }
    @{ Team = 'QA'; Status = 'Open'; Priority = 'Medium'; Hours = 1 }
    @{ Team = 'QA'; Status = 'Closed'; Priority = 'High'; Hours = 7 }
)
# before
New-UDPivot -Id 'tickets-before' -Data $data -Rows 'Team' -Cols 'Status' -Vals 'Hours' -AggregatorName 'Sum' -RowOrder 'value_z_to_a' -ValueFilter @{ Priority = @{ Low = $true } }
# after
New-UDPivotReport -Id 'tickets-after' -Data $data -View @{
    rows    = @('Team')
    cols    = @('Status')
    values  = @(@{ field = 'Hours'; agg = 'sum' })
    filters = @(@{ field = 'Priority'; type = 'in'; items = @('Low'); not = $true; blanks = 'include' })
    sort    = @(@{ field = 'Team'; by = 'value'; order = 'desc' })
}
```

Both show the sum of hours without the Low tickets, the teams by their total, highest first: DEV 11,
OPS 9, QA 8.

## Parameters

| `New-UDPivot` | `New-UDPivotReport` |
| --- | --- |
| `-Id`, `-Data` | `-Id`, `-Data`: also a DataTable ([Data and loading](data.md)) |
| `-Rows`, `-Cols` | `rows`, `cols` in `-View` |
| `-RowOrder`, `-ColOrder` | `key_a_to_z`: the default. `value_a_to_z`, `value_z_to_a`: `sort = @(@{ field = 'Team'; by = 'value'; order = 'asc' })` or `'desc'`, per row or column field. |
| `-ValueFilter` | `filters`: the listed items with `type = 'in'; not = $true; blanks = 'include'` ([Filters](filters.md)). |
| `-HiddenAttributes` | No counterpart: leave the column out of the rows you pass to `-Data` (`Select-Object -ExcludeProperty` for objects), so it does not reach the browser either. |
| `-HiddenFromAggregators`, `-HiddenFromDragDrop`, `-MenuLimit`, `-UnusedOrientationCutoff` | No counterpart. |

## Aggregators

`-Vals` and `-AggregatorName` become `values` in `-View`, each with its field and `agg`.

| `-AggregatorName` | `agg` in `values` |
| --- | --- |
| `Count` | `count` on a field: it counts the rows where the field has a value. |
| `Count Unique Values`, `List Unique Values` | `countUnique`, `listUnique` |
| `Sum`, `Integer Sum` | `sum`; for `Integer Sum` with `format = 'integer'` |
| `Average`, `Median`, `Minimum`, `Maximum`, `First`, `Last` | `average`, `median`, `min`, `max`, `first`, `last` |
| `Sample Variance`, `Sample Standard Deviation` | `var`, `stdev` |
| `Sum as Fraction of Total`, `of Rows`, `of Columns`; the same for `Count` | `sum` or `count` with `showAs = @{ type = 'percentOfGrandTotal' }`, `'percentOfRowTotal'`, `'percentOfColumnTotal'` |
| `Sum over Sum`, `80% Upper Bound`, `80% Lower Bound` | No counterpart. |

## Renderers

`-RendererName` becomes the value's `conditional` or the view's `display` and `chart`.

| `-RendererName` | In `-View` |
| --- | --- |
| `Table` | The default. |
| `Table Heatmap` | `conditional = @{ type = 'colorScale' }` on the value |
| `Grouped Column Chart`, `Stacked Column Chart` | `display = 'chart'; chart = @{ type = 'bar' }`; for stacked columns `chart = @{ type = 'bar'; stacked = $true }` |
| `Grouped Bar Chart`, `Stacked Bar Chart` | the same as the column charts, with `horizontal = $true` in `chart` |
| `Line Chart`, `Area Chart` | `display = 'chart'; chart = @{ type = 'line' }`, or `type = 'area'` |
| `Exportable TSV` | The reader's export copies the table as tab-separated text. |
| `Table Row Heatmap`, `Table Col Heatmap`, `Dot Chart`, `Scatter Chart`, `Multiple Pie Chart` | No counterpart. `type = 'pie'` draws one pie of the row totals. |

Next: [Views](views.md), [Data and loading](data.md), [Overview](index.md).
