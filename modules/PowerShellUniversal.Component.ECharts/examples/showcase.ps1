<#
    Showcase app for PowerShellUniversal.Component.ECharts: every chart type with realistic data, from
    simple bars to a ticket report, finance charts, public APIs, PowerShell and DataTable data, live
    updates and a benchmark. Ticket and finance data are generated with a fixed seed, so every load shows
    the same numbers; the public APIs need internet access from the PSU server.

    Deploy: copy into an app (admin console) or with PSUTools: Set-PSUTestApp -Name EChartsShowcase
    -BaseUrl /echarts -ScriptPath ./examples/showcase.ps1
#>

#region Generated ticket data (2000 tickets, last 120 days)
if (-not $Cache:EChartsTickets) {
    $rng = [System.Random]::new(42)
    $teams = 'Service Desk', 'Network', 'Server', 'Applications'
    $priorities = 'P1', 'P2', 'P3', 'P4'
    $channels = 'Mail', 'Phone', 'Portal', 'Monitoring'
    $start = (Get-Date).Date.AddDays(-120)
    $Cache:EChartsTickets = foreach ($i in 1..2000) {
        $created = $start.AddDays($rng.Next(0, 120)).AddHours([math]::Min(23, [math]::Max(0, [int](8 + 4 * ($rng.NextDouble() + $rng.NextDouble() - 1) * 2)))).AddMinutes($rng.Next(0, 60))
        $priority = $priorities[[math]::Min(3, [int][math]::Floor([math]::Pow($rng.NextDouble(), 0.6) * 4))]
        $factor = @{ P1 = 0.3; P2 = 0.7; P3 = 1.0; P4 = 1.6 }[$priority]
        # lead time: log-normal, a few long runners
        $lead = [math]::Round([math]::Exp(2.6 + 0.9 * ($rng.NextDouble() + $rng.NextDouble() + $rng.NextDouble() - 1.5)) * $factor, 1)
        $status = if ($created -gt (Get-Date).AddDays(-7) -and $rng.NextDouble() -lt 0.5) { 'Open' } elseif ($rng.NextDouble() -lt 0.08) { 'Waiting' } else { 'Closed' }
        [pscustomobject]@{
            Id              = 10000 + $i
            Created         = $created
            Team            = $teams[$rng.Next(0, 4)]
            Priority        = $priority
            Channel         = $channels[$rng.Next(0, 4)]
            Status          = $status
            LeadHours       = $lead
            HoldHours       = [math]::Round($lead * 0.25 * $rng.NextDouble(), 1)
            WaitHours       = [math]::Round($lead * 0.35 * $rng.NextDouble(), 1)
            ResponseMinutes = [math]::Round(5 + 90 * [math]::Pow($rng.NextDouble(), 2) * $factor)
        }
    }
}
#endregion

New-UDApp -Title 'ECharts for PowerShell Universal' -Pages @(

    #region Basics
    New-UDPage -Name 'Basics' -Url '/basics' -Content {
        $months = 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        $sales = for ($m = 0; $m -lt 12; $m++) {
            [pscustomobject]@{ Month = $months[$m]; Online = 120 + 15 * $m + (($m * 37) % 40); Store = 200 - 6 * $m + (($m * 53) % 30); Partner = 60 + 4 * $m }
        }
        New-UDTypography -Variant h5 -Text 'Basics: two lines of PowerShell each'
        New-UDGrid -Container -Content {
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Bar' -Content { New-UDEChart -Data $sales -Type bar -X Month -Y Online, Store, Partner -Height 320px }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Stacked bar with labels' -Content { New-UDEChart -Data $sales -Type bar -X Month -Y Online, Store, Partner -Stacked -DataLabels -Height 320px }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Smooth area, stacked' -Content { New-UDEChart -Data $sales -Type area -X Month -Y Online, Store, Partner -Stacked -Smooth -Height 320px }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Horizontal bar, sorted' -Content {
                    New-UDEChart -Data ($sales | Sort-Object Online -Descending) -Type bar -Horizontal -X Month -Y Online -DataLabels -Height 320px
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 4 -Content {
                New-UDCard -Title 'Pie' -Content {
                    New-UDEChart -Type pie -X Channel -Y Count -Height 300px -Data ($Cache:EChartsTickets | Group-Object Channel | Select-Object @{ n = 'Channel'; e = { $_.Name } }, Count)
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 4 -Content {
                New-UDCard -Title 'Donut, click shows a toast' -Content {
                    New-UDEChart -Type donut -X Status -Y Count -Height 300px -Data ($Cache:EChartsTickets | Group-Object Status | Select-Object @{ n = 'Status'; e = { $_.Name } }, Count) `
                        -OnClick { Show-UDToast -Message ('{0}: {1} tickets' -f $EventData.name, $EventData.value) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 4 -Content {
                New-UDCard -Title 'Scatter: response vs lead time' -Content {
                    New-UDEChart -Type scatter -X ResponseMinutes -Y LeadHours -GroupBy Priority -XAxisType Value -Height 300px -Data ($Cache:EChartsTickets | Select-Object -First 600)
                }
            }
        }
    }
    #endregion

    #region Bars
    New-UDPage -Name 'Bars' -Url '/bars' -Content {
        $rng = [System.Random]::new(3)
        $teams = 'Service Desk', 'Network', 'Server', 'Applications', 'Security', 'Database'
        $statusRows = foreach ($t in $teams) { [pscustomobject]@{ Team = $t; Open = $rng.Next(5, 60); Waiting = $rng.Next(2, 25); Closed = $rng.Next(80, 400) } }
        $months = 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'
        function Add-ChartCard {
            # one grid cell with a card around a chart (the parameters are used inside -Content)
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
            param([string]$Title, [int]$Size, [scriptblock]$Chart)
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize $Size -Content { New-UDCard -Title $Title -Content $Chart }
        }
        New-UDTypography -Variant h5 -Text 'Bar charts in every variant'
        New-UDGrid -Container -Content {
            Add-ChartCard 'Columns with values' 4 { New-UDEChart -Data $statusRows -Type bar -X Team -Y Closed -DataLabels -Height 300px }
            Add-ChartCard 'Grouped' 4 { New-UDEChart -Data $statusRows -Type bar -X Team -Y Open, Waiting, Closed -Height 300px }
            Add-ChartCard 'Stacked' 4 { New-UDEChart -Data $statusRows -Type bar -X Team -Y Open, Waiting, Closed -Stacked -Height 300px }
            Add-ChartCard 'Stacked horizontal' 6 { New-UDEChart -Data $statusRows -Type bar -Horizontal -X Team -Y Open, Waiting, Closed -Stacked -DataLabels -Height 340px }
            Add-ChartCard 'Stacked to 100 % (share per team; tooltip shows the counts)' 6 { New-UDEChart -Data $statusRows -Type bar -Horizontal -X Team -Y Open, Waiting, Closed -Normalize -DataLabels -LabelFormat 'percent100:0' -Height 340px }
            Add-ChartCard 'Negative values, horizontal: budget variance per department' 6 {
                $variance = foreach ($d in 'IT', 'HR', 'Sales', 'Marketing', 'Logistics', 'Production', 'Finance', 'Legal') { [pscustomobject]@{ Department = $d; Variance = $rng.Next(-180000, 140000) } }
                New-UDEChart -Data ($variance | Sort-Object Variance) -Type bar -Horizontal -X Department -Y Variance -Format 'currency:EUR' -Locale de-DE -NegativeColor '#e53935' -DataLabels -Height 340px
            }
            Add-ChartCard 'Diverging: survey answers (negative to the left)' 6 {
                $survey = foreach ($q in 'Response time', 'Communication', 'Solution quality', 'Self-service portal', 'Opening hours') {
                    $neg = $rng.Next(5, 35)
                    [pscustomobject]@{ Question = $q; 'Disagree' = - $neg; 'Rather disagree' = - $rng.Next(5, 20); 'Rather agree' = $rng.Next(15, 35); 'Agree' = $rng.Next(20, 50) }
                }
                New-UDEChart -Data $survey -Type bar -Horizontal -X Question -Y 'Disagree', 'Rather disagree', 'Rather agree', 'Agree' -Stacked -Height 340px -Palette '#c62828', '#ef9a9a', '#a5d6a7', '#2e7d32' `
                    -Options @{ xAxis = @{ axisLabel = @{} } }
            }
            Add-ChartCard 'Select columns with the brush (toolbox), the range comes back as a toast' 6 {
                $daily = foreach ($d in 0..29) { [pscustomobject]@{ Day = (Get-Date).Date.AddDays(-29 + $d); Changes = $rng.Next(3, 40) } }
                New-UDEChart -Data $daily -Type bar -X Day -Y Changes -Brush -Height 320px -OnSelect { Show-UDToast -Message ('Selected {0} to {1}' -f $EventData.from, $EventData.to) }
            }
            Add-ChartCard 'Zoom on the value axis: one outlier, small values still readable (slider on the right)' 6 {
                $disk = foreach ($s in 1..14) { [pscustomobject]@{ Server = 'srv{0:00}' -f $s; 'Disk GB' = if ($s -eq 7) { 9800 } else { $rng.Next(40, 420) } } }
                New-UDEChart -Data $disk -Type bar -X Server -Y 'Disk GB' -Zoom Both -ZoomAxis Y -DataLabels -Height 320px
            }
            Add-ChartCard 'Bars and a line on a second axis: tickets and SLA %' 6 {
                $mixed = foreach ($m in $months) { [pscustomobject]@{ Month = $m; Tickets = $rng.Next(600, 1100); 'SLA %' = [math]::Round(92 + 7 * $rng.NextDouble(), 1) } }
                New-UDEChart -Data $mixed -Type bar -X Month -Y Tickets, 'SLA %' -SecondaryY 'SLA %' -SecondaryTitle 'SLA %' -Height 320px -Options @{ series = @(@{}, @{ type = 'line'; smooth = $true; symbolSize = 8 }); yAxis = @(@{}, @{ min = 90; max = 100 }) }
            }
            Add-ChartCard 'Sorted, with the average' 6 {
                $apps = foreach ($a in 'SAP', 'Exchange', 'SharePoint', 'Teams', 'Jira', 'Confluence', 'GitLab', 'ServiceNow', 'Salesforce', 'Workday') { [pscustomobject]@{ App = $a; Incidents = $rng.Next(2, 60) } }
                New-UDEChart -Data ($apps | Sort-Object Incidents -Descending) -Type bar -X App -Y Incidents -MarkLine average -DataLabels -Height 320px
            }
            Add-ChartCard 'Many categories: 80 servers, zoom with the slider' 12 {
                $many = foreach ($s in 1..80) { [pscustomobject]@{ Server = 'vm-{0:000}' -f $s; CPU = $rng.Next(2, 95); RAM = $rng.Next(10, 98) } }
                New-UDEChart -Data $many -Type bar -X Server -Y CPU, RAM -Format percent100 -Zoom Both -Height 340px -MarkLine @{ value = 85; name = 'Threshold'; color = '#e53935' }
            }
            Add-ChartCard 'Rounded corners and a target line through -Options' 6 {
                New-UDEChart -Data $statusRows -Type bar -X Team -Y Closed -Height 300px -MarkLine @{ value = 250; name = 'Target'; color = '#43a047' } -Options @{ series = @(@{ itemStyle = @{ borderRadius = @(6, 6, 0, 0) }; barWidth = '45%' }) }
            }
            Add-ChartCard 'Monthly trend as stacked area of bars (step)' 6 {
                $trend = foreach ($m in $months) { [pscustomobject]@{ Month = $m; IaaS = $rng.Next(200, 400); PaaS = $rng.Next(80, 200); SaaS = $rng.Next(120, 260) } }
                New-UDEChart -Data $trend -Type bar -X Month -Y IaaS, PaaS, SaaS -Stacked -Format compact -Height 300px -Options @{ series = @(@{ barCategoryGap = '10%' }) }
            }
        }
    }
    #endregion

    #region Ticket report
    New-UDPage -Name 'Ticket report' -Url '/tickets' -Content {
        $tickets = $Cache:EChartsTickets
        $closed = @($tickets | Where-Object Status -EQ 'Closed')
        $sla = 48
        $sorted = $closed.LeadHours | Sort-Object
        $median = $sorted[[int][math]::Floor($sorted.Count / 2)]
        $within = ($closed | Where-Object LeadHours -LE $sla).Count / [math]::Max(1, $closed.Count)

        New-UDTypography -Variant h5 -Text 'Ticket report'
        New-UDTypography -Variant body2 -Text ('{0} tickets, {1} closed, median lead time {2:N1} h, {3:P1} within the {4} h SLA. Click a bar or select a range to filter the table.' -f $tickets.Count, $closed.Count, $median, $within, $sla)

        New-UDGrid -Container -Content {
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 4 -Content {
                New-UDCard -Title 'SLA compliance' -Content {
                    New-UDEChart -Type gauge -Data @([pscustomobject]@{ Name = 'within SLA'; Value = [math]::Round($within * 100, 1) }) -X Name -Y Value -Format percent100 -Height 260px
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 8 -Content {
                New-UDCard -Title 'Opened per day: this period vs previous period' -Content {
                    # last 60 days against the 60 before, aligned by day number
                    $today = (Get-Date).Date
                    $perDay = foreach ($offset in 0..59) {
                        $now = $today.AddDays(-59 + $offset)
                        $before = $now.AddDays(-60)
                        [pscustomobject]@{
                            Day      = 'Day {0}' -f ($offset + 1)
                            Current  = @($tickets | Where-Object { $_.Created.Date -eq $now }).Count
                            Previous = @($tickets | Where-Object { $_.Created.Date -eq $before }).Count
                        }
                    }
                    New-UDEChart -Data $perDay -Type line -X Day -Y Current, Previous -Smooth -Height 260px -MarkLine average `
                        -Options @{ series = @(@{ name = 'This period' }, @{ name = 'Previous period'; lineStyle = @{ type = 'dashed' }; itemStyle = @{ opacity = 0.6 } }) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Lead time distribution with median and SLA' -Content {
                    New-UDEChart -Data $closed -Type histogram -Y LeadHours -Format 'duration:h' -Bins 30 -Height 320px `
                        -MarkLine 'median', @{ value = $sla; name = 'SLA'; color = '#e53935' } -XTitle 'Lead time'
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Lead time by team (boxplot: quartiles, whiskers, outliers)' -Content {
                    New-UDEChart -Data $closed -Type boxplot -X Team -Y LeadHours -Format 'duration:h' -Height 320px
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Tickets per team and priority (click filters the table)' -Content {
                    $byTeam = $tickets | Group-Object Team, Priority | ForEach-Object {
                        [pscustomobject]@{ Team = $_.Group[0].Team; Priority = $_.Group[0].Priority; Tickets = $_.Count }
                    } | Sort-Object Team, Priority
                    New-UDEChart -Data $byTeam -Type bar -X Team -Y Tickets -GroupBy Priority -Stacked -Height 320px -OnClick {
                        $Session:TicketFilter = @{ Team = $EventData.name; Priority = $EventData.seriesName }
                        Sync-UDElement -Id 'ticket-table'
                    }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Average times per team (hours)' -Content {
                    $avg = $closed | Group-Object Team | ForEach-Object {
                        [pscustomobject]@{
                            Team     = $_.Name
                            Lead     = [math]::Round(($_.Group | Measure-Object LeadHours -Average).Average, 1)
                            Hold     = [math]::Round(($_.Group | Measure-Object HoldHours -Average).Average, 1)
                            Waiting  = [math]::Round(($_.Group | Measure-Object WaitHours -Average).Average, 1)
                            Response = [math]::Round(($_.Group | Measure-Object ResponseMinutes -Average).Average / 60, 2)
                        }
                    }
                    New-UDEChart -Data $avg -Type bar -X Team -Y Lead, Hold, Waiting, Response -Format 'number:1' -DataLabels -Height 320px
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -Content {
                New-UDCard -Title 'Tickets per day: select a range (brush button) to filter the table' -Content {
                    $daily = $tickets | Group-Object { $_.Created.Date } | ForEach-Object {
                        [pscustomobject]@{ Day = [datetime]$_.Name; Opened = $_.Count; P1 = @($_.Group | Where-Object Priority -EQ 'P1').Count }
                    } | Sort-Object Day
                    New-UDEChart -Data $daily -Type bar -X Day -Y Opened, P1 -SecondaryY P1 -SecondaryTitle 'P1' -Zoom Both -Brush -Height 320px `
                        -Options @{ series = @(@{}, @{ type = 'line'; smooth = $true }) } -OnSelect {
                        $Session:TicketFilter = @{ From = $EventData.from; To = $EventData.to }
                        Sync-UDElement -Id 'ticket-table'
                    }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Tickets per day (calendar)' -Content {
                    $perDate = $tickets | Group-Object { $_.Created.ToString('yyyy-MM-dd') } | Select-Object @{ n = 'Date'; e = { $_.Name } }, Count
                    New-UDEChart -Data $perDate -Type calendar -X Date -Y Count -Height 220px
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Created: weekday x hour' -Content {
                    $days = 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
                    $grid = $tickets | Group-Object { $_.Created.DayOfWeek }, { $_.Created.Hour } | ForEach-Object {
                        [pscustomobject]@{ Hour = '{0:00}' -f $_.Group[0].Created.Hour; Weekday = [string]$_.Group[0].Created.DayOfWeek; Tickets = $_.Count }
                    } | Sort-Object @{ e = { [int]$_.Hour } }, @{ e = { $days.IndexOf($_.Weekday) } }
                    New-UDEChart -Data $grid -Type heatmap -X Hour -Y Weekday -Value Tickets -Height 300px
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Channel to team to status (sankey)' -Content {
                    $flows = @(
                        $tickets | Group-Object Channel, Team | ForEach-Object { [pscustomobject]@{ Source = $_.Group[0].Channel; Target = $_.Group[0].Team; Value = $_.Count } }
                        $tickets | Group-Object Team, Status | ForEach-Object { [pscustomobject]@{ Source = $_.Group[0].Team; Target = $_.Group[0].Status; Value = $_.Count } }
                    )
                    New-UDEChart -Data $flows -Type sankey -Height 360px
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Status funnel' -Content {
                    $all = $tickets.Count
                    $responded = @($tickets | Where-Object ResponseMinutes -LE 60).Count
                    New-UDEChart -Type funnel -X Stage -Y Tickets -Height 360px -Data @(
                        [pscustomobject]@{ Stage = 'Created'; Tickets = $all }
                        [pscustomobject]@{ Stage = 'Answered within 1 h'; Tickets = $responded }
                        [pscustomobject]@{ Stage = 'Closed'; Tickets = $closed.Count }
                        [pscustomobject]@{ Stage = 'Closed within SLA'; Tickets = @($closed | Where-Object LeadHours -LE $sla).Count }
                    )
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -Content {
                New-UDDynamic -Id 'ticket-table' -Content {
                    $rows = $Cache:EChartsTickets
                    $f = $Session:TicketFilter
                    $label = 'all tickets'
                    if ($f -and $f.Team) {
                        $rows = $rows | Where-Object { $_.Team -eq $f.Team -and $_.Priority -eq $f.Priority }
                        $label = '{0}, {1}' -f $f.Team, $f.Priority
                    }
                    elseif ($f -and $f.From) {
                        $from = [datetime]$f.From; $to = [datetime]$f.To
                        $rows = $rows | Where-Object { $_.Created -ge $from -and $_.Created -le $to.AddDays(1) }
                        $label = '{0:d} to {1:d}' -f $from, $to
                    }
                    New-UDCard -Title ('Tickets: {0} ({1})' -f $label, @($rows).Count) -Content {
                        New-UDButton -Text 'Show all' -Variant outlined -OnClick { $Session:TicketFilter = $null; Sync-UDElement -Id 'ticket-table' }
                        New-UDTable -Data (@($rows) | Sort-Object Created -Descending | Select-Object -First 200 Id, @{ n = 'Created'; e = { $_.Created.ToString('yyyy-MM-dd HH:mm') } }, Team, Priority, Channel, Status, LeadHours) -Dense -PageSize 10 -ShowSort
                    }
                }
            }
        }
    }
    #endregion

    #region Finance
    New-UDPage -Name 'Finance' -Url '/finance' -Content {
        $months = 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        $rng = [System.Random]::new(7)
        $planActual = for ($m = 0; $m -lt 10; $m++) {
            $plan = 820000 + 25000 * $m
            $actual = [math]::Round($plan * (0.9 + 0.2 * $rng.NextDouble()))
            [pscustomobject]@{ Month = $months[$m]; Plan = $plan; Actual = $actual; Variance = $actual - $plan }
        }
        $ytd = 0; $ytdPlan = 0
        $cumulative = foreach ($row in $planActual) {
            $ytd += $row.Actual; $ytdPlan += $row.Plan
            [pscustomobject]@{ Month = $row.Month; 'Actual YTD' = $ytd; 'Plan YTD' = $ytdPlan }
        }
        New-UDTypography -Variant h5 -Text 'Finance'
        New-UDGrid -Container -Content {
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Profit bridge (waterfall)' -Content {
                    New-UDEChart -Type waterfall -X Step -Y Amount -Totals 'Gross margin', 'Operating result' -Format 'currency:EUR' -Locale de-DE -Height 360px -Data @(
                        [pscustomobject]@{ Step = 'Revenue'; Amount = 9850000 }
                        [pscustomobject]@{ Step = 'Material'; Amount = -3420000 }
                        [pscustomobject]@{ Step = 'Freight'; Amount = -410000 }
                        [pscustomobject]@{ Step = 'Gross margin'; Amount = 0 }
                        [pscustomobject]@{ Step = 'Staff'; Amount = -3150000 }
                        [pscustomobject]@{ Step = 'Rent'; Amount = -620000 }
                        [pscustomobject]@{ Step = 'IT'; Amount = -480000 }
                        [pscustomobject]@{ Step = 'Other income'; Amount = 260000 }
                        [pscustomobject]@{ Step = 'Operating result'; Amount = 0 }
                    )
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Plan vs actual per month' -Content {
                    New-UDEChart -Data $planActual -Type bar -X Month -Y Plan, Actual -Format compact -Locale de-DE -Height 360px `
                        -Options @{ series = @(@{ itemStyle = @{ color = 'transparent'; borderColor = '#909399'; borderWidth = 2 }; barGap = '-100%'; z = 3 }, @{ barWidth = '50%' }) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Variance to plan (negative in red)' -Content {
                    New-UDEChart -Data $planActual -Type bar -X Month -Y Variance -Format 'currency:EUR' -Locale de-DE -NegativeColor '#e53935' -DataLabels -Height 320px `
                        -Options @{ series = @(@{ label = @{ fontSize = 10 } }) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Year to date' -Content {
                    New-UDEChart -Data $cumulative -Type area -X Month -Y 'Actual YTD', 'Plan YTD' -Format compact -Locale de-DE -Height 320px `
                        -Options @{ series = @(@{}, @{ areaStyle = @{ opacity = 0 }; lineStyle = @{ type = 'dashed' } }) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Cost centres (treemap, click to zoom in)' -Content {
                    $costs = @(
                        [pscustomobject]@{ Division = 'Operations'; Department = 'Logistics'; Cost = 1850000 }
                        [pscustomobject]@{ Division = 'Operations'; Department = 'Production'; Cost = 3120000 }
                        [pscustomobject]@{ Division = 'Operations'; Department = 'Quality'; Cost = 540000 }
                        [pscustomobject]@{ Division = 'Sales'; Department = 'Field sales'; Cost = 1320000 }
                        [pscustomobject]@{ Division = 'Sales'; Department = 'Marketing'; Cost = 760000 }
                        [pscustomobject]@{ Division = 'Administration'; Department = 'Finance'; Cost = 610000 }
                        [pscustomobject]@{ Division = 'Administration'; Department = 'IT'; Cost = 980000 }
                        [pscustomobject]@{ Division = 'Administration'; Department = 'HR'; Cost = 420000 }
                    )
                    New-UDEChart -Data $costs -Type treemap -Path Division, Department -Y Cost -Format compact -Locale de-DE -Height 360px
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Same data as sunburst' -Content {
                    New-UDEChart -Type sunburst -Path Division, Department -Y Cost -Format compact -Locale de-DE -Height 360px -Data @(
                        [pscustomobject]@{ Division = 'Operations'; Department = 'Logistics'; Cost = 1850000 }
                        [pscustomobject]@{ Division = 'Operations'; Department = 'Production'; Cost = 3120000 }
                        [pscustomobject]@{ Division = 'Sales'; Department = 'Field sales'; Cost = 1320000 }
                        [pscustomobject]@{ Division = 'Sales'; Department = 'Marketing'; Cost = 760000 }
                        [pscustomobject]@{ Division = 'Administration'; Department = 'IT'; Cost = 980000 }
                        [pscustomobject]@{ Division = 'Administration'; Department = 'HR'; Cost = 420000 }
                    )
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -Content {
                New-UDCard -Title 'Share price with volume (candlestick, generated)' -Content {
                    $price = 100.0
                    $day = (Get-Date).Date.AddDays(-180)
                    $ohlc = foreach ($i in 1..180) {
                        $day = $day.AddDays(1)
                        if ($day.DayOfWeek -in 'Saturday', 'Sunday') { continue }
                        $open = $price
                        $close = [math]::Round($open * (1 + ($rng.NextDouble() - 0.48) * 0.04), 2)
                        $price = $close
                        [pscustomobject]@{
                            Date = $day.ToString('yyyy-MM-dd'); Open = $open; Close = $close
                            Low = [math]::Round([math]::Min($open, $close) * (1 - $rng.NextDouble() * 0.015), 2)
                            High = [math]::Round([math]::Max($open, $close) * (1 + $rng.NextDouble() * 0.015), 2)
                            Volume = $rng.Next(80000, 400000)
                        }
                    }
                    New-UDEChart -Data $ohlc -Type candlestick -X Date -Open Open -Close Close -Low Low -High High -Volume Volume -Format 'currency:EUR' -Locale de-DE -Height 420px -MarkLine 'max', 'min'
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Revenue by region' -Content {
                    New-UDEChart -Type donut -X Region -Y Revenue -Format 'currency:EUR' -Locale de-DE -Height 320px -Data @(
                        [pscustomobject]@{ Region = 'DACH'; Revenue = 4120000 }
                        [pscustomobject]@{ Region = 'Benelux'; Revenue = 1350000 }
                        [pscustomobject]@{ Region = 'Nordics'; Revenue = 980000 }
                        [pscustomobject]@{ Region = 'UK'; Revenue = 1720000 }
                        [pscustomobject]@{ Region = 'Rest of world'; Revenue = 1680000 }
                    )
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Department scores (radar)' -Content {
                    New-UDEChart -Type radar -X Department -Y Budget, Quality, Speed, Satisfaction, Innovation -Max 100 -Height 320px -Data @(
                        [pscustomobject]@{ Department = 'Logistics'; Budget = 82; Quality = 74; Speed = 91; Satisfaction = 68; Innovation = 55 }
                        [pscustomobject]@{ Department = 'IT'; Budget = 64; Quality = 88; Speed = 72; Satisfaction = 79; Innovation = 93 }
                        [pscustomobject]@{ Department = 'Sales'; Budget = 91; Quality = 69; Speed = 84; Satisfaction = 86; Innovation = 61 }
                    )
                }
            }
        }
    }
    #endregion

    #region Managed services
    New-UDPage -Name 'Managed services' -Url '/msp' -Content {
        # A managed service provider's platform: generated with a fixed seed
        $rng = [System.Random]::new(2026)
        New-UDTypography -Variant h5 -Text 'Managed services: VMware, Windows and Linux, storage, network, backup'
        New-UDGrid -Container -Content {
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'VMware clusters: CPU and RAM use, vCPU:pCPU' -Content {
                    $clusters = foreach ($c in 'CL-PROD-01', 'CL-PROD-02', 'CL-PROD-03', 'CL-DMZ-01', 'CL-VDI-01', 'CL-TEST-01') {
                        [pscustomobject]@{ Cluster = $c; 'CPU %' = [math]::Round(35 + 50 * $rng.NextDouble(), 1); 'RAM %' = [math]::Round(50 + 45 * $rng.NextDouble(), 1); 'vCPU:pCPU' = [math]::Round(1.5 + 4 * $rng.NextDouble(), 1) }
                    }
                    New-UDEChart -Data $clusters -Type bar -X Cluster -Y 'CPU %', 'RAM %', 'vCPU:pCPU' -SecondaryY 'vCPU:pCPU' -SecondaryTitle 'vCPU:pCPU' -YMax 100 -Height 340px `
                        -MarkLine @{ value = 85; name = 'RAM threshold'; color = '#e53935' } -Options @{ series = @(@{}, @{}, @{ type = 'line'; symbolSize = 10 }) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Virtual machines by operating system and support status' -Content {
                    $os = @(
                        @('Windows Server 2016', 'Extended support', 412), @('Windows Server 2019', 'Mainstream ended', 1180), @('Windows Server 2022', 'Supported', 1640),
                        @('Windows Server 2025', 'Supported', 310), @('RHEL 8', 'Supported', 520), @('RHEL 9', 'Supported', 690), @('Ubuntu 22.04', 'Supported', 840),
                        @('Ubuntu 24.04', 'Supported', 460), @('Debian 12', 'Supported', 280), @('SLES 15', 'Supported', 150), @('CentOS 7', 'End of life', 96), @('Windows Server 2012 R2', 'End of life', 64)
                    ) | ForEach-Object { [pscustomobject]@{ OS = $_[0]; Support = $_[1]; VMs = $_[2] } } | Sort-Object VMs
                    New-UDEChart -Data $os -Type bar -Horizontal -X OS -Y VMs -GroupBy Support -Stacked -Height 380px `
                        -Palette '#e53935', '#fb8c00', '#fdd835', '#43a047' -OnClick { Show-UDToast -Message ('{0}: {1} VMs ({2})' -f $EventData.name, $EventData.value, $EventData.seriesName) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Storage capacity per system (used and free)' -Content {
                    $tb = [math]::Pow(1024, 4)
                    $storage = foreach ($a in @(('NetApp AFF A400 FRA', 420), ('NetApp AFF A250 MUC', 180), ('Pure FlashArray//X FRA', 300), ('vSAN CL-PROD-01', 160), ('vSAN CL-VDI-01', 96), ('Dell PowerScale archive', 1200), ('S3 object (MinIO)', 800))) {
                        $used = $a[1] * (0.45 + 0.5 * $rng.NextDouble())
                        [pscustomobject]@{ System = $a[0]; Used = [math]::Round($used * $tb); Free = [math]::Round(($a[1] - $used) * $tb) }
                    }
                    New-UDEChart -Data $storage -Type bar -Horizontal -X System -Y Used, Free -Stacked -Format bytes -Height 360px -Palette '#5470c6', '#91cc7533'
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Storage growth, 12 months and a 6-month forecast' -Content {
                    $used = 610.0
                    $growth = foreach ($m in -11..6) {
                        $month = (Get-Date -Day 1).AddMonths($m).ToString('yyyy-MM')
                        if ($m -le 0) { $used += 14 + 8 * $rng.NextDouble(); [pscustomobject]@{ Month = $month; 'Used TB' = [math]::Round($used, 1); 'Forecast TB' = $null } }
                        else { [pscustomobject]@{ Month = $month; 'Used TB' = $null; 'Forecast TB' = [math]::Round($used + 18 * $m, 1) } }
                    }
                    New-UDEChart -Data $growth -Type line -X Month -Y 'Used TB', 'Forecast TB' -Height 360px -MarkLine @{ value = 820; name = 'Installed capacity'; color = '#e53935' } `
                        -Options @{ series = @(@{ areaStyle = @{ opacity = 0.2 } }, @{ lineStyle = @{ type = 'dashed' } }) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Datastores: latency vs IOPS (click for details)' -Content {
                    $ds = foreach ($i in 1..60) {
                        $tier = @('Gold (NVMe)', 'Silver (SSD)', 'Bronze (hybrid)')[$i % 3]
                        $base = @{ 'Gold (NVMe)' = 0.4; 'Silver (SSD)' = 1.2; 'Bronze (hybrid)' = 4.5 }[$tier]
                        [pscustomobject]@{ Datastore = 'DS-{0:000}' -f $i; Tier = $tier; IOPS = $rng.Next(500, 60000); 'Latency ms' = [math]::Round($base * (0.5 + 1.5 * $rng.NextDouble()), 2) }
                    }
                    New-UDEChart -Data $ds -Type scatter -X IOPS -Y 'Latency ms' -GroupBy Tier -XAxisType Value -Height 340px -MarkLine @{ value = 5; name = 'Latency SLA' } `
                        -OnClick { Show-UDToast -Message ('{0}: {1} IOPS at {2} ms' -f $EventData.row.datastore, $EventData.row.iops, $EventData.row.'latency ms') }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'WAN link utilisation per hour (%)' -Content {
                    $links = 'FRA-MUC 10G', 'FRA-HAM 10G', 'FRA-AMS 40G', 'Internet FRA 20G', 'Internet MUC 10G', 'MPLS customer A', 'MPLS customer B'
                    $util = foreach ($l in $links) {
                        foreach ($h in 0..23) {
                            $day = [math]::Max(0, [math]::Sin(($h - 6) / 24 * 2 * [math]::PI))
                            [pscustomobject]@{ Hour = '{0:00}:00' -f $h; Link = $l; Utilisation = [math]::Round(8 + 70 * $day * (0.6 + 0.4 * $rng.NextDouble()) + $(if ($h -eq 2) { 55 } else { 0 }), 0) }  # 02:00 backup traffic
                        }
                    }
                    New-UDEChart -Data $util -Type heatmap -X Hour -Y Link -Value Utilisation -Min 0 -Max 100 -Format percent100 -Height 340px `
                        -Options @{ visualMap = @{ inRange = @{ color = @('#1b5e20', '#fdd835', '#e53935') } } }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Backup jobs per night (Veeam): success, warning, failed' -Content {
                    $nights = foreach ($d in -29..0) {
                        $total = 1800 + $rng.Next(0, 120)
                        $failed = $rng.Next(0, 18); $warn = $rng.Next(10, 60)
                        [pscustomobject]@{ Night = (Get-Date).Date.AddDays($d); Success = $total - $failed - $warn; Warning = $warn; Failed = $failed }
                    }
                    New-UDEChart -Data $nights -Type bar -X Night -Y Success, Warning, Failed -Stacked -Height 340px -Palette '#43a047', '#fb8c00', '#e53935' -YMin 1500
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Backup job duration against the 6-hour backup window' -Content {
                    $jobs = foreach ($i in 1..1500) { [pscustomobject]@{ Minutes = [math]::Round([math]::Exp(3.6 + 0.8 * ($rng.NextDouble() + $rng.NextDouble() - 1)), 0) } }
                    New-UDEChart -Data $jobs -Type histogram -Y Minutes -Format 'duration:min' -Bins 25 -Height 340px -MarkLine 'median', @{ value = 360; name = 'Backup window'; color = '#e53935' }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Availability last 30 days vs 99.9 % SLA' -Content {
                    $services = foreach ($svc in 'vCenter', 'IaaS compute', 'Object storage', 'Managed SQL', 'Managed Kubernetes', 'Firewall as a service', 'VDI', 'Exchange hybrid', 'Backup portal') {
                        [pscustomobject]@{ Service = $svc; Availability = [math]::Round(99.8 + 0.2 * $rng.NextDouble(), 3) }
                    }
                    New-UDEChart -Data $services -Type bar -X Service -Y Availability -YMin 99.7 -YMax 100 -Format 'number:2' -DataLabels -Height 340px `
                        -MarkLine @{ value = 99.9; name = 'SLA 99.9 %'; color = '#e53935' }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Incident resolution by priority against SLA (hours)' -Content {
                    $inc = foreach ($i in 1..800) {
                        $p = @('P1', 'P2', 'P3', 'P4')[[math]::Min(3, [int]([math]::Pow($rng.NextDouble(), 0.5) * 4))]
                        $f = @{ P1 = 1.5; P2 = 4; P3 = 12; P4 = 30 }[$p]
                        [pscustomobject]@{ Priority = $p; Hours = [math]::Round($f * [math]::Exp(0.6 * ($rng.NextDouble() + $rng.NextDouble() - 1)), 1) }
                    }
                    New-UDEChart -Data $inc -Type boxplot -X Priority -Y Hours -Format 'duration:h' -Height 340px -LogScale
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -Content {
                New-UDCard -Title 'Monthly recurring revenue by customer and service (click a customer to zoom in)' -Content {
                    $catalog = 'vCPU', 'RAM', 'Block storage', 'Object storage', 'Backup', 'Firewall', 'Managed OS Windows', 'Managed OS Linux', 'Managed SQL', 'Kubernetes', 'Microsoft 365'
                    $mrr = foreach ($cust in 'Contoso AG', 'Fabrikam GmbH', 'Northwind KG', 'Tailspin SE', 'Adatum GmbH', 'Woodgrove Bank', 'Litware Inc', 'Proseware') {
                        foreach ($svc in ($catalog | Get-Random -Count (Get-Random -Minimum 4 -Maximum 9 -SetSeed $cust.Length))) {
                            [pscustomobject]@{ Customer = $cust; Service = $svc; MRR = $rng.Next(800, 24000) }
                        }
                    }
                    New-UDEChart -Data $mrr -Type treemap -Path Customer, Service -Y MRR -Format 'currency:EUR' -Locale de-DE -Height 440px
                }
            }
        }
    }
    #endregion

    #region Operations
    New-UDPage -Name 'Operations & SLA' -Url '/operations' -Content {
        $rng = [System.Random]::new(17)
        $night = (Get-Date).Date.AddDays(-1).AddHours(21)
        New-UDTypography -Variant h5 -Text 'Operations and SLA: timelines, availability, forecasts'
        New-UDGrid -Container -Content {
            New-UDGrid -Item -ExtraSmallSize 12 -Content {
                New-UDCard -Title 'Backup jobs last night per server (gantt; colour = result; zoom with the wheel)' -Content {
                    $jobs = foreach ($srv in 1..14) {
                        $t = $night.AddMinutes($rng.Next(0, 90))
                        foreach ($kind in 'Incremental', 'Log', 'Copy to S3') {
                            $dur = $rng.Next(10, 140)
                            $state = if ($rng.NextDouble() -lt 0.06) { 'Failed' } elseif ($rng.NextDouble() -lt 0.12) { 'Warning' } else { 'Success' }
                            [pscustomobject]@{ Server = 'srv-{0:00}' -f $srv; Job = $kind; Start = $t; End = $t.AddMinutes($dur); Result = $state }
                            $t = $t.AddMinutes($dur + $rng.Next(2, 20))
                        }
                    }
                    New-UDEChart -Data $jobs -Type gantt -X Server -Start Start -End End -GroupBy Result -Value Job -Height 460px -Palette '#e53935', '#43a047', '#fb8c00' `
                        -MarkArea @{ from = $night.AddHours(1).ToString('o'); to = $night.AddHours(1.5).ToString('o'); name = 'Storage maintenance' } `
                        -OnClick { Show-UDToast -Message ('{0} {1}: {2}' -f $EventData.row.server, $EventData.row.job, $EventData.row.result) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 7 -Content {
                New-UDCard -Title 'Maintenance windows and on-call next two weeks' -Content {
                    $start = (Get-Date).Date
                    $plan = @(
                        foreach ($d in 0..13) {
                            $day = $start.AddDays($d)
                            [pscustomobject]@{ Lane = 'On-call'; Start = $day.AddHours(18); End = $day.AddHours(32); Kind = 'On-call'; Who = @('Anna', 'Ben', 'Chris', 'Dana')[$d % 4] }
                            if ($day.DayOfWeek -eq 'Saturday') { [pscustomobject]@{ Lane = 'VMware'; Start = $day.AddHours(6); End = $day.AddHours(10); Kind = 'Maintenance'; Who = 'ESXi patches' } }
                            if ($day.DayOfWeek -eq 'Tuesday' -and $day.Day -ge 8 -and $day.Day -le 14) { [pscustomobject]@{ Lane = 'Windows'; Start = $day.AddHours(20); End = $day.AddHours(24); Kind = 'Patch day'; Who = 'Patch Tuesday' } }
                            if ($day.DayOfWeek -eq 'Thursday') { [pscustomobject]@{ Lane = 'Network'; Start = $day.AddHours(22); End = $day.AddHours(24); Kind = 'Maintenance'; Who = 'Firmware' } }
                        }
                    )
                    New-UDEChart -Data $plan -Type gantt -X Lane -Start Start -End End -GroupBy Kind -Value Who -Height 300px -Zoom Slider
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 5 -Content {
                New-UDCard -Title 'Availability per service (rings)' -Content {
                    New-UDEChart -Type gauge -GaugeStyle Ring -X Service -Y Availability -Min 99 -Max 100 -Format 'percent100:2' -Height 300px -Data @(
                        [pscustomobject]@{ Service = 'IaaS'; Availability = 99.97 }
                        [pscustomobject]@{ Service = 'Managed SQL'; Availability = 99.91 }
                        [pscustomobject]@{ Service = 'Kubernetes'; Availability = 99.85 }
                        [pscustomobject]@{ Service = 'Backup'; Availability = 99.99 }
                    )
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 4 -Content {
                New-UDCard -Title 'SLA this month (grade gauge)' -Content {
                    New-UDEChart -Type gauge -GaugeStyle Grade -Data @([pscustomobject]@{ Name = 'SLA'; Value = 98.7 }) -X Name -Y Value -Min 90 -Max 100 -Format 'percent100:1' -Height 280px `
                        -Thresholds @{ value = 95; color = '#e53935' }, @{ value = 99; color = '#fb8c00' }, @{ value = 100; color = '#43a047' }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 8 -Content {
                New-UDCard -Title 'Customers: revenue vs tickets, bubble size = VMs' -Content {
                    $customers = foreach ($c in 'Contoso', 'Fabrikam', 'Northwind', 'Tailspin', 'Adatum', 'Woodgrove', 'Litware', 'Proseware', 'Alpine Ski', 'Coho Winery', 'Lucerne', 'Margie Travel') {
                        [pscustomobject]@{ Customer = $c; 'Revenue per month' = $rng.Next(8000, 120000); 'Tickets per month' = $rng.Next(10, 400); VMs = $rng.Next(5, 600); Tier = @('Gold', 'Silver', 'Bronze')[$rng.Next(0, 3)] }
                    }
                    New-UDEChart -Data $customers -Type scatter -X 'Revenue per month' -Y 'Tickets per month' -Size VMs -GroupBy Tier -XAxisType Value -Height 300px -XTitle 'Revenue per month' `
                        -OnClick { Show-UDToast -Message ('{0}: {1} VMs' -f $EventData.row.customer, $EventData.row.vms) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Capacity forecast with a confidence band' -Content {
                    $used = 540.0
                    $forecast = foreach ($m in -11..9) {
                        $month = (Get-Date -Day 1).AddMonths($m).ToString('yyyy-MM')
                        if ($m -le 0) { $used += 9 + 6 * $rng.NextDouble(); [pscustomobject]@{ Month = $month; Used = [math]::Round($used); Forecast = $null; Low = $null; High = $null } }
                        else { $f = $used + 12 * $m; [pscustomobject]@{ Month = $month; Used = $null; Forecast = [math]::Round($f); Low = [math]::Round($f - 4 * $m); High = [math]::Round($f + 6 * $m) } }
                    }
                    New-UDEChart -Data $forecast -Type line -X Month -Y Used, Forecast -Band Low, High -BandName 'Forecast range' -Height 320px -YTitle 'TB' `
                        -MarkLine @{ value = 720; name = 'Installed'; color = '#e53935' } -Options @{ series = @(@{}, @{}, @{}, @{ lineStyle = @{ type = 'dashed' } }) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'API latency today with the incident window marked' -Content {
                    $t0 = (Get-Date).Date
                    $lat = foreach ($i in 0..287) { $t = $t0.AddMinutes(5 * $i); [pscustomobject]@{ Time = $t; 'Latency ms' = [math]::Round(80 + 30 * [math]::Sin($i / 20) + $rng.Next(0, 15) + $(if ($i -ge 130 -and $i -le 150) { 400 } else { 0 })) } }
                    New-UDEChart -Data $lat -Type area -X Time -Y 'Latency ms' -Height 320px -MarkLine @{ value = 250; name = 'SLA'; color = '#e53935' } `
                        -MarkArea @{ from = $t0.AddMinutes(650).ToString('o'); to = $t0.AddMinutes(755).ToString('o'); name = 'Incident INC-4711'; color = 'rgba(229,57,53,0.15)' }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Ticket categories (rose / Nightingale)' -Content {
                    New-UDEChart -Type pie -Rose -X Category -Y Tickets -Height 340px -Data @(
                        foreach ($c in 'Password reset', 'Hardware', 'Network', 'Access request', 'Software install', 'E-mail', 'VPN', 'Printer') { [pscustomobject]@{ Category = $c; Tickets = $rng.Next(20, 300) } }
                    )
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -Content {
                New-UDCard -Title 'Dependencies: services, VMs, ESXi hosts, datastores (drag, zoom; hover shows what an outage affects)' -Content {
                    $links = [System.Collections.Generic.List[object]]::new()
                    $services = 'CRM', 'ERP', 'Webshop', 'Mail', 'File', 'Monitoring', 'Billing'
                    foreach ($svc in $services) {
                        foreach ($n in 1..$rng.Next(1, 4)) {
                            $vm = 'vm-{0}-{1:00}' -f $svc.ToLower(), $n
                            $links.Add([pscustomobject]@{ From = $svc; To = $vm; FromKind = 'Service'; ToKind = 'VM' })
                            $links.Add([pscustomobject]@{ From = $vm; To = 'esx-{0:00}' -f $rng.Next(1, 7); FromKind = 'VM'; ToKind = 'ESXi host' })
                        }
                    }
                    foreach ($h in 1..6) { $links.Add([pscustomobject]@{ From = 'esx-{0:00}' -f $h; To = @('DS-Gold', 'DS-Silver', 'DS-Bronze')[$h % 3]; FromKind = 'ESXi host'; ToKind = 'Datastore' }) }
                    New-UDEChart -Data $links -Type graph -Source From -Target To -GroupBy FromKind -TargetGroup ToKind -Height 520px `
                        -OnClick { if ($EventData.name) { Show-UDToast -Message ('Selected {0}' -f $EventData.name) } }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Half donut via -Options: licence usage' -Content {
                    New-UDEChart -Type donut -X State -Y Licences -Height 340px -Data @(
                        [pscustomobject]@{ State = 'Assigned'; Licences = 1840 }
                        [pscustomobject]@{ State = 'Free'; Licences = 260 }
                    ) -Options @{ series = @(@{ startAngle = 180; endAngle = 360; center = @('50%', '70%'); radius = @('55%', '95%') }) }
                }
            }
        }
    }
    #endregion

    #region Calendar
    New-UDPage -Name 'Calendar' -Url '/calendar' -Content {
        $rng = [System.Random]::new(11)
        $today = (Get-Date).Date
        New-UDTypography -Variant h5 -Text 'Calendar heatmaps: one cell per day'
        New-UDGrid -Container -Content {
            New-UDGrid -Item -ExtraSmallSize 12 -Content {
                New-UDCard -Title 'Changes per day, two years (one calendar per year)' -Content {
                    $changes = foreach ($d in -729..0) {
                        $day = $today.AddDays($d)
                        $base = if ($day.DayOfWeek -in 'Saturday', 'Sunday') { 1 } else { 9 }
                        [pscustomobject]@{ Date = $day.ToString('yyyy-MM-dd'); Changes = [math]::Max(0, $base + $rng.Next(-3, 12)) }
                    }
                    New-UDEChart -Data $changes -Type calendar -X Date -Y Changes -Height 420px
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Backup success rate per day (red below 95 %, orange below 99 %)' -Content {
                    $rate = foreach ($d in -179..0) { [pscustomobject]@{ Date = $today.AddDays($d).ToString('yyyy-MM-dd'); Success = [math]::Round(100 - [math]::Pow($rng.NextDouble(), 6) * 9, 2) } }
                    New-UDEChart -Data $rate -Type calendar -X Date -Y Success -Format 'percent100:2' -Height 260px -Options @{
                        visualMap = @{ type = 'piecewise'; pieces = @(@{ lt = 95; color = '#e53935'; label = '< 95 %' }, @{ gte = 95; lt = 99; color = '#fb8c00'; label = '95 - 99 %' }, @{ gte = 99; color = '#43a047'; label = '>= 99 %' }) }
                    }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'On-call: alerts outside business hours per day' -Content {
                    $alerts = foreach ($d in -179..0) { [pscustomobject]@{ Date = $today.AddDays($d).ToString('yyyy-MM-dd'); Alerts = [math]::Max(0, [int]([math]::Pow($rng.NextDouble(), 3) * 14)) } }
                    New-UDEChart -Data $alerts -Type calendar -X Date -Y Alerts -Height 260px -Options @{ visualMap = @{ inRange = @{ color = @('#e8f5e9', '#ffb74d', '#c62828') } } } `
                        -OnClick { Show-UDToast -Message ('{0}: {1} alerts' -f $EventData.value[0], $EventData.value[1]) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -Content {
                New-UDCard -Title 'Change freeze, maintenance windows and patch days' -Content {
                    $plan = foreach ($d in 0..119) {
                        $day = $today.AddDays($d)
                        $kind = if ($day.Month -eq 12 -and $day.Day -ge 15) { 3 } elseif ($day.DayOfWeek -eq 'Tuesday' -and $day.Day -ge 8 -and $day.Day -le 14) { 2 } elseif ($day.DayOfWeek -eq 'Saturday') { 1 } else { 0 }
                        [pscustomobject]@{ Date = $day.ToString('yyyy-MM-dd'); Kind = $kind }
                    }
                    New-UDEChart -Data $plan -Type calendar -X Date -Y Kind -Height 240px -Options @{
                        visualMap = @{ type = 'piecewise'; pieces = @(@{ value = 0; color = 'rgba(128,128,128,0.15)'; label = 'normal' }, @{ value = 1; color = '#42a5f5'; label = 'maintenance window' }, @{ value = 2; color = '#ab47bc'; label = 'patch day' }, @{ value = 3; color = '#e53935'; label = 'change freeze' }) }
                        tooltip   = @{ show = $false }
                    }
                }
            }
        }
    }
    #endregion

    #region Intraday
    New-UDPage -Name 'Intraday & small multiples' -Url '/intraday' -Content {
        $rng = [System.Random]::new(5)
        $from = (Get-Date).Date.AddDays(-13)
        $to = (Get-Date).Date.AddDays(1).AddSeconds(-1)
        New-UDTypography -Variant h5 -Text 'Axis breaks, small multiples and sparklines'
        New-UDGrid -Container -Content {
            New-UDGrid -Item -ExtraSmallSize 12 -Content {
                New-UDCard -Title 'Portal response time, business hours only (nights and weekends cut out)' -Content {
                    $samples = for ($t = $from; $t -lt $to; $t = $t.AddMinutes(10)) {
                        if ($t.DayOfWeek -in 'Saturday', 'Sunday' -or $t.Hour -lt 7 -or $t.Hour -ge 19) { continue }
                        $load = [math]::Sin(($t.Hour - 7) / 12 * [math]::PI)
                        [pscustomobject]@{ Time = $t; 'Response ms' = [math]::Round(180 + 220 * $load + $rng.Next(0, 90) + $(if ($rng.NextDouble() -lt 0.01) { 900 } else { 0 })) }
                    }
                    $breaks = New-UDEChartTimeBreak -From $from -To $to -DayStart '07:00' -DayEnd '19:00' -Weekends
                    New-UDEChart -Data $samples -Type line -X Time -Y 'Response ms' -Breaks $breaks -Zoom Both -Height 360px -MarkLine @{ value = 600; name = 'SLA 600 ms'; color = '#e53935' } `
                        -Options @{ series = @(@{ lineStyle = @{ width = 1 } }) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Backups per hour, only the backup window 22:00 - 06:00' -Content {
                    $start = (Get-Date).Date.AddDays(-6)
                    $jobs = for ($t = $start; $t -lt (Get-Date).Date.AddDays(1); $t = $t.AddHours(1)) {
                        if ($t.Hour -ge 6 -and $t.Hour -lt 22) { continue }
                        [pscustomobject]@{ Hour = $t; Finished = $rng.Next(40, 260); Failed = $rng.Next(0, 6) }
                    }
                    $daytime = for ($d = $start; $d -lt (Get-Date).Date.AddDays(1); $d = $d.AddDays(1)) { @{ start = $d.AddHours(6).ToString('o'); end = $d.AddHours(22).ToString('o'); gap = '2%' } }
                    New-UDEChart -Data $jobs -Type bar -X Hour -Y Finished, Failed -Stacked -Breaks $daytime -Height 340px -Palette '#43a047', '#e53935'
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Storage per customer: a break in the value axis keeps the small ones readable' -Content {
                    $customers = @(('Contoso', 48), ('Fabrikam', 62), ('Northwind', 35), ('Tailspin', 1840), ('Adatum', 71), ('Litware', 29)) | ForEach-Object { [pscustomobject]@{ Customer = $_[0]; TB = $_[1] } }
                    New-UDEChart -Data $customers -Type bar -X Customer -Y TB -DataLabels -YBreaks @{ start = 120; end = 1750; gap = '8%' } -Height 340px
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -Content {
                New-UDCard -Title 'Tickets per hour, one small chart per weekday (same scale)' -Content {
                    $days = 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
                    $perHour = foreach ($d in $days) {
                        $weekend = $d -in 'Saturday', 'Sunday'
                        foreach ($h in 0..23) {
                            $curve = [math]::Max(0, [math]::Sin(($h - 6) / 13 * [math]::PI))
                            [pscustomobject]@{ Weekday = $d; Hour = '{0:00}' -f $h; Tickets = [math]::Round($curve * $(if ($weekend) { 6 } else { 28 }) + $rng.Next(0, 4)); Calls = [math]::Round($curve * $(if ($weekend) { 3 } else { 14 }) + $rng.Next(0, 3)) }
                        }
                    }
                    New-UDEChart -Data $perHour -Type area -X Hour -Y Tickets, Calls -Facet Weekday -FacetColumns 4 -Smooth -Height 460px
                }
            }
            foreach ($kpi in @(@('CPU, last 24 h', '%', 'percent100'), @('Open tickets', '', 'integer'), @('Backup volume', 'TB', 'number:1'), @('Portal latency', 'ms', 'integer'))) {
                $points = foreach ($i in 0..47) { [pscustomobject]@{ T = $i; V = [math]::Round(40 + 25 * [math]::Sin($i / 6 + $kpi[0].Length) + $rng.Next(0, 12), 1) } }
                New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 6 -MediumSize 3 -Content {
                    New-UDCard -Content {
                        New-UDTypography -Variant caption -Text $kpi[0]
                        New-UDTypography -Variant h4 -Text ('{0} {1}' -f $points[-1].V, $kpi[1])
                        New-UDEChart -Data $points -Type area -X T -Y V -Sparkline -Format $kpi[2] -Height 60px
                    }
                }
            }
        }
    }
    #endregion

    #region Public data
    New-UDPage -Name 'Public data' -Url '/public' -Content {
        function Invoke-ShowcaseApi {
            # public APIs are called once per hour per URL; every visitor shares the cached answer
            param([Parameter(Mandatory)][string]$Uri)
            $key = 'EChartsApi:' + $Uri
            $hit = if ($Cache:EChartsApi) { $Cache:EChartsApi[$key] }
            if ($hit -and $hit.Time -gt (Get-Date).AddHours(-1)) { return $hit.Data }
            $data = Invoke-RestMethod -Uri $Uri -TimeoutSec 45
            if (-not $Cache:EChartsApi) { $Cache:EChartsApi = @{} }
            $Cache:EChartsApi[$key] = @{ Time = Get-Date; Data = $data }
            $data
        }
        New-UDTypography -Variant h5 -Text 'Public APIs (fetched by the PSU server; each card shows an error if the API is unreachable)'
        New-UDGrid -Container -Content {
            New-UDGrid -Item -ExtraSmallSize 12 -Content {
                New-UDCard -Title 'Weather Berlin, next 7 days (Open-Meteo): temperature and rain on two axes' -Content {
                    try {
                        $w = Invoke-ShowcaseApi 'https://api.open-meteo.com/v1/forecast?latitude=52.52&longitude=13.41&hourly=temperature_2m,precipitation&timezone=Europe%2FBerlin&forecast_days=7'
                        $hours = for ($i = 0; $i -lt $w.hourly.time.Count; $i++) {
                            [pscustomobject]@{ Time = $w.hourly.time[$i]; Temperature = $w.hourly.temperature_2m[$i]; Rain = $w.hourly.precipitation[$i] }
                        }
                        New-UDEChart -Data $hours -Type line -X Time -Y Temperature, Rain -SecondaryY Rain -YTitle 'deg C' -SecondaryTitle 'mm' -Zoom Both -Height 340px `
                            -Options @{ series = @(@{ smooth = $true }, @{ type = 'bar'; itemStyle = @{ opacity = 0.6 } }) }
                    }
                    catch { New-UDAlert -Severity warning -Text ('Open-Meteo: {0}' -f $_.Exception.Message) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'EUR exchange rates, last 12 months (ECB via Frankfurter)' -Content {
                    try {
                        $from = (Get-Date).AddYears(-1).ToString('yyyy-MM-dd')
                        $fx = Invoke-ShowcaseApi "https://api.frankfurter.dev/v1/$from..?symbols=USD,GBP,CHF"
                        $rates = foreach ($p in $fx.rates.PSObject.Properties) {
                            [pscustomobject]@{ Date = $p.Name; USD = $p.Value.USD; GBP = $p.Value.GBP; CHF = $p.Value.CHF }
                        }
                        New-UDEChart -Data $rates -Type line -X Date -Y USD, GBP, CHF -Format 'number:4' -Zoom Both -Height 340px -Options @{ yAxis = @{ scale = $true } }
                    }
                    catch { New-UDAlert -Severity warning -Text ('Frankfurter: {0}' -f $_.Exception.Message) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Earthquakes of the last 7 days (USGS): magnitude vs depth' -Content {
                    try {
                        $q = Invoke-ShowcaseApi 'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_week.geojson'
                        $quakes = $q.features | ForEach-Object {
                            [pscustomobject]@{ Magnitude = $_.properties.mag; Depth = $_.geometry.coordinates[2]; Type = if ($_.properties.tsunami) { 'Tsunami alert' } else { 'Earthquake' }; Place = $_.properties.place }
                        }
                        New-UDEChart -Data $quakes -Type scatter -X Magnitude -Y Depth -GroupBy Type -XAxisType Value -YTitle 'km' -Height 340px `
                            -OnClick { Show-UDToast -Message ('M{0} at {1} km: {2}' -f $EventData.row.magnitude, $EventData.row.depth, $EventData.row.place) } `
                            -Options @{ yAxis = @{ inverse = $true } }
                    }
                    catch { New-UDAlert -Severity warning -Text ('USGS: {0}' -f $_.Exception.Message) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Population, 15 largest countries (World Bank)' -Content {
                    try {
                        $wb = Invoke-ShowcaseApi 'https://api.worldbank.org/v2/country/all/indicator/SP.POP.TOTL?date=2023&format=json&per_page=400'
                        # the list mixes countries and aggregates; countries have a 3-letter ISO code and a region
                        $countries = Invoke-ShowcaseApi 'https://api.worldbank.org/v2/country?format=json&per_page=400'
                        $real = @($countries[1] | Where-Object { $_.region.id -ne 'NA' } | ForEach-Object id)
                        $top = $wb[1] | Where-Object { $_.countryiso3code -in $real -and $_.value } | Sort-Object value -Descending | Select-Object -First 15 @{ n = 'Country'; e = { $_.country.value } }, @{ n = 'Population'; e = { $_.value } }
                        New-UDEChart -Data $top -Type bar -Horizontal -X Country -Y Population -Format compact -DataLabels -Height 420px
                    }
                    catch { New-UDAlert -Severity warning -Text ('World Bank: {0}' -f $_.Exception.Message) }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'An OpenAPI document: operations per tag and method (Swagger Petstore)' -Content {
                    try {
                        $api = Invoke-ShowcaseApi 'https://petstore3.swagger.io/api/v3/openapi.json'
                        $ops = foreach ($path in $api.paths.PSObject.Properties) {
                            foreach ($op in $path.Value.PSObject.Properties) {
                                [pscustomobject]@{ Tag = @($op.Value.tags)[0]; Method = $op.Name.ToUpper(); Path = $path.Name }
                            }
                        }
                        $byTag = $ops | Group-Object Tag, Method | ForEach-Object { [pscustomobject]@{ Tag = $_.Group[0].Tag; Method = $_.Group[0].Method; Operations = $_.Count } }
                        New-UDEChart -Data $byTag -Type bar -X Tag -Y Operations -GroupBy Method -Stacked -DataLabels -Height 420px
                    }
                    catch { New-UDAlert -Severity warning -Text ('OpenAPI: {0}' -f $_.Exception.Message) }
                }
            }
        }
    }
    #endregion

    #region Technical
    New-UDPage -Name 'Technical' -Url '/technical' -Content {
        New-UDTypography -Variant h5 -Text 'Data from PowerShell on the PSU server'
        New-UDGrid -Container -Content {
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Processes by memory (Get-Process)' -Content {
                    $procs = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 12 @{ n = 'Process'; e = { '{0} ({1})' -f $_.ProcessName, $_.Id } }, @{ n = 'Memory'; e = { $_.WorkingSet64 } }
                    New-UDEChart -Data $procs -Type bar -Horizontal -X Process -Y Memory -Format bytes -DataLabels -Height 380px
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Size of the PSU program folder (treemap from Get-ChildItem)' -Content {
                    $root = Split-Path ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
                    $files = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                        $rel = [System.IO.Path]::GetRelativePath($root, $_.DirectoryName).Replace('\', '/')
                        [pscustomobject]@{ Folder = if ($rel -eq '.') { '(root)' } else { ($rel -split '/' | Select-Object -First 2) -join '/' }; Bytes = $_.Length }
                    }
                    $sizes = $files | Group-Object Folder | ForEach-Object { [pscustomobject]@{ Folder = $_.Name; Bytes = ($_.Group | Measure-Object Bytes -Sum).Sum } }
                    New-UDEChart -Data $sizes -Type treemap -Path Folder -Y Bytes -Format bytes -Height 380px
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'A System.Data.DataTable with DBNull (as SqlClient returns it)' -Content {
                    $table = [System.Data.DataTable]::new()
                    [void]$table.Columns.Add('Server', [string])
                    [void]$table.Columns.Add('CpuPercent', [double])
                    [void]$table.Columns.Add('MemoryPercent', [double])
                    foreach ($r in @(('db01', 71.5, 82.1), ('db02', 34.2, [DBNull]::Value), ('app01', 55.0, 61.3), ('app02', [DBNull]::Value, 44.8), ('web01', 18.9, 37.0))) {
                        [void]$table.Rows.Add($r[0], $r[1], $r[2])
                    }
                    New-UDEChart -Data $table -Type bar -X Server -Y CpuPercent, MemoryPercent -Format percent100 -DataLabels -Height 320px `
                        -ExportColumns @{ field = 'Server'; title = 'Server' }, @{ field = 'CpuPercent'; title = 'CPU %'; type = 'number' }, @{ field = 'MemoryPercent'; title = 'Memory %'; type = 'number' }
                }
            }
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Linked charts: zoom or hover one, the other follows' -Content {
                    $t0 = (Get-Date).Date
                    $series = foreach ($i in 0..287) { [pscustomobject]@{ Time = $t0.AddMinutes(5 * $i); Requests = [math]::Round(400 + 300 * [math]::Sin($i / 30) + ($i * 13) % 50); Errors = [math]::Round(5 + 4 * [math]::Cos($i / 17) + ($i * 7) % 3) } }
                    New-UDEChart -Data $series -Type area -X Time -Y Requests -Group 'linked' -Height 180px -Legend None
                    New-UDEChart -Data $series -Type bar -X Time -Y Errors -Group 'linked' -Height 180px -Legend None -Palette '#ee6666'
                }
            }
        }
    }
    #endregion

    #region Live
    New-UDPage -Name 'Live' -Url '/live' -Content {
        New-UDTypography -Variant h5 -Text 'Live data: a new point every 2 seconds (Set-UDEChartData), zoom and hidden series stay'
        $Session:LivePoints = [System.Collections.Generic.List[object]]::new()
        New-UDEChart -Id 'live-chart' -Data @() -Type line -X Time -Y Load, Queue -Smooth -Height 360px -Zoom Slider
        New-UDElement -Tag 'div' -AutoRefresh -RefreshInterval 2 -Endpoint {
            $now = Get-Date
            $Session:LivePoints.Add([pscustomobject]@{ Time = $now; Load = [math]::Round(50 + 30 * [math]::Sin($now.Second / 9) + (Get-Random -Maximum 10), 1); Queue = Get-Random -Minimum 0 -Maximum 25 })
            while ($Session:LivePoints.Count -gt 300) { $Session:LivePoints.RemoveAt(0) }
            Set-UDEChartData -Id 'live-chart' -Data $Session:LivePoints
        }
    }
    #endregion

    #region Benchmark
    New-UDPage -Name 'Benchmark' -Url '/benchmark' -Content {
        New-UDTypography -Variant h5 -Text 'Large data: points generated on the server, sampled (LTTB) in the browser'
        New-UDSelect -Id 'bench-size' -Label 'Points' -DefaultValue '10000' -Option {
            New-UDSelectOption -Name '10.000' -Value '10000'
            New-UDSelectOption -Name '100.000' -Value '100000'
            New-UDSelectOption -Name '300.000' -Value '300000'
        } -OnChange { $Session:BenchSize = [int]$EventData; Sync-UDElement -Id 'bench' }
        New-UDDynamic -Id 'bench' -Content {
            $n = if ($Session:BenchSize) { $Session:BenchSize } else { 10000 }
            $watch = [System.Diagnostics.Stopwatch]::StartNew()
            $t0 = [datetime]'2026-01-01'
            $points = [System.Collections.Generic.List[object]]::new($n)
            $v = 100.0
            $rnd = [System.Random]::new(1)
            for ($i = 0; $i -lt $n; $i++) {
                $v += ($rnd.NextDouble() - 0.5) * 2
                $points.Add([pscustomobject]@{ Time = $t0.AddSeconds(30 * $i); Value = [math]::Round($v, 2) })
            }
            New-UDTypography -Variant body2 -Text ('{0:N0} points generated in {1:N0} ms on the server' -f $n, $watch.ElapsedMilliseconds)
            New-UDEChart -Data $points -Type line -X Time -Y Value -Zoom Both -Height 420px -NoExport
        }
    }
    #endregion
)
