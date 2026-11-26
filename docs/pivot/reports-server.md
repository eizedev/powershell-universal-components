---
title: Reports from a pivotkit-server
description: "Invoke-UDPivotReport -Engine Rest: render a view on a pivotkit-server, list its sources with Get-UDPivotSource, and return a report as a link that expires (-AsLink)."
---

# Reports from a pivotkit-server

`Invoke-UDPivotReport -Engine Rest` sends the view and the rows to a pivotkit-server, or names one of
its sources. The basics, the formats and the Node engine: [Reports without a browser](reports.md).
To run the pivotkit-server on the Windows server next to PSU, with its token in a PSU secret, follow
pivotkit's [Services next to PowerShell Universal](https://pivotkit.eize.dev/getting-started/powershell-universal/).

## REST: a pivotkit-server

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
later; `-Locale`, `-Numbers` and `-FlatHeader` ([Reports without a browser](reports.md#two-engines)) 0.3.0 or later.

The token comes from the server's operator, who makes it with `pivotkit-server token new`; keep it in
a PSU secret. pivotkit-server refuses a static token that is easy to guess
([pivotkit's rule](https://pivotkit.eize.dev/security/#rest)).

With `-Source` instead of `-Data` the report runs over a source the operator configured, with
`-Parameter` for its parameters; that needs a caller whose policy has `results: true`:

```powershell
Invoke-UDPivotReport -Engine Rest -Uri 'https://reports.example.com/api/v1' -Token $Secret:PivotkitToken `
    -Source 'vms' -Parameter @{ customer = 'acme' } -View $view -OutFile ./vms.xlsx
```

## Which sources the server has

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
| `Records` | Whether the caller may read the source's rows ([rows from a server](server-rows.md)) |
| `LinkParams` | The parameters a link may carry in the page's query string |
| `Views` | The views the operator publishes for the source: `name`, `title`, `description` |
| `Rows`, `DataAsOf` | The row count and the data's date, where the server read the data and shows them to the caller |
| `RequestId` | The id of the answer, for the operator |

`Records`, `LinkParams`, `Views`, `Rows` and `DataAsOf` need pivotkit-server 0.4.0 or later.

When the server lists no source, the function returns nothing and writes the server's reason to
the warning stream: the sign-in lacks the sources' scopes.

## A report as a link

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
- An error has a fixed error id ([Errors](errors.md#errors)). Its message says:
    - the server's code and detail, and the findings of a view with errors (422);
    - when to try again (`Retry-After` of a 429 or 503), or that trying again may work (`retryable`);
    - the request id the operator finds the log lines by.
- A 413 says what to do by its code. For a request over the server's cap, send less data or use
  `-Source`. This holds also when the server answers while the request is still being sent. For a
  report over a limit of the server, make the view smaller or filter it.
- Data over `-MaxBytes` is refused before it is sent ([Size and memory](reports.md#size-and-memory)).
- The token and the client secret never appear in an error, `$Error`, the verbose or the debug stream
  or the output, also with `-Verbose` and `-Debug`.
