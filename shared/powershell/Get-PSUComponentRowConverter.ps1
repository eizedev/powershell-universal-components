function Get-PSUComponentRowConverter {
    <#
    .SYNOPSIS
        The compiled DataTable converter of ConvertTo-PSUComponentData, compiled on first use; $null when
        Add-Type is not available.
    .DESCRIPTION
        A DataTable is the large case (SQL results of thousands of rows), and building PSCustomObjects in
        PowerShell costs about 40 microseconds per row on a small server; the same in C# about 7 (measured
        on PSU 2026.3.4: 5000 rows x 12 columns, 190 ms against 35 ms). The class in RowConverter.cs is
        compiled once per process (about 2 s), the first time a DataTable of at least
        $Script:PSUComponentCompileMinRows rows arrives; PSU runs its apps in its own process, so that
        happens once per PSU start, not per app start. Where Add-Type is not available (constrained
        language mode) the PowerShell path does the same work.
    .EXAMPLE
        $converter = Get-PSUComponentRowConverter
    .OUTPUTS
        System.Type, or $null.
    #>
    [CmdletBinding()]
    [OutputType([type])]
    param()
    if ($false -eq $Script:PSUComponentRowCompiled) { return $null }
    $type = $null
    try {
        # RowConverter.cs next to this file; a module without it (or without Add-Type) converts in PowerShell
        if (-not $Script:PSUComponentRowSource) {
            $Script:PSUComponentRowSource = Get-PSUComponentTypeSource -Path (Join-Path $PSScriptRoot 'RowConverter.cs') -TypeName 'PSUComponentData.RowConverter'
        }
        $type = $Script:PSUComponentRowSource.Type -as [type]
        if (-not $type) {
            Add-Type -TypeDefinition $Script:PSUComponentRowSource.Source -ErrorAction Stop
            $type = $Script:PSUComponentRowSource.Type -as [type]
        }
    }
    catch {
        Write-Verbose ('ConvertTo-PSUComponentData: no compiled converter ({0}); PowerShell converts the rows.' -f $_.Exception.Message)
    }
    $Script:PSUComponentRowCompiled = $null -ne $type
    $type
}
