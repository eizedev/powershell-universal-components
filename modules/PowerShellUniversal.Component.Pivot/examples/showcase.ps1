<#
    Showcase app of PowerShellUniversal.Component.Pivot: a ticket report from a System.Data.DataTable
    (what a SQL query returns: dates, numbers, text and DBNull), with built-in templates, view files
    from a folder, a template store, a language switch, events and the report in common page layouts.
    All data is generated with a fixed seed, so every run shows the same numbers.

    The app has no sign-in: the server cannot tell readers apart, so each reader's own views ("My
    views") stay in the browser, and shared views come from the store (New-UDPivotFileTemplateStore,
    view files next to the PSU repository). templates.ps1 is the same report in an app with sign-in,
    where readers keep their views on the server and admins publish shared ones.
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
# what the report knows about the fields: aggregator and format in Values, the order of Priority,
# names and descriptions (the "i" next to a field)
$fieldDefaults = @{
    'Lead hours' = @{ Agg = 'average'; Format = 'number:1'; Description = 'Hours from creation to closing; empty while the ticket is open.' }
    Cost         = @{ Agg = 'sum'; Format = 'currency:EUR'; Description = 'Cost of the work on the ticket, in euros.' }
    Ticket       = @{ Agg = 'count'; DrillFormat = 'text'; Description = 'The ticket number.' }
    Priority     = @{ Order = @('P1', 'P2', 'P3', 'P4'); Description = 'P1 is the most urgent.' }
    Reopened     = @{ Label = 'Reopened?' }
}
#endregion

#region Shared views: view files shipped with the app, and a store for readers' and shared views
# the folder next to this script (examples/views); PSU sets $PSScriptRoot for an app script
$viewFolder = Join-Path $PSScriptRoot 'views'
# view files in a folder next to the PSU repository ($Repository), never inside it
$templateStore = New-UDPivotFileTemplateStore
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
        New-UDTypography -Variant body2 -Text '5000 tickets from a DataTable. Drag fields from the list into Rows, Columns and Values, click a number to see its tickets, save your layout under Views.' -Style @{ marginBottom = '12px' }
        # the placeholder comes with the page: the report's frame at once, and the browser loads the
        # module's code while the server still builds the 5000 rows
        New-UDDynamic -Id 'tickets-report' -LoadingComponent {
            New-UDPivotReportPlaceholder -Locale $(if ($Session:PivotLocale) { $Session:PivotLocale } else { 'en-US' })
        } -Content {
            $locale = if ($Session:PivotLocale) { $Session:PivotLocale } else { 'en-US' }
            # the tab keeps its own view (also over a change of language); $Session is shared by all tabs
            # of the browser, so the last view stored there only starts a new tab (-SavedView), and never
            # replaces what another tab shows (as -View would)
            New-UDPivotReport -Id 'tickets' -Data $tickets -View $startView -SavedView $Session:PivotView -FieldDefaults $fieldDefaults `
                -Templates $builtInTemplates -TemplatePath $viewFolder -TemplateStore $templateStore -AdminRole 'Administrator' -SourceName 'Tickets' `
                -Locale $locale -FileName 'tickets' -OnViewChange {
                Import-Module PowerShellUniversal.Component.Pivot
                $Session:PivotView = ConvertFrom-UDPivotView -InputObject $EventData.json
            } -OnCellClick {
                $where = ($EventData.filter | ForEach-Object { '{0} = {1}' -f $_.field, $_.value }) -join ', '
                Show-UDToast -Message ('{0} tickets{1}' -f $EventData.count, $(if ($where) { " ($where)" })) -Duration 4000
            }
        }
    }

    New-UDPage -Name 'Templates' -Url '/templates' -Content {
        New-UDTypography -Variant h5 -Text 'Templates: shared views and my views'
        New-UDTypography -Variant body2 -Text 'Open Views in the toolbar. Shared views come from -Templates, from view files in a folder (-TemplatePath) and from the store; this app has no sign-in, so the views you save stay in this browser. Download view writes the view file a folder or a store keeps.' -Style @{ marginBottom = '12px' }
        New-UDPivotReport -Id 'templates-report' -Data $tickets -View $startView -FieldDefaults $fieldDefaults -Label 'Tickets with templates' `
            -Templates $builtInTemplates -TemplatePath $viewFolder -TemplateStore $templateStore -AdminRole 'Administrator' -SourceId 'tickets' -SourceName 'Tickets'
    }

    New-UDPage -Name 'Events' -Url '/events' -Content {
        New-UDTypography -Variant h5 -Text 'What the events send to the server ($EventData)'
        New-UDTypography -Variant body2 -Text 'Change the view or click a value: the last event appears below the report.' -Style @{ marginBottom = '12px' }
        # 640 pixels, not the default of one screen: the event log below the report stays in view
        New-UDPivotReport -Id 'events-report' -Data $tickets -View $startView -Height 640px -OnViewChange {
            Set-UDElement -Id 'event-log' -Properties @{ text = 'OnViewChange: ' + $EventData.json }
        } -OnCellClick {
            $summary = [ordered]@{ filter = $EventData.filter; value = $EventData.value; text = $EventData.text; count = $EventData.count; rows = @($EventData.rows).Count }
            Set-UDElement -Id 'event-log' -Properties @{ text = 'OnCellClick: ' + ($summary | ConvertTo-Json -Depth 5 -Compress) }
        }
        New-UDTypography -Id 'event-log' -Variant body2 -Text 'No event yet.' -Style @{ marginTop = '12px'; fontFamily = 'monospace'; overflowWrap = 'anywhere' }
    }

    New-UDPage -Name 'Your file' -Url '/your-file' -Content {
        New-UDTypography -Variant h5 -Text 'Your own file next to the app''s data (-AllowImport)'
        New-UDTypography -Variant body2 -Text 'Drop a CSV, JSON or Excel file onto the report, or pick it under Data. It is read in your browser; the server only hears that the data changed (-OnDataLoad, below). Views of your file are saved in this browser, per file; Back to original data under Data shows the tickets again.' -Style @{ marginBottom = '12px' }
        # 640 pixels: the event log below the report stays in view. -OnSaveTemplate saves views of the
        # tickets on the server (here: only logged); views of a file go to the browser's store.
        New-UDPivotReport -Id 'import-report' -Data $tickets -View $startView -Height 640px -FieldDefaults $fieldDefaults -SourceId 'tickets' -SourceName 'Tickets' `
            -Templates $builtInTemplates -AllowImport -OnDataLoad {
            $file = if ($EventData.file) { $EventData.file.name } else { 'the app''s data' }
            Set-UDElement -Id 'import-log' -Properties @{ text = 'OnDataLoad: {0}, {1}, {2} rows, {3} columns' -f $EventData.cause, $file, $EventData.rows, $EventData.columnCount }
        } -OnViewChange {
            Set-UDElement -Id 'import-event-log' -Properties @{ text = 'OnViewChange: ' + $EventData.json }
        } -OnCellClick {
            Set-UDElement -Id 'import-event-log' -Properties @{ text = 'OnCellClick: {0} rows' -f $EventData.count }
        } -OnSaveTemplate {
            Set-UDElement -Id 'import-event-log' -Properties @{ text = 'OnSaveTemplate: ' + $EventData.name }
        }
        New-UDTypography -Id 'import-log' -Variant body2 -Text 'No data loaded yet.' -Style @{ marginTop = '12px'; fontFamily = 'monospace'; overflowWrap = 'anywhere' }
        New-UDTypography -Id 'import-event-log' -Variant body2 -Text 'No event yet.' -Style @{ fontFamily = 'monospace'; overflowWrap = 'anywhere' }
    }

    New-UDPage -Name 'Fields' -Url '/fields' -Content {
        New-UDTypography -Variant h5 -Text 'Field names and descriptions from a schema'
        New-UDTypography -Variant body2 -Text 'Display names, descriptions (the "i" next to a field), links, types and orders come from an OpenAPI document; one description comes from -FieldDescriptions, as Get-UDPivotSqlColumnDescription returns them from SQL Server.' -Style @{ marginBottom = '12px' }
        # an OpenAPI 3 document as a hashtable; a file path, JSON text or an https URL work the same
        $openApi = @{
            openapi    = '3.0.3'
            info       = @{ title = 'Tickets'; version = '1.0' }
            paths      = @{}
            components = @{ schemas = @{ Ticket = @{
                        type       = 'object'
                        properties = @{
                            Ticket       = @{ type = 'integer'; title = 'Ticket number' }
                            Created      = @{ type = 'string'; format = 'date-time'; description = 'When the customer reported it.' }
                            Team         = @{ type = 'string'; title = 'Support team'; description = 'The team the ticket is assigned to.'; externalDocs = @{ url = 'https://powershell-universal-components.eize.dev/pivot/fields/' } }
                            Status       = @{ type = 'string'; enum = @('Open', 'Waiting', 'Closed'); description = 'Open, waiting for the customer, or closed.' }
                            'Lead hours' = @{ type = 'number'; title = 'Lead time (h)' }
                        }
                    }
                }
            }
        }
        # as Get-UDPivotSqlColumnDescription returns them (MS_Description of the columns)
        $columnComments = [ordered]@{ Customer = 'The customer who reported the ticket.'; Agent = 'Who works on it; empty while unassigned.' }
        New-UDPivotReport -Id 'fields-report' -Data $tickets -Schema $openApi -SchemaName 'Ticket' -FieldDescriptions $columnComments -FieldDefaults $fieldDefaults `
            -View @{ rows = @('Team'); cols = @('Status'); values = @(@{ field = 'Lead hours'; agg = 'average'; format = 'number:1' }) } `
            -ChartOptions @{ legend = @{ top = 0 } } -Label 'Tickets with field descriptions'
    }

    # 640 pixels and more: below 600 pivotkit folds the zones into one line (its compact layout), which
    # the fixed card below shows on purpose
    New-UDPage -Name 'Layouts' -Url '/layouts' -Content {
        New-UDTypography -Variant h5 -Text 'The report in page layouts'
        New-UDTabs -Tabs {
            New-UDTab -Text 'In a tab' -Content {
                New-UDPivotReport -Id 'layout-tab-1' -Data $tickets -View $builtInTemplates[1].View -Height 640px -Label 'Tickets per month'
            }
            New-UDTab -Text 'Second tab (starts hidden)' -Content {
                New-UDPivotReport -Id 'layout-tab-2' -Data $tickets -View $builtInTemplates[2].View -Height 640px -Label 'Lead time per customer'
            }
        }
        # a card of a fixed height: the report keeps inside its -Height (pivotkit's grow is off with a
        # height), the field list starts collapsed to a rail
        New-UDCard -Id 'fixed-card' -Title 'In a card of a fixed height (560 px), field list collapsed' -Style @{ height = '560px'; overflow = 'hidden' } -Content {
            New-UDPivotReport -Id 'layout-fixed' -Data $tickets -View $startView -Height 440px -FieldList Collapsed -Label 'Tickets in a fixed card'
        }
        # -NoAddressBar: this report's view stays out of the address (sessionStorage only)
        New-UDCard -Title 'In a card, 640 px high, view not in the address bar' -Content {
            New-UDPivotReport -Id 'layout-card' -Data $tickets -View $builtInTemplates[3].View -Height 640px -NoAddressBar -Label 'Cost per team'
        }
        New-UDStack -Direction row -Spacing 2 -Content {
            New-UDCard -Title 'Half width' -Style @{ flex = '1 1 0'; minWidth = 0 } -Content {
                New-UDPivotReport -Id 'layout-half-1' -Data $tickets -View @{ rows = @('Category'); values = @(@{ field = 'Ticket'; agg = 'count' }) } -Height 640px -Label 'Tickets per category'
            }
            New-UDCard -Title 'Half width, German' -Style @{ flex = '1 1 0'; minWidth = 0 } -Content {
                New-UDPivotReport -Id 'layout-half-2' -Data $tickets -View @{ rows = @('Status'); values = @(@{ field = 'Cost'; agg = 'sum'; format = 'currency:EUR' }) } -Locale de-DE -Height 640px -Label 'Kosten je Status'
            }
        }
    }

    # On purpose without -Id: the module tells the two reports apart by the line of the call and the columns
    New-UDPage -Name 'Without Id' -Url '/without-id' -Content {
        New-UDTypography -Variant h5 -Text 'Two reports without -Id'
        New-UDTypography -Variant body2 -Text 'Each keeps its own view when the theme switches or the page reloads.' -Style @{ marginBottom = '12px' }
        New-UDPivotReport -Data $tickets -View $startView -Height 640px -Label 'Tickets per team'
        New-UDPivotReport -Data $tickets -View @{ rows = @('Category'); values = @(@{ field = 'Ticket'; agg = 'count' }) } -Height 640px -Label 'Tickets per category'
    }
)
