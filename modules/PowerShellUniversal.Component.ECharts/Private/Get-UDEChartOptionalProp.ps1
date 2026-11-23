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
    $map = [ordered]@{
        X = 'x'; Y = 'y'; GroupBy = 'groupBy'; Value = 'value'; Path = 'path'; Source = 'source'; Target = 'target'
        Open = 'open'; Close = 'close'; Low = 'low'; High = 'high'; Volume = 'volume'; Totals = 'totals'
        Title = 'title'; Subtitle = 'subtitle'; Width = 'width'; ClassName = 'className'; Style = 'style'; Palette = 'palette'; Format = 'format'; LabelFormat = 'labelFormat'; XFormat = 'xFormat'
        Locale = 'locale'; XTitle = 'xTitle'; YTitle = 'yTitle'; SecondaryY = 'secondaryY'; SecondaryTitle = 'secondaryTitle'
        Min = 'min'; Max = 'max'; YMin = 'yMin'; YMax = 'yMax'; Bins = 'bins'; MarkLine = 'markLine'
        NegativeColor = 'negativeColor'; PositiveColor = 'positiveColor'; ExportColumns = 'exportColumns'; EventColumns = 'eventColumns'
        ExportFileName = 'exportFileName'; Group = 'group'; Options = 'options'
        Breaks = 'breaks'; YBreaks = 'yBreaks'; Facet = 'facet'; FacetColumns = 'facetColumns'
        Start = 'start'; End = 'end'; Size = 'size'; Band = 'band'; BandName = 'bandName'; MarkArea = 'markArea'; Thresholds = 'thresholds'; TargetGroup = 'targetGroup'
        Orient = 'orient'; Depth = 'depth'; RootName = 'rootName'; EdgeLabel = 'edgeLabel'; MarkPoint = 'markPoint'; LabelColumn = 'labelColumn'; LabelTemplate = 'labelTemplate'; TooltipColumns = 'tooltipColumns'; TooltipTemplate = 'tooltipTemplate'; Forecast = 'forecast'; TrendTarget = 'trendTarget'; TrendName = 'trendName'
    }
    foreach ($name in $map.Keys) {
        if ($Bound.ContainsKey($name)) { $props[$map[$name]] = $Bound[$name] }
    }
    # choices in lower case, as the browser side takes them
    foreach ($name in 'CellType', 'LegendType', 'Aggregate', 'Layout', 'Trend', 'Legend') {
        if ($Bound.ContainsKey($name)) { $props[$name.Substring(0, 1).ToLowerInvariant() + $name.Substring(1)] = ([string]$Bound[$name]).ToLowerInvariant() }
    }
    if ($Bound['Undirected']) { $props['directed'] = $false }
    foreach ($name in 'LightTheme', 'DarkTheme') {
        if ($Bound.ContainsKey($name)) { $props[$name.Substring(0, 1).ToLowerInvariant() + $name.Substring(1)] = ConvertTo-UDEChartTheme -Theme $Bound[$name] }
    }
    if ($Bound.ContainsKey('TooltipMode')) { $props['tooltipMode'] = ConvertTo-UDEChartTooltipMode -TooltipMode $Bound['TooltipMode'] }
    if ($Bound.ContainsKey('EmptyText')) { $props['emptyText'] = $Bound['EmptyText'] }
    if ($Bound.ContainsKey('ColorMap')) {
        $columns = @{ X = $Bound['X']; GroupBy = $Bound['GroupBy']; Path = $Bound['Path']; Source = $Bound['Source']; Target = $Bound['Target']; TargetGroup = $Bound['TargetGroup'] }
        $props['colorMap'] = ConvertTo-UDEChartColorMap -ColorMap $Bound['ColorMap'] -Data $Data -Column $columns -SeriesName $Bound['Y']
    }
    $props
}
