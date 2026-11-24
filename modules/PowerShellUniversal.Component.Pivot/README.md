# PowerShellUniversal.Component.Pivot

A pivot report builder for PowerShell Universal apps, on [pivotkit](https://github.com/eizedev/pivotkit).
Readers drag fields into Rows, Columns, Values and Filters and get a table with totals or a chart.

- Dates grouped by month, quarter or year; a click on a value shows the rows behind it.
- Views kept in the browser, in files or your own store; roles decide who publishes shared views.
- Export to Excel, CSV, PNG, SVG and HTML, and print. `-ExportData` adds the source rows as a download.
- `-AllowImport`: readers pivot a CSV, JSON or Excel file of their own, read in the browser, never uploaded.
- `Invoke-UDPivotReport` renders the same views into files from endpoints and schedules.
- Light and dark theme in PSU's colours, English and German, from a phone to a wide screen.

```powershell
New-UDPivotReport -Id 'python' -Data (Invoke-RestMethod 'https://endoflife.date/api/python.json')
New-UDPivotReport -Id 'tickets' -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets') -Locale de-DE
New-UDPivotReport -Id 'own-data' -Data @() -AllowImport -TemplateStore Browser   # the reader's own file
```

Supported and tested versions: [Requirements](https://powershell-universal-components.eize.dev/#requirements).

**Documentation: [powershell-universal-components.eize.dev](https://powershell-universal-components.eize.dev/pivot/)** - data and dates, views and
templates, events, security notes, with live examples.

## Install

```powershell
Install-PSResource -Name PowerShellUniversal.Component.Pivot
```

In the PowerShell Gallery: [PowerShellUniversal.Component.Pivot](https://www.powershellgallery.com/packages/PowerShellUniversal.Component.Pivot).

or copy the built module folder into `Modules/PowerShellUniversal.Component.Pivot/<version>/` of your
PSU repository. To update, see
[Update](https://powershell-universal-components.eize.dev/getting-started/#update).

[examples/showcase.ps1](examples/showcase.ps1) is an app with a 5,000-row DataTable,
shipped views and a template store, a language switch, the events and the report in page layouts;
[examples/templates.ps1](examples/templates.ps1) an app with sign-in where readers keep their views on
the server and admins publish shared ones. The module
[PowerShellUniversal.Component.Pivot.Demo](https://powershell-universal-components.eize.dev/pivot/demo/)
is a showcase app in one line (`New-UDPivotShowcase`).

## Where to read on

- [Overview](https://powershell-universal-components.eize.dev/pivot/): three examples on public data, what readers can do, data, dates, language, theme and height
- [Field names and descriptions](https://powershell-universal-components.eize.dev/pivot/fields/): `-FieldDefaults`, `-FieldDescriptions`, SQL Server column descriptions, `-Schema`
- [Views](https://powershell-universal-components.eize.dev/pivot/views/): `-View`, `-SavedView`, filters, tabs, the address bar, links from pivotkit
- [Templates, view files and roles](https://powershell-universal-components.eize.dev/pivot/templates/): `-Templates`, `-TemplateStore`, `-AdminRole`
- [Readers' own files](https://powershell-universal-components.eize.dev/pivot/import/): `-AllowImport`, `-OnDataLoad`, `-ImportLimit`
- [Events, security and limits](https://powershell-universal-components.eize.dev/pivot/events/): the `-On...` events
- [Reports without a browser](https://powershell-universal-components.eize.dev/pivot/reports/): `Invoke-UDPivotReport`, `Get-UDPivotSource`
- [Themes and corporate design](https://powershell-universal-components.eize.dev/pivot/themes/), shared with the ECharts module
- [Reference](https://powershell-universal-components.eize.dev/pivot/reference/): every parameter

## Security notes

All rows go to the browser and readers see every column: select the columns a reader may see first.
Views and `$EventData` come from the browser: check views with `ConvertFrom-UDPivotView` before
storing them; the template stores do that themselves and check `-AdminRole` on the server. A file a
reader loads with `-AllowImport` stays in the browser; only `-OnDataLoad` sends its name and column names. Details: [Events, security and limits](https://powershell-universal-components.eize.dev/pivot/events/).

## License

MIT. The bundle includes libraries under their own licences: pivotkit-core, pivotkit-react, pivotkit-report
and pivotkit-xlsx (MIT), read-excel-file (MIT), dnd-kit (MIT), the parts of Apache ECharts the chart uses
(Apache-2.0) with ZRender (BSD-3-Clause), fflate (MIT), tslib (0BSD) and PSU's universal-dashboard helper
(ISC). Their licence texts are in `THIRD-PARTY-NOTICES.txt` of the built module.
