# Accessibility

I want the people who read an app built with these modules to be able to use it with a keyboard, a
screen reader or a touch screen. A barrier that a module causes is a bug.

Each module wraps a library and offers what that library offers.

## What the modules offer

- **Pivot**: `New-UDPivotReport` is the pivotkit report, for the pivotkit version the module bundles.
  It works with the keyboard, names its controls and has a text alternative for the chart. See
  pivotkit's [Keyboard and screen readers](https://pivotkit.eize.dev/use/keyboard/). `-Label` names
  the report for screen readers.
- **ECharts**: `New-UDEChart` gives the chart ECharts' generated description for screen readers.
  `-Decal` adds patterns, so series do not rely on colour alone; it is off by default
  ([Themes](https://powershell-universal-components.eize.dev/echarts/themes/)).
  Labels inside filled shapes take dark or white text, whichever contrasts more
  ([Labels on filled shapes](https://powershell-universal-components.eize.dev/echarts/labels/#labels-on-filled-shapes)).
- **Perspective**: `New-UDPerspective` adds a toolbar with named buttons. The viewer itself is
  Perspective's ([For the app](https://powershell-universal-components.eize.dev/perspective/using/#for-the-app)).

## How it is checked

- The browser tests run the documentation site in Chromium, Firefox and WebKit. They run the
  showcase apps only when a PowerShell Universal instance is set.
- Few of these tests check accessibility, and none runs with a real screen reader.
- pivotkit's own tests cover the pivot report
  ([pivotkit's ACCESSIBILITY.md](https://github.com/eizedev/pivotkit/blob/main/ACCESSIBILITY.md)).

No module claims a WCAG conformance level. Colours that an app's theme sets are not checked.

## Supported environments

The PowerShell Universal versions and browsers under
[Compatibility](https://powershell-universal-components.eize.dev/compatibility/).

## Known limitations

- You cannot reach an ECharts chart's points, tooltips or toolbox buttons with the keyboard. Show the
  data beside it, for example in a table
  ([Limits](https://powershell-universal-components.eize.dev/echarts/security/#limits)).
- The default ECharts palette is not checked for contrast.
- The Perspective viewer is not tested with a keyboard or a screen reader here.
- The pivot report's limitations are in pivotkit's
  [ACCESSIBILITY.md](https://github.com/eizedev/pivotkit/blob/main/ACCESSIBILITY.md#known-limitations).

## Report a barrier

Open an
[accessibility issue](https://github.com/eizedev/powershell-universal-components/issues/new?template=accessibility.yml).
Say what you tried to do, what happened, and which browser and assistive technology you used.
You do not need to tell me anything about yourself. Leave out real data. If the barrier is in
pivotkit itself, I move the issue there.
