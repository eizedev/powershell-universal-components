# Security and limits

## Security notes

- Everything in `-Data` is sent to the browser - every column, also those the chart does not draw - and
  is what CSV/Excel export offers by default. Select the columns first (`Select-Object`) when a source
  holds more than the viewer may see.
- `$EventData` comes from the browser (the clicked row, a selected range, rows of a parallel
  selection). Treat it like any user input: look the record up again on the server before acting on
  it, never pass it to a query or command unchecked. A parallel selection sends at most 1000 rows; a
  click sends the one row. `-EventColumns Name, Id` limits those rows to the columns the script block
  needs.
- `-Options`, `-MarkLine`, `-MarkArea`, `-Thresholds`, the templates and `-LightTheme`/`-DarkTheme`
  are configuration for the app author; do not build them from what a user typed.
- A theme path is read on the PSU server on every render, and its content goes to every viewer.
- Values from the data are HTML-escaped in tooltips.
- In CSV export, text starting with `=`, `+`, `-`, `@`, a tab or a carriage return gets a leading `'` so spreadsheets do not run
  it as a formula; Excel export writes text cells, which are never evaluated.

## Limits

- Apache ECharts draws a chart on a canvas. The keyboard reaches none of its points, tooltips or
  toolbox buttons (zoom, export, full screen), and a tooltip needs a pointer. Screen readers get
  ECharts' generated description of the chart (`role="img"`). Keyboard users reach the data only
  through what the app shows beside the chart, such as a table.
- PSU provides React 18.3.1; the module does not bundle React.
- Above 20,000 points per chart, points are drawn with sampling (LTTB) and click events carry values
  but no row.
