# Changelog

All notable changes to PowerShellUniversal.Component.Pivot.Demo. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

### Fixed

- A value of `New-UDPivotShowcase` with a typographic apostrophe, such as `-PivotkitPath` with a
  folder of `O’Neil`, no longer breaks the page's code: the app escapes every quote character
  PowerShell reads.

### Changed

- Requires PowerShellUniversal.Component.Pivot 0.9.1. The ticket showcase's Events page reads the
  report's view with `Get-UDElement`, which works from Pivot 0.9.1 on
  ([#158](https://github.com/eizedev/powershell-universal-components/issues/158)).

## [0.6.0] - 2026-11-22

### Added

- The page "Report as a file": the buttons **Download Excel workbook** and **Download HTML report** make a file of the
  reader's view on the PSU server with `Invoke-UDPivotReport -Engine Node`. They need pivotkit's command
  line on the server; `New-UDPivotShowcase -PivotkitPath` names it when it is not on the PATH. Without
  it the page says what to install, and its report still works.
- The page "Rows from a server": `New-UDPivotReport -Uri -Source -Token $AccessToken` for the signed-in
  person, set up with `New-UDPivotShowcase -ServerUri -ServerSource`. Without them, or without a token,
  the page says what it needs and shows no report.
- The ticket showcase has the page Charts: the menu on a bar (Show the rows, Only, Without), a
  treemap, and a donut that puts its smallest slices into one slice "Other". Its views folder carries
  the view file "Hours to close per group (table and chart)".
- Weather has the views "Which city is the warmest in July?" (rows sorted by one column) and "Rain and
  sunshine per month (bars and lines)" (a combo chart with field names of the report's own).

### Changed

- Requires PowerShellUniversal.Component.Pivot 0.9.0 or later (pivotkit 0.9.0): the pages use
  `display = 'both'`, `combo`, `treemap`, the high and low points, `fieldLabels`, a sort by one column
  and `New-UDPivotReport -Uri`.
- Weather is the first page, with the field list folded. Its start view shows the table and the chart side by side: the mean
  temperature per month as a colour scale from blue to orange and as lines, with each city's warmest and
  coldest month marked.

## [0.5.0] - 2026-11-18

### Added

- The documentation pages have the example "Chart settings in a view" (a start view with stacked
  bars, a fixed series colour, the average as a reference line and shares in the tooltip, and
  `-Zones Folded`).

### Changed

- Requires PowerShellUniversal.Component.Pivot 0.7.0 or later (pivotkit 0.8.0): the example above
  uses `-Zones`, and the ticket showcase's Tickets page keeps the drill-down's Export menu with
  `-DrillDownExport`.

## [0.4.0] - 2026-11-16

### Added

- The documentation pages have the example "Source data for readers" (`-ExportData` with
  `-ExportDataColumn`).

### Changed

- Requires PowerShellUniversal.Component.Pivot 0.6.0 or later (the example above uses `-ExportData`).

## [0.3.0] - 2026-11-15

### Changed

- Requires PowerShellUniversal.Component.Pivot 0.5.0 or later (pivotkit 0.5.0): the ticket showcase's
  views "Open work per team" and "Lead time per customer" filter in pivotkit's view version 2 (`in`
  with `blanks`), and the documentation pages have the example "Readers' files with smaller limits"
  (`-ImportLimit`).

## [0.2.0] - 2026-11-11

### Added

- Your data: readers save their views in the browser (`-TemplateStore Browser`), per file: the Views
  menu lists those made for the file shown and those saved without a data source, and the same file
  uploaded again offers them again. All uploaded files share the browser store's limits (100 views,
  500,000 characters).

### Changed

- Requires PowerShellUniversal.Component.Pivot 0.4.0 or later (Your data uses `-AllowImport`).
- Your data reads the reader's file in the browser with `New-UDPivotReport -AllowImport`: CSV, TSV,
  JSON and Excel workbooks (`.xlsx`), dropped onto the report or picked under Data, with a preview
  before the data is replaced. The file is never uploaded; the server-side upload (`New-UDUpload`,
  5 MB and 100,000 rows, CSV and JSON only) is gone. Views saved for a file keep their id (the file
  name and a hash of the name and column names, the scheme the upload used), so views readers saved
  for an uploaded file are offered for the same file loaded in the browser, unless its name or column names needed cleaning ([how ids are built](https://powershell-universal-components.eize.dev/pivot/templates/#ids))
  ([#64](https://github.com/eizedev/powershell-universal-components/issues/64)).

### Fixed

- Your data: the report's `-SourceId` is the uploaded file's name and a hash of the whole name and its
  column names in their order, not the report's id that every upload shared. A view file or link made from one file names that file, and
  loading it into the report of another file asks first (Load anyway, Cancel); the same file uploaded
  again is the same data ([pivotkit#116](https://github.com/eizedev/pivotkit/issues/116)).
- Your data: a file name longer than 120 characters no longer fails the page (the report's `-Label`
  takes at most 120); the page shows it shortened, never splitting an emoji. A file name with spaces
  around it is read without them (a trailing space refused the file).

## [0.1.1] - 2026-11-09

### Changed

- Requires PowerShellUniversal.Component.Pivot 0.3.0 or later (pivotkit 0.3.0: menus in levels, the
  Filter level with its summary and quick choices, the default height of one screen).
- The pages' reports (Weather, Your data) and the placeholder while the data loads take the pivot
  report's default height, one screen, instead of 640 pixels, which left only a few rows below the
  zones on a desktop window. The ticket pages (Templates, Fields) do the same with the pivot module's
  examples; the new default comes with the pivot module 0.3.0.

### Fixed

- A click on the free space beside the "Live data" switch no longer switches it
  ([#75](https://github.com/eizedev/powershell-universal-components/issues/75)).

## [0.1.0] - 2026-11-08

### Added

- `New-UDPivotShowcase`: the showcase app of PowerShellUniversal.Component.Pivot as a module, with
  pages for the three pivot examples of the documentation on endoflife.date, daily weather of six
  cities from Open-Meteo, your own CSV and JSON files (read on the server, kept in the session's memory
  only, 5 MB and 100,000 rows at most), and the pivot module's ticket showcase. A language switch
  (English, German) and, on the pages with public data, a live switch; `-LiveData` and `-Locale` set
  where the app starts.
- `Get-UDPivotShowcaseData`: answers the app's public API calls from the snapshots shipped in `Data/`
  (with their sources and licences, `Data/SOURCES.md`), or live.

[Unreleased]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot.Demo-v0.6.0...HEAD
[0.6.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot.Demo-v0.5.0...PowerShellUniversal.Component.Pivot.Demo-v0.6.0
[0.5.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot.Demo-v0.4.0...PowerShellUniversal.Component.Pivot.Demo-v0.5.0
[0.4.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot.Demo-v0.3.0...PowerShellUniversal.Component.Pivot.Demo-v0.4.0
[0.3.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot.Demo-v0.2.0...PowerShellUniversal.Component.Pivot.Demo-v0.3.0
[0.2.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot.Demo-v0.1.1...PowerShellUniversal.Component.Pivot.Demo-v0.2.0
[0.1.1]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Pivot.Demo-v0.1.0...PowerShellUniversal.Component.Pivot.Demo-v0.1.1
[0.1.0]: https://github.com/eizedev/powershell-universal-components/releases/tag/PowerShellUniversal.Component.Pivot.Demo-v0.1.0
