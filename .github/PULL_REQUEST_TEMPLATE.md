## Summary

<!-- What changes and why. Link the issue: Fixes #n / Refs #n -->

## Whole-change check

<!--
Needed when the pull request changes docs or code; CI checks for it. Write your answers below this comment.

Docs: each page you touched, read whole and rendered.
- Its reader, and the task they come with.
- Does the reader find what to do in 30 seconds? Is the order by importance? Is every paragraph worth their time?
- How you reshaped it: detail moved to a sub-page and linked, shortened with the full version elsewhere,
  a list or table instead of prose, a section moved where it belongs.
- What you removed or moved, item by item, and where it went.

Code: each function or file you touched, read whole.
- Its job now. One job each; a second job is a split.
- What you extracted or reused.
- Why the rest fits as it is.

A growth guard that fails: the entry, and why the growth is right.
-->

## Checklist

- [ ] Linked issue
- [ ] A fix comes with a test that fails without it; no test weakened, skipped or deleted
- [ ] The pages in `docs/` and the module's `CHANGELOG.md` describe the new state
- [ ] A visible change: checked on a PSU instance in light and dark theme, narrow and wide window, with the events it fires (PSU version: ...)

## Test plan

- [ ] The checks of [Check your change](https://github.com/eizedev/powershell-universal-components/blob/main/CONTRIBUTING.md#check-your-change): those for every change, and those for what this one changes
- [ ] What I ran and saw:
