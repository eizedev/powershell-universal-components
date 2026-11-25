---
title: Exact versions and own wrappers for npm packages
description: Every npm package is pinned to an exact version with a lock file, and a small own wrapper is preferred over a wrapper package.
status: accepted
date: 2026-11-05
---

# 0004 Exact versions and own wrappers for npm packages

Source: [#9](https://github.com/eizedev/powershell-universal-components/pull/9)

## Context and Problem Statement

Each module bundles npm packages into the JavaScript it ships to every reader of an app. A package
that changes under a version range, or a wrapper package that is taken over, ships its code with the
next build.

## Considered Options

- Version ranges and wrapper packages such as `echarts-for-react` (not discussed in a source).
- Exact versions with a lock file, and an own wrapper around the library.

## Decision Outcome

Chosen option: every package pinned to an exact version with a lock file, and a small own wrapper
preferred over a wrapper package.

The reason recorded in #9: chart libraries have been hijacked on npm (`echarts-for-react`, May 2026).

### Consequences

- Good: a build ships exactly the reviewed versions.
- Bad: every update is a pull request of its own (Dependabot), and the own wrappers need upkeep.
