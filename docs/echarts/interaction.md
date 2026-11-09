# Interaction and events

On by default: tooltips (the element under the pointer, or every series at an axis position; see
[Which items the tooltip shows](labels.md#which-items-the-tooltip-shows)), hover highlighting, legend
toggles, zoom with the mouse wheel, and a toolbox with box zoom, line/bar/stack switch, restore, PNG, CSV, Excel and full screen (the chart alone on the
whole screen, zoom and selection kept; Esc returns; not offered where the browser cannot do it, e.g.
iPhone Safari).

| Parameter | Effect |
| --- | --- |
| `-Zoom Inside \| Slider \| Both \| None` | wheel/drag zoom, a slider, both or none |
| `-ZoomAxis X \| Y \| Both` | zoom along the data (X) or the value axis (Y); with Both, Shift + wheel zooms Y |
| `-Brush` | select a range with the mouse (toolbox button) |
| `-Group <name>` | charts with the same group share tooltip, zoom and legend |
| `-NoToolbox`, `-NoExport`, `-NoFullscreen` | hide the toolbox, its CSV/Excel buttons or the full screen button |
| `-ExportColumns` | export columns in order, with `title`, `type` (text, number, integer, currency, percent, date, datetime, boolean) and `format` |
| `-ExportFileName` | the file name of CSV, Excel and PNG exports |

## Events

Events run a script block on the server; `$EventData` holds what happened. On this page the chart
shows the `$EventData` it would send instead.

| Event | `$EventData` |
| --- | --- |
| `-OnClick` | `seriesName`, `seriesIndex`, `dataIndex`, `name`, `value`, `row` (the clicked data row) |
| `-OnSelect` | `from`, `to` (ISO dates on a time axis, category names on a category axis); rows of a parallel selection |
| `-OnZoom` | `from`, `to`, `start`, `end` |
| `-OnLegendChange` | `name`, `selected` |

`-EventColumns Name, Id` limits the rows in `$EventData` to the columns the script block needs, which
keeps messages small with wide rows. The last click, range and zoom are also in the component's state
(`Get-UDElement`).

### Click and range selection

--8<-- "examples/click-and-range-selection.md"

A click that filters a table on the same page:

```powershell
New-UDEChart -Data $byTeam -Type bar -X Team -Y Tickets -GroupBy Priority -Stacked -OnClick {
    $Session:Filter = @{ Team = $EventData.name; Priority = $EventData.seriesName }
    Sync-UDElement -Id 'ticket-table'
}
```

`$EventData` comes from the browser: see [Security and limits](security.md).
