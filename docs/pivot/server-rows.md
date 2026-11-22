---
title: Rows from a server
description: "New-UDPivotReport -Uri -Source -Token: a live report over a pivotkit-server source for the signed-in person, also from a create_link link with parameters. Setup on PSU and pivotkit-server, errors, what stays on the PSU server, memory and DOTNET_GCHeapHardLimit."
---

# Rows from a server for the signed-in person

Some data only a pivotkit-server can reach for the person who opens the page: an HTTP source with a
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
browser. pivotkit's [decision record 0015](https://pivotkit.eize.dev/decisions/0015-live-rows-for-a-host-page/)
explains the design.

## What it needs

### On PSU

- PSU's [OpenID Connect sign-in](https://docs.devolutions.net/powershell-universal/security/enterprise-security/openid-connect)
  with `Authentication__OIDC__SaveTokens=true`. PSU then gives the page the person's access token as
  `$AccessToken`.
- `$AccessToken` exists on app pages and in `New-UDDynamic`. It does not exist in API endpoints, so
  this mode is for pages.
- The module does not refresh the token. When it has expired, the report asks the person to sign in
  again. A page without a token (nobody signed in, `SaveTokens` off) asks the same and sends nothing.

### On pivotkit-server

You need pivotkit-server 0.4.0 or later: older servers have no rows route.
pivotkit's [rows route for a host backend](https://pivotkit.eize.dev/reference/rest/#records-host) has
the details. In short:

1. `auth.mode` is `oauth`, and `auth.issuer` is the issuer of PSU's sign-in.
2. `rest.audience` lists the audience of PSU's access tokens, beside the REST resource.
3. The token carries the scopes of `rest.requiredScopes` and of the source. The OIDC provider must put
   them into the access token PSU gets.
4. A profile names the source in `records`. Only fields at `show` for the person leave the server.
5. The profile is bound to people, for example with `auth.defaultProfile` or `auth.groupProfiles`.
6. For links with parameters, `sources.<id>.linkParams` lists them.

```json
{
  "rest": { "audience": ["https://reports.example.com/api/v1", "psu-app"], "requiredScopes": ["pivotkit"] },
  "sources": { "orders": { "linkParams": ["customer"], "link": "https://psu.example.com/reports/orders", "linkKey": "orders" } },
  "policy": { "profiles": { "staff": { "records": ["orders"], "default": "hide", "fields": { "order": "show", "region": "show" } } } },
  "auth": { "mode": "oauth", "issuer": "https://login.example.com", "resource": "https://reports.example.com/mcp", "defaultProfile": "staff" }
}
```

- A token PSU signs for the person also works ([tokens from another
  system](https://pivotkit.eize.dev/reference/rest/#external-issuers)). PSU has no command for that;
  you sign it in your own script. It cannot read a source with a token exchange.
- A static token and OAuth client credentials get no rows: the server hands rows only to a person.

The server's limits for this route decide how many people can open the report at once:

| Key | Default | What it means here |
| --- | --- | --- |
| `rest.records.concurrency` | 1 | One person at a time. A second person, or a second load of the same person, gets the "busy" message. Raise it together with `compute.workers`, and keep it below the workers |
| `rest.records.maxRows`, `rest.records.maxCells` | 50,000 rows, 1,000,000 values | Above them the reader gets the server's "too many rows" message |
| `rest.records.writeMs` | 10 seconds | The module reads the answer at once; a slow link to PSU counts here |

The default limits answer about 8 MiB for 20 columns. When you raise them, raise `-MaxBytes` on the
page as well (default 32 MB, at most 64 MB).

`Get-UDPivotSource` shows `Records` as `$true` for each source the caller may read the rows of.

## What leaves the server

- Every row of the source the person's profile shows leaves the server. A view's filters do not limit
  them, since filters are no permission.
- A link's parameters, such as a customer, limit the rows only where the source uses them, as an HTTP
  source puts them into its address.
- The rows reach the browser, and the browser is not access control. Show only fields the person may
  take home.

## Links with parameters

A link from `create_link` names the source's parameters in the page's query string, such as
`/orders?customer=acme#pivot-orders=1.<view>`. The view stays in the fragment, and the report reads
it in the browser as before ([links from pivotkit](views.md#links-from-pivotkit-create_link)).

- The module reads `$Query` of the page. It passes on only the names the server lists as the source's
  `linkParams` in `GET /sources`. Other names in the query string stay out.
- Pass `-Query $Query` where the call runs in a script block or function defined in the app script.
- `-Parameter` replaces the query string: `-Parameter @{ customer = $Query.customer }` narrows what a
  link may set. A value that is `$null` is left out. `-Params` is another name for it.
- The server checks every value again with the rights of the person who opens the page.
- The report writes its view into the fragment and keeps the query string. A link a person copies from
  the address bar still names the customer.
- Values in a query string land in access logs, the browser history and the `Referer` header. List
  only parameters whose values may show up there. Let the reverse proxy in front of PSU send a strict
  `Referrer-Policy` header, such as `same-origin`
  ([pivotkit's security notes](https://pivotkit.eize.dev/security/#link-params)).
- Give the report an `-Id`. Without it, the key the reader's view is kept under follows the server's
  columns, and a person with another profile gets another key.

A view the server publishes for the source goes by its name: `-View 'by-region'`. Then only the fields
it uses leave the server. The server lists its views' names, not the views, so the report starts with
the view of the link, else empty.

## When the server gives no rows

The report shows a message instead, in its language. The message for the operator, with the error id,
the server's address and its answer, goes to the warning stream, the app's log. It is no error on
purpose: PSU shows an error of a page to the reader as a toast. With `-ErrorAction` or
`-ErrorVariable` the error goes to the error stream as well, and `-ErrorAction Stop` throws it, for a
page that handles it itself. `-ErrorVariable` holds the error once (with `-ErrorAction Ignore`, nothing).

| Server answer | Error id | The reader reads |
| --- | --- | --- |
| no token on the page | `PivotTokenRefused` | Sign in again |
| 401 | `PivotTokenRefused` | Sign in again |
| 403 `INSUFFICIENT_SCOPE` | `PivotTokenRefused` | Not set up for your sign-in: tell the operator |
| 403 `NOT_ALLOWED` | `PivotRowsNotAllowed` | Not available for you, with the fields from `notShown` |
| 400 `INVALID_INPUT` | `PivotServerError` | The link does not fit: a value or a view name is wrong |
| 404 `SOURCE_NOT_FOUND`, `DATA_NOT_AVAILABLE` | `PivotNoData` | No data |
| 413 `LIMIT_EXCEEDED` | `PivotDataTooLarge` | The server's own message, which names the limit |
| more than `-MaxBytes` | `PivotDataTooLarge` | Too many rows to open here |
| 429 `RATE_LIMITED`, 503 `BUSY` | `PivotServerBusy` | The service is busy, try again in the seconds of `Retry-After` |
| 503 `SOURCE_UNAVAILABLE`, any other 5xx, a redirect, an answer cut off | `PivotServerError` | Try again later |
| no answer | `PivotServerUnreachable` | The service does not answer |

- `$_.TargetObject` is the server's answer as a `PivotServerProblem` ([errors](reports.md#errors)).
  `NotShown` lists the fields of a `NOT_ALLOWED` answer.
- A reader never sees the server's address, the token or a stack trace. The message ends with the
  request id, for the operator.
- A link's view that needs a field the server did not hand out says which field above the report,
  and that the operator decides. The report does not leave the field out silently.
- The server answers 403 `NOT_ALLOWED` for a source that does not exist too, so a person cannot tell
  which sources there are.

## What stays on the PSU server

- The token: only in the request to pivotkit-server. It is never in a prop, an error or a log line.
- The rows, as text, while PSU renders the page: in the PowerShell process that runs the page and in
  PSU's server process on their way to the browser. Nothing in the module keeps them. .NET returns
  little of that memory to the system, and PSU may keep the page's last props
  ([sizing](#sizing)).
- `-MaxBytes` (default 32 MB, at most 64 MB) caps the answer. The module reads it in pieces and stops
  past the cap before it reads the rest.

## Sizing

Three places hold the rows:

- **The browser.** It parses the text and keeps the rows encoded, as with `-Data`. pivotkit's
  [browser benchmark](https://pivotkit.eize.dev/concepts/limits/) measured about 10 MB for the data
  and 13 MB for the report at 100,000 rows of 9 columns.
- **The PowerShell process of the page.** In an app of PSU's **Integrated** environment, that is
  PSU's server process. In a **PowerShell 7** environment, it is a host process of its own.
- **PSU's server process.** It passes the text on to the browser.

Measured on two PSU test instances (2026.2.5 and 2026.3.4 in containers with a 2 GiB limit), an app in
a PowerShell 7 environment, a pivotkit-server on the same host, 20 columns, three page loads each.
The numbers are the growth of each process's memory (RSS) at the peak, sampled every 0.25 seconds.
Before the loads, PSU's server process held about 1.0 to 1.2 GB and the host process about 0.3 GB.

| Rows | Answer | Page process | PSU server process | Page load |
| --- | --- | --- | --- | --- |
| 10,000 | 1.6 MiB | +5 to +22 MB | +0 to +15 MB | 0.5 to 1.5 s |
| 50,000 (the server's default limit) | 8.2 MiB | +145 to +162 MB | +53 to +105 MB | 0.9 to 3 s |
| 100,000 | 16.3 MiB | +161 to +284 MB | +12 to +87 MB | 1.4 to 4.6 s |
| 10,000 as `-Data` (`Import-Csv` objects) | - | +73 to +116 MB | +1 to +35 MB | 2.9 to 4.5 s |
| 50,000 as `-Data` (`Import-Csv` objects) | - | +467 to +509 MB | +0 to +4 MB | 14.5 to 17.8 s |

- The rows of a server ran 10,000, 50,000 and 100,000 one after another in the same page process,
  and `-Data` in a new one: each row is the growth over the row before.
- These are numbers of two test instances with other apps running, not a benchmark. .NET's garbage
  collector frees at its own time, so a single load can show more or less. Measure with your data.
- The largest text the module passed through PSU to the browser was 64 MiB, on both instances. A
  string of 128 MiB crashed the browser tab, not PSU. That is why `-MaxBytes` stops at 64 MB.
- A worked guess for a container: PSU's server process at rest, plus the page processes, plus about
  200 to 270 MB per person who opens a report at the default row limit at the same time. That is the
  page process and PSU's server process together, in the row of 50,000 rows.

Set a memory limit per PSU process, so a load too large fails with an `OutOfMemoryException` in .NET
before the system kills the whole container:

- `DOTNET_GCHeapHardLimit` caps the managed heap of a .NET process. Its value is a number of bytes in
  hexadecimal, such as `0x60000000` for 1.5 GiB
  ([.NET garbage collector settings](https://learn.microsoft.com/dotnet/core/runtime-config/garbage-collector)).
  It caps the managed heap, not all of the process's memory.
- To choose the value, measure the busiest PSU process at its peak on a normal day (its RSS), add the
  reports you expect at once, and stay below the container's limit with room for memory outside the
  heap. On the test instances above, PSU's server process alone took 1.0 to 1.2 GB, so 1 GiB would
  have been too low.
- Set it in the environment of PSU's container or service. The host processes PSU starts for its
  environments inherit it (checked on PSU 2026.2.5): each process gets the same cap.
- An `OutOfMemoryException` in PSU's server process can still hit other requests running at the same
  time. Run large reports in a PowerShell 7 environment, so the page's own process takes the hit.

Next: [Reports without a browser](reports.md), [Events, security and limits](events.md),
[Reference](reference.md).
