function Assert-UDPivotReportParameter {
    <#
    .SYNOPSIS
        Refuses the parameter combinations of New-UDPivotReport that cannot work, before anything is read.
    .PARAMETER Bound
        New-UDPivotReport's $PSBoundParameters.
    .EXAMPLE
        Assert-UDPivotReportParameter -Bound $PSBoundParameters
    .OUTPUTS
        None; throws on a combination that cannot work.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Bound)
    if (-not $Script:AssetId) { throw $Script:MissingAssetMessage }
    if ($Bound['OnDataLoad'] -and -not $Bound['AllowImport']) { throw '-OnDataLoad needs -AllowImport: without it the data shown never changes.' }
    if ($Bound.ContainsKey('ImportLimit') -and -not $Bound['AllowImport']) { throw '-ImportLimit needs -AllowImport: without it no file is loaded.' }
    if ($Bound['DrillDownExport'] -and $Bound['NoDrillDown']) { throw '-DrillDownExport needs the drill-down: -NoDrillDown leaves no panel to copy or download from.' }
    if ($Bound['ExportDataColumn'] -and -not $Bound['ExportData']) { throw '-ExportDataColumn needs -ExportData: naming columns never turns an export on by itself.' }
}
