function New-UDPivotError {
    <#
    .SYNOPSIS
        An ErrorRecord with a fixed error id, so a script can tell the reasons apart
        ($_.FullyQualifiedErrorId, Should -Throw -ErrorId).
    .DESCRIPTION
        The ids: PivotServerUnreachable, PivotRedirectRefused, PivotTokenRefused, PivotDataTooLarge,
        PivotViewHasErrors, PivotNoLink, PivotServerError, PivotCliNotFound, PivotCliFailed, and for the
        rows route PivotRowsNotAllowed, PivotNoData and PivotServerBusy. Data holds
        what the caller may act on, where the server sent it: Status, Code, Title, Detail, RetryAfter
        (the Retry-After header: seconds or an HTTP date), Retryable (bool: whether the same request may
        work when tried again) and RequestId (from the problem document, else the X-Request-Id header).
        For an answer of pivotkit-server, TargetObject is the answer as a PivotServerProblem
        (ConvertTo-UDPivotServerProblem). The record carries no request, so no token or secret.
    .PARAMETER Id
        The error id.
    .PARAMETER Message
        What happened and what to do.
    .PARAMETER Category
        The ErrorCategory.
    .PARAMETER Data
        Values for Exception.Data.
    .PARAMETER TargetObject
        The server's answer (a PivotServerProblem), or nothing.
    .EXAMPLE
        throw (New-UDPivotError -Id PivotCliNotFound -Message 'pivotkit was not found' -Category ObjectNotFound)
    .OUTPUTS
        System.Management.Automation.ErrorRecord
    #>
    # Builds an errorrecord in memory; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)][ValidateSet('PivotServerUnreachable', 'PivotRedirectRefused', 'PivotTokenRefused', 'PivotDataTooLarge', 'PivotViewHasErrors', 'PivotNoLink', 'PivotServerError', 'PivotCliNotFound', 'PivotCliFailed', 'PivotRowsNotAllowed', 'PivotNoData', 'PivotServerBusy')][string]$Id,
        [Parameter(Mandatory)][string]$Message,
        [System.Management.Automation.ErrorCategory]$Category = 'InvalidResult',
        [hashtable]$Data,
        [AllowNull()][object]$TargetObject
    )
    $exception = [System.InvalidOperationException]::new($Message)
    if ($Data) { foreach ($k in $Data.Keys) { if ($null -ne $Data[$k]) { $exception.Data[$k] = $Data[$k] } } }
    [System.Management.Automation.ErrorRecord]::new($exception, $Id, $Category, $TargetObject)
}
