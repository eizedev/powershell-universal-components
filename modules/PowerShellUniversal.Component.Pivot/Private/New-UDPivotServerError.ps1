function New-UDPivotServerError {
    <#
    .SYNOPSIS
        The ErrorRecord for an answer of pivotkit-server that is no success: an error id by status and
        code, a message that says what to do, and the PivotServerProblem as TargetObject.
    .DESCRIPTION
        The message holds the code, the status, the detail, the findings, when to try again, a hint for
        the known cases (401, 403 INSUFFICIENT_SCOPE, 413 by its code, the 400 of a server too old for
        -Data, -Parameter, -Locale, -Numbers or -FlatHeader) and the request id. Exception.Data holds
        Status, Code, Title, Detail, RetryAfter, Retryable and RequestId. The error ids: PivotTokenRefused (401, 403
        INSUFFICIENT_SCOPE), PivotDataTooLarge (413), PivotViewHasErrors (422), PivotServerError
        (anything else). With -RowsRoute, by the rows route's codes: PivotRowsNotAllowed (403
        NOT_ALLOWED), PivotNoData (404 SOURCE_NOT_FOUND, DATA_NOT_AVAILABLE), PivotServerBusy (429
        RATE_LIMITED, 503 BUSY); 503 SOURCE_UNAVAILABLE and the rest stay PivotServerError.
    .PARAMETER Response
        Invoke-UDPivotHttp's answer.
    .PARAMETER Where
        The address called, as messages show it (Get-UDPivotSafeAddress).
    .PARAMETER RowsRoute
        The answer is one of POST /sources/records: its codes pick the error id.
    .EXAMPLE
        throw (New-UDPivotServerError -Response $response -Where 'https://reports.example.com/api/v1/sources')
    .OUTPUTS
        System.Management.Automation.ErrorRecord
    #>
    # Builds an errorrecord in memory; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param([Parameter(Mandatory)][pscustomobject]$Response, [Parameter(Mandatory)][string]$Where, [switch]$RowsRoute)
    $p = ConvertTo-UDPivotServerProblem -Response $Response
    $status = $p.Status
    $code = if ($p.Code) { $p.Code } else { 'HTTP {0}' -f $status }
    $message = 'pivotkit-server {0}: {1} ({2})' -f $Where, $code, $status
    if ($p.Detail) { $message += ': {0}' -f $p.Detail }
    $findings = @(Get-UDPivotFindingText -Finding $p.Findings)
    if ($findings.Count) { $message += [Environment]::NewLine + ($findings -join [Environment]::NewLine) }
    $retryText = Get-UDPivotRetryText -RetryAfter $p.RetryAfter
    if (-not $retryText -and $p.Retryable) { $retryText = 'Trying again may work.' }
    if ($retryText) { $message += [Environment]::NewLine + $retryText }
    if ($status -eq 401) { $message += [Environment]::NewLine + 'Check the token: the server did not accept it.' }
    if ($status -eq 413) {
        $message += [Environment]::NewLine + $(if ($code -eq 'LIMIT_EXCEEDED') { 'The report is over a limit of the server (rows, cells or memory): make the view smaller or filter the data.' }
            else { 'The data is too large for the server: send fewer rows or columns, or let the operator configure a source for it and use -Source.' })
    }
    # pivotkit-server 0.1.1 knows neither data in the request nor params; its answer reads like a
    # fault in the request (#129). 0.2.0 answers params the same way when none of its sources takes
    # any; later versions say that in words, recognised by "takes params" (NO_PARAMS_TEXT, #132):
    # that server is new enough, only its sources take no parameters.
    if ($status -eq 400 -and $code -eq 'INVALID_INPUT' -and $p.Detail -match 'no key "(data|params)"') {
        $message += [Environment]::NewLine + $(if ($Matches[1] -eq 'data') { '-Data needs pivotkit-server 0.2.0 or later; an older server renders only -Source.' }
            else { '-Parameter needs a source with parameters on pivotkit-server 0.2.0 or later.' })
    }
    elseif ($status -eq 400 -and $code -eq 'INVALID_INPUT' -and $p.Detail -match 'takes params') {
        $message += [Environment]::NewLine + 'No source on this server takes parameters: leave -Parameter out, or use a source that declares them (Get-UDPivotSource lists them).'
    }
    elseif ($status -eq 400 -and $code -eq 'INVALID_INPUT' -and $p.Detail -match 'no key "(locale|numbers|flatHeader)"') {
        $message += [Environment]::NewLine + '-Locale, -Numbers and -FlatHeader need pivotkit-server 0.3.0 or later.'
    }
    $scopeMissing = $status -eq 403 -and $code -eq 'INSUFFICIENT_SCOPE'
    if ($scopeMissing -and $RowsRoute) { $message += [Environment]::NewLine + 'The person''s token lacks a scope the server needs (rest.requiredScopes and the source''s scopes): let PSU''s OpenID Connect sign-in ask the provider for it, and make sure the provider puts it into the access token.' }
    elseif ($scopeMissing) { $message += [Environment]::NewLine + 'The token lacks a scope the server needs: ask the token endpoint for it with -Scope (the scope the operator set in rest.requiredScopes, for example pivotkit:rest), and make sure the OAuth provider grants it to this client.' }
    if ($RowsRoute -and $p.NotShown.Count) { $message += [Environment]::NewLine + ('Fields this person may not take from the server (not at "show" in their profile): {0}. The operator decides which fields leave the server.' -f ($p.NotShown -join ', ')) }
    if ($p.RequestId) { $message += [Environment]::NewLine + ('Request id for the operator: {0}' -f $p.RequestId) }
    $id = if ($scopeMissing) { 'PivotTokenRefused' } else { switch ($status) { 401 { 'PivotTokenRefused' } 413 { 'PivotDataTooLarge' } 422 { 'PivotViewHasErrors' } default { 'PivotServerError' } } }
    if ($RowsRoute -and -not $scopeMissing) {
        # the rows route's codes (pivotkit's rows route): the same status means different things
        $byCode = @{ NOT_ALLOWED = 'PivotRowsNotAllowed'; SOURCE_NOT_FOUND = 'PivotNoData'; DATA_NOT_AVAILABLE = 'PivotNoData'; RATE_LIMITED = 'PivotServerBusy'; BUSY = 'PivotServerBusy' }
        if ($p.Code -and $byCode.ContainsKey($p.Code)) { $id = $byCode[$p.Code] }
    }
    $category = switch ($status) { 401 { 'AuthenticationError' } 403 { 'PermissionDenied' } 413 { 'LimitsExceeded' } 422 { 'InvalidData' } default { 'InvalidResult' } }
    if ($id -eq 'PivotServerBusy') { $category = 'ResourceBusy' } elseif ($id -eq 'PivotNoData') { $category = 'ObjectNotFound' }
    New-UDPivotError -Id $id -Category $category -Message $message -TargetObject $p -Data @{
        Status = $status; Code = $code; Title = $p.Title; Detail = $p.Detail; RetryAfter = $p.RetryAfter; Retryable = $p.Retryable; RequestId = $p.RequestId; NotShown = if ($p.NotShown.Count) { $p.NotShown }
    }
}
