function Get-UDPivotReportInput {
    <#
    .SYNOPSIS
        What Invoke-UDPivotReport renders: the checked view file of -View or the layout of -Layout, and
        the report's title (-Title, else the view file's own name).
    .PARAMETER Bound
        Invoke-UDPivotReport's $PSBoundParameters: View or Layout, and Title.
    .PARAMETER ParameterSetName
        View or Layout.
    .EXAMPLE
        $report = Get-UDPivotReportInput -Bound $PSBoundParameters -ParameterSetName $PSCmdlet.ParameterSetName
    .OUTPUTS
        PSCustomObject with ViewFile (or $null), Layout (or $null) and Title (or $null).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Bound, [Parameter(Mandatory)][string]$ParameterSetName)
    $viewFile = $null
    $layout = $null
    if ($ParameterSetName -eq 'View') {
        try { $viewFile = ConvertFrom-UDPivotViewFile -InputObject $Bound['View'] -Name 'Pivot report' }
        catch { throw ('-View: {0}' -f $_.Exception.Message) }
    }
    else {
        $layout = ConvertTo-UDPivotReportLayout -Layout $Bound['Layout']
    }
    $title = if ($Bound['Title']) { $Bound['Title'] } elseif ($viewFile -and $viewFile.Name -ne 'Pivot report') { $viewFile.Name }
    [pscustomobject]@{ ViewFile = $viewFile; Layout = $layout; Title = $title }
}
