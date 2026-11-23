function New-UDEChartProp {
    <#
    .SYNOPSIS
        The props every chart of New-UDEChart has: the component, its id and data, the chart type and
        the settings with a default.
    .DESCRIPTION
        The parameters with a default are passed on their own: $PSBoundParameters holds only what the
        caller gave. Switches are read from -Bound; a switch not given is $false.
    .PARAMETER Bound
        New-UDEChart's $PSBoundParameters.
    .PARAMETER Data
        New-UDEChart's -Data, converted here with ConvertTo-PSUComponentData.
    .EXAMPLE
        $props = New-UDEChartProp -Bound $PSBoundParameters -Data $Data -Id $Id -Type $Type -Height $Height -Theme $Theme -Zoom $Zoom -ZoomAxis $ZoomAxis -Renderer $Renderer -GaugeStyle $GaugeStyle -XAxisType $XAxisType
    .OUTPUTS
        System.Collections.Hashtable
    #>
    # builds a hashtable; changes no state, so no ShouldProcess
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Bound,
        [AllowNull()][object]$Data,
        [string]$Id,
        [string]$Type,
        [string]$Height,
        [string]$Theme,
        [string]$Zoom,
        [string]$ZoomAxis,
        [string]$Renderer,
        [string]$GaugeStyle,
        [string]$XAxisType
    )
    @{
        assetId    = $Script:AssetId
        isPlugin   = $true
        type       = 'ud-echart'
        id         = $Id
        data       = ConvertTo-PSUComponentData -InputObject $Data
        chartType  = $Type
        height     = $Height
        theme      = $Theme.ToLowerInvariant()
        zoom       = $Zoom.ToLowerInvariant()
        renderer   = $Renderer.ToLowerInvariant()
        toolbox    = -not $Bound['NoToolbox']
        export     = -not $Bound['NoExport']
        fullscreen = -not $Bound['NoFullscreen']
        stacked    = [bool]$Bound['Stacked']
        horizontal = [bool]$Bound['Horizontal']
        normalize  = [bool]$Bound['Normalize']
        zoomAxis   = $ZoomAxis.ToLowerInvariant()
        smooth     = [bool]$Bound['Smooth']
        logScale   = [bool]$Bound['LogScale']
        brush      = [bool]$Bound['Brush']
        decal      = [bool]$Bound['Decal']
        sparkline  = [bool]$Bound['Sparkline']
        rose       = [bool]$Bound['Rose']
        gaugeStyle = $GaugeStyle.ToLowerInvariant()
        xAxisType  = $XAxisType.ToLowerInvariant()
    }
}
