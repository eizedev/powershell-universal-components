---
title: Record decisions as decision records
description: The modules record lasting decisions as numbered MADR records in docs/decisions; decisions shared with pivotkit stay in pivotkit's records.
status: accepted
date: 2026-11-25
---

# 0001 Record decisions as decision records

Source: [#217](https://github.com/eizedev/powershell-universal-components/issues/217)

## Context and Problem Statement

Lasting decisions of the modules lived in AGENTS.md, in pull requests and in comments in the code.
A rule there says what to do, but rarely why, and nothing marks which rules are decisions that a
change must not undo by accident.

## Considered Options

- Keep decisions in AGENTS.md and pull requests (not discussed in a source).
- Record each decision in `docs/decisions/`, as pivotkit does.

## Decision Outcome

Chosen option: decision records in `docs/decisions/`, in the minimal template of
[MADR](https://adr.github.io/madr/), with the same rules as
[pivotkit's record 0001](https://pivotkit.eize.dev/decisions/0001-record-decisions/).

- One decision per file, numbered, about one page. Each record links its issue or pull request.
- An accepted record is not edited. A change is a new record that supersedes the old one. Both link
  each other.
- Reversible choices with little impact get no record.
- A decision that spans pivotkit and these modules lives in pivotkit's records. A record here links
  it instead of repeating it.
- `node build/decisions.js` writes the index; `tests/js/decisions.test.js` checks the records and the index.

Status means:

| Status | Meaning |
| --- | --- |
| accepted | binding. A change that conflicts with it stops and proposes a new record |
| proposed | context. Not binding yet |
| superseded | history. It links the record that replaced it |

Where no source gives the reason, a record says "reason not recorded".

A record's `date` is the day it was accepted. A record of a decision made before this folder existed
carries the day its source was merged.

### Consequences

- Good: a change can be checked against the accepted records before it starts.
- Bad: the records and the index need upkeep.
