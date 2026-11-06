# Lines and time

`-Type line`, `area` or `step`. A date column on `-X` gives a time axis with zoom; `-Smooth` smooths the
lines, `-SecondaryY` puts named series on a second axis, `-LogScale` makes the value axis logarithmic,
`-Band Low, High` shades a range around a line, `-MarkArea` marks a time window.

## Time axis with zoom and a reference line

--8<-- "examples/time-axis-with-zoom-and-a-reference-line.md"

## Reference lines and pins

`-MarkLine 'median', 'average'` per series, or fixed lines: `@{ value = 48; name = 'SLA'; color = '#e53935' }`
(`axis = 'x'` for a vertical line).

`-MarkPoint 'max', 'min'` pins those values on every series; `@{ x = 'Thu'; y = 306; label = 'Outage' }`
pins one point (add `series = 'Mail'` for another series than the first).

## Pins on single values

--8<-- "examples/pins-on-single-values.md"

## Trends and forecasts

`-Trend Linear` adds a dashed least-squares line per series. On a time or value axis, `-Forecast 6`
continues it six steps of the data, and `-TrendTarget 100` continues it until it reaches 100 and marks
the date - when a datastore is full or a licence count is used up.

## Trend to a limit: when is the datastore full?

--8<-- "examples/trend-to-a-limit-when-is-the-datastore-full.md"

## Axis breaks

`New-UDEChartTimeBreak` cuts nights and weekends out of a time axis, so business hours fill the chart;
`-YBreaks @{ start = 120; end = 1750 }` keeps small bars readable next to one huge one.

## Business hours only

--8<-- "examples/business-hours-only.md"

