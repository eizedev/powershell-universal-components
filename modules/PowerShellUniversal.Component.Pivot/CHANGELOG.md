# Changelog

All notable changes to PowerShellUniversal.Component.Pivot. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

### Changed

- The report's default height (without `-Height`) is one screen: the window's height minus 160
  pixels for PSU's app bar and a page title, between 600 and 1400 pixels (was minus 200, between 480
  and 1400). The whole report is on screen when the page loads, and the table shows more rows below
  the toolbar, the zones and a tip; below 600 pixels pivotkit would fold the zones. `-Height` sets
  another one, as before.
- The example showcase's pages with one report (Templates, Fields) take the default height instead
  of 640 pixels; the Events page keeps 640 so its event log stays in view.

## [0.2.0] - 2026-11-08

### Changed

- pivotkit 0.2.0 ([pivotkit-react release](https://github.com/eizedev/pivotkit/releases/tag/pivotkit-react%400.2.0)):
  Save, Save as and New, empty report in the Views menu with the loaded view's name and an
  unsaved-changes dot in the toolbar; sorting by a click on a table header; a view's unused parts as a
  warning in plain words; field menus with one line per setting. Labels a `-Labels` override may use
  changed: `issues`, `viewMissingFields`, `viewOtherIssue(s)` and `valuesFilterHint` are gone (see
  pivotkit-react's CHANGELOG for the new keys).
- View names in the template stores match as in pivotkit's Views menu: the same characters in the same
  case (after trimming). `Sales` and `sales` are two views; before, saving `sales` replaced `Sales`
  without pivotkit asking. Files of new views carry a hash of the name as it is. A view saved by 0.1.0
  is replaced in its file; in a custom store whose `-Get` returns only the Json it moves to the new
  key on its next save, and the old key is deleted.
- `New-UDPivotTemplateStore`: `-Get` may return objects with `Json` and `FileName`; a save over such a
  view gets its `FileName`, so `-Save` replaces it where it is stored. The SQL Server example returns it.
  `-Delete` must succeed for a key that is not stored: after a save the module also removes the other
  places a view of the name may be under, and a failure there is a warning in the log, not an error
  for the save. On several PSU nodes the store's own unique key (scope, user, `FileName`) keeps a
  name once; the module's lock holds on one machine only.
- `ConvertFrom-UDPivotViewFile` also returns `Generator` (name and version of what wrote the file).

### Fixed

- Saving or publishing a name that exists replaces that view in both template stores (an upsert, as
  pivotkit 0.2.0's Save expects), also a view stored under another file name (copied into the folder by
  hand, saved by 0.1.0) and a view that names no data; before, these got a second entry. A view stored
  twice is left once. `-OnSaveTemplate` and `-OnPublishTemplate` document that a save sends existing
  names. Listing, the check and the write of a custom store run under the store's lock, as in the file
  store.

## [0.1.0] - 2026-11-08

### Added

- `New-UDPivotReport` on pivotkit 0.1.0 (pivotkit-core and pivotkit-react from npm): a field list with
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
