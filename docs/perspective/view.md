# The starting view

| Parameter | Effect |
| --- | --- |
| `-Plugin` | `Datagrid` (default); charts (WebGL): `X Bar`, `Y Bar`, `Y Line`, `Y Area`, `Y Scatter`, `X/Y Scatter`, `X/Y Line`, `Density`, `Treemap`, `Sunburst`, `Heatmap`, `Candlestick`, `OHLC`, `Map Scatter`, `Map Line`, `Map Density` (maps need longitude and latitude columns) |
| `-Columns` | columns to show, in order |
| `-GroupBy`, `-SplitBy` | pivot rows and columns |
| `-Aggregates` | `@{ Tickets = 'sum'; LeadHours = 'avg' }` (Perspective's names: sum, avg, count, distinct count, min, max, median, first, last, ...) |
| `-Sort` | `'Created desc'`, `'Team'` |
| `-Filter` | `'Status == Open'`, `'LeadHours > 48'`, `'Team contains Net'` |
| `-Settings` | open the configuration panel at the start |
| `-ChartPlugin` | the chart of the toolbar's Chart button until the reader picks one: `Y Bar` (default) or any chart of `-Plugin` |
| `-Labels` | the toolbar's words in another language: `@{ EditView = 'Ansicht bearbeiten'; Table = 'Tabelle'; Chart = 'Diagramm' }` |
| `-NoToolbar` | no toolbar above the viewer (see [Using the viewer](using.md)) |
| `-Config` | Perspective's full viewer configuration (the viewer's "copy" button gives it), merged over the parameters |

Column names in these parameters are matched without regard to case; names with spaces work
(`'Lead Hours > 48'`). Filter values take the column's type (`'Code == 007'` stays text in a text
column, a number column takes only numbers, a boolean column `true`/`false`); `in` and `not in` take a
comma-separated list (values themselves cannot contain a comma). A name that matches no column, a value
of the wrong type or a malformed `-Sort`/`-Filter` entry is reported above the grid and left out; names
of expression columns from `-Config` count as columns.

## Pivot: tickets per team and priority

--8<-- "examples/pivot-tickets-per-team-and-priority.md"

## Perspective chart: open tickets per team

--8<-- "examples/perspective-chart-open-tickets-per-team.md"

## Theme and layout

Light and dark follow the app's switch (Perspective's "Pro Light" and "Pro Dark"); `-Theme Light` or
`Dark` pins one. `-Height` (default `480px`), `-Width`, `-Id`, `-ClassName` and `-Style` as on PSU's own
components. Number formats follow Perspective (thousands separators also on id columns); adjust them
in the configuration panel or through `-Config`.
