function New-UDEChartShowcase {
    <#
    .SYNOPSIS
        Returns the showcase app of PowerShellUniversal.Component.ECharts.
    .DESCRIPTION
        The app has fourteen pages: basics, every bar variant, a ticket report, finance, managed
        services, operations and SLA, a data platform that combines many source systems, calendars,
        intraday charts, public data, layouts, technical examples, live data and a benchmark. Data is
        generated with a fixed seed; the page "Public data" needs internet access from the PSU server.
        Use it as the whole content of an app:
            Import-Module PowerShellUniversal.Component.ECharts.Demo
            New-UDEChartShowcase
    .EXAMPLE
        New-PSUApp -Name 'EChartsShowcase' -BaseUrl '/echarts' -Content { New-UDEChartShowcase }
    .OUTPUTS
        The app PSU renders (New-UDApp).
    #>
    [CmdletBinding()]
    param()

    & (Join-Path $PSScriptRoot 'Apps' 'Showcase.ps1')
}

Export-ModuleMember -Function New-UDEChartShowcase
