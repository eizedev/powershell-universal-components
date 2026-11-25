---
title: The growth guards are a ratchet
description: Code, tests and docs may not grow by appending; CI compares each offender over a limit with a committed baseline that may only shrink, and raising it needs a reason in the pull request.
status: accepted
date: 2026-11-22
---

# 0010 The growth guards are a ratchet

Source: [#166](https://github.com/eizedev/powershell-universal-components/pull/166)

## Context and Problem Statement

Code, tests and docs should not grow by appending (`build/growth.js`). When the guards came (#166),
several PowerShell functions, JavaScript functions and docs pages were already over the limits the
guards set.

## Considered Options

- Fixed limits that fail every file over them (not discussed in a source).
- A ratchet: limits, with the offenders of the day in a baseline that may only shrink.

## Decision Outcome

Chosen option: a ratchet (#166), as pivotkit's `scripts/growth.js` does. `build/growth.js` has four
guards, each a CI step of its own. Three are ratchets: PowerShell lines per file and function,
JavaScript lines and complexity per function, and docs lines per page with their total, which may
drift by a margin. `build/growth-baseline.json` holds their offenders. The fourth, duplicated
JavaScript, has a fixed threshold in `.jscpd.json`.

- A new or grown offender fails.
- A smaller one fails until `node build/growth.js --update` lowers the baseline in the same pull
  request, so the room it left cannot be filled again unseen.
- `--update --accept-growth` raises an entry; the pull request says why.

The limits start where the outliers begin: PSScriptAnalyzer has no rule for length, and #166 found no
common number for PowerShell. Why a ratchet rather than fixed limits: reason not recorded.

### Consequences

- Good: the guards started without rewriting the offenders first, and each offender in the baseline
  can only get smaller.
- Bad: lines are a weak measure for docs, and the docs total is one number, so two pull requests that
  each change it can pass alone and need an `--update` together.
