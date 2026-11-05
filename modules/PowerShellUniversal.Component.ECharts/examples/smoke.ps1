# Smoke test: one chart of each family with generated data. Deploy with PSUTools Set-PSUTestApp.
New-UDApp -Title 'ECharts smoke test' -Content {
    $days = 0..59 | ForEach-Object {
        $d = (Get-Date '2026-09-01').AddDays($_)
        [pscustomobject]@{ Day = $d.Date; Team = 'OPS'; Opened = 20 + ($_ % 7) * 3; Closed = 18 + ($_ % 5) * 4 }
        [pscustomobject]@{ Day = $d.Date; Team = 'DEV'; Opened = 12 + ($_ % 6) * 2; Closed = 10 + ($_ % 4) * 3 }
    }
    New-UDGrid -Container -Content {
        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
            New-UDCard -Title 'Line, GroupBy, brush' -Content {
                New-UDEChart -Id 'smoke-line' -Data $days -Type line -X Day -Y Opened -GroupBy Team -Brush -Zoom Both -Group 'smoke' `
                    -OnSelect { Show-UDToast -Message ('Range {0} .. {1}' -f $EventData.from, $EventData.to) }
            }
        }
        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
            New-UDCard -Title 'Stacked bars, click' -Content {
                New-UDEChart -Id 'smoke-bar' -Data ($days | Where-Object Team -EQ 'OPS') -Type bar -X Day -Y Opened, Closed -Stacked -Group 'smoke' `
                    -OnClick { Show-UDToast -Message ('{0}: {1} at {2}' -f $EventData.seriesName, $EventData.value, $EventData.name) }
            }
        }
        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 4 -Content {
            New-UDCard -Title 'Donut' -Content {
                New-UDEChart -Id 'smoke-donut' -Type donut -X Status -Y Count -Data @(
                    @{ Status = 'Open'; Count = 42 }, @{ Status = 'In progress'; Count = 27 }, @{ Status = 'Waiting'; Count = 18 }, @{ Status = 'Closed'; Count = 113 }
                ) -OnClick { Show-UDToast -Message $EventData.name }
            }
        }
        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 4 -Content {
            New-UDCard -Title 'Histogram with SLA' -Content {
                $lead = 1..400 | ForEach-Object { [pscustomobject]@{ Hours = [math]::Round([math]::Abs((Get-Random -Minimum 0.0 -Maximum 1.0) * (Get-Random -Minimum 4 -Maximum 96)), 1) } }
                New-UDEChart -Id 'smoke-hist' -Data $lead -Type histogram -Y Hours -MarkLine 'median', @{ value = 48; name = 'SLA'; color = '#e53935' }
            }
        }
        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 4 -Content {
            New-UDCard -Title 'Waterfall' -Content {
                New-UDEChart -Id 'smoke-waterfall' -Type waterfall -X Step -Y Amount -Totals 'Result' -Format 'currency:EUR' -Data @(
                    @{ Step = 'Revenue'; Amount = 1200000 }, @{ Step = 'Material'; Amount = -420000 }, @{ Step = 'Staff'; Amount = -380000 },
                    @{ Step = 'Other'; Amount = -95000 }, @{ Step = 'Result'; Amount = 0 }
                )
            }
        }
    }
}
