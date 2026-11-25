---
title: Security
description: What runs on the PowerShell Universal server and what in the browser, what the modules treat as untrusted, and which network requests they make; with links to each module's security notes.
---

# Security

For app authors and PSU admins who decide what an app may show and do. Each module's page has the
details; how to report a vulnerability is in
[SECURITY.md](https://github.com/eizedev/powershell-universal-components/blob/HEAD/SECURITY.md).

## What runs where

| Where | What |
| --- | --- |
| PSU server, in the app's PowerShell | the module's commands: they convert the data, read files the app names (themes, view files, template stores) and return what PSU sends to the browser |
| Browser | the module's JavaScript bundle, served by PSU: it draws the component, filters, exports and copies from the rows it got |

Every row in `-Data` reaches the browser, with every column. Select what a reader may see first
(`Select-Object`, the SQL query). The bundles bring their libraries along and load no code from
elsewhere.

## What the modules treat as untrusted

- the data (`-Data`): the components show its values as text and never run them as HTML or code
- what comes back from the browser: a view from a link, the address bar or a save, and `$EventData`
  (which the app checks as well)
- view files, from `-TemplatePath` or a template store
- a file a reader loads into a pivot report (`-AllowImport`)
- the request headers the pivot module takes the origin of a view file's `$schema` from

What the modules trust because it comes from the app author, such as `-Options` or a theme, and
what is not a vulnerability by design:
[SECURITY.md](https://github.com/eizedev/powershell-universal-components/blob/HEAD/SECURITY.md#scope).

## Network requests

- **ECharts** makes none: neither its commands nor its bundle request anything.
- **Perspective** makes none, except the base map tiles of the map charts a reader can pick in the
  editor, which the browser loads from map tile servers
  ([Security notes](perspective/events.md#security-notes)).
- **Pivot** makes requests from the PSU server only, to addresses the app's script names: a
  `-Schema` address, a pivotkit-server and its token endpoint
  ([Network requests](pivot/events.md#network-requests)).
- **The showcase apps** call public web services from the PSU server on their public and live data
  pages ([ECharts showcase](demo.md), [Pivot showcase](pivot/demo.md#public-data-offline-or-live)).

## Each module

- [ECharts: security and limits](echarts/security.md)
- [Perspective: events, security and limits](perspective/events.md#security-notes)
- [Pivot: events, security and limits](pivot/events.md#security-notes)
