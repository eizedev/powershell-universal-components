# Layout

`-Height` (default `400px`, also `100%` inside a container with a fixed height) and `-Width` (default:
the container's width) size the chart; `-Id`, `-ClassName` and `-Style` work as on PSU's own
components.

The chart follows its container's size, also when it was created hidden and shown later: tested in
`New-UDStack`, `New-UDGrid`, `New-UDPaper`, `New-UDTabs` (with and without `-RenderOnActive`),
`New-UDExpansionPanel`, `Show-UDModal` and `New-UDDynamic -AutoRefresh` (showcase page "Layouts").

Charts without a grid (funnel, treemap, pie, sunburst, gauge, polar, radialbar, radar, layered graph)
place their plot below the title and toolbox and above the legend for the size they have, also when a
plain legend wraps in a narrow container; a position or size set in `-Options` (`top`, `bottom`,
`left`, `right`, `center`, `radius`) wins. A layered graph keeps room for its largest node and the
labels under the nodes, and its nodes stay round in a narrow or a wide chart; radial bar names keep
clear of the rings' round ends.
In a narrow container the charts use smaller text and hide what does not fit (value labels on tiny
charts, toolbox buttons that need room). With `--psu-chart-font-size` ([Themes](themes.md)) these
sizes follow the app's base size by the same factor, and title, legend and labels keep their room when
the text grows. The first and last label of a time axis are aligned inwards, so a tick at the edge of a
narrow chart is not cut.

In a row of a flex container (`New-UDStack -Direction row`), the items share the row with
`-Style @{ flex = '1 1 0'; minWidth = 0 }` on their `New-UDPaper`.
