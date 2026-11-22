function ConvertTo-UDPivotHeight {
    <#
    .SYNOPSIS
        -Height as the report takes it: a bare number becomes pixels, anything else stays as it is.
    .PARAMETER Height
        The value of -Height (already checked against $Script:HeightPattern).
    .EXAMPLE
        ConvertTo-UDPivotHeight -Height 640
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$Height)
    $value = $Height.Trim()
    if ($value -match '^\d+(\.\d+)?$') { '{0}px' -f $value } else { $value }
}
