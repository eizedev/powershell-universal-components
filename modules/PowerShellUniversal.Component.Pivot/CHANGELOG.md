# Changelog

All notable changes to PowerShellUniversal.Component.Pivot. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

## [0.1.0] - unreleased

### Added

- `New-UDPivotReport` on pivotkit 0.1.0 (built from its main branch at 4bb1d91): a field list with
  search that collapses to a rail, Rows, Columns, Values and Filters with drag and drop and a menu on
  every field, aggregators and "show values as", date grouping, filters with value counts, table or
  chart (bars, lines, area, pie, donut, heatmap, Automatic) with display settings, Enlarge and Full
  screen, drill-down to the source rows with its own Enlarge, Copy and CSV/Excel export, undo and redo,
  the Views menu (shared views and my views, view files: Copy, Download, Load), and Excel, CSV and PNG
  export, Copy table and Copy data as JSON. pivotkit's lazily loaded menus are part of the module's one
  bundle (PSU serves only the registered bundle). Copying works over plain http too (pivotkit's
  fallback without the Clipboard API, measured in Chromium, Firefox and WebKit).
- Data straight from DataTables, REST results and PowerShell objects with their original column names;
  dates stay dates, `-TimeZone` (default: the server's zone) for dates with an offset.
- `New-UDPivotReportPlaceholder` for `New-UDDynamic -LoadingComponent`: pivotkit's own skeleton of the
  report in its colours while the server builds the data (reduced motion respected, announced to screen
  readers); it also makes the browser load the module's code at once. The showcase uses it.
- Data conversion without a function call per cell: the showcase's 5000-row DataTable takes about 40 ms
  instead of 2.4 to 2.9 s on the test instance, the table appears after about 0.46 s instead of 2.6 s.
- Field names and descriptions: `-FieldDefaults` with `Label`, `Description`, `Href` (https only),
  `Order`, `Agg`, `Format`, `DrillFormat` and `Type`, checked on the server; `-FieldDescriptions` (field
  name to text); `-Schema` from a JSON Schema or an OpenAPI 3 / Swagger 2 document (hashtable, JSON,
  file or https URL fetched on the server with timeout and size cap) with `-SchemaName`, read by
  pivotkit-core's `fieldDefaultsFromSchema` in the browser; `Get-UDPivotSqlColumnDescription` reads
  SQL Server column descriptions (`MS_Description`) for `-FieldDescriptions`. `-FieldInfo` and
  `-ZoneInfo` decide the "i" of fields and zones.
- `-ChartOptions` (plain JSON over the chart's ECharts option), `-Tips` (On, Off or tip ids; dismissed
  tips are remembered per report), `-Label` (the report's name for screen readers, also on the
  placeholder).
- Templates: `-Templates` (Scope shared or user, `File` for a view file), `-TemplatePath` (folders of
  pivotkit view files, checked on the server, read-only shared views), `-TemplateStore` with `Browser`,
  `New-UDPivotFileTemplateStore` (view files per user and shared, next to the PSU repository, lock and
  atomic writes, caps) or `New-UDPivotTemplateStore` (Get/Save/Delete/Publish script blocks for a
  database, Valkey, S3: the module checks users, roles, names, views and limits). `-AdminRole`: who
  publishes and deletes shared views, checked in the event handlers with the event's `$Roles`, and the
  admin panel under the report (view JSON, columns and types, timings). Without a signed-in user the
  reader's own views stay in the browser. `-UserName` and `-Roles` for calls from script blocks that
  do not see `$User` and `$Roles`.
- View files: `ConvertFrom-UDPivotViewFile`, `ConvertTo-UDPivotViewFile`; `-SourceId`, `-SourceName`
  (the data a view file or link was made for) and `-SchemaUrl`.
- `-SettingInfo`, `-FieldList` and `-Grow` (a report with a height stays inside it, also in a card of a
  fixed size).
- `-View` (hashtable or JSON), `-Labels`, `-Locale` (English and
  German, default en-US), `-Theme`, `-Height` (default: the window's height), `-FileName`, `-NoDrillDown`, `-NoAddressBar`.
- `-OnViewChange`, `-OnCellClick`, `-OnSaveTemplate`, `-OnDeleteTemplate` (with the entry's `scope`)
  and `-OnPublishTemplate` (for `-AdminRole`); saving, publishing and deleting show in the report once
  the server confirmed them, and a server's refusal shows its message.
- `Private/SHARED.txt`: the content hashes of the repository's `shared/` code the module was built from.
- `ConvertFrom-UDPivotView`: checks a view from the browser (size, depth, shape, known keys only) before
  it is stored.
- Light and dark theme in PSU's colours, following the app's switch; a corporate design from the app's
  stylesheet through the ECharts module's `--psu-chart-*` properties and the report's own `--psu-pivot-*`
  ones, per mode.
- The reader's view (fields, table or chart, chart type, collapsed groups) is kept in the browser tab
  per page and `-Id` (without `-Id`: the place of the call in the app script and the columns), so it
  survives PSU building the report anew on its light/dark switch and a reload; `Reset` goes back to `-View`.
  Two tabs on the same report keep their own views. The view is also written into the address bar
  (`#pivot-<id>=...`, in place, without history entries), so a reload keeps it and a copied link opens
  the same report layout; `-NoAddressBar` keeps it out (filter values would otherwise appear in the
  address, the history and copied links).
- `-SavedView`: the reader's view stored by the app (in `-OnViewChange`) starts a tab without a view of
  its own and never replaces the view another tab shows; the showcase uses it instead of
  `-View $Session:PivotView`, which made every tab of a browser take over the last change of another
  tab on reload.
- `examples/showcase.ps1`: a 5,000-row DataTable with shipped views (`examples/views`), a file template
  store, a language switch, the events and the report in page layouts (a card of a fixed height among
  them); `examples/templates.ps1`: an app with sign-in, readers' views on the server, publishing for
  two roles and the admin panel.
