#Requires -Version 7.4
# Pester tests for PowerShellUniversal.Component.Pivot outside PSU: PSU's [Endpoint] type is a stub,
# the asset id is set by hand.

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
    $script:module = Import-Module (Join-Path $script:repo 'modules' 'PowerShellUniversal.Component.Pivot' 'PowerShellUniversal.Component.Pivot.psm1') -Force -PassThru
    & $script:module { $Script:AssetId = 'asset-under-test' }
}

Describe 'New-UDPivotReport' {
    It 'without -Id: a storage key from the call site and the columns, the same on every build' {
        $rows = @([pscustomobject]@{ A = 1; B = 2 })
        $keys = foreach ($i in 1..2) { (New-UDPivotReport -Data $rows).storageKey }
        $keys[0] | Should -Match '^auto-[0-9a-f]{16}$'
        $keys[1] | Should -Be $keys[0]
        # another call (another line), other columns: other keys; the GUID id differs per build
        $other = (New-UDPivotReport -Data $rows).storageKey
        $other | Should -Not -Be $keys[0]
        # one call, data with other columns: other keys
        $byColumns = foreach ($d in @($rows, @([pscustomobject]@{ A = 1 }))) { (New-UDPivotReport -Data $d).storageKey }
        $byColumns[1] | Should -Not -Be $byColumns[0]
        (New-UDPivotReport -Data $rows).id | Should -Not -Be (New-UDPivotReport -Data $rows).id
    }

    It 'returns the plugin hashtable with the rows, their original column names and the defaults' {
        $rows = @([pscustomobject]@{ TicketId = 1; 'Lead hours' = 2.5 }, [pscustomobject]@{ TicketId = 2; 'Lead hours' = 4 })
        $c = New-UDPivotReport -Id 'p1' -Data $rows -TimeZone 'Europe/Berlin'
        $c.type | Should -Be 'ud-pivot-report'
        $c.assetId | Should -Be 'asset-under-test'
        $c.isPlugin | Should -BeTrue
        @($c.data).Count | Should -Be 2
        $c.columnNames | Should -Be @('TicketId', 'Lead hours')
        $c.locale | Should -Be 'en-US'
        $c.timeZone | Should -Be 'Europe/Berlin'
        $c.theme | Should -Be 'auto'
        $c.storageKey | Should -Be 'p1'
        $c.fileName | Should -Be 'pivot'
        $c.drillDown | Should -BeTrue
        foreach ($key in 'view', 'templates', 'height', 'labels', 'fieldDefaults', 'onViewChange', 'onCellClick', 'onSaveTemplate', 'onDeleteTemplate') {
            $c.ContainsKey($key) | Should -BeFalse -Because "$key was not passed"
        }
    }

    It 'converts a DataTable: DBNull to null, dates to ISO text without offset, numbers stay numbers' {
        $t = [System.Data.DataTable]::new()
        [void]$t.Columns.Add('Name')
        [void]$t.Columns.Add('Created', [datetime])
        [void]$t.Columns.Add('Hours', [double])
        [void]$t.Rows.Add('a', [datetime]'2026-03-04 10:30', 1.5)
        [void]$t.Rows.Add('b', [DBNull]::Value, [DBNull]::Value)
        $c = New-UDPivotReport -Data $t
        $c.columnNames | Should -Be @('Name', 'Created', 'Hours')
        $first, $second = @($c.data)
        # a DateTime from SQL has no kind: written as it is, which pivotkit reads as wall-clock time
        $first.Created | Should -Be '2026-03-04T10:30:00.0000000'
        $first.Hours | Should -Be 1.5
        $second.Created | Should -BeNullOrEmpty
        $second.Hours | Should -BeNullOrEmpty
    }

    It 'converts hashtables and a single object into rows' {
        (New-UDPivotReport -Data @(@{ A = 1 }, @{ A = 2 })).data.Count | Should -Be 2
        @((New-UDPivotReport -Data ([pscustomobject]@{ A = 1 })).data).Count | Should -Be 1
        @((New-UDPivotReport -Data $null).data).Count | Should -Be 0
    }

    It 'takes -View as a hashtable or as JSON, and refuses what is no view' {
        $fromHashtable = New-UDPivotReport -Data @() -View @{ rows = @('Team'); values = @(@{ field = 'Id'; agg = 'count' }) }
        $fromHashtable.view.rows | Should -Be @('Team')
        $fromJson = New-UDPivotReport -Data @() -View '{"rows":["Team"],"cols":["Priority"],"unknown":1}'
        $fromJson.view.cols | Should -Be @('Priority')
        $fromJson.view.PSObject.Properties.Name | Should -Not -Contain 'unknown'
        { New-UDPivotReport -Data @() -View '[1,2]' } | Should -Throw '*-View*'
        { New-UDPivotReport -Data @() -View '{"rows":"Team"}' } | Should -Throw '*rows*'
    }

    It 'checks -Templates and keeps Deletable' {
        $c = New-UDPivotReport -Data @() -Templates @(
            @{ Name = 'Per team'; View = @{ rows = @('Team') } }
            [pscustomobject]@{ Name = 'Mine'; View = '{"rows":["Customer"]}'; Deletable = $true }
        )
        $c.templates.Count | Should -Be 2
        $c.templates[0].name | Should -Be 'Per team'
        $c.templates[0].deletable | Should -BeFalse
        $c.templates[1].view.rows | Should -Be @('Customer')
        $c.templates[1].deletable | Should -BeTrue
        { New-UDPivotReport -Data @() -Templates @(@{ View = @{} }) } | Should -Throw '*Name*'
        { New-UDPivotReport -Data @() -Templates @(@{ Name = 'Bad'; View = 'not json' }) } | Should -Throw '*"Bad"*'
        (New-UDPivotReport -Data @() -Templates @()).templates.Count | Should -Be 0
    }

    It 'validates -Locale, -TimeZone, -Theme, -Height and -FieldDefaults' {
        (New-UDPivotReport -Data @() -Locale de-DE).locale | Should -Be 'de-DE'
        { New-UDPivotReport -Data @() -Locale 'de_DE;x' } | Should -Throw
        { New-UDPivotReport -Data @() -TimeZone '../etc' } | Should -Throw
        (New-UDPivotReport -Data @() -Theme Dark).theme | Should -Be 'dark'
        (New-UDPivotReport -Data @() -Height 640).height | Should -Be '640px'
        (New-UDPivotReport -Data @() -Height '70vh').height | Should -Be '70vh'
        (New-UDPivotReport -Data @() -Height 'calc(100vh - 120px)').height | Should -Be 'calc(100vh - 120px)'
        { New-UDPivotReport -Data @() -Height '640px; background: red' } | Should -Throw
        (New-UDPivotReport -Data @() -FieldDefaults @{ Hours = @{ Agg = 'average'; Format = 'number:1' } }).fieldDefaults.Hours.Format | Should -Be 'number:1'
        { New-UDPivotReport -Data @() -FieldDefaults @{ Hours = 'average' } } | Should -Throw '*Hours*'
        { New-UDPivotReport -Data @() -FieldDefaults @{ Hours = @{ Format = 'x(); alert(1)' } } } | Should -Throw '*Hours*'
        (New-UDPivotReport -Data @() -NoDrillDown).drillDown | Should -BeFalse
    }

    It 'registers every event under its own id' {
        $c = New-UDPivotReport -Id 'r' -Data @() -OnViewChange ([Endpoint]::new({ 1 })) -OnCellClick ([Endpoint]::new({ 2 })) -OnSaveTemplate ([Endpoint]::new({ 3 })) -OnDeleteTemplate ([Endpoint]::new({ 4 }))
        $c.onViewChange.RegisteredId | Should -Be 'r-onViewChange'
        $c.onCellClick.RegisteredId | Should -Be 'r-onCellClick'
        $c.onSaveTemplate.RegisteredId | Should -Be 'r-onSaveTemplate'
        $c.onDeleteTemplate.RegisteredId | Should -Be 'r-onDeleteTemplate'
    }

    It 'defaults -TimeZone to an IANA name of the server' {
        (New-UDPivotReport -Data @()).timeZone | Should -Match '^(UTC|[A-Za-z_]+(/[A-Za-z0-9_+-]+){1,2})$'
    }
}

Describe 'ConvertFrom-UDPivotView' {
    It 'keeps only the keys of a view, from JSON, a hashtable or an object' {
        $json = '{"version":1,"rows":["Team"],"cols":[],"values":[{"field":"Id","agg":"count"}],"display":"chart","chart":{"type":"bar"},"script":"x"}'
        $view = ConvertFrom-UDPivotView $json
        $view.PSObject.Properties.Name | Should -Be @('version', 'rows', 'cols', 'values', 'display', 'chart')
        $view.values[0].agg | Should -Be 'count'
        (ConvertFrom-UDPivotView @{ rows = @('A') }).rows | Should -Be @('A')
        (ConvertFrom-UDPivotView ([pscustomobject]@{ cols = @('B') })).cols | Should -Be @('B')
    }

    It 'keeps a one-element list a list' {
        $view = ConvertFrom-UDPivotView '{"rows":["Team"],"values":[{"field":"Id","agg":"sum"}]}'
        , $view.rows | Should -BeOfType [string[]]
        (ConvertFrom-UDPivotView $view -AsJson) | Should -Be '{"rows":["Team"],"values":[{"field":"Id","agg":"sum"}]}'
    }

    It 'returns compact JSON with -AsJson that reads back as the same view' {
        $json = ConvertFrom-UDPivotView @{ rows = @('Team'); filters = @(@{ field = 'Status'; type = 'include'; items = @('Open') }) } -AsJson
        $json | Should -Not -Match '\s{2}'
        (ConvertFrom-UDPivotView $json).filters[0].items | Should -Be @('Open')
    }

    It 'refuses input that is no view' {
        { ConvertFrom-UDPivotView 'not json' } | Should -Throw '*not valid JSON*'
        { ConvertFrom-UDPivotView '"text"' } | Should -Throw '*JSON object*'
        { ConvertFrom-UDPivotView '[]' } | Should -Throw '*JSON object*'
        { ConvertFrom-UDPivotView $null } | Should -Throw '*no view*'
        { ConvertFrom-UDPivotView '{"rows":[1]}' } | Should -Throw '*field names*'
        { ConvertFrom-UDPivotView '{"values":["Id"]}' } | Should -Throw '*object*'
        { ConvertFrom-UDPivotView '{"display":"grid"}' } | Should -Throw '*table*'
        { ConvertFrom-UDPivotView '{"totals":[]}' } | Should -Throw '*object*'
    }

    It 'limits size, list length and depth' {
        $long = '{"rows":["' + ('x' * 70000) + '"]}'
        { ConvertFrom-UDPivotView $long } | Should -Throw '*characters*'
        { ConvertFrom-UDPivotView $long -MaxLength 100000 } | Should -Throw '*field names*'
        $many = @{ rows = @(1..65 | ForEach-Object { "f$_" }) }
        { ConvertFrom-UDPivotView $many } | Should -Throw '*at most 64*'
        $deep = '{"chart":' + ('{"a":' * 10) + '1' + ('}' * 10) + '}'
        { ConvertFrom-UDPivotView $deep } | Should -Throw '*levels*'
    }

    It 'never evaluates what it gets' {
        $marker = Join-Path ([System.IO.Path]::GetTempPath()) ('pivot-test-{0}' -f [guid]::NewGuid().ToString('n'))
        $json = '{"rows":["$(New-Item -Path ''' + $marker.Replace('\', '\\') + ''')"]}'
        $view = ConvertFrom-UDPivotView $json
        $view.rows[0] | Should -BeLike '$(New-Item*'
        Test-Path -LiteralPath $marker | Should -BeFalse
    }
}

Describe 'The pivot module' {
    It 'has a manifest with the PowerShellUniversal tag and exports both commands' {
        $manifest = Import-PowerShellDataFile (Join-Path $script:repo 'modules' 'PowerShellUniversal.Component.Pivot' 'PowerShellUniversal.Component.Pivot.psd1')
        $manifest.PrivateData.PSData.Tags | Should -Contain 'PowerShellUniversal'
        $manifest.FunctionsToExport | Should -Be @('New-UDPivotReport', 'ConvertFrom-UDPivotView')
        $manifest.ModuleVersion | Should -Be '0.1.0'
    }

    It 'documents every parameter with an example' {
        foreach ($command in 'New-UDPivotReport', 'ConvertFrom-UDPivotView') {
            $help = Get-Help $command -Full
            @($help.examples.example).Count | Should -BeGreaterThan 0
            foreach ($p in $help.parameters.parameter) {
                ($p.description | Out-String).Trim() | Should -Not -BeNullOrEmpty -Because "$command -$($p.name)"
            }
        }
    }
}
