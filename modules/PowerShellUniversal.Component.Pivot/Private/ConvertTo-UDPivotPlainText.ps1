function ConvertTo-UDPivotPlainText {
    <#
    .SYNOPSIS
        A secret given as a string or a SecureString, as plain text for the one request that needs it.
    .DESCRIPTION
        PSU hands a secret variable to a script as its value; a SecureString (Read-Host -AsSecureString,
        a PSCredential's password) works the same. The text is never written to any stream.
    .PARAMETER Secret
        The secret.
    .PARAMETER Name
        The parameter it came from, for the error message.
    .EXAMPLE
        ConvertTo-UDPivotPlainText -Secret $Secret:PivotkitToken -Name '-Token'
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][object]$Secret, [Parameter(Mandatory)][string]$Name)
    $text = if ($Secret -is [securestring]) { [System.Net.NetworkCredential]::new('', $Secret).Password } elseif ($Secret -is [string]) { $Secret }
    if ([string]::IsNullOrEmpty($text)) { throw ('{0}: expected a token as a string or SecureString (a PSU secret).' -f $Name) }
    if ($text -match '[\s\p{Cc}]') { throw ('{0}: the token holds whitespace or a control character.' -f $Name) }
    $text
}
