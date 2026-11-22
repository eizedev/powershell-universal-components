function Assert-UDPivotRestInput {
    <#
    .SYNOPSIS
        Refuses what Invoke-UDPivotReport -Engine Rest cannot send: rows and a source together or
        neither, parameters without a source, data options without rows, a link written to a file.
    .PARAMETER Bound
        Invoke-UDPivotReport's $PSBoundParameters.
    .EXAMPLE
        Assert-UDPivotRestInput -Bound $PSBoundParameters
    .OUTPUTS
        None; throws on a combination that cannot work.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Bound)
    $hasData = $Bound.ContainsKey('Data')
    $source = [string]$Bound['Source']
    if ($hasData -eq [bool]$source) { throw '-Engine Rest needs either -Data (rows sent with the request) or -Source (a source the operator configured).' }
    if ($Bound['Parameter'] -and -not $source) { throw '-Parameter goes with -Source.' }
    if (($Bound['DataName'] -or $Bound['DataAsOf'] -or $Bound.ContainsKey('MaxBytes')) -and -not $hasData) { throw '-DataName, -DataAsOf and -MaxBytes go with -Data.' }
    if ($Bound['AsLink'] -and $Bound['OutFile']) { throw '-AsLink returns a link to the report the server keeps; it writes no file, so it does not go with -OutFile.' }
}
