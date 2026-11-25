---
description: "Distributions with New-UDEChart: a histogram of -Y with -Bins and the median, and a boxplot with quartiles, whiskers and outliers per group."
---

# Distributions

`-Type histogram` bins the values of `-Y` (`-Bins` sets the number) and draws the median unless
`-MarkLine` says otherwise; `-Type boxplot` computes quartiles, whiskers and outliers per `-X` group.

## Lead time histogram with SLA

--8<-- "examples/lead-time-histogram-with-sla.md"

## Boxplot per team

--8<-- "examples/boxplot-per-team.md"

