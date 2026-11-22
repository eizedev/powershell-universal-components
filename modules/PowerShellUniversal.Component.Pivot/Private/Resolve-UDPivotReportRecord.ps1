function Resolve-UDPivotReportRecord {
    <#
    .SYNOPSIS
        The rows of a report on a pivotkit-server source (New-UDPivotReport -Uri -Source), or the problem
        the reader sees instead when the server or the sign-in refuses.
    .DESCRIPTION
        The page still gets a report that tells the reader what happened. The operator's message (the
        server's address and answer) goes to the warning stream, the app's log: PSU shows an error of a
        page to the reader as a toast (measured on 2026.2.5 and 2026.3.4). A caller of New-UDPivotReport
        that asks for the error (-ErrorAction, -ErrorVariable) gets it with its id; with Stop it throws
        (the module's own preference is Stop, so the caller's choice decides here).
    .PARAMETER Bound
        New-UDPivotReport's $PSBoundParameters.
    .PARAMETER Cmdlet
        New-UDPivotReport's $PSCmdlet: the error is written to its error stream.
    .PARAMETER ErrorMark
        New-UDPivotReport's mark of Get-UDPivotErrorMark.
    .PARAMETER ViewName
        The name of a view the server publishes for the source, or nothing.
    .PARAMETER MaxBytes
        The most bytes of the answer to read.
    .PARAMETER TimeoutSec
        How long the server may take.
    .EXAMPLE
        $server = Resolve-UDPivotReportRecord -Bound $PSBoundParameters -Cmdlet $PSCmdlet -ErrorMark $errorMark -MaxBytes $MaxBytes -TimeoutSec $TimeoutSec
    .OUTPUTS
        PSCustomObject with Records (of Get-UDPivotRecordText) or Problem (of ConvertTo-UDPivotReaderProblem).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Bound,
        [Parameter(Mandatory)][System.Management.Automation.PSCmdlet]$Cmdlet,
        [AllowNull()][object]$ErrorMark,
        [string]$ViewName,
        [Parameter(Mandatory)][long]$MaxBytes,
        [Parameter(Mandatory)][int]$TimeoutSec
    )
    $auth = Resolve-UDPivotRestSignIn -Bound @{ Uri = $Bound['Uri']; Token = $Bound['Token'] } -TimeoutSec $TimeoutSec
    try {
        $records = Get-UDPivotServerRecord -Bound $Bound -Cmdlet $Cmdlet -Auth $auth -ViewName $ViewName -MaxBytes $MaxBytes -TimeoutSec $TimeoutSec
        return [pscustomobject]@{ Records = $records; Problem = $null }
    }
    catch {
        if ($_.FullyQualifiedErrorId -notmatch '^Pivot[A-Za-z]+$') { throw }
        $problem = ConvertTo-UDPivotReaderProblem -ErrorRecord $_
        Write-Warning ('{0}: {1}' -f ($_.FullyQualifiedErrorId -split ',')[0], $_.Exception.Message)
        if ($Bound.ContainsKey('ErrorAction') -or $Bound.ContainsKey('ErrorVariable')) {
            # -ErrorVariable holds this error once, not the module's steps on the way (#153)
            Reset-UDPivotErrorVariable -Mark $ErrorMark
            if ([string]$Bound['ErrorAction'] -eq 'Stop') { throw $_ }
            if (-not $Bound.ContainsKey('ErrorAction')) { $ErrorActionPreference = 'Continue' }
            $Cmdlet.WriteError($_)
        }
        [pscustomobject]@{ Records = $null; Problem = $problem }
    }
}
