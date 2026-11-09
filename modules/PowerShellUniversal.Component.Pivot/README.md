# PowerShellUniversal.Component.Pivot

A pivot report builder for PowerShell Universal apps, on [pivotkit](https://www.npmjs.com/package/pivotkit-react):
readers drag fields from a searchable list into Rows, Columns, Values and Filters and get a table with
totals or a chart. Dates are grouped by month, quarter or year, a click on a value opens the source
rows behind it, readers keep their layouts as views (in the browser, in files or a database of your
choice; roles decide who publishes shared views), undo every step and export to Excel, CSV and PNG. Fields get display names and descriptions from your script, SQL Server column descriptions or an
OpenAPI schema. Light and dark theme in PSU's colours, English and German, from a phone to a wide screen.

```powershell
New-UDPivotReport -Id 'python' -Data (Invoke-RestMethod 'https://endoflife.date/api/python.json')
New-UDPivotReport -Id 'tickets' -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets') -Locale de-DE
```

Requires PowerShell Universal 2026 (PowerShell 7.4+). Tested on PSU 2026.3.4 and 2026.2.5 in Chromium,
Firefox and WebKit (Safari's engine).

**Documentation: [powershell-universal-components.eize.dev](https://powershell-universal-components.eize.dev/pivot/)** - data and dates, views and
templates, events, security notes, with live examples.

## Install

```powershell
Install-PSResource -Name PowerShellUniversal.Component.Pivot
```

In the PowerShell Gallery: [PowerShellUniversal.Component.Pivot](https://www.powershellgallery.com/packages/PowerShellUniversal.Component.Pivot).

or copy the built module folder into `Modules/PowerShellUniversal.Component.Pivot/<version>/` of your
PSU repository. [examples/showcase.ps1](examples/showcase.ps1) is an app with a 5,000-row DataTable,
shipped views and a template store, a language switch, the events and the report in page layouts;
[examples/templates.ps1](examples/templates.ps1) an app with sign-in where readers keep their views on
the server and admins publish shared ones. The module
[PowerShellUniversal.Component.Pivot.Demo](https://powershell-universal-components.eize.dev/pivot/demo/)
is a showcase app in one line (`New-UDPivotShowcase`).

## Where to read on

| Topic | Page |
| --- | --- |
| Three examples on public data (one line; start view, field names and templates; an app with loading, views per reader and roles), what readers can do, data, dates and time zones, language, theme and height, the placeholder while the data loads, performance | [Overview](https://powershell-universal-components.eize.dev/pivot/) |
| Corporate design from the app's stylesheet, shared with the ECharts module | [Themes and corporate design](https://powershell-universal-components.eize.dev/pivot/themes/) |
| `-FieldDefaults`, `-FieldDescriptions`, SQL Server column descriptions (`Get-UDPivotSqlColumnDescription`), `-Schema` (JSON Schema, OpenAPI) | [Field names and descriptions](https://powershell-universal-components.eize.dev/pivot/fields/) |
| `-View`, `-SavedView`, several tabs, the address bar | [Views](https://powershell-universal-components.eize.dev/pivot/views/) |
| `-Templates`, `-TemplatePath`, view files, `-TemplateStore` (browser, files, your own storage), `-AdminRole` and the admin panel | [Templates, view files and roles](https://powershell-universal-components.eize.dev/pivot/templates/) |
| `-OnViewChange`, `-OnCellClick`, `-OnSaveTemplate`, `-OnDeleteTemplate`, `-OnPublishTemplate`, security | [Events, security and limits](https://powershell-universal-components.eize.dev/pivot/events/) |
| Parameters | [Reference](https://powershell-universal-components.eize.dev/pivot/reference/) |

## Security notes

All rows go to the browser and readers see every column: select the columns a reader may see first.
Views and `$EventData` come from the browser: check views with `ConvertFrom-UDPivotView` before
storing them; the template stores do that themselves and check `-AdminRole` on the server. Details: [Events, security and limits](https://powershell-universal-components.eize.dev/pivot/events/).

## License

MIT. Includes pivotkit-core and pivotkit-react (MIT), dnd-kit (MIT), the parts of Apache ECharts the
chart uses (Apache-2.0) with ZRender (BSD-3-Clause), fflate (MIT) and tslib (0BSD); their licence texts
are in `THIRD-PARTY-NOTICES.txt` of the built module.
