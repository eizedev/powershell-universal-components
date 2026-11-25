---
title: React, ReactDOM and UniversalDashboard come from PSU
description: The bundles take React, ReactDOM and UniversalDashboard from PowerShell Universal at runtime and never bundle them.
status: accepted
date: 2026-11-05
---

# 0003 React, ReactDOM and UniversalDashboard come from PSU

Source: [#9](https://github.com/eizedev/powershell-universal-components/pull/9)

## Context and Problem Statement

PowerShell Universal runs React and its own `UniversalDashboard` object on the page that shows a
component. A module's bundle needs React too. Does it bring its own?

## Considered Options

- Bundle React with each module (not discussed in a source).
- Take React, ReactDOM and `UniversalDashboard` from PSU as webpack externals.

## Decision Outcome

Chosen option: webpack externals (`build/webpack.base.cjs`, AGENTS.md since #9).

- No module bundles React, ReactDOM or `UniversalDashboard`.
- No module depends on a library that needs React 19 or brings its own MUI.

The reason recorded in `build/webpack.base.cjs`: bundling React again breaks hooks. Why a library with
its own MUI is ruled out: reason not recorded.

pivotkit keeps React 18 as its lowest supported version because PowerShell Universal ships it:
[pivotkit's record 0005](https://pivotkit.eize.dev/decisions/0005-react-18-floor/).

### Consequences

- Good: the components use the same React instance as the PSU page.
- Bad: the modules are bound to the React version PSU ships and cannot use a library that needs a newer one.
