---
title: The theme tokens are a contract
description: The --psu-chart-* CSS custom properties are the contract between the modules and an app's stylesheet; renaming or removing one is a breaking change.
status: accepted
date: 2026-11-08
---

# 0007 The theme tokens are a contract

Sources: [#2](https://github.com/eizedev/powershell-universal-components/issues/2), [#23](https://github.com/eizedev/powershell-universal-components/pull/23), [#66](https://github.com/eizedev/powershell-universal-components/pull/66)

## Context and Problem Statement

A company wants its colours in every chart of an app without passing them to each one (#2). #23 added
CSS custom properties that the ECharts module reads from the app's stylesheet. The pivot module came
later and needed the same design.

## Considered Options

- Separate properties per module (not discussed in a source).
- One set of `--psu-chart-*` tokens that every module reads.

## Decision Outcome

Chosen option: one set of `--psu-chart-*` tokens (#66). Today the ECharts module reads them in
`Components/themes.js` and the pivot module in `psu.css`; `docs/echarts/themes.md` documents them.

- A token is added to that page and to its reader together.
- Renaming or removing a token is a breaking change in every module.

The reason recorded in #23: charts take a company's design without passing `-Palette` to each one.
#66 states the contract: the tokens are the interface between the modules and an app's stylesheet.

### Consequences

- Good: one stylesheet themes every module of an app.
- Bad: a token cannot be renamed or removed without a breaking release of every module.
