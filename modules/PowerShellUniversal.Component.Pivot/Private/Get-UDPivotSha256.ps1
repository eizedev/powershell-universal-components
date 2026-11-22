function Get-UDPivotSha256 {
    <#
    .SYNOPSIS
        The SHA-256 of a text (UTF-8) as lower-case hex, cut to -Length characters.
    .PARAMETER Text
        The text.
    .PARAMETER Length
        Characters of the hex string to keep (2 to 64).
    .EXAMPLE
        Get-UDPivotSha256 -Text 'alex' -Length 24
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text, [ValidateRange(2, 64)][int]$Length = 64)
    $hash = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($Text))
    [System.Convert]::ToHexString($hash).Substring(0, $Length).ToLowerInvariant()
}
