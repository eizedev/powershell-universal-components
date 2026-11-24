---
title: Template stores
description: "Where New-UDPivotReport keeps readers' own views and shared views with -TemplateStore: in the browser, in files on the server, or on your own storage such as SQL Server, Valkey, or S3."
---

# Template stores: `-TemplateStore`

A template store keeps the views of the Views menu ([Templates, view files and roles](templates.md)):
readers' own views and the shared views admins publish. Who may publish: [Roles and your own code](roles.md).

## In the browser: `-TemplateStore Browser`

```powershell
New-UDPivotReport -Id 'tickets' -Data $tickets -TemplateStore Browser
```

pivotkit keeps each reader's views in the browser's localStorage (`pivotkit:views:<id>`): only in this
browser on this device, gone when the site's data is cleared, shared with nobody; the menu says so.
Each view names the `-SourceId` it was saved for, and the menu lists those of the report's
`-SourceId` (see [View files](templates.md#view-files) for data that changes per call).
At most 100 views and 500,000 characters. Nothing reaches the server, so nothing needs checking there.

## In files on the server: `New-UDPivotFileTemplateStore`

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
- **Writes**: a new file replaces the old one, under a lock per folder: no half file, no count over the limit.
- **Limits**: `-MaxUserViews` (default 50) and `-MaxSharedViews` (default 200); a save over the limit
  says "At most 50 own views; delete one first." Every stored file is checked again when it is read.
- **Errors of the server** (a folder it cannot write) go to the app's log; the reader reads a general text.
- **Several PSU nodes**: a local folder is per node. Use a folder all nodes share, or a database.

## On your own storage: `New-UDPivotTemplateStore`

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
module removes the other places a view of that name may be stored (a copy, or a file name in the form
with a vertical bar, see [How ids and names are built](ids.md)), and where it has to guess, the key may not exist. A delete that fails there is a warning in the
app's log, not an error for a save that worked.

The lock the module holds while it lists and writes is a named mutex on one machine. With several PSU
nodes, two saves of a new name on two nodes at the same moment can both add it: give the storage a
unique key on scope, user and `FileName` (the SQL Server example's primary key), so the second
replaces the first instead of adding a row.

Throw a text to refuse (`throw 'Not on weekends.'`); the reader sees it. An error of a .NET method
(a database that is down) goes to the app's log instead, and the reader reads a general text. Like the file store, a report lists only the views made
for its `-SourceId` and those that name no data, so one store serves several reports. The script blocks run in the runspace of the app script
that defined them, for every reader: they do not see `$User` or `$Roles` (use `$Request`), and PSU
runs the event handlers in runspaces of their own, so a script block imports the modules it uses
itself. What `-Get` returns is checked again, like a file.

The examples below are sketches with no dependency of this module; check them against your own
servers and the current documentation of the modules they use.

### SQL Server

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

### Valkey or Redis

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

### S3 (RustFS, MinIO, AWS)

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
