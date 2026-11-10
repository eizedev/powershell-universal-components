#Requires -Version 7.4
# Pester tests for PowerShellUniversal.Component.Pivot.Demo outside PSU: the PSU commands the app uses
# are stubs (New-UDDynamic draws its content, New-UDAlert fails the test), $Session is a variable
# drive, New-UDPivotReport is the real one.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '', Justification = 'PSU provides $Repository; the upload stub hands its handler to the test')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = '$EventData is read by the dot-sourced upload handler')]
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
    function global:New-UDUpload { param($Id, $Text, $Accept, $OnUpload) $global:UploadHandler = $OnUpload }
    function global:New-UDElement { param($Tag, $Attributes, $Content) if ($Content) { & $Content } }
    foreach ($name in 'New-UDTypography', 'New-UDSelect', 'New-UDSelectOption', 'New-UDSwitch', 'New-UDMarkdown', 'New-UDExpansionPanelGroup', 'New-UDExpansionPanel', 'Sync-UDElement', 'Show-UDToast') {
        Set-Item -Path "function:global:$name" -Value { }
    }
}

AfterAll {
    foreach ($name in 'Invoke-RestMethod', 'New-UDApp', 'New-UDPage', 'New-UDDynamic', 'New-UDAlert', 'New-UDUpload', 'New-UDElement', 'New-UDTypography', 'New-UDSelect', 'New-UDSelectOption', 'New-UDSwitch', 'New-UDMarkdown', 'New-UDExpansionPanelGroup', 'New-UDExpansionPanel', 'Sync-UDElement', 'Show-UDToast') {
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

    It 'has the documentation''s three endoflife examples, weather, upload and the ticket pages' {
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

Describe 'Pivot demo upload' {
    BeforeAll {
        $Session:PivotShowcaseLocale = 'en-GB'
        $app = New-UDPivotShowcase
        $script:uploadPage = $app.Pages | Where-Object Name -EQ 'Your data'
        & $script:uploadPage.Content | Out-Null
        $script:handler = $global:UploadHandler
        # the event PSU sends: the uploaded file in a temporary file. The handler is dot-sourced in the
        # test itself, since the $Session stub is a variable drive and its values live in that scope.
        function script:New-UploadEvent([string]$Name, [string]$Text) {
            $file = Join-Path $TestDrive ([guid]::NewGuid().ToString('n'))
            Set-Content -LiteralPath $file -Value $Text -NoNewline -Encoding utf8
            [pscustomobject]@{ Name = $Name; FileName = $file }
        }
    }

    It 'reads a German CSV with semicolons and decimal commas into numbers and deletes the file' {
        $EventData = New-UploadEvent -Name 'costs.csv' -Text "Team;Cost`nNetwork;1.234,5`nServer;12,25`n"
        . $script:handler
        $EventData.FileName | Should -Not -Exist
        $Session:PivotShowcaseUploadError | Should -BeNullOrEmpty
        $Session:PivotShowcaseUpload.Rows.Count | Should -Be 2
        $Session:PivotShowcaseUpload.Rows[0].Cost | Should -Be 1234.5
        $Session:PivotShowcaseUpload.Rows[1].Team | Should -Be 'Server'
        # the report on the page gets the rows, at the report's default height
        $report = & $script:uploadPage.Content | Where-Object { $_ -is [hashtable] -and $_.type -eq 'ud-pivot-report' }
        @($report.data).Count | Should -Be 2
        $report.ContainsKey('height') | Should -BeFalse
    }

    It 'gives each uploaded file its own source id, so browser views of one file are not offered for another' {
        # the source id the report on the page gets after an upload (pivotkit lists the browser views
        # made for it); the server's temporary path must not be in it
        $sourceAfter = {
            param([string]$Name, [string]$Text)
            $EventData = New-UploadEvent -Name $Name -Text $Text
            . $script:handler
            $Session:PivotShowcaseUploadError | Should -BeNullOrEmpty
            $report = & $script:uploadPage.Content | Where-Object { $_ -is [hashtable] -and $_.type -eq 'ud-pivot-report' }
            $report.source.id | Should -Not -BeLike ('*{0}*' -f [System.IO.Path]::GetFileName($EventData.FileName))
            $report.source.id
        }
        $costs = . $sourceAfter 'data.csv' "Team,Cost`nNetwork,1`n"
        $tickets = . $sourceAfter 'data.csv' "Ticket,Priority,Team`n1,High,Ops`n"
        $costsAgain = . $sourceAfter 'data.csv' "Team,Cost`nServer,7`nNetwork,2`n"
        $otherName = . $sourceAfter 'other.csv' "Team,Cost`nNetwork,1`n"
        # different columns under the same file name: different data
        $tickets | Should -Not -Be $costs
        # the same file (name and columns) again, also with other rows: the same id, its views stay
        $costsAgain | Should -Be $costs
        $otherName | Should -Not -Be $costs
        # not the report's storage key, which every upload shares
        $costs | Should -Not -Be 'upload'
        $costs.Length | Should -BeLessOrEqual 256
        # a file name of 255 characters (the most a file system allows) still draws the report
        $long = . $sourceAfter (('x' * 251) + '.csv') "Team,Cost`nNetwork,1`n"
        $long.Length | Should -BeLessOrEqual 256
        $long | Should -Not -Be (. $sourceAfter (('x' * 251) + '.csv') "Ticket,Team`n1,Ops`n")
    }

    It 'reads JSON as an array of objects or an object with one array' {
        $EventData = New-UploadEvent -Name 'a.json' -Text '[{"a":1,"b":"x"},{"a":2,"b":"y"}]'
        . $script:handler
        $Session:PivotShowcaseUpload.Rows.Count | Should -Be 2
        $EventData = New-UploadEvent -Name 'b.json' -Text '{"count":2,"items":[{"a":1},{"a":2},{"a":3}]}'
        . $script:handler
        $Session:PivotShowcaseUpload.Rows.Count | Should -Be 3
    }

    It 'refuses <Name> with a message and keeps no file' -ForEach @(
        @{ Name = 'notes.txt'; Text = 'a,b'; Message = '*reads .csv and .json*' }
        @{ Name = 'bad.json'; Text = '{"a":[1,2]}'; Message = '*must be an object*' }
        @{ Name = 'two.json'; Text = '{"a":[],"b":[]}'; Message = '*exactly one array*' }
        @{ Name = 'empty.csv'; Text = 'a,b'; Message = '*no rows*' }
        @{ Name = 'broken.json'; Text = '{"a":'; Message = '*not valid JSON*' }
        @{ Name = 'deep.json'; Text = ('[' * 30) + (']' * 30); Message = '*not valid JSON, or nested deeper*' }
        @{ Name = 'wide.csv'; Text = ((1..201 | ForEach-Object { "c$_" }) -join ',') + "`n" + ((1..201) -join ','); Message = '*201 columns*up to 200*' }
        @{ Name = 'wide.json'; Text = '[{' + ((1..201 | ForEach-Object { '"c{0}":1' -f $_ }) -join ',') + '}]'; Message = '*201 columns*up to 200*' }
    ) {
        $Session:PivotShowcaseUpload = $null
        $EventData = New-UploadEvent -Name $Name -Text $Text
        . $script:handler
        $EventData.FileName | Should -Not -Exist
        $Session:PivotShowcaseUpload | Should -BeNullOrEmpty
        $Session:PivotShowcaseUploadError | Should -BeLike $Message
    }

    It 'refuses a file over 5 MB before reading it' {
        $EventData = New-UploadEvent -Name 'big.csv' -Text ('a,b' + "`n" + ('1,2' + "`n") * 1500000)
        . $script:handler
        $EventData.FileName | Should -Not -Exist
        $Session:PivotShowcaseUploadError | Should -BeLike '*MB; the showcase reads files up to 5 MB.'
    }

    It 'refuses more than 100,000 rows before parsing them' {
        $Session:PivotShowcaseUpload = $null
        $EventData = New-UploadEvent -Name 'long.csv' -Text ('a' + "`n" + ('1' + "`n") * 100001)
        . $script:handler
        $Session:PivotShowcaseUpload | Should -BeNullOrEmpty
        $Session:PivotShowcaseUploadError | Should -BeLike '*100?001 rows; the showcase reads up to 100?000.'
    }

    It 'deletes the file and shows no server details when reading it fails' {
        $Session:PivotShowcaseUpload = $null
        $EventData = New-UploadEvent -Name 'costs.csv' -Text "a,b`n1,2"
        # an error with a path in it, as the file system would raise
        Mock Get-Item { throw "Access to the path '/srv/secret/tmp/x' is denied." }
        . $script:handler 3>$null
        $EventData.FileName | Should -Not -Exist
        $Session:PivotShowcaseUploadError | Should -Be 'The file could not be read. The server log has the details.'
    }
}
