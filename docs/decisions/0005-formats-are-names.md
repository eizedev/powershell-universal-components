---
title: Formats are names, never code
description: PowerShell passes formats as names that the bundle resolves; a string from props is never evaluated as code.
status: accepted
date: 2026-11-05
---

# 0005 Formats are names, never code

Source: [#9](https://github.com/eizedev/powershell-universal-components/pull/9)

## Context and Problem Statement

A chart formats axis labels, tooltips and values. Apache ECharts takes formatter functions, but a
component's props reach the browser as JSON from PowerShell.

## Considered Options

- Pass JavaScript as strings and evaluate them in the browser (not discussed in a source).
- Pass a format's name and resolve it in the bundle.

## Decision Outcome

Chosen option: formats are names, resolved in the ECharts module's `Components/formatters.js`. A
string from props is never evaluated as code.

The reason recorded in #9: PowerShell sends no functions. Why a string is never evaluated as code:
reason not recorded.

### Consequences

- Good: data and options in props cannot run script in the browser.
- Bad: a format the modules do not name needs a change to the module.
