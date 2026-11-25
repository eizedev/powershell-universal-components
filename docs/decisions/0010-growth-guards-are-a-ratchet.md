---
title: The growth guards are a ratchet
description: Code, tests and docs may not grow by appending; CI compares each offender over a limit with a committed baseline that may only shrink, and raising it needs a reason in the pull request.
status: accepted
date: 2026-11-22
---

# 0010 The growth guards are a ratchet

Source: [#166](https://github.com/eizedev/powershell-universal-components/pull/166)

## Context and Problem Statement

PowerShell files and functions, JavaScript functions and docs pages grew by appending. Some were
already over any sensible limit when the guards came (#166), so a plain limit would have failed CI
until all of them were rewritten.

## Considered Options

- Fixed limits that fail every file over them.
- A ratchet: limits, with the offenders of the day in a baseline that may only shrink.

## Decision Outcome

Chosen option: a ratchet (#166), as pivotkit's `scripts/growth.js` does. `build/growth.js` measures
four guards, each a CI step of its own: PowerShell lines per file and function, JavaScript lines and
complexity per function, duplicated JavaScript and docs lines per page and in total.
`build/growth-baseline.json` holds the offenders over a limit.

- A new or grown offender fails.
- A smaller one fails until `node build/growth.js --update` lowers the baseline in the same pull
  request, so the room it left cannot be filled again unseen.
- `--update --accept-growth` raises an entry; the pull request says why.

The limits start where the outliers begin: PSScriptAnalyzer has no rule for length, and #166 found no
common number for PowerShell.

### Consequences

- Good: the guards could start on the day they came, and every offender can only get smaller.
- Bad: lines are a weak measure for docs, and the docs total is one number, so two pull requests that
  each change it can pass alone and need an `--update` together.
