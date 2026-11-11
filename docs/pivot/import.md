---
title: Readers' own files
description: "New-UDPivotReport -AllowImport: readers load a CSV, TSV, JSON or Excel file into the report, read in the browser and never uploaded; views per file, -OnDataLoad, how it works with -SourceId, -TemplateStore and the events."
---

# Readers' own files

`-AllowImport` lets readers pivot a file of their own next to the app's data: they drop it onto the
report or pick it under **Data**, **Load data…**, check a preview and load it. The file is read in
the browser; nothing is uploaded, the server never sees its rows, and after a reload the app's data
is back.

```powershell
# the app's data, and the reader's own file next to it
New-UDPivotReport -Id 'tickets' -Data $tickets -AllowImport

# no data of the app: the report asks for a file ("Load data to start")
New-UDPivotReport -Id 'own-data' -Data @() -AllowImport -TemplateStore Browser
```

| Format | Files |
| --- | --- |
| CSV, TSV, text | `.csv`, `.tsv`, `.txt`, `.tab`: commas, semicolons, tabs or vertical bars; German or English numbers and dates; the encoding from the byte order mark, else UTF-8 or Windows-1252 |
| JSON | `.json`: a list of records, or a table under a property |
| Excel workbook | `.xlsx`: one sheet at a time, picked in the preview; dates from the cell formats, the values Excel saved (never formulas). `.xls`, `.xlsb`, workbooks with macros and password-protected ones are refused with what to do. |

What readers see - the Data menu, the preview with a type per column, the notes, Undo and **Back to
original data** - is described on pivotkit's page
[Load your own data](https://pivotkit.eize.dev/use/load-data/); what the readers do with a
file on [Loading files](https://pivotkit.eize.dev/reference/import/). The pivot demo's page
"Your data" ([Showcase app](demo.md#your-own-data)) is a report with `-AllowImport` and no data of its
own.

!!! note "The file is not kept when the report is drawn anew"
    PSU's light/dark switch, a reload and a page that draws the report again (`Sync-UDElement` on a
    `New-UDDynamic` around it, such as the demo's language switch) show the app's data again: the
    loaded file lives in the report's own state, and the reader loads it again. Views saved for it are
    still offered.

## What stays in the browser

While a file's data is shown, the report keeps it away from the server and from what describes the
app's data:

| Part | While a file is shown |
| --- | --- |
| The view | Stays out of the address bar and the tab's `sessionStorage`; `Get-UDElement` and `-OnViewChange` keep the view of the app's data. **Back to original data** (or Undo back to it) shows that view again and reports it. |
| `-OnCellClick` | Does not run: its `$EventData` would carry rows of the file. The panel with the source rows still opens. |
| Saved views | Go to the browser's store, per file (below), never to `-TemplateStore` or `-OnSaveTemplate`. The app's shared views stay in the Views menu; a view for fields the file lacks says which parts it leaves out. |
| `-OnDataLoad` | Runs: it says that the data changed, never what is in it. |

## Views per file

pivotkit names a loaded file's data by its name and a hash of its name and column names in their
order (`tickets.csv#0123456789abcdef`). Views a reader saves while the file is shown carry that id and
are kept in the browser's store (`localStorage`, the store of `-TemplateStore Browser`, under the
report's `-Id`): the Views menu offers them when the same file is loaded again (same name, same
columns), not for another file and not for the app's data. A file with the same name and other or
reordered columns is other data.

| Setting | The app's data | A loaded file |
| --- | --- | --- |
| `-SourceId` (default `-Id`) | names the app's data in view files, links and the store | not used: the file's own id |
| `-TemplateStore Browser` | the reader's views of the app's data, in the browser | the reader's views of the file, in the browser |
| `-TemplateStore` with a store, `-OnSaveTemplate` | the reader's views on the server | in the browser instead: the server never has the file to apply them to |
| `-Templates`, `-TemplatePath`, shared views | offered | offered too: a shipped view fits a file with the same columns, such as a monthly export of the same table |

Views saved for a file stay in that browser only. The store holds at most 100 views and 500,000
characters per report, for the app's data and all files together.

## `-OnDataLoad` { #ondataload }

Runs on the server after the data shown changed. It only reports: pivotkit does not wait for the
server, so it cannot refuse a file.

| Key | What |
| --- | --- |
| `cause` | `load` (a file), `original` (the app's data again), `undo`, `redo` |
| `source` | `id`, `name` of the data shown: the file's, or the report's `-SourceId` and `-SourceName` |
| `file` | `name`, `size` (bytes), `type` of the file shown; `$null` for the app's data |
| `sheet` | the sheet of a workbook, else `$null` |
| `rows`, `columnCount` | the size of the data shown |
| `columns` | the first 200 columns: `name`, `type` (`string`, `number`, `date`, `boolean`) |
| `notes` | the codes of the readers' notes (`ENCODING`, `SEPARATOR`, `ROWS_EMPTY`, ...) |

```powershell
New-UDPivotReport -Id 'tickets' -Data $tickets -AllowImport -OnDataLoad {
    if ($EventData.file) {
        Write-Information ('{0} loaded {1}: {2} rows' -f $User, $EventData.file.name, $EventData.rows)
    }
}
```

No value of the file is sent. Its name, its sheet and its column names are, cut to 256 characters:
they come from the reader's file, so treat them as user input and show them as text. Leave
`-OnDataLoad` out where even the names of a reader's files must not reach the server.

## Large files and the import worker

CSV, TSV, text and JSON files are read in a Web Worker, so the page stays responsive: the module's
build makes pivotkit's worker a file of its own (`import-worker.<hash>.js`, about 26 KB), which PSU
serves next to the bundle. Where a worker cannot start - a Content-Security-Policy without
`worker-src 'self'`, a browser without workers - pivotkit reads the file on the page, with progress
and Cancel. Excel workbooks are always read on the page (the plugin is code of the page, never of the
worker); it starts no worker of its own and needs no `blob:`.

The readers check pivotkit's limits before the expensive steps: 100 MiB per file, 1,000,000 rows,
1,000 columns, 10,000,000 cells. While the preview is open the browser holds the file's table; a
CSV of 1,000,000 rows and 5 columns took about 650 MB more memory in pivotkit's own measurement
(Node, not a browser; approximate).

## Security

- The file is read by the reader's browser with pivotkit's readers; the server gets no byte of it.
  Values show as text, never as HTML, and the CSV export guards against formulas.
- Workbooks are refused before anything is parsed when they hold macros, are encrypted, would unpack
  to more than the limits allow (a ZIP bomb) or declare a document type or entities in their XML.
- The Excel reader (pivotkit-xlsx with read-excel-file and fflate) is part of the module's bundle and
  loads only when the first workbook is read. No code is loaded from elsewhere.
- `-OnDataLoad` sends file and column names (above); every other event keeps to the app's data.
