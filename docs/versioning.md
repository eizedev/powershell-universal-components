---
title: Versioning
description: How the modules number their releases, when an update can break your app, and what counts as their public interface.
---

# Versioning

This page says when an update of a module may break your app. Each module has its own version and
its own `CHANGELOG.md`, and has releases of its own.

## The promise

### Before 1.0.0

The modules are 0.x and under active development.

- A minor release, from 0.y to 0.(y+1), can break things. The modules break as little as possible.
- The module's `CHANGELOG.md` says what changed and marks each break **Breaking**;
  [Upgrading](upgrading.md) says what to do. Read them before you update.

To choose when you update, install a fixed version:

```powershell
Install-PSResource -Name PowerShellUniversal.Component.Pivot -Version <x.y.z>
```

### From 1.0.0

A module that reaches 1.0.0 follows [Semantic Versioning](https://semver.org/):

| Release | May contain |
| --- | --- |
| Patch (1.2.3 to 1.2.4) | fixes |
| Minor (1.2 to 1.3) | additions |
| Major (1 to 2) | changes that break the public interface |

Each module reaches 1.0.0 on its own.

## What is public interface

These are the parts a break can hit:

- The commands a module exports, their parameters and the values they take, and what they return.
- The error ids of a command, such as `PivotServerUnreachable`.
- The `--psu-*` CSS custom properties an app's stylesheet sets
  ([themes](echarts/themes.md), [pivot themes](pivot/themes.md)).
- The data and view formats: the rows a component takes, a pivot view and the view file, with its
  `$schema`.
- The keys of `-Labels`.
- Events: when a script block such as `-OnClick` runs and the `$EventData` it gets, and the answer to
  `Get-UDElement`.
- Environment variables, such as `PSU_COMPONENT_PIVOT_SCHEMA_URL`.
- The addresses of the showcase apps' pages where the docs name them.
- The lowest supported versions of PowerShell Universal and PowerShell ([compatibility](compatibility.md)).

These are not public interface and can change in any release:

- The look: colours, sizes, and spacing.
- The wording of messages. Match on the error id, not on the text.
- The code in a module's `Private/` folder and the bundled JavaScript libraries.
- What `-Options` passes to Apache ECharts or `-Config` to Perspective: those libraries define it.
