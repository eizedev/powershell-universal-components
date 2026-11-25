---
title: ECharts showcase app
description: "PowerShellUniversal.Component.ECharts.Demo - the showcase app of the ECharts module as a module: 14 pages of New-UDEChart examples with generated and public data."
---

# ECharts showcase app

`PowerShellUniversal.Component.ECharts.Demo` is the showcase app of the [ECharts module](echarts/index.md)
as a module: install it and an app needs one line. The pivot module has one of its own, the
[pivot showcase app](pivot/demo.md); the Perspective module has example apps in its
[folder](https://github.com/eizedev/powershell-universal-components/tree/HEAD/modules/PowerShellUniversal.Component.Perspective/examples).

```powershell
Install-PSResource -Name PowerShellUniversal.Component.ECharts.Demo   # installs the chart module too
```

In the PowerShell Gallery: [PowerShellUniversal.Component.ECharts.Demo](https://www.powershellgallery.com/packages/PowerShellUniversal.Component.ECharts.Demo).

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

![Data platform page of the showcase app in the light theme: coverage heatmap of source systems per asset class, and assets per number of sources](assets/images/screenshot-data-platform-light.png#only-light)
![Data platform page of the showcase app in the dark theme: coverage heatmap of source systems per asset class, and assets per number of sources](assets/images/screenshot-data-platform-dark.png#only-dark)

![Ticket report page in the light theme: SLA gauge, opened per day against the previous period, lead time histogram, boxplot per team](assets/images/screenshot-ticket-report-light.png#only-light)
![Ticket report page in the dark theme: SLA gauge, opened per day against the previous period, lead time histogram, boxplot per team](assets/images/screenshot-ticket-report-dark.png#only-dark)

![Managed services page in the light theme: service review, a KPI matrix of sparklines per customer](assets/images/screenshot-service-review-light.png#only-light)
![Managed services page in the dark theme: service review, a KPI matrix of sparklines per customer](assets/images/screenshot-service-review-dark.png#only-dark)

## Before you share the app

The app has no sign-in, and two pages read the PSU server:

- **Technical** shows the server's twelve largest processes with their names and process ids, and
  the size of each folder of the PSU program folder. It reads both on every page view.
- **Public data** calls five public web services from the server. The app keeps each answer for an hour. It
  tries a failed call again on the next view, and each try can take up to 45 seconds.

Protect the app before people outside your network can reach it, for example with a role in PSU.

The source of the app is
[Apps/Showcase.ps1](https://github.com/eizedev/powershell-universal-components/blob/HEAD/modules/PowerShellUniversal.Component.ECharts.Demo/Apps/Showcase.ps1);
copy parts of it into your own apps.

## Reference

--8<-- "reference/New-UDEChartShowcase.md"
