---
title: Errors
description: "The error ids of Invoke-UDPivotReport, Get-UDPivotSource and New-UDPivotReport -Uri, and how to read pivotkit-server's problem document in a script."
---

# Errors

Every failure of `Invoke-UDPivotReport` and `Get-UDPivotSource`, and every answer the server refuses
to `New-UDPivotReport -Uri` ([rows from a server](server-rows.md#when-the-server-gives-no-rows)), is an
ErrorRecord with a fixed error id (`$_.FullyQualifiedErrorId`, or `catch` and `Should -Throw -ErrorId` in a test).

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
- `NotShown`: the fields of a `NOT_ALLOWED` answer of the rows route.

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
| `PivotTokenRefused` | the server answered 401, or 403 `INSUFFICIENT_SCOPE` (the token lacks the REST scope: with client credentials ask for it with `-Scope`; for `New-UDPivotReport -Uri` see [rows from a server](server-rows.md#when-the-server-gives-no-rows)), or the token endpoint refused the client credentials or gave no usable token, or `New-UDPivotReport -Uri` got no token |
| `PivotDataTooLarge` | `-Data` passed `-MaxBytes`, or the server answered 413: `BODY_TOO_LARGE` (the request is over the server's cap: send fewer rows or columns, or use `-Source`) or `LIMIT_EXCEEDED` (the report is over a limit of the server, rows, cells or memory: make the view smaller or filter) |
| `PivotViewHasErrors` | the view has errors: the server's 422 (with `-AsLink` its 200 with `ok: false`) or the command line's findings (exit 1) |
| `PivotNoLink` | `-AsLink`: the server saved the report without a download link, or it has no output directory (409 `NO_OUTPUT`) |
| `PivotRowsNotAllowed` | `New-UDPivotReport -Uri`: the rows route answered 403 `NOT_ALLOWED` |
| `PivotNoData` | `New-UDPivotReport -Uri`: the rows route answered 404 `SOURCE_NOT_FOUND` or `DATA_NOT_AVAILABLE` |
| `PivotServerBusy` | `New-UDPivotReport -Uri`: the rows route answered 429 `RATE_LIMITED` or 503 `BUSY` |
| `PivotServerError` | any other answer of the server that is no report (400, 403, 404, 429, 500, 502, 503 and so on). The three ids above apply to the rows route only; on the other routes these answers stay `PivotServerError` |
| `PivotCliNotFound` | `pivotkit` (or `node` for a .js) was not found, or `-CliPath` is no file |
| `PivotCliFailed` | the command line did not start, took longer than `-TimeoutSec`, gave no `--json` answer or failed otherwise (exit 2) |

Wrong or missing parameters (an engine's parameter given to the other, `-Uri` without https) are
plain errors before anything runs.

`-ErrorVariable` holds the error record once, the same one `catch` gets. With `-ErrorVariable +name`
the entries you had before stay in front of it. These errors stop the call with every `-ErrorAction`,
also `SilentlyContinue`: handle them with `try` and `catch`.

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
