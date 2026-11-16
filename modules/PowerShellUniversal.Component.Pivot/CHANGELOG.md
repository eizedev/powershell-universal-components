# Changelog

All notable changes to PowerShellUniversal.Component.Pivot. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

## [0.6.0] - 2026-11-16

### Added

- `Invoke-UDPivotReport`: renders a view over rows into an Excel workbook, an HTML report, CSV, JSON
  or SVG without a browser, for endpoints, schedules and jobs. `-Engine Node` runs pivotkit's command
  line on the PSU server (pivotkit-cli 0.2.1 or later; the rows in a temporary folder only this user can
  read, removed afterwards); `-Engine Rest` calls a pivotkit-server's file route with the rows in the
  request (pivotkit's data in the request, source `inline:`), or with `-Source` over a source the
  operator configured. `-Data`, `-Parameter` and `-DataAsOf` need pivotkit-server 0.2.0 or later
  (pivotkit-server 0.1.1 answers `-Data` with `INVALID_INPUT (400)`, and the error then says which
  version `-Data` needs); `-Source` works with pivotkit-server 0.1.1. Input is a view, a view file
  or a layout (`-Layout @{ rows = 'Team'; values = @{ field = 'Hours'; agg = 'sum' } }`); output is a
  file (`-OutFile`) or its bytes. A view with errors throws with pivotkit's findings. Every failure has a fixed error id (`PivotServerUnreachable`,
  `PivotRedirectRefused`, `PivotTokenRefused`, `PivotDataTooLarge`, `PivotViewHasErrors`,
  `PivotServerError`, `PivotCliNotFound`, `PivotCliFailed`) with `Status`, `Code`, `RetryAfter` and
  `RequestId` in the exception's `Data`; a 403 `INSUFFICIENT_SCOPE` is `PivotTokenRefused` and says to
  ask for the REST scope with `-Scope`. The rows are written into the request or the data file one by
  one, a DataTable straight from its rows, by a class compiled once per process (100,000 rows x 3
  columns: 0.1 s and about 30 MB instead of seconds and hundreds of MB); `-MaxBytes` (default 10 MiB,
  the server's default cap) stops oversized data before the rest is converted and before anything is
  sent. The Reports page has a section on size and memory. Rows are read by column name (the first row's columns), so
  another property order keeps its columns
  ([#114](https://github.com/eizedev/powershell-universal-components/issues/114),
  [#112](https://github.com/eizedev/powershell-universal-components/issues/112),
  [#129](https://github.com/eizedev/powershell-universal-components/issues/129)).
- Sign-in for `-Engine Rest`: a static token (`-Token`, a PSU secret) or OAuth client credentials
  (`-Credential` with `-TokenUri`, `-Scope`, `-Audience`, `-Resource`), the access token kept per
  runspace (per client, secret hash, scopes and server) until a minute before it expires and fetched
  again once after a 401. https only (http to this machine), no user info in an address, and a
  `-Uri` with a query string or fragment is refused (the routes are appended to its path, so the
  query would be dropped from the request); no redirects followed; the token and the secret appear in no message, `$Error`, verbose or debug output. The new page "Reports
  without a browser" has an Authentik example
  ([#115](https://github.com/eizedev/powershell-universal-components/issues/115)).
- Links from pivotkit: the report opens a view from pivotkit's share format in the address
  (`#pivot-<-Id>=1.<view>`, and `#pivot=1.<view>` without a key), which pivotkit's MCP tool
  `create_link` and REST route `/views/link` make for a source whose `link` is the PSU page and whose
  `linkKey` is the report's `-Id`. A link made for other data (its source id is not the report's
  `-SourceId`) is not loaded; the console says why. The report then writes its own entry in place of
  pivotkit's, so a reload keeps the view. The Views page has the configuration
  ([#116](https://github.com/eizedev/powershell-universal-components/issues/116)).
- `-ExportData`: Export, Source data downloads every row of `-Data` as a CSV or JSON file (pivotkit's
  `exportData`, off by default). `-ExportDataColumn` keeps it, and the drill-down's copies and files,
  to the columns it names; a name that is no column of `-Data` is an error, so a typo never widens the
  export, and the explanation next to Source data names those columns. It is no access control: the
  field list, the drill-down panel and `$EventData.rows` still carry every column, so a column readers
  must not have is removed before `-Data`. The Pivot page has a table of what the exports, the drill-down and Source data hand out
  ([#111](https://github.com/eizedev/powershell-universal-components/issues/111),
  [#113](https://github.com/eizedev/powershell-universal-components/issues/113)).

### Changed

- pivotkit 0.7.0 ([pivotkit-react release](https://github.com/eizedev/pivotkit/releases/tag/pivotkit-react%400.7.0),
  [upgrading from 0.6](https://pivotkit.eize.dev/getting-started/upgrading/#from-0-6-1)): pivotkit-core
  and pivotkit-react 0.7.0, pivotkit-report 0.3.0 and pivotkit-xlsx 0.4.0, all pinned and in the one
  bundle (1.60 MB, 497 KB gzip). Export, HTML report carries the dark colours of the report's theme
  too: a reader on a dark screen sees the app's dark values (the `--psu-pivot-*` of
  `.ud-pivot-report [data-pk-theme="dark"]`, PSU's dark greys without them), and paper stays light. A
  colour scale's middle colour on a dark screen is the dark theme's `--psu-pivot-scale-mid`; without one
  the cells run between the dark low and high colours. Print or save as PDF opens the print dialog in
  the click itself, a second click on a menu's button closes it in Safari, and a field's filter rules
  show in one column as wide as the menu.

### Fixed

- `-TemplatePath` lists only the view files made for the report's data (`-SourceId`, else `-Id`) and
  those that name no data, as the template stores do; it listed every file for every report. A
  folder that held the views of one report under another id shows them only in that report now
  ([#90](https://github.com/eizedev/powershell-universal-components/issues/90)).
- A shared `-Templates` entry with the name of a store's shared view showed twice in the Views menu;
  the store's view now takes its place, as for `-TemplatePath` files
  ([#91](https://github.com/eizedev/powershell-universal-components/issues/91)).
- A view from a link in the address bar is held to pivotkit's limits for views from outside (at most
  50 filters, 1,000,000 characters) instead of the app's own (128 filters); the tab's own view, kept
  in its sessionStorage, keeps the app's limits after a reload or the light/dark switch
  ([#105](https://github.com/eizedev/powershell-universal-components/issues/105)).
- `Invoke-UDPivotReport -Engine Rest`: a body over pivotkit-server's cap ends in the server's 413
  (`PivotDataTooLarge` with `BODY_TOO_LARGE` and the request id) instead of `PivotServerUnreachable`
  ("Error while copying content to a stream"): the server answers such a body at once and closes the
  connection, and the request reads that answer while it still sends. A 413 says what to do by its
  code (`BODY_TOO_LARGE`: send less or use `-Source`; `LIMIT_EXCEEDED`: make the view smaller or
  filter). `retryable` of a problem document is `Retryable` in the exception's `Data` and "Trying again
  may work." in the message; `Retry-After` as an HTTP date is shown as a time. Without a problem
  document the request id comes from the `X-Request-Id` header, and the 500 of a crashed handler shows
  its `error` text. A header value outside printable ASCII (a token with an umlaut) is refused before
  anything is sent, naming the header, not its value.
  `-TimeoutSec` limits each REST call as a whole, including sending the body and reading the report
  in full; Invoke-WebRequest's `-TimeoutSec`, used before, stopped only the wait for the answer's
  headers (measured on PowerShell 7.6.9), so a slowly streamed report was not limited.

## [0.5.0] - 2026-11-15

### Security

- pivotkit-xlsx 0.3.1: a crafted Excel workbook could pass the size checks before parsing and fill
  the reader's browser memory (denial of service in the reader's own tab;
  [GHSA-c6vh-q36c-92r3](https://github.com/eizedev/pivotkit/security/advisories/GHSA-c6vh-q36c-92r3),
  pivotkit-xlsx 0.3.0 and earlier, so release 0.4.0 of this module with `-AllowImport`; update from
  0.4.0). Workbooks with namespace-prefixed elements are checked like the others. Also, a workbook's
  different texts and cell formats count against `importCells` while they are unpacked.

### Added

- `-ImportLimit`: pivotkit's limits for a file loaded with `-AllowImport` per report, e.g.
  `@{ fileBytes = 250MB; rows = 2000000 }` (`fileBytes`, `rows`, `columns`, `importCells`,
  `textLength`, `archiveEntries`, `unpackedBytes`; keys left out keep pivotkit's defaults). They go to
  pivotkit-react's `importLimits`, so the app's `-Data` keeps pivotkit's own limits. An unknown key or
  a value that is not a whole number of at least 1 is an error that names it
  ([#103](https://github.com/eizedev/powershell-universal-components/issues/103),
  [#106](https://github.com/eizedev/powershell-universal-components/issues/106)).

### Changed

- pivotkit 0.6.1 ([pivotkit-react release](https://github.com/eizedev/pivotkit/releases/tag/pivotkit-react%400.6.1),
  [upgrading from 0.4](https://pivotkit.eize.dev/getting-started/upgrading/)): pivotkit-core and
  pivotkit-react 0.6.1, pivotkit-xlsx 0.3.1 and pivotkit-report 0.2.1, all pinned and in the one
  bundle (1.58 MB, 494 KB gzip). Export's table as CSV is called **Table as CSV (.csv)**; pivotkit's
  Source data export stays off (`-ExportData` follows,
  [#113](https://github.com/eizedev/powershell-universal-components/issues/113)). A view saved in the
  browser for a sheet of a loaded workbook opens on that sheet again. Dates before 1 AD carry their era
  ("Q1 2 BC"). Export has an HTML report, the chart as SVG and Print or save as PDF; Excel, the HTML
  report and print are light also from a dark app. Column subtotals are off unless a view turns them on
  (`totals = @{ colSubtotals = $true }`); views the report saves name all four totals. The chart's
  text is 14 px, the font weights are four (`--psu-pivot-weight-*`). `-Tips` knows the tip
  `colSubtotals`. The filter menus write view version 2 (below).
- A colour scale without colours of its own runs from light to strong blue, the heatmap's colours,
  on screen and in the Excel export, not from red over yellow to green: it says "more", not "good" or
  "bad". `--psu-pivot-scale-low` and `--psu-pivot-scale-high` fall back to `--psu-pivot-heat-low` and
  `--psu-pivot-heat-high`; `--psu-pivot-scale-mid` adds a middle colour. The Themes page shows how to
  get red, yellow and green back
  ([#107](https://github.com/eizedev/powershell-universal-components/issues/107)).
- Themes: the corporate stylesheet sets each mode for the page and for the theme the report shows
  (`:root, .ud-pivot-report [data-pk-theme="light"]` and `:root[data-theme="dark"],
  .ud-pivot-report [data-pk-theme="dark"]`), so the Excel export and the HTML report of a dark app take
  the light values and a report pinned with `-Theme` takes those of its own theme. A stylesheet with
  `:root[data-theme="dark"]` alone still themes the screen, but its dark values reach those files.
- New theme properties: `--psu-pivot-input-border` and `--psu-pivot-rule` (the edge of a text field and
  the line between a menu's groups, PSU's neutral greys instead of pivotkit's blue-grey) and
  `--psu-pivot-weight-normal`, `-medium`, `-strong` and `-bold`. The admin panel of `-AdminRole` takes
  the report's corners, weights and text size (at least 14 px; its code was 13 px).
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

[Unreleased]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.6.0...HEAD
[0.6.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.5.0...PowerShellUniversal.Component.Pivot-v0.6.0
[0.5.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.4.0...PowerShellUniversal.Component.Pivot-v0.5.0
[0.4.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.3.0...PowerShellUniversal.Component.Pivot-v0.4.0
[0.3.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.2.0...PowerShellUniversal.Component.Pivot-v0.3.0
[0.2.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.1.0...PowerShellUniversal.Component.Pivot-v0.2.0
[0.1.0]: https://github.com/eizedev/powershell-universal-components/releases/tag/PowerShellUniversal.Component.Pivot-v0.1.0
