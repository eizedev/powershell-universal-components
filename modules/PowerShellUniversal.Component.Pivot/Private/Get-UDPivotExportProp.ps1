function Get-UDPivotExportProp {
    <#
    .SYNOPSIS
        The props of New-UDPivotReport for what readers may take out and load: drill-down export, data
        export, file import and its limits.
    .PARAMETER Bound
        New-UDPivotReport's $PSBoundParameters.
    .PARAMETER ColumnName
        The names of the report's columns.
    .EXAMPLE
        $props += Get-UDPivotExportProp -Bound $PSBoundParameters -ColumnName $columnNames
    .OUTPUTS
        System.Collections.Hashtable: the props to add.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Bound,
        [AllowEmptyCollection()][string[]]$ColumnName
    )
    $props = @{}
    if ($Bound['DrillDownExport']) { $props['drillDownExport'] = $true }
    if ($Bound['ExportData']) { $props['exportData'] = ConvertTo-UDPivotExportData -Column $Bound['ExportDataColumn'] -ColumnName $ColumnName }
    if ($Bound['AllowImport']) { $props['allowImport'] = $true }
    if ($Bound.ContainsKey('ImportLimit') -and $null -ne $Bound['ImportLimit']) {
        $limits = ConvertTo-UDPivotImportLimit -ImportLimit $Bound['ImportLimit']
        if (@($limits.PSObject.Properties).Count) { $props['importLimits'] = $limits }
    }
    $props
}
