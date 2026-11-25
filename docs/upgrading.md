---
title: Upgrading
description: How to update a module on the PowerShell Universal server, and what to change in your apps for the newest release of each module.
---

# Upgrading

For everyone who runs the modules on a PSU server. The first part says how to update. The second
lists the changes of each module's newest release that need your action, and those of the next
release once `main` has any. Every other change is in the module's `CHANGELOG.md`.
[Versioning](versioning.md) says which releases may break things.

## Update a module { #update }

Read [what changed](#changes) first.

1. Install the new version of each module you use, the way you installed it:

    ```powershell
    Update-PSResource -Name PowerShellUniversal.Component.Pivot                    # the newest version
    Install-PSResource -Name PowerShellUniversal.Component.Pivot -Version <x.y.z>  # a version you name
    ```

    Both put the new version in a folder of its own, next to the old one. From a release zip, copy
    the new `<version>` folder next to the old one in `Modules/<Module>/`.

2. Restart PSU. PowerShell imports the newest version it finds in the folder, but a process that has
    already imported the module keeps that version.
3. Readers reload their open pages. The bundle's file name holds a hash of its content, so a reload
    fetches the new code.
4. Remove the old version folder once nothing uses it. Installing a new version does not remove it.

What to check:

- **Every module carries its own copy of the code the modules share.** A fix in that code reaches a
  module only with that module's own release. Update every module you use.
- **Readers' views (Pivot)** live outside the module folder: in the reader's browser, in
  `pivot-views` next to the repository (`New-UDPivotFileTemplateStore`), or in your own storage
  (`New-UDPivotTemplateStore`). A release refuses view files of a newer format than it reads, so
  check before you go back to an older one: [View files](pivot/templates.md#view-files).
- **A published folder for the pivot schema** names the old version folder:
  [Your own copy of the schema](pivot/schema.md#your-own-copy-of-the-schema).
- **A showcase app** requires a minimum version of its component module. Update the component
  module first.

## What changed { #changes }

Each entry names who is affected and what to do. Releases not listed here need no action.

### In the next release { #next }

ECharts module:

- **The chart's own texts follow `-Locale`**, or the browser's language without it: the toolbox, "Total"
  in a stack's tooltip, the box plot's statistics and its "Outliers" series, the histogram's "Count"
  axis, the candlestick's "Price" and "Volume" series, and "No data".
    - Who is affected: an app with a `-ColorMap` entry or a click handler that names "Outliers",
      "Volume" or "Price".
    - What to do: set `-Locale` on that chart and name the series in that language, or set
      `-Locale en-US` to keep the English names.

### ECharts 0.3 { #echarts }

- **A tooltip of a bar, line, area or step chart shows the element under the pointer**, with the
  stack's total for a stacked segment, instead of every series at that position.
    - Who is affected: readers who compare the series of a position in the tooltip.
    - What to do: `-TooltipMode Axis` lists every series at the position.

### Pivot 0.10 { #pivot }

- **A reader's CSV or Excel file with numbers such as `1,234` or `1.500`** is read in the notation of
  the report's locale, with a note that says so.
    - Who is affected: readers of a report with `-AllowImport` who load such files.
    - What to do: check such a column after the update.
- **`-Labels` has no key `settingsShort`.**
    - Who is affected: an app that sets it.
    - What to do: remove the key.
- **A shared view of a template store takes no origin from the request's headers** for a
  `-SchemaUrl` path. It takes the origin of an https `PSU_COMPONENT_PIVOT_SCHEMA_URL`, else
  pivotkit's schema address.
    - Who is affected: an app that publishes shared views with a `-SchemaUrl` path and no https default.
    - What to do: to keep your own address in them, set `PSU_COMPONENT_PIVOT_SCHEMA_URL` to it.

### Older releases { #older }

The breaks of every release, marked **Breaking:**, are in each module's `CHANGELOG.md`:
[ECharts](https://github.com/eizedev/powershell-universal-components/blob/HEAD/modules/PowerShellUniversal.Component.ECharts/CHANGELOG.md),
[Perspective](https://github.com/eizedev/powershell-universal-components/blob/HEAD/modules/PowerShellUniversal.Component.Perspective/CHANGELOG.md),
[Pivot](https://github.com/eizedev/powershell-universal-components/blob/HEAD/modules/PowerShellUniversal.Component.Pivot/CHANGELOG.md),
[ECharts showcase app](https://github.com/eizedev/powershell-universal-components/blob/HEAD/modules/PowerShellUniversal.Component.ECharts.Demo/CHANGELOG.md),
[Pivot showcase app](https://github.com/eizedev/powershell-universal-components/blob/HEAD/modules/PowerShellUniversal.Component.Pivot.Demo/CHANGELOG.md).
