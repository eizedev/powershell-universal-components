function ConvertTo-PSUComponentValue {
    <#
    .SYNOPSIS
        Converts one cell value to a JSON-safe value (see ConvertTo-PSUComponentData).
    .DESCRIPTION
        The rules for every type. ConvertTo-PSUComponentData applies them inline for the common
        types (see $Script:PSUComponentValueKind) and calls this function for the others.
    .PARAMETER Value
        The value.
    .EXAMPLE
        ConvertTo-PSUComponentValue ([DBNull]::Value)
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$Value)
    if ($null -eq $Value -or $Value -is [System.DBNull]) { return $null }
    if ($Value -is [datetime] -or $Value -is [datetimeoffset]) { return $Value.ToString('o') }
    if ($Value -is [timespan]) { return $Value.TotalSeconds }
    if ($Value -is [enum]) { return [string]$Value }
    $Value
}
