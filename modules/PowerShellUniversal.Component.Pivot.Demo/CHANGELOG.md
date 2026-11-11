# Changelog

All notable changes to PowerShellUniversal.Component.Pivot.Demo. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

### Added

- Your data: readers save their views in the browser (`-TemplateStore Browser`), per file: the Views
  menu lists those made for the file shown and those saved without a data source, and the same file
  uploaded again offers them again. All uploaded files share the browser store's limits (100 views,
  500,000 characters).

### Changed

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
