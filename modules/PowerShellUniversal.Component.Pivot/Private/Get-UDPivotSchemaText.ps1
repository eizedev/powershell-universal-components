function Get-UDPivotSchemaText {
    <#
    .SYNOPSIS
        -Schema as checked JSON text: from a hashtable or object, a JSON string, a file or an https URL.
    .DESCRIPTION
        Used by New-UDPivotReport. A string that starts with { is JSON; one that starts with https:// is
        fetched on the server (timeout 15 seconds, at most 1 MB, kept for 10 minutes per PowerShell
        runspace); another address scheme (http://, file://) is refused; any other string is a file path.
        The schema must be one JSON object of at most 1 MB and 64 levels. pivotkit-core reads it in the
        browser; nothing in it runs, and only references inside the document are followed.
    .PARAMETER Schema
        The value of -Schema.
    .EXAMPLE
        Get-UDPivotSchemaText -Schema 'https://example.org/openapi.json'
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][object]$Schema)

    $check = @{ Name = '-Schema'; MaxLength = $Script:MaxSchemaLength; MaxDepth = $Script:MaxSchemaDepth }
    if ($Schema -isnot [string]) { return ConvertTo-UDPivotJsonText -InputObject $Schema @check }
    $value = $Schema.Trim()
    if ($value.StartsWith('{')) { return Test-UDPivotJsonText -Text $value @check }
    if ($value -match '^https://') {
        $cached = $Script:SchemaCache[$value]
        if ($cached -and $cached.Time -gt [datetime]::UtcNow.AddMinutes(-$Script:SchemaCacheMinutes)) { return $cached.Text }
        $client = [System.Net.Http.HttpClient]::new()
        try {
            $client.Timeout = [timespan]::FromSeconds($Script:SchemaTimeoutSec)
            # the answer is read into memory only up to this size; a longer one fails
            $client.MaxResponseContentBufferSize = $Script:MaxSchemaLength * 4
            $text = $client.GetStringAsync($value).GetAwaiter().GetResult()
        }
        catch {
            throw ('-Schema: {0} could not be read ({1})' -f $value, $_.Exception.Message)
        }
        finally {
            $client.Dispose()
        }
        $text = Test-UDPivotJsonText -Text $text @check
        $Script:SchemaCache[$value] = @{ Text = $text; Time = [datetime]::UtcNow }
        return $text
    }
    if ($value -match '^[A-Za-z][A-Za-z0-9+.-]+://') { throw ('-Schema: only https:// addresses are fetched, not "{0}".' -f ($value -replace '^([A-Za-z0-9+.-]+://).*', '$1')) }
    $file = Get-Item -LiteralPath $value -ErrorAction Ignore
    if ($file -isnot [System.IO.FileInfo]) { throw ('-Schema: no file "{0}" (expected a hashtable, JSON, an https URL or a file path).' -f $value) }
    # UTF-8 takes up to four bytes per character; a larger file cannot hold an allowed schema
    if ($file.Length -gt $Script:MaxSchemaLength * 4) { throw ('-Schema: "{0}" is larger than {1} bytes.' -f $value, ($Script:MaxSchemaLength * 4)) }
    Test-UDPivotJsonText -Text (Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8) @check
}
