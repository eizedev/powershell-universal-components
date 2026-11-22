function ConvertTo-UDPivotExportData {
    <#
    .SYNOPSIS
        -ExportData and -ExportDataColumn as pivotkit-react's exportData: $true, or @{ columns } with the
        names as the data spells them.
    .DESCRIPTION
        Every name in -Column must be a column of the data (without regard to case), each once: an
        unknown name throws and names it, so a typo never turns into an export of every column. Data
        without rows (-AllowImport with an empty -Data) has no columns to check against; the names go
        to pivotkit as given, which offers nothing for a name that matches no column.
    .PARAMETER Column
        The columns of -ExportDataColumn, or none for every column.
    .PARAMETER ColumnName
        The columns of the data.
    .EXAMPLE
        ConvertTo-UDPivotExportData -Column 'team', 'Hours' -ColumnName 'Team', 'Hours', 'Customer'
    .OUTPUTS
        System.Boolean or System.Collections.Hashtable
    #>
    [CmdletBinding()]
    [OutputType([bool], [hashtable])]
    param(
        [AllowNull()][AllowEmptyCollection()][string[]]$Column,
        [AllowNull()][AllowEmptyCollection()][string[]]$ColumnName
    )
    if (-not $Column) { return $true }
    $known = @($ColumnName | Where-Object { $_ })
    $picked = [System.Collections.Generic.List[string]]::new()
    $unknown = [System.Collections.Generic.List[string]]::new()
    foreach ($name in $Column) {
        $match = if ($known.Count) { $known | Where-Object { $_ -eq $name } | Select-Object -First 1 } else { $name }
        if ($null -eq $match) { $unknown.Add($name) }
        elseif (-not ($picked | Where-Object { $_ -eq $match })) { $picked.Add($match) }
    }
    if ($unknown.Count) {
        throw ('-ExportDataColumn: {0} {1} no column of -Data (columns: {2}).' -f (($unknown | ForEach-Object { '"{0}"' -f $_ }) -join ', '), $(if ($unknown.Count -eq 1) { 'is' } else { 'are' }), ($known -join ', '))
    }
    # an array, also for one name: pivotkit turns everything off for columns that are no list
    @{ columns = [string[]]$picked.ToArray() }
}
