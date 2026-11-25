---
title: Templates, view files and roles
description: "Shared views and my views in the Views menu of New-UDPivotReport: -Templates, view files from a folder (-TemplatePath) and the view file format, with links to the template stores, the roles and how ids are built."
---

# Templates, view files and roles

A **template** is a [view](views.md) with a name. The report's **Views** menu lists them in two
groups:

- **Shared views** - the same for everyone: what your app ships (`-Templates`, view files from
  `-TemplatePath`) and what admins published.
- **My views** - the reader's own, saved with **Save as…** (**Save current view** before a view is
  loaded).

Each entry loads its view with one click (one undo step); the first three are also offered on the
empty report. The view loaded has a check mark in the menu, and its name shows in the toolbar next to
Views, with a dot while it has unsaved changes. The menu starts with **This view**:

| Entry | What it does |
| --- | --- |
| **Save “…”** | Writes the loaded view under its own name in one click: one of My views through the store or `-OnSaveTemplate`; a shared view through Publish, only for a reader with a role of `-AdminRole` and after "Replace the shared view “…” for everyone?". Off, with the reason, for a shared view the reader may not change, a view from a file or a link, and an empty report. |
| **Save as…** | Saves the view as one of My views under a name; a name the reader's views have asks "“…” exists. Replace it?" first (Cancel has the focus). |
| **New, empty report** | Empties the report to its start screen in one undo step; the report then shows no saved view. |

Save and a confirmed Save as send the name of a view that exists: the store replaces that view (an
upsert, see [Saving a name that exists](stores.md#in-files-on-the-server-new-udpivotfiletemplatestore)), and
your own `-OnSaveTemplate` and `-OnPublishTemplate` must do the same. Undo and Redo carry the view's
name with the view; Reset and New take it away. The menu is a flat list to scan; Save as…, Share and
the questions before a delete, a publish or a Save over a shared view open levels of their own, with
‹ Back. **Share** (under its own heading, Share this view) has **Copy link**, **Copy view as JSON**,
**Download view** (a [view file](#view-files)) and **Load view…** (a view file, JSON or a link). **More** is
always at the end of the toolbar, with Help first. Toolbar buttons that do not fit move into it
below Help: Data first, then Start over, and Views last, only when the report is narrow.

| What you want | Parameters |
| --- | --- |
| Views you ship with the app | `-Templates`, `-TemplatePath` |
| Readers keep their own views in their browser | `-TemplateStore Browser` |
| Readers keep their own views on the server, admins publish shared ones | `-TemplateStore (New-UDPivotFileTemplateStore)` with `-AdminRole` |
| The same on a database, Valkey or S3 | `-TemplateStore (New-UDPivotTemplateStore ...)` with `-AdminRole` |
| Your own code for everything | `-OnSaveTemplate`, `-OnDeleteTemplate`, `-OnPublishTemplate` |

Without `-TemplateStore` and without `-OnSaveTemplate` nothing is written: the menu offers no Save.

--8<-- "examples/shared-views-and-my-views.md"

## Views you ship: `-Templates` and `-TemplatePath`

```powershell
New-UDPivotReport -Id 'tickets' -Data $tickets -TemplatePath (Join-Path $PSScriptRoot 'views') -Templates @(
    @{ Name = 'Tickets per team'; View = @{ rows = @('Team'); values = @(@{ field = 'Ticket'; agg = 'count' }) } }
    @{ File = (Get-Content -LiteralPath ./lead-time.pivotkit.json -Raw) }
)
```

- `-Templates`: entries with `Name` and `View` (a hashtable or JSON), or `File` (a view file as text or
  object; its name is the default of `Name`). `Scope` is `shared` or `user` (without it, as in
  pivotkit, an entry with `Deletable = $true` is the reader's own and every other one shared);
  `Deletable` gives an entry a delete button when `-OnDeleteTemplate` is set.
- `-TemplatePath`: one or more folders of view files (`*.pivotkit.json`, not their subfolders), read
  on the server on every render, in the order of their file names, listed under Shared views and
  read-only. A module ships its views this way: `-TemplatePath (Join-Path $PSScriptRoot 'views')`; an
  app script can do the same (PSU sets `$PSScriptRoot` for it, measured on PSU 2026.2.5 and 2026.3.4).
  A report lists the files made for its data (their `source.id` is its `-SourceId`, else its `-Id`,
  compared with case) and those that name no data, as the template stores do, so one folder can hold
  the views of several reports.
- With a [template store](stores.md#template-stores-templatestore), a shared view of the store with the same
  name (the same characters in the same case) takes the place of a shipped shared view, from
  `-Templates` or a file, in the menu: an admin who saves or publishes over a shipped view writes it
  to the store, and the menu shows that view once. The shipped view stays the default: delete the
  shared view and it is offered again.

Every file is checked before it reaches the page: at most 1,000,000 characters and 16 levels, a
format version and a view version this module reads, a name of 1 to 120 characters of plain text, a
view `ConvertFrom-UDPivotView` accepts. A file that does not pass is left out with a warning in the
app's log, so one broken file never breaks a page. At most 500 templates reach the report.

The simplest way to a view file: build the view in the report, then **Views, Download view**.

## View files

A view file is pivotkit's JSON format for a view with its name and the data it was made for. The
report writes it for Copy view as JSON and Download view, the template stores keep views in it, and
`-TemplatePath` reads it:

```json
{
  "$schema": "https://pivotkit.eize.dev/schema/view-file-2.json",
  "format": "pivotkit-view",
  "formatVersion": 2,
  "name": "Open work per team",
  "description": "Tickets not closed yet, per team and priority.",
  "source": { "id": "tickets", "name": "Tickets" },
  "extensions": {},
  "view": {
    "version": 2,
    "rows": ["Team"],
    "cols": ["Priority"],
    "values": [{ "field": "Ticket", "agg": "count" }],
    "filters": [{ "field": "Status", "type": "in", "items": ["Open", "Waiting"], "blanks": "exclude" }]
  }
}
```

Format version 2 carries a view of version 2 ([filters](filters.md)), which the report writes.
Files of format version 1 (views of version 1) are read as they are:
the report migrates their filters to version 2 with the same result, and the module keeps them
unchanged on the server until they are saved again.

The whole format, its rules and its JSON Schema: [View file format](https://pivotkit.eize.dev/reference/view-file/)
on pivotkit's site. In PowerShell:

| Command | What |
| --- | --- |
| `ConvertFrom-UDPivotViewFile` | Reads a view file of format version 1 or 2 (or `{ name, view }`, or a bare view with `-Name`) as untrusted input: `Name`, `Description`, `Source`, `View`. Refuses a newer format or view version (above 2), since saving it again would lose what the newer version added. |
| `ConvertTo-UDPivotViewFile` | Writes one, in pivotkit's key order with a trailing newline: format version 2 for a view of version 2, format version 1 for a view of version 1 or without `version`. Without `-CreatedAt` the same view gives the same bytes, so a file kept in git changes only with the view. |

`source` names the data a view was made for: `-SourceId` (default: `-Id`, or the key the module
derives without one) and `-SourceName` (default: `-Label`) of the report. Loading a view made for
another id asks first (Load anyway, Cancel). Give two reports of the same data the same `-SourceId`.

The Views menu offers the views of a template store (`Browser` included) made for the report's
`-SourceId` and those that name no data. The default follows `-Id`, so a report that shows other data
on every call under the same `-Id` - an uploaded file, a parameter the reader picks - sets
`-SourceId` per data source: otherwise the views saved for one file or parameter show for all of them,
and those for fields the data lacks report unused parts when loaded. For a file the server reads
(an upload), pass the file name and a hash of its name and column names, the id pivotkit gives a file
a reader loads with `-AllowImport` itself:

```powershell
$columnHash = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes((@($fileName) + $columnNames) -join [char]0))
New-UDPivotReport -Id 'upload' -Data $rows -SourceId ('{0}#{1}' -f $fileName, [System.Convert]::ToHexString($columnHash, 0, 8).ToLowerInvariant())
```

A file loaded in the browser with `-AllowImport` needs none of this: its views are kept per file in
the browser, whatever `-SourceId` and `-TemplateStore` say ([Readers' own files](import.md#views-per-file)).

Use a name the reader may see (it is in view files and links), never a path on the server.
`-SchemaUrl` sets the file's `$schema`. Loading never depends on it: [The `$schema` of a view file](schema.md).

## More on views

- [The `$schema` of a view file](schema.md): `-SchemaUrl` and `PSU_COMPONENT_PIVOT_SCHEMA_URL`.
- [Template stores](stores.md): `-TemplateStore` keeps readers' own views and shared views in the
  browser, in files, or on your own storage.
- [Roles and your own code](roles.md): who may change shared views (`-AdminRole`), and
  `-OnSaveTemplate`, `-OnDeleteTemplate` and `-OnPublishTemplate`.

### How ids and names are built { #ids }

The ids and names the report and its stores build: [How ids and names are built](ids.md).
