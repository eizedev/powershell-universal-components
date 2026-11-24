function Get-UDEChartOptionalProp {
    <#
    .SYNOPSIS
        The props of New-UDEChart's parameters without a default: only those the caller gave.
    .DESCRIPTION
        The browser side has a default for everything else. Most values go as they are, under their
        camelCase name; choices go in lower case; themes, tooltip modes and the colour map are
        converted first.
    .PARAMETER Bound
        New-UDEChart's $PSBoundParameters.
    .PARAMETER Data
        The converted rows (the data prop), which -ColorMap is checked against.
    .EXAMPLE
        $props += Get-UDEChartOptionalProp -Bound $PSBoundParameters -Data $props['data']
    .OUTPUTS
        System.Collections.Hashtable: the props to add.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Bound, [AllowNull()][object]$Data)
    $props = @{}
    # DataLabels: unset means the chart type's default (pie shows labels, bars do not)
    if ($Bound.ContainsKey('DataLabels')) { $props['dataLabels'] = [bool]$Bound['DataLabels'] }
    # the prop's name is the parameter's in camelCase, as PSU would send it
    $camelCase = { param([string]$Name) $Name.Substring(0, 1).ToLowerInvariant() + $Name.Substring(1) }
    # values that go as they are
    $asGiven = @(
        'X', 'Y', 'GroupBy', 'Value', 'Path', 'Source', 'Target', 'Open', 'Close', 'Low', 'High', 'Volume',
        'Totals', 'Title', 'Subtitle', 'Width', 'ClassName', 'Style', 'Palette', 'Format', 'LabelFormat',
        'XFormat', 'Locale', 'XTitle', 'YTitle', 'SecondaryY', 'SecondaryTitle', 'Min', 'Max', 'YMin',
        'YMax', 'Bins', 'MarkLine', 'NegativeColor', 'PositiveColor', 'ExportColumns', 'EventColumns',
        'ExportFileName', 'Group', 'Options', 'Breaks', 'YBreaks', 'Facet', 'FacetColumns', 'Start', 'End',
        'Size', 'Band', 'BandName', 'MarkArea', 'Thresholds', 'TargetGroup', 'Orient', 'Depth', 'RootName',
        'EdgeLabel', 'MarkPoint', 'LabelColumn', 'LabelTemplate', 'TooltipColumns', 'TooltipTemplate',
        'Forecast', 'TrendTarget', 'TrendName'
    )
    foreach ($name in $asGiven) {
        if ($Bound.ContainsKey($name)) { $props[(& $camelCase $name)] = $Bound[$name] }
    }
    # choices in lower case, as the browser side takes them
    foreach ($name in 'CellType', 'LegendType', 'Aggregate', 'Layout', 'Trend', 'Legend') {
        if ($Bound.ContainsKey($name)) { $props[(& $camelCase $name)] = ([string]$Bound[$name]).ToLowerInvariant() }
    }
    if ($Bound['Undirected']) { $props['directed'] = $false }
    foreach ($name in 'LightTheme', 'DarkTheme') {
        if ($Bound.ContainsKey($name)) { $props[(& $camelCase $name)] = ConvertTo-UDEChartTheme -Theme $Bound[$name] }
    }
    if ($Bound.ContainsKey('TooltipMode')) { $props['tooltipMode'] = ConvertTo-UDEChartTooltipMode -TooltipMode $Bound['TooltipMode'] }
    if ($Bound.ContainsKey('EmptyText')) { $props['emptyText'] = $Bound['EmptyText'] }
    if ($Bound.ContainsKey('ColorMap')) {
        $columns = @{ X = $Bound['X']; GroupBy = $Bound['GroupBy']; Path = $Bound['Path']; Source = $Bound['Source']; Target = $Bound['Target']; TargetGroup = $Bound['TargetGroup'] }
        $props['colorMap'] = ConvertTo-UDEChartColorMap -ColorMap $Bound['ColorMap'] -Data $Data -Column $columns -SeriesName $Bound['Y']
    }
    $props
}
