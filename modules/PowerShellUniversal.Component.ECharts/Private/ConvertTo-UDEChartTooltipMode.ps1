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
