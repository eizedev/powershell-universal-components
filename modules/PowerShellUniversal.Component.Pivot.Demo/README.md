# PowerShellUniversal.Component.Pivot.Demo

The showcase app of [PowerShellUniversal.Component.Pivot](https://powershell-universal-components.eize.dev/pivot/)
as a module: install it and an app needs one line.

```powershell
Install-PSResource -Name PowerShellUniversal.Component.Pivot.Demo   # installs the pivot module too
```

In the PowerShell Gallery: [PowerShellUniversal.Component.Pivot.Demo](https://www.powershellgallery.com/packages/PowerShellUniversal.Component.Pivot.Demo).
To update, see [Update](https://powershell-universal-components.eize.dev/getting-started/#update).

App content (admin console > Apps > create, or a script):

```powershell
New-UDPivotShowcase
```

Pages:

- Weather from [Open-Meteo](https://open-meteo.com/): the table and the chart side by side.
- Python releases, End of life, and Release cycles from [endoflife.date](https://endoflife.date/): the
  three pivot examples of the documentation.
- Your data: a CSV, TSV, JSON or Excel file of the reader's own, read in the browser.
- Report as a file: the reader's view as an Excel workbook or an HTML report, made on the server.
- Rows from a server: a pivotkit-server source for the signed-in person.
- Tickets, Templates, Charts, Events, Fields, Layouts, and Without Id: the pivot module's ticket
  showcase with 5,000 generated tickets.

The public data comes from snapshots shipped with the module, so the app works without internet
access. The Live data switch calls Open-Meteo's free API, whose terms allow non-commercial use only:
inside a company, keep the snapshot or use an Open-Meteo API key.

Two pages need more on the PSU server: Report as a file needs pivotkit's command line, and Rows from
a server needs a pivotkit-server and a sign-in. Each download from Report as a file runs Node on the PSU
server, and the app has no sign-in: protect it before people outside your network can reach it. The
app stores views in a folder next to the PSU repository. Read the
[documentation](https://powershell-universal-components.eize.dev/pivot/demo/) before you share the app.

The source of the app is [Apps/Showcase.ps1](Apps/Showcase.ps1).

Documentation: [Pivot showcase app](https://powershell-universal-components.eize.dev/pivot/demo/).
