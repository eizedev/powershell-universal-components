function ConvertTo-UDPivotReaderProblem {
    <#
    .SYNOPSIS
        What the report tells the reader when the server gave no rows: a kind the browser has words for,
        and what goes with it. Never the token, never the operator's details beyond a request id.
    .DESCRIPTION
        kind: signIn (PivotTokenRefused), notAllowed (PivotRowsNotAllowed, with fields from notShown),
        badLink (the server's 400: a parameter's value or a view name that does not fit), notSetUp
        (403 INSUFFICIENT_SCOPE: the sign-in lacks a scope the server asks for), noData (PivotNoData), tooLarge (PivotDataTooLarge, with the server's detail as it is), busy
        (PivotServerBusy, with retryAfter in seconds where the server sent them), unreachable
        (PivotServerUnreachable) or serverError (the rest). requestId is the server's, for the operator.
    .PARAMETER ErrorRecord
        The error of the rows request.
    .EXAMPLE
        ConvertTo-UDPivotReaderProblem -ErrorRecord $_
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord)
    $id = ($ErrorRecord.FullyQualifiedErrorId -split ',')[0]
    $kind = switch ($id) {
        'PivotTokenRefused' { 'signIn' }
        'PivotRowsNotAllowed' { 'notAllowed' }
        'PivotNoData' { 'noData' }
        'PivotDataTooLarge' { 'tooLarge' }
        'PivotServerBusy' { 'busy' }
        'PivotServerUnreachable' { 'unreachable' }
        default { 'serverError' }
    }
    $p = $ErrorRecord.TargetObject
    # the server refused the request itself: a link's value or view name that does not fit the source
    if ($kind -eq 'serverError' -and $p -and $p.Status -eq 400) { $kind = 'badLink' }
    # the token lacks a scope the server asks for: the operator's setting, signing in again cannot help
    if ($p -and $p.Status -eq 403 -and $p.Code -eq 'INSUFFICIENT_SCOPE') { $kind = 'notSetUp' }
    $out = [ordered]@{ kind = $kind }
    if ($p -and $p.NotShown -and $p.NotShown.Count) { $out['fields'] = [string[]]@($p.NotShown | Select-Object -First 64 | ForEach-Object { Limit-UDPivotText -Text $_ -MaxLength $Script:MaxNameLength }) }
    $seconds = 0
    if ($p -and $p.RetryAfter -and [int]::TryParse(([string]$p.RetryAfter).Trim(), [System.Globalization.NumberStyles]::None, [cultureinfo]::InvariantCulture, [ref]$seconds)) { $out['retryAfter'] = $seconds }
    # the server's own words where they are meant for the reader: the limit and what to do about it
    if ($kind -eq 'tooLarge' -and $p -and $p.Detail) { $out['detail'] = Limit-UDPivotText -Text $p.Detail -MaxLength $Script:MaxDescriptionLength }
    if ($p -and $p.RequestId) { $out['requestId'] = Limit-UDPivotText -Text $p.RequestId -MaxLength 128 }
    [pscustomobject]$out
}
