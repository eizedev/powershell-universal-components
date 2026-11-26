---
title: Compatibility
description: Which versions of PowerShell Universal and PowerShell and which browsers the modules work with, and how each was tested.
---

# Compatibility

What the modules work with, and how that was tested. A version not named here may work, but nobody
has checked it.

| Works with | Supported | Tested with | How |
| --- | --- | --- | --- |
| PowerShell Universal | 2026.2 and 2026.3 | 2026.2.5 and 2026.3.4 | by hand on PSU test instances, in a browser, before a change to a component is done ([Development](development/index.md#browser-tests-on-psu)) |
| PowerShell | 7.4 or later, in the PSU environment the app runs in | the PowerShell 7 of GitHub's runner, not pinned; 7.4 itself is not tested | Pester tests on every pull request, and each built component module loaded in a new process |
| Browsers | desktop browsers built on Chromium, Firefox and WebKit | Chromium, Firefox and WebKit, the engine of Safari | Playwright: the components on this site on every pull request, the showcase apps on PSU by hand |
| pivotkit's command line, for `Invoke-UDPivotReport -Engine Node` | what [Two engines](pivot/reports.md#two-engines) names | pivotkit-cli 0.5.0, 0.6.0 and 0.7.0 | the pivot module's opt-in tests against the real command line ([Development](development/index.md#report-command-against-the-real-pivotkit)) |

Not tested: the Safari app, iOS and Android browsers. Windows PowerShell 5.1 does not load the
modules.

The lowest supported versions of PowerShell Universal and PowerShell are public interface: raising
one is a breaking change ([Versioning](versioning.md#what-is-public-interface)). What a pivot feature
needs from a pivotkit-server is on its page, such as [Rows from a server](pivot/server-rows.md).
