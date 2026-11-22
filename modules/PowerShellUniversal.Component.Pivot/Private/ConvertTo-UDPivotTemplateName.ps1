function ConvertTo-UDPivotTemplateName {
    <#
    .SYNOPSIS
        A template name as plain text: control characters become spaces, trimmed, 1 to 120 characters.
    .PARAMETER Name
        The name from the browser, a file or a store.
    .EXAMPLE
        ConvertTo-UDPivotTemplateName -Name ' Open work per team '
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()][object]$Name)
    if ($Name -isnot [string]) { throw 'A view name must be text.' }
    $text = ($Name -replace '[\p{Cc}\p{Cf}\u2028\u2029]', ' ').Trim()
    if ($text.Length -lt 1 -or $text.Length -gt $Script:MaxTemplateNameLength) {
        throw ('A view name has 1 to {0} characters.' -f $Script:MaxTemplateNameLength)
    }
    $text
}
