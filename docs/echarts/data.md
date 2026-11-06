# Data

`-Data` takes a `System.Data.DataTable` or `DataView` (SqlClient, ODBC), DataRows, PSCustomObjects,
hashtables, or a script block returning any of these. `DBNull` becomes `null` (a gap in a line), dates
become ISO 8601 (the time axis picks them up), TimeSpans become seconds. Column names are matched
without regard to case, so `-X Team` finds `team`.

## Wide and long data

Wide data has one column per series (`-Y Opened, Closed`); long data has one row per series and point
(`-Y Tickets -GroupBy Team` draws one series per team).

## Rows with the same x

On a category axis each x value is one point per series: rows with the same x (and group) are combined
with `-Aggregate Sum | Avg | Count | Min | Max` (also for pie, donut, funnel and polar), or the last one
wins. `-Aggregate Count` counts raw rows, so `-Data $tickets -X Team -Y Id -Aggregate Count` needs no
`Group-Object`. On a time axis only identical timestamps combine: round dates first
(`$_.Created.Date`) to count per day. Empty values are left out; a group with none is a gap, not a 0.

## Mistakes and empty data

A column parameter that matches no column (`-Y Tickts`) shows an error in place of the chart, with the
columns the data has. A parameter that only another chart type reads (`-Source` on a bar chart) gives a
warning naming the types that use it.

### When there is nothing to show

--8<-- "examples/when-there-is-nothing-to-show.md"

## Numbers and language

Numbers on axes, labels and tooltips follow `-Locale` (e.g. `de-DE`) or, without it, the browser's
language - two readers can see `1,200` and `1.200` for the same chart. Formats: [Formats](formats.md).

## How much data

Above 20,000 points per chart, points are drawn with sampling (LTTB) and click events carry values but
no row. Everything in `-Data` is sent to the browser: see [Security and limits](security.md).
