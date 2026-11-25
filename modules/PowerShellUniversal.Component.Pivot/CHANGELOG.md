# Changelog

All notable changes to PowerShellUniversal.Component.Pivot. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

## [0.10.1] - 2026-11-25

### Fixed

- `Invoke-UDPivotReport -Engine Rest` without `-OutFile` returns a `byte[]` again, as with
  `-Engine Node`. Since 0.9.0 it returned an `object[]` of single bytes: `[string]` of it gave the
  byte values joined by spaces, so an HTML report shown in a page read `60 33 100 ...`
  ([#204](https://github.com/eizedev/powershell-universal-components/issues/204)). Large answers and
  requests no longer pass through PowerShell's pipeline byte by byte.

## [0.10.0] - 2026-11-25

### Fixed

- A store error of the server, such as a folder it cannot write, no longer shows the server's path to
  the reader. Only the module's own refusals (a name, a limit, a busy store, rights) and a text that
  the app's store throws reach the browser. Any other error goes to the app's log as a warning, and
  the reader reads "The server could not change the views."
- `Invoke-UDPivotReport -Engine Node` renders when `PSU_COMPONENT_PIVOT_SCHEMA_URL` is a path. The
  temporary view file leaves `$schema` out; before, the path stopped every render from a schedule.
- A time without an offset in a pivotkit-server answer is read as UTC, as documented, not as the
  server's local time.
- `ConvertTo-UDPivotViewFile` ends the file with a newline, as its help says.
- A field or column name with `$` shows as written in the notices above the report; `$&` and similar
  patterns were replaced.
- A description cut at its limit no longer ends in half of an emoji or another character outside the
  Basic Multilingual Plane.

### Changed

- pivotkit-core 0.10.0, pivotkit-react 0.10.0, pivotkit-report 0.6.0 and pivotkit-xlsx 0.7.0, all
  pinned. What readers see:
    - A loaded CSV or Excel file with numbers such as `1,234` or `1.500` reads them in the notation
      of the report's locale and says so in a note. Check such a column after the update.
    - On a phone, the settings button shows its icon only, and table headers wrap between words.
    - A menu that a low window cuts off fades out at its end.
  `-Labels` no longer uses the key `settingsShort`. Remove it if you set it. The
  [pivotkit changelogs](https://pivotkit.eize.dev/getting-started/upgrading/#from-0-9) list all changes.
- A shared view of a template store takes no origin from the request's headers for a `-SchemaUrl`
  path. It takes the origin of an https `PSU_COMPONENT_PIVOT_SCHEMA_URL`, else it names pivotkit's
  schema address. This affects you when you publish shared views with a path and no https default:
  to keep your own address in them, set `PSU_COMPONENT_PIVOT_SCHEMA_URL` to it. A view a reader saves
  for themselves keeps the origin of the request.
- `ConvertTo-PSUComponentData`, the data conversion all modules share, keeps its C# converter in
  `RowConverter.cs` and its helpers one function per file. The rows it returns are unchanged.
- The module's code is one function per file in `Public/` and `Private/`; the `.psm1` only loads them.
  Commands, parameters, help and output are unchanged
  ([#163](https://github.com/eizedev/powershell-universal-components/issues/163)). The settings files in
  `Private/Settings/` load in the order of their names on every file system.
- The help of `New-UDPivotTemplateStore` shows a store you can run: one file per view in a folder.

## [0.9.1] - 2026-11-22

### Added

- The showcase's Events page has a button that reads the report's view with `Get-UDElement`.

### Fixed

- `Get-UDElement -Id <report id>` returns the reader's current view as `.view`, as documented.
  It returned the string `"null"` on PSU 2026.2 and 2026.3. It now returns only `id` and `view`, not
  the rows ([#158](https://github.com/eizedev/powershell-universal-components/issues/158)).

## [0.9.0] - 2026-11-22

### Added

- `Invoke-UDPivotReport -Engine Node -Numbers Full|Shown` and `-FlatHeader`: pivotkit-cli 0.5.0's
  `--numbers` and `--flat-header`. CSV and JSON numbers rounded to the decimals the view shows, and a
  CSV file with one header row
  ([#153](https://github.com/eizedev/powershell-universal-components/issues/153)).
- `New-UDPivotReport -Uri -Source -Token` shows the rows of a pivotkit-server source for the signed-in
  person, also when a link from pivotkit's `create_link` opens the page
  ([#144](https://github.com/eizedev/powershell-universal-components/issues/144),
  [rows from a server](https://powershell-universal-components.eize.dev/pivot/server-rows/)).
    - PowerShell fetches the rows from the server's rows route (`POST /sources/records`) with the
      person's token, `$AccessToken` of PSU's OpenID Connect sign-in. The browser makes no request to
      the server, and the token never reaches it.
    - The server's answer goes to the report as JSON text, never as PowerShell objects. The report
      parses it in the browser.
    - A link's parameters come from the page's query string (`$Query`, or `-Query`), only those the
      server lists in the source's `linkParams`. `-Parameter` sets them instead.
    - `-View` takes the name of a view the server publishes for the source: only the fields it uses
      leave the server.
    - `-MaxBytes` (default 32 MB, at most 64 MB) caps the answer. The module reads it in pieces and
      stops past the cap.
    - `-Parameter` also binds as `-Params`, the name of the issue.
    - When the server refuses, the report tells the reader in plain words, in English or German. The
      operator's message with a fixed error id goes to the warning stream, the app's log.
      `-ErrorAction` or `-ErrorVariable` get the error itself; `-ErrorAction Stop` throws it. The new
      error ids are `PivotRowsNotAllowed`, `PivotNoData` and `PivotServerBusy`.
    - A page without a token asks the reader to sign in, and a token without the server's scope says
      the service is not set up for the sign-in.
    - A link's view that needs a field the server held back says which field above the report.
- `Get-UDPivotSource` gives each source `Records`, `LinkParams`, `Views`, `Rows` and `DataAsOf`, where
  the server sends them.
- `PivotServerProblem` has `NotShown`, the fields of a `NOT_ALLOWED` answer of the rows route.
- The docs list the module's own network requests next to pivotkit's
  ([#146](https://github.com/eizedev/powershell-universal-components/issues/146),
  [network requests](https://powershell-universal-components.eize.dev/pivot/events/#network-requests)).
- A sizing section: what the rows of a server take in the browser, the PowerShell process and PSU's
  server process, measured on PSU 2026.2.5 and 2026.3.4, and `DOTNET_GCHeapHardLimit` per PSU process.
- pivotkit 0.9's chart types in views and in `Invoke-UDPivotReport -Layout`: `combo` (bars and lines)
  and `treemap`. High and low points on a chart, `chart.referenceLines.extremes`.
- pivotkit 0.9's view keys pass `ConvertFrom-UDPivotView`, view files, `-Templates` and the template
  stores: `fieldLabels` (a field's name of the report's own), `display = 'both'` (the table and the chart
  side by side), `sort[].column` (rows sorted by one column) and a colour scale's `conditional.colors`.
  The check refuses a `fieldLabels` that is no object of field names with a text of 1 to 256
  characters each.
- Theme properties `--psu-pivot-chart-axis` (falls back to `--psu-chart-axis`) for the chart's axis
  line, and `--psu-pivot-chart-other` for a pie's slice "Other (n)". Without it the slice takes
  pivotkit's colours: the muted text in the light theme, a grey in the dark.

### Changed

- pivotkit-core 0.9.0, pivotkit-react 0.9.0, pivotkit-report 0.5.0 and pivotkit-xlsx 0.6.0, all pinned.
  What readers see:
    - Chart settings offers **Bars and lines** and **Treemap**, and **High and low points** under
      Reference lines.
    - A pie or donut without a legend puts its smallest slices into one grey slice "Other (n)" when
      their labels have no room.
    - The messages about a loaded view no longer name pivotkit.
    - A click on a bar, a point or a heatmap cell opens a menu at it: **Show the rows**, **Only …** and
      **Without …**. A double click opens the rows at once.
    - **Name** in the menu of a field in Rows, Columns or Filters, a tab **Both** for the table and the
      chart side by side, **Colours** for a colour scale, a click on a column's name sorts by that
      column, and a date in Filters can be grouped.
    - A tip on stacked bars of a value that does not add up (`stackedTotal` for `-Tips`).
    - On a touch screen every button and menu row is at least 44 by 44 pixels.
    - The German texts and the tips are part of the module's one bundle, as before: PSU loads no
      new file.
- `-OnCellClick` for a chart point runs at **Show the rows** in the point's menu or at a double click,
  no longer at the first click. The docs of the event say so.
- `ConvertFrom-UDPivotView` takes `display` in lower case only, as pivotkit writes it: `'Table'` is
  refused.
- The bundle is about 1.8 MB, 550 KB with gzip.
- Views with the new keys need this version on every PSU server that reads them. Module 0.8 skips a
  view with `display = 'both'` in a view folder or store with a warning, refuses it in `-View` and
  `-Templates`, and drops `fieldLabels`. Update every server that shares
  a template store or a view folder before readers save such views.
- The chart's axis line takes `--psu-chart-axis` where an app sets it, also when it sets
  `--psu-pivot-border` for the report's other lines.
- `Invoke-UDPivotReport -Engine Node` names Node 24 or later for pivotkit-cli 0.5.0 and later
  (Node 22 for pivotkit-cli 0.4 and older).

### Fixed

- `-ErrorVariable` holds the error that stops a command, once. It also held each step the error took
  through the module, often eight records or more. With `-ErrorVariable +name`, the entries you had
  before stay. This holds for every command of the module
  ([#153](https://github.com/eizedev/powershell-universal-components/issues/153)).
- With `-ErrorAction SilentlyContinue` or `Ignore`, a command of the module went on after its own
  error: `Invoke-UDPivotReport` without a command line still tried to run it, and
  `ConvertFrom-UDPivotView` returned a result for a view it had refused. Such an error now stops the
  command with every `-ErrorAction`. Catch it with `try` and `catch`
  ([#153](https://github.com/eizedev/powershell-universal-components/issues/153)).
- `New-UDPivotReport -Tips` refuses an id pivotkit does not know, and names the ones it knows. A wrong
  id or a notice id such as `filterEmpty` went to pivotkit, which ignored it. An id in other case, such as
  `Values`, now reaches pivotkit in its spelling
  ([#154](https://github.com/eizedev/powershell-universal-components/issues/154)).
- The views page lists the chart settings in a table of their own
  ([#154](https://github.com/eizedev/powershell-universal-components/issues/154)).

## [0.8.0] - 2026-11-18

### Added

- `Get-UDPivotSource` lists the sources of a pivotkit-server that the caller may use (`GET /sources`),
  with the same sign-in parameters as `Invoke-UDPivotReport -Engine Rest`
  ([#141](https://github.com/eizedev/powershell-universal-components/issues/141)).
    - Each source has its id, title, description, kind, parameters and whether links and schedules
      work for it.
    - `DataMaxBytes` says how large a request with `-Data` the caller may send.
    - An empty list writes the server's reason to the warning stream.
- `Invoke-UDPivotReport -AsLink` returns a link to the report that expires, instead of the file
  ([#141](https://github.com/eizedev/powershell-universal-components/issues/141)).
    - The server keeps the report (`POST /views/render` with `save: true`).
    - The result has `Url`, `ExpiresAt`, `Rows`, `RequestId`, `Format`, `FileName`, `Bound`,
      `DataAsOf` and `Message`.
    - Where the server gives no link, the new error id `PivotNoLink` says so plainly, with the
      server's reason.
- The errors of pivotkit-server carry its answer as a record: `$_.TargetObject` is a
  `PivotServerProblem` with `Status`, `Code`, `Title`, `Detail`, `RequestId`, `Retryable`,
  `RetryAfter`, `Type` and `Findings`. A page can tell the reader why a call failed by its code
  ([#141](https://github.com/eizedev/powershell-universal-components/issues/141)).
- `$_.Exception.Data` holds `Title` and `Detail` too. Its other keys and the error ids stay.
- `Invoke-UDPivotReport -Template` gives an HTML report of the command line a print template of your
  own. It goes with `-Format html` and `-Engine Node`. With `-Engine Rest` the server's source decides
  the template, so the function refuses it there
  ([#140](https://github.com/eizedev/powershell-universal-components/issues/140)).
- Theme properties for the field type colours: `--psu-pivot-type-string`, `--psu-pivot-type-number`,
  `--psu-pivot-type-date` and `--psu-pivot-type-boolean`. Without them the colours stay pivotkit's
  ([#137](https://github.com/eizedev/powershell-universal-components/issues/137)).
- Theme properties for the tabs and buttons of pivotkit-react 0.8.1: `--psu-pivot-tab-*`,
  `--psu-pivot-icon-button-*`, `--psu-pivot-button-border*` and `--psu-pivot-primary-*`. Without them
  the parts follow the report's colours as before. A primary button's hover follows its own fill
  ([#137](https://github.com/eizedev/powershell-universal-components/issues/137)).

### Changed

- The docs give both zone heights, measured on PSU: about 150 pixels in the 2×2 grid, about 390
  pixels in one column.
  The showcase screenshots show pivotkit 0.8's toolbar and zones
  ([#143](https://github.com/eizedev/powershell-universal-components/issues/143)).

## [0.7.2] - 2026-11-18

### Changed

- pivotkit-react 0.8.1 ([release](https://github.com/eizedev/pivotkit/releases/tag/pivotkit-react%400.8.1),
  [upgrading from 0.8.0](https://pivotkit.eize.dev/getting-started/upgrading/#from-0-8-0)).
  pivotkit-core stays at 0.8.0, pivotkit-report at 0.4.0 and pivotkit-xlsx at 0.5.0, all pinned.
  What readers see:
    - The four zones form an even 2×2 grid: Filters and Columns on top, Rows and Values below, in
      equal halves. In a narrow report they stand in one column.
    - Each zone has a frame and is a little taller. Adding a field no longer moves the other zones.
    - The Filters hint is shorter: "Add or drop a field to filter".
    - Folding the field list to its rail gives the zones the freed width.
- pivotkit 0.8.1 adds theme tokens for the zone frames, the tabs, the icon buttons, the buttons
  and the primary buttons. The module's PSU theme needs no new properties for them: they take PSU's colours from
  the tokens it already sets. The zone frames use the colour of `--psu-pivot-border-strong`.

## [0.7.1] - 2026-11-18

### Added

- `-SchemaUrl` takes a path on the PSU server, such as `/assets/pivot/schema/view-file-2.json`. One
  value fits every instance, a local one on `http://localhost` included
  ([#138](https://github.com/eizedev/powershell-universal-components/issues/138)).
    - The browser writes the path with the page's origin.
    - The template stores and `ConvertTo-UDPivotViewFile` take the origin of an https default.
    - Without one, they take the origin of the request (`Origin`, the page address, `Referer`). A
      template store uses the request of the save.
    - Without either, they stop with an error.
- A module-wide default for `-SchemaUrl`: the environment variable `PSU_COMPONENT_PIVOT_SCHEMA_URL`
  of the PSU process. An explicit `-SchemaUrl` still wins, `''` included.
- The module ships pivotkit-core's `view-file-1.json`, `view-file-2.json` and `view-2.json` in its
  `schema` folder. They come from the pivotkit-core version the bundle is built from, so a host can
  publish the matching copy.

### Changed

- `New-UDPivotReport`, `ConvertTo-UDPivotViewFile` and the template stores check `-SchemaUrl` the
  same way: `''`, an https address or a path; no spaces, at most 2,000 characters, no user name or
  password. The scheme may be in any case. `ConvertTo-UDPivotViewFile` and the stores took any text
  before: an `http://` address or another value now stops them with an error. The error text is new
  in all of them ([#110](https://github.com/eizedev/powershell-universal-components/issues/110)).
- An address of your own names the schema of the current format (view file format 2). A file of
  format 1 keeps pivotkit's `view-file-1.json` address, so it never names the schema of another
  format ([#110](https://github.com/eizedev/powershell-universal-components/issues/110)).
- An address of your own for a file of format 1 is no longer possible.

## [0.7.0] - 2026-11-18

### Added

- `-Zones Open` or `-Zones Folded`: how the zones start under "Fields in the report" (pivotkit's
  `zones`). Without it the report's height decides, as before: below 600 pixels (820 in the narrow
  layout) they start folded. Readers still fold and open them
  ([#133](https://github.com/eizedev/powershell-universal-components/issues/133)).
- `-DrillDownExport`: the drill-down panel's Export menu (copy, Copy as JSON, CSV and Excel of the
  rows behind a value, every column) without `-ExportData` (pivotkit's `drillDownExport`). Not with
  `-NoDrillDown`.
- The Views page lists the chart settings a view can hold since pivotkit 0.8.0 (`tooltip`, `zoom`,
  `stackPercent`, `hidden`, `referenceLines`, `colors`, `tooltipShare`), with an example that
  also uses `-Zones Folded`.
  `ConvertFrom-UDPivotView`, the view files and the template stores keep them as they are.

### Changed

- pivotkit 0.8.0 ([pivotkit-react release](https://github.com/eizedev/pivotkit/releases/tag/pivotkit-react%400.8.0),
  [upgrading from 0.7](https://pivotkit.eize.dev/getting-started/upgrading/#from-0-7)):
  pivotkit-core and pivotkit-react 0.8.0, pivotkit-report 0.4.0 and pivotkit-xlsx 0.5.0, all pinned.
  What readers see:
    - Table and Chart are tabs on top of the result, with "Table settings" or "Chart settings"
      beside them. The chart type button, Options and Layout left the toolbar. More is always at
      the toolbar's end, with Help first; "Show tips" and "Show explanations" are there.
    - The zones sit under the heading "Fields in the report", which folds them. Each zone is a
      shelf with "+ Add", which places a field without dragging.
    - Charts: a zoom slider for a long axis, a click on the legend hides a series, stacks to
      100 %, reference lines (average, trend, a target), a colour per series, each value's share
      in the tooltip, and Export, Copy chart image.
    - The footer names the data's date range, and a grouping such as "Month of year" says which
      years it combines.
    - The row count says "2,190 of 4,386 rows" when a filter leaves rows out.
- Behaviour change: without `-ExportData` the drill-down panel has no Export menu any more. Readers
  still see the rows behind a value and can select and copy their text. `-DrillDownExport` brings the
  menu back without Source data; `-ExportData` brings it with Source data.
- `-Labels`: pivotkit 0.8.0 no longer shows the keys `layout`, `showLayout`, `options` and
  `chartDisplay`, and says once in the browser's console which key holds that text now. Use
  `zonesTitle`, `tableSettings` and `chartSettings`. An app that sets `rowsCount` sets `rowsFiltered`
  too ([upgrading](https://pivotkit.eize.dev/getting-started/upgrading/#view-tabs-0-8)).
- The help of `-Tips`, `-FieldInfo`, `-ZoneInfo` and `-SettingInfo` and the Pivot pages name More,
  Help instead of Options, and the zones' heading instead of the Layout button.
- `Invoke-UDPivotReport` is tested with pivotkit-cli 0.4.0 and pivotkit-server 0.3.0. The file route
  it calls keeps every digit of csv and json, so 0.3.0's rounded inline numbers do not reach it. The
  Reports page says that `-Token` also sends a short-lived token another system signed
  (pivotkit-server's `auth.externalIssuers`).

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
  file (`-OutFile`) or its bytes. A view with errors throws with pivotkit's findings. Every failure
  has a fixed error id (`PivotServerUnreachable`, `PivotRedirectRefused`, `PivotTokenRefused`,
  `PivotDataTooLarge`, `PivotViewHasErrors`, `PivotServerError`, `PivotCliNotFound`,
  `PivotCliFailed`) with `Status`, `Code`, `RetryAfter`, `Retryable`, `RequestId` and `MaxBytes` in
  the exception's `Data`; a 403 `INSUFFICIENT_SCOPE` is `PivotTokenRefused` and says to ask for the
  REST scope with `-Scope`. An error from the server names its code, detail, findings and request id
  (from the problem document, else the `X-Request-Id` header; a crashed handler's 500 shows its
  `error` text), says when to try again (`Retry-After` in seconds or as a time) or that trying again
  may work (`retryable`), and for a 413 what to do by its code (`BODY_TOO_LARGE`: send less or use
  `-Source`; `LIMIT_EXCEEDED`: make the view smaller or filter). A body over the server's cap ends in
  its 413, also when the server answers while the body is still being sent. A header value outside
  printable ASCII (a token with an umlaut) is refused before anything is sent, naming the header,
  not its value. `-TimeoutSec` limits each REST call as a whole, including sending the body and
  reading the report in full. The rows are written into the request or the data file one by one, a
  DataTable straight from its rows, by a class compiled once per process (100,000 rows x 3 columns:
  0.1 s and about 30 MB instead of seconds and hundreds of MB); `-MaxBytes` (default 10 MiB, the
  server's default cap) stops oversized data before the rest is converted and before anything is
  sent. The Reports page has a section on size and memory. Rows are read by column name (the first
  row's columns), so another property order keeps its columns
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
  [upgrading from 0.6](https://pivotkit.eize.dev/getting-started/upgrading/#from-0-6-1)):
  pivotkit-core and pivotkit-react 0.7.0, pivotkit-report 0.3.0 and pivotkit-xlsx 0.4.0, all pinned.
- Export, HTML report carries the dark colours of the report's theme too. A reader on a dark screen
  sees the app's dark values (the `--psu-pivot-*` of `.ud-pivot-report [data-pk-theme="dark"]`), or
  PSU's dark greys without them. Paper stays light.
- A colour scale's middle colour on a dark screen is the dark theme's `--psu-pivot-scale-mid`.
  Without one, the cells run between the dark low and high colours.
- Print or save as PDF opens the print dialog in the click itself.
- A second click on a menu's button closes the menu in Safari.
- A field's filter rules show in one column as wide as the menu.

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

[Unreleased]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.9.1...HEAD
[0.9.1]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.9.0...PowerShellUniversal.Component.Pivot-v0.9.1
[0.9.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.8.0...PowerShellUniversal.Component.Pivot-v0.9.0
[0.8.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.7.2...PowerShellUniversal.Component.Pivot-v0.8.0
[0.7.2]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.7.1...PowerShellUniversal.Component.Pivot-v0.7.2
[0.7.1]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.7.0...PowerShellUniversal.Component.Pivot-v0.7.1
[0.7.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.6.0...PowerShellUniversal.Component.Pivot-v0.7.0
[0.6.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.5.0...PowerShellUniversal.Component.Pivot-v0.6.0
[0.5.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.4.0...PowerShellUniversal.Component.Pivot-v0.5.0
[0.4.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.3.0...PowerShellUniversal.Component.Pivot-v0.4.0
[0.3.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.2.0...PowerShellUniversal.Component.Pivot-v0.3.0
[0.2.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot-v0.1.0...PowerShellUniversal.Component.Pivot-v0.2.0
[0.1.0]: https://github.com/eizedev/powershell-universal-components/releases/tag/PowerShellUniversal.Component.Pivot-v0.1.0
