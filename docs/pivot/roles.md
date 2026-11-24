---
title: Roles and your own code
description: "Who may change the shared views of New-UDPivotReport (-AdminRole), the $User and $Roles of the page, and your own code for saving views (-OnSaveTemplate, -OnDeleteTemplate, -OnPublishTemplate)."
---

# Roles and your own code

Who may change shared views in a [template store](stores.md), and how to handle saving views
with your own code instead of a store.

## Who may change shared views: `-AdminRole`

`-AdminRole` names PSU roles (`$Roles`), for example `-AdminRole 'Administrator'` or a role of your own
from claims mapping. A reader with one of them gets:

- **Publish as shared view** next to each of their own views (asked in a level of the menu), and **Save “…”** on a
  shared view they loaded (after "Replace the shared view “…” for everyone?"),
- a delete button on every shared view, and
- the **admin panel** under the report: the current view as JSON, the columns with the type pivotkit
  reads them as, their distinct and blank values, how long the server took (converting the data, the
  whole `New-UDPivotReport`) and the browser (pivotkit's encode, pivot and grid of the last change), the
  number of rows, columns and templates, and the store. pivotkit's menus have no place for an app's own
  entries, so the panel is the module's own, collapsed until it is opened.

The browser only shows what the server allows. The checks that count run on the server, in the event
handlers the module registers for the store: every save, publish and delete reads `$User` and
`$Roles` of that event (set by PSU per request) and refuses a shared view without the role, whatever
the browser sends: "Only admins can change shared views." A reader's own views are found by their
`$User` only. Without a signed-in user (an app without authentication: `$User` is not defined there,
measured) the server cannot tell readers apart: their own views then stay in the browser (as
`-TemplateStore Browser`), and shared views come from the store.

### $User and $Roles of the page

`New-UDPivotReport` reads `$User` and `$Roles` of the code that calls it to list the reader's views and
to decide what the menu offers. That works in page code, `New-UDDynamic` and event handlers. A script
block or function defined in the app script does not see them (it runs in the session state it was
created in; measured on PSU 2026.2.5 and 2026.3.4): call the report there with `-UserName $User -Roles $Roles`,
taken from the page that calls the function.

```powershell
function Show-Tickets { param($UserName, $Roles) New-UDPivotReport -Id 'tickets' -Data $tickets -TemplateStore $store -AdminRole 'Administrator' -UserName $UserName -Roles $Roles }
New-UDPage -Name 'Tickets' -Content { Show-Tickets -UserName $User -Roles $Roles }
```

The event handlers always use the event's own `$User` and `$Roles`, not these parameters. A store keeps
what the module registered for it in the PSU process (keyed by app, report and settings), so the
handlers of a page find it after it was rendered; after a restart of the app the reader reloads the
page ("This page is out of date (the app was restarted); reload it.").

## Your own code: `-OnSaveTemplate`, `-OnDeleteTemplate`, `-OnPublishTemplate`

For full control, handle the events yourself instead of a store (the two cannot be combined):

| Parameter | `$EventData` |
| --- | --- |
| `-OnSaveTemplate` | `name`, `view`, `json`, `scope` (`user`) |
| `-OnDeleteTemplate` | `name`, `scope` (`user` or `shared`, the group of the entry) |
| `-OnPublishTemplate` | `name`, `view`, `json`; offered only to readers with a role of `-AdminRole` |

Save current view and Publish send the name of a view that exists when the reader saves over it:
replace that view (by its name, the same characters in the same case), do not add a second one.

The view comes from the browser: check it with `ConvertFrom-UDPivotView` (or write it with
`ConvertTo-UDPivotViewFile`, which checks it) before it is stored, check the name, never build a path
or a query from it, and check `$Roles` again in `-OnPublishTemplate` and for a shared delete - the
browser only hides the buttons. Return `@{ error = '...' }` to refuse with that text; a script block
that throws refuses too, but the reader then sees only "the server reported an error". For a file
everyone reads, pass `ConvertTo-UDPivotViewFile` an https `-SchemaUrl`: a path takes its origin from
the request's headers.

```powershell
New-UDPivotReport -Id 'tickets' -Data $tickets -Templates $templates -AdminRole 'Administrator' -OnSaveTemplate {
    try {
        $json = ConvertTo-UDPivotViewFile -View $EventData.view -Name $EventData.name -SourceId 'tickets'
        # store $json for $User: a database row, a file named after a hash of $User
    }
    catch { @{ error = $_.Exception.Message } }
} -OnPublishTemplate {
    if ($Roles -notcontains 'Administrator') { return @{ error = 'Only admins can change shared views.' } }
    # store $EventData for everyone
}
```

Event handlers run in a runspace of their own: functions defined in the app script are not there, and
PSU does not load the module by itself. Call `Import-Module PowerShellUniversal.Component.Pivot` in a
handler that uses the module's commands.

The [showcase app](https://github.com/eizedev/powershell-universal-components/blob/HEAD/modules/PowerShellUniversal.Component.Pivot/examples/showcase.ps1)
has no sign-in and shows `-Templates`, `-TemplatePath` and the file store (its readers' own views stay
in the browser);
[templates.ps1](https://github.com/eizedev/powershell-universal-components/blob/HEAD/modules/PowerShellUniversal.Component.Pivot/examples/templates.ps1)
is an app with sign-in, own views on the server, publishing for two roles and the admin panel.
