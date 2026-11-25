---
title: One function per file in a split module
description: A module with more than a few functions keeps each exported function in Public/ and each helper in Private/, one per file; the .psm1 only loads them.
status: accepted
date: 2026-11-22
---

# 0006 One function per file in a split module

Sources: [#163](https://github.com/eizedev/powershell-universal-components/issues/163), [#164](https://github.com/eizedev/powershell-universal-components/pull/164), [#171](https://github.com/eizedev/powershell-universal-components/pull/171),
[#173](https://github.com/eizedev/powershell-universal-components/pull/173)

## Context and Problem Statement

The pivot module's `.psm1` had grown to 4,948 lines with 66 functions and two C# sources in
here-strings (#163). The ECharts module's held seven functions in 329 code lines (#173).

## Considered Options

- One module file, built from the sources or written by hand (not discussed in a source).
- One function per file, dot-sourced by the `.psm1` at import.

## Decision Outcome

Chosen option: one function per file (#164), applied to the pivot module in #171 and the ECharts
module in #173.

- Exported functions live one per file in `Public/`, helpers in `Private/`. The `.psm1` only loads them.
- C# lives in `.cs` files, never in here-strings.
- Perspective and the demo modules have one to three functions and stay in their `.psm1`.

The reasons recorded in #171: dot-sourcing keeps the tested source and the shipped module the same,
and error positions point to the real files. Measured there outside PSU: about 11 ms more per runspace
import for the pivot module. If that matters on PSU, the build can merge the files without changing the
source layout.

### Consequences

- Good: a function does one job and can be found by its file name.
- Bad: a module loads many files at import.
