# PowerShellUniversal.Component.Perspective

[Perspective](https://perspective-dev.github.io/) for PowerShell Universal apps: a datagrid, pivot
table and chart in one. Readers group, split, filter, sort and aggregate the data themselves in the
configuration panel and switch between the grid and the charts; the parameters set the view it starts
with. The data is held by Perspective's WebAssembly engine in a Web Worker in the browser, so tens of
thousands of rows stay fast.

```powershell
New-UDPerspective -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets') -GroupBy Team -SplitBy Priority -Columns Id -Aggregates @{ Id = 'count' }
```

Requires PowerShell Universal 2026 (PowerShell 7.4+). Tested on PSU 2026.3.4 and 2026.2.5 in Chromium, Firefox and
WebKit (Safari's engine).

**Documentation: [powershell-universal-components.eize.dev](https://powershell-universal-components.eize.dev/perspective/)** - data and types, the
starting view, events, security notes, with live examples.

## Install

```powershell
Install-PSResource -Name PowerShellUniversal.Component.Perspective
```

or copy the built module folder into `Modules/PowerShellUniversal.Component.Perspective/<version>/` of
your PSU repository.

## Where to read on

| Topic | Page |
| --- | --- |
| Data, column types, size and limits | [Overview and data](https://powershell-universal-components.eize.dev/perspective/) |
| `-GroupBy`, `-SplitBy`, `-Columns`, `-Filter`, `-Sort`, `-Plugin`, `-Config` | [The starting view](https://powershell-universal-components.eize.dev/perspective/view/) |
| `-OnClick`, map plugins and their tiles, security | [Events, security and limits](https://powershell-universal-components.eize.dev/perspective/events/) |
| Parameters | [Reference](https://powershell-universal-components.eize.dev/perspective/reference/) |

## Security notes

All rows go to the browser: select the columns a reader may see first. The map plugins of the
configuration panel load base map tiles from OpenStreetMap or VersaTiles when a reader picks one.
`$EventData` comes from the browser: treat it like user input. Details:
[Events, security and limits](https://powershell-universal-components.eize.dev/perspective/events/).

## License

MIT. Includes Perspective 5.7 (`@perspective-dev/*`, Apache-2.0) with regular-table (Apache-2.0); the
other runtime packages are under MIT, ISC and, for two small helpers of Perspective's WebAssembly
packaging (`buffer-pipe`, `leb128`), MPL-2.0. Their licence texts are in `THIRD-PARTY-NOTICES.txt` of the
built module.
