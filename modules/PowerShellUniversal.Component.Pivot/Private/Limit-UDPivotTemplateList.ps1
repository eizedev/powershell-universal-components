function Limit-UDPivotTemplateList {
    <#
    .SYNOPSIS
        Cuts a report's templates to the most the report takes, with a warning.
    .PARAMETER List
        The templates; changed in place.
    .EXAMPLE
        Limit-UDPivotTemplateList -List $list
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param([Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$List)
    if ($List.Count -gt $Script:MaxTemplates) {
        Write-Warning ('Pivot templates: {0}, more than the {1} the report takes; the rest is left out.' -f $List.Count, $Script:MaxTemplates)
        $List.RemoveRange($Script:MaxTemplates, $List.Count - $Script:MaxTemplates)
    }
}
