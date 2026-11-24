# Changelog

All notable changes to PowerShellUniversal.Component.ECharts.Demo. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

### Added

- The Basics page has a chart whose last click and zoom a button reads with `Get-UDElement`.

### Changed

- Requires PowerShellUniversal.Component.ECharts 0.3.1, where `Get-UDElement` works for charts
  ([#159](https://github.com/eizedev/powershell-universal-components/issues/159)).
- The Bars page names its last card "Monthly trend as stacked bars, close together", which it shows.
  The diverging survey chart lost an `-Options` entry that changed nothing.
- The help and README say that the generated data counts its dates from today.

## [0.3.0] - 2026-11-09

### Changed

- Requires PowerShellUniversal.Component.ECharts 0.3.0.
- Two stacked bar charts with ten series each show the tooltip of the hovered segment and the total,
  and the same chart with `-TooltipMode Axis`.

## [0.2.0] - 2026-11-06

### Changed

- Requires PowerShellUniversal.Component.ECharts 0.2.0.
- Charts of job and support states (backup nights, backup windows, jobs per hour, VMs by support
  status) colour each state the same in every chart with `-ColorMap` instead of a palette in the order
  the states happen to appear.

## [0.1.0] - 2026-11-06

### Added

- `New-UDEChartShowcase`: the showcase app of PowerShellUniversal.Component.ECharts as a module.

[Unreleased]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.ECharts.Demo-v0.3.0...HEAD
[0.3.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.ECharts.Demo-v0.2.0...PowerShellUniversal.Component.ECharts.Demo-v0.3.0
[0.2.0]: https://github.com/eizedev/powershell-universal-components/compare/PowerShellUniversal.Component.ECharts.Demo-v0.1.0...PowerShellUniversal.Component.ECharts.Demo-v0.2.0
[0.1.0]: https://github.com/eizedev/powershell-universal-components/releases/tag/PowerShellUniversal.Component.ECharts.Demo-v0.1.0
