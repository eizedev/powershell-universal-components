# PowerShellUniversal.Component.Perspective

[FINOS Perspective](https://perspective.finos.org/) for PowerShell Universal apps: a datagrid, pivot
table and chart in one. Readers group, split, filter, sort and aggregate the data themselves in the
configuration panel and switch between the grid and the charts; the parameters set the view it starts
with. The data is held by Perspective's WebAssembly engine in a Web Worker in the browser, so tens of
thousands of rows stay fast.

```powershell
New-UDPerspective -Data (Invoke-Sqlcmd -Query 'SELECT * FROM Tickets') -GroupBy Team -SplitBy Priority -Columns Id -Aggregates @{ Id = 'count' }
```

Requires PowerShell Universal 2026 (PowerShell 7.4+). Tested on PSU 2026.3.4 and 2026.2.5 in Chromium, Firefox and
WebKit (Safari's engine).

## Install

```powershell
Install-PSResource -Name PowerShellUniversal.Component.Perspective
```

or copy the built module folder into `Modules/PowerShellUniversal.Component.Perspective/<version>/` of
your PSU repository.

## Data

`-Data` takes a DataTable, DataRows, PSCustomObjects, hashtables or a script block, like the other
modules of this repository. Column names keep their PowerShell spelling in the grid. Every column gets
a type from its values: ISO dates and times become dates (sortable and filterable as dates), whole
numbers integers, other numbers floats, `$true`/`$false` booleans, everything else text.

## The starting view

| Parameter | Effect |
| --- | --- |
| `-Plugin` | `Datagrid` (default), `X Bar`, `Y Bar`, `Y Line`, `Y Area`, `Y Scatter`, `XY Scatter`, `Treemap`, `Sunburst`, `Heatmap` |
| `-Columns` | columns to show, in order |
| `-GroupBy`, `-SplitBy` | pivot rows and columns |
| `-Aggregates` | `@{ Tickets = 'sum'; LeadHours = 'avg' }` (Perspective's names: sum, avg, count, distinct count, min, max, median, first, last, ...) |
| `-Sort` | `'Created desc'`, `'Team'` |
| `-Filter` | `'Status == Open'`, `'LeadHours > 48'`, `'Team contains Net'` |
| `-Settings` | open the configuration panel at the start |
| `-Config` | Perspective's full viewer configuration (the viewer's "copy" button gives it), merged over the parameters |

Column names in these parameters are matched without regard to case.

## Events

`-OnClick` runs on the server when a cell is clicked; `$EventData.row` holds the values of the clicked
row (or of the group in a pivot), `$EventData.filter` the group and split values that lead to the cell
as `[column, operator, value]`.

```powershell
New-UDPerspective -Data $tickets -OnClick { Show-UDToast -Message "Ticket $($EventData.row.Id)" }
```

## Theme and layout

Light and dark follow the app's switch (Perspective's "Pro Light" and "Pro Dark"); `-Theme Light` or
`Dark` pins one. `-Height` (default `480px`), `-Width`, `-Id`, `-ClassName` and `-Style` as on PSU's own
components.

## Size and limits

- The bundle is about 8 MB: it carries Perspective's WebAssembly, so it works without internet access.
  The browser downloads it once and caches it; PSU runs it for every Perspective component on a page,
  and only the first run sets the engine up, the others share it (one Web Worker per page).
- All rows go to the browser (see the security notes of the ECharts module; select columns first).
- Number formats follow Perspective (thousands separators also on id columns); adjust them in the
  configuration panel or through `-Config`.

## Example

[examples/smoke.ps1](examples/smoke.ps1): 5000 generated tickets as a datagrid, a pivot (team x
priority) and a chart.

## License

MIT. Includes FINOS Perspective (Apache-2.0) and its dependencies; their licence texts are in
`THIRD-PARTY-NOTICES.txt` of the built module.
