# Getting started

## Install

From the PowerShell Gallery, on the PSU server:

```powershell
Install-PSResource -Name PowerShellUniversal.Component.ECharts
Install-PSResource -Name PowerShellUniversal.Component.Perspective
Install-PSResource -Name PowerShellUniversal.Component.Pivot
```

In the PowerShell Gallery: [PowerShellUniversal.Component.ECharts](https://www.powershellgallery.com/packages/PowerShellUniversal.Component.ECharts), [PowerShellUniversal.Component.Perspective](https://www.powershellgallery.com/packages/PowerShellUniversal.Component.Perspective), [PowerShellUniversal.Component.Pivot](https://www.powershellgallery.com/packages/PowerShellUniversal.Component.Pivot).

Or copy a built module folder into `Modules/<Module>/<version>/` of your PSU repository (the release
zip on GitHub has that layout). Then use the module's command in any app; PSU loads the component
when a page uses it.

## Update

1. Install the new version of each module you use, the way you installed it:

    ```powershell
    Install-PSResource -Name PowerShellUniversal.Component.Pivot   # repeat for each module
    ```

    `Install-PSResource` puts the new version in a folder of its own, next to the old one. From a release
    zip, copy the new `<version>` folder next to the old one in `Modules/<Module>/`.
2. Restart PSU. PowerShell imports the newest version it finds in the folder, but a process that has
    already imported the module keeps that version.
3. Readers reload their open pages. The bundle's file name holds a hash of its content, so a reload
    fetches the new code.
4. Remove the old version folder once nothing uses it. Installing a new version does not remove it.

What to check:

- **Every module carries its own copy of the code the modules share.** A fix in that code reaches a
  module only with that module's own release. Update every module you use, and read each module's
  `CHANGELOG.md`.
- **Readers' views (Pivot)** live outside the module folder: in the reader's browser, in
  `pivot-views` next to the repository (`New-UDPivotFileTemplateStore`), or in your own storage
  (`New-UDPivotTemplateStore`). A release refuses view files of a newer format than it reads, so
  check before you go back to an older one: [View files](pivot/templates.md#view-files).
- **A published folder for the pivot schema** names the old version folder:
  [Your own copy of the schema](pivot/templates.md#your-own-copy-of-the-schema).

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
New-UDPivotReport -Id 'tickets' -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets') -Locale de-DE
```

With thousands of rows, give it a placeholder that shows the report's frame while the server builds the
data: [Pivot: loading and performance](pivot/index.md#loading-and-performance).

## Try everything

The [showcase app](demo.md) has 14 pages of charts with generated and public data:
`Install-PSResource PowerShellUniversal.Component.ECharts.Demo` ([PowerShell Gallery](https://www.powershellgallery.com/packages/PowerShellUniversal.Component.ECharts.Demo)), then `New-UDEChartShowcase` as an app's
content. The [pivot showcase app](pivot/demo.md) works the same way:
`Install-PSResource PowerShellUniversal.Component.Pivot.Demo` ([PowerShell Gallery](https://www.powershellgallery.com/packages/PowerShellUniversal.Component.Pivot.Demo)), then `New-UDPivotShowcase`.
