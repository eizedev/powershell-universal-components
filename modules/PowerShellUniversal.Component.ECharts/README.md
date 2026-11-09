# PowerShellUniversal.Component.ECharts

Interactive [Apache ECharts](https://echarts.apache.org/) charts for PowerShell Universal apps. Pass the
data as it comes - a DataTable from SQL, objects from `Invoke-RestMethod` or any PowerShell command -
name the columns, and the chart is drawn in the browser with zoom, tooltips, range selection, click
events, light and dark theme and CSV/Excel export.

```powershell
New-UDEChart -Data (Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 Name, CPU) -Type bar -X Name -Y CPU
```

Requires PowerShell Universal 2026 (PowerShell 7.4+). Tested on PSU 2026.3.4 and 2026.2.5 in Chromium,
Firefox and WebKit (Safari's engine).

**Documentation: [powershell-universal-components.eize.dev](https://powershell-universal-components.eize.dev/echarts/)** - every chart type with
live examples next to their code, and the parameter reference.

## Install

```powershell
Install-PSResource -Name PowerShellUniversal.Component.ECharts
```

In the PowerShell Gallery: [PowerShellUniversal.Component.ECharts](https://www.powershellgallery.com/packages/PowerShellUniversal.Component.ECharts).

or copy the built module folder into `Modules/PowerShellUniversal.Component.ECharts/<version>/` of your
PSU repository. Then use `New-UDEChart` in any app.

## Where to read on

| Topic | Page |
| --- | --- |
| Data: DataTables, objects, wide and long data, `-Aggregate` | [Data](https://powershell-universal-components.eize.dev/echarts/data/) |
| The 29 chart types | [Overview](https://powershell-universal-components.eize.dev/echarts/) and one page per family |
| Click, range selection, linked charts, `$EventData` | [Interaction and events](https://powershell-universal-components.eize.dev/echarts/interaction/) |
| Number and date formats, labels, tooltips | [Formats](https://powershell-universal-components.eize.dev/echarts/formats/), [Labels and tooltips](https://powershell-universal-components.eize.dev/echarts/labels/) |
| Light and dark, corporate themes, `-ColorMap` | [Themes and corporate design](https://powershell-universal-components.eize.dev/echarts/themes/) |
| Size, legend, toolbox, narrow containers | [Layout](https://powershell-universal-components.eize.dev/echarts/layout/) |
| Anything Apache ECharts can do: `-Options` | [Everything else](https://powershell-universal-components.eize.dev/echarts/options/), [gallery mapping](https://powershell-universal-components.eize.dev/echarts/gallery/) |
| Live data | [Live updates](https://powershell-universal-components.eize.dev/echarts/live-updates/) |
| Parameters of every command | [Reference](https://powershell-universal-components.eize.dev/echarts/reference/) |

## Security notes

Everything in `-Data` goes to the browser, also columns the chart does not draw: select the columns
first. `$EventData` comes from the browser: treat it like user input. `-Options`, the templates and the
themes are configuration for the app author, never built from what a user typed. Details:
[Security and limits](https://powershell-universal-components.eize.dev/echarts/security/).

## License

MIT. Includes Apache ECharts (Apache-2.0), ZRender (BSD-3-Clause), fflate (MIT), tslib (0BSD) and PSU's
universal-dashboard helper (ISC); their licence texts are in `THIRD-PARTY-NOTICES.txt` of the built module.
