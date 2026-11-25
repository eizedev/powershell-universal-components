# What the modules are (and are not)

The modules add charts, a datagrid and a pivot report builder to PowerShell Universal (PSU) apps.
Each is a PowerShell module you install on its own. You pass the data as it comes, from SQL, REST
or any PowerShell command, and the component draws it in the browser. This page says who the
modules are for, what they are not, and what a change delivers. The [README](README.md) lists the
modules.

## Who they are for

I check every change against these three roles.

| Role | Wants | Success means |
| --- | --- | --- |
| Reader | to understand the data in an app: a chart, a grid or a pivot report | it reads at once, in light and dark mode, on a wide screen, and on a phone |
| App author or PSU admin | to put data into an app and run it on their PSU server | one command with the data as it comes, no JavaScript |
| Developer | to build on the modules: themes, template stores, reports from scripts, a change to a module | stable commands and formats, clear errors, docs that describe how it works now |

## What they are not

| Not | Instead |
| --- | --- |
| A chart, grid, or pivot engine of their own | Apache ECharts, Perspective and pivotkit draw. The modules connect them to PSU |
| Access control for data | remove the rows and columns a reader must not see before `-Data` |
| A UI framework next to PSU's | the components use the React that PSU provides and follow PSU's light and dark theme |
| A product of Devolutions | an independent, MIT-licensed project |

## What a change delivers

A change makes the product better for at least one of the three roles and keeps the
promises on the [versioning page](docs/versioning.md). [CONTRIBUTING.md](CONTRIBUTING.md) has the steps and checks.
