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
