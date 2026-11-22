function Get-UDPivotAdminInfo {
    <#
    .SYNOPSIS
        The admin panel under a report: its size, how long the server took for it, and its templates.
    .PARAMETER RowCount
        The rows of the report.
    .PARAMETER ColumnCount
        The columns of the report.
    .PARAMETER ConvertMs
        How long reading and converting the data took.
    .PARAMETER Timer
        Started when New-UDPivotReport began.
    .PARAMETER Template
        The result of Resolve-UDPivotReportTemplate.
    .EXAMPLE
        $props['admin'] = Get-UDPivotAdminInfo -RowCount 10 -ColumnCount 3 -ConvertMs 1.2 -Timer $timer -Template $templateInfo
    .OUTPUTS
        PSCustomObject with rows, columns, convertMs, serverMs, templates and store.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][object]$RowCount,
        [Parameter(Mandatory)][object]$ColumnCount,
        [Parameter(Mandatory)][double]$ConvertMs,
        [Parameter(Mandatory)][System.Diagnostics.Stopwatch]$Timer,
        [Parameter(Mandatory)][pscustomobject]$Template
    )
    [pscustomobject]@{
        rows      = $RowCount
        columns   = $ColumnCount
        convertMs = [math]::Round($ConvertMs, 1)
        serverMs  = [math]::Round($Timer.Elapsed.TotalMilliseconds, 1)
        templates = $Template.Count
        store     = $Template.StoreKind
    }
}
