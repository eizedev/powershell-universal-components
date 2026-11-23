function ConvertTo-UDEChartColorMap {
    <#
    .SYNOPSIS
        Turns -ColorMap into the list the chart reads ({ name, light, dark }), checks the colours and
        warns about names that are no category of the data.
    .DESCRIPTION
        A list instead of the hashtable itself: PSU's serializer camelCases dictionary keys, which would
        change the category names. Categories are the -Y names and the values of the columns that
        -X, -GroupBy, -Path, -Source, -Target and -TargetGroup name.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$ColorMap,
        [object[]]$Data,
        [hashtable]$Column = @{},
        [string[]]$SeriesName
    )
    # colour strings only, the same rule as in the browser (Components/colormap.js)
    $colorPattern = '^(#[0-9a-fA-F]{3,8}|(rgb|rgba|hsl|hsla)\([0-9.,%\s/]+\)|[a-zA-Z]+)$'
    $known = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $SeriesName) { if ($name) { [void]$known.Add($name) } }
    $wanted = @($Column.Values | ForEach-Object { $_ } | Where-Object { $_ })
    foreach ($row in $Data) {
        if ($null -eq $row) { continue }
        $pairs = if ($row -is [System.Collections.IDictionary]) { $row.GetEnumerator() | ForEach-Object { [pscustomobject]@{ Name = [string]$_.Key; Value = $_.Value } } } else { $row.PSObject.Properties }
        foreach ($p in $pairs) {
            if ($p.Name -in $wanted -and $null -ne $p.Value -and "$($p.Value)" -ne '') { [void]$known.Add("$($p.Value)") }
        }
    }
    $out = foreach ($key in $ColorMap.Keys) {
        $colors = @($ColorMap[$key])
        if ($colors.Count -lt 1 -or $colors.Count -gt 2 -or @($colors | Where-Object { $_ -isnot [string] -or $_.Trim() -notmatch $colorPattern }).Count) {
            throw "New-UDEChart: -ColorMap '$key' needs one colour or two (light, dark), e.g. '#E3000F' or '#E3000F', '#FF6B6B'."
        }
        [pscustomobject]@{ name = [string]$key; light = $colors[0].Trim(); dark = $colors[-1].Trim() }
    }
    $unknown = @($ColorMap.Keys | Where-Object { -not $known.Contains([string]$_) })
    if ($unknown.Count -and $known.Count) {
        $list = @($known | Sort-Object | Select-Object -First 20)
        $more = if ($known.Count -gt 20) { ', ...' } else { '' }
        Write-Warning ('New-UDEChart: -ColorMap names {0}, which no category of the data has. Categories: {1}{2}' -f ($unknown -join ', '), ($list -join ', '), $more)
    }
    , @($out)
}
