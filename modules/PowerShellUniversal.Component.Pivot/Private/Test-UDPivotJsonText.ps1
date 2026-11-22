function Test-UDPivotJsonText {
    <#
    .SYNOPSIS
        Checks that a text is one JSON object of at most -MaxLength characters and -MaxDepth levels.
    .DESCRIPTION
        Parses with System.Text.Json (strict JSON, no comments or trailing commas, nothing evaluated) and
        throws an error that starts with -Name when the text is not such an object.
    .PARAMETER Text
        The JSON text.
    .PARAMETER Name
        The parameter the text came from, for the error message.
    .PARAMETER MaxLength
        The longest text accepted, in characters.
    .PARAMETER MaxDepth
        The deepest nesting accepted.
    .EXAMPLE
        Test-UDPivotJsonText -Text '{"title":{"text":"Tickets"}}' -Name '-ChartOptions' -MaxLength 65536 -MaxDepth 16
    .OUTPUTS
        System.String, the text without leading and trailing white space.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][int]$MaxLength,
        [Parameter(Mandatory)][int]$MaxDepth
    )
    $json = $Text.Trim()
    if ($json.Length -gt $MaxLength) { throw ('{0}: {1} characters, more than the {2} allowed.' -f $Name, $json.Length, $MaxLength) }
    $options = [System.Text.Json.JsonDocumentOptions]::new()
    $options.MaxDepth = $MaxDepth
    try {
        $document = [System.Text.Json.JsonDocument]::Parse($json, $options)
    }
    catch {
        throw ('{0}: not valid JSON of at most {1} levels ({2})' -f $Name, $MaxDepth, $_.Exception.InnerException.Message ?? $_.Exception.Message)
    }
    try {
        if ($document.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) { throw ('{0}: expected a JSON object.' -f $Name) }
    }
    finally {
        $document.Dispose()
    }
    $json
}
