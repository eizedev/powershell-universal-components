# Changelog

All notable changes to PowerShellUniversal.Component.Pivot.Demo. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

### Fixed

- Your data: views saved in the browser belong to the uploaded file. The report's `-SourceId` is the
  file name and a hash of its column names, so a file with other columns no longer offers the views of
  the last one, and the same file uploaded again finds its views
  ([pivotkit#116](https://github.com/eizedev/pivotkit/issues/116)).
- Your data: a file name longer than 120 characters no longer fails the page (the report's `-Label`
  takes at most 120); the page shows it shortened.

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
