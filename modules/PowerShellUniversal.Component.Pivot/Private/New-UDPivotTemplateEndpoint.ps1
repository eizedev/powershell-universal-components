function New-UDPivotTemplateEndpoint {
    <#
    .SYNOPSIS
        The event handler of one template action of a report with -TemplateStore, as a PSU endpoint.
    .DESCRIPTION
        The handler is code text with the store's key in it: PSU runs it in a runspace of its own, where
        it loads the module and calls Invoke-UDPivotTemplateRequest with the $User and $Roles of the event.
    .PARAMETER Key
        The store's key.
    .PARAMETER Action
        Save, Publish or Delete.
    .EXAMPLE
        New-UDPivotTemplateEndpoint -Key $key -Action Save
    .OUTPUTS
        Endpoint
    #>
    # describes a handler for PSU to register; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{32}$')][string]$Key, [Parameter(Mandatory)][ValidateSet('Save', 'Publish', 'Delete')][string]$Action)
    $code = @'
Import-Module PowerShellUniversal.Component.Pivot
Invoke-UDPivotTemplateRequest -Key '{0}' -Action {1} -EventData $EventData -UserName ([string](Get-Variable -Name User -ValueOnly -ErrorAction Ignore)) -Roles @(Get-Variable -Name Roles -ValueOnly -ErrorAction Ignore)
'@ -f $Key, $Action
    [Endpoint][scriptblock]::Create($code)
}
