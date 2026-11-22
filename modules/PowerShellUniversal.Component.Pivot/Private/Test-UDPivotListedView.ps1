function Test-UDPivotListedView {
    <#
    .SYNOPSIS
        True when a report lists a stored view: one store serves several reports, and a report lists the
        views of its data and those made for no named data (as pivotkit's browser store).
    .PARAMETER Entry
        A view of Get-UDPivotStoredView.
    .PARAMETER ReportData
        The id of the report's data; empty lists every view.
    .EXAMPLE
        $all | Where-Object { Test-UDPivotListedView -Entry $_ -ReportData 'tickets' }
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][object]$Entry, [AllowEmptyString()][string]$ReportData)
    -not $ReportData -or -not $Entry.SourceId -or $Entry.SourceId -ceq $ReportData
}
