function Get-UDPivotTypeSource {
    <#
    .SYNOPSIS
        The C# source of a type the module compiles on first use, and the type's name.
    .DESCRIPTION
        Reads a .cs file whose class is named <Class>_SUFFIX and replaces SUFFIX with the first 16 hex
        digits of the file's SHA-256. Two versions of the module in one process then compile two types
        instead of finding the other version's type by its name.
    .PARAMETER Path
        The .cs file.
    .PARAMETER TypeName
        The type's name without the suffix: namespace and class, e.g. PivotReportTable.Writer.
    .EXAMPLE
        $writer = Get-UDPivotTypeSource -Path (Join-Path $PSScriptRoot 'ReportWriter.cs') -TypeName 'PivotReportTable.Writer'
    .OUTPUTS
        PSCustomObject with Source (the C# text) and Type (the full type name).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$TypeName
    )
    $text = [System.IO.File]::ReadAllText($Path)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($text)) } finally { $sha.Dispose() }
    $class = '{0}_{1}' -f ($TypeName -split '\.')[-1], (-join ($hash[0..7] | ForEach-Object { $_.ToString('x2') }))
    [pscustomobject]@{
        Source = $text.Replace(('{0}_SUFFIX' -f ($TypeName -split '\.')[-1]), $class)
        Type   = '{0}.{1}' -f ($TypeName -replace '\.[^.]+$'), $class
    }
}
