function ConvertTo-UDPivotJsonText {
    <#
    .SYNOPSIS
        A hashtable, an object or a JSON string as checked compact JSON text, for a prop PSU must not
        camelCase.
    .DESCRIPTION
        PSU camelCases the keys of objects in props on their way to the browser; field names and schema
        names in them would change. As JSON text they arrive as they are. A string is taken as JSON;
        anything else goes through ConvertTo-Json. The result is checked by Test-UDPivotJsonText.
    .PARAMETER InputObject
        The value: a hashtable, an ordered dictionary, a PSCustomObject or a JSON string.
    .PARAMETER Name
        The parameter the value came from, for error messages.
    .PARAMETER MaxLength
        The longest JSON accepted, in characters.
    .PARAMETER MaxDepth
        The deepest nesting accepted.
    .EXAMPLE
        ConvertTo-UDPivotJsonText -InputObject @{ legend = @{ show = $false } } -Name '-ChartOptions' -MaxLength 65536 -MaxDepth 16
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowNull()][object]$InputObject,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$MaxLength,
        [Parameter(Mandatory)][int]$MaxDepth
    )
    if ($null -eq $InputObject) { throw ('{0}: no value (null).' -f $Name) }
    $text = if ($InputObject -is [string]) { $InputObject } else {
        # one level deeper than allowed: ConvertTo-Json cuts deeper levels off with a warning and writes
        # them as text, which the depth check below then refuses
        ConvertTo-Json -InputObject $InputObject -Depth ($MaxDepth + 1) -Compress -WarningAction SilentlyContinue
    }
    Test-UDPivotJsonText -Text $text -Name $Name -MaxLength $MaxLength -MaxDepth $MaxDepth
}
