# Labels and tooltips

Labels and tooltips can come from the row behind each point, for every chart type:

```powershell
New-UDEChart -Data $vms -Type tree -Path Folder -LabelTemplate '{Name} ({Cpu} vCPU)' `
    -TooltipColumns 'vCPU=Cpu', 'Memory (GB)=RamGB:integer', 'Disk=DiskBytes:bytes', 'PowerState'
New-UDEChart -Data $links -Type graph -Source From -Target To `
    -TooltipTemplate "{From} > {To}`nVLAN: {Vlan}`nLoad: {Load:percent100:0}"
```

A placeholder `{Column}` or `{Column:format}` takes any [format](formats.md); a list column is joined
with commas; `` `n `` starts a new line. `-LabelColumn Name` is the short form of
`-LabelTemplate '{Name}'`. `-TooltipColumns` entries are `Column`, `Column:format` or
`Label=Column:format`. Points without a row of their own (a tree's folders, aggregated nodes) keep their
name. Values are HTML-escaped in tooltips.

`-DataLabels` writes the values on bars, lines and points; `-LabelFormat` formats them.

## Which items the tooltip shows

The element under the pointer wins: a bar, a bar segment or a point on a line shows that element
only, a stacked segment also the stack total. A position on the axis without an element (between the
bars, between the points of a line) shows all series there; between stacked bars only the total.
Switching bars to a stack in the toolbox does the same.

--8<-- "examples/tooltip-on-the-hovered-segment.md"

`-TooltipMode` changes it for one chart:

| Mode | Tooltip |
| --- | --- |
| `Auto` (default) | as above |
| `Item` | one element, nothing between them; stacked bars with the total |
| `Axis` | all series at the position, wherever the pointer is; stacked bars with the total |
| `None` | no tooltip |

`Item` and `Axis` apply to line, area, step and bar. The other chart types keep their own tooltip and
ignore them: one element where an element is what is pointed at (pie, donut, funnel, scatter, heatmap,
calendar, gauge, treemap, sunburst, sankey, graph, chord, tree, parallel, boxplot, radar, polar,
radialbar, bump, gantt), the values at the position where a position is (candlestick with its
volume, histogram, waterfall, themeriver, matrix, sparklines, `-Facet` panels). `None` works for every
type.

A hashtable sets the mode per chart type, `'*'` for the others; with `$PSDefaultParameterValues` it
applies to every chart of an app, and a chart's own `-TooltipMode` still wins. For an app used mostly
on touch screens, where a finger rarely hits a point of a line:

```powershell
$PSDefaultParameterValues['New-UDEChart:TooltipMode'] = @{ line = 'Axis'; area = 'Axis'; '*' = 'Auto' }
```

With `-TooltipColumns` or `-TooltipTemplate` the text of each item comes from its row; the mode decides
which items. Totals are not part of a template.

## Legend

`-Legend Bottom | Top | Left | Right | None` places the legend; `-LegendType Scroll` (default) pages
through entries that do not fit, `Plain` wraps them over several lines.

## Labels on filled shapes

Labels inside a filled shape (funnel stages, pie slices with inside labels, treemap tiles, sunburst
rings) are dark or white, whichever contrasts more with the fill; a `label.color` in `-Options` wins.

A funnel stage too small for its label (the last stages, or every stage of a low chart with many of
them) gets the label on one line right of the funnel, with a line to the stage, in the page's text
colour; the funnel gets narrower for it. Where even that leaves too little room, the label is hidden;
the tooltip and the legend name the stage.
