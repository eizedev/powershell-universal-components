# Formats

`-Format` applies to axis, tooltip and labels; `-LabelFormat` to value labels only (default: the short
form of `-Format` for numbers of 10,000 and more). `-XFormat` formats a value x axis. Numbers and dates use the browser's language or `-Locale`
(e.g. `de-DE`).

A time axis without `-XFormat` (line, area, bar over dates, gantt, themeriver) labels its ticks in the
same locale: times between day boundaries, the date where a day starts ("23:00, 5. Nov., 01:00" with
`de-DE`, "23:00, Nov 5, 01:00" with `en-US`), the month or the year at those boundaries of a coarser
axis. Boundaries are bold.

| Format | Shows |
| --- | --- |
| `number`, `number:2` | a number, with that many decimals |
| `integer` | a whole number |
| `currency`, `currency:USD`, `compactcurrency:EUR` | an amount, in the locale's or the given currency, short for large amounts |
| `percent` | 0.25 as 25 % |
| `percent100` | 25 as 25 % (`percent100:1` with one decimal) |
| `compact` | 1.2M |
| `bytes` | a size in bytes, with a unit |
| `duration`, `duration:min`, `duration:h` | seconds (or minutes, hours) as a duration |
| `date`, `datetime`, `time` | a date or time in the reader's language |
| `text` | as it is |

PowerShell sends no functions to the browser, so formats are names; a format string is never run as code.
