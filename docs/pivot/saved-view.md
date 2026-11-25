---
title: Several tabs and the reader's view
description: "How New-UDPivotReport keeps a view per browser tab, and how an app keeps the reader's view beyond the tab with -OnViewChange and -SavedView: $Session, $Page or a store per $User."
---

# Several tabs and the reader's view

For app authors whose readers come back to a report and expect their view.

Every browser tab keeps its own view, also two tabs on the same page: nothing needs to be stored on
the server for a reload, a light/dark switch, a `Sync-UDElement` of a surrounding `New-UDDynamic` or a
shared link.

To keep the reader's view beyond the tab (a new tab, another day, another device), store it in
`-OnViewChange` and pass it back as `-SavedView`, never as `-View`:

```powershell
New-UDPivotReport -Id 'tickets' -Data $tickets -View $startView -SavedView $Session:PivotView -OnViewChange {
    Import-Module PowerShellUniversal.Component.Pivot
    $Session:PivotView = ConvertFrom-UDPivotView -InputObject $EventData.json
}
```

`-SavedView` starts a tab that has no view of its own yet; a tab that already shows a view keeps it,
and **Start over** goes back to `-View`. The difference matters because PSU's scopes are not per tab
(measured on PSU 2026.3.4):

| Scope | Shared by | Lifetime |
| --- | --- | --- |
| `$Session:` | all tabs of one browser (one session cookie) | until the session ends (idle timeout) |
| `$Page:` | one tab | until the tab reloads or closes; survives the light/dark switch and `Sync-UDElement` |
| a file or table per `$User` | all browsers and devices of the reader | until the app removes it |

`-View $Session:PivotView` would hand the last change of one tab to every other tab on its next
reload. `$Page:` is per tab but gone after a reload, which the address bar and the tab's storage
already cover.
For a view that follows the reader to other devices, store it per `$User` (as a
[template store](stores.md#template-stores-templatestore) does), either on every change or with an
explicit "save as my default", and pass it as `-SavedView`.

Without `-Id` the report is identified by its page and its place in the app script (the line of the
`New-UDPivotReport` call) together with its column names, so two reports on one page keep their own
views. Set `-Id` if reports are added or removed dynamically, or when one call builds several reports
(a loop): they would share one view otherwise.

Next: [Views](views.md), [Templates, view files and roles](templates.md), [Events, security and limits](events.md).
