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
