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
- An error says the server's code and detail, the findings of a view with errors (422), the seconds to
  wait from `Retry-After` (429, 503) and the request id the operator finds the log lines by. The
  exception's `Data` holds `Status`, `Code` and `RetryAfter` for a script that wants to try again. A
  413 says the data is too large for the server; a request over 10 MiB (the server's default cap)
  gets a warning first.
- The token and the client secret never appear in an error, `$Error`, the verbose or the debug stream
  or the output, also with `-Verbose` and `-Debug`.

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
        -TokenUri 'https://auth.example.com/application/o/token/' -Scope 'pivotkit-rest' -Data $rows -View $view
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
   the REST scope's name.

Authentik answers the client credentials grant with the provider's client ID and secret and creates a
service account for it (`ak-<provider>-client_credentials`): bind it, or a group it is in, to the
application if the application has bindings
([Authentik: client credentials](https://docs.goauthentik.io/add-secure-apps/providers/oauth2/client_credentials/)).
This sequence follows Authentik's documentation; it was not run against an Authentik instance.
Decode an access token of your own to check its `aud` and `scope`.

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
