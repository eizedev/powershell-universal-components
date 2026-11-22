---
title: Pivot showcase app
description: "PowerShellUniversal.Component.Pivot.Demo - the showcase app of the pivot module as a module: weather from Open-Meteo, the documentation's examples on endoflife.date, your own CSV, JSON and Excel files, the report as an Excel or HTML file, rows from a pivotkit-server and a 5,000-row ticket report, in English and German."
---

# Pivot showcase app

`PowerShellUniversal.Component.Pivot.Demo` is the showcase app of the [pivot module](index.md) as a
module: install it and an app needs one line.

```powershell
Install-PSResource -Name PowerShellUniversal.Component.Pivot.Demo   # installs the pivot module too
```

In the PowerShell Gallery: [PowerShellUniversal.Component.Pivot.Demo](https://www.powershellgallery.com/packages/PowerShellUniversal.Component.Pivot.Demo).

App content (admin console > Apps > create, or a script):

```powershell
New-UDPivotShowcase
```

| Page | Data | What it shows |
| --- | --- | --- |
| Weather (the first page) | [Open-Meteo](https://open-meteo.com/) | Daily weather of six cities in 2024 and 2025. The start view shows the table and the chart side by side (**Both**): the mean temperature per month as a colour scale and as lines, with each city's warmest and coldest month marked. The Views menu has more questions: the warmest city in July (sorted by one column), the sunniest city, rain and sunshine as bars and lines with field names of the report's own, rain days per season, rain per month. |
| Python releases, End of life, Release cycles | [endoflife.date](https://endoflife.date/) | The three examples of the [overview](index.md): one line; a start view, field names and templates; an app with a loading placeholder, views per reader on the server, roles and `-OnCellClick`. Each page shows its code. |
| Your data | the reader's own file | A CSV, TSV, JSON or Excel file of the reader's own as a pivot report, read in the browser (`-AllowImport`). |
| Report as a file | Open-Meteo | The reader's view as an Excel workbook or an HTML report, made on the server with `Invoke-UDPivotReport` ([Report as a file](#report-as-a-file)). |
| Rows from a server | a pivotkit-server | A pivotkit-server source for the signed-in person (`New-UDPivotReport -Uri -Source -Token`). Without a server, the page says what it needs ([Rows from a server](#rows-from-a-server)). |
| Tickets, Templates, Charts, Events, Fields, Layouts, Without Id | generated | The pivot module's ticket showcase: 5,000 tickets from a DataTable, shared and own views with a file template store, charts (the menu on a bar, a treemap, a donut with its slice "Other"), what the events send and the view `Get-UDElement` reads, field descriptions from an OpenAPI document, the report in page layouts. |

![Weather page of the showcase app in the light theme: mean temperature per month and city as a colour scale, next to a line chart with the warmest and coldest month marked](../assets/pivot-showcase-weather-light.png#only-light)
![Weather page of the showcase app in the dark theme: mean temperature per month and city as a colour scale, next to a line chart with the warmest and coldest month marked](../assets/pivot-showcase-weather-dark.png#only-dark)

<small>Weather data by [Open-Meteo.com](https://open-meteo.com/), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); contains modified Copernicus Climate Change Service information 2026; neither the European Commission nor ECMWF is responsible for any use that may be made of the Copernicus information or data it contains ([sources and licences](https://github.com/eizedev/powershell-universal-components/blob/HEAD/docs/site/data/SOURCES.md)).</small>

## Public data, offline or live

The pages on endoflife.date and Open-Meteo read snapshots shipped with the module (`Data/`, the same
files this site is built from, with their sources, licences and the attribution each source asks for in
`Data/SOURCES.md`), so the app works on a PSU server without internet access. The **Live data** switch
on those pages fetches the same addresses from the APIs instead; `New-UDPivotShowcase -LiveData`
starts with it switched on. The offline snapshot is the default: the switch calls Open-Meteo's free API, whose terms allow non-commercial use only, so a company that uses the demo internally keeps the snapshot or uses an Open-Meteo API key (`Data/SOURCES.md`).

The **Language** switch shows the reports in English or German (`-Locale de-DE` starts in German).
Both switches are kept per session.

## Your own data

![Your data in the light theme: a CSV file loaded into the report, with its columns in the field list and "only in this browser" under the table](../assets/pivot-showcase-upload-light.png#only-light)
![Your data in the dark theme: a CSV file loaded into the report, with its columns in the field list and "only in this browser" under the table](../assets/pivot-showcase-upload-dark.png#only-dark)

The page "Your data" is a report without data of its own and with `-AllowImport`: the reader drops a
CSV, TSV, JSON or Excel file (`.xlsx`) onto it, or picks one under **Data**, **Load data…**, checks
the preview with a type per column (and the sheet of a workbook) and loads it. The file is read in the
browser and never uploaded; after a reload it is gone. Readers save their views in their browser
(`-TemplateStore Browser`), per file: the same file loaded again offers them, another file does not.
See [Readers' own files](import.md).

## Report as a file

![Report as a file in the light theme: the buttons Excel workbook and HTML report above a report of rain days per city and season](../assets/pivot-showcase-report-file-light.png#only-light)
![Report as a file in the dark theme: the buttons Excel workbook and HTML report above a report of rain days per city and season](../assets/pivot-showcase-report-file-dark.png#only-dark)

The page "Report as a file" has a report of the weather rows and two buttons, **Download Excel
workbook** and **Download HTML report**. A button makes the file of the view the reader has on the page, on the PSU server,
with `Invoke-UDPivotReport -Engine Node`, and the browser downloads it. A schedule can make the same file
every Monday and mail it ([Reports without a browser](reports.md)).

- The page keeps the reader's view with `-OnViewChange` in `$Session`; the button reads it from there.
  The report keeps its view out of the address bar (`-NoAddressBar`), so a link never shows a view
  the server does not know.
- The buttons need pivotkit's command line on the PSU server: Node 24 or later and
  `npm install --global pivotkit-cli`. `New-UDPivotShowcase -PivotkitPath` names the program when it
  is not on the PATH.
- Without it, the page says what to install, and the buttons are off. The report still works.
- Each click runs Node on the PSU server. The app has no sign-in: protect it before people outside
  your network can reach it.
- PSU 2026.2 has no `Start-UDDownload -Bytes`. There the file waits in the folder
  `pivot-showcase-downloads` of the server's temporary folder; a later click removes files older than
  10 minutes.

## Rows from a server

The page "Rows from a server" shows a pivotkit-server source for the signed-in person
([Rows from a server](server-rows.md)). It needs the server's address and the source:

```powershell
New-UDPivotShowcase -ServerUri 'https://reports.example.com/api/v1' -ServerSource 'orders'
```

- PSU's OpenID Connect sign-in with `Authentication__OIDC__SaveTokens=true`, so the page has the
  person's token (`$AccessToken`).
- pivotkit-server 0.4.0 or later. The person's profile names the source under `records`.
- Without `-ServerUri`, the page says what it needs and shows no report. Without a token (no sign-in,
  or tokens not saved), it says that the page needs a sign-in and sends nothing to the server.

## Views stored on the server

The page Release cycles and the ticket pages keep views with `New-UDPivotFileTemplateStore` (see
[Templates, view files and roles](templates.md)): as files in a folder `pivot-views` next to the PSU
repository folder, never inside it. `users/` holds the own views of signed-in readers, `shared/` the
shared views readers with the role Administrator publish. Without sign-in, readers' own views stay in
their browser and nothing is written for them. To remove what the app stored, delete that folder on the
server:

```powershell
Remove-Item -Recurse -Force (Join-Path (Split-Path -Parent $Repository) 'pivot-views')
```

Other apps with a file template store without `-Path` use the same folder; check before deleting it.

## Open a view from pivotkit

Every page of the app opens views from pivotkit links. The Weather page's report has the `-Id`
`weather`: a pivotkit-server source with the id `weather`, `"link": "https://<your PSU>/<app base
URL>/weather"` and `"linkKey": "weather"` makes `create_link` return links that open on that page,
over the app's rows. The view's fields must be columns of those rows
([Links from pivotkit](views.md#links-from-pivotkit-create_link)).

## How it is built

The source of the app is
[Apps/Showcase.ps1](https://github.com/eizedev/powershell-universal-components/blob/HEAD/modules/PowerShellUniversal.Component.Pivot.Demo/Apps/Showcase.ps1).
Nothing in it is written twice: the pages on endoflife.date run the examples of this site
(`docs/site/examples.ps1`), the ticket pages are the pivot module's
[examples/showcase.ps1](https://github.com/eizedev/powershell-universal-components/blob/HEAD/modules/PowerShellUniversal.Component.Pivot/examples/showcase.ps1),
and the module's `Build.psd1` names the files the build copies into it. The examples call
`Invoke-RestMethod`; in the app the call goes to `Get-UDPivotShowcaseData`, which answers from the
snapshot or, with live data, from the API.

## Reference

### New-UDPivotShowcase

--8<-- "reference/New-UDPivotShowcase.md"

### Get-UDPivotShowcaseData

--8<-- "reference/Get-UDPivotShowcaseData.md"
