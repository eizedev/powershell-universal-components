# PowerShellUniversal.Component.Pivot

A pivot report builder for PowerShell Universal apps, on [pivotkit](https://www.npmjs.com/package/pivotkit-react):
readers drag fields from a searchable list into Rows, Columns, Values and Filters and get a table with
totals or a chart. Dates are grouped by month, quarter or year, a click on a value opens the source
rows behind it, readers save their layouts as templates, undo every step and export to Excel, CSV and
PNG. Light and dark theme in PSU's colours, English and German, from a phone to a wide screen.

```powershell
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

or copy the built module folder into `Modules/PowerShellUniversal.Component.Pivot/<version>/` of your
PSU repository. [examples/showcase.ps1](examples/showcase.ps1) is an app with a 5,000-row DataTable,
templates saved per user, a language switch, the events and the report in page layouts.

## Where to read on

| Topic | Page |
| --- | --- |
| What readers can do, data, dates and time zones, language, theme and height | [Overview](https://powershell-universal-components.eize.dev/pivot/) |
| Corporate design from the app's stylesheet, shared with the ECharts module | [Themes and corporate design](https://powershell-universal-components.eize.dev/pivot/themes/) |
| `-View`, `-Templates`, saving templates, `ConvertFrom-UDPivotView` | [Views and templates](https://powershell-universal-components.eize.dev/pivot/views/) |
| `-OnViewChange`, `-OnCellClick`, `-OnSaveTemplate`, `-OnDeleteTemplate`, security | [Events, security and limits](https://powershell-universal-components.eize.dev/pivot/events/) |
| Parameters | [Reference](https://powershell-universal-components.eize.dev/pivot/reference/) |

## Security notes

All rows go to the browser and readers see every column: select the columns a reader may see first.
Views and `$EventData` come from the browser: check views with `ConvertFrom-UDPivotView` before
storing them. Details: [Events, security and limits](https://powershell-universal-components.eize.dev/pivot/events/).

## License

MIT. Includes pivotkit-core and pivotkit-react (MIT), dnd-kit (MIT), the parts of Apache ECharts the
chart uses (Apache-2.0) with ZRender (BSD-3-Clause), fflate (MIT) and tslib (0BSD); their licence texts
are in `THIRD-PARTY-NOTICES.txt` of the built module.
