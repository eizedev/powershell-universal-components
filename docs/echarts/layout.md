# Layout

`-Height` (default `400px`, also `100%` inside a container with a fixed height) and `-Width` (default:
the container's width) size the chart; `-Id`, `-ClassName` and `-Style` work as on PSU's own
components.

The chart follows its container's size, also when it was created hidden and shown later: tested in
`New-UDStack`, `New-UDGrid`, `New-UDPaper`, `New-UDTabs` (with and without `-RenderOnActive`),
`New-UDExpansionPanel`, `Show-UDModal` and `New-UDDynamic -AutoRefresh` (showcase page "Layouts").

Charts without a grid (funnel, treemap, pie, sunburst, gauge, polar, radialbar, radar) place their plot
below the title and toolbox and above the legend for the size they have, also when a plain legend wraps
in a narrow container; a position or size set in `-Options` (`top`, `bottom`, `center`, `radius`) wins.
In a narrow container the charts use smaller text and hide what does not fit (value labels on tiny
charts, toolbox buttons that need room).

In a row of a flex container (`New-UDStack -Direction row`), the items share the row with
`-Style @{ flex = '1 1 0'; minWidth = 0 }` on their `New-UDPaper`.
