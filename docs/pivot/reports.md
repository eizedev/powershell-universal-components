---
title: Reports without a browser
description: "Invoke-UDPivotReport - render a pivot view into an Excel workbook, an HTML report, CSV, JSON or SVG from an endpoint or a schedule, with pivotkit's command line or a pivotkit-server; size, memory and security notes."
---

# Reports without a browser

`Invoke-UDPivotReport` turns a view and rows into a file without a browser: for an endpoint that
answers with a report, a schedule that mails a workbook every Monday, a job that drops a CSV on a
share. The view is the one readers build in `New-UDPivotReport` (Views, Download view, or the `.view`
of `Get-UDElement`), so a report a reader set up on a page can run as a file.

```powershell
$view = Get-Content -LiteralPath (Join-Path $Repository 'views' 'tickets-per-team.pivotkit.json') -Raw
Invoke-UDPivotReport -Engine Node -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets') -View $view -OutFile '/reports/tickets.xlsx'
```

| Output | `-Format` | What it is |
| --- | --- | --- |
| Excel workbook | `xlsx` (default) | The table with number formats and merged headers |
| HTML report | `html` | The chart above the table, for reading and printing: light on paper, dark on a dark screen |
| CSV | `csv` | The table's layout, UTF-8 with a byte order mark |
| JSON | `json` | The result for a program |
| SVG | `svg` | The chart as an image |

`-Format` defaults to the extension of `-OutFile` (`.htm` is html), else `xlsx`. With `-OutFile` the
function writes the file (it replaces one that is there) and returns it; without it, it returns the
file's bytes, for an endpoint's answer or a mail attachment.

## Two engines

| | `-Engine Node` | `-Engine Rest` |
| --- | --- | --- |
| Runs | pivotkit's command line on the PSU server | a pivotkit-server somewhere else |
| Needs | Node 24 or later and `npm install --global pivotkit-cli` (0.2.1 or later) on the PSU server | a pivotkit-server, its address and a token or OAuth client ([which server](reports-server.md#rest-a-pivotkit-server)) |
| Data | `-Data`, written to a temporary folder of its own (mode 0700 on Linux and macOS; on Windows it inherits the ACL of the user's TEMP folder), removed afterwards | `-Data`, sent in the request; or `-Source`, a source the server's operator configured |
| Language, time zone | `-Locale`, `-TimeZone` | `-Locale`; the time zone is the server's |
| HTML print template | `-Template` | the server's source decides |
| Result | the file | the file, or a link that expires (`-AsLink`) |

Both take `-View` (a hashtable, JSON text or a view file) or `-Layout` (the view by field names), and
both check the view against the data first: a view with errors writes nothing, and the error lists
what pivotkit found (the field it did not find, the name it probably meant).

A CSV or JSON file holds every number with full precision. `-Numbers Shown` rounds each number to the
decimals the view shows; `-Numbers Full` is the default. `-FlatHeader` gives a CSV file one header
row instead of one per column field; each column names its labels joined with " / ". `-Locale` sets
the language and number format of a view that names none (a CSV in `de-DE` uses `;` and the decimal
comma). Both engines write the same file from them. `-Numbers` and `-FlatHeader` need pivotkit-cli
0.5.0 or later, and all three need pivotkit-server 0.3.0 or later; the function refuses `-Numbers` and
`-FlatHeader` for another format.

```powershell
Invoke-UDPivotReport -Engine Node -Data $tickets -View $view -OutFile ./tickets.csv -Numbers Shown -FlatHeader -Locale de-DE
```

```powershell
Invoke-UDPivotReport -Engine Node -Data $tickets -Format html -Title 'Lead time per month' -Layout @{
    rows   = 'Created'
    groups = @{ field = 'Created'; by = 'yearMonth' }
    values = @{ field = 'LeadHours'; agg = 'average' }
    chart  = 'line'
}
```

`-Layout` takes the keys of pivotkit's layout: `rows`, `cols` (field names), `values`
(`@{ field; agg }`), `groups` (`@{ field; by }`, `by` one of year, yearQuarter, yearMonth, yearWeek,
day, quarter, month, week, weekday, hour, or bin with `size`), `filters` (as a view writes them),
`chart` (auto, bar, line, area, pie, donut, heatmap, combo, treemap) and `map` (`@{ Revenue = 'Turnover' }` for a
column renamed since the view was made). pivotkit's
[view file reference](https://pivotkit.eize.dev/reference/view-file/) and
[command line](https://pivotkit.eize.dev/reference/cli/#layout-flags) have the details.

### Node: pivotkit's command line

```powershell
Invoke-UDPivotReport -Engine Node -Data $tickets -View $view -OutFile ./tickets.xlsx -Locale de-DE -TimeZone 'Europe/Berlin'
```

The function finds `pivotkit` on the PATH, or takes `-CliPath` (the program, or pivotkit-cli's
`bin/pivotkit.js`, which it runs with `node`). On Windows npm installs `pivotkit.cmd`; the function
runs the `bin/pivotkit.js` next to it with `node` instead, so no argument passes through `cmd.exe`.
Arguments go to the process one by one, never through a shell, each value as `--option=value`, so a
field name or a title may start with a dash. The command line reads and writes only inside the
temporary folder (`--allow-dir`), and warnings such as "the filters keep no row" go to the warning
stream. `-TimeoutSec` (default 120) stops a run that takes longer. A job that is killed before its
`finally` runs (PSU stopping the job, the server restarting) leaves the folder with the rows behind:
`pivotkit-<32 hex characters>` in the temporary folder of the account PSU runs as; remove such folders
now and then.

An HTML report takes a print template of your own with `-Template`, for your company's look and
metadata. It goes with `-Format html` only (or an `-OutFile` that ends in `.html`):

```powershell
Invoke-UDPivotReport -Engine Node -Data $tickets -View $view -Format html `
    -Template (Join-Path $Repository 'templates' 'corporate.template.html') -OutFile '/reports/tickets.html'
```

The function copies the template into the run's temporary folder and passes it as `--template`, since
the command line reads only there. pivotkit's [print template](https://pivotkit.eize.dev/reference/print-template/)
page lists the placeholders. `pivotkit example templates` writes two templates to start from. pivotkit
trusts a template like code: use a file of your own, never one a reader sent. With `-Engine Rest` the
server's source decides the template, so the function refuses `-Template` there.

The columns are those of the first row. Every row's values are read by those names, so rows whose
properties come in another order (hashtables, objects merged from two sources) stay right; a column a
row lacks is empty there, and a property the first row does not have is left out, with one warning
that names it. Give every row the same properties (`Select-Object`) to keep them all.

## Size and memory

The rows go into the request one by one: a DataTable (or DataView) straight from its rows, a list of
PSCustomObjects as it is, anything else (hashtables, DataRows, a mix) through the same conversion
`New-UDPivotReport` uses, which converts all of them before the first check. From 1,000 rows on, a
small compiled class writes them (compiled once per process, about 2 seconds; where `Add-Type` fails,
PowerShell writes them, more slowly, with the same result). Rows of a DataTable that are deleted but
not yet accepted are left out.

`-MaxBytes` (default 10 MiB, pivotkit-server's default `rest.data.maxBytes`) is checked first against
the number of rows times the columns (each cell takes at least two bytes), then every 256 rows while
they are written, and once at the end: past it the function stops with `PivotDataTooLarge`, after at
most 255 more rows were written into the request and before anything is sent. Raise it only to what
the operator set on the server (at most 64 MiB).

The module needs PowerShell's full language mode: it does not load in constrained language mode
(checked with PowerShell 7.6), and the JSON writer the engines use is a .NET type that mode blocks.

The rows are written row by row, so the request costs little memory beyond the data itself.
Measured with 100,000 rows of 3 columns (text, number, date; a 4.3 MB request) against a stand-in
server on the same machine, PowerShell 7.6 on macOS (approximate: your server differs): a DataTable
took 0.1 s and about 30 MB more memory, PSCustomObjects 0.8 s and about 180 MB.

An endpoint or a script in PSU's **Integrated** environment runs inside the PSU server process: the
memory it takes is the server's, shared with every app and endpoint. Run large reports in a
PowerShell 7 environment of their own, and keep large data out of PSU altogether: let the
pivotkit-server operator configure a source for it (a file, a database export, an HTTP source) and
render with `-Source`. `-Data` is for what a script has at hand, a few megabytes.

## Security notes

- The rows you send leave the PSU server: send only the columns the report needs (`Select-Object`, the
  SQL query), and only to a server you run or trust.
- A view, a layout and `-Title` come from your script. A view a reader saved (`$EventData`, a template
  store) is user input: it goes through the same checks as on a page (`ConvertFrom-UDPivotViewFile`),
  and pivotkit runs nothing from it.
- `-OutFile` is your path; the function never takes a file name from the server's answer. It replaces
  a file that is there and follows a symbolic link to its target: never build it from a reader's
  input, a request or `$EventData`.
- Rows are needed: `-Data` without rows throws, since there is nothing to check a view against. A
  schedule that may find no rows checks first (`if (@($rows).Count) { ... }`).
- The access token is kept per runspace in memory, as a SecureString; it is gone when the runspace
  ends. A new PSU runspace asks for a new one.

## More on reports

- [Reports from a pivotkit-server](reports-server.md): `-Engine Rest`, the server's sources and
  reports as links.
- [Sign-in to a pivotkit-server](server-sign-in.md): a token, or OAuth client credentials.
- [Errors](errors.md): the error ids of the report functions and of pivotkit-server's answers.
