---
title: Events, security and limits
description: "The events of New-UDPivotReport ($EventData of -OnViewChange, -OnCellClick, -OnSaveTemplate, -OnDeleteTemplate, -OnPublishTemplate), security notes, size and limits."
---

# Events, security and limits

## Events

Every event runs a script block on the server with `$EventData`:

| Parameter | When | `$EventData` |
| --- | --- | --- |
| `-OnViewChange` | The reader changed the view and paused for 0.6 seconds | `view` (an object), `json` (the same as JSON text) |
| `-OnCellClick` | A click (or Enter) on a value or a chart point | `row`, `col` (the key paths), `rowFields`, `colFields`, `filter` (one `@{ field; value }` per level, rows first), `valueField`, `value`, `text` (as shown), `count` (source rows), `rows` (the first 100 of them) |
| `-OnSaveTemplate` | The reader saves the view: Save as… under a new name, or Save and a confirmed Save as under the name of one of their views (replace that view) | `name`, `view`, `json`, `scope` (`user`) |
| `-OnDeleteTemplate` | The reader deletes a template and confirmed it | `name`, `scope` (`user` or `shared`) |
| `-OnPublishTemplate` | A reader with a role of `-AdminRole` publishes one of their views as a shared view, or saves a loaded shared view (Save: replace that view) | `name`, `view`, `json` |

With `-TemplateStore` the module registers the three template events itself
([Templates, view files and roles](templates.md)).

```powershell
New-UDPivotReport -Id 'tickets' -Data $tickets -OnCellClick {
    $where = ($EventData.filter | ForEach-Object { '{0} = {1}' -f $_.field, $_.value }) -join ', '
    Show-UDToast -Message "$($EventData.count) tickets ($where)"
}
```

A grouped date has its group as value: `202605` for May 2026 by month, `2026` by year. The panel with
the source rows opens on every click; `-NoDrillDown` turns it off, `-OnCellClick` still runs.

`-OnViewChange` can keep the reader's layout, for example for the session:
`$Session:PivotView = ConvertFrom-UDPivotView -InputObject $EventData.json`, then `-SavedView $Session:PivotView`
when the page is built again (not `-View`: `$Session` is shared by all tabs of a browser, see
[several tabs](views.md#several-tabs-and-keeping-the-readers-view)). Saving, publishing and deleting
templates: [Templates, view files and roles](templates.md).

## Security notes

- All rows go to the browser, and readers can see every column in the field list and the drill-down:
  select the columns a reader may see first (`Select-Object`, the SQL query).
- `$EventData` comes from the browser: treat it as user input. Check views with
  `ConvertFrom-UDPivotView` before storing them, never build file paths or queries from names or values
  without checking them, and never pass any of it to `Invoke-Expression`.
- Who may change shared views is decided on the server: `-AdminRole` with a template store checks
  `$Roles` of every save, publish and delete event; the browser only hides what a reader may not do.
  In your own `-OnPublishTemplate` and `-OnDeleteTemplate`, check `$Roles` yourself
  ([Templates, view files and roles](templates.md#who-may-change-shared-views-adminrole)).
- View files from `-TemplatePath` and a store are read as untrusted input: size, depth, version and the
  view are checked, and a file that does not pass is left out.
- Copying (Copy table, Copy data as JSON, the drill-down's Copy) works without the browser's Clipboard
  API, which browsers offer only on https: over plain http pivotkit uses the older copy command
  (measured in Chromium, Firefox and WebKit on PSU 2026.3.4 over http). Where a browser refuses it,
  the report says "This page does not allow copying. Download a file instead."
- The reader's view, filter values included, is written into the address bar
  ([views](views.md#the-start-view-view)): it is in the browser history and in a copied link, and PSU
  sends the page address with its requests. `-NoAddressBar` keeps it out for sensitive data. A view
  from a link is checked like every other view.
- Views are data. The report checks them against the data and runs nothing from them; formats are
  names, not code. The table and the drill-down show values as text, never as HTML, and so are field
  labels and descriptions; a description's link must be `https://`.
- `-Schema` with a URL is fetched by the server (https only, 15 seconds, at most 1 MB), never by the
  browser; pass only addresses you trust, never one a reader typed. `-ChartOptions` is plain JSON:
  pivotkit drops options that are markup or addresses.
- Exports and copies are made in the browser from what the reader sees; nothing is sent to a server. The CSV
  export guards against formulas (a value starting with `=`, `+`, `-` or `@` is not run by Excel).
- The report loads nothing from the internet.

## Size and limits

The module's bundle is about 1 MB (pivotkit, the parts of Apache ECharts the chart uses, drag and drop);
the browser downloads it once and caches it. The pivot runs in the browser: tens of thousands of rows
stay fast (measured by hand on one laptop: about a tenth of a second to read 100,000 rows once, a frame
or two for a change of the view);
the limit is what the server sends and the browser holds. A layout with more cells than the table can
show says so instead of drawing them. ECharts, the menus and the Excel export are set up on first use;
they are all in the module's one bundle, since PSU serves only the bundle it registered.
