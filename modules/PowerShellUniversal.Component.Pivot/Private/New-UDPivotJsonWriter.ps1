function New-UDPivotJsonWriter {
    <#
    .SYNOPSIS
        A UTF-8 JSON writer on a stream, compact, with non-ASCII text as it is.
    .DESCRIPTION
        The relaxed encoder leaves letters with accents as they are instead of \u escapes: the JSON goes to
        pivotkit (a request body, a data file), never into an HTML page.
    .PARAMETER Stream
        The stream to write to.
    .EXAMPLE
        $writer = New-UDPivotJsonWriter -Stream $memory
    .OUTPUTS
        System.Text.Json.Utf8JsonWriter
    #>
    # Creates a writer object in memory; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([System.Text.Json.Utf8JsonWriter])]
    param([Parameter(Mandatory)][System.IO.Stream]$Stream)
    $options = [System.Text.Json.JsonWriterOptions]::new()
    $options.Encoder = [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping
    [System.Text.Json.Utf8JsonWriter]::new($Stream, $options)
}
