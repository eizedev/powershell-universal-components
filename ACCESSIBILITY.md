# Accessibility

I want the people who read an app built with these modules to be able to use it with a keyboard, a
screen reader, zoom or touch. A barrier that a module causes is a bug.

Each module wraps a library and inherits what it offers. This page says what that is per module.

## Pivot

`New-UDPivotReport` is the pivotkit report. Its keyboard and screen reader support is pivotkit's:

- every action by keyboard and by a menu, without drag and drop
- named controls, announced moves and status messages
- a text alternative for the chart

[Keyboard and screen readers](https://pivotkit.eize.dev/use/keyboard/) in pivotkit's docs has the
details, and pivotkit's [ACCESSIBILITY.md](https://github.com/eizedev/pivotkit/blob/main/ACCESSIBILITY.md)
how it is checked and what is still open. `-Label` names the report for screen readers; several
reports on one page need one each.

## ECharts

`New-UDEChart` draws with Apache ECharts:

- The chart gets ECharts' generated description for screen readers, with `role="img"`.
- `-Decal` adds patterns, so series do not rely on colour alone
  ([Themes](https://powershell-universal-components.eize.dev/echarts/themes/)).
- Labels on coloured fills take dark or white text, whichever contrasts more.

## Perspective

`New-UDPerspective` shows Perspective's own viewer. Its keyboard and screen reader behaviour comes
from the Perspective project. This repository neither documents nor tests it.

## How it is checked

The browser tests of this repository run the documentation site in Chromium, Firefox and WebKit,
and the showcase apps on a PowerShell Universal instance. They do not check accessibility on their own. pivotkit's tests cover the pivot
report's keyboard, focus and screen reader behaviour. No module claims a WCAG conformance level.
Colours set by an app's theme are not checked.

## Supported environments

The PowerShell Universal versions and browsers under
[Requirements](https://powershell-universal-components.eize.dev/#requirements).

## Known limitations

- An ECharts chart is not a keyboard stop: you cannot move through its points or open its tooltip
  with the keyboard. The data stays reachable through export
  ([Limits](https://powershell-universal-components.eize.dev/echarts/security/#limits)).
- The pivot report's open points are listed in pivotkit's
  [ACCESSIBILITY.md](https://github.com/eizedev/pivotkit/blob/main/ACCESSIBILITY.md#known-limitations).

## Report a barrier

Open an
[accessibility issue](https://github.com/eizedev/powershell-universal-components/issues/new?template=accessibility.yml).
Say what you tried to do, what happened, and which browser and assistive technology you used.
You do not need to tell me anything about yourself. Leave out real data. If the barrier is in
pivotkit itself, I move the issue there.
