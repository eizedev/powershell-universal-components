function ConvertTo-UDPivotReportLayout {
    <#
    .SYNOPSIS
        Checks a layout (a view by field names) and returns it as an ordered dictionary of its keys.
    .DESCRIPTION
        Keys: rows, cols (field names), values (@{ field; agg }), groups (@{ field; by; size }), filters
        (as a view writes them), chart (auto, bar, line, area, pie, donut, heatmap, combo, treemap) and map (old name =
        the data's name), as pivotkit's layout flags and the REST service's layout take them. An unknown
        key is an error that names it.
    .PARAMETER Layout
        The layout.
    .EXAMPLE
        ConvertTo-UDPivotReportLayout -Layout @{ rows = 'Team'; values = @{ field = 'Hours'; agg = 'sum' } }
    .OUTPUTS
        System.Collections.Specialized.OrderedDictionary
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Layout)
    $out = [ordered]@{}
    foreach ($key in $Layout.Keys) {
        $name = $Script:LayoutKeys | Where-Object { $_ -eq [string]$key } | Select-Object -First 1
        if (-not $name) { throw ('-Layout: unknown key "{0}"; expected {1}.' -f $key, ($Script:LayoutKeys -join ', ')) }
        $value = $Layout[$key]
        $out[$name] = switch ($name) {
            { $_ -in 'rows', 'cols' } { , [string[]]@($value | ForEach-Object { [string]$_ }) }
            'chart' {
                $type = [string]$value
                if ($type -notin $Script:ChartTypes) { throw ('-Layout: chart "{0}"; expected {1} or {2}.' -f $type, ($Script:ChartTypes[0..($Script:ChartTypes.Count - 2)] -join ', '), $Script:ChartTypes[-1]) }
                $type.ToLowerInvariant()
            }
            'map' {
                if ($value -isnot [System.Collections.IDictionary]) { throw '-Layout: map is a hashtable of a field the layout names and the data''s field: @{ Revenue = ''Turnover'' }.' }
                $map = [ordered]@{}
                foreach ($k in $value.Keys) { $map[[string]$k] = [string]$value[$k] }
                $map
            }
            default {
                $items = @($value | ForEach-Object {
                        if ($_ -isnot [System.Collections.IDictionary] -and $_ -isnot [System.Management.Automation.PSCustomObject]) { throw ('-Layout: {0} is a list of hashtables.' -f $name) }
                        $_
                    })
                , $items
            }
        }
    }
    if (-not $out.Count) { throw '-Layout: empty; give rows, cols or values.' }
    $out
}
