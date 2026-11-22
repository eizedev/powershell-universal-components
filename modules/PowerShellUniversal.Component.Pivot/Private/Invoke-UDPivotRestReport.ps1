function Invoke-UDPivotRestReport {
    <#
    .SYNOPSIS
        Renders a report with pivotkit-server (Invoke-UDPivotReport -Engine Rest): the file's bytes, or
        with -AsLink a link to the report the server keeps.
    .PARAMETER Bound
        Invoke-UDPivotReport's $PSBoundParameters: Data, Source, Parameter, DataName, DataAsOf and Uri.
    .PARAMETER Report
        The result of Get-UDPivotReportInput.
    .PARAMETER Kind
        The format.
    .PARAMETER Auth
        The sign-in of Resolve-UDPivotRestSignIn.
    .PARAMETER MaxBytes
        The most bytes of rows to send.
    .PARAMETER TimeoutSec
        How long the server may take.
    .PARAMETER AsLink
        Ask the server to keep the report and return a link to it.
    .EXAMPLE
        $bytes = Invoke-UDPivotRestReport -Bound $PSBoundParameters -Report $report -Kind xlsx -Auth $auth -MaxBytes 10MB -TimeoutSec 120
    .OUTPUTS
        System.Byte[], or the link of Get-UDPivotReportLink with -AsLink.
    #>
    [CmdletBinding()]
    [OutputType([byte[]], [pscustomobject])]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Bound,
        [Parameter(Mandatory)][pscustomobject]$Report,
        [Parameter(Mandatory)][string]$Kind,
        [Parameter(Mandatory)][hashtable]$Auth,
        [Parameter(Mandatory)][long]$MaxBytes,
        [Parameter(Mandatory)][int]$TimeoutSec,
        [switch]$AsLink
    )
    # splatted: a $(...) around -Data would enumerate a DataTable into its rows
    $bodyArgs = @{ Source = [string]$Bound['Source']; Parameter = $Bound['Parameter']; Layout = $Report.Layout; Format = $Kind; Title = $Report.Title; DataName = [string]$Bound['DataName']; DataAsOf = $Bound['DataAsOf'] }
    if ($Bound.ContainsKey('Data')) { $bodyArgs['Data'] = $Bound['Data']; $bodyArgs['MaxBytes'] = $MaxBytes }
    if ($Report.ViewFile) { $bodyArgs['View'] = $Report.ViewFile.View }
    if ($AsLink) {
        $body = New-UDPivotRenderBody @bodyArgs -Save
        return Get-UDPivotReportLink -Uri $Bound['Uri'] -Body $body -Auth $Auth -TimeoutSec $TimeoutSec
    }
    $body = New-UDPivotRenderBody @bodyArgs
    , (Invoke-UDPivotRestRender -Uri $Bound['Uri'] -Body $body -Auth $Auth -TimeoutSec $TimeoutSec)
}
