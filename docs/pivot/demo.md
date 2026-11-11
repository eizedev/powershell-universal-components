---
title: Pivot showcase app
description: "PowerShellUniversal.Component.Pivot.Demo - the showcase app of the pivot module as a module: the documentation's examples on endoflife.date, weather from Open-Meteo, your own CSV, JSON and Excel files and a 5,000-row ticket report, in English and German."
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
| Python releases, End of life, Release cycles | [endoflife.date](https://endoflife.date/) | The three examples of the [overview](index.md): one line; a start view, field names and templates; an app with a loading placeholder, views per reader on the server, roles and `-OnCellClick`. Each page shows its code. |
| Weather | [Open-Meteo](https://open-meteo.com/) | Daily weather of six cities in 2024 and 2025: the mean temperature per month as a colour scale, and questions in the Views menu (the sunniest city, rain days per season, rain per month). |
| Your data | the reader's own file | A CSV, TSV, JSON or Excel file of the reader's own as a pivot report, read in the browser (`-AllowImport`). |
| Tickets, Templates, Events, Fields, Layouts, Without Id | generated | The pivot module's ticket showcase: 5,000 tickets from a DataTable, shared and own views with a file template store, what the events send, field descriptions from an OpenAPI document, the report in page layouts. |

![Weather page of the showcase app in the light theme: mean temperature per city and month as a colour scale](../assets/pivot-showcase-weather-light.png#only-light)
![Weather page of the showcase app in the dark theme: mean temperature per city and month as a colour scale](../assets/pivot-showcase-weather-dark.png#only-dark)

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
