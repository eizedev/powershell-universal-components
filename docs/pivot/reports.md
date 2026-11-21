---
title: Reports without a browser
description: "Invoke-UDPivotReport - render a pivot view into an Excel workbook, an HTML report, CSV, JSON or SVG from an endpoint or a schedule, with pivotkit's command line or a pivotkit-server, signed in with a token or OAuth client credentials; Get-UDPivotSource lists the server's sources, -AsLink returns a link that expires."
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
| Needs | Node and `npm install --global pivotkit-cli` (0.2.1 or later; tested with 0.4.0) on the PSU server: Node 22 or later, Node 24 or later for the command line released with pivotkit 0.9 | a pivotkit-server, its address and a token or OAuth client; for `-Data` and `-Parameter` pivotkit-server 0.2.0 or later ([which server](#rest-a-pivotkit-server)) |
| Data | `-Data`, written to a temporary folder of its own (mode 0700 on Linux and macOS; on Windows it inherits the ACL of the user's TEMP folder), removed afterwards | `-Data`, sent in the request; or `-Source`, a source the server's operator configured |
| Language, time zone | `-Locale`, `-TimeZone` | the server's |
| HTML print template | `-Template` | the server's source decides |
| Result | the file | the file, or a link that expires (`-AsLink`) |

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

`-Data` (and with it `-DataName` and `-DataAsOf`) and `-Parameter` need pivotkit-server 0.2.0 or
later. pivotkit-server 0.1.1 renders `-Source` without parameters. It answers `-Data` and `-Parameter`
with `INVALID_INPUT (400)`, and the error then names the version they need.

The token comes from the server's operator, who makes it with `pivotkit-server token new`; keep it in
a PSU secret. pivotkit-server 0.2.0 does not start with a static token that is easy to guess
([pivotkit's rule](https://pivotkit.eize.dev/getting-started/upgrading/#weak-tokens)).

With `-Source` instead of `-Data` the report runs over a source the operator configured, with
`-Parameter` for its parameters; that needs a caller whose policy has `results: true`:

```powershell
Invoke-UDPivotReport -Engine Rest -Uri 'https://reports.example.com/api/v1' -Token $Secret:PivotkitToken `
    -Source 'vms' -Parameter @{ customer = 'acme' } -View $view -OutFile ./vms.xlsx
```

### Which sources the server has

`Get-UDPivotSource` lists the sources the signed-in caller may use (`GET /sources`). It takes the same
sign-in parameters as `Invoke-UDPivotReport -Engine Rest`: `-Uri`, and `-Token` or `-Credential` with
`-TokenUri`, `-Scope`, `-Audience`, `-Resource` and `-ClientAuthentication`.

```powershell
$sources = Get-UDPivotSource -Uri 'https://reports.example.com/api/v1' -Token $Secret:PivotkitToken
New-UDSelect -Id 'source' -Option { foreach ($s in $sources) { New-UDSelectOption -Name $s.Title -Value $s.Id } }
```

Each source is an object with these properties:

| Property | What it is |
| --- | --- |
| `Id` | The source's id, for `-Source` |
| `Title`, `Description` | The source's name and description |
| `Kind` | `source`, or `file` for a file the server reads |
| `Link` | Whether pivotkit's share links of views work for it. This is not the download link of `-AsLink` |
| `Schedulable` | Whether the server drafts schedules for it |
| `Parameters` | The values the source takes, as the server describes them (`name`, `type`, `required`, `description`, `example`) |
| `DataMaxBytes` | The largest request this caller may send with `-Data`. Empty when it may send none. The same on every source |
| `Records` | Whether the caller may read the source's rows: [rows from a server](#server-rows) |
| `LinkParams` | The parameters a link may carry in the page's query string |
| `Views` | The views the operator publishes for the source: `name`, `title`, `description` |
| `Rows`, `DataAsOf` | The row count and the data's date, where the server read the data and shows them to the caller |
| `RequestId` | The id of the answer, for the operator |

A server older than pivotkit-server 0.4 leaves `Records`, `LinkParams`, `Views`, `Rows` and `DataAsOf`
empty. When the server lists no source, the function returns nothing and writes the server's reason to
the warning stream: the sign-in lacks the sources' scopes.

### A report as a link

With `-AsLink` the server keeps the report and the function returns a link to it that expires
(`POST /views/render` with `save: true`). A page or a mail then hands out the link instead of the file:

```powershell
$link = Invoke-UDPivotReport -Engine Rest -Uri 'https://reports.example.com/api/v1' -Token $Secret:PivotkitToken `
    -Source 'sales' -View $view -AsLink
$until = if ($link.ExpiresAt) { ', until {0:t}' -f $link.ExpiresAt.ToLocalTime() }
New-UDLink -Text "Sales report$until" -Url $link.Url
```

| Property | What it is |
| --- | --- |
| `Url` | The download link |
| `ExpiresAt` | When the link stops working, a `DateTimeOffset` in UTC. Empty where the server names no expiry, as for some links of an operator's own store |
| `Rows` | The rows of the report's table, without the header. Empty where the server withholds it |
| `RequestId` | The id of the answer, for the operator |
| `Format` | xlsx, html, csv, json or svg |
| `FileName` | The file's name for the person who opens it |
| `Bound` | `none` (anyone with the link), `once` (one download) or `signIn` (only the person who asked). Empty for a link of an operator's own store |
| `DataAsOf` | When the data is from |
| `Message` | The server's sentence for the person who asked |

The server decides which report gets a link ([download links](https://pivotkit.eize.dev/reference/delivery/)).
A report over an open source gets one where the operator turned on download links and the server can
sign them. A report over a closed source, or over data sent with `-Data`, gets one only where the
operator binds links to a sign-in or to one download. A server without an output directory saves no
report at all. In each of these cases the function stops with `PivotNoLink`, and the message says so
in plain words, with the server's own reason. `-AsLink` does not go with `-OutFile`.

The link, `FileName` and `Message` are the server's text. The function returns only an `http` or
`https` link. Show the other two as text, never as markup.

What the function does on the way:

- Only `https://` addresses, or `http://` to this machine (`localhost`, `127.0.0.1`, `::1`), for the
  server and the token endpoint. An address with a user name or password in it is refused, and so is
  a `-Uri` with a query string or fragment (the routes are appended to its path); messages show an
  address as scheme, host, port and path only.
- No redirect is followed: a token goes only to the address you gave.
- `-TimeoutSec` (default 120) limits each call as a whole: sending the request and reading the
  report in full; the token request has a limit of the same length of its own.
- An error has a fixed error id ([Errors](#errors)). Its message says:
    - the server's code and detail, and the findings of a view with errors (422);
    - when to try again (`Retry-After` of a 429 or 503), or that trying again may work (`retryable`);
    - the request id the operator finds the log lines by.
- A 413 says what to do by its code. For a request over the server's cap, send less data or use
  `-Source`. This holds also when the server answers while the request is still being sent. For a
  report over a limit of the server, make the view smaller or filter it.
- Data over `-MaxBytes` is refused before it is sent ([Size and memory](#size-and-memory)).
- The token and the client secret never appear in an error, `$Error`, the verbose or the debug stream
  or the output, also with `-Verbose` and `-Debug`.

## Rows from a server for the signed-in person { #server-rows }

Some data only a pivotkit-server can reach, for the person who opens the page: an HTTP source with a
token exchange, a file on the server. `New-UDPivotReport -Uri -Source -Token` shows such a source as
a live report. A link from pivotkit's `create_link` opens on it too.

```powershell
New-UDPage -Name 'Orders' -Url '/orders' -Content {
    New-UDPivotReport -Id 'orders' -Uri 'https://reports.example.com/api/v1' -Source 'orders' -Token $AccessToken
}
```

How it works:

1. PowerShell asks the server's rows route, `POST /sources/records`, with the person's token.
2. The server answers with the rows the person may see, as JSON text in pivotkit's columnar shape.
3. The module hands that text to the report as it is. It never turns the rows into PowerShell objects.
4. The report parses the text in the browser and works as with `-Data`.

The browser makes no request to the server. There is no CORS, and the token never reaches the
browser.

### What it needs

On PSU:

- PSU's OpenID Connect sign-in with `Authentication__OIDC__SaveTokens=true`. PSU then gives the page
  the person's access token as `$AccessToken`.
- `$AccessToken` exists on app pages and in `New-UDDynamic`. It does not exist in API endpoints, so
  this mode is for pages.
- There is no refresh token. When the token has expired, the report asks the person to sign in again.

On pivotkit-server (its [rows route](https://pivotkit.eize.dev/reference/rest/#records-host)):

- The server accepts the token as an OAuth token of its issuer. `rest.audience` lists the audience of
  PSU's tokens, and the token carries the scopes of `rest.requiredScopes` and of the source.
- A profile of the person names the source in `records`. Only fields at `show` for the person leave
  the server.
- A token PSU signs for the person ([tokens from another
  system](https://pivotkit.eize.dev/reference/rest/#external-issuers)) works too. It cannot read a
  source with a token exchange.
- A static token and OAuth client credentials get no rows: the server hands rows only to a person.

`Get-UDPivotSource` shows `Records` as `$true` for each source the caller may read the rows of.

### Links with parameters

A link from `create_link` names the source's parameters in the page's query string, such as
`/orders?customer=acme#pivot-orders=1.<view>`. The view stays in the fragment, and the report reads
it in the browser as before ([links from pivotkit](views.md#links-from-pivotkit-create_link)).

- The module reads `$Query` of the page and passes on only the names the server lists as the
  source's `linkParams` in `GET /sources`. Other names in the query string stay out.
- Pass `-Query $Query` where the call runs in a script block or function defined in the app script.
- `-Parameter` replaces the query string: `-Parameter @{ customer = $Query.customer }` narrows what a
  link may set. Its values go to the server as they are.
- The server checks every value again with the rights of the person who opens the page.
- The report writes its view into the fragment and keeps the query string. A link a person copies from
  the address bar still names the customer.
- Values in a query string land in access logs, the browser history and the `Referer` header. List
  only parameters whose values may show up there, and send a strict `Referrer-Policy`
  ([pivotkit's security notes](https://pivotkit.eize.dev/security/#link-params)).

A view the server publishes for the source goes by its name: `-View 'by-region'`. Then only the fields
it uses leave the server. The server lists its views' names, not the views, so the report starts with
the view of the link, else empty.

### When the server gives no rows

The report shows a message instead, in its language. The message for the operator, with the error id,
the server's address and its answer, goes to the warning stream, the app's log. It is no error on
purpose: PSU shows an error of a page to the reader as a toast. With `-ErrorAction` or
`-ErrorVariable` the error goes to the error stream, and `-ErrorAction Stop` throws it, for a page that
handles it itself.

| Server answer | Error id | The reader reads |
| --- | --- | --- |
| 401 | `PivotTokenRefused` | Sign in again |
| 403 `NOT_ALLOWED` | `PivotRowsNotAllowed` | Not available for you, with the fields from `notShown` |
| 400 `INVALID_INPUT` | `PivotServerError` | The link does not fit: a value or a view name is wrong |
| 404 `SOURCE_NOT_FOUND`, `DATA_NOT_AVAILABLE` | `PivotNoData` | No data |
| 413 `LIMIT_EXCEEDED`, or more than `-MaxBytes` | `PivotDataTooLarge` | The server's own message, which names the limit |
| 429 `RATE_LIMITED`, 503 `BUSY` | `PivotServerBusy` | The service is busy, try again in the seconds of `Retry-After` |
| 503 `SOURCE_UNAVAILABLE`, any other 5xx, an answer cut off | `PivotServerError` | Try again later |
| no answer | `PivotServerUnreachable` | The service does not answer |

- `$_.TargetObject` is the server's answer as a `PivotServerProblem` ([errors](#errors)). `NotShown`
  lists the fields of a `NOT_ALLOWED` answer.
- A reader never sees the server's address, the token or a stack trace. The message ends with the
  request id, for the operator.
- A link's view that needs a field the server did not hand out says which field above the report,
  and that the operator decides. The report does not leave the field out silently.
- The server answers 403 `NOT_ALLOWED` for a source that does not exist too, so a person cannot tell
  which sources there are.

### What stays on the PSU server

- The token: only in the request to pivotkit-server. It is never in a prop, an error or a log line.
- The rows, as text, while PSU renders the page: in the PowerShell process that runs the page and
  in PSU's server process on their way to the browser. Neither keeps them afterwards, but .NET returns
  little of that memory ([sizing](#sizing-of-server-rows)).
- `-MaxBytes` (default 32 MB) caps the answer. The module reads it in pieces and stops past the cap
  before it reads the rest.

### Sizing { #sizing-of-server-rows }

Three places hold the rows:

- **The browser.** It parses the text and keeps the rows encoded, as with `-Data`. pivotkit's
  [browser benchmark](https://pivotkit.eize.dev/concepts/limits/) measured about 10 MB for the data
  and 13 MB for the report at 100,000 rows of 9 columns.
- **The PowerShell process of the page.** In an app of PSU's **Integrated** environment, that is
  PSU's server process. In a **PowerShell 7** environment, it is a host process of its own.
- **PSU's server process.** It passes the text on to the browser.

Measured on two PSU test instances (2026.2.5 and 2026.3.4 in containers with a 2 GiB limit), an app in
a PowerShell 7 environment, a pivotkit-server on the same host, 20 columns, three page loads each.
The numbers are the growth of each process's memory (RSS) at the peak, sampled every 0.25 seconds:

| Rows | Answer | Page process | PSU server process | Page load |
| --- | --- | --- | --- | --- |
| 10,000 | 1.6 MiB | +5 to +22 MB | +0 to +15 MB | 0.5 to 1.5 s |
| 50,000 (the server's default limit) | 8.2 MiB | +145 to +162 MB | +53 to +105 MB | 0.9 to 3 s |
| 100,000 | 16.3 MiB | +161 to +284 MB | +12 to +87 MB | 1.4 to 4.6 s |
| 10,000 as `-Data` (`Import-Csv` objects) | - | +73 to +116 MB | +1 to +35 MB | 2.9 to 4.5 s |
| 50,000 as `-Data` (`Import-Csv` objects) | - | +467 to +509 MB | +0 to +4 MB | 14.5 to 17.8 s |

- These are numbers of two test instances with other apps running, not a benchmark. .NET's garbage
  collector frees at its own time, so a single load can show more or less. Measure with your data.
- The largest text the module passed through PSU to the browser was 64 MiB, on both instances. A
  string of 128 MiB crashed the browser tab, not PSU.
- PSU keeps much of the memory a process took, as the process grows. Several people opening large
  reports at once add up.

Set a memory limit per PSU process, so an overflow ends as an error in one request instead of the
system killing the whole container:

- `DOTNET_GCHeapHardLimit` caps the managed heap of a .NET process. Its value is a number of bytes in
  hexadecimal, such as `0x40000000` for 1 GiB
  ([.NET garbage collector settings](https://learn.microsoft.com/dotnet/core/runtime-config/garbage-collector)).
- Set it in the environment of PSU's container or service. The host processes PSU starts for its
  environments inherit it (checked on PSU 2026.2.5): each process gets the same cap.
- Choose it so that the server process and the host processes you expect fit together into the
  container's limit.

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

Every failure of `Invoke-UDPivotReport` and `Get-UDPivotSource` is an ErrorRecord with a fixed error
id (`$_.FullyQualifiedErrorId`, or `catch` and `Should -Throw -ErrorId` in a test).

For an answer of pivotkit-server, `$_.TargetObject` is the server's
[problem document](https://pivotkit.eize.dev/reference/rest/) as a `PivotServerProblem`. It has these
properties:

- `Status`: the HTTP status.
- `Code`: the server's stable code, such as `INVALID_TOKEN`, `INSUFFICIENT_SCOPE`, `NOT_ALLOWED` or
  `SOURCE_NOT_FOUND`.
- `Title`, `Detail`: the problem's title, and what went wrong and what to do.
- `RequestId`: the id the operator finds the log lines by.
- `Retryable`, `RetryAfter`: whether trying again may work, and when.
- `Type`, `Findings`: the address that names the code, and the findings of a view with errors.

A field the answer lacks is empty. An error that is no answer of the server (no connection, a missing
command line) has no `TargetObject`. A page uses the code to tell the reader why a report failed:

```powershell
try { $link = Invoke-UDPivotReport -Engine Rest -Uri $uri -Token $Secret:PivotkitToken -Source 'sales' -View $view -AsLink }
catch {
    $problem = $_.TargetObject
    # [string]: a switch over $null runs no branch, not even default
    $why = switch ([string]$problem.Code) {
        'INVALID_TOKEN' { 'The report service did not accept the sign-in.' }
        'INSUFFICIENT_SCOPE' { 'The sign-in lacks the scope for reports.' }
        'NOT_ALLOWED' { 'Your role may not use this report.' }
        default { 'The report failed. Request id: {0}' -f $problem.RequestId }
    }
    Show-UDToast -Message $why
}
```

`$_.Exception.Data` holds the same for a script, where the answer had it:

- `Status`: the HTTP status.
- `Code`: pivotkit-server's problem code, the OAuth error or the command line's error code.
- `Title`, `Detail`: the problem's title and detail.
- `RetryAfter`: the `Retry-After` header of a 429 or 503, in seconds or as an HTTP date.
- `Retryable`: `$true` or `$false` where the server said whether the same request may work when
  tried again, as for a source that is not available right now. The message then says "Trying again
  may work."
- `RequestId`: give it to the server's operator. It comes from the answer's body, else from its
  `X-Request-Id` header.
- `MaxBytes`: the cap `-Data` went over.

| Error id | When |
| --- | --- |
| `PivotServerUnreachable` | pivotkit-server or the token endpoint did not answer (no connection, a time-out) |
| `PivotRedirectRefused` | the server or the token endpoint answered with a redirect, which is not followed |
| `PivotTokenRefused` | the server answered 401, or 403 `INSUFFICIENT_SCOPE` (the token lacks the REST scope: ask for it with `-Scope`), or the token endpoint refused the client credentials or gave no usable token |
| `PivotDataTooLarge` | `-Data` passed `-MaxBytes`, or the server answered 413: `BODY_TOO_LARGE` (the request is over the server's cap: send fewer rows or columns, or use `-Source`) or `LIMIT_EXCEEDED` (the report is over a limit of the server, rows, cells or memory: make the view smaller or filter) |
| `PivotViewHasErrors` | the view has errors: the server's 422 (with `-AsLink` its 200 with `ok: false`) or the command line's findings (exit 1) |
| `PivotNoLink` | `-AsLink`: the server saved the report without a download link, or it has no output directory (409 `NO_OUTPUT`) |
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

    pivotkit-server 0.3.0 and later also accept short-lived tokens that another system signs
    ([tokens from another system](https://pivotkit.eize.dev/reference/rest/#external-issuers),
    `auth.externalIssuers`). `-Token` sends such a token as it sends a static one.

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
