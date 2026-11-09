# Perspective

`New-UDPerspective` puts [Perspective](https://perspective-dev.github.io/) into PSU apps: a datagrid,
pivot table and chart in one. Readers group, split, filter, sort and aggregate the data themselves:
**Edit view** above the viewer opens the editor, **Table** and **Chart** switch between the grid and a
chart ([Using the viewer](using.md)); the parameters set the view it starts with. The data is held by Perspective's WebAssembly engine in a Web Worker in the browser, so
tens of thousands of rows stay fast.

```powershell
Install-PSResource -Name PowerShellUniversal.Component.Perspective
```

In the PowerShell Gallery: [PowerShellUniversal.Component.Perspective](https://www.powershellgallery.com/packages/PowerShellUniversal.Component.Perspective).

## Datagrid that readers rearrange

--8<-- "examples/datagrid-that-readers-rearrange.md"

## Data

`-Data` takes a DataTable, DataRows, PSCustomObjects, hashtables or a script block, like the chart
module (a DataTable of 1000 rows or more is converted by a small class compiled once per PSU process:
[loading and performance](../pivot/index.md#loading-and-performance)). Column names keep their PowerShell spelling in the grid. Every column gets a type from its
values: ISO dates and times become dates (sortable and filterable as dates), whole numbers up to
2,147,483,647 integers (Perspective's integers are 32 bit), other numbers floats, `$true`/`$false`
booleans, everything else text.

New data for the same component replaces the rows and keeps the reader's layout; when the columns or
their types change, the table is built anew and the view starts again from the parameters.

Next: [Using the viewer](using.md), [The starting view](view.md), [Events, security and limits](events.md), [Reference](reference.md).
