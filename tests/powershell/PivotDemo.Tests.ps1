#Requires -Version 7.4
# Pester tests for PowerShellUniversal.Component.Pivot.Demo outside PSU: the PSU commands the app uses
# are stubs (New-UDDynamic draws its content, New-UDAlert fails the test), $Session is a variable
# drive, New-UDPivotReport is the real one.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'PSU provides $Repository')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'The stubs take the parameters of the PSU commands')]
param()

BeforeAll {
    . (Join-Path $PSScriptRoot '..' '..' 'build' 'Add-EndpointType.ps1')
    $script:repo = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $script:demoDir = Join-Path $script:repo 'modules' 'PowerShellUniversal.Component.Pivot.Demo'
    $pivot = Import-Module (Join-Path $script:repo 'modules' 'PowerShellUniversal.Component.Pivot' 'PowerShellUniversal.Component.Pivot.psm1') -Force -PassThru
    & $pivot { $Script:AssetId = 'asset-under-test' }
    Import-Module (Join-Path $script:demoDir 'PowerShellUniversal.Component.Pivot.Demo.psm1') -Force

    # what PSU provides to an app: $Session, $Repository; the stubs record what they get
    if (-not (Get-PSDrive -Name Session -ErrorAction Ignore)) { New-PSDrive -Name Session -PSProvider Variable -Root '' -Scope Global | Out-Null }
    $global:Repository = Join-Path $TestDrive 'Repository'
    function global:New-UDApp { param($Title, $Pages) @{ Title = $Title; Pages = @($Pages) } }
    function global:New-UDPage { param($Name, $Url, $Content) @{ Name = $Name; Url = $Url; Content = $Content } }
    function global:New-UDDynamic { param($Id, $Content, $LoadingComponent) & $Content }
    # an error on the page fails the test; the info notes of the pages that need a server or a program are expected
    $global:PivotDemoAlerts = [System.Collections.Generic.List[string]]::new()
    function global:New-UDAlert { param($Severity, $Title, $Text) if ($Severity -eq 'error') { throw "Alert on the page: $Text" }; $global:PivotDemoAlerts.Add("$Title") }
    function global:New-UDButton { param($Id, $Text, $Variant, $OnClick, [switch]$ShowLoading, [switch]$Disabled) @{ type = 'button'; id = $Id; text = $Text; disabled = [bool]$Disabled; onClick = $OnClick } }
    # the pages answer public API calls from the snapshots: a call to the network fails the test
    function global:Invoke-RestMethod { throw "Network call: $args" }
    function global:New-UDElement { param($Tag, $Attributes, $Content) if ($Content) { & $Content } }
    foreach ($name in 'New-UDTypography', 'New-UDLink', 'New-UDSelect', 'New-UDSelectOption', 'New-UDSwitch', 'New-UDMarkdown', 'New-UDExpansionPanelGroup', 'New-UDExpansionPanel', 'Sync-UDElement', 'Show-UDToast') {
        Set-Item -Path "function:global:$name" -Value { }
    }
}

AfterAll {
    foreach ($name in 'Invoke-RestMethod', 'New-UDApp', 'New-UDPage', 'New-UDDynamic', 'New-UDAlert', 'New-UDButton', 'New-UDElement', 'New-UDTypography', 'New-UDLink', 'New-UDSelect', 'New-UDSelectOption', 'New-UDSwitch', 'New-UDMarkdown', 'New-UDExpansionPanelGroup', 'New-UDExpansionPanel', 'Sync-UDElement', 'Show-UDToast') {
        Remove-Item -Path "function:$name" -ErrorAction Ignore
    }
    Remove-PSDrive -Name Session -ErrorAction Ignore
    Remove-Variable -Scope Global -Name Repository, PivotDemoAlerts, PivotDemoDownload -ErrorAction Ignore
}

Describe 'Pivot demo module' {
    It 'exports New-UDPivotShowcase and requires a pivot module version that exists' {
        # read as data: Test-ModuleManifest would need the pivot module installed (RequiredModules)
        $manifest = Import-PowerShellDataFile -LiteralPath (Join-Path $script:demoDir 'PowerShellUniversal.Component.Pivot.Demo.psd1')
        $manifest.FunctionsToExport | Should -Contain 'New-UDPivotShowcase'
        $manifest.PrivateData.PSData.Tags | Should -Contain 'PowerShellUniversal'
        $pivotManifest = Import-PowerShellDataFile -LiteralPath (Join-Path $script:repo 'modules' 'PowerShellUniversal.Component.Pivot' 'PowerShellUniversal.Component.Pivot.psd1')
        $required = $manifest.RequiredModules | Where-Object ModuleName -EQ 'PowerShellUniversal.Component.Pivot'
        [version]$required.ModuleVersion | Should -BeLessOrEqual ([version]$pivotManifest.ModuleVersion)
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $script:demoDir 'Apps' 'Showcase.ps1'), [ref]$null, [ref]$errors) | Out-Null
        $errors | Should -BeNullOrEmpty
    }

    It 'is built with the examples, the data and the ticket showcase, and links that work outside the repository' {
        $built = & (Join-Path $script:repo 'build' 'Build-Module.ps1') -Module 'PowerShellUniversal.Component.Pivot.Demo' -OutputPath (Join-Path $TestDrive 'out')
        foreach ($file in 'Apps/Showcase.ps1', 'Apps/Docs/examples.ps1', 'Apps/Tickets/showcase.ps1', 'Apps/Tickets/views', 'Apps/Tickets/views/hours-to-close-per-group.pivotkit.json', 'Data/SOURCES.md', 'Data/Addresses.psd1', 'Data/endoflife.date/api/python.json', 'Data/archive-api.open-meteo.com/v1/archive.json') {
            Join-Path $built.FullName $file | Should -Exist
        }
        Join-Path $built.FullName 'Build.psd1' | Should -Not -Exist
        $readme = Get-Content -LiteralPath (Join-Path $built.FullName 'README.md') -Raw
        $readme | Should -Not -Match '\]\(\.\./'
        $readme | Should -Match '\]\(https://github\.com/[^)]+/blob/HEAD/modules/PowerShellUniversal\.Component\.Pivot\.Demo/Apps/Showcase\.ps1\)'
    }

    It 'has the documentation''s three endoflife examples, weather, your data and the ticket pages' {
        $app = New-UDPivotShowcase
        $names = $app.Pages.Name
        foreach ($name in 'Python releases', 'End of life', 'Release cycles', 'Weather', 'Your data', 'Report as a file', 'Rows from a server', 'Tickets', 'Templates', 'Charts', 'Events', 'Fields', 'Layouts') {
            $names | Should -Contain $name
        }
        # the URLs are unique (PSU would serve only one of two pages with the same URL)
        ($app.Pages.Url | Sort-Object -Unique).Count | Should -Be $app.Pages.Count
    }

    It 'draws every page with public data from the shipped snapshots, in <Locale>' -ForEach @(@{ Locale = 'en-GB' }, @{ Locale = 'de-DE' }) {
        $Session:PivotShowcaseLocale = $Locale
        $Session:PivotShowcaseLive = $false
        $app = New-UDPivotShowcase
        foreach ($name in 'Python releases', 'End of life', 'Release cycles', 'Weather') {
            $page = $app.Pages | Where-Object Name -EQ $name
            $reports = @(& $page.Content | Where-Object { $_ -is [hashtable] -and $_.type -eq 'ud-pivot-report' })
            $reports.Count | Should -Be 1 -Because $name
            $reports[0].locale | Should -Be $Locale -Because $name
            @($reports[0].data).Count | Should -BeGreaterThan 10 -Because $name
        }
        $weather = (& ($app.Pages | Where-Object Name -EQ 'Weather').Content | Where-Object { $_ -is [hashtable] -and $_.type -eq 'ud-pivot-report' })
        # one report per page: no -Height of its own, so the report's default fills the window
        $weather.ContainsKey('height') | Should -BeFalse -Because 'a fixed height would leave only a few rows below the zones'
        # six cities, two years of days
        @($weather.data).Count | Should -Be (6 * 731)
    }

    It 'gives its reports and their placeholder no -Height, so the default fills the window' {
        # the pages' code is text in Showcase.ps1 (shown on the pages too): read it as text
        $text = Get-Content -Raw -LiteralPath (Join-Path $script:demoDir 'Apps' 'Showcase.ps1')
        $calls = [regex]::Matches($text, '(?m)New-UDPivotReport(Placeholder)?\b[^\r\n]*')
        $calls.Count | Should -BeGreaterThan 2
        foreach ($call in $calls) { $call.Value | Should -Not -Match '-Height\b' }
    }

    It 'answers only the addresses it has a snapshot of' {
        { Get-UDPivotShowcaseData 'https://endoflife.date/api/no-such-product.json' } | Should -Throw '*No snapshot*'
        { Get-UDPivotShowcaseData 'https://archive-api.open-meteo.com/v1/archive?latitude=1&longitude=1' } | Should -Throw '*No snapshot*'
        { Get-UDPivotShowcaseData 'http://endoflife.date/api/python.json' } | Should -Throw '*https*'
        # no way out of the module's Data folder, and nothing but its .json snapshots
        { Get-UDPivotShowcaseData 'https://endoflife.date/api/../../Addresses.psd1' } | Should -Throw '*No snapshot*'
        { Get-UDPivotShowcaseData 'https://endoflife.date/%2e%2e/%2e%2e/SOURCES.md' } | Should -Throw '*No snapshot*'
        { Get-UDPivotShowcaseData 'https://endoflife.date/..%2f..%2f..%2fREADME.md' } | Should -Throw '*No snapshot*'
        (Get-UDPivotShowcaseData 'https://endoflife.date/api/python.json').Count | Should -BeGreaterThan 10
    }
}

Describe 'Pivot demo: your data' {
    It 'reads the reader''s file in the browser: -AllowImport on an empty report, views per file in the browser, no upload to the server' {
        $Session:PivotShowcaseLocale = 'de-DE'
        $app = New-UDPivotShowcase
        $page = $app.Pages | Where-Object Name -EQ 'Your data'
        $report = @(& $page.Content | Where-Object { $_ -is [hashtable] -and $_.type -eq 'ud-pivot-report' })
        $report.Count | Should -Be 1
        $report[0].allowImport | Should -BeTrue
        $report[0].templateStore | Should -Be 'browser'
        $report[0].locale | Should -Be 'de-DE'
        @($report[0].data).Count | Should -Be 0
        # no server upload is left on the page (its code is text in Showcase.ps1)
        Get-Content -Raw -LiteralPath (Join-Path $script:demoDir 'Apps' 'Showcase.ps1') | Should -Not -Match 'New-UDUpload'
    }
}

Describe 'Pivot demo: the first page and pivotkit 0.9' {
    BeforeAll {
        $Session:PivotShowcaseLocale = 'en-GB'
        $Session:PivotShowcaseLive = $false
        $script:app = New-UDPivotShowcase
        $script:weather = & ($script:app.Pages | Where-Object Name -EQ 'Weather').Content | Where-Object { $_ -is [hashtable] -and $_.type -eq 'ud-pivot-report' }
    }

    It 'opens with the Weather page: the table and a line chart with the high and low points side by side' {
        $script:app.Pages[0].Name | Should -Be 'Weather'
        $view = $script:weather.view
        $view.display | Should -Be 'both'
        $view.chart.type | Should -Be 'line'
        $view.chart.referenceLines.extremes | Should -BeTrue
        $view.values[0].conditional.colors | Should -Be @('#2a78d6', '#f2f2f2', '#eb6834')
    }

    It 'has views with bars and lines, field names of its own and the rows sorted by one column' {
        $templates = @($script:weather.templates)
        $combo = ($templates | Where-Object { $_.view.chart.type -eq 'combo' }).view
        $combo | Should -Not -BeNullOrEmpty
        @($combo.values).Count | Should -Be 2
        $combo.fieldLabels.'Rain mm' | Should -Be 'Rain (mm a day)'
        $sorted = ($templates | Where-Object { $_.view.sort -and $_.view.sort[0].column }).view
        $sorted.sort[0].column | Should -Be @(7)
    }
}

Describe 'Pivot demo: rows from a server' {
    BeforeEach { $global:PivotDemoAlerts.Clear() }

    It 'explains what it needs when no server is set up, and draws no report' {
        $app = New-UDPivotShowcase
        $page = $app.Pages | Where-Object Name -EQ 'Rows from a server'
        $page.Url | Should -Be '/server-rows'
        @(& $page.Content | Where-Object { $_ -is [hashtable] -and $_.type -eq 'ud-pivot-report' }).Count | Should -Be 0
        $global:PivotDemoAlerts | Should -Contain 'No pivotkit-server is set up for this page'
    }

    It 'shows the server''s source with the person''s token; without a token it says the page needs a sign-in and sends nothing' {
        $app = New-UDPivotShowcase -ServerUri 'https://reports.example.com/api/v1' -ServerSource 'orders'
        $page = $app.Pages | Where-Object Name -EQ 'Rows from a server'
        # no $AccessToken: no report, so no request to the server either
        @(& $page.Content | Where-Object { $_ -is [hashtable] -and $_.type -eq 'ud-pivot-report' }).Count | Should -Be 0
        $global:PivotDemoAlerts | Should -Contain 'This page needs a sign-in'
        # the page's code names the configured server and source, never another
        $page.Content.ToString() | Should -Match ([regex]::Escape("-Uri 'https://reports.example.com/api/v1' -Source 'orders' -Token `$AccessToken -Query `$Query"))
        $page.Content.ToString() | Should -Match ([regex]::Escape('if ($AccessToken) {'))
    }

    It 'asks the server with the person''s token when there is one' {
        # a closed port on this machine: the request fails, and the report says so instead of the rows
        $app = New-UDPivotShowcase -ServerUri 'http://127.0.0.1:9/api/v1' -ServerSource 'orders'
        $page = $app.Pages | Where-Object Name -EQ 'Rows from a server'
        Set-Variable -Name AccessToken -Value 'token-under-test'
        try { $report = @(& $page.Content 3>$null | Where-Object { $_ -is [hashtable] -and $_.type -eq 'ud-pivot-report' }) }
        finally { Remove-Variable -Name AccessToken }
        $report.Count | Should -Be 1
        $report[0].id | Should -Be 'server-rows'
        $global:PivotDemoAlerts | Should -BeNullOrEmpty
        ($report[0] | ConvertTo-Json -Depth 8 -Compress) | Should -Not -Match 'token-under-test'
    }

    It 'takes -ServerUri and -ServerSource only together, and only an http(s) address without a query' {
        { New-UDPivotShowcase -ServerUri 'https://reports.example.com/api/v1' } | Should -Throw '*go together*'
        { New-UDPivotShowcase -ServerUri 'https://reports.example.com/api/v1?x=1' -ServerSource 'orders' } | Should -Throw '*without a query string*'
        { New-UDPivotShowcase -ServerUri 'file:///etc/passwd' -ServerSource 'orders' } | Should -Throw '*absolute http(s) address*'
    }
}

Describe 'Pivot demo: report as a file' {
    BeforeEach { $global:PivotDemoAlerts.Clear() }

    It 'says what to install and disables the buttons when pivotkit''s command line is missing; the report still works' {
        $path = Join-Path $TestDrive 'no-such-pivotkit'
        $app = New-UDPivotShowcase -PivotkitPath $path
        $page = $app.Pages | Where-Object Name -EQ 'Report as a file'
        $out = @(& $page.Content)
        # the code the page shows never names the server's own path of the program; the code that runs does
        $text = $page.Content.ToString()
        $shown = [regex]::Match($text, '(?s)New-UDExpansionPanel .*').Value
        $shown | Should -Match 'Invoke-UDPivotReport'
        $shown | Should -Not -Match ([regex]::Escape($path))
        $text.Replace($shown, '') | Should -Match ([regex]::Escape($path))
        $global:PivotDemoAlerts | Should -Contain 'pivotkit''s command line is not installed on this PSU server'
        $buttons = @($out | Where-Object { $_ -is [hashtable] -and $_.type -eq 'button' })
        $buttons.text | Should -Be @('Download Excel workbook', 'Download HTML report')
        $buttons.disabled | Should -Be @($true, $true)
        @($out | Where-Object { $_ -is [hashtable] -and $_.type -eq 'ud-pivot-report' }).Count | Should -Be 1
    }

    It 'keeps a typographic apostrophe in -PivotkitPath as text, never as the end of a string in the page code' {
        $quote = [char]0x2019
        $path = Join-Path $TestDrive ('O{0}Neil{0}; Write-Output INJECTED; {0}x' -f $quote)
        $app = New-UDPivotShowcase -PivotkitPath $path
        $page = $app.Pages | Where-Object Name -EQ 'Report as a file'
        $out = @(& $page.Content)
        $out | Should -Not -Contain 'INJECTED'
        # the page ran its check of the path as written: the program is not there
        $global:PivotDemoAlerts | Should -Contain 'pivotkit''s command line is not installed on this PSU server'
        $page.Content.ToString() | Should -Match ([regex]::Escape(($path -replace [string]$quote, ($quote + $quote))))
    }

    It 'makes a real <Format> file of the view the reader has, with pivotkit''s command line' -Skip:(-not (Get-Command -Name 'pivotkit' -CommandType Application -ErrorAction Ignore)) -ForEach @(
        @{ Format = 'xlsx'; Magic = 'PK' }
        @{ Format = 'html'; Magic = '<!' }
    ) {
        $cli = (Get-Command -Name 'pivotkit' -CommandType Application | Select-Object -First 1).Source
        $app = New-UDPivotShowcase -PivotkitPath $cli
        $out = @(& ($app.Pages | Where-Object Name -EQ 'Report as a file').Content)
        $global:PivotDemoAlerts | Should -BeNullOrEmpty
        $button = $out | Where-Object { $_ -is [hashtable] -and $_.type -eq 'button' -and $_.id -eq "weather-file-$Format" }
        $button.disabled | Should -BeFalse
        # the reader's view: rain days per city, as the browser sends it
        # the reader's view, as -OnViewChange keeps it: rain days per season only
        $Session:PivotShowcaseFileView = ConvertFrom-UDPivotView -InputObject '{"rows":["Season"],"values":[{"field":"Rain day","agg":"sum"}]}'
        $global:PivotDemoDownload = $null
        # PSU 2026.3's -Bytes; 2026.2 has only -Path (the browser tests on both instances cover that one)
        function global:Start-UDDownload {
            param([byte[]]$Bytes, $FileName, $ContentType)
            $global:PivotDemoDownload = @{ Bytes = $Bytes; FileName = $FileName; ContentType = $ContentType }
        }
        try { & $button.onClick 3>$null }
        finally { Remove-Item -Path function:Start-UDDownload -ErrorAction Ignore; $Session:PivotShowcaseFileView = $null }
        $global:PivotDemoDownload | Should -Not -BeNullOrEmpty
        $global:PivotDemoDownload.FileName | Should -Match "^weather-report-\d{4}-\d{2}-\d{2}\.$Format$"
        [System.Text.Encoding]::ASCII.GetString($global:PivotDemoDownload.Bytes, 0, 2) | Should -Be $Magic
        if ($Format -eq 'html') {
            # the reader's view, not the start view: seasons in the rows, no city
            $html = [System.Text.Encoding]::UTF8.GetString($global:PivotDemoDownload.Bytes)
            $html | Should -Match 'Spring'
            $html | Should -Not -Match 'Sydney'
        }
    }
}
