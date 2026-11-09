# Changelog

All notable changes to PowerShellUniversal.Component.ECharts.Demo. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versions: [SemVer](https://semver.org/).

## [Unreleased]

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
