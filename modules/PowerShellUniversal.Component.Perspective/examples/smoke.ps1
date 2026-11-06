<#
    Smoke test app for PowerShellUniversal.Component.Perspective: a ticket list as a datagrid, the same
    rows as a pivot (team x priority) and as a chart, generated with a fixed seed.
#>
$rng = [System.Random]::new(42)
$teams = 'Service Desk', 'Network', 'Server', 'Applications'
$tickets = foreach ($i in 1..5000) {
    [pscustomobject]@{
        Id        = 10000 + $i
        Created   = (Get-Date).Date.AddDays(-$rng.Next(0, 90)).AddHours($rng.Next(7, 19))
        Team      = $teams[$rng.Next(0, 4)]
        Priority  = 'P{0}' -f (1 + [int][math]::Floor([math]::Pow($rng.NextDouble(), 0.6) * 4))
        Customer  = 'Customer {0}' -f [char](65 + $rng.Next(0, 6))
        Status    = @('Open', 'Waiting', 'Closed', 'Closed', 'Closed')[$rng.Next(0, 5)]
        LeadHours = [math]::Round([math]::Exp(2.6 + 0.9 * ($rng.NextDouble() - 0.5)), 1)
    }
}

New-UDApp -Title 'Perspective for PowerShell Universal' -Content {
    New-UDTypography -Variant h5 -Text 'Perspective: datagrid, pivot and chart in one (5000 tickets)'
    New-UDCard -Title 'Datagrid: sort, filter and rearrange in the panel (click a cell)' -Content {
        New-UDPerspective -Data $tickets -Sort 'Created desc' -Height 420px -OnClick {
            Show-UDToast -Message ('Ticket {0}, {1}' -f $EventData.row.Id, $EventData.row.Team)
        }
    }
    New-UDCard -Title 'Pivot: tickets per team and priority, average lead time' -Content {
        New-UDPerspective -Data $tickets -GroupBy Team -SplitBy Priority -Columns Id, LeadHours -Aggregates @{ Id = 'count'; LeadHours = 'avg' } -Height 360px
    }
    New-UDCard -Title 'Chart: open tickets per customer and team (Y Bar)' -Content {
        New-UDPerspective -Data $tickets -Plugin 'Y Bar' -GroupBy Customer -SplitBy Team -Columns Id -Aggregates @{ Id = 'count' } -Filter "Status == Open" -Height 380px
    }
}
