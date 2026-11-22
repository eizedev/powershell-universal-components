function Register-UDPivotReportEvent {
    <#
    .SYNOPSIS
        Registers the event handlers of a report with PSU and returns them as the report's props.
    .DESCRIPTION
        One registration per event: endpoints registered under the same id replace each other, so each
        event gets the id <report id>-<event>.
    .PARAMETER Id
        The report's -Id.
    .PARAMETER Bound
        New-UDPivotReport's $PSBoundParameters: the Endpoints of OnViewChange, OnCellClick,
        OnSaveTemplate, OnDeleteTemplate, OnPublishTemplate and OnDataLoad.
    .PARAMETER StoreHandler
        The handlers of the template store (Get-UDPivotReportTemplate), in place of the parameters.
    .PARAMETER Cmdlet
        New-UDPivotReport's $PSCmdlet, which PSU's Endpoint.Register takes.
    .EXAMPLE
        $props += Register-UDPivotReportEvent -Id 'tickets' -Bound $PSBoundParameters -StoreHandler @{} -Cmdlet $PSCmdlet
    .OUTPUTS
        System.Collections.Hashtable: the props to add (onViewChange, ...).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Id,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Bound,
        [Parameter(Mandatory)][AllowEmptyCollection()][hashtable]$StoreHandler,
        [Parameter(Mandatory)][System.Management.Automation.PSCmdlet]$Cmdlet
    )
    $props = @{}
    foreach ($name in 'OnViewChange', 'OnCellClick', 'OnSaveTemplate', 'OnDeleteTemplate', 'OnPublishTemplate', 'OnDataLoad') {
        $endpoint = if ($StoreHandler.ContainsKey($name)) { $StoreHandler[$name] } else { $Bound[$name] }
        if (-not $endpoint) { continue }
        $prop = $name.Substring(0, 1).ToLowerInvariant() + $name.Substring(1)
        $endpoint.Register(('{0}-{1}' -f $Id, $prop), $Cmdlet)
        $props[$prop] = $endpoint
    }
    $props
}
