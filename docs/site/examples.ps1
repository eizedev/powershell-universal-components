<#
    Examples of the documentation site. Each one is shown as its code and as the chart that code
    produces: Build-Site.ps1 runs the script block with the real New-UDEChart. Keep every block
    self-contained (it creates or fetches its own data), so readers can copy it into an app as it is.

    Keys: Section, Title (the id of the page snippet), Text (above the example), Code; App (a title:
    the page also shows the code as a whole app script) and Source (a line under it, for the
    attribution of public data). Public data comes from Invoke-RestMethod, answered at build time from
    the snapshots in data/ (data/SOURCES.md).
#>

# the attribution endoflife.date's licence asks for, under every example with its data
$endoflife = 'Release data by [endoflife.date](https://endoflife.date/), MIT licence, Copyright 2020 endoflife.date contributors; on this page a snapshot of 2026-11-08 ([sources and licence](https://github.com/eizedev/powershell-universal-components/blob/HEAD/docs/site/data/SOURCES.md)).'

@(
    #region Start
    @{ Section = 'First charts'; Title = 'A bar chart from any PowerShell objects'; Text = 'Name the columns; the chart picks a category axis for text and a value axis for numbers.'; Code = {
            $sales = 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun' | ForEach-Object -Begin { $i = 0 } -Process {
                $i++; [pscustomobject]@{ Month = $_; Online = 100 + 12 * $i; Store = 160 - 5 * $i }
            }
            New-UDEChart -Data $sales -Type bar -X Month -Y Online, Store -Height 320px
        }
    }
    @{ Section = 'First charts'; Title = 'Long data: one series per group'; Text = '-GroupBy splits rows into series, in natural order (P1, P2 ... P10).'; Code = {
            $tickets = foreach ($team in 'Service Desk', 'Network', 'Server') {
                foreach ($p in 'P1', 'P2', 'P3') { [pscustomobject]@{ Team = $team; Priority = $p; Tickets = 10 * $team.Length + 7 * [int]$p.Substring(1) } }
            }
            New-UDEChart -Data $tickets -Type bar -X Team -Y Tickets -GroupBy Priority -Stacked -DataLabels -Height 320px
        }
    }
    #endregion

    #region Bars
    @{ Section = 'Bars'; Title = 'Horizontal and sorted'; Text = 'Sort in PowerShell; -Horizontal turns the bars.'; Code = {
            $vms = 'Windows Server 2025', 'Windows Server 2022', 'Ubuntu 24.04', 'RHEL 9', 'Debian 12', 'SLES 15' | ForEach-Object -Begin { $n = 0 } -Process { $n++; [pscustomobject]@{ OS = $_; VMs = 40 * $n + 3 * $_.Length } }
            New-UDEChart -Data ($vms | Sort-Object VMs) -Type bar -Horizontal -X OS -Y VMs -DataLabels -Height 320px
        }
    }
    @{ Section = 'Bars'; Title = 'Shares of 100 % per category'; Text = '-Normalize stacks to 100 %; the tooltip shows share and original value.'; Code = {
            $mix = foreach ($q in 'Q1', 'Q2', 'Q3', 'Q4') {
                [pscustomobject]@{ Quarter = $q; Mail = 120 - 10 * $q[1]; Phone = 80; Portal = 60 + 25 * [int]"$($q[1])" }
            }
            New-UDEChart -Data $mix -Type bar -X Quarter -Y Mail, Phone, Portal -Normalize -DataLabels -Height 320px
        }
    }
    @{ Section = 'Bars'; Title = 'Negative values'; Text = '-NegativeColor marks losses.'; Code = {
            $result = 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun' | ForEach-Object -Begin { $i = 0 } -Process { $i++; [pscustomobject]@{ Month = $_; Result = [math]::Round(40 * [math]::Sin($i)) } }
            New-UDEChart -Data $result -Type bar -X Month -Y Result -NegativeColor '#e53935' -Format 'currency:EUR' -Height 300px
        }
    }
    #endregion

    #region Lines and time
    @{ Section = 'Lines and time'; Title = 'Time axis with zoom and a reference line'; Text = 'Dates become a time axis; the wheel zooms, the slider below shows the whole range.'; Code = {
            $rng = [System.Random]::new(4)
            $latency = foreach ($m in 0..287) { [pscustomobject]@{ Time = ([datetime]'2026-11-03').AddMinutes(5 * $m); Ms = [math]::Round(90 + 30 * [math]::Sin($m / 20) + $rng.Next(0, 20)) } }
            New-UDEChart -Data $latency -Type area -X Time -Y Ms -MarkLine @{ value = 150; name = 'SLA'; color = '#e53935' } -Thresholds @{ value = 150; color = '#43a047' }, @{ value = 100000; color = '#e53935' } -Height 320px
        }
    }
    @{ Section = 'Lines and time'; Title = 'Trend to a limit: when is the datastore full?'; Text = '-Trend Linear with -TrendTarget continues the least-squares line and marks the date.'; Code = {
            $fill = 0..59 | ForEach-Object { [pscustomobject]@{ Day = ([datetime]'2026-09-01').AddDays($_); Used = [math]::Round(60 + 0.42 * $_ + [math]::Sin($_) * 1.5, 1) } }
            New-UDEChart -Data $fill -Type line -X Day -Y Used -Format 'percent100:0' -Trend Linear -TrendTarget 100 -YMax 105 -Height 320px
        }
    }
    @{ Section = 'Lines and time'; Title = 'Business hours only'; Text = 'New-UDEChartTimeBreak cuts nights and weekends out of the time axis.'; Code = {
            $from = [datetime]'2026-11-02'; $to = $from.AddDays(5)
            $samples = for ($t = $from; $t -lt $to; $t = $t.AddMinutes(30)) { if ($t.Hour -ge 7 -and $t.Hour -lt 19) { [pscustomobject]@{ Time = $t; Calls = 20 + 15 * [math]::Sin(($t.Hour - 7) / 2) } } }
            New-UDEChart -Data $samples -Type line -X Time -Y Calls -Breaks (New-UDEChartTimeBreak -From $from -To $to -DayStart '07:00' -DayEnd '19:00') -Height 300px
        }
    }
    @{ Section = 'Lines and time'; Title = 'Pins on single values'; Text = '-MarkPoint max, min pins the extremes of every series.'; Code = {
            $weeks = 1..12 | ForEach-Object { [pscustomobject]@{ Week = 'W{0:00}' -f (34 + $_); Windows = 20 + 9 * [math]::Sin($_); Linux = 12 + 6 * [math]::Cos($_ / 2) } }
            New-UDEChart -Data $weeks -Type line -X Week -Y Windows, Linux -MarkPoint max, min -Format 'number:0' -Height 320px
        }
    }
    #endregion

    #region Distributions
    @{ Section = 'Distributions'; Title = 'Lead time histogram with SLA'; Text = 'Bins, a median line and a fixed SLA line; durations in hours.'; Code = {
            $rng = [System.Random]::new(7)
            $lead = 1..600 | ForEach-Object { [pscustomobject]@{ Hours = [math]::Round([math]::Exp(2.6 + 0.8 * ($rng.NextDouble() + $rng.NextDouble() - 1)), 1) } }
            New-UDEChart -Data $lead -Type histogram -Y Hours -Bins 24 -Format 'duration:h' -MarkLine 'median', @{ value = 48; name = 'SLA'; color = '#e53935' } -Height 320px
        }
    }
    @{ Section = 'Distributions'; Title = 'Boxplot per team'; Text = 'Quartiles, whiskers and outliers are computed from the raw values.'; Code = {
            $rng = [System.Random]::new(9)
            $rows = foreach ($team in 'Service Desk', 'Network', 'Server', 'Applications') { 1..80 | ForEach-Object { [pscustomobject]@{ Team = $team; Hours = [math]::Round(4 + $team.Length * $rng.NextDouble() * 3, 1) } } }
            New-UDEChart -Data $rows -Type boxplot -X Team -Y Hours -Format 'number:1' -Height 320px
        }
    }
    #endregion

    #region Shares
    @{ Section = 'Shares'; Title = 'Donut'; Text = 'Labels with value and share; small slices move their label inside on narrow screens.'; Code = {
            $channels = @(
                [pscustomobject]@{ Channel = 'Mail'; Tickets = 812 }
                [pscustomobject]@{ Channel = 'Phone'; Tickets = 455 }
                [pscustomobject]@{ Channel = 'Portal'; Tickets = 390 }
                [pscustomobject]@{ Channel = 'Monitoring'; Tickets = 168 }
            )
            New-UDEChart -Data $channels -Type donut -X Channel -Y Tickets -Height 320px
        }
    }
    @{ Section = 'Shares'; Title = 'Funnel'; Code = {
            $stages = @(
                [pscustomobject]@{ Stage = 'Created'; Tickets = 2000 }
                [pscustomobject]@{ Stage = 'Answered within 1 h'; Tickets = 1640 }
                [pscustomobject]@{ Stage = 'Closed'; Tickets = 1810 }
                [pscustomobject]@{ Stage = 'Closed within SLA'; Tickets = 1525 }
            )
            New-UDEChart -Data $stages -Type funnel -X Stage -Y Tickets -Height 320px
        }
    }
    @{ Section = 'Shares'; Title = 'Treemap from paths'; Text = '-Path takes the levels from the root; click a box to zoom in.'; Code = {
            $costs = @(
                [pscustomobject]@{ Area = 'Infrastructure'; Item = 'Compute'; EUR = 42000 }
                [pscustomobject]@{ Area = 'Infrastructure'; Item = 'Storage'; EUR = 18500 }
                [pscustomobject]@{ Area = 'Infrastructure'; Item = 'Network'; EUR = 9200 }
                [pscustomobject]@{ Area = 'Licences'; Item = 'Microsoft'; EUR = 31000 }
                [pscustomobject]@{ Area = 'Licences'; Item = 'Backup'; EUR = 7600 }
                [pscustomobject]@{ Area = 'Staff'; Item = 'Operations'; EUR = 54000 }
            )
            New-UDEChart -Data $costs -Type treemap -Path Area, Item -Y EUR -Format 'compactcurrency:EUR' -Height 340px
        }
    }
    #endregion

    #region Heatmaps and calendars
    @{ Section = 'Heatmaps and calendars'; Title = 'Weekday x hour'; Code = {
            $days = 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
            $grid = foreach ($h in 0..23) { foreach ($d in $days) { [pscustomobject]@{ Hour = '{0:00}' -f $h; Weekday = $d; Tickets = [math]::Max(0, [math]::Round(30 * [math]::Sin(($h - 6) / 4) * ($(if ($days.IndexOf($d) -lt 5) { 1 } else { 0.3 })))) } } }
            New-UDEChart -Data $grid -Type heatmap -X Hour -Y Weekday -Value Tickets -Height 320px -Options @{ yAxis = @{ inverse = $true } }
        }
    }
    @{ Section = 'Heatmaps and calendars'; Title = 'Calendar'; Code = {
            $rng = [System.Random]::new(3)
            $days = 0..240 | ForEach-Object { [pscustomobject]@{ Date = ([datetime]'2026-03-01').AddDays($_).ToString('yyyy-MM-dd'); Changes = $rng.Next(0, 25) } }
            New-UDEChart -Data $days -Type calendar -X Date -Y Changes -Height 220px
        }
    }
    #endregion

    #region Finance
    @{ Section = 'Finance'; Title = 'Waterfall: from revenue to result'; Code = {
            $bridge = @(
                [pscustomobject]@{ Step = 'Revenue'; EUR = 1200000 }
                [pscustomobject]@{ Step = 'Staff'; EUR = -540000 }
                [pscustomobject]@{ Step = 'Licences'; EUR = -210000 }
                [pscustomobject]@{ Step = 'Hardware'; EUR = -130000 }
                [pscustomobject]@{ Step = 'Other'; EUR = -60000 }
                [pscustomobject]@{ Step = 'Result'; EUR = 0 }
            )
            New-UDEChart -Data $bridge -Type waterfall -X Step -Y EUR -Totals Result -Format 'compactcurrency:EUR' -Height 340px
        }
    }
    @{ Section = 'Finance'; Title = 'Candlestick with volume'; Code = {
            $rng = [System.Random]::new(11); $price = 100
            $days = 0..59 | ForEach-Object {
                $open = $price; $price = [math]::Round($price + $rng.NextDouble() * 6 - 3, 2)
                [pscustomobject]@{ Date = ([datetime]'2026-08-03').AddDays($_); Open = $open; Close = $price; Low = [math]::Min($open, $price) - 1; High = [math]::Max($open, $price) + 1; Volume = $rng.Next(1000, 5000) }
            }
            New-UDEChart -Data $days -Type candlestick -X Date -Open Open -Close Close -Low Low -High High -Volume Volume -Height 380px
        }
    }
    #endregion

    #region Operations
    @{ Section = 'Operations'; Title = 'Backup windows (gantt)'; Text = 'Bars from -Start to -End per lane, coloured by -GroupBy.'; Code = {
            $night = [datetime]'2026-11-04 21:00'
            $jobs = foreach ($srv in 1..6) { foreach ($k in 0..2) { $s = $night.AddMinutes(20 * $srv + 70 * $k); [pscustomobject]@{ Server = 'srv-{0:00}' -f $srv; Start = $s; End = $s.AddMinutes(45 + 5 * $srv); Result = @('Success', 'Success', 'Warning', 'Failed')[($srv + $k) % 4] } } }
            New-UDEChart -Data $jobs -Type gantt -X Server -Start Start -End End -GroupBy Result -Palette '#e53935', '#43a047', '#fb8c00' -Height 340px
        }
    }
    @{ Section = 'Operations'; Title = 'Gauge with bands'; Code = {
            New-UDEChart -Data @([pscustomobject]@{ SLA = 98.7 }) -Type gauge -Y SLA -Min 90 -Max 100 -GaugeStyle Grade -Format 'percent100:1' `
                -Thresholds @{ value = 95; color = '#e53935' }, @{ value = 99; color = '#fb8c00' }, @{ value = 100; color = '#43a047' } -Height 300px
        }
    }
    #endregion

    #region Relations and hierarchies
    @{ Section = 'Relations and hierarchies'; Title = 'Network path (layered graph)'; Text = 'Columns follow the links; ports on the lines, details in the tooltip.'; Code = {
            $links = @(
                [pscustomobject]@{ From = 'fw-01'; To = 'core-01'; Kind = 'Firewall'; ToKind = 'Switch'; Ports = 'port9 > Te1/0/1'; Vlan = 'trunk' }
                [pscustomobject]@{ From = 'core-01'; To = 'access-01'; Kind = 'Switch'; ToKind = 'Switch'; Ports = 'Te1/0/11 > Te1/1/1'; Vlan = 'trunk' }
                [pscustomobject]@{ From = 'core-01'; To = 'access-02'; Kind = 'Switch'; ToKind = 'Switch'; Ports = 'Te1/0/12 > Te1/1/1'; Vlan = 'trunk' }
                [pscustomobject]@{ From = 'access-01'; To = 'esx-01'; Kind = 'Switch'; ToKind = 'Host'; Ports = 'Gi1/0/11 > vmnic0'; Vlan = '120' }
                [pscustomobject]@{ From = 'access-02'; To = 'esx-01'; Kind = 'Switch'; ToKind = 'Host'; Ports = 'Gi1/0/11 > vmnic1'; Vlan = '120' }
                [pscustomobject]@{ From = 'esx-01'; To = 'vm-web'; Kind = 'Host'; ToKind = 'VM'; Ports = ''; Vlan = '120' }
                [pscustomobject]@{ From = 'esx-01'; To = 'vm-db'; Kind = 'Host'; ToKind = 'VM'; Ports = ''; Vlan = '120' }
            )
            New-UDEChart -Data $links -Type graph -Layout Layered -Source From -Target To -GroupBy Kind -TargetGroup ToKind -EdgeLabel Ports -Undirected `
                -TooltipTemplate "{From} > {To}`nPorts: {Ports}`nVLAN: {Vlan}" -Height 380px
        }
    }
    @{ Section = 'Relations and hierarchies'; Title = 'Folders as a tree'; Text = 'One "a/b/c" column or several -Path columns; label and tooltip from templates.'; Code = {
            $vms = @(
                [pscustomobject]@{ Folder = 'vCenter/Customer A/Production/vm-a1'; Name = 'vm-a1'; Cpu = 4; RamGB = 16 }
                [pscustomobject]@{ Folder = 'vCenter/Customer A/Production/vm-a2'; Name = 'vm-a2'; Cpu = 8; RamGB = 32 }
                [pscustomobject]@{ Folder = 'vCenter/Customer A/Test/vm-a3'; Name = 'vm-a3'; Cpu = 2; RamGB = 8 }
                [pscustomobject]@{ Folder = 'vCenter/Customer B/Production/vm-b1'; Name = 'vm-b1'; Cpu = 4; RamGB = 16 }
                [pscustomobject]@{ Folder = 'vCenter/Infrastructure/Management/vm-mgmt'; Name = 'vm-mgmt'; Cpu = 2; RamGB = 4 }
            )
            New-UDEChart -Data $vms -Type tree -Path Folder -Depth 4 -LabelTemplate '{Name} ({Cpu} vCPU)' -TooltipColumns 'vCPU=Cpu', 'Memory (GB)=RamGB' -Height 360px
        }
    }
    @{ Section = 'Relations and hierarchies'; Title = 'Flows (sankey)'; Code = {
            $flows = @(
                [pscustomobject]@{ Source = 'Mail'; Target = 'Service Desk'; Value = 520 }
                [pscustomobject]@{ Source = 'Phone'; Target = 'Service Desk'; Value = 310 }
                [pscustomobject]@{ Source = 'Monitoring'; Target = 'Server'; Value = 140 }
                [pscustomobject]@{ Source = 'Service Desk'; Target = 'Closed'; Value = 700 }
                [pscustomobject]@{ Source = 'Service Desk'; Target = 'Server'; Value = 130 }
                [pscustomobject]@{ Source = 'Server'; Target = 'Closed'; Value = 250 }
                [pscustomobject]@{ Source = 'Server'; Target = 'Waiting'; Value = 20 }
            )
            New-UDEChart -Data $flows -Type sankey -Height 340px
        }
    }
    @{ Section = 'Relations and hierarchies'; Title = 'Overlaps (chord)'; Code = {
            $shared = @(
                [pscustomobject]@{ Source = 'Virtualisation'; Target = 'Backup'; Assets = 410 }
                [pscustomobject]@{ Source = 'Virtualisation'; Target = 'EDR'; Assets = 380 }
                [pscustomobject]@{ Source = 'Backup'; Target = 'EDR'; Assets = 350 }
                [pscustomobject]@{ Source = 'EDR'; Target = 'CMDB'; Assets = 300 }
                [pscustomobject]@{ Source = 'Backup'; Target = 'CMDB'; Assets = 260 }
            )
            New-UDEChart -Data $shared -Type chord -Source Source -Target Target -Value Assets -Legend None -Height 360px
        }
    }
    #endregion

    #region Comparisons
    @{ Section = 'Comparisons'; Title = 'KPI matrix with sparklines'; Text = 'One small chart per row and column, one scale per column.'; Code = {
            $kpis = foreach ($c in 'Customer A', 'Customer B', 'Customer C') {
                foreach ($k in 'Tickets', 'SLA %', 'Backup %') {
                    foreach ($w in 1..10) { [pscustomobject]@{ Customer = $c; Kpi = $k; Week = "W$w"; Value = switch ($k) { 'Tickets' { 40 + 5 * $c.Length + ($w % 4) * 6 } 'SLA %' { 97 + ($w % 3) } default { 98 + ($w % 2) } } } }
                }
            }
            New-UDEChart -Data $kpis -Type matrix -Y Customer -GroupBy Kpi -X Week -Value Value -CellType Area -Height 300px
        }
    }
    @{ Section = 'Comparisons'; Title = 'Many measures (parallel)'; Text = 'Drag along an axis to keep only the lines in that range; -OnSelect gets their rows.'; Code = {
            $rng = [System.Random]::new(5)
            $servers = 1..60 | ForEach-Object { [pscustomobject]@{ Name = 'srv-{0:00}' -f $_; Class = @('Windows', 'Linux')[$_ % 2]; Cpu = @(2, 4, 8, 16)[$rng.Next(0, 4)]; DiskPct = $rng.Next(30, 98); PatchDays = $rng.Next(0, 60) } }
            New-UDEChart -Data $servers -Type parallel -X Name -GroupBy Class -Y Cpu, DiskPct, PatchDays -Height 340px -OnSelect { Show-UDToast -Message "$($EventData.count) servers" }
        }
    }
    @{ Section = 'Comparisons'; Title = 'Radar'; Code = {
            $teams = @(
                [pscustomobject]@{ Team = 'Service Desk'; Speed = 8; Quality = 7; Coverage = 9; Docs = 5 }
                [pscustomobject]@{ Team = 'Server'; Speed = 6; Quality = 9; Coverage = 6; Docs = 8 }
            )
            New-UDEChart -Data $teams -Type radar -X Team -Y Speed, Quality, Coverage, Docs -Max 10 -Height 320px
        }
    }
    @{ Section = 'Comparisons'; Title = 'Small multiples'; Text = '-Facet draws one small chart per value, all on one scale.'; Code = {
            $rows = foreach ($d in 'Mon', 'Tue', 'Wed', 'Thu', 'Fri') { foreach ($h in 8..18) { [pscustomobject]@{ Day = $d; Hour = $h; Calls = [math]::Round(20 + 15 * [math]::Sin(($h - 8) / 3) + $d.Length) } } }
            New-UDEChart -Data $rows -Type line -X Hour -Y Calls -Facet Day -FacetColumns 5 -XAxisType Category -Height 220px
        }
    }
    #endregion

    @{ Section = 'Comparisons'; Title = 'Rank over time (bump)'; Text = 'The rank of each item per period by its value; lines cross when one overtakes another.'; Code = {
            $months = 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov'
            $ranking = foreach ($i in 0..5) { foreach ($c in 'Customer A', 'Customer B', 'Customer C', 'Customer D') { [pscustomobject]@{ Month = $months[$i]; Customer = $c; Tickets = 50 + (($i + 1) * $c.Length * 7) % 90 } } }
            New-UDEChart -Data $ranking -Type bump -X Month -GroupBy Customer -Y Tickets -Height 320px
        }
    }
    @{ Section = 'Comparisons'; Title = 'Around the clock (polar)'; Text = 'Categories around a circle; -Aggregate Count counts raw rows per category.'; Code = {
            $calls = foreach ($i in 1..400) { [pscustomobject]@{ Id = $i; Hour = '{0:00}' -f [int](8 + 4 * [math]::Sin($i) + ($i % 7)) } }
            New-UDEChart -Data ($calls | Sort-Object Hour) -Type polar -X Hour -Y Id -Aggregate Count -Legend None -Height 340px
        }
    }
    @{ Section = 'Comparisons'; Title = 'Progress rings (radialbar)'; Text = 'One ring per category; -Max is three quarters of the circle, the names sit in the free quarter.'; Code = {
            $compliance = @(
                [pscustomobject]@{ Customer = 'Customer A'; Compliance = 96 }
                [pscustomobject]@{ Customer = 'Customer B'; Compliance = 88 }
                [pscustomobject]@{ Customer = 'Customer D'; Compliance = 61 }
            )
            New-UDEChart -Data $compliance -Type radialbar -X Customer -Y Compliance -Min 0 -Max 100 -Format 'percent100:0' -Legend None -Height 300px
        }
    }
    #region Interaction
    @{ Section = 'Interaction'; Title = 'Click and range selection'; Text = 'In an app these script blocks run on the server; here the page shows the $EventData they would get.'; Code = {
            $daily = 0..29 | ForEach-Object { [pscustomobject]@{ Day = ([datetime]'2026-10-01').AddDays($_); Opened = 30 + ($_ % 7) * 4 } }
            # -EventColumns: only these columns of the row travel back to the server
            New-UDEChart -Data $daily -Type bar -X Day -Y Opened -Brush -EventColumns Day, Opened -OnClick {
                Show-UDToast -Message "$($EventData.name): $($EventData.row.Opened) tickets"
            } -OnSelect {
                $Session:Range = $EventData; Sync-UDElement -Id 'ticket-table'
            } -Height 320px
        }
    }
    @{ Section = 'Interaction'; Title = 'Tooltip on the hovered segment'; Text = 'Point at a segment: its value and the stack total. Point between the stacks: the total only. -TooltipMode Axis lists every series instead.'; Code = {
            $storage = foreach ($site in 'Berlin', 'Hamburg', 'Munich', 'Vienna', 'Zurich', 'Prague') {
                foreach ($dept in 'Finance', 'HR', 'IT', 'Legal', 'Marketing', 'Production', 'Sales', 'Support') {
                    [pscustomobject]@{ Site = $site; Department = $dept; GB = 40 + 9 * $site.Length + 13 * $dept.Length }
                }
            }
            New-UDEChart -Data $storage -Type bar -X Site -Y GB -GroupBy Department -Stacked -Format 'integer' -Height 340px
        }
    }
    @{ Section = 'Interaction'; Title = 'Corporate design'; Text = 'An ECharts theme per mode - a hashtable, or the JSON the ECharts theme builder downloads - merged over the module''s own. Set it once for an app with $PSDefaultParameterValues.'; Code = {
            $quarters = 'Q1', 'Q2', 'Q3', 'Q4' | ForEach-Object -Begin { $q = 0 } -Process { $q++; [pscustomobject]@{ Quarter = $_; Managed = 300 + 40 * $q; Projects = 180 + 25 * $q; Licences = 90 + 10 * $q } }
            $light = @{ color = @('#003b6f', '#f28c28', '#6c8ebf'); title = @{ textStyle = @{ color = '#003b6f' } } }
            $dark = @{ color = @('#6fa8dc', '#f6b26b', '#9fc5e8'); title = @{ textStyle = @{ color = '#9fc5e8' } } }
            New-UDEChart -Data $quarters -Type bar -X Quarter -Y Managed, Projects, Licences -Stacked -LightTheme $light -DarkTheme $dark -Height 300px
        }
    }
    @{ Section = 'Interaction'; Title = 'Fixed colours per category'; Text = '-ColorMap: Failed is always red and Success always green, whichever states the data has and in every chart type; two colours give one per mode.'; Code = {
            $states = @{ Failed = '#E3000F', '#FF6B6B'; Warning = '#FB8C00'; Success = '#287233', '#4CAF50' }
            $nights = 1..7 | ForEach-Object { [pscustomobject]@{ Night = "Day $_"; Success = 180 + 3 * $_; Warning = 12 + $_ % 4; Failed = $_ % 3 } }
            New-UDEChart -Data $nights -Type bar -X Night -Y Success, Warning, Failed -Stacked -ColorMap $states -Height 300px
        }
    }
    @{ Section = 'Interaction'; Title = 'When there is nothing to show'; Text = 'Empty data shows "No data" in place of bare axes; -EmptyText says what it means for this chart.'; Code = {
            $jobs = 'Backup', 'Patch', 'Report' | ForEach-Object { [pscustomobject]@{ Job = $_; State = 'Completed'; Minutes = 5 * $_.Length } }
            $failed = @($jobs | Where-Object State -EQ 'Failed')
            New-UDEChart -Data $failed -Type bar -X Job -Y Minutes -EmptyText 'No failed jobs today' -Height 240px
        }
    }
    @{ Section = 'Interaction'; Title = 'Anything else: -Options'; Text = 'The full Apache ECharts option, merged over what the parameters built.'; Code = {
            $months = 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun' | ForEach-Object -Begin { $i = 0 } -Process { $i++; [pscustomobject]@{ Month = $_; Tickets = 300 + 20 * $i; SLA = 96 + $i / 2 } }
            New-UDEChart -Data $months -Type bar -X Month -Y Tickets, SLA -SecondaryY SLA -SecondaryTitle 'SLA %' -Height 320px -Options @{
                series = @(@{ itemStyle = @{ borderRadius = 6 } }, @{ type = 'line'; smooth = $true })
            }
        }
    }
    #endregion

    #region Perspective
    @{ Section = 'Perspective'; Title = 'Datagrid that readers rearrange'; Text = 'Sort, filter and group in the editor (Edit view); Table and Chart switch between the grid and a chart. A click on a cell gives the row, as $EventData would.'; Code = {
            $rng = [System.Random]::new(42)
            $tickets = foreach ($i in 1..800) {
                [pscustomobject]@{
                    Id        = 10000 + $i
                    Created   = ([datetime]'2026-10-01').AddDays($rng.Next(0, 30)).AddHours($rng.Next(7, 19))
                    Team      = ('Service Desk', 'Network', 'Server', 'Applications')[$rng.Next(0, 4)]
                    Priority  = 'P{0}' -f $rng.Next(1, 5)
                    Status    = ('Open', 'Waiting', 'Closed', 'Closed')[$rng.Next(0, 4)]
                    LeadHours = [math]::Round(2 + 40 * $rng.NextDouble(), 1)
                }
            }
            New-UDPerspective -Data $tickets -Sort 'Created desc' -Height 420px -OnClick {
                Show-UDToast -Message ('Ticket {0}, {1}' -f $EventData.row.Id, $EventData.row.Team)
            }
        }
    }
    @{ Section = 'Perspective'; Title = 'Pivot: tickets per team and priority'; Text = '-GroupBy rows, -SplitBy columns, -Aggregates per column; the reader can change all of it.'; Code = {
            $rng = [System.Random]::new(7)
            $tickets = foreach ($i in 1..800) {
                [pscustomobject]@{ Id = $i; Team = ('Service Desk', 'Network', 'Server', 'Applications')[$rng.Next(0, 4)]; Priority = 'P{0}' -f $rng.Next(1, 5); LeadHours = [math]::Round(2 + 40 * $rng.NextDouble(), 1) }
            }
            New-UDPerspective -Data $tickets -GroupBy Team -SplitBy Priority -Columns Id, LeadHours -Aggregates @{ Id = 'count'; LeadHours = 'avg' } -Height 320px
        }
    }
    @{ Section = 'Perspective'; Title = 'Perspective chart: open tickets per team'; Text = 'A chart plugin with a filter; the WebGL charts redraw as the reader changes the grouping.'; Code = {
            $rng = [System.Random]::new(3)
            $tickets = foreach ($i in 1..800) {
                [pscustomobject]@{ Id = $i; Team = ('Service Desk', 'Network', 'Server', 'Applications')[$rng.Next(0, 4)]; Customer = 'Customer {0}' -f [char](65 + $rng.Next(0, 5)); Status = ('Open', 'Closed', 'Closed')[$rng.Next(0, 3)] }
            }
            New-UDPerspective -Data $tickets -Plugin 'Y Bar' -GroupBy Customer -SplitBy Team -Columns Id -Aggregates @{ Id = 'count' } -Filter 'Status == Open' -Height 360px
        }
    }
    #endregion

    #region Pivot
    @{ Section = 'Pivot'; Title = 'Pivot report from a web API'; App = 'Python releases'; Source = $endoflife; Text = 'One line: the release cycles of Python from endoflife.date, one row each. Click a field to put it into Rows or Values, or drag it into a zone.'; Code = {
            New-UDPivotReport -Id 'python' -Data (Invoke-RestMethod 'https://endoflife.date/api/python.json')
        }
    }
    @{ Section = 'Pivot'; Title = 'Start view, field names and templates'; App = 'End of life'; Source = $endoflife; Text = 'Five products from the same API. -View opens the report with end of life per year and product, -FieldDefaults gives the fields names, descriptions and types, -Locale en-GB formats dates and numbers, and -Templates puts two views into the Views menu.'; Code = {
            $cycles = foreach ($product in 'python', 'nodejs', 'postgresql', 'ubuntu', 'powershell') {
                # eol and lts are a date or $true/$false: keep eol's dates, lts as $true/$false
                (Invoke-RestMethod "https://endoflife.date/api/$product.json") | Select-Object @{ n = 'product'; e = { $product } }, cycle, releaseDate,
                    @{ n = 'eol'; e = { if ($_.eol -is [string]) { $_.eol } } }, @{ n = 'lts'; e = { [bool]$_.lts } }, latest
            }
            $eolPerYear = @{
                derived = @(@{ name = 'End of life (year)'; field = 'eol'; by = 'year' })
                rows    = @('End of life (year)'); cols = @('product'); values = @(@{ field = 'cycle'; agg = 'count' })
            }
            New-UDPivotReport -Id 'endoflife' -Data $cycles -Locale en-GB -View $eolPerYear -FieldDefaults @{
                product     = @{ Label = 'Product' }
                cycle       = @{ Label = 'Release cycle' }
                releaseDate = @{ Label = 'Released'; Type = 'date' }
                eol         = @{ Label = 'End of life'; Type = 'date'; Description = 'The day support ends; empty while endoflife.date knows no date.'; Href = 'https://endoflife.date/' }
                lts         = @{ Label = 'LTS'; Description = 'A long-term support release.' }
                latest      = @{ Label = 'Latest version' }
            } -Templates @(
                @{ Name = 'End of life per year and product'; View = $eolPerYear }
                @{ Name = 'Releases per year'; View = @{
                        derived = @(@{ name = 'Released (year)'; field = 'releaseDate'; by = 'year' })
                        rows    = @('Released (year)'); cols = @('product'); values = @(@{ field = 'cycle'; agg = 'count' })
                        display = 'chart'; chart = @{ type = 'bar'; stacked = $true }
                    }
                }
            )
        }
    }
    @{ Section = 'Pivot'; Title = 'A report app with loading, views per reader and roles'; App = 'Release cycles'; Source = $endoflife; Text = 'The report in New-UDDynamic with New-UDPivotReportPlaceholder while the server asks the API; readers keep their own views on the server (New-UDPivotFileTemplateStore), readers with the role of -AdminRole publish shared views and see the admin panel, and -OnCellClick runs on the server. The app needs authentication and the role -AdminRole names: without a signed-in $User the readers'' own views stay in the browser, and without that role in $Roles there is no Publish and no admin panel. On this page the report appears at once, the reader is signed in with the role Administrator, and the page shows the $EventData the server would get.'; Code = {
            $products = 'python', 'nodejs', 'postgresql', 'ubuntu', 'debian', 'powershell', 'dotnet', 'mssqlserver', 'windows-server'
            # view files next to the PSU repository: users/<hash>/ for each reader, shared/ for everyone
            $store = New-UDPivotFileTemplateStore -MaxUserViews 20
            New-UDDynamic -Id 'release-cycles-report' -LoadingComponent {
                New-UDPivotReportPlaceholder -Height 640px -Locale en-GB -Label 'Release cycles'
            } -Content {
                $cycles = foreach ($product in $products) {
                    foreach ($cycle in (Invoke-RestMethod "https://endoflife.date/api/$product.json")) {
                        [pscustomobject]@{
                            Product          = $product
                            Cycle            = $cycle.cycle
                            Released         = $cycle.releaseDate
                            # a date, or $true/$false when endoflife.date knows none
                            'End of life'    = if ($cycle.eol -is [string]) { $cycle.eol }
                            LTS              = [bool]$cycle.lts
                            'Latest version' = $cycle.latest
                        }
                    }
                }
                $perProduct = @{ rows = @('Product'); cols = @('LTS'); values = @(@{ field = 'Cycle'; agg = 'count' }) }
                New-UDPivotReport -Id 'release-cycles' -Data $cycles -Label 'Release cycles' -SourceName 'Release cycles' -Height 640px -Locale en-GB `
                    -View $perProduct -Templates @(
                        @{ Name = 'Release cycles per product'; View = $perProduct }
                        @{ Name = 'End of life per year'; View = @{
                                derived = @(@{ name = 'End of life (year)'; field = 'End of life'; by = 'year' })
                                rows    = @('End of life (year)'); values = @(@{ field = 'Cycle'; agg = 'count' }); display = 'chart'; chart = @{ type = 'bar' }
                            }
                        }
                    ) -FieldDefaults @{
                        Released      = @{ Type = 'date' }
                        'End of life' = @{ Type = 'date'; Description = 'The day support ends; empty while endoflife.date knows no date.' }
                    } -TemplateStore $store -AdminRole 'Administrator' -OnCellClick {
                        Show-UDToast -Message ('{0} release cycles' -f $EventData.count)
                    }
            }
        }
    }
    @{ Section = 'Pivot'; Title = 'Pivot report from a DataTable'; Text = 'Drag fields from the list into Rows, Columns and Values, switch to Chart, click a number for its rows. Saving a template and clicking a value show the $EventData the server would get.'; Code = {
            # what a SQL query returns: a DataTable with dates, numbers, text and DBNull
            $rng = [System.Random]::new(5)
            $tickets = [System.Data.DataTable]::new()
            foreach ($c in @(@('Ticket', [int]), @('Created', [datetime]), @('Team', [string]), @('Priority', [string]), @('Lead hours', [double]))) { [void]$tickets.Columns.Add($c[0], $c[1]) }
            foreach ($i in 1..1200) {
                $open = $rng.NextDouble() -lt 0.2
                [void]$tickets.Rows.Add(10000 + $i, ([datetime]'2026-10-31').AddDays(-$rng.Next(0, 300)).AddHours($rng.Next(7, 19)),
                    ('Service Desk', 'Network', 'Server', 'Applications')[$rng.Next(0, 4)], 'P{0}' -f $rng.Next(1, 5),
                    $(if ($open) { [DBNull]::Value } else { [math]::Round(2 + 40 * $rng.NextDouble(), 1) }))
            }
            $view = @{ rows = @('Team'); cols = @('Priority'); values = @(@{ field = 'Ticket'; agg = 'count' }) }
            New-UDPivotReport -Id 'pivot-datatable' -Data $tickets -View $view -Height 620px -TimeZone UTC -Templates @(
                @{ Name = 'Tickets per team and priority'; View = $view }
                @{ Name = 'Lead time per month'; View = @{ rows = @('Created'); values = @(@{ field = 'Lead hours'; agg = 'average'; format = 'number:1' }); display = 'chart'; chart = @{ type = 'line' } } }
            ) -OnCellClick {
                Show-UDToast -Message ('{0} tickets' -f $EventData.count)
            } -OnSaveTemplate {
                # checked before it is stored anywhere (see "Templates, view files and roles")
                $json = ConvertFrom-UDPivotView -InputObject $EventData.view -AsJson
                Show-UDToast -Message ('{0} saved ({1} characters)' -f $EventData.name, $json.Length)
            }
        }
    }
    @{ Section = 'Pivot'; Title = 'Shared views and my views'; Text = 'Open Views: shared views from -Templates, the reader''s own under My views. This reader has the role of -AdminRole, so each own view can be published, a loaded shared view saved over (Save, after a question) and shared views deleted; Save as asks before it replaces one of My views; the page shows the $EventData the server would get. On a PSU server -TemplateStore does the storing.'; Code = {
            $rng = [System.Random]::new(21)
            $rows = foreach ($i in 1..400) {
                [pscustomobject]@{ Ticket = $i; Team = ('Service Desk', 'Network', 'Server')[$rng.Next(0, 3)]; Priority = 'P{0}' -f $rng.Next(1, 5); 'Lead hours' = [math]::Round(2 + 30 * $rng.NextDouble(), 1) }
            }
            $perTeam = @{ rows = @('Team'); values = @(@{ field = 'Ticket'; agg = 'count' }) }
            New-UDPivotReport -Id 'pivot-templates' -Data $rows -View $perTeam -Height 560px -TimeZone UTC -Templates @(
                @{ Name = 'Tickets per team'; View = $perTeam }
                @{ Name = 'Lead time per priority'; View = @{ rows = @('Priority'); values = @(@{ field = 'Lead hours'; agg = 'average'; format = 'number:1' }); display = 'chart'; chart = @{ type = 'donut'; labelPosition = 'inside' } } }
                @{ Name = 'My priorities'; Scope = 'user'; Deletable = $true; View = @{ rows = @('Priority'); cols = @('Team'); values = @(@{ field = 'Ticket'; agg = 'count' }) } }
            ) -AdminRole 'Administrator' -UserName 'kim' -Roles 'Administrator' -OnSaveTemplate {
                $json = ConvertTo-UDPivotViewFile -View $EventData.view -Name $EventData.name -SourceId 'pivot-templates'
            } -OnDeleteTemplate {
                # $EventData.scope: user or shared; a shared delete needs the role (check $Roles here)
            } -OnPublishTemplate {
                if ($Roles -notcontains 'Administrator') { return @{ error = 'Only admins can change shared views.' } }
            }
        }
    }
    @{ Section = 'Pivot'; Title = 'Readers'' files with smaller limits'; Text = 'Drop a CSV, JSON or Excel file of your own onto the report, or pick it under Data, Load data. -ImportLimit lowers pivotkit''s limits for files loaded into this report to at most 1 MB and 200 rows: a larger file is refused with a message that names the limit, while the app''s own 300 rows keep pivotkit''s limits. The file is read in the browser and never uploaded.'; Code = {
            $rng = [System.Random]::new(17)
            $rows = foreach ($i in 1..300) {
                [pscustomobject]@{ Ticket = $i; Team = ('Service Desk', 'Network', 'Server')[$rng.Next(0, 3)]; 'Lead hours' = [math]::Round(2 + 30 * $rng.NextDouble(), 1) }
            }
            New-UDPivotReport -Id 'pivot-import-limits' -Data $rows -Height 560px -TimeZone UTC -AllowImport -ImportLimit @{ fileBytes = 1MB; rows = 200 } -View @{
                rows = @('Team'); values = @(@{ field = 'Ticket'; agg = 'count' })
            }
        }
    }
    @{ Section = 'Pivot'; Title = 'Placeholder while the data loads'; Text = 'What New-UDPivotReportPlaceholder shows in New-UDDynamic -LoadingComponent until the report arrives: pivotkit''s own skeleton of the report in its colours, moving unless the reader asked for reduced motion.'; Code = {
            New-UDPivotReportPlaceholder -Height 420px
        }
    }
    @{ Section = 'Pivot'; Title = 'Pivot report in German'; Text = '-Locale de-DE: German labels, numbers and dates; -FieldDefaults gives Lead hours an average with one decimal when it is put into Values.'; Code = {
            $rng = [System.Random]::new(9)
            $rows = foreach ($i in 1..600) {
                [pscustomobject]@{ Ticket = $i; Team = ('Service Desk', 'Netzwerk', 'Server')[$rng.Next(0, 3)]; Kunde = 'Kunde {0}' -f [char](65 + $rng.Next(0, 4)); 'Lead hours' = [math]::Round(2 + 30 * $rng.NextDouble(), 1) }
            }
            New-UDPivotReport -Id 'pivot-german' -Data $rows -Locale de-DE -Height 560px -TimeZone UTC -FieldDefaults @{ 'Lead hours' = @{ Agg = 'average'; Format = 'number:1' } } -View @{
                rows = @('Kunde'); cols = @('Team'); values = @(@{ field = 'Lead hours'; agg = 'average'; format = 'number:1' })
            }
        }
    }
    @{ Section = 'Pivot'; Title = 'Field names and descriptions'; Text = 'Labels, descriptions with a link, the order of Status and the type of Created from a JSON Schema; one description from -FieldDescriptions (as Get-UDPivotSqlColumnDescription returns them), aggregator and format from -FieldDefaults. Hover or tap the "i" next to a field.'; Code = {
            $rng = [System.Random]::new(13)
            $rows = foreach ($i in 1..500) {
                [pscustomobject]@{
                    Id        = 20000 + $i
                    Created   = ([datetime]'2026-10-31').AddDays(-$rng.Next(0, 200)).ToString('yyyy-MM-dd')
                    Team      = ('Service Desk', 'Network', 'Server')[$rng.Next(0, 3)]
                    Status    = ('Open', 'Waiting', 'Closed', 'Closed')[$rng.Next(0, 4)]
                    LeadHours = [math]::Round(2 + 30 * $rng.NextDouble(), 1)
                }
            }
            $schema = @{
                type       = 'object'
                properties = @{
                    Id        = @{ type = 'integer'; title = 'Ticket number' }
                    Created   = @{ type = 'string'; format = 'date'; description = 'The day the customer reported it.' }
                    Status    = @{ type = 'string'; enum = @('Open', 'Waiting', 'Closed'); description = 'Open, waiting for the customer, or closed.' }
                    LeadHours = @{ type = 'number'; title = 'Lead time (h)'; externalDocs = @{ url = 'https://powershell-universal-components.eize.dev/pivot/fields/' } }
                }
            }
            New-UDPivotReport -Id 'pivot-fields' -Data $rows -Schema $schema -Height 560px -TimeZone UTC `
                -FieldDescriptions @{ Team = 'The team the ticket is assigned to.' } `
                -FieldDefaults @{ LeadHours = @{ Agg = 'average'; Format = 'number:1'; Description = 'Hours from creation to closing.' } } `
                -View @{ rows = @('Team'); cols = @('Status'); values = @(@{ field = 'LeadHours'; agg = 'average'; format = 'number:1' }) }
        }
    }
    #endregion
)
