function Get-UDPivotTemplateFile {
    <#
    .SYNOPSIS
        The view files (*.pivotkit.json) of one or more folders, as templates: Name, View, File.
    .DESCRIPTION
        Used by New-UDPivotReport -TemplatePath and the file template store. Reads the files of each
        folder (not its subfolders) in the order of their names; a file larger than 4 MB (the
        1,000,000 characters of a view file in UTF-8), one that is no view file or a view
        ConvertFrom-UDPivotView refuses is left out with a warning, so one broken file never breaks a
        page. At most -MaxCount templates.
    .PARAMETER Path
        The folders.
    .PARAMETER MaxCount
        The most templates returned. Default: 500.
    .EXAMPLE
        Get-UDPivotTemplateFile -Path (Join-Path $PSScriptRoot 'views')
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)][string[]]$Path, [int]$MaxCount = $Script:MaxTemplates)
    $count = 0
    foreach ($folder in $Path) {
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { continue }
        $files = Get-ChildItem -LiteralPath $folder -Filter '*.pivotkit.json' -File -ErrorAction SilentlyContinue | Sort-Object Name
        foreach ($file in $files) {
            if ($count -ge $MaxCount) {
                Write-Warning ('Pivot templates: more than {0}; the rest of {1} is left out.' -f $MaxCount, $folder)
                return
            }
            if ($file.Length -gt $Script:MaxViewFileLength * 4) {
                Write-Warning ('Pivot template {0} skipped: larger than {1} bytes.' -f $file.Name, ($Script:MaxViewFileLength * 4))
                continue
            }
            try {
                $read = ConvertFrom-UDPivotViewFile -InputObject (Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8) -Name ($file.Name -replace '\.pivotkit\.json$', '')
                $count++
                [pscustomobject]@{ Name = $read.Name; View = $read.View; File = $file.Name; SourceId = if ($read.Source) { $read.Source.id } }
            }
            catch {
                Write-Warning ('Pivot template {0} skipped: {1}' -f $file.Name, $_.Exception.Message)
            }
        }
    }
}
