---
title: Reports without a browser
description: "Invoke-UDPivotReport - render a pivot view into an Excel workbook, an HTML report, CSV, JSON or SVG from an endpoint or a schedule, with pivotkit's command line or a pivotkit-server, signed in with a token or OAuth client credentials."
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
| HTML report | `html` | The chart above the table, light, for reading and printing |
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
| Needs | Node 22 or later and `npm install --global pivotkit-cli` (0.2.1 or later) on the PSU server | a pivotkit-server of pivotkit 0.7.0 or later, its address and a token or OAuth client |
| Data | `-Data`, written to a temporary folder of its own (mode 0700 on Linux and macOS; on Windows it inherits the ACL of the user's TEMP folder), removed afterwards | `-Data`, sent in the request; or `-Source`, a source the server's operator configured |
| Language, time zone | `-Locale`, `-TimeZone` | the server's |

Both take `-View` (a hashtable, JSON text or a view file) or `-Layout` (the view by field names), and
both check the view against the data first: a view with errors writes nothing, and the error lists
what pivotkit found (the field it did not find, the name it probably meant).

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
`chart` (auto, bar, line, area, pie, donut, heatmap) and `map` (`@{ Revenue = 'Turnover' }` for a
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

The columns are those of the first row. Every row's values are read by those names, so rows whose
properties come in another order (hashtables, objects merged from two sources) stay right; a column a
row lacks is empty there, and a property the first row does not have is left out, with one warning
that names it. Give every row the same properties (`Select-Object`) to keep them all.

### REST: a pivotkit-server

```powershell
$bytes = Invoke-UDPivotReport -Engine Rest -Uri 'https://reports.example.com/api/v1' -Token $Secret:PivotkitToken `
    -Data (Get-Ticket) -View $view -Format html
```

The rows go in the request as pivotkit's [data in the request](https://pivotkit.eize.dev/reference/rest/#data)
(source `inline:`): nothing has to be put on the server first, and the server keeps nothing of them.
The server's operator allows it per caller (a profile with `data: true`, or `policy.data`) and caps
the body (`rest.data.maxBytes`, default 10 MiB); the operator's exposure policy does not apply to
data you send. `-DataName` names the data, `-DataAsOf` says when it is from (sent as the data's
`asOf`; the server keeps it with the request, while the file's own "Data as of" is when the data
arrived).

With `-Source` instead of `-Data` the report runs over a source the operator configured, with
`-Parameter` for its parameters; that needs a caller whose policy has `results: true`:

```powershell
Invoke-UDPivotReport -Engine Rest -Uri 'https://reports.example.com/api/v1' -Token $Secret:PivotkitToken `
    -Source 'vms' -Parameter @{ customer = 'acme' } -View $view -OutFile ./vms.xlsx
```

What the function does on the way:

- Only `https://` addresses, or `http://` to this machine (`localhost`, `127.0.0.1`, `::1`), for the
  server and the token endpoint. An address with a user name or password in it is refused, and so is
  a `-Uri` with a query string or fragment (the routes are appended to its path); messages show an
  address as scheme, host, port and path only.
- No redirect is followed: a token goes only to the address you gave.
- An error says the server's code and detail, the findings of a view with errors (422), when to try
  again from `Retry-After` (429, 503) or that trying again may work (`retryable`), and the request id
  the operator finds the log lines by, and has a fixed error id ([Errors](#errors)). A 413 says what to
  do by its code: less data or `-Source` for a request over the server's cap, also when the server
  answers it while the request is still being sent; a smaller view or a filter for a report over a
  limit of the server. Data over `-MaxBytes` is refused before it is sent
  ([Size and memory](#size-and-memory)).
- The token and the client secret never appear in an error, `$Error`, the verbose or the debug stream
  or the output, also with `-Verbose` and `-Debug`.

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

Measured with 100,000 rows of 3 columns (text, number, date; a 4.3 MB request) against a stand-in
server on the same machine, PowerShell 7.6 on macOS, the compiled class already loaded (approximate:
your server differs):

| Data | All rows as objects, then one JSON text (earlier builds) | Written row by row |
| --- | --- | --- |
| DataTable | 3.2 s, about 800 MB more memory at the peak | 0.1 s, about 30 MB |
| PSCustomObjects | 5.0 s, about 1.3 GB more | 0.8 s, about 180 MB |

On the PSU test instance (PSU 2026.2.5 in a container), a build before this one took 16.8 seconds and
about 700 MB more for 100,000 rows of 3 columns in an endpoint, and 260,000 rows ended in an
OutOfMemoryException in a 2 GiB container, before the server's 413 could answer.

An endpoint or a script in PSU's **Integrated** environment runs inside the PSU server process: the
memory it takes is the server's, shared with every app and endpoint. Run large reports in a
PowerShell 7 environment of their own, and keep large data out of PSU altogether: let the
pivotkit-server operator configure a source for it (a file, a database export, an HTTP source) and
render with `-Source`. `-Data` is for what a script has at hand, a few megabytes.

## Errors

Every failure of the engines is an ErrorRecord with a fixed error id (`$_.FullyQualifiedErrorId`, or
`catch` and `Should -Throw -ErrorId` in a test). `$_.Exception.Data` holds what a script may act on:
`Status` (the HTTP status), `Code` (pivotkit-server's problem code, the OAuth error, the command
line's error code), `RetryAfter` (the `Retry-After` header of a 429 or 503: seconds, or an HTTP date),
`Retryable` (`$true` or `$false` where the server said whether the same request may work when tried
again, as for a source that is not available right now; the message then says "Trying again may
work."), `RequestId` (give it to the server's operator; from the answer's body, else its
`X-Request-Id` header) and `MaxBytes`.

| Error id | When |
| --- | --- |
| `PivotServerUnreachable` | pivotkit-server or the token endpoint did not answer (no connection, a time-out) |
| `PivotRedirectRefused` | the server or the token endpoint answered with a redirect, which is not followed |
| `PivotTokenRefused` | the server answered 401, or 403 `INSUFFICIENT_SCOPE` (the token lacks the REST scope: ask for it with `-Scope`), or the token endpoint refused the client credentials or gave no usable token |
| `PivotDataTooLarge` | `-Data` passed `-MaxBytes`, or the server answered 413: `BODY_TOO_LARGE` (the request is over the server's cap: send fewer rows or columns, or use `-Source`) or `LIMIT_EXCEEDED` (the report is over a limit of the server, rows, cells or memory: make the view smaller or filter) |
| `PivotViewHasErrors` | the view has errors: the server's 422 or the command line's findings (exit 1) |
| `PivotServerError` | any other answer of the server that is no report (400, 403, 404, 429, 500, 502, 503 and so on) |
| `PivotCliNotFound` | `pivotkit` (or `node` for a .js) was not found, or `-CliPath` is no file |
| `PivotCliFailed` | the command line did not start, took longer than `-TimeoutSec`, gave no `--json` answer or failed otherwise (exit 2) |

Wrong or missing parameters (an engine's parameter given to the other, `-Uri` without https) are
plain errors before anything runs.

```powershell
try { Invoke-UDPivotReport -Engine Rest -Uri $uri -Token $Secret:PivotkitToken -Data $rows -View $view -OutFile $file }
catch {
    switch ($_.FullyQualifiedErrorId) {
        'PivotServerError' { if ($_.Exception.Data['RetryAfter'] -or $_.Exception.Data['Retryable']) { <# try again later #> } }
        'PivotDataTooLarge' { <# fewer rows, or a source on the server #> }
        default { throw }
    }
}
```

## Sign-in

=== "Static token"

    A token the operator gave you (`auth.tokens` of the server), kept as a PSU secret:

    ```powershell
    Invoke-UDPivotReport -Engine Rest -Uri 'https://reports.example.com/api/v1' -Token $Secret:PivotkitToken -Data $rows -View $view
    ```

    `-Token` takes a string or a SecureString.

=== "OAuth client credentials"

    The client id and secret of an OAuth client, kept as a PSU secret of type PSCredential (user name:
    the client id, password: the client secret):

    ```powershell
    Invoke-UDPivotReport -Engine Rest -Uri 'https://reports.example.com/api/v1' -Credential $Secret:PivotkitClient `
        -TokenUri 'https://auth.example.com/application/o/token/' -Scope 'pivotkit:rest' -Data $rows -View $view
    ```

    The function asks the token endpoint for an access token (`grant_type=client_credentials`, the
    client id and secret in the body, or as HTTP Basic with `-ClientAuthentication Basic`; `-Scope`,
    `-Audience` and `-Resource` when given) and keeps it in the PowerShell runspace until a minute
    before it expires, per token endpoint, client id, secret (as its SHA-256), scopes and server: a
    changed secret is checked at the token endpoint, and a token never goes to another server. A 401
    from the server gets one new token and one more try. A token without `expires_in` is not kept.

### Authentik

On the pivotkit-server side, set up the provider as pivotkit's
[Sign-in with Authentik](https://pivotkit.eize.dev/getting-started/kubernetes/#oauth) says, with a
signing key and a scope of its own for REST (`rest.requiredScopes`, a scope mapping in Authentik), and
`rest.audience` set to the provider's client ID, since Authentik puts the client ID into the access
token's `aud`. For this function:

1. Set the provider's **Client Type** to **Confidential** and note its **Client ID** and **Client
   Secret**.
2. In PSU, create a secret of type PSCredential with the client ID as user name and the client secret
   as password, e.g. `PivotkitClient`.
3. Call the function with `-TokenUri 'https://<authentik>/application/o/token/'` and `-Scope` with
   the REST scope's name, e.g. `-Scope 'pivotkit:rest'`. Without it Authentik issues a token without
   that scope, and the server answers 403 `INSUFFICIENT_SCOPE` (`PivotTokenRefused`).

Authentik answers the client credentials grant with the provider's client ID and secret and creates a
service account for it (`ak-<provider>-client_credentials`): bind it, or a group it is in, to the
application if the application has bindings
([Authentik: client credentials](https://docs.goauthentik.io/add-secure-apps/providers/oauth2/client_credentials/)).
This sequence was run against Authentik 2026.8.5: the client ID and secret as a PSU secret of type
PSCredential, `-TokenUri` `/application/o/token/` and `-Scope` with the REST scope. Labels and
defaults can change between Authentik releases; decode an access token of your own to check its
`aud` and `scope`.

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
