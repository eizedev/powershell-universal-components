<#
    Showcase app of PowerShellUniversal.Component.Perspective: use cases for readers who arrange their
    own views - pivots, filters, charts - with "Edit view" and the Table/Chart switch above every viewer.
    All data is generated with a fixed seed, so every run shows the same numbers.
#>

#region Generated data
$rng = [System.Random]::new(7)
$teams = 'Service Desk', 'Network', 'Server', 'Applications'
$customers = 'Customer A', 'Customer B', 'Customer C', 'Customer D', 'Customer E', 'Customer F'
$today = (Get-Date).Date

$tickets = foreach ($i in 1..6000) {
    $created = $today.AddDays(-$rng.Next(0, 120)).AddHours($rng.Next(7, 19))
    [pscustomobject]@{
        Id        = 20000 + $i
        Created   = $created
        Month     = $created.ToString('yyyy-MM')
        Team      = $teams[$rng.Next(0, 4)]
        Priority  = 'P{0}' -f (1 + [int][math]::Floor([math]::Pow($rng.NextDouble(), 0.6) * 4))
        Customer  = $customers[$rng.Next(0, 6)]
        Status    = @('Open', 'Waiting', 'Closed', 'Closed', 'Closed', 'Closed')[$rng.Next(0, 6)]
        LeadHours = [math]::Round([math]::Exp(2.6 + 0.9 * ($rng.NextDouble() - 0.5)), 1)
        WithinSla = $rng.NextDouble() -gt 0.08
    }
}

# assets as a data platform sees them: one row per asset and source system, Found = the source knows it
$sources = 'Virtualisation', 'Backup', 'EDR', 'Monitoring', 'CMDB', 'Patching'
$classes = 'Windows server', 'Linux server', 'Client', 'Network device', 'Appliance'
$assets = foreach ($n in 1..900) {
    $class = $classes[[math]::Min(4, [int][math]::Floor([math]::Pow($rng.NextDouble(), 1.4) * 5))]
    $customer = $customers[$rng.Next(0, 6)]
    foreach ($source in $sources) {
        # clients have no backup, network devices no EDR: those gaps are expected, the others are not
        $expected = -not (($class -eq 'Client' -and $source -eq 'Backup') -or ($class -in 'Network device', 'Appliance' -and $source -in 'EDR', 'Patching'))
        [pscustomobject]@{
            Asset    = 'asset-{0:0000}' -f $n
            Class    = $class
            Customer = $customer
            Source   = $source
            Expected = $expected
            Found    = $expected -and $rng.NextDouble() -gt 0.12
        }
    }
}

# monthly costs per customer and service
$services = 'Managed servers', 'Backup', 'Licences', 'Projects'
$costs = foreach ($m in 11..0) {
    $month = $today.AddDays(1 - $today.Day).AddMonths(-$m)
    foreach ($customer in $customers) {
        foreach ($service in $services) {
            [pscustomobject]@{
                Month    = $month.ToString('yyyy-MM-dd')
                Customer = $customer
                Service  = $service
                Cost     = [math]::Round((800 + 300 * $customers.IndexOf($customer)) * (1 + 0.04 * (11 - $m)) * (0.6 + $services.IndexOf($service) * 0.35) + $rng.Next(-120, 120), 2)
            }
        }
    }
}
#endregion

New-UDApp -Title 'Perspective for PowerShell Universal' -Pages @(

    New-UDPage -Name 'How it works' -Url '/how' -Content {
        New-UDTypography -Variant h5 -Text 'Arrange the data yourself: three steps'
        New-UDTypography -Variant body1 -Text '1. "Edit view" opens the editor next to the table (and closes it again). 2. At the top of the editor, pick what to show: Datagrid (the table) or a chart such as Y Bar, Y Line, Treemap or Heatmap; "Table" and "Chart" switch between the table and the last chart you picked. 3. Drag columns into Group By (rows) and Split By (columns), pick how values are combined next to each column (count, sum, avg), add filters under Where. Reload the page to start again.'
        New-UDCard -Title 'Try it: tickets per team - open "Edit view", drag Priority into Split By' -Content {
            New-UDPerspective -Data $tickets -GroupBy Team -Columns Id, LeadHours -Aggregates @{ Id = 'count'; LeadHours = 'avg' } -Height 420px
        }
    }

    New-UDPage -Name 'Tickets' -Url '/tickets' -Content {
        New-UDTypography -Variant h5 -Text 'Tickets: who has how many, how fast'
        New-UDCard -Title 'Pivot: tickets per team and priority, average lead time (hours)' -Content {
            New-UDPerspective -Data $tickets -GroupBy Team -SplitBy Priority -Columns Id, LeadHours -Aggregates @{ Id = 'count'; LeadHours = 'avg' } -Height 380px
        }
        New-UDCard -Title 'Open and waiting tickets per customer as a chart (switch to "Table" for the numbers)' -Content {
            New-UDPerspective -Data $tickets -Plugin 'Y Bar' -GroupBy Customer -SplitBy Status -Columns Id -Aggregates @{ Id = 'count' } -Filter 'Status in Open, Waiting' -Height 380px
        }
        New-UDCard -Title 'All tickets: sort, filter, click a row' -Content {
            New-UDPerspective -Data $tickets -Columns Id, Created, Team, Priority, Customer, Status, LeadHours -Sort 'Created desc' -Height 420px -OnClick {
                Show-UDToast -Message ('Ticket {0}: {1}, {2}' -f $EventData.row.Id, $EventData.row.Team, $EventData.row.Status)
            }
        }
    }

    New-UDPage -Name 'Data platform' -Url '/assets' -Content {
        New-UDTypography -Variant h5 -Text 'Assets across source systems: where are the gaps?'
        New-UDCard -Title 'Gaps: assets a source should know but does not, per class and source' -Content {
            New-UDPerspective -Data $assets -GroupBy Class -SplitBy Source -Columns Asset -Aggregates @{ Asset = 'distinct count' } -Filter 'Expected == true', 'Found == false' -Height 340px
        }
        New-UDCard -Title 'The same gaps per customer as a heatmap' -Content {
            New-UDPerspective -Data $assets -Plugin Heatmap -GroupBy Customer -SplitBy Source -Columns Asset -Aggregates @{ Asset = 'distinct count' } -Filter 'Expected == true', 'Found == false' -ChartPlugin Heatmap -Height 360px
        }
        New-UDCard -Title 'Every asset and source (filter by Asset to see one asset everywhere)' -Content {
            New-UDPerspective -Data $assets -Sort 'Asset' -Height 400px
        }
    }

    New-UDPage -Name 'Costs' -Url '/costs' -Content {
        New-UDTypography -Variant h5 -Text 'Costs: twelve months per customer and service'
        New-UDCard -Title 'Monthly cost per customer (line chart; "Table" shows the pivot behind it)' -Content {
            New-UDPerspective -Data $costs -Plugin 'Y Line' -GroupBy Month -SplitBy Customer -Columns Cost -Aggregates @{ Cost = 'sum' } -ChartPlugin 'Y Line' -Height 380px
        }
        New-UDCard -Title 'Share per service and customer (treemap)' -Content {
            New-UDPerspective -Data $costs -Plugin Treemap -GroupBy Service, Customer -Columns Cost -Aggregates @{ Cost = 'sum' } -ChartPlugin Treemap -Height 380px
        }
        New-UDCard -Title 'Pivot: customer x service, sum of the year' -Content {
            New-UDPerspective -Data $costs -GroupBy Customer -SplitBy Service -Columns Cost -Aggregates @{ Cost = 'sum' } -Height 320px
        }
    }

    New-UDPage -Name 'Other language' -Url '/labels' -Content {
        New-UDTypography -Variant h5 -Text 'The toolbar in another language (-Labels)'
        New-UDCard -Title 'Tickets pro Team und Stufe' -Content {
            New-UDPerspective -Data $tickets -GroupBy Team -SplitBy Priority -Columns Id -Aggregates @{ Id = 'count' } -Labels @{ EditView = 'Ansicht bearbeiten'; Table = 'Tabelle'; Chart = 'Diagramm' } -Height 360px
        }
    }
)
