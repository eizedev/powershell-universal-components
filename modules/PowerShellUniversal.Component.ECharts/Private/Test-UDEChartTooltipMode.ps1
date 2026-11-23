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
