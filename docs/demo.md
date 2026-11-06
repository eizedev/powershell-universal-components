# Demo: the showcase app

`PowerShellUniversal.Component.ECharts.Demo` is the showcase app of the chart module as a module:
install it and an app needs one line.

```powershell
Install-PSResource -Name PowerShellUniversal.Component.ECharts.Demo   # installs the chart module too
```

App content (admin console > Apps > create, or a script):

```powershell
New-UDEChartShowcase
```

Fourteen pages: basics, every bar variant, a ticket report (lead time with SLA, boxplots, previous
period, filters on a table), finance (waterfall, plan versus actual, candlestick), managed services
(KPI matrix, VMware, storage, backup, customer ranking), operations (backup gantt, forecasts,
dependencies), a data platform that combines many source systems (coverage, gaps, network path,
asset 360), calendars, intraday charts with axis breaks, public data, layouts, technical examples,
live data and a benchmark. All data is generated with a fixed seed; "Public data" calls public web
APIs from the PSU server.

![Ticket report page: SLA gauge, opened per day against the previous period, lead time histogram, boxplot per team](assets/images/screenshot-ticket-report-dark.png)

![Service review page: KPI matrix of sparklines per customer](assets/images/screenshot-service-review-light.png)

The source of the app is
[Apps/Showcase.ps1](https://github.com/eizedev/powershell-universal-components/blob/HEAD/modules/PowerShellUniversal.Component.ECharts.Demo/Apps/Showcase.ps1);
copy parts of it into your own apps.

## Reference

--8<-- "reference/New-UDEChartShowcase.md"
