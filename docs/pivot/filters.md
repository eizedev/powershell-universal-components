---
title: Filters in a view
description: "The filters of a New-UDPivotReport view: one shape for every filter (field, type, not, blanks), the types in, blank, text, compare, relative, value and top, and rules that move with today."
---

# Filters in a view

For app authors who write a start view or a template with filters. Readers set filters in the report
itself ([pivotkit's guide](https://pivotkit.eize.dev/use/filters/)); the view keeps them in the form below.

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

Next: [Views](views.md), [Templates, view files and roles](templates.md).
