#Requires -Version 7.4
# Pester tests for PowerShellUniversal.Component.Pivot.Demo outside PSU: the PSU commands the app uses
# are stubs (New-UDDynamic draws its content, New-UDAlert fails the test), $Session is a variable
# drive, New-UDPivotReport is the real one.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'PSU provides $Repository')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'The stubs take the parameters of the PSU commands')]
param()

BeforeAll {
    if (-not ('Endpoint' -as [type])) {
        Add-Type -TypeDefinition @'
public class Endpoint {
    public System.Management.Automation.ScriptBlock ScriptBlock;
    public string RegisteredId;
    public Endpoint(System.Management.Automation.ScriptBlock scriptBlock) { ScriptBlock = scriptBlock; }
    public void Register(string id, object cmdlet) { RegisteredId = id; }
}
'@
    }
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
    function global:New-UDAlert { param($Severity, $Text) throw "Alert on the page: $Text" }
    # the pages answer public API calls from the snapshots: a call to the network fails the test
    function global:Invoke-RestMethod { throw "Network call: $args" }
    function global:New-UDElement { param($Tag, $Attributes, $Content) if ($Content) { & $Content } }
    foreach ($name in 'New-UDTypography', 'New-UDSelect', 'New-UDSelectOption', 'New-UDSwitch', 'New-UDMarkdown', 'New-UDExpansionPanelGroup', 'New-UDExpansionPanel', 'Sync-UDElement', 'Show-UDToast') {
        Set-Item -Path "function:global:$name" -Value { }
    }
}

AfterAll {
    foreach ($name in 'Invoke-RestMethod', 'New-UDApp', 'New-UDPage', 'New-UDDynamic', 'New-UDAlert', 'New-UDElement', 'New-UDTypography', 'New-UDSelect', 'New-UDSelectOption', 'New-UDSwitch', 'New-UDMarkdown', 'New-UDExpansionPanelGroup', 'New-UDExpansionPanel', 'Sync-UDElement', 'Show-UDToast') {
        Remove-Item -Path "function:$name" -ErrorAction Ignore
    }
    Remove-PSDrive -Name Session -ErrorAction Ignore
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
        foreach ($file in 'Apps/Showcase.ps1', 'Apps/Docs/examples.ps1', 'Apps/Tickets/showcase.ps1', 'Apps/Tickets/views', 'Data/SOURCES.md', 'Data/Addresses.psd1', 'Data/endoflife.date/api/python.json', 'Data/archive-api.open-meteo.com/v1/archive.json') {
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
        foreach ($name in 'Python releases', 'End of life', 'Release cycles', 'Weather', 'Your data', 'Tickets', 'Templates', 'Events', 'Fields', 'Layouts') {
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
