# PowerShellUniversal.Component.Pivot.Demo

The showcase app of [PowerShellUniversal.Component.Pivot](https://powershell-universal-components.eize.dev/pivot/)
as a module: install it and an app needs one line.

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
| Python releases, End of life, Release cycles | [endoflife.date](https://endoflife.date/) | The three pivot examples of the documentation: one line; a start view, field names and templates; an app with a loading placeholder, views per reader on the server, roles and a server event |
| Weather | [Open-Meteo](https://open-meteo.com/) | Daily weather of six cities in 2024 and 2025, with questions in the Views menu |
| Your data | your own file | A CSV, TSV, JSON or Excel file of your own as a pivot report, read in the browser |
| Tickets, Templates, Events, Fields, Layouts, Without Id | generated | The pivot module's ticket showcase: 5,000 tickets from a DataTable, shared and own views, the events, field descriptions from an OpenAPI document, page layouts |

Public data comes from snapshots shipped with the module (`Data/`, with sources and licences in
`Data/SOURCES.md`), so the app works without internet access; the "Live data" switch on those pages,
or `New-UDPivotShowcase -LiveData`, fetches it from the APIs on the PSU server. The language switch
shows the reports in English or German (`-Locale de-DE` to start in German). The offline snapshot is
the default: the switch calls Open-Meteo's free API, whose terms allow non-commercial use only, so a
company that uses the demo internally keeps the snapshot or uses an Open-Meteo API key.

Your data reads the reader's file in the browser (`New-UDPivotReport -AllowImport`): it is never
uploaded, the server does not see it, and after a reload it is gone. Views of a file are kept in the
reader's browser, per file.

Views stored on the server: the page Release cycles and the ticket pages use
`New-UDPivotFileTemplateStore`, which keeps views as files in a folder `pivot-views` next to the PSU
repository folder: the own views of signed-in readers (`users/`) and the shared views readers with the
role Administrator publish (`shared/`). Without sign-in, readers' own views stay in their browser. To
remove what the app stored, delete that folder on the server, e.g.
`Remove-Item -Recurse -Force (Join-Path (Split-Path -Parent $Repository) 'pivot-views')`; other apps
with a file template store without `-Path` use the same folder.

The source of the app is [Apps/Showcase.ps1](Apps/Showcase.ps1); the pages on endoflife.date run the
documentation's examples and the ticket pages the pivot module's
[examples/showcase.ps1](../PowerShellUniversal.Component.Pivot/examples/showcase.ps1), so each is
written once.

Documentation: [Pivot showcase app](https://powershell-universal-components.eize.dev/pivot/demo/).
