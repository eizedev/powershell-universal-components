function Write-UDEChartTypeWarning {
    <#
    .SYNOPSIS
        Warns about each parameter of New-UDEChart that only another family of chart types reads.
    .DESCRIPTION
        Says so instead of ignoring the parameter silently. The warning goes to the caller's warning
        stream, so -WarningAction and -WarningVariable of New-UDEChart apply.
    .PARAMETER Bound
        New-UDEChart's $PSBoundParameters.
    .PARAMETER Type
        New-UDEChart's -Type.
    .EXAMPLE
        Write-UDEChartTypeWarning -Bound $PSBoundParameters -Type $Type
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Bound, [Parameter(Mandatory)][string]$Type)
    $onlyFor = @{
        Source = 'sankey', 'graph', 'chord'; Target = 'sankey', 'graph', 'chord'; TargetGroup = 'graph'; Layout = 'graph'; EdgeLabel = 'graph'; Undirected = 'graph'
        Path = 'treemap', 'sunburst', 'tree'; Orient = 'tree'; Depth = 'tree'; RootName = 'tree'
        Open = 'candlestick'; Close = 'candlestick'; Low = 'candlestick'; High = 'candlestick'; Volume = 'candlestick'
        Start = 'gantt'; End = 'gantt'; Bins = 'histogram'; GaugeStyle = 'gauge'; Rose = 'pie', 'donut'; Totals = 'waterfall'; CellType = 'matrix'
    }
    foreach ($name in $onlyFor.Keys) {
        if ($Bound.ContainsKey($name) -and $Type -notin $onlyFor[$name]) {
            Write-Warning ('New-UDEChart: -{0} is used by -Type {1} only; -Type {2} ignores it.' -f $name, ($onlyFor[$name] -join ', '), $Type)
        }
    }
}
