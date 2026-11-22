function Get-UDPivotShippedTemplate {
    <#
    .SYNOPSIS
        The views an app ships with a report: -Templates, then the -TemplatePath files made for this
        report's data or for no data (as the store and pivotkit's browser store list them, ids compared
        with case).
    .PARAMETER Bound
        New-UDPivotReport's $PSBoundParameters: Templates and TemplatePath.
    .PARAMETER SourceId
        The id of the report's data.
    .EXAMPLE
        $shipped = Get-UDPivotShippedTemplate -Bound $PSBoundParameters -SourceId 'tickets'
    .OUTPUTS
        System.Collections.Generic.List[object]: templates as the report takes them.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[object]])]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Bound,
        [Parameter(Mandatory)][AllowEmptyString()][string]$SourceId
    )
    $shipped = [System.Collections.Generic.List[object]]::new()
    if ($Bound.ContainsKey('Templates')) { foreach ($t in @(ConvertTo-UDPivotTemplate -Template $Bound['Templates'])) { $shipped.Add($t) } }
    if ($Bound['TemplatePath']) {
        foreach ($t in @(Get-UDPivotTemplateFile -Path $Bound['TemplatePath'])) {
            if ($t.SourceId -and $t.SourceId -cne $SourceId) { continue }
            $shipped.Add([pscustomobject]@{ name = $t.Name; view = $t.View; scope = 'shared'; deletable = $false })
        }
    }
    , $shipped
}
