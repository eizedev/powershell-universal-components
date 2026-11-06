---
title: Events, security and limits
description: "The events of New-UDPivotReport ($EventData of -OnViewChange, -OnCellClick, -OnSaveTemplate, -OnDeleteTemplate), security notes, size and limits."
---

# Events, security and limits

## Events

Every event runs a script block on the server with `$EventData`:

| Parameter | When | `$EventData` |
| --- | --- | --- |
| `-OnViewChange` | The reader changed the view and paused for 0.6 seconds | `view` (an object), `json` (the same as JSON text) |
| `-OnCellClick` | A click (or Enter) on a value or a chart point | `row`, `col` (the key paths), `rowFields`, `colFields`, `filter` (one `@{ field; value }` per level, rows first), `valueField`, `value`, `text` (as shown), `count` (source rows), `rows` (the first 100 of them) |
| `-OnSaveTemplate` | The reader saves the view under a name | `name`, `view`, `json` |
| `-OnDeleteTemplate` | The reader deletes a template and confirmed it | `name` |

```powershell
New-UDPivotReport -Data $tickets -OnCellClick {
    $where = ($EventData.filter | ForEach-Object { '{0} = {1}' -f $_.field, $_.value }) -join ', '
    Show-UDToast -Message "$($EventData.count) tickets ($where)"
}
```

A grouped date has its group as value: `202605` for May 2026 by month, `2026` by year. The panel with
the source rows opens on every click; `-NoDrillDown` turns it off, `-OnCellClick` still runs.

`-OnViewChange` can keep the reader's layout, for example for the session:
`$Session:PivotView = ConvertFrom-UDPivotView -InputObject $EventData.json`, then `-View $Session:PivotView`
when the page is built again. Saving and deleting templates: [Views and templates](views.md).

## Security notes

- All rows go to the browser, and readers can see every column in the field list and the drill-down:
  select the columns a reader may see first (`Select-Object`, the SQL query).
- `$EventData` comes from the browser: treat it as user input. Check views with
  `ConvertFrom-UDPivotView` before storing them, never build file paths or queries from names or values
  without checking them, and never pass any of it to `Invoke-Expression`.
- Views are data. The report checks them against the data and runs nothing from them; formats are
  names, not code. The table and the drill-down show values as text, never as HTML.
- Exports are made in the browser from what the reader sees; nothing is sent to a server. The CSV
  export guards against formulas (a value starting with `=`, `+`, `-` or `@` is not run by Excel).
- The report loads nothing from the internet.

## Size and limits

The module's bundle is about 1 MB (pivotkit, the parts of Apache ECharts the chart uses, drag and drop);
the browser downloads it once and caches it. The pivot runs in the browser: tens of thousands of rows
stay fast (measured by hand on one laptop: about a tenth of a second to read 100,000 rows once, a frame
or two for a change of the view);
the limit is what the server sends and the browser holds. A layout with more cells than the table can
show says so instead of drawing them. ECharts and the Excel export are set up on first use.
