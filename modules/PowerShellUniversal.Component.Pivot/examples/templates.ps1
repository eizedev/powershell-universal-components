<#
    Templates in an app with sign-in: every reader keeps their own views on the server ("My views"),
    readers with an admin role publish views for everyone ("Shared views"), delete shared ones and see
    the admin panel under the report (the view as JSON, the columns, timings).

    Run it as an app with authentication (New-PSUApp -Authenticated, or "Authenticated" in the admin
    console). -AdminRole names the roles that may change shared views: the event handlers the module
    registers check them on the server with $Roles of each event. The views are view files in a folder
    next to the PSU repository (New-UDPivotFileTemplateStore); New-UDPivotTemplateStore keeps them in a
    database, Valkey or S3 instead (see the documentation).
#>

#region Data: 600 service requests (a fixed seed, so every run shows the same numbers)
$rng = [System.Random]::new(7)
$services = 'Mail', 'VPN', 'Printing', 'Laptop', 'Phone'
$sites = 'Berlin', 'Hamburg', 'Munich', 'Remote'
$requests = foreach ($i in 1..600) {
    [pscustomobject]@{
        Request  = 1000 + $i
        Opened   = ([datetime]'2026-10-31').AddDays(-$rng.Next(0, 365))
        Service  = $services[$rng.Next(0, $services.Count)]
        Site     = $sites[$rng.Next(0, $sites.Count)]
        Minutes  = 5 + $rng.Next(0, 240)
        Solved   = $rng.NextDouble() -lt 0.8
    }
}
#endregion

# view files next to the PSU repository: users/<hash>/ for each reader, shared/ for everyone
$templateStore = New-UDPivotFileTemplateStore -MaxUserViews 20 -MaxSharedViews 50
# the roles that may publish and delete shared views
$adminRoles = @('Administrator', 'Operator')

New-UDApp -Title 'Pivot templates with sign-in' -Pages @(
    New-UDPage -Name 'Requests' -Url '/requests' -Content {
        New-UDTypography -Variant h5 -Text 'Service requests'
        New-UDTypography -Id 'signed-in' -Variant body2 -Style @{ marginBottom = '12px' } -Text $(
            if (@($Roles) | Where-Object { $_ -in $adminRoles }) { "Signed in as ${User}, an admin: Views offers Publish as shared view, and the admin panel is under the report." }
            else { "Signed in as ${User}: save your own views under Views; shared views are read-only for you." }
        )
        # -UserName and -Roles default to $User and $Roles of this page; 640 pixels, not the default of
        # one screen, so an admin sees the admin panel under the report
        New-UDPivotReport -Id 'requests' -Data $requests -SourceName 'Service requests' -Height 640px `
            -View @{ rows = @('Service'); cols = @('Site'); values = @(@{ field = 'Request'; agg = 'count' }) } `
            -FieldDefaults @{ Minutes = @{ Agg = 'average'; Format = 'number:0'; Description = 'Minutes of work on the request.' }; Request = @{ DrillFormat = 'text' } } `
            -TemplateStore $templateStore -AdminRole $adminRoles
    }
)
