---
title: Templates, view files and roles
description: "Shared views and my views in the Views menu of New-UDPivotReport: -Templates, view files from a folder (-TemplatePath), template stores in the browser, in files or on your own storage (-TemplateStore), and who may change shared views (-AdminRole)."
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
upsert, see [Saving a name that exists](#in-files-on-the-server-new-udpivotfiletemplatestore)), and
your own `-OnSaveTemplate` and `-OnPublishTemplate` must do the same. Undo and Redo carry the view's
name with the view; Reset and New take it away. The menu is a flat list to scan; Save as…, Share and
the questions before a delete, a publish or a Save over a shared view open levels of their own, with
‹ Back. **Share** (under its own heading, Share this view) has **Copy link**, **Copy view as JSON**,
**Download view** (a [view file](#view-files)) and **Load view…** (a view file, JSON or a link). Toolbar buttons
that do not fit move into **More**; Views is the last to go (pivotkit's order: Reset, Layout,
Options, the chart type, Views), so it moves under More only when the report is narrow.

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
  With a [template store](#template-stores-templatestore), a shared view of the store with the same
  name (the same characters in the same case) takes the file's place in the menu: an admin who saves
  or publishes over a shipped view writes it to the store, and the menu shows that view. The file stays
  the default: delete the shared view and the file is offered again.

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
  "$schema": "https://pivotkit.eize.dev/schema/view-file-1.json",
  "format": "pivotkit-view",
  "formatVersion": 1,
  "name": "Open work per team",
  "description": "Tickets not closed yet, per team and priority.",
  "source": { "id": "tickets", "name": "Tickets" },
  "extensions": {},
  "view": { "rows": ["Team"], "cols": ["Priority"], "values": [{ "field": "Ticket", "agg": "count" }] }
}
```

The whole format, its rules and its JSON Schema: [View file format](https://pivotkit.eize.dev/reference/view-file/)
on pivotkit's site. In PowerShell:

| Command | What |
| --- | --- |
| `ConvertFrom-UDPivotViewFile` | Reads a view file (or `{ name, view }`, or a bare view with `-Name`) as untrusted input: `Name`, `Description`, `Source`, `View`. Refuses a newer format or view version, since saving it again would lose what the newer version added. |
| `ConvertTo-UDPivotViewFile` | Writes one, in pivotkit's key order with a trailing newline; without `-CreatedAt` the same view gives the same bytes, so a file kept in git changes only with the view. |

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
`-SchemaUrl` sets the file's `$schema`: pivotkit's address by default, an https address of your own
copy, or `''` to leave it out; loading never depends on it.

## Template stores: `-TemplateStore`

### In the browser: `-TemplateStore Browser`

```powershell
New-UDPivotReport -Id 'tickets' -Data $tickets -TemplateStore Browser
```

pivotkit keeps each reader's views in the browser's localStorage (`pivotkit:views:<id>`): only in this
browser on this device, gone when the site's data is cleared, shared with nobody; the menu says so.
Each view names the `-SourceId` it was saved for, and the menu lists those of the report's
`-SourceId` (see [View files](#view-files) for data that changes per call).
At most 100 views and 500,000 characters. Nothing reaches the server, so nothing needs checking there.

### In files on the server: `New-UDPivotFileTemplateStore`

```powershell
$store = New-UDPivotFileTemplateStore

New-UDApp -Title 'Tickets' -Pages @(
    New-UDPage -Name 'Tickets' -Content {
        New-UDPivotReport -Id 'tickets' -Data (Get-Tickets) -TemplateStore $store -AdminRole 'Administrator'
    }
)
```

Every signed-in reader saves views under My views and finds them on every device. Readers with a role
of `-AdminRole` publish their views as shared views (Publish as shared view, asked in a level of the menu) and
delete shared views; everyone else sees shared views read-only. The store keeps view files:

| Path below `-Path` | What |
| --- | --- |
| `users/<hash of the user name>/<name>-<hash>.pivotkit.json` | A reader's own views |
| `shared/<name>-<hash>.pivotkit.json` | The shared views; also usable as a `-TemplatePath` |

- **Where**: without `-Path`, in `pivot-views` next to the PSU repository (`$Repository`, else
  `$env:Data__RepositoryPath`), never inside it: a repository synced with git would pick the files up,
  and PSU watches it. In PSU's Docker image that is `/data/pivot-views` with the repository in
  `/data/Repository` (measured on PSU 2026.2.5 and 2026.3.4). The PSU service account needs to write
  there.
- **Names**: the file name comes from the view's name (lower case, accents dropped, everything else a
  `-`, plus a hash of the name and the report's `-SourceId`), so a name never leaves the folder. A user's
  folder is a hash of the user name: the name itself is not on disk.
- **Saving a name that exists** replaces that view in its file (an upsert): the reader's own view for
  Save and Save as, the shared view for Publish and Save on a shared view. Names match as in pivotkit's Views menu: the same
  characters in the same case after trimming, so `Sales` and `sales` are two views. A report replaces
  the view made for its data, else one that names no data (which then still names none). A view stored
  twice (copied by hand) is left once.
- **Several reports** can share one store: each lists the views made for its data (`-SourceId`) and
  those that name no data, as pivotkit's browser store does; the same name in two reports is two views.
- **Writes**: to a new file that then replaces the old one, under a lock per folder, so two saves at the
  same moment never leave half a file or a count over the limit.
- **Limits**: `-MaxUserViews` (default 50) and `-MaxSharedViews` (default 200); a save over the limit
  says "At most 50 own views; delete one first." Every stored file is checked again when it is read.
- **Several PSU nodes** (high availability): a local folder is per node. Use a folder all nodes share,
  or a store on a database.

### On your own storage: `New-UDPivotTemplateStore`

When views belong in a database, a cache or object storage, write how one is stored; the module does
the rest - who may do what, the checks of names and views, the limits and the view file. Each script
block gets one argument, `$Request`:

| Script block | `$Request` | Returns |
| --- | --- | --- |
| `-Get` | `Scope` (`user` or `shared`), `User` (`$null` for shared), `UserKey` (a hash of the user name, safe in keys and file names) | The stored views: view file texts (the `Json` of a save), objects with `Json` and `FileName` (where the view is stored), or objects with `Name` and `View` |
| `-Save` | `Scope`, `User`, `UserKey`, `Name` (checked), `FileName`, `Key` (`users/<UserKey>/<FileName>` or `shared/<FileName>`), `Json` (the view file to store), `View` (the checked view) | Nothing; store `Json` under `FileName`, replacing what is there |
| `-Delete` | `Scope`, `User`, `UserKey`, `Name`, `FileName`, `Key` | Nothing |
| `-Publish` (optional) | As `-Save`, with `Scope` `shared` and `User` the publisher | Nothing; without it, publishing calls `-Save` with `Scope` `shared` |

Saving a name the scope has replaces that view, as in the file store: the module finds it in what
`-Get` returns (same name, same case) and passes its `FileName`, so `-Save` writes over it. For a
new name `FileName` is `<name>-<hash>.pivotkit.json` (a hash of the name and the `-SourceId`), one no
stored view has; when that one is taken, another (`<name>-<hash>.pivotkit.json` with another hash).

Return `FileName` from `-Get` (objects with `FileName` and `Json`). Without it the module can only
assume where a view is stored: the `FileName` a save of its name gives it. A view stored under another
one - put there by hand or by another tool, or given another `FileName` because the first was taken -
is then not found again, and the next save of its name adds a second entry instead of replacing it.

`-Delete` must succeed for a `Key` that is not stored (as `DELETE`, `HDEL` and S3 do): after a save the
module removes the other places a view of that name may be stored (a copy, the key version 0.1.0 gave
it), and where it has to guess, the key may not exist. A delete that fails there is a warning in the
app's log, not an error for a save that worked.

The lock the module holds while it lists and writes is a named mutex on one machine. With several PSU
nodes, two saves of a new name on two nodes at the same moment can both add it: give the storage a
unique key on scope, user and `FileName` (the SQL Server example's primary key), so the second
replaces the first instead of adding a row.

Throw to refuse; the reader sees the message. Like the file store, a report lists only the views made
for its `-SourceId` and those that name no data, so one store serves several reports. The script blocks run in the runspace of the app script
that defined them, for every reader: they do not see `$User` or `$Roles` (use `$Request`), and PSU
runs the event handlers in runspaces of their own, so a script block imports the modules it uses
itself. What `-Get` returns is checked again, like a file.

The examples below are sketches with no dependency of this module; check them against your own
servers and the current documentation of the modules they use.

#### SQL Server

A table `PivotViews (Scope nvarchar(10), UserKey nvarchar(24), FileName nvarchar(100), Json nvarchar(max))`
with a primary key on `(Scope, UserKey, FileName)`; shared views have an empty `UserKey`. Every
value goes in as a parameter, never into the query text.

```powershell
$connectionString = $Secret:PivotViewsDb   # a PSU secret
$run = {
    param([string]$Query, [hashtable]$Parameters)
    $connection = [Microsoft.Data.SqlClient.SqlConnection]::new($connectionString)
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandText = $Query
        foreach ($p in $Parameters.GetEnumerator()) { [void]$command.Parameters.AddWithValue($p.Key, [string]$p.Value) }
        $reader = $command.ExecuteReader()
        # Get reads FileName and Json; MERGE and DELETE return no rows
        while ($reader.Read()) { [pscustomobject]@{ FileName = $reader.GetString(0); Json = $reader.GetString(1) } }
    }
    finally { $connection.Dispose() }
}
$store = New-UDPivotTemplateStore -Get {
    param($Request)
    & $run 'SELECT FileName, Json FROM PivotViews WHERE Scope = @Scope AND UserKey = @UserKey ORDER BY FileName' @{ '@Scope' = $Request.Scope; '@UserKey' = "$($Request.UserKey)" }
} -Save {
    param($Request)
    & $run @'
MERGE PivotViews AS t USING (SELECT @Scope AS Scope, @UserKey AS UserKey, @FileName AS FileName) AS s
ON t.Scope = s.Scope AND t.UserKey = s.UserKey AND t.FileName = s.FileName
WHEN MATCHED THEN UPDATE SET Json = @Json
WHEN NOT MATCHED THEN INSERT (Scope, UserKey, FileName, Json) VALUES (@Scope, @UserKey, @FileName, @Json);
'@ @{ '@Scope' = $Request.Scope; '@UserKey' = "$($Request.UserKey)"; '@FileName' = $Request.FileName; '@Json' = $Request.Json }
} -Delete {
    param($Request)
    & $run 'DELETE FROM PivotViews WHERE Scope = @Scope AND UserKey = @UserKey AND FileName = @FileName' @{ '@Scope' = $Request.Scope; '@UserKey' = "$($Request.UserKey)"; '@FileName' = $Request.FileName }
}
```

#### Valkey or Redis

One hash per scope and user (`pivot:users:<UserKey>`, `pivot:shared`), the file name as the field.
The sketch calls `valkey-cli` (or `redis-cli`), which must be on the PSU server; a .NET client such as
StackExchange.Redis works the same way. The CLI prints one value per line, so each view is stored as
one line of JSON (a line break in a view file is only ever indentation: line breaks inside its texts
are escaped).

```powershell
$cli = { param([string[]]$Arguments) & valkey-cli -h 'valkey.example.org' --no-auth-warning @Arguments }
$hash = { param($Request) if ($Request.Scope -eq 'shared') { 'pivot:shared' } else { 'pivot:users:' + $Request.UserKey } }
$store = New-UDPivotTemplateStore -Get {
    param($Request)
    & $cli @('--raw', 'HVALS', (& $hash $Request)) | Where-Object { $_ }
} -Save {
    param($Request)
    & $cli @('HSET', (& $hash $Request), $Request.FileName, ($Request.Json -replace '\r?\n\s*', '')) | Out-Null
} -Delete {
    param($Request)
    & $cli @('HDEL', (& $hash $Request), $Request.FileName) | Out-Null
}
```

#### S3 (RustFS, MinIO, AWS)

One object per view under `pivot-views/` + `$Request.Key`, with the AWS.Tools.S3 module and an
S3-compatible endpoint (RustFS, MinIO) or AWS itself. Credentials come from the PSU service
account's AWS profile or a PSU secret, never from the script. Some S3-compatible servers need
path-style addresses: see the AWS.Tools documentation for your version.

```powershell
$s3 = @{ BucketName = 'psu-data'; EndpointUrl = 'https://s3.example.org' }
$store = New-UDPivotTemplateStore -Get {
    param($Request)
    Import-Module AWS.Tools.S3
    $prefix = if ($Request.Scope -eq 'shared') { 'pivot-views/shared/' } else { 'pivot-views/users/{0}/' -f $Request.UserKey }
    foreach ($object in Get-S3Object @s3 -Prefix $prefix) {
        $file = [System.IO.Path]::GetTempFileName()
        try {
            Read-S3Object @s3 -Key $object.Key -File $file | Out-Null
            Get-Content -LiteralPath $file -Raw
        }
        finally { Remove-Item -LiteralPath $file -ErrorAction Ignore }
    }
} -Save {
    param($Request)
    Import-Module AWS.Tools.S3
    Write-S3Object @s3 -Key ('pivot-views/' + $Request.Key) -Content $Request.Json -ContentType 'application/json'
} -Delete {
    param($Request)
    Import-Module AWS.Tools.S3
    Remove-S3Object @s3 -Key ('pivot-views/' + $Request.Key) -Force | Out-Null
}
```

## Who may change shared views: `-AdminRole`

`-AdminRole` names PSU roles (`$Roles`), for example `-AdminRole 'Administrator'` or a role of your own
from claims mapping. A reader with one of them gets:

- **Publish as shared view** next to each of their own views (asked in a level of the menu), and **Save “…”** on a
  shared view they loaded (after "Replace the shared view “…” for everyone?"),
- a delete button on every shared view, and
- the **admin panel** under the report: the current view as JSON, the columns with the type pivotkit
  reads them as, their distinct and blank values, how long the server took (converting the data, the
  whole `New-UDPivotReport`) and the browser (pivotkit's encode, pivot and grid of the last change), the
  number of rows, columns and templates, and the store. pivotkit's menus have no place for an app's own
  entries, so the panel is the module's own, collapsed until it is opened.

The browser only shows what the server allows. The checks that count run on the server, in the event
handlers the module registers for the store: every save, publish and delete reads `$User` and
`$Roles` of that event (set by PSU per request) and refuses a shared view without the role, whatever
the browser sends: "Only admins can change shared views." A reader's own views are found by their
`$User` only. Without a signed-in user (an app without authentication: `$User` is not defined there,
measured) the server cannot tell readers apart: their own views then stay in the browser (as
`-TemplateStore Browser`), and shared views come from the store.

### $User and $Roles of the page

`New-UDPivotReport` reads `$User` and `$Roles` of the code that calls it to list the reader's views and
to decide what the menu offers. That works in page code, `New-UDDynamic` and event handlers. A script
block or function defined in the app script does not see them (it runs in the session state it was
created in; measured on PSU 2026.2.5 and 2026.3.4): call the report there with `-UserName $User -Roles $Roles`,
taken from the page that calls the function.

```powershell
function Show-Tickets { param($UserName, $Roles) New-UDPivotReport -Id 'tickets' -Data $tickets -TemplateStore $store -AdminRole 'Administrator' -UserName $UserName -Roles $Roles }
New-UDPage -Name 'Tickets' -Content { Show-Tickets -UserName $User -Roles $Roles }
```

The event handlers always use the event's own `$User` and `$Roles`, not these parameters. A store keeps
what the module registered for it in the PSU process (keyed by app, report and settings), so the
handlers of a page find it after it was rendered; after a restart of the app the reader reloads the
page ("This page is out of date (the app was restarted); reload it.").

## Your own code: `-OnSaveTemplate`, `-OnDeleteTemplate`, `-OnPublishTemplate`

For full control, handle the events yourself instead of a store (the two cannot be combined):

| Parameter | `$EventData` |
| --- | --- |
| `-OnSaveTemplate` | `name`, `view`, `json`, `scope` (`user`) |
| `-OnDeleteTemplate` | `name`, `scope` (`user` or `shared`, the group of the entry) |
| `-OnPublishTemplate` | `name`, `view`, `json`; offered only to readers with a role of `-AdminRole` |

Save current view and Publish send the name of a view that exists when the reader saves over it:
replace that view (by its name, the same characters in the same case), do not add a second one.

The view comes from the browser: check it with `ConvertFrom-UDPivotView` (or write it with
`ConvertTo-UDPivotViewFile`, which checks it) before it is stored, check the name, never build a path
or a query from it, and check `$Roles` again in `-OnPublishTemplate` and for a shared delete - the
browser only hides the buttons. Return `@{ error = '...' }` to refuse with that text; a script block
that throws refuses too, but the reader then sees only "the server reported an error".

```powershell
New-UDPivotReport -Id 'tickets' -Data $tickets -Templates $templates -AdminRole 'Administrator' -OnSaveTemplate {
    try {
        $json = ConvertTo-UDPivotViewFile -View $EventData.view -Name $EventData.name -SourceId 'tickets'
        # store $json for $User: a database row, a file named after a hash of $User
    }
    catch { @{ error = $_.Exception.Message } }
} -OnPublishTemplate {
    if ($Roles -notcontains 'Administrator') { return @{ error = 'Only admins can change shared views.' } }
    # store $EventData for everyone
}
```

Event handlers run in a runspace of their own: functions defined in the app script are not there, and
PSU does not load the module by itself. Call `Import-Module PowerShellUniversal.Component.Pivot` in a
handler that uses the module's commands.

The [showcase app](https://github.com/eizedev/powershell-universal-components/blob/HEAD/modules/PowerShellUniversal.Component.Pivot/examples/showcase.ps1)
has no sign-in and shows `-Templates`, `-TemplatePath` and the file store (its readers' own views stay
in the browser);
[templates.ps1](https://github.com/eizedev/powershell-universal-components/blob/HEAD/modules/PowerShellUniversal.Component.Pivot/examples/templates.ps1)
is an app with sign-in, own views on the server, publishing for two roles and the admin panel.

## How ids and names are built { #ids }

The ids and names the report and the stores build, where they appear and why. Every rule is the
module's or pivotkit's code; nothing here needs to be set by hand.

| What | Rule | Example | Why |
| --- | --- | --- | --- |
| The report's key in the browser | `-Id`; without `-Id`: `auto-` and 16 hex characters of the SHA-256 of the call site in the app script (script, line, column) and the column names | `tickets`, `auto-3f9c0a1b2c4d5e6f` | The same key on every build of the page, so a reader's view comes back after a reload; no server path reaches the browser. |
| Source id of the app's data | `-SourceId`; default: the report's key above | `tickets` | Written into view files (`source.id`) and links; pivotkit asks before it loads a view made for another id; the Views menu offers the views of a store made for this id and those that name no data. Set it per data source when the data changes under the same `-Id` ([View files](#view-files)). |
| Source id of a file loaded with `-AllowImport` | pivotkit's rule: the file's name and a short hash of its name and column names ([pivotkit: How a loaded file is named](https://pivotkit.eize.dev/reference/import/#how-a-loaded-file-is-named)) | `tickets.csv#e51bd4bc21e98ee8` | The same file loaded again finds its views; a file with other or reordered columns is other data. Kept in the browser only ([Readers' own files](import.md#views-per-file)). |
| A reader's folder in the file store | `users/` and the first 24 hex characters of the SHA-256 (UTF-8) of the user name, trimmed and in lower case | `users/72774cafc3203b941d3eb047` for `CONTOSO\Alex` | The user name is not on disk and cannot leave the folder. Lower case: `CONTOSO\Alex` and `contoso\alex` share one folder, as Windows sign-ins do. |
| A view's file name | The name in lower case, accents dropped, every run of other characters a `-`, at most 60 characters (`view` when nothing is left); `-`; 10 hex characters of the SHA-256 of the source id and the name as it is, joined with a NUL character; `.pivotkit.json` | `umsatz-je-region-u-4a0d68db25.pivotkit.json` for `Umsatz je Region (Ü)` and source id `tickets` | Readable in a folder; the hash keeps apart names with the same slug, the same name in another case (two views in pivotkit) and the views of two reports. |
| … when that file name is taken | The source id, the name and the attempt (1, 2, …) joined with NUL, hashed the same way | `umsatz-je-region-u-b29f59675e.pivotkit.json` | A file stored by hand under that name is never overwritten. |
| … of version 0.1.0 | The hash of the source id, a vertical bar and the name in lower case | `umsatz-je-region-u-a56ef71be3.pivotkit.json` | Still found and replaced by a save of the name; a file name of this version never equals one of 0.1.0 (NUL against a vertical bar). |
| … on a save over a stored view | The view keeps its file | | A save replaces the view in place, whatever file name it has. |
| The tab's view in the address bar | `#pivot-<report key>=` and the view as base64url JSON; several reports joined with `&` | `#pivot-tickets=eyJyb3dzIjpbIlRlYW0iXX0` | A reload and a copied link open the same view ([Views](views.md)); left out with `-NoAddressBar`. |
| The tab's view in sessionStorage | One item `psu-pivot-views`, an entry per page path and report key (`<path>#<report key>`), at most 20 | `/tickets#tickets` | Survives PSU's light/dark switch and a view too long for the address bar. |
| My views in the browser (`-TemplateStore Browser`) | pivotkit's `localStorage` item `pivotkit:views:<report key>` ([pivotkit: `templateStore`](https://pivotkit.eize.dev/reference/react/#prop-templatestore)) | `pivotkit:views:tickets` | Views of the app's data and of every file loaded into this report, each naming its source id. |
| Dismissed tips | pivotkit's `localStorage` item `pivotkit:tips:<report key>` ([pivotkit: `storageKey`](https://pivotkit.eize.dev/reference/react/#prop-storagekey)) | `pivotkit:tips:tickets` | A tip a reader closed stays closed in this browser. |

To find a reader's folder in the file store, for example to remove their views:

```powershell
$userName = 'CONTOSO\Alex'
$bytes = [System.Text.Encoding]::UTF8.GetBytes($userName.Trim().ToLowerInvariant())
$folder = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).Substring(0, 24).ToLowerInvariant()
Join-Path $store.Path 'users' $folder   # $store = New-UDPivotFileTemplateStore
```

The demo's former server upload built a file's source id by the same formula, from the file name
trimmed and the column names as `ConvertFrom-Csv` or `ConvertFrom-Json` gave them. pivotkit cleans
both first (control and direction characters out, line breaks to spaces, trimmed, a file name cut
at 256 characters, empty or repeated column names renamed), so the ids match for ordinary files; a
file whose name or column names needed such cleaning gets another id, and its views saved then are
not offered again.
