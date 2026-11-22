function Write-UDPivotDataFile {
    <#
    .SYNOPSIS
        Writes rows straight into a JSON file, { columns, rows }, as pivotkit's JSON reader takes them.
    .PARAMETER Path
        The file to write.
    .PARAMETER Data
        The rows (objects, a DataTable or DataRows).
    .EXAMPLE
        Write-UDPivotDataFile -Path (Join-Path $work 'data.json') -Data $rows
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param([Parameter(Mandatory)][string]$Path, [AllowNull()][object]$Data)
    $file = [System.IO.File]::Create($Path)
    try {
        $writer = New-UDPivotJsonWriter -Stream $file
        $writer.WriteStartObject()
        Write-UDPivotReportTable -Writer $writer -Data $Data
        $writer.WriteEndObject()
        $writer.Flush()
        $writer.Dispose()
    }
    finally { $file.Dispose() }
}
