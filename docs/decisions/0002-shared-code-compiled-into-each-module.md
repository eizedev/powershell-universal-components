---
title: Shared code is compiled into each module
description: Code several modules need lives once in shared/ and is copied into each module at build time; there is no common runtime module.
status: accepted
date: 2026-11-05
---

# 0002 Shared code is compiled into each module

Sources: [#9](https://github.com/eizedev/powershell-universal-components/pull/9), [#66](https://github.com/eizedev/powershell-universal-components/pull/66)

## Context and Problem Statement

Several modules need the same code: the bridge to PSU's light and dark theme, column matching, the
answer to `Get-UDElement`, and the data conversion in PowerShell. How do the modules share it?

## Considered Options

- A common runtime module that the component modules require (ruled out by AGENTS.md since #66, not discussed).
- One copy in `shared/`, compiled or copied into each module when it is built.

## Decision Outcome

Chosen option: one copy in `shared/`, built into each module.

- `shared/js/` is compiled into each module's bundle by the shared webpack configuration. It is never
  a runtime dependency between modules (#9).
- `shared/powershell/` is copied into each built module's `Private/` by `build/Copy-SharedCode.ps1`,
  which also writes `Private/SHARED.txt` with the hashes of what was copied (#66).
- Code moves into `shared/` only once a second module needs it (#66).

The reason recorded in AGENTS.md since #66 and in `build/webpack.base.cjs`: each module stays
installable on its own.

### Consequences

- Good: a module installs from the PowerShell Gallery without another module of this repository.
- Bad: a change in `shared/` reaches a module only with that module's next release, so each module
  that uses it needs its own CHANGELOG entry and release.
