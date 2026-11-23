function Register-UDEChartEvent {
    <#
    .SYNOPSIS
        Registers New-UDEChart's event handlers with PSU under the chart's id and returns their props.
    .PARAMETER Bound
        New-UDEChart's $PSBoundParameters.
    .PARAMETER Id
        The chart's id (-Id, or the GUID New-UDEChart made).
    .PARAMETER Cmdlet
        New-UDEChart's $PSCmdlet, which PSU's Endpoint.Register takes.
    .EXAMPLE
        $events = Register-UDEChartEvent -Bound $PSBoundParameters -Id $Id -Cmdlet $PSCmdlet
    .OUTPUTS
        System.Collections.Hashtable: onClick, onSelect, onZoom and onLegendChange, those given.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Bound, [Parameter(Mandatory)][AllowEmptyString()][string]$Id, [Parameter(Mandatory)][System.Management.Automation.PSCmdlet]$Cmdlet)
    $props = @{}
    foreach ($name in 'OnClick', 'OnSelect', 'OnZoom', 'OnLegendChange') {
        $endpoint = $Bound[$name]
        if ($endpoint) {
            $endpoint.Register($Id, $Cmdlet)
            $props['o' + $name.Substring(1)] = $endpoint
        }
    }
    $props
}
