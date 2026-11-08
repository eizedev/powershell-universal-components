# Changelog

All notable changes to PowerShellUniversal.Component.Pivot.Demo. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

### Added

- `New-UDPivotShowcase`: the showcase app of PowerShellUniversal.Component.Pivot as a module, with
  pages for the three pivot examples of the documentation on endoflife.date, daily weather of six
  cities from Open-Meteo, your own CSV and JSON files (read on the server, kept in the session's memory
  only, 5 MB and 100,000 rows at most), and the pivot module's ticket showcase. A language switch
  (English, German) and, on the pages with public data, a live switch; `-LiveData` and `-Locale` set
  where the app starts.
- `Get-UDPivotShowcaseData`: answers the app's public API calls from the snapshots shipped in `Data/`
  (with their sources and licences, `Data/SOURCES.md`), or live.
