function ConvertTo-UDEChartTheme {
    <#
    .SYNOPSIS
        Turns a theme parameter (hashtable, object or JSON file path) into the theme object the chart uses.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][AllowNull()][object]$Theme)

    if ($null -eq $Theme) { return $null }
    if ($Theme -is [string]) {
        if (-not (Test-Path -LiteralPath $Theme -PathType Leaf)) { throw ('Theme file not found: {0}' -f $Theme) }
        $Theme = Get-Content -LiteralPath $Theme -Raw | ConvertFrom-Json -AsHashtable
    }
    elseif ($Theme -is [System.Management.Automation.PSCustomObject]) {
        $Theme = $Theme | ConvertTo-Json -Depth 30 | ConvertFrom-Json -AsHashtable
    }
    if ($Theme -isnot [System.Collections.IDictionary]) { throw 'A theme is a hashtable, an object or the path of a theme JSON file.' }
    # the theme builder's project file ("Export config", *.project.json) holds the builder's own
    # settings, not an ECharts theme (apache/echarts-theme-builder, src/stores/theme.ts)
    if ($Theme.Contains('themeName') -and $Theme.Contains('version') -and $Theme.Contains('theme')) {
        throw 'This is an ECharts theme builder project file. Use "Download theme" in the builder and choose JSON.'
    }
    $Theme
}
