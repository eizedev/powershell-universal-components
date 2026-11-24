---
title: How ids and names are built
description: "The ids and names New-UDPivotReport and its template stores build: the report key, source ids, a reader's folder, view file names, and the keys in the address bar and the browser."
---

# How ids and names are built { #ids }

The ids and names the report and the stores build, where they appear and why. Every rule is the
module's or pivotkit's code. Set `-Id` when readers save views: without it the key and `-SourceId`
follow the call's line in the app script, and a line added above the call hides the saved views.

| What | Rule | Example | Why |
| --- | --- | --- | --- |
| The report's key in the browser | `-Id`; without `-Id`: `auto-` and 16 hex characters of the SHA-256 of the call site in the app script (script, line, column) and the column names | `tickets`, `auto-3f9c0a1b2c4d5e6f` | The same key on every build of the page, so a reader's view comes back after a reload; no server path reaches the browser. |
| Source id of the app's data | `-SourceId`; default: the report's key above | `tickets` | Written into view files (`source.id`) and links; pivotkit asks before it loads a view made for another id; the Views menu offers the views of a store made for this id and those that name no data. Set it per data source when the data changes under the same `-Id` ([View files](templates.md#view-files)). |
| Source id of a file loaded with `-AllowImport` | pivotkit's rule: the file's name and a short hash of its name and column names ([pivotkit: How a loaded file is named](https://pivotkit.eize.dev/reference/import/#how-a-loaded-file-is-named)) | `tickets.csv#e51bd4bc21e98ee8` | The same file loaded again finds its views; a file with other or reordered columns is other data. Kept in the browser only ([Readers' own files](import.md#views-per-file)). |
| A reader's folder in the file store | `users/` and the first 24 hex characters of the SHA-256 (UTF-8) of the user name, trimmed and in lower case | `users/72774cafc3203b941d3eb047` for `CONTOSO\Alex` | The user name is not on disk and cannot leave the folder. Lower case: `CONTOSO\Alex` and `contoso\alex` share one folder, as Windows sign-ins do. |
| A view's file name | The name in lower case, accents dropped, every run of other characters a `-`, at most 60 characters (`view` when nothing is left); `-`; 10 hex characters of the SHA-256 of the source id and the name as it is, joined with a NUL character; `.pivotkit.json` | `umsatz-je-region-u-4a0d68db25.pivotkit.json` for `Umsatz je Region (Ü)` and source id `tickets` | Readable in a folder; the hash keeps apart names with the same slug, the same name in another case (two views in pivotkit) and the views of two reports. |
| … when that file name is taken | The source id, the name and the attempt (1, 2, …) joined with NUL, hashed the same way | `umsatz-je-region-u-b29f59675e.pivotkit.json` | A file stored by hand under that name is never overwritten. |
| … in the form with a vertical bar | The hash of the source id, a vertical bar and the name in lower case | `umsatz-je-region-u-a56ef71be3.pivotkit.json` | Found, and replaced by a save of the name. It never equals a file name of the form above (NUL against a vertical bar). |
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
