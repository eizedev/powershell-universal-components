function ConvertTo-UDPivotServerProblem {
    <#
    .SYNOPSIS
        An answer of pivotkit-server that is no success, as a PivotServerProblem: the problem document's
        fields (RFC 9457) with the status, the request id and Retry-After.
    .DESCRIPTION
        The fields are those of the problem document where the server sent one: Type, Title, Status,
        Code, Detail, RequestId, Retryable, Findings, NotShown (the rows route's fields below show). A field the answer lacks is $null; nothing is made
        up. Status is the HTTP status of the answer. RequestId falls back to the X-Request-Id header (the
        listener's own 400, a proxy's answer). Detail falls back to the "error" text of a handler that
        crashed (pivotkit-server's 500). RetryAfter is the Retry-After header as the server sent it.
    .PARAMETER Response
        Invoke-UDPivotHttp's answer: StatusCode, Headers and Content.
    .PARAMETER Answer
        The answer's JSON, when it was read already (a 200 that is no success, such as a view with
        errors); else the content is read.
    .EXAMPLE
        ConvertTo-UDPivotServerProblem -Response $response
    .OUTPUTS
        System.Management.Automation.PSCustomObject (PivotServerProblem).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][pscustomobject]$Response, [AllowNull()][object]$Answer)
    $problem = $Answer
    if ($null -eq $problem) {
        try { $problem = ConvertFrom-Json -InputObject ([System.Text.Encoding]::UTF8.GetString($Response.Content)) -Depth 16 } catch { $problem = $null }
    }
    # a problem document (RFC 9457) is an object; anything else (an empty body, a proxy's page) has no members to read
    if ($problem -isnot [System.Management.Automation.PSCustomObject]) { $problem = $null }
    $text = { param($Name) if ($problem -and $problem.$Name -is [string] -and $problem.$Name) { $problem.$Name } }
    $detail = & $text 'detail'
    if (-not $detail) { $detail = & $text 'error' }
    # a 200 that is no success (a view with errors, a report without a link) says what happened in "message"
    if (-not $detail) { $detail = & $text 'message' }
    $requestId = & $text 'requestId'
    if (-not $requestId -and $Response.Headers['X-Request-Id']) { $requestId = [string]$Response.Headers['X-Request-Id'] }
    [pscustomobject]@{
        PSTypeName = 'PivotServerProblem'
        Status     = [int]$Response.StatusCode
        Code       = & $text 'code'
        Title      = & $text 'title'
        Detail     = $detail
        RequestId  = $requestId
        Retryable  = if ($problem -and $problem.retryable -is [bool]) { $problem.retryable }
        RetryAfter = if ($Response.Headers['Retry-After']) { [string]$Response.Headers['Retry-After'] }
        Type       = & $text 'type'
        Findings   = if ($problem -and $problem.findings) { @($problem.findings) } else { @() }
        NotShown   = if ($problem -and $problem.notShown) { [string[]]@($problem.notShown | Where-Object { $_ -is [string] }) } else { [string[]]@() }
    }
}
