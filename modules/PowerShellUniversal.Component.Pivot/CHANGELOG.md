# Changelog

All notable changes to PowerShellUniversal.Component.Pivot. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

## [0.1.0] - unreleased

### Added

- `New-UDPivotReport` on pivotkit 0.1.0: a field list with search, Rows, Columns, Values and Filters
  with drag and drop and a menu on every field, aggregators and "show values as", date grouping,
  filters with value counts, table or chart (bars, lines, area, pie, heatmap), drill-down to the source
  rows, undo and redo, templates, and Excel, CSV and PNG export.
- Data straight from DataTables, REST results and PowerShell objects with their original column names;
  dates stay dates, `-TimeZone` (default: the server's zone) for dates with an offset.
- `New-UDPivotReportPlaceholder` for `New-UDDynamic -LoadingComponent`: the report's frame in its own
  colours and layout while the server builds the data (reduced motion respected, announced to screen
  readers); it also makes the browser load the module's code at once. The showcase uses it.
- Data conversion without a function call per cell: the showcase's 5000-row DataTable takes about 40 ms
  instead of 2.4 to 2.9 s on the test instance, the table appears after about 0.46 s instead of 2.6 s.
- `-View` (hashtable or JSON), `-Templates`, `-FieldDefaults`, `-Labels`, `-Locale` (English and
  German, default en-US), `-Theme`, `-Height` (default: the window's height), `-FileName`, `-NoDrillDown`.
- `-OnViewChange`, `-OnCellClick`, `-OnSaveTemplate` and `-OnDeleteTemplate`; saving and deleting show
  in the report once the server confirmed them, and a server's refusal shows its message.
- `ConvertFrom-UDPivotView`: checks a view from the browser (size, depth, shape, known keys only) before
  it is stored.
- Light and dark theme in PSU's colours, following the app's switch; a corporate design from the app's
  stylesheet through the ECharts module's `--psu-chart-*` properties and the report's own `--psu-pivot-*`
  ones, per mode.
- The reader's view (fields, table or chart, chart type, collapsed groups) is kept in the browser tab
  per page and `-Id` (without `-Id`: the place of the call in the app script and the columns), so it
  survives PSU building the report anew on its light/dark switch and a reload; `Reset` goes back to `-View`.
- `examples/showcase.ps1`: a 5,000-row DataTable with templates saved per user, a language switch, the
  events and the report in page layouts.
