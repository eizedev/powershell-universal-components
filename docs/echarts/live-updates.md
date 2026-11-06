# Live updates

`Set-UDEChartData` replaces the data of a chart on the page; zoom and hidden series stay.

```powershell
New-UDEChart -Id 'cpu' -Data @() -Type line -X Time -Y Load
New-UDElement -Tag div -AutoRefresh -RefreshInterval 5 -Endpoint {
    Set-UDEChartData -Id 'cpu' -Data (Get-MyCounters)
}
```

The same works for a drill-down: `-OnClick` plus `Set-UDEChartData` with the level below.
