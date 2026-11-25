---
title: The pivot module's dark values follow the report's theme
description: The pivot module's psu.css writes its dark values for pivotkit's data-pk-theme on the report, never for the page's data-theme, so an export from a dark app takes the light colours.
status: accepted
date: 2026-11-14
---

# 0009 The pivot module's dark values follow the report's theme

Sources: [#66](https://github.com/eizedev/powershell-universal-components/pull/66), [#104](https://github.com/eizedev/powershell-universal-components/pull/104)

## Context and Problem Statement

The pivot report follows PSU's light and dark mode: it reads `<html data-theme>` and sets pivotkit's
`data-pk-theme` on its own root (#66). The Excel export reads the light theme, and the HTML report
both, by showing that theme on the report for a moment. A dark value written for the page's
`data-theme` stays in force while the report shows its light theme, so it reaches the file (#104).

## Considered Options

- Dark values on the page's `:root[data-theme="dark"]`.
- Dark values on pivotkit's `[data-pk-theme="dark"]` of the report.

## Decision Outcome

Chosen option: pivotkit's `[data-pk-theme="dark"]` (#104). `psu.css` writes its dark defaults for
that attribute and has no `data-theme` selector. An app's corporate dark values name both,
`:root[data-theme="dark"], .ud-pivot-report [data-pk-theme="dark"]`, as `docs/pivot/themes.md` shows,
so one stylesheet themes the ECharts module and the report. `tests/js/pivot.test.js` checks
`psu.css` and the documented stylesheet.

### Consequences

- Good: an export or HTML report from a dark app has the colours of the theme it shows; a report
  pinned to one theme with `-Theme` keeps it.
- Bad: an app's stylesheet needs a selector for the report besides the page's.
