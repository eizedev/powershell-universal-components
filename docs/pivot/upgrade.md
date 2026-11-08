---
title: Upgrade notes
description: "What changes for apps and readers between builds of PowerShellUniversal.Component.Pivot: the Views menu, scopes of templates, the template events, view files."
---

# Upgrade notes

What an app has to look at when it moves to a newer build of the module. The complete list of
changes is the module's [CHANGELOG](https://github.com/eizedev/powershell-universal-components/blob/main/modules/PowerShellUniversal.Component.Pivot/CHANGELOG.md).

## From the first builds of 0.1.0 (pivotkit before its Views menu)

**Readers** find the templates in **Views** (the Templates menu is gone), in two groups: Shared views
and My views. Views also holds Copy view as JSON, Download view and Load view…. Toolbar buttons that do
not fit move into **More**, Views among the first: in the showcase's report in a window 1,440 pixels
wide, Views is in More (measured on PSU 2026.3.4).

**Apps**:

- `-Templates` entries get a group: `Scope = 'shared'` or `'user'`. Without it, an entry with
  `Deletable = $true` is listed under My views and every other one under Shared views, which is what
  an app that passed its readers' saved templates as deletable entries wants. Set `Scope` on every
  entry where that is not right (a shared view admins may delete).
- `$EventData` of `-OnDeleteTemplate` has `scope` (`user` or `shared`): check it before deleting, and
  check `$Roles` for a shared one. `-OnSaveTemplate` gets `scope = 'user'`.
- Instead of storing templates in your own `-OnSaveTemplate` and `-OnDeleteTemplate`, consider
  `-TemplateStore` with `New-UDPivotFileTemplateStore` or `New-UDPivotTemplateStore`, and `-AdminRole`
  for shared views ([Templates, view files and roles](templates.md)). The two cannot be combined in one
  report.
- Store views as [view files](templates.md#view-files) (`ConvertTo-UDPivotViewFile`): the format
  pivotkit's Download view writes and Load view reads, with the data's id and a version.
- Templates, views and links now carry the report's data id (`-SourceId`, default `-Id`): loading a view
  made for another id asks first. Give reports of the same data the same `-SourceId`.
- The showcase app keeps its readers' views with `New-UDPivotFileTemplateStore` in `pivot-views` next
  to the repository; the one JSON file per user in `pivot-templates` of its first version is not read.
- New, optional: `-SettingInfo`, `-FieldList`, `-Grow`, `-SchemaUrl`, `-SourceName`,
  `-OnPublishTemplate`, `-TemplatePath`.
