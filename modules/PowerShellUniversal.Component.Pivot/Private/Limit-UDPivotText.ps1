function Limit-UDPivotText {
    <#
    .SYNOPSIS
        A text cut to -MaxLength characters (ending with an ellipsis when cut), or $null for an empty one.
    .PARAMETER Text
        The text.
    .PARAMETER MaxLength
        The longest text kept.
    .EXAMPLE
        Limit-UDPivotText -Text $description -MaxLength 1000
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][AllowEmptyString()][string]$Text, [Parameter(Mandatory)][int]$MaxLength)
    $value = "$Text".Trim()
    if (-not $value) { return $null }
    if ($value.Length -le $MaxLength) { return $value }
    $value.Substring(0, $MaxLength - 1).TrimEnd() + [char]0x2026
}
