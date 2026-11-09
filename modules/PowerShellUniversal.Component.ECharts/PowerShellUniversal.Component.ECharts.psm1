$ErrorActionPreference = 'Stop'

#region Shared code and asset registration
# The build copies the repository's shared/powershell/*.ps1 into Private/; from a source checkout
# they are loaded from there directly.
$private = Join-Path $PSScriptRoot 'Private'
if (-not (Test-Path -LiteralPath $private)) { $private = Join-Path $PSScriptRoot '..' '..' 'shared' 'powershell' }
foreach ($file in Get-ChildItem -LiteralPath $private -Filter '*.ps1' -File) { . $file.FullName }

# the bundle's asset id for the hashtable PSU renders (shared/powershell/Register-PSUComponentAsset.ps1)
$Script:AssetId = Register-PSUComponentAsset -Path $PSScriptRoot
#endregion


function New-UDEChart {
    <#
    .SYNOPSIS
        An interactive Apache ECharts chart for PowerShell Universal apps.

    .DESCRIPTION
        Pass the data as it comes - a DataTable from SQL, objects from Invoke-RestMethod or any
        PowerShell command - name the columns, and the chart is built in the browser. Column names are
        matched without regard to case.

        Zoom (mouse wheel, box), the toolbox (box zoom, line/bar/stack switch, restore, PNG, CSV and
        Excel export), tooltips, hover highlighting and legend toggles are on by default. Light and
        dark follow the app's theme switch. -Options takes any Apache ECharts option
        (https://echarts.apache.org/en/option.html) and is merged over the generated one, so every
        ECharts feature stays reachable: objects merge key by key, arrays element by element, an object
        given for an array (yAxis = @{...}) applies to every element.

        Chart types and the columns they use:
        - line, area, step, bar, scatter: -X (category, date or number), -Y (one or more numbers) or
          -Y with -GroupBy (long data: one series per group value); -SecondaryY on a second axis
        - pie, donut, funnel: -X (name), -Y (value)
        - heatmap: -X, -Y (both categories), -Value
        - calendar: -X (date), -Y or -Value
        - boxplot: -X (group, optional), -Y (values) - quartiles, whiskers and outliers are computed
        - histogram: -Y (values), -Bins - with a median line unless -MarkLine says otherwise
        - candlestick: -X (date), -Open, -Close, -Low, -High, -Volume (optional, own panel)
        - gauge: -Y (value) of the first row, -Min, -Max
        - radar: -X (name per series), -Y (the axes)
        - sankey: -Source, -Target, -Value
        - treemap, sunburst: -Path (columns from the root down, or one column with "a/b/c"), -Y (value)
        - waterfall: -X (step), -Y (change), -Totals (steps that show the running total)
        - gantt: -X (row: server, job, person), -Start, -End, -GroupBy (colour, e.g. status), -Value
          (text in the bar) - maintenance windows, job runs, on-call shifts
        - graph: -Source, -Target, optional -Value, -GroupBy (group of the source node), -TargetGroup
          (group of the target node) - dependency and topology maps; drag, zoom, neighbours on hover
        - tree: -Path (levels, e.g. vCenter, Cluster, Host, VM), -Orient, -Depth - collapsible hierarchy
        - chord: -Source, -Target, -Value - overlaps or hand-overs between the same set of things
        - parallel: -Y (dimensions), -X (name), -GroupBy (colour) - compare many items across many
          measures; drag along an axis to filter
        - themeriver: -X (date), -GroupBy (category), -Y (value) - how a mix changes over time
        - matrix: -Y (rows, e.g. customer), -GroupBy (columns, e.g. KPI), -X (time inside a cell),
          -Value, -CellType - a table of sparklines with one scale per column
        - polar: -X (categories around the circle, e.g. hours), -Y or -GroupBy, -Stacked
        - radialbar: -X (one ring per category), -Y, -Max (the longest ring, three quarters of the circle)
        - bump: -X (period, in the order of the data), -GroupBy (item), -Y (value) - the rank of each
          item per period; equal values rank in the order the items first appear

    .PARAMETER Id
        Component id for Get-UDElement, Set-UDElement, Sync-UDElement and Set-UDEChartData.
    .PARAMETER Data
        Rows: a DataTable or DataView, objects, hashtables, or a script block returning them.
    .PARAMETER Type
        Chart type, see the description.
    .PARAMETER X
        Column for the x axis, the names (pie, funnel, radar) or the dates (calendar, candlestick).
    .PARAMETER Y
        Value column(s). Without -Y, line/bar/area use every numeric column except -X and -GroupBy.
    .PARAMETER GroupBy
        Column whose values become separate series (long data, e.g. one row per day and team).
    .PARAMETER Value
        Value column for heatmap, calendar and sankey.
    .PARAMETER Path
        Hierarchy columns for treemap and sunburst.
    .PARAMETER Source
        Source column for sankey.
    .PARAMETER Target
        Target column for sankey.
    .PARAMETER Open
        Opening price column for candlestick.
    .PARAMETER Close
        Closing price column for candlestick.
    .PARAMETER Low
        Low price column for candlestick.
    .PARAMETER High
        High price column for candlestick.
    .PARAMETER Volume
        Volume column for candlestick (shown in a second panel).
    .PARAMETER Totals
        Waterfall steps (values of -X) that show the running total, e.g. 'Q1', 'Year'.
    .PARAMETER Start
        Start column for gantt.
    .PARAMETER End
        End column for gantt.
    .PARAMETER Size
        Bubble size column for scatter (area grows with the value).
    .PARAMETER Band
        Two columns, lower and upper bound, drawn as a shaded range behind the series (forecast,
        confidence or normal operating range).
    .PARAMETER BandName
        Name of the band in the legend. Default: "<lower> - <upper>".
    .PARAMETER MarkArea
        Shaded ranges: @{ from = '2026-11-03T02:00'; to = '2026-11-03T04:00'; name = 'Maintenance' }
        on the x axis, or with axis = 'y' a value range (e.g. the SLA corridor); color optional.
    .PARAMETER GaugeStyle
        Progress (default, one value), Ring (one ring per row, e.g. availability per service) or Grade
        (arc coloured by -Thresholds, with a needle).
    .PARAMETER Thresholds
        Upper bounds with colours, ascending:
        @{ value = 95; color = '#e53935' }, @{ value = 99; color = '#fb8c00' }, @{ value = 100; color = '#43a047' }
        For -GaugeStyle Grade the bands of the dial; for line and area each stretch of the line in the
        colour of its band (e.g. red above an SLA), above the last bound in the last colour.
    .PARAMETER TargetGroup
        For graph: column naming the group of the target node (colour and legend).
    .PARAMETER Orient
        For tree: LR (default), RL, TB, BT or Radial.
    .PARAMETER Depth
        For tree: levels open at the start (default 2); click a node to open or close it.
    .PARAMETER RootName
        For tree: name of the common root when the data has several top-level values.
    .PARAMETER Layout
        For graph: Force (default; nodes arrange themselves, drag to move), Circular, or Layered (left
        to right along the links, e.g. firewall > core switch > access switch > ESXi > VM).
    .PARAMETER CellType
        For matrix: Line (default), Area or Bar in each cell.
    .PARAMETER EdgeLabel
        For graph: column written on each link, e.g. the ports of a connection ('Gi1/0/12 > vmnic2').
    .PARAMETER Undirected
        For graph: lines without arrows (cabling, peerings).
    .PARAMETER Rose
        Pie and donut as a rose (Nightingale) chart: the radius shows the value.
    .PARAMETER Title
        Title above the chart.
    .PARAMETER Subtitle
        Second line under the title.
    .PARAMETER Height
        CSS height. Default: 400px.
    .PARAMETER Width
        CSS width. Default: 100%.
    .PARAMETER ClassName
        CSS class of the chart's outer element, as on PSU's own components.
    .PARAMETER Style
        CSS styles of the chart's outer element, e.g. @{ marginTop = '8px'; border = '1px solid #ccc' }.
    .PARAMETER Theme
        Auto (follows the app's light/dark switch), Light or Dark.
    .PARAMETER LightTheme
        Corporate design for the light mode: an Apache ECharts theme as a hashtable, or the path of a
        theme JSON file as the ECharts theme builder downloads it ("Download theme", JSON; the builder's
        project file is refused). Merged over the module's own theme: what the theme
        sets wins, the rest stays. For every chart of an app at once:
        $PSDefaultParameterValues['New-UDEChart:LightTheme'] = '/path/on/the/psu/server/corporate-light.json'
    .PARAMETER DarkTheme
        Corporate design for the dark mode, as -LightTheme.
    .PARAMETER Palette
        Series colours, e.g. '#5470c6', '#91cc75'.
    .PARAMETER ColorMap
        A fixed colour per category name, for every chart type: series names (-Y columns, -GroupBy
        values, gantt groups) and data item names (pie and funnel slices, treemap and sunburst nodes,
        sankey and graph nodes). @{ Failed = '#E3000F'; Success = '#287233' }; two colours for light and
        dark mode: @{ Failed = '#E3000F', '#FF6B6B' }. Names match without regard to case; categories
        not in the map keep the palette. Colours are hex, rgb(), rgba(), hsl(), hsla() or CSS names.
    .PARAMETER Legend
        Bottom, Top, Left, Right or None. Default: Bottom when there is more than one series.
    .PARAMETER LegendType
        Scroll (default): one line or column with paging arrows when the entries do not fit. Plain: all
        entries, wrapped over several lines (pie and donut make room for them).
    .PARAMETER Format
        Value format for axis, tooltip and labels: number, number:2, integer, currency, currency:USD,
        percent (0.25 -> 25 %), percent100 (25 -> 25 %), compact, compactcurrency:EUR, bytes, duration (seconds),
        duration:min, duration:h, date, datetime, time, text. Numbers use the browser's locale or -Locale.
    .PARAMETER LabelFormat
        Format for value labels (-DataLabels, pie, waterfall). Default: the short form of -Format
        (currency:EUR -> compactcurrency:EUR, "9,9 Mio. EUR" in de-DE), so long numbers do not overlap.
    .PARAMETER XFormat
        Format for x axis labels, e.g. date.
    .PARAMETER Locale
        Locale for numbers and dates, e.g. de-DE. Default: the browser's language.
    .PARAMETER XTitle
        Name of the x axis.
    .PARAMETER YTitle
        Name of the value axis.
    .PARAMETER SecondaryY
        Columns drawn against a second value axis on the right.
    .PARAMETER SecondaryTitle
        Name of the second value axis.
    .PARAMETER XAxisType
        Auto (dates become a time axis), Category, Time or Value.
    .PARAMETER Min
        Lower bound (gauge, heatmap/calendar colour scale, radar).
    .PARAMETER Max
        Upper bound (gauge, heatmap/calendar colour scale, radar).
    .PARAMETER YMin
        Lower bound of the value axis.
    .PARAMETER YMax
        Upper bound of the value axis.
    .PARAMETER Bins
        Number of histogram bins. Default: from the number of values (Sturges).
    .PARAMETER Aggregate
        Combine rows with the same x (and group): Sum, Avg, Count, Min or Max (line, area, bar, step,
        scatter, pie, donut, funnel, polar, radialbar; bump ranks by Sum by default). Without it the last
        row wins. Count counts rows; the others ignore empty values and leave a gap when there is none.
        On a time axis only rows with exactly the same timestamp combine: round dates first (to the day,
        the hour) to count events per day.
    .PARAMETER EmptyText
        Text shown when -Data has no rows. Default: No data.
    .PARAMETER Stacked
        Stack the series (line, area, bar).
    .PARAMETER Horizontal
        Horizontal bars (bar, boxplot).
    .PARAMETER Normalize
        Stack the series to 100 % per category (shares); the tooltip shows share and original value.
    .PARAMETER Smooth
        Smooth lines.
    .PARAMETER LogScale
        Logarithmic value axis.
    .PARAMETER DataLabels
        Values on bars, points and slices (pie, donut and funnel show them by default).
    .PARAMETER MarkLine
        Reference lines: 'median', 'average', 'min', 'max' (per series) or
        @{ value = 48; name = 'SLA'; color = '#e53935' } (fixed; add axis = 'x' for a vertical line).
    .PARAMETER MarkPoint
        Pins on single values: 'min', 'max', 'average' (per series) or
        @{ x = 'Thu'; y = 306; label = 'Outage'; series = 'Mail' } (one point; without series on the first).
    .PARAMETER LabelColumn
        Show this column of the row behind each point as its label (every chart type).
    .PARAMETER LabelTemplate
        Label text from the row: '{Name} ({Cpu} vCPU, {RamGB:integer} GB)'. A placeholder is a column,
        optionally with a format of -Format ('{Size:bytes}', '{Share:percent100:1}'); a list column is
        joined with commas; `n starts a new line. Points without a row of their own (a tree's folders,
        aggregated nodes) keep their name.
    .PARAMETER TooltipColumns
        Columns of the row shown in the tooltip, one line each, optionally with a format and a label:
        'Cpu', 'RamGB:integer', 'Used:bytes', 'Memory (GB)=RamGB:integer'.
    .PARAMETER TooltipTemplate
        Tooltip text from the row, placeholders as in -LabelTemplate; `n starts a new line. Values are
        HTML-escaped.
    .PARAMETER TooltipMode
        Which items the tooltip covers. Auto (default): the element under the pointer wins - a bar,
        a bar segment or a line point shows that element only (stacked bars: plus the stack total),
        a position on the axis without an element shows all series there (stacked bars: the total
        only). Item: always one element, nothing between them. Axis: all series at the position.
        None: no tooltip. Item and Axis apply to line, area, step and bar; the other chart types keep
        their own tooltip and ignore them. A hashtable sets a mode per chart type, '*' for the rest,
        for every chart of an app at once:
        $PSDefaultParameterValues['New-UDEChart:TooltipMode'] = @{ line = 'Axis'; '*' = 'Auto' }
    .PARAMETER Trend
        Linear: a dashed least-squares trend line per series (line, area, bar, scatter).
    .PARAMETER Forecast
        With -Trend on a time or value axis: continue the trend for this many steps of the data.
    .PARAMETER TrendTarget
        With -Trend: continue the trend until it reaches this value and mark the date (a datastore at
        100 %, a licence limit). Only when that lies ahead and within five times the data's span.
    .PARAMETER TrendName
        Legend name of the trend line. Default: '<series> (trend)'.
    .PARAMETER NegativeColor
        Colour for negative bars (bar, waterfall).
    .PARAMETER PositiveColor
        Colour for rising waterfall steps.
    .PARAMETER Breaks
        Gaps cut out of a time or value x axis: @{ start = ...; end = ...; gap = '1%' }, start and end
        as dates (time axis) or numbers. New-UDEChartTimeBreak builds them for nights and weekends.
        Not possible on category axes.
    .PARAMETER YBreaks
        Gaps cut out of the value axis, e.g. @{ start = 200; end = 5000 } when one bar dwarfs the rest.
    .PARAMETER Facet
        Small multiples: one small chart per value of this column (e.g. one per weekday), all with the
        same value scale (line, area, step, bar, scatter).
    .PARAMETER FacetColumns
        Small multiples per row. Default: up to 4.
    .PARAMETER Sparkline
        A tiny trend without axes, legend and toolbox, for tiles and tables (line, area, bar).
        Use with -Height, e.g. 60px.
    .PARAMETER Zoom
        Auto (default: mouse wheel and drag; plus a slider with a preview of the data on time axes and
        with more than 60 categories), Inside (wheel and drag only), Slider, Both or None.
    .PARAMETER ZoomAxis
        X (default: along the data), Y (the value axis, to look into small values next to large ones)
        or Both. With Both the mouse wheel zooms X, Shift + wheel zooms Y.
    .PARAMETER Brush
        Select a range with the mouse (toolbox button); fires -OnSelect.
    .PARAMETER NoToolbox
        Hide the toolbox.
    .PARAMETER NoExport
        Hide the CSV and Excel buttons.
    .PARAMETER NoFullscreen
        Hide the toolbox button that shows the chart alone on the whole screen (Esc returns). The
        button is hidden anyway where the browser cannot show an element full screen (iPhone Safari).
    .PARAMETER ExportColumns
        Columns of the CSV/Excel export, in order: names, or hashtables
        @{ field = 'leadTime'; title = 'Lead time (h)'; type = 'number'; format = 'number:1' }
        with type text, number, integer, currency, percent, date, datetime or boolean. Default: all
        columns of -Data with their types guessed.
    .PARAMETER EventColumns
        Columns of the data row that events send back to the server ($EventData.row of a click, the rows
        of a parallel selection). Default: the whole row. Keeps messages small with wide rows; it does
        not hide data - everything in -Data is in the browser anyway.
    .PARAMETER ExportFileName
        File name without extension for PNG, CSV and Excel. Default: the title.
    .PARAMETER Group
        Charts with the same group share tooltip, zoom and legend.
    .PARAMETER Decal
        Patterns on top of colours (helps colour-blind readers and black-and-white prints).
    .PARAMETER Renderer
        Canvas (default, fast) or Svg (sharp when printed or scaled).
    .PARAMETER Options
        Any Apache ECharts option, merged over the generated one.
    .PARAMETER OnClick
        Runs when a bar, point or slice is clicked. $EventData: seriesName, seriesIndex, dataIndex,
        name, value, row (the clicked data row, when the chart has fewer than 20000 points).
    .PARAMETER OnSelect
        Runs when a range is selected with -Brush. $EventData: from, to (ISO dates on a time axis,
        category names on a category axis, numbers otherwise). For parallel, after dragging along an
        axis: filtered, count and rows (the data rows of the lines still shown, at most 1000).
    .PARAMETER OnZoom
        Runs after zooming. $EventData: from, to, start, end (percent).
    .PARAMETER OnLegendChange
        Runs when a series is shown or hidden. $EventData: name, selected (map of all series).

    .EXAMPLE
        New-UDEChart -Data (Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, CPU) -Type bar -X Name -Y CPU

        Ten busiest processes as bars.

    .EXAMPLE
        $tickets = Invoke-Sqlcmd -Query 'SELECT Day, Team, Opened FROM dbo.TicketsPerDay' -OutputAs DataTables
        New-UDEChart -Data $tickets -Type line -X Day -Y Opened -GroupBy Team -Zoom Both -Brush -OnSelect {
            Sync-UDElement -Id 'ticket-table'   # reload a table for $EventData.from .. $EventData.to
        }

        One line per team from a DataTable, range selection drives another element.

    .EXAMPLE
        New-UDEChart -Data $leadTimes -Type histogram -Y Hours -Format 'duration:h' -MarkLine 'median', @{ value = 48; name = 'SLA' }

        Distribution of lead times with median and SLA line.

    .EXAMPLE
        New-UDEChart -Data $rows -Type bar -X Month -Y Revenue -Options @{
            yAxis  = @{ splitLine = @{ show = $false } }
            series = @(@{ itemStyle = @{ borderRadius = 4 } })
        }

        Simple parameters plus any ECharts option.

    .OUTPUTS
        System.Collections.Hashtable
    #>
    # describes a chart (or its axis breaks) for PSU to render; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]$Id = [guid]::NewGuid().ToString(),
        [Parameter(Mandatory)][AllowNull()][object]$Data,
        [ValidateSet('line', 'area', 'bar', 'scatter', 'step', 'pie', 'donut', 'funnel', 'heatmap', 'calendar', 'boxplot', 'histogram', 'candlestick', 'gauge', 'radar', 'sankey', 'treemap', 'sunburst', 'waterfall', 'gantt', 'graph', 'tree', 'chord', 'parallel', 'themeriver', 'matrix', 'polar', 'radialbar', 'bump')]
        [string]$Type = 'line',
        [string]$X,
        [string[]]$Y,
        [string]$GroupBy,
        [string]$Value,
        [string[]]$Path,
        [string]$Source,
        [string]$Target,
        [string]$Open,
        [string]$Close,
        [string]$Low,
        [string]$High,
        [string]$Volume,
        [string[]]$Totals,
        [string]$Start,
        [string]$End,
        [string]$Size,
        [ValidateCount(2, 2)][string[]]$Band,
        [string]$BandName,
        [object[]]$MarkArea,
        [ValidateSet('Progress', 'Ring', 'Grade')][string]$GaugeStyle = 'Progress',
        [object[]]$Thresholds,
        [switch]$Rose,
        [string]$TargetGroup,
        [ValidateSet('LR', 'RL', 'TB', 'BT', 'Radial')][string]$Orient,
        [ValidateRange(1, 20)][int]$Depth,
        [string]$RootName,
        [ValidateSet('Force', 'Circular', 'Layered')][string]$Layout,
        [string]$EdgeLabel,
        [ValidateSet('Line', 'Area', 'Bar')][string]$CellType,
        [switch]$Undirected,
        [object[]]$MarkPoint,
        [string]$LabelColumn,
        [string]$LabelTemplate,
        [string[]]$TooltipColumns,
        [string]$TooltipTemplate,
        [ValidateScript({ Test-UDEChartTooltipMode -TooltipMode $_ })][object]$TooltipMode,
        [ValidateSet('Linear')][string]$Trend,
        [ValidateRange(1, 10000)][int]$Forecast,
        [Nullable[double]]$TrendTarget,
        [string]$TrendName,
        [string]$Title,
        [string]$Subtitle,
        [string]$Height = '400px',
        [string]$Width,
        [string]$ClassName,
        [hashtable]$Style,
        [ValidateSet('Auto', 'Light', 'Dark')][string]$Theme = 'Auto',
        [object]$LightTheme,
        [object]$DarkTheme,
        [string[]]$Palette,
        [System.Collections.IDictionary]$ColorMap,
        [ValidateSet('Bottom', 'Top', 'Left', 'Right', 'None')][string]$Legend,
        [ValidateSet('Scroll', 'Plain')][string]$LegendType,
        [ValidatePattern('^(number|integer|currency|compactcurrency|percent|percent100|compact|bytes|duration|date|datetime|time|text)(:[A-Za-z0-9]+)?$')][string]$Format,
        [ValidatePattern('^(number|integer|currency|compactcurrency|percent|percent100|compact|bytes|duration|date|datetime|time|text)(:[A-Za-z0-9]+)?$')][string]$LabelFormat,
        [ValidatePattern('^(number|integer|currency|percent|percent100|compact|bytes|duration|date|datetime|time|text)(:[A-Za-z0-9]+)?$')][string]$XFormat,
        [ValidatePattern('^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$')][string]$Locale,
        [string]$XTitle,
        [string]$YTitle,
        [string[]]$SecondaryY,
        [string]$SecondaryTitle,
        [ValidateSet('Auto', 'Category', 'Time', 'Value')][string]$XAxisType = 'Auto',
        [Nullable[double]]$Min,
        [Nullable[double]]$Max,
        [Nullable[double]]$YMin,
        [Nullable[double]]$YMax,
        [ValidateRange(1, 500)][int]$Bins,
        [ValidateSet('Sum', 'Avg', 'Count', 'Min', 'Max')][string]$Aggregate,
        [string]$EmptyText,
        [switch]$Stacked,
        [switch]$Horizontal,
        [switch]$Normalize,
        [switch]$Smooth,
        [switch]$LogScale,
        [switch]$DataLabels,
        [object[]]$MarkLine,
        [string]$NegativeColor,
        [string]$PositiveColor,
        [object[]]$Breaks,
        [object[]]$YBreaks,
        [string]$Facet,
        [ValidateRange(1, 12)][int]$FacetColumns,
        [switch]$Sparkline,
        [ValidateSet('Auto', 'Inside', 'Slider', 'Both', 'None')][string]$Zoom = 'Auto',
        [ValidateSet('X', 'Y', 'Both')][string]$ZoomAxis = 'X',
        [switch]$Brush,
        [switch]$NoToolbox,
        [switch]$NoExport,
        [switch]$NoFullscreen,
        [object[]]$ExportColumns,
        [string[]]$EventColumns,
        [string]$ExportFileName,
        [string]$Group,
        [switch]$Decal,
        [ValidateSet('Canvas', 'Svg')][string]$Renderer = 'Canvas',
        [hashtable]$Options,
        [Endpoint]$OnClick,
        [Endpoint]$OnSelect,
        [Endpoint]$OnZoom,
        [Endpoint]$OnLegendChange
    )

    if (-not $Script:AssetId) {
        throw 'PowerShellUniversal.Component.ECharts: the JavaScript bundle (index.<hash>.bundle.js) was not found next to the module, or the module was imported outside PowerShell Universal.'
    }
    foreach ($endpoint in $OnClick, $OnSelect, $OnZoom, $OnLegendChange) {
        if ($endpoint) { $endpoint.Register($Id, $PSCmdlet) }
    }

    $props = @{
        assetId   = $Script:AssetId
        isPlugin  = $true
        type      = 'ud-echart'
        id        = $Id
        data      = ConvertTo-PSUComponentData -InputObject $Data
        chartType = $Type
        height    = $Height
        theme     = $Theme.ToLowerInvariant()
        zoom      = $Zoom.ToLowerInvariant()
        renderer  = $Renderer.ToLowerInvariant()
        toolbox   = -not $NoToolbox
        export    = -not $NoExport
        fullscreen = -not $NoFullscreen
        stacked   = [bool]$Stacked
        horizontal = [bool]$Horizontal
        normalize = [bool]$Normalize
        zoomAxis  = $ZoomAxis.ToLowerInvariant()
        smooth    = [bool]$Smooth
        logScale  = [bool]$LogScale
        brush     = [bool]$Brush
        decal     = [bool]$Decal
        sparkline = [bool]$Sparkline
        rose      = [bool]$Rose
        gaugeStyle = $GaugeStyle.ToLowerInvariant()
        xAxisType = $XAxisType.ToLowerInvariant()
    }
    # DataLabels: unset means the chart type's default (pie shows labels, bars do not)
    if ($PSBoundParameters.ContainsKey('DataLabels')) { $props['dataLabels'] = [bool]$DataLabels }
    # only what was given; the browser side has a default for everything else
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
        if ($PSBoundParameters.ContainsKey($name)) { $props[$map[$name]] = $PSBoundParameters[$name] }
    }
    if ($PSBoundParameters.ContainsKey('CellType')) { $props['cellType'] = $CellType.ToLowerInvariant() }
    if ($Undirected) { $props['directed'] = $false }
    foreach ($name in 'LightTheme', 'DarkTheme') {
        if ($PSBoundParameters.ContainsKey($name)) { $props[$name.Substring(0, 1).ToLowerInvariant() + $name.Substring(1)] = ConvertTo-UDEChartTheme -Theme $PSBoundParameters[$name] }
    }
    if ($PSBoundParameters.ContainsKey('TooltipMode')) { $props['tooltipMode'] = ConvertTo-UDEChartTooltipMode -TooltipMode $TooltipMode }
    if ($PSBoundParameters.ContainsKey('LegendType')) { $props['legendType'] = $LegendType.ToLowerInvariant() }
    if ($PSBoundParameters.ContainsKey('Aggregate')) { $props['aggregate'] = $Aggregate.ToLowerInvariant() }
    if ($PSBoundParameters.ContainsKey('EmptyText')) { $props['emptyText'] = $EmptyText }
    if ($PSBoundParameters.ContainsKey('ColorMap')) {
        $columns = @{ X = $X; GroupBy = $GroupBy; Path = $Path; Source = $Source; Target = $Target; TargetGroup = $TargetGroup }
        $props['colorMap'] = ConvertTo-UDEChartColorMap -ColorMap $ColorMap -Data $props['data'] -Column $columns -SeriesName $Y
    }
    # parameters that only one family of chart types reads: say so instead of ignoring them silently
    $onlyFor = @{
        Source = 'sankey', 'graph', 'chord'; Target = 'sankey', 'graph', 'chord'; TargetGroup = 'graph'; Layout = 'graph'; EdgeLabel = 'graph'; Undirected = 'graph'
        Path = 'treemap', 'sunburst', 'tree'; Orient = 'tree'; Depth = 'tree'; RootName = 'tree'
        Open = 'candlestick'; Close = 'candlestick'; Low = 'candlestick'; High = 'candlestick'; Volume = 'candlestick'
        Start = 'gantt'; End = 'gantt'; Bins = 'histogram'; GaugeStyle = 'gauge'; Rose = 'pie', 'donut'; Totals = 'waterfall'; CellType = 'matrix'
    }
    foreach ($name in $onlyFor.Keys) {
        if ($PSBoundParameters.ContainsKey($name) -and $Type -notin $onlyFor[$name]) {
            Write-Warning ('New-UDEChart: -{0} is used by -Type {1} only; -Type {2} ignores it.' -f $name, ($onlyFor[$name] -join ', '), $Type)
        }
    }
    if ($PSBoundParameters.ContainsKey('Layout')) { $props['layout'] = $Layout.ToLowerInvariant() }
    if ($PSBoundParameters.ContainsKey('Trend')) { $props['trend'] = $Trend.ToLowerInvariant() }
    if ($PSBoundParameters.ContainsKey('Legend')) { $props['legend'] = $Legend.ToLowerInvariant() }
    if ($OnClick) { $props['onClick'] = $OnClick }
    if ($OnSelect) { $props['onSelect'] = $OnSelect }
    if ($OnZoom) { $props['onZoom'] = $OnZoom }
    if ($OnLegendChange) { $props['onLegendChange'] = $OnLegendChange }
    $props
}

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

function Test-UDEChartTooltipMode {
    <#
    .SYNOPSIS
        Validates -TooltipMode: a mode name, or a hashtable of chart type (or '*') to mode name.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)][AllowNull()][object]$TooltipMode)

    $modes = 'Auto', 'Item', 'Axis', 'None'
    if ($TooltipMode -is [string]) {
        if ($TooltipMode -in $modes) { return $true }
        throw ('-TooltipMode {0}: use {1}, or a hashtable of chart type to mode.' -f $TooltipMode, ($modes -join ', '))
    }
    if ($TooltipMode -is [System.Collections.IDictionary]) {
        $types = @((Get-Command New-UDEChart).Parameters['Type'].Attributes.ValidValues) + '*'
        foreach ($key in $TooltipMode.Keys) {
            if ([string]$key -notin $types) { throw ('-TooltipMode: {0} is not a chart type. Use one of {1}.' -f $key, ($types -join ', ')) }
            if ([string]$TooltipMode[$key] -notin $modes) { throw ('-TooltipMode {0} = {1}: use {2}.' -f $key, $TooltipMode[$key], ($modes -join ', ')) }
        }
        return $true
    }
    throw '-TooltipMode is a mode name (Auto, Item, Axis, None) or a hashtable of chart type to mode.'
}

function ConvertTo-UDEChartTooltipMode {
    <#
    .SYNOPSIS
        Turns -TooltipMode into what the chart reads: a lower-case mode, or a map of chart type to mode.
    #>
    [CmdletBinding()]
    [OutputType([string], [hashtable])]
    param([Parameter(Mandatory)][object]$TooltipMode)

    if ($TooltipMode -is [System.Collections.IDictionary]) {
        $map = @{}
        foreach ($key in $TooltipMode.Keys) { $map[([string]$key).ToLowerInvariant()] = ([string]$TooltipMode[$key]).ToLowerInvariant() }
        return $map
    }
    ([string]$TooltipMode).ToLowerInvariant()
}

function New-UDEChartTimeBreak {
    <#
    .SYNOPSIS
        Axis breaks that cut nights and/or weekends out of a time axis (intraday charts, business hours).
    .DESCRIPTION
        Returns one break per night (between -DayEnd and the next -DayStart) and, with -Weekends, one per
        weekend, between -From and -To, ready for New-UDEChart -Breaks. Dates are written in ISO 8601 with
        the local offset, like the chart's own data, so the cuts line up with the points.
    .PARAMETER From
        Start of the period.
    .PARAMETER To
        End of the period.
    .PARAMETER DayStart
        Start of the visible part of a day. Default: 08:00.
    .PARAMETER DayEnd
        End of the visible part of a day. Default: 18:00.
    .PARAMETER Weekends
        Also cut out Saturdays and Sundays completely.
    .PARAMETER Gap
        Visual width of each cut, in percent of the axis. Default: 1%.
    .EXAMPLE
        $breaks = New-UDEChartTimeBreak -From (Get-Date).AddDays(-14) -To (Get-Date) -DayStart '07:00' -DayEnd '19:00' -Weekends
        New-UDEChart -Data $samples -Type line -X Time -Y Latency -Breaks $breaks
    .OUTPUTS
        System.Collections.Hashtable
    #>
    # describes a chart (or its axis breaks) for PSU to render; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][datetime]$From,
        [Parameter(Mandatory)][datetime]$To,
        [timespan]$DayStart = '08:00',
        [timespan]$DayEnd = '18:00',
        [switch]$Weekends,
        [ValidatePattern('^\d+(\.\d+)?%$')][string]$Gap = '1%'
    )
    if ($DayEnd -le $DayStart) { throw 'DayEnd must be later than DayStart.' }
    $day = $From.Date
    $cuts = [System.Collections.Generic.List[object]]::new()
    while ($day -le $To.Date) {
        $isWeekend = $Weekends -and $day.DayOfWeek -in 'Saturday', 'Sunday'
        if ($isWeekend) {
            $cuts.Add(@($day, ($day.AddDays(1))))
        }
        else {
            # parentheses: the comma binds tighter than +
            $cuts.Add(@($day, ($day + $DayStart)))
            $cuts.Add(@(($day + $DayEnd), ($day.AddDays(1))))
        }
        $day = $day.AddDays(1)
    }
    # neighbouring cuts (evening + night + next morning, whole weekends) become one break
    $merged = [System.Collections.Generic.List[object]]::new()
    foreach ($c in $cuts) {
        if ($merged.Count -gt 0 -and $merged[$merged.Count - 1][1] -ge $c[0]) { $merged[$merged.Count - 1][1] = $c[1] }
        else { $merged.Add(@($c[0], $c[1])) }
    }
    foreach ($m in $merged) {
        $start = if ($m[0] -lt $From) { $From } else { $m[0] }
        $end = if ($m[1] -gt $To) { $To } else { $m[1] }
        if ($end -gt $start) { @{ start = $start.ToString('o'); end = $end.ToString('o'); gap = $Gap } }
    }
}

function Set-UDEChartData {
    <#
    .SYNOPSIS
        Replaces the data of a chart on the page without redrawing the page (live updates).
    .DESCRIPTION
        Converts the data like New-UDEChart -Data and sends it with Set-UDElement. Zoom and hidden
        series stay as they are. Call it from an endpoint or a timer (New-UDDynamic -AutoRefresh,
        New-UDElement -AutoRefresh) inside the app.
    .PARAMETER Id
        Id of the chart (New-UDEChart -Id).
    .PARAMETER Data
        Rows, as for New-UDEChart.
    .EXAMPLE
        $sample = Get-Counter '\Processor(_Total)\% Processor Time' -MaxSamples 1
        $Cache:Cpu = @($Cache:Cpu) + [pscustomobject]@{ Time = $sample.Timestamp; Load = [math]::Round($sample.CounterSamples[0].CookedValue, 1) } | Select-Object -Last 120
        Set-UDEChartData -Id 'cpu' -Data $Cache:Cpu
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][AllowNull()][object]$Data
    )
    if ($PSCmdlet.ShouldProcess($Id, 'Set chart data')) {
        Set-UDElement -Id $Id -Properties @{ data = ConvertTo-PSUComponentData -InputObject $Data }
    }
}

Export-ModuleMember -Function New-UDEChart, New-UDEChartTimeBreak, Set-UDEChartData
