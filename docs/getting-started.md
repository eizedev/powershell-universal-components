# Getting started

## Install

From the PowerShell Gallery, on the PSU server:

```powershell
Install-PSResource -Name PowerShellUniversal.Component.ECharts
Install-PSResource -Name PowerShellUniversal.Component.Perspective
Install-PSResource -Name PowerShellUniversal.Component.Pivot
```

Or copy a built module folder into `Modules/<Module>/<version>/` of your PSU repository (the release
zip on GitHub has that layout). Then use the module's command in any app; PSU loads the component
when a page uses it.

## A first chart

An app that runs on any PSU server, without a database or an API: the PowerShell commands of the
server per verb, split into cmdlets and functions. A click on a bar shows a toast.

```powershell
New-UDApp -Title 'Commands' -Content {
    New-UDCard -Title 'PowerShell commands per verb' -Content {
        $commands = Get-Command -CommandType Cmdlet, Function | Where-Object Verb
        $top = $commands | Group-Object Verb | Sort-Object Count -Descending | Select-Object -First 10 -ExpandProperty Name
        $rows = $commands | Where-Object Verb -In $top | Group-Object Verb, CommandType | ForEach-Object {
            [pscustomobject]@{ Verb = $_.Group[0].Verb; Type = "$($_.Group[0].CommandType)"; Commands = $_.Count }
        } | Sort-Object { [array]::IndexOf($top, $_.Verb) }   # most commands first
        New-UDEChart -Data $rows -Type bar -X Verb -Y Commands -GroupBy Type -Stacked -Height 360px -OnClick {
            Show-UDToast -Message "$($EventData.name): $($EventData.value) $($EventData.seriesName)s"
        }
    }
}
```

![The quick start app: stacked bars of PowerShell commands per verb, cmdlets and functions](assets/images/screenshot-quickstart-light.png)

The same app is in the repository as
[examples/quickstart.ps1](https://github.com/eizedev/powershell-universal-components/blob/HEAD/modules/PowerShellUniversal.Component.ECharts/examples/quickstart.ps1).

## With your own data

The same call. From SQL Server, for example:

```powershell
$byTeam = Invoke-Sqlcmd -Query 'SELECT Team, Priority, COUNT(*) AS Tickets FROM Tickets GROUP BY Team, Priority'
New-UDEChart -Data $byTeam -Type bar -X Team -Y Tickets -GroupBy Priority -Stacked
```

DataTables, `Invoke-RestMethod` results and PowerShell objects go in as they are; column names are
matched without regard to case. How the data is read: [ECharts: Data](echarts/data.md),
[Perspective](perspective/index.md#data), [Pivot](pivot/index.md#data).

The same rows as a table readers rearrange themselves:

```powershell
New-UDPerspective -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets') -GroupBy Team -SplitBy Priority -Columns Id -Aggregates @{ Id = 'count' }
```

Or as a report builder, where readers drag the fields into rows, columns and values, save their layouts
as templates and export to Excel:

```powershell
New-UDPivotReport -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets') -Locale de-DE
```

## Try everything

The [showcase app](demo.md) has 14 pages of charts with generated and public data:
`Install-PSResource PowerShellUniversal.Component.ECharts.Demo`, then `New-UDEChartShowcase` as an app's
content.
