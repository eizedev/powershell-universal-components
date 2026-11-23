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
