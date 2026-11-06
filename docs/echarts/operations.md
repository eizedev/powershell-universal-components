# Operations

`-Type gantt` draws lanes (`-X`) with bars from `-Start` to `-End`, coloured by `-GroupBy`, labelled
with `-Value`: backup windows, maintenance, on-call. `-Type gauge` shows the first row's `-Y`:
`-GaugeStyle Progress` (default) as a progress arc, `Ring` as one ring per row, `Grade` as an arc
coloured by `-Thresholds` (upper bounds, ascending) with a needle.

## Backup windows (gantt)

--8<-- "examples/backup-windows-gantt.md"

## Gauge with bands

--8<-- "examples/gauge-with-bands.md"

