---
title: Each module is released on its own
description: Each module has its own version and CHANGELOG and is published to the PowerShell Gallery from a tag on main, after a maintainer's approval.
status: accepted
date: 2026-11-06
---

# 0008 Each module is released on its own

Sources: [#4](https://github.com/eizedev/powershell-universal-components/issues/4), [#25](https://github.com/eizedev/powershell-universal-components/pull/25), [#29](https://github.com/eizedev/powershell-universal-components/pull/29)

## Context and Problem Statement

The repository builds several modules. People install them with `Install-PSResource` from the
PowerShell Gallery (#4). How are they versioned and published?

## Considered Options

- One version and one release for all modules (not discussed in a source).
- One version, CHANGELOG and release per module.

## Decision Outcome

Chosen option: one release per module, from a tag `<Module>-v<Version>`.

- Each module keeps its own SemVer `ModuleVersion` and `CHANGELOG.md`.
- `release.yml` tests, builds and checks the tagged module without secrets. Only after a maintainer
  approves the environment `psgallery`, which holds the gallery key, does a second job publish it (#25).
- Only a commit on main is released, never one of a branch (#29).

Why one release per module: reason not recorded. The reason recorded in #29 for the main check: the
publishing job runs the tagged commit's `Publish-Module.ps1` with the gallery key, and a tag on a
branch would run that branch's unreviewed script.

The [versioning page](../versioning.md) says when an update can break an app.

### Consequences

- Good: a fix to one module does not release the others.
- Bad: a module that requires another one (a demo requires its component module) is released after it.
