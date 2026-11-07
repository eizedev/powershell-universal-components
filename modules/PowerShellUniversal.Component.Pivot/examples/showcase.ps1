<#
    Showcase app of PowerShellUniversal.Component.Pivot: a ticket report from a System.Data.DataTable
    (what a SQL query returns: dates, numbers, text and DBNull), with built-in templates, templates each
    user saves and deletes, a language switch, events and the report in common page layouts.
    All data is generated with a fixed seed, so every run shows the same numbers.

    Templates the users save are JSON files, one per user, in a folder next to the PSU repository
    ($TemplateSettings below; change it to where your app keeps data, or use a database table). The views
    come from the browser: ConvertFrom-UDPivotView checks every one before it is stored.
#>

#region Generated data: 5000 tickets as a DataTable, like Invoke-Sqlcmd returns them
$rng = [System.Random]::new(11)
$teams = 'Service Desk', 'Network', 'Server', 'Applications', 'Security'
$customers = 'Contoso', 'Fabrikam', 'Northwind', 'Tailspin', 'Wingtip', 'Litware'
$categories = 'Incident', 'Request', 'Change', 'Problem'
$agents = 'Alex', 'Kim', 'Sam', 'Robin', 'Jo', 'Mika', 'Chris', 'Pat'
# a fixed end date keeps the numbers the same on every run
$end = [datetime]'2026-10-31'

$tickets = [System.Data.DataTable]::new('Tickets')
foreach ($column in @(
        @('Ticket', [int]), @('Created', [datetime]), @('Closed', [datetime]), @('Team', [string]), @('Priority', [string]),
        @('Customer', [string]), @('Category', [string]), @('Status', [string]), @('Agent', [string]),
        @('Lead hours', [double]), @('Cost', [decimal]), @('Reopened', [bool]))) {
    [void]$tickets.Columns.Add($column[0], $column[1])
}
foreach ($i in 1..5000) {
    $created = $end.AddDays(-$rng.Next(0, 540)).AddMinutes($rng.Next(7 * 60, 19 * 60))
    $priority = 'P{0}' -f (1 + [int][math]::Floor([math]::Pow($rng.NextDouble(), 0.6) * 4))
    $status = @('Open', 'Waiting', 'Closed', 'Closed', 'Closed', 'Closed', 'Closed')[$rng.Next(0, 7)]
    $lead = [math]::Round([math]::Exp(2.4 + 1.1 * ($rng.NextDouble() - 0.5)) * (1 + 0.5 * ($priority -eq 'P4')), 1)
    $row = $tickets.NewRow()
    $row['Ticket'] = 40000 + $i
    $row['Created'] = $created
    # open tickets have no close date and no lead time yet: DBNull, as from SQL
    $row['Closed'] = if ($status -eq 'Closed') { $created.AddMinutes([math]::Round($lead * 60)) } else { [DBNull]::Value }
    $row['Team'] = $teams[$rng.Next(0, $teams.Count)]
    $row['Priority'] = $priority
    $row['Customer'] = $customers[$rng.Next(0, $customers.Count)]
    $row['Category'] = $categories[[math]::Min(3, [int][math]::Floor([math]::Pow($rng.NextDouble(), 1.5) * 4))]
    $row['Status'] = $status
    # unassigned tickets have no agent
    $row['Agent'] = if ($rng.NextDouble() -lt 0.06) { [DBNull]::Value } else { $agents[$rng.Next(0, $agents.Count)] }
    $row['Lead hours'] = if ($status -eq 'Closed') { $lead } else { [DBNull]::Value }
    $row['Cost'] = [decimal][math]::Round(35 + $lead * (18 + $rng.Next(0, 25)), 2)
    $row['Reopened'] = $rng.NextDouble() -lt 0.07
    $tickets.Rows.Add($row)
}
#endregion

#region Views: the start view and the built-in templates (plain data, the same JSON a saved template has)
$startView = @{
    rows   = @('Team')
    cols   = @('Priority')
    values = @(@{ field = 'Ticket'; agg = 'count' })
}
$builtInTemplates = @(
    @{ Name = 'Tickets per team and priority'; View = $startView }
    @{ Name = 'Tickets per month and category'; View = @{
            rows   = @('Created (Month)'); cols = @('Category')
            derived = @(@{ name = 'Created (Month)'; field = 'Created'; by = 'yearMonth' })
            values = @(@{ field = 'Ticket'; agg = 'count' })
            display = 'chart'; chart = @{ type = 'line' }
        }
    }
    @{ Name = 'Lead time per customer'; View = @{
            rows   = @('Customer'); cols = @('Priority')
            values = @(@{ field = 'Lead hours'; agg = 'average'; format = 'number:1' })
            filters = @(@{ field = 'Status'; type = 'include'; items = @('Closed') })
        }
    }
    @{ Name = 'Cost per team (share of the total)'; View = @{
            rows   = @('Team'); values = @(@{ field = 'Cost'; agg = 'sum'; format = 'currency:EUR'; showAs = @{ type = 'percentOfGrandTotal' } })
            display = 'chart'; chart = @{ type = 'pie' }
        }
    }
)
$fieldDefaults = @{
    'Lead hours' = @{ Agg = 'average'; Format = 'number:1' }
    Cost         = @{ Agg = 'sum'; Format = 'currency:EUR' }
    Ticket       = @{ Agg = 'count' }
}
#endregion

#region Template store: one JSON file per user
# next to the repository, not inside it (a git-synced repository would pick the files up)
$TemplateSettings = @{
    Root       = if ($Repository) { Join-Path (Split-Path -Parent $Repository) 'pivot-templates' } else { Join-Path ([System.IO.Path]::GetTempPath()) 'pivot-templates' }
    MaxPerUser = 50
    # names of the built-in templates, which no user template may take
    Reserved   = @($builtInTemplates | ForEach-Object { $_.Name })
}

# The store is a script block, not a function: PSU runs event handlers in their own runspace, which
# gets the app script's variables the handler names, but not functions defined in it. For the same
# reason every call passes the settings.
$TemplateStore = {
    param(
        [ValidateSet('List', 'Save', 'Delete')][string]$Action,
        [hashtable]$Settings,
        [string]$Name,
        [object]$View
    )
    $ErrorActionPreference = 'Stop'
    # event handlers run in a runspace of their own, where PSU does not load the module by itself
    Import-Module PowerShellUniversal.Component.Pivot
    # $User: the signed-in user of the page or event that runs this; apps without authentication have none
    $userName = if ($User) { [string]$User } else { 'anonymous' }
    # a file name from the user name that cannot leave the folder
    $hash = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($userName.ToLowerInvariant()))
    $id = [System.Convert]::ToHexString($hash).Substring(0, 24).ToLowerInvariant()
    $file = Join-Path $Settings.Root ('{0}.json' -f $id)
    $mutex = $null
    if ($Action -ne 'List') {
        # one change at a time per user: two saves at the same moment would otherwise lose one
        $mutex = [System.Threading.Mutex]::new($false, ('pivot-templates-{0}' -f $id))
        if (-not $mutex.WaitOne([timespan]::FromSeconds(10))) { throw 'The template store is busy; try again.' }
    }
    try {
        $saved = @(if (Test-Path -LiteralPath $file) { Get-Content -LiteralPath $file -Raw | ConvertFrom-Json -Depth 12 })
        switch ($Action) {
            'List' {
                # each stored view is checked again: a file can be edited by hand
                foreach ($t in $saved) {
                    try { [pscustomobject]@{ Name = $t.Name; View = (ConvertFrom-UDPivotView -InputObject $t.View); Deletable = $true } }
                    catch { Write-Warning ('Pivot template "{0}" skipped: {1}' -f $t.Name, $_.Exception.Message) }
                }
                return
            }
            'Save' {
                $Name = ([string]$Name).Trim()
                if ($Name.Length -lt 1 -or $Name.Length -gt 80) { throw 'A template name has 1 to 80 characters.' }
                if ($Name -in $Settings.Reserved) { throw ('"{0}" is a built-in template; choose another name.' -f $Name) }
                # throws for anything that is not a view; what is stored is the checked JSON, never the input
                $json = ConvertFrom-UDPivotView -InputObject $View -AsJson
                $others = @($saved | Where-Object Name -NE $Name)
                if ($others.Count -ge $Settings.MaxPerUser) { throw ('At most {0} templates per user.' -f $Settings.MaxPerUser) }
                $saved = @($others) + [pscustomobject]@{ Name = $Name; View = ($json | ConvertFrom-Json -Depth 12) }
            }
            'Delete' {
                $saved = @($saved | Where-Object Name -NE $Name)
            }
        }
        New-Item -ItemType Directory -Path $Settings.Root -Force | Out-Null
        # write a new file, then replace: a reader never sees half a file
        $temp = '{0}.{1}.tmp' -f $file, [guid]::NewGuid().ToString('n')
        Set-Content -LiteralPath $temp -Value (ConvertTo-Json -InputObject @($saved) -Depth 12 -Compress) -Encoding utf8NoBOM
        Move-Item -LiteralPath $temp -Destination $file -Force
    }
    finally {
        if ($mutex) { $mutex.ReleaseMutex(); $mutex.Dispose() }
    }
}
#endregion

New-UDApp -Title 'Pivot reports for PowerShell Universal' -Pages @(

    New-UDPage -Name 'Tickets' -Url '/tickets' -Content {
        $locale = if ($Session:PivotLocale) { $Session:PivotLocale } else { 'en-US' }
        New-UDStack -Direction row -Spacing 2 -AlignItems center -Content {
            New-UDTypography -Variant h5 -Text 'Tickets: build your own report' -Style @{ flex = '1 1 auto' }
            New-UDSelect -Id 'pivot-locale' -Label 'Language' -DefaultValue $locale -Option {
                New-UDSelectOption -Name 'English' -Value 'en-US'
                New-UDSelectOption -Name 'Deutsch' -Value 'de-DE'
            } -OnChange {
                $Session:PivotLocale = $EventData
                Sync-UDElement -Id 'tickets-report'
            }
        }
        New-UDTypography -Variant body2 -Text '5000 tickets from a DataTable. Drag fields from the list into Rows, Columns and Values, click a number to see its tickets, save your layout under Templates.' -Style @{ marginBottom = '12px' }
        # the placeholder comes with the page: the report's frame at once, and the browser loads the
        # module's code while the server still builds the 5000 rows
        New-UDDynamic -Id 'tickets-report' -LoadingComponent {
            New-UDPivotReportPlaceholder -Locale $(if ($Session:PivotLocale) { $Session:PivotLocale } else { 'en-US' })
        } -Content {
            $locale = if ($Session:PivotLocale) { $Session:PivotLocale } else { 'en-US' }
            $templates = @($builtInTemplates) + @(& $TemplateStore -Action List -Settings $TemplateSettings)
            # the tab keeps its own view (also over a change of language); $Session is shared by all tabs
            # of the browser, so the last view stored there only starts a new tab (-SavedView), and never
            # replaces what another tab shows (as -View would)
            New-UDPivotReport -Id 'tickets' -Data $tickets -View $startView -SavedView $Session:PivotView -Templates $templates -FieldDefaults $fieldDefaults `
                -Locale $locale -FileName 'tickets' -OnViewChange {
                Import-Module PowerShellUniversal.Component.Pivot
                $Session:PivotView = ConvertFrom-UDPivotView -InputObject $EventData.json
            } -OnCellClick {
                $where = ($EventData.filter | ForEach-Object { '{0} = {1}' -f $_.field, $_.value }) -join ', '
                Show-UDToast -Message ('{0} tickets{1}' -f $EventData.count, $(if ($where) { " ($where)" })) -Duration 4000
            } -OnSaveTemplate {
                # @{ error = '...' } refuses with that text (a bare throw shows a general error)
                try { & $TemplateStore -Action Save -Settings $TemplateSettings -Name $EventData.name -View $EventData.view }
                catch { @{ error = $_.Exception.Message } }
            } -OnDeleteTemplate {
                try { & $TemplateStore -Action Delete -Settings $TemplateSettings -Name $EventData.name }
                catch { @{ error = $_.Exception.Message } }
            }
        }
    }

    New-UDPage -Name 'Events' -Url '/events' -Content {
        New-UDTypography -Variant h5 -Text 'What the events send to the server ($EventData)'
        New-UDTypography -Variant body2 -Text 'Change the view or click a value: the last event appears below the report.' -Style @{ marginBottom = '12px' }
        New-UDPivotReport -Id 'events-report' -Data $tickets -View $startView -Height 560px -OnViewChange {
            Set-UDElement -Id 'event-log' -Properties @{ text = 'OnViewChange: ' + $EventData.json }
        } -OnCellClick {
            $summary = [ordered]@{ filter = $EventData.filter; value = $EventData.value; text = $EventData.text; count = $EventData.count; rows = @($EventData.rows).Count }
            Set-UDElement -Id 'event-log' -Properties @{ text = 'OnCellClick: ' + ($summary | ConvertTo-Json -Depth 5 -Compress) }
        }
        New-UDTypography -Id 'event-log' -Variant body2 -Text 'No event yet.' -Style @{ marginTop = '12px'; fontFamily = 'monospace'; overflowWrap = 'anywhere' }
    }

    New-UDPage -Name 'Layouts' -Url '/layouts' -Content {
        New-UDTypography -Variant h5 -Text 'The report in page layouts'
        New-UDTabs -Tabs {
            New-UDTab -Text 'In a tab' -Content {
                New-UDPivotReport -Id 'layout-tab-1' -Data $tickets -View $builtInTemplates[1].View -Height 640px
            }
            New-UDTab -Text 'Second tab (starts hidden)' -Content {
                New-UDPivotReport -Id 'layout-tab-2' -Data $tickets -View $builtInTemplates[2].View -Height 640px
            }
        }
        # -NoAddressBar: this report's view stays out of the address (sessionStorage only)
        New-UDCard -Title 'In a card, 600 px high, view not in the address bar' -Content {
            New-UDPivotReport -Id 'layout-card' -Data $tickets -View $builtInTemplates[3].View -Height 600px -NoAddressBar
        }
        New-UDStack -Direction row -Spacing 2 -Content {
            New-UDCard -Title 'Half width' -Style @{ flex = '1 1 0'; minWidth = 0 } -Content {
                New-UDPivotReport -Id 'layout-half-1' -Data $tickets -View @{ rows = @('Category'); values = @(@{ field = 'Ticket'; agg = 'count' }) } -Height 560px
            }
            New-UDCard -Title 'Half width, German' -Style @{ flex = '1 1 0'; minWidth = 0 } -Content {
                New-UDPivotReport -Id 'layout-half-2' -Data $tickets -View @{ rows = @('Status'); values = @(@{ field = 'Cost'; agg = 'sum'; format = 'currency:EUR' }) } -Locale de-DE -Height 560px
            }
        }
    }

    # On purpose without -Id: the module tells the two reports apart by the line of the call and the columns
    New-UDPage -Name 'Without Id' -Url '/without-id' -Content {
        New-UDTypography -Variant h5 -Text 'Two reports without -Id'
        New-UDTypography -Variant body2 -Text 'Each keeps its own view when the theme switches or the page reloads.' -Style @{ marginBottom = '12px' }
        New-UDPivotReport -Data $tickets -View $startView -Height 560px
        New-UDPivotReport -Data $tickets -View @{ rows = @('Category'); values = @(@{ field = 'Ticket'; agg = 'count' }) } -Height 560px
    }
)
