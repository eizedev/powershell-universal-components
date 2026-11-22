function Get-UDPivotEntryValue {
    <#
    .SYNOPSIS
        The value of a key of a dictionary or a property of an object, the name matched without regard to case.
    .PARAMETER InputObject
        A dictionary (hashtable, ordered) or an object.
    .PARAMETER Name
        The key or property name.
    .EXAMPLE
        Get-UDPivotEntryValue -InputObject @{ label = 'Lead time' } -Name 'Label'
    .OUTPUTS
        System.Object
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param([Parameter(Mandatory)][object]$InputObject, [Parameter(Mandatory)][string]$Name)
    if ($InputObject -is [System.Collections.IDictionary]) {
        # the comma keeps a list a list (a one-element array would come back as its element)
        foreach ($key in $InputObject.Keys) { if ([string]$key -eq $Name) { return , $InputObject[$key] } }
        return $null
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) { , $property.Value }
}
