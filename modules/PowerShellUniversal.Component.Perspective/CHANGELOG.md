# Changelog

All notable changes to PowerShellUniversal.Component.Perspective. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

### Added

- `New-UDPerspective` on Perspective 5.7 (`@perspective-dev`): datagrid, pivot (`-GroupBy`, `-SplitBy`,
  `-Aggregates`) and charts, starting view from `-Plugin`, `-Columns`, `-Sort`, `-Filter`, `-Config`;
  readers rearrange it in the configuration panel.
- Data straight from DataTables, REST results and PowerShell objects with the original column names
  and typed columns (dates as dates).
- `-OnClick` with the clicked row and its group/split filter; light and dark theme following the app;
  WebAssembly bundled, no internet access needed.
