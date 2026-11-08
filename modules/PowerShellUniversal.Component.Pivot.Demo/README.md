# PowerShellUniversal.Component.Pivot.Demo

The showcase app of [PowerShellUniversal.Component.Pivot](https://powershell-universal-components.eize.dev/pivot/)
as a module: install it and an app needs one line.

```powershell
Install-PSResource -Name PowerShellUniversal.Component.Pivot.Demo   # installs the pivot module too
```

App content (admin console > Apps > create, or a script):

```powershell
New-UDPivotShowcase
```

| Page | Data | What it shows |
| --- | --- | --- |
| Python releases, End of life, Release cycles | [endoflife.date](https://endoflife.date/) | The three pivot examples of the documentation: one line; a start view, field names and templates; an app with a loading placeholder, views per reader on the server, roles and a server event |
| Weather | [Open-Meteo](https://open-meteo.com/) | Daily weather of six cities in 2024 and 2025, with questions in the Views menu |
| Your data | an uploaded file | A CSV or JSON file of your own as a pivot report |
| Tickets, Templates, Events, Fields, Layouts, Without Id | generated | The pivot module's ticket showcase: 5,000 tickets from a DataTable, shared and own views, the events, field descriptions from an OpenAPI document, page layouts |

Public data comes from snapshots shipped with the module (`Data/`, with sources and licences in
`Data/SOURCES.md`), so the app works without internet access; the "Live data" switch on those pages,
or `New-UDPivotShowcase -LiveData`, fetches it from the APIs on the PSU server. The language switch
shows the reports in English or German (`-Locale de-DE` to start in German).

Uploaded files are read on the server and deleted at once; their rows stay in the memory of the
reader's session only (CSV with comma, semicolon or tab, JSON as an array of objects; up to 5 MB and
100,000 rows).

The source of the app is [Apps/Showcase.ps1](Apps/Showcase.ps1); the pages on endoflife.date run the
documentation's examples and the ticket pages the pivot module's
[examples/showcase.ps1](../PowerShellUniversal.Component.Pivot/examples/showcase.ps1), so each is
written once.

Documentation: [Pivot showcase app](https://powershell-universal-components.eize.dev/pivot/demo/).
