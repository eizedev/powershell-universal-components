function New-UDPivotRenderBody {
    <#
    .SYNOPSIS
        The input of pivotkit-server's render_view as UTF-8 JSON, the rows written straight into it.
    .DESCRIPTION
        source, then data (columns, rows, rowCount, name, asOf) or params, then view or layout, format,
        title, locale, numbers and flatHeader. The rows go through Write-UDPivotReportTable: no copy of
        them as objects or as one JSON string, and past -MaxBytes it stops with PivotDataTooLarge before
        the rest is converted.
    .PARAMETER Data
        The rows, or $null with -Source.
    .PARAMETER Source
        A source the operator configured, instead of -Data.
    .PARAMETER Parameter
        The source's parameters.
    .PARAMETER View
        The view (an object), or $null with -Layout.
    .PARAMETER Layout
        The layout, or $null with -View.
    .PARAMETER Format
        The format.
    .PARAMETER Title
        The report's title.
    .PARAMETER DataName
        What the data is.
    .PARAMETER DataAsOf
        When the data is from.
    .PARAMETER Locale
        The report's language and number format, for a view that names none.
    .PARAMETER Numbers
        csv and json: Shown or Full, sent in lower case.
    .PARAMETER FlatHeader
        csv: one header row.
    .PARAMETER MaxBytes
        The most bytes of the body; 0 for no cap.
    .PARAMETER Save
        Adds save: true, for /views/render (the file route refuses save).
    .EXAMPLE
        New-UDPivotRenderBody -Data $rows -View $view -Format csv -MaxBytes 10MB
    .OUTPUTS
        System.Byte[]
    #>
    # Builds a request body in memory; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [AllowNull()][object]$Data,
        [string]$Source,
        [System.Collections.IDictionary]$Parameter,
        [AllowNull()][object]$View,
        [AllowNull()][System.Collections.IDictionary]$Layout,
        [Parameter(Mandatory)][string]$Format,
        [string]$Title,
        [string]$DataName,
        [Nullable[datetime]]$DataAsOf,
        [string]$Locale,
        [string]$Numbers,
        [switch]$FlatHeader,
        [long]$MaxBytes = 0,
        [switch]$Save
    )
    $memory = [System.IO.MemoryStream]::new()
    $writer = New-UDPivotJsonWriter -Stream $memory
    try {
        $writer.WriteStartObject()
        if ($Source) { $writer.WriteString('source', $Source) }
        else {
            $writer.WriteString('source', 'inline:')
            $writer.WriteStartObject('data')
            Write-UDPivotReportTable -Writer $writer -Data $Data -MaxBytes $MaxBytes -RowCount
            if ($DataName) { $writer.WriteString('name', $DataName) }
            if ($DataAsOf) { $writer.WriteString('asOf', ([datetime]$DataAsOf).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture)) }
            $writer.WriteEndObject()
        }
        if ($Parameter) { $writer.WritePropertyName('params'); $writer.WriteRawValue((ConvertTo-Json -InputObject $Parameter -Depth 4 -Compress)) }
        # the view and the layout are small and checked already: their JSON goes in as it is
        if ($null -ne $View) { $writer.WritePropertyName('view'); $writer.WriteRawValue((ConvertTo-Json -InputObject $View -Depth 32 -Compress -WarningAction SilentlyContinue)) }
        else { $writer.WritePropertyName('layout'); $writer.WriteRawValue((ConvertTo-Json -InputObject $Layout -Depth 32 -Compress -WarningAction SilentlyContinue)) }
        $writer.WriteString('format', $Format)
        if ($Title) { $writer.WriteString('title', $Title) }
        # left out unless given: the server's defaults, and a server older than 0.3.0 still renders
        if ($Locale) { $writer.WriteString('locale', $Locale) }
        if ($Numbers) { $writer.WriteString('numbers', $Numbers.ToLowerInvariant()) }
        if ($FlatHeader) { $writer.WriteBoolean('flatHeader', $true) }
        if ($Save) { $writer.WriteBoolean('save', $true) }
        $writer.WriteEndObject()
        $writer.Flush()
        , $memory.ToArray()
    }
    finally {
        $writer.Dispose()
        $memory.Dispose()
    }
}
