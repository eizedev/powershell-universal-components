# Changelog

All notable changes to PowerShellUniversal.Component.Pivot. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

### Added

- `-ImportLimit`: pivotkit's limits for a file loaded with `-AllowImport` per report, e.g.
  `@{ fileBytes = 250MB; rows = 2000000 }` (`fileBytes`, `rows`, `columns`, `importCells`,
  `textLength`, `archiveEntries`, `unpackedBytes`; keys left out keep pivotkit's defaults). They go to
  pivotkit-react's `importLimits`, so the app's `-Data` keeps pivotkit's own limits. An unknown key or
  a value that is not a whole number of at least 1 is an error that names it
  ([#103](https://github.com/eizedev/powershell-universal-components/issues/103),
  [#106](https://github.com/eizedev/powershell-universal-components/issues/106)).

### Changed

- pivotkit's view version 2 ([pivotkit#165](https://github.com/eizedev/pivotkit/issues/165)): every
  filter is `{ field, type, ..., not, blanks }` with the types `in`, `blank`, `text`, `compare`,
  `relative`, `top` and `value`. Views of version 1 (`include`, `exclude`, `label`, the operators
  `!=`, `notBetween`, `notEquals`, `notContains`) in `-View`, `-SavedView`, `-Templates`, view files,
  template stores and links still load with the same result: the report migrates them. The report
  writes version 2, so `-OnViewChange`, `Get-UDElement` and saved views carry it.
- View files: `ConvertFrom-UDPivotViewFile`, `-TemplatePath` and the template stores read format
  versions 1 and 2 and views of version 1 and 2; a newer one is still refused.
  `ConvertTo-UDPivotViewFile` and the stores write format version 2 with
  `https://pivotkit.eize.dev/schema/view-file-2.json` for a view of version 2, and format version 1
  with `view-file-1.json` for a view of version 1 or without a version, so stored views of version 1
  stay readable by older releases.
- The shipped view "Open work per team" and the showcase's "Lead time per customer" are views of
  version 2. Docs: the Views page has a section on filters (types, `not`, `blanks`, version 1).

## [0.4.0] - 2026-11-11

### Added

- `-AllowImport`: readers load a CSV, TSV, JSON or Excel file (`.xlsx`) of their own into the report,
  read in the browser and never uploaded: a Data menu, a file dropped onto the report and a preview
  with a type per column and the sheet of a workbook; Back to original data and Undo go back to the
  app's data ([pivotkit#44](https://github.com/eizedev/pivotkit/issues/44)). The Excel reader
  (pivotkit-xlsx) is part of the bundle and runs only when the first workbook is read; CSV and JSON
  files are read in a worker the module ships next to its bundle (`import-worker.<hash>.js`, about
  26 KB), or on the page where a Content-Security-Policy keeps the worker from starting. `-Data` may
  be empty: the report then asks for a file. The bundle grows from 1.27 MB (391 KB gzip) to 1.41 MB
  (434 KB gzip): 69 KB (19 KB gzip) are the Excel reader, the rest pivotkit's import UI and menus.
- While a reader's file is shown, its view stays out of the address bar, `sessionStorage`,
  `Get-UDElement` and `-OnViewChange`, `-OnCellClick` does not run (its rows would carry the file's),
  and views the reader saves go to the browser's store per file, never to `-TemplateStore` or
  `-OnSaveTemplate`; the reader's own server views of the app's data leave "My views" meanwhile.
  Back to original data shows the app's last view, also after more loads than Undo keeps. PSU's
  light/dark switch and `Sync-UDElement` keep the file shown with its view (pivotkit keeps it per
  report in the page's memory; `-OnDataLoad` hears `restore`).
- `-OnDataLoad`: runs on the server when the data shown changes (a file loaded, the app's data again,
  Undo, Redo) with the cause, the file's name, size and type, the sheet, rows, columns (the first 200
  names and types) and the codes of the readers' notes; never a value of the file.
- Docs: the page [Readers' own files](https://powershell-universal-components.eize.dev/pivot/import/);
  the showcase app has a page "Your file" with the tickets, a file next to them and the events.

### Changed

- pivotkit 0.4.0 ([pivotkit-react release](https://github.com/eizedev/pivotkit/releases/tag/pivotkit-react%400.4.0))
  and the new pivotkit-xlsx 0.1.0: the Start over menu (Reset and New, empty report) after
  Undo and Redo, the Views menu regrouped (This view, Shared views, My views, Share this view), menu
  groups and a More menu only for buttons that do not fit.
- The help of `-SourceId` and the docs (Templates, view files and roles) say when to set it: a report
  whose data changes per call under the same `-Id` (an uploaded file, a parameter) sets `-SourceId` per
  data source, else the views saved for all of its data show together
  ([pivotkit#116](https://github.com/eizedev/pivotkit/issues/116)). The default stays `-Id`, so views
  readers saved keep showing.

### Fixed

- A shared view of `-TemplateStore` with the name of a `-TemplatePath` file takes the file's place in the
  Views menu. The menu listed the read-only file next to it, so an admin's Publish or Save over a
  shipped view looked lost; deleting the shared view offers the file again
  ([#73](https://github.com/eizedev/powershell-universal-components/issues/73)).

## [0.3.0] - 2026-11-09

### Changed

- pivotkit 0.3.0 ([pivotkit-react release](https://github.com/eizedev/pivotkit/releases/tag/pivotkit-react%400.3.0)):
  the menus of a chip, Options and Views are in levels (a first level that says what is set, a topic's
  level in place with Back, a search that finds a choice of any level, "/" goes to it); the Filter
  level rebuilt with a summary card (what the table shows of the field and why the rest does not,
  Reset filter), quick choices for a date (This year, Last N years, months or days, counted back from
  today or the latest record), Years combined for a grouping that repeats every year, Pick items and
  Rules (the item itself, its total or its name compared), each applied at once; a field in Filters
  opens the same level. Views: Save as, Share (Copy link, Copy view as JSON, Download view, Load view)
  and the questions before a delete or a publish are levels of the menu. A press inside a menu no
  longer drags the chip that opened it. New filter types in a view, `compare` and `relative` (with
  `anchor`); views saved by earlier versions load unchanged, and the template stores keep the new
  filters as they are. Labels a `-Labels` override may use changed again (new `summary*`, `quick*`,
  `anchor*`, `yearsCombined*`, `rule*`, `back`, `searchMenu` and more; gone: `moreFilters`,
  `itemsPicked`, `itemsShown*`, `pickedPlus`, `ruleOut`, `quickCustom`, `conditionOnNames`,
  `removeConditions`, `removeFilter`, `chooseValues`, `valueFilter`, `change`, `removeSetting`,
  `topStart`, `binsStart`, `filterIs`, `groupBy`, `resetSections`, `resetSectionsDone`; a text for a
  key that is gone is ignored). The docs describe the menus and the view's filter types.
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

[Unreleased]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.4.0...HEAD
[0.4.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.3.0...PowerShellUniversal.Component.Pivot-v0.4.0
[0.3.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.2.0...PowerShellUniversal.Component.Pivot-v0.3.0
[0.2.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.1.0...PowerShellUniversal.Component.Pivot-v0.2.0
[0.1.0]: https://github.com/eizedev/powershell-universal-components/releases/tag/PowerShellUniversal.Component.Pivot-v0.1.0
