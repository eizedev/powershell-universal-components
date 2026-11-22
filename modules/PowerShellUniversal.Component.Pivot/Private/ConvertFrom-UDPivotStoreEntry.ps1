function ConvertFrom-UDPivotStoreEntry {
    <#
    .SYNOPSIS
        One entry a custom store's Get returned, as a checked view with the places it may be stored.
    .DESCRIPTION
        File is where the view is stored: the FileName Get returns, else the one a save gives it, so a
        save over it replaces it in place. Files is every place it may be stored: without FileName also
        the one version 0.1.0 gave it (a hash of the name in lower case, which "Sales" and "sales"
        share), unless the stored file says this module wrote it from 0.2.0 on, which never uses that
        place: so a view saved now never claims the place of an old one.
    .PARAMETER Entry
        A view file as text, or an object with Json (or itself a view file) and FileName.
    .EXAMPLE
        ConvertFrom-UDPivotStoreEntry -Entry @{ Json = $json; FileName = 'sales.pivotkit.json' }
    .OUTPUTS
        PSCustomObject with Name, View, File, Files and SourceId. Throws on an entry that is no view file.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][object]$Entry)
    $source = if ($Entry -is [string]) { $Entry } else {
        $json = Get-UDPivotEntryValue -InputObject $Entry -Name 'Json'
        if ($json -is [string]) { $json } else { $Entry }
    }
    $read = ConvertFrom-UDPivotViewFile -InputObject $source
    $sourceId = if ($read.Source) { $read.Source.id }
    $stored = if ($Entry -isnot [string]) { Get-UDPivotEntryValue -InputObject $Entry -Name 'FileName' }
    $writtenBy = $read.Generator
    $version = $null
    $current = $writtenBy -and $writtenBy.name -ceq 'PowerShellUniversal.Component.Pivot' -and [version]::TryParse([string]$writtenBy.version, [ref]$version) -and $version -ge [version]'0.2.0'
    $files = @(if ($stored -is [string] -and $stored -match '^[^\\/\p{Cc}]{1,255}$' -and $stored -notin '.', '..') { $stored } else {
            Get-UDPivotViewFileName -Name $read.Name -SourceId $sourceId
            if (-not $current) { Get-UDPivotViewFileName -Name $read.Name -SourceId $sourceId -Legacy }
        }) | Select-Object -Unique
    $files = @($files)
    [pscustomobject]@{ Name = $read.Name; View = $read.View; File = $files[0]; Files = @($files); SourceId = $sourceId }
}
