# What the modules are (and are not)

The modules add charts, a datagrid and a pivot report builder to PowerShell Universal (PSU) apps.
Each is a PowerShell module you install on its own. You pass the data as it comes, from SQL, REST
or any PowerShell command, and the component draws it in the browser. This page says who the
modules are for, what they are not, and what a change delivers.

## Who they are for

I check every change against these three roles.

| Role | Wants | Success means |
| --- | --- | --- |
| Reader | to understand the data in an app: a chart, a grid or a pivot report | it reads at once, in light and dark mode, on a wide screen, and on a phone |
| App author or PSU admin | to put data into an app and run it on their PSU server | one command with the data as it comes, no JavaScript |
| Developer | to build on the modules: themes, template stores, reports from scripts, a change to a module | stable commands and formats, clear errors, docs that describe how it works now |

## What they are

- **ECharts** (`New-UDEChart`): charts on Apache ECharts.
- **Perspective** (`New-UDPerspective`): the Perspective datagrid with pivot and charts.
- **Pivot** (`New-UDPivotReport`, `Invoke-UDPivotReport`): a pivot report builder on pivotkit, and
  its views as files without a browser.
- **The demo modules**: the showcase apps of ECharts and Pivot.

Every module stays installable on its own. The build compiles code that several modules need into
each of them. A component module never depends on another one at run time.

## What they are not

| Not | Instead |
| --- | --- |
| A chart, grid, or pivot engine of their own | Apache ECharts, Perspective and pivotkit draw. The modules connect them to PSU |
| Access control for data | remove the rows and columns a reader must not see before `-Data` |
| A UI framework next to PSU's | the components use the React that PSU provides and follow PSU's light and dark theme |
| A product of Devolutions | an independent, MIT-licensed project |

## Promises and limits

- **Versions.** Each module has its own version and changelog. Before 1.0.0, a minor release can
  break things. [Versioning](docs/versioning.md) says what counts as public interface.
- **Requirements.** The tested PSU and PowerShell versions and browsers are on the
  [overview page](docs/index.md#requirements).

## What a change delivers

A change makes the product better for at least one of the three roles and keeps the
[promises above](#promises-and-limits). [CONTRIBUTING.md](CONTRIBUTING.md) has the steps and checks.
