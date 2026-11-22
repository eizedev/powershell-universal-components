function Select-UDPivotNamedView {
    <#
    .SYNOPSIS
        The stored views of a name the report lists, by pivotkit's rule: its Views menu compares names
        with === (the same characters in the same case). Those made for this data, else those made for
        no named data, as pivotkit's browser store replaces them.
    .PARAMETER Entries
        The views of Get-UDPivotStoredView.
    .PARAMETER Name
        The checked name.
    .PARAMETER ReportData
        The id of the report's data.
    .EXAMPLE
        $found = @(Select-UDPivotNamedView -Entries $all -Name 'Sales' -ReportData 'tickets')
    .OUTPUTS
        PSCustomObject: the views of Get-UDPivotStoredView that match.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyCollection()][object[]]$Entries,
        [Parameter(Mandatory)][string]$Name,
        [AllowEmptyString()][string]$ReportData
    )
    $all = @($Entries | Where-Object { $_.Name -ceq $Name -and (Test-UDPivotListedView -Entry $_ -ReportData $ReportData) })
    $same = @($all | Where-Object { [string]$_.SourceId -ceq $ReportData })
    if ($same.Count) { $same } else { @($all | Where-Object { -not $_.SourceId }) }
}
