function Assert-UDPivotReportEngine {
    <#
    .SYNOPSIS
        Refuses the parameters of Invoke-UDPivotReport that do not go with its -Engine.
    .PARAMETER Bound
        Invoke-UDPivotReport's $PSBoundParameters.
    .PARAMETER Engine
        Node or Rest.
    .EXAMPLE
        Assert-UDPivotReportEngine -Bound $PSBoundParameters -Engine Node
    .OUTPUTS
        None; throws on a parameter of the other engine.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Bound, [Parameter(Mandatory)][string]$Engine)
    # the parameters given of a list, as "-Name"
    $given = { param($Names) @($Names | Where-Object { $Bound.ContainsKey($_) } | ForEach-Object { "-$_" }) }
    if ($Engine -eq 'Node') {
        $wrong = & $given 'Source', 'Parameter', 'Uri', 'Token', 'Credential', 'TokenUri', 'Scope', 'Audience', 'Resource', 'ClientAuthentication', 'DataName', 'DataAsOf', 'MaxBytes', 'AsLink'
        if ($wrong.Count) { throw ('{0}: only with -Engine Rest.' -f ($wrong -join ', ')) }
        if (-not $Bound.ContainsKey('Data')) { throw '-Engine Node needs -Data: the command line runs over the rows you give.' }
        return
    }
    $wrong = & $given 'CliPath', 'TimeZone'
    if ($wrong.Count) { throw ('{0}: only with -Engine Node (pivotkit-server uses its own).' -f ($wrong -join ', ')) }
    if ($Bound['Template']) { throw '-Template: only with -Engine Node. With -Engine Rest the server''s source decides the template (sources.<id>.template in its configuration).' }
}
