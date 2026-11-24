# Changelog

All notable changes to PowerShellUniversal.Component.Perspective. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

### Added

- `Private/SHARED.txt` in the built module: the content hashes of the repository's `shared/` code it was
  built from, to compare two builds or releases.
- A toolbar above every viewer: **Edit view** opens and closes the editor, **Table** and **Chart** switch
  between the grid and the chart the reader picked last (`-ChartPlugin`, Y Bar by default). `-Labels`
  translates it, `-NoToolbar` hides it.
- `examples/showcase.ps1`: an app with pages for tickets, assets across source systems and costs, and
  one that explains the three steps of the editor.

### Changed

- `ConvertTo-PSUComponentData`, the data conversion all modules share, keeps its C# converter in
  `RowConverter.cs` and its helpers one function per file. The rows it returns are unchanged.
- Data conversion is about ten times faster (a DataTable of 5000 rows and 12 columns: 2.4 to 2.9 s
  before, about 40 ms now, measured on a PSU test instance): no function call per cell, and large
  DataTables go through a small class compiled on first use (Add-Type, once per PSU process). The rows
  the component gets are the same as before.

### Fixed

- In dark mode, the chart picker at the top of the editor no longer turns white under the mouse.
- When new rows hold a value the table refuses, the viewer frees the half-built table in its worker.
  Before, its memory stayed until the reader closed the page.

## [0.1.0] - 2026-11-06

### Added

- `New-UDPerspective` on Perspective 5.7 (`@perspective-dev`): datagrid, pivot (`-GroupBy`, `-SplitBy`,
  `-Aggregates`) and charts, starting view from `-Plugin`, `-Columns`, `-Sort`, `-Filter`, `-Config`;
  readers rearrange it in the configuration panel.
- Data straight from DataTables, REST results and PowerShell objects with the original column names
  and typed columns (dates as dates).
- `-OnClick` with the clicked row and its group/split filter; light and dark theme following the app;
  WebAssembly bundled, no internet access needed.

[Unreleased]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.Perspective-v0.1.0...HEAD
[0.1.0]: https://github.com/eizedev/powershell-universal-components/releases/tag/PowerShellUniversal.Component.Perspective-v0.1.0
