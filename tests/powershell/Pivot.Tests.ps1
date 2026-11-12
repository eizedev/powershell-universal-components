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
        $c.addressBar | Should -BeTrue
        (New-UDPivotReport -Id 'p2' -Data $rows -NoAddressBar).addressBar | Should -BeFalse
        foreach ($key in 'view', 'savedView', 'templates', 'height', 'labels', 'fieldDefaults', 'onViewChange', 'onCellClick', 'onSaveTemplate', 'onDeleteTemplate', 'allowImport', 'onDataLoad', 'importLimits', 'limits') {
            $c.ContainsKey($key) | Should -BeFalse -Because "$key was not passed"
        }
    }

    It '-AllowImport: sent as allowImport, also on an empty report; -OnDataLoad registered under its own id and only with -AllowImport' {
        $c = New-UDPivotReport -Id 'own' -Data @() -AllowImport -OnDataLoad ([Endpoint]::new({ 5 }))
        $c.allowImport | Should -BeTrue
        @($c.data).Count | Should -Be 0
        $c.onDataLoad.RegisteredId | Should -Be 'own-onDataLoad'
        (New-UDPivotReport -Id 'own2' -Data $null -AllowImport).allowImport | Should -BeTrue
        { New-UDPivotReport -Id 'own3' -Data @() -OnDataLoad ([Endpoint]::new({ 5 })) } | Should -Throw '*-OnDataLoad needs -AllowImport*'
    }

    It '-ImportLimit: pivotkit''s key names in any case, whole numbers, sent as importLimits (never limits); only with -AllowImport' {
        $c = New-UDPivotReport -Id 'own' -Data @() -AllowImport -ImportLimit @{ FILEBYTES = 250MB; rows = 2000000; importcells = 2e7; UnpackedBytes = 1GB; textlength = 100; archiveEntries = 50 }
        # the JSON PSU sends: pivotkit's spelling and order, numbers, only the keys given
        $c.importLimits | ConvertTo-Json -Compress | Should -Be '{"fileBytes":262144000,"rows":2000000,"importCells":20000000,"textLength":100,"archiveEntries":50,"unpackedBytes":1073741824}'
        # the app's data keeps pivotkit's limits
        $c.ContainsKey('limits') | Should -BeFalse
        (New-UDPivotReport -Id 'own2' -Data @() -AllowImport -ImportLimit @{ columns = 5GB }).importLimits.columns | Should -Be 5368709120
        (New-UDPivotReport -Id 'own3' -Data @() -AllowImport -ImportLimit @{ rows = 9007199254740991 }).importLimits.rows | Should -Be 9007199254740991
        # an empty hashtable changes nothing
        (New-UDPivotReport -Id 'own4' -Data @() -AllowImport -ImportLimit @{}).ContainsKey('importLimits') | Should -BeFalse
        { New-UDPivotReport -Id 'x' -Data @() -AllowImport -ImportLimit @{ groups = 5 } } | Should -Throw '*unknown limit "groups"*fileBytes, rows, columns, importCells, textLength, archiveEntries, unpackedBytes*'
        { New-UDPivotReport -Id 'x' -Data @() -AllowImport -ImportLimit @{ cells = 5 } } | Should -Throw '*unknown limit "cells"*'
        foreach ($bad in 0, -1, 2.5, '100', $true, $null, 9007199254740992, [double]::NaN, [double]::PositiveInfinity) {
            { New-UDPivotReport -Id 'x' -Data @() -AllowImport -ImportLimit @{ rows = $bad } } | Should -Throw '*rows must be a whole number*' -Because "rows = $bad"
        }
        # a case-sensitive dictionary can hold one limit twice
        $twice = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
        $twice['rows'] = 5
        $twice['ROWS'] = 6
        { New-UDPivotReport -Id 'x' -Data @() -AllowImport -ImportLimit $twice } | Should -Throw '*rows is given twice*'
        { New-UDPivotReport -Id 'x' -Data @() -ImportLimit @{ rows = 5 } } | Should -Throw '*-ImportLimit needs -AllowImport*'
    }

    It '-SavedView: checked like -View, sent as savedView; a broken one is left out with a warning' {
        $rows = @([pscustomobject]@{ Team = 'Ops'; Priority = 'High' })
        $c = New-UDPivotReport -Id 'p1' -Data $rows -View @{ rows = @('Team') } -SavedView '{"rows":["Priority"],"evil":"x"}'
        $c.savedView.rows | Should -Be @('Priority')
        $c.savedView.PSObject.Properties.Name | Should -Not -Contain 'evil'
        $c.view.rows | Should -Be @('Team')
        (New-UDPivotReport -Id 'p1' -Data $rows -SavedView $null).ContainsKey('savedView') | Should -BeFalse
        $broken = New-UDPivotReport -Id 'p1' -Data $rows -SavedView '{not json' -WarningVariable warned -WarningAction SilentlyContinue
        $broken.ContainsKey('savedView') | Should -BeFalse
        "$warned" | Should -Match '-SavedView left out'
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
        ((New-UDPivotReport -Data @() -FieldDefaults @{ Hours = @{ Agg = 'average'; Format = 'number:1' } }).fieldDefaults | ConvertFrom-Json).Hours.format | Should -Be 'number:1'
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

Describe 'New-UDPivotReport: fields, schema, chart options and tips' {
    BeforeAll {
        $script:rows = @([pscustomobject]@{ LeadHours = 2.5; Priority = 'High' })
        # the props travel as JSON text; this is what the browser parses
        $script:defaultsOf = { param($Component) $Component.fieldDefaults | ConvertFrom-Json -AsHashtable }
    }

    It '-FieldDefaults: every key in pivotkit''s name, the field names as given, as JSON text' {
        $c = New-UDPivotReport -Data $rows -FieldDefaults @{
            LeadHours = @{ Agg = 'average'; Format = 'number:1'; DrillFormat = 'text'; Label = 'Lead time'; Description = 'Hours to resolve'; Href = 'https://wiki.example.org/lead'; Type = 'number' }
            Priority  = [pscustomobject]@{ Order = @('Low', 'Normal', 'High') }
        }
        $c.fieldDefaults | Should -BeOfType [string]
        $d = & $defaultsOf $c
        $d.LeadHours.Keys | Sort-Object | Should -Be @('agg', 'description', 'drillFormat', 'format', 'href', 'label', 'type')
        $d.LeadHours.label | Should -Be 'Lead time'
        $d.LeadHours.href | Should -Be 'https://wiki.example.org/lead'
        $d.Priority.order | Should -Be @('Low', 'Normal', 'High')
    }

    It '-FieldDefaults: refuses unknown keys, non-text, links that are not https, wrong types and orders' {
        { New-UDPivotReport -Data $rows -FieldDefaults @{ A = @{ Colour = 'red' } } } | Should -Throw '*unknown key "Colour"*'
        { New-UDPivotReport -Data $rows -FieldDefaults @{ A = @{ Label = 42 } } } | Should -Throw '*Label must be text*'
        { New-UDPivotReport -Data $rows -FieldDefaults @{ A = @{ Description = @('x') } } } | Should -Throw '*Description must be text*'
        foreach ($href in 'http://example.org', 'javascript:alert(1)', 'https://user:pw@example.org/', '/relative', ('https://example.org/' + ('a' * 2000))) {
            { New-UDPivotReport -Data $rows -FieldDefaults @{ A = @{ Href = $href } } } | Should -Throw '*https*' -Because $href
        }
        { New-UDPivotReport -Data $rows -FieldDefaults @{ A = @{ Type = 'object' } } } | Should -Throw '*Type*'
        { New-UDPivotReport -Data $rows -FieldDefaults @{ A = @{ Order = @(@{ x = 1 }) } } } | Should -Throw '*Order*'
        { New-UDPivotReport -Data $rows -FieldDefaults @{ A = @{ Order = 1..1001 } } } | Should -Throw '*1000*'
        { New-UDPivotReport -Data $rows -FieldDefaults @{ ('x' * 257) = @{ Label = 'x' } } } | Should -Throw '*field names*'
    }

    It 'cuts labels and descriptions to pivotkit''s caps' {
        $d = & $defaultsOf (New-UDPivotReport -Data $rows -FieldDefaults @{ A = @{ Label = 'L' * 500; Description = 'D' * 5000 } })
        $d.A.label.Length | Should -Be 120
        $d.A.label | Should -BeLike ('*' + [char]0x2026)
        $d.A.description.Length | Should -Be 1000
    }

    It '-FieldDescriptions: adds descriptions, a Description of -FieldDefaults wins, case-insensitive; empty, null and DBNull left out' {
        $descriptions = [ordered]@{ leadhours = 'From SQL'; Priority = 'How urgent'; Empty = ''; Null = $null; Db = [System.DBNull]::Value }
        $d = & $defaultsOf (New-UDPivotReport -Data $rows -FieldDescriptions $descriptions -FieldDefaults @{ LeadHours = @{ Description = 'Own text'; Agg = 'average' } })
        $d.Keys | Sort-Object | Should -Be @('LeadHours', 'Priority')
        $d.LeadHours.description | Should -Be 'Own text'
        $d.Priority.description | Should -Be 'How urgent'
        { New-UDPivotReport -Data $rows -FieldDescriptions @{ A = 1 } } | Should -Throw '*must be text*'
        (New-UDPivotReport -Data $rows -FieldDescriptions @{ A = '' }).ContainsKey('fieldDefaults') | Should -BeFalse
    }

    It '-Schema: a hashtable, JSON, a file; the text keeps its names; -SchemaName goes along' {
        $schema = @{ openapi = '3.0.3'; components = @{ schemas = @{ Ticket = @{ properties = @{ LeadHours = @{ title = 'Lead time' } } } } } }
        $c = New-UDPivotReport -Data $rows -Schema $schema -SchemaName 'Ticket'
        $c.schema | Should -BeOfType [string]
        ($c.schema | ConvertFrom-Json -AsHashtable).components.schemas.Ticket.properties.LeadHours.title | Should -Be 'Lead time'
        $c.schemaName | Should -Be 'Ticket'
        (New-UDPivotReport -Data $rows -Schema ' {"properties":{"A":{}}} ').schema | Should -Be '{"properties":{"A":{}}}'
        $file = Join-Path $TestDrive 'schema.json'
        Set-Content -LiteralPath $file -Value '{"properties":{"A":{"description":"from a file"}}}' -Encoding utf8
        (New-UDPivotReport -Data $rows -Schema $file).schema | Should -Match 'from a file'
    }

    It '-Schema: refuses what is no JSON object, too large, too deep, other address schemes and missing files' {
        { New-UDPivotReport -Data $rows -Schema '{"a":' } | Should -Throw '*-Schema: not valid JSON*'
        { New-UDPivotReport -Data $rows -Schema (Join-Path $TestDrive 'missing.json') } | Should -Throw '*no file*'
        { New-UDPivotReport -Data $rows -Schema 'http://example.org/openapi.json' } | Should -Throw '*only https*'
        { New-UDPivotReport -Data $rows -Schema 'file:///etc/passwd' } | Should -Throw '*only https*'
        { New-UDPivotReport -Data $rows -Schema ('{"a":"' + ('x' * 1MB) + '"}') } | Should -Throw '*more than*'
        { New-UDPivotReport -Data $rows -Schema (('{"a":' * 70) + '1' + ('}' * 70)) } | Should -Throw '*64 levels*'
        $array = Join-Path $TestDrive 'array.json'
        Set-Content -LiteralPath $array -Value '[1,2]'
        { New-UDPivotReport -Data $rows -Schema $array } | Should -Throw '*JSON object*'
        { New-UDPivotReport -Data $rows -SchemaName 'Ticket' } | Should -Throw '*needs -Schema*'
    }

    It '-Schema: an https URL is fetched once and kept per runspace' {
        & $script:module {
            $Script:SchemaCache['https://schemas.example.invalid/openapi.json'] = @{ Text = '{"properties":{}}'; Time = [datetime]::UtcNow }
        }
        (New-UDPivotReport -Data $rows -Schema 'https://schemas.example.invalid/openapi.json').schema | Should -Be '{"properties":{}}'
        # an outdated entry is fetched again; the address does not resolve, so the error names it
        & $script:module { $Script:SchemaCache['https://schemas.example.invalid/openapi.json'].Time = [datetime]::UtcNow.AddHours(-1) }
        { New-UDPivotReport -Data $rows -Schema 'https://schemas.example.invalid/openapi.json' } | Should -Throw '*could not be read*'
    }

    It '-ChartOptions: JSON text from a hashtable or JSON, capped' {
        $c = New-UDPivotReport -Data $rows -ChartOptions @{ legend = @{ top = 0 }; xAxis = @{ axisLabel = @{ rotate = 30 } } }
        ($c.chartOptions | ConvertFrom-Json).xAxis.axisLabel.rotate | Should -Be 30
        (New-UDPivotReport -Data $rows -ChartOptions '{"grid":{"left":80}}').chartOptions | Should -Be '{"grid":{"left":80}}'
        { New-UDPivotReport -Data $rows -ChartOptions '[1]' } | Should -Throw '*JSON object*'
        { New-UDPivotReport -Data $rows -ChartOptions @{ a = 'x' * 70000 } } | Should -Throw '*more than*'
    }

    It '-Tips, -FieldInfo, -ZoneInfo and -Label' {
        (New-UDPivotReport -Data $rows -Tips Off).tips | Should -Be 'off'
        (New-UDPivotReport -Data $rows -Tips values, chartSeries).tips | Should -Be @('values', 'chartSeries')
        { New-UDPivotReport -Data $rows -Tips On, values } | Should -Throw '*alone*'
        { New-UDPivotReport -Data $rows -Tips 'a b' } | Should -Throw
        $c = New-UDPivotReport -Data $rows -FieldInfo Off -ZoneInfo On -Label 'Tickets per team'
        $c.fieldInfo | Should -Be 'off'
        $c.zoneInfo | Should -Be 'on'
        $c.label | Should -Be 'Tickets per team'
        foreach ($key in 'tips', 'fieldInfo', 'zoneInfo', 'label', 'schema', 'chartOptions') {
            (New-UDPivotReport -Data $rows).ContainsKey($key) | Should -BeFalse -Because "$key was not passed"
        }
    }
}

Describe 'Get-UDPivotSqlColumnDescription' {
    BeforeAll {
        # a stand-in ADO.NET connection: records the command, answers with a DataTable
        if (-not ('PivotTest.FakeConnection' -as [type])) {
            Add-Type -ReferencedAssemblies System.Data.Common, System.Data, System.ComponentModel.Primitives, System.ComponentModel.TypeConverter, System.Collections, System.Linq -TypeDefinition @'
using System.Data;
using System.Data.Common;
namespace PivotTest {
    public class FakeParameter : DbParameter {
        public override DbType DbType { get; set; }
        public override ParameterDirection Direction { get; set; }
        public override bool IsNullable { get; set; }
        public override string ParameterName { get; set; }
        public override string SourceColumn { get; set; }
        public override object Value { get; set; }
        public override bool SourceColumnNullMapping { get; set; }
        public override int Size { get; set; }
        public override void ResetDbType() { }
    }
    public class FakeParameters : DbParameterCollection {
        public System.Collections.Generic.List<DbParameter> Items = new System.Collections.Generic.List<DbParameter>();
        public override int Count { get { return Items.Count; } }
        public override object SyncRoot { get { return this; } }
        public override int Add(object value) { Items.Add((DbParameter)value); return Items.Count - 1; }
        public override void AddRange(System.Array values) { foreach (object v in values) Add(v); }
        public override void Clear() { Items.Clear(); }
        public override bool Contains(object value) { return Items.Contains((DbParameter)value); }
        public override bool Contains(string value) { return IndexOf(value) >= 0; }
        public override void CopyTo(System.Array array, int index) { }
        public override System.Collections.IEnumerator GetEnumerator() { return Items.GetEnumerator(); }
        public override int IndexOf(object value) { return Items.IndexOf((DbParameter)value); }
        public override int IndexOf(string name) { return Items.FindIndex(p => p.ParameterName == name); }
        public override void Insert(int index, object value) { Items.Insert(index, (DbParameter)value); }
        public override void Remove(object value) { Items.Remove((DbParameter)value); }
        public override void RemoveAt(int index) { Items.RemoveAt(index); }
        public override void RemoveAt(string name) { Items.RemoveAt(IndexOf(name)); }
        protected override DbParameter GetParameter(int index) { return Items[index]; }
        protected override DbParameter GetParameter(string name) { return Items[IndexOf(name)]; }
        protected override void SetParameter(int index, DbParameter value) { Items[index] = value; }
        protected override void SetParameter(string name, DbParameter value) { Items[IndexOf(name)] = value; }
    }
    public class FakeCommand : DbCommand {
        public FakeConnection Owner;
        public FakeParameters Params = new FakeParameters();
        public override string CommandText { get; set; }
        public override int CommandTimeout { get; set; }
        public override CommandType CommandType { get; set; }
        public override bool DesignTimeVisible { get; set; }
        public override UpdateRowSource UpdatedRowSource { get; set; }
        protected override DbConnection DbConnection { get; set; }
        protected override DbParameterCollection DbParameterCollection { get { return Params; } }
        protected override DbTransaction DbTransaction { get; set; }
        public override void Cancel() { }
        public override int ExecuteNonQuery() { return 0; }
        public override object ExecuteScalar() { return null; }
        public override void Prepare() { }
        protected override DbParameter CreateDbParameter() { return new FakeParameter(); }
        protected override DbDataReader ExecuteDbDataReader(CommandBehavior behavior) { Owner.Last = this; return Owner.Answer.CreateDataReader(); }
    }
    public class FakeConnection : DbConnection {
        public DataTable Answer;
        public FakeCommand Last;
        public bool WasDisposed;
        public override string ConnectionString { get; set; }
        public override string Database { get { return "test"; } }
        public override string DataSource { get { return "test"; } }
        public override string ServerVersion { get { return "16.0"; } }
        public override ConnectionState State { get { return ConnectionState.Open; } }
        protected override DbTransaction BeginDbTransaction(IsolationLevel level) { return null; }
        public override void ChangeDatabase(string name) { }
        public override void Close() { }
        public override void Open() { }
        protected override DbCommand CreateDbCommand() { return new FakeCommand { Owner = this }; }
        protected override void Dispose(bool disposing) { WasDisposed = true; base.Dispose(disposing); }
    }
}
'@
        }
    }

    It 'asks sys.extended_properties with the table as a parameter and returns column to description in order' {
        $answer = [System.Data.DataTable]::new()
        [void]$answer.Columns.Add('ColumnName', [string])
        [void]$answer.Columns.Add('Description', [string])
        [void]$answer.Rows.Add('TicketId', 'Number of the ticket')
        [void]$answer.Rows.Add('Team', [System.DBNull]::Value)
        [void]$answer.Rows.Add('LeadHours', 'Hours from created to resolved')
        $connection = [PivotTest.FakeConnection]@{ Answer = $answer }
        $result = Get-UDPivotSqlColumnDescription -Connection $connection -Table "dbo.Tickets'; DROP TABLE x;--"
        $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
        @($result.Keys) | Should -Be @('TicketId', 'LeadHours')
        $result.LeadHours | Should -Be 'Hours from created to resolved'
        $command = $connection.Last
        $command.CommandText | Should -Match 'FROM sys\.columns AS c'
        $command.CommandText | Should -Match 'ep\.class = 1 AND ep\.major_id = c\.object_id AND ep\.minor_id = c\.column_id AND ep\.name = @Name'
        $command.CommandText | Should -Match 'OBJECT_ID\(@Table\)'
        $command.CommandText | Should -Not -Match 'DROP'
        ($command.Params.Items | Where-Object ParameterName -EQ '@Table').Value | Should -Be "dbo.Tickets'; DROP TABLE x;--"
        ($command.Params.Items | Where-Object ParameterName -EQ '@Name').Value | Should -Be 'MS_Description'
        $command.CommandTimeout | Should -Be 30
        # a connection the caller passed stays open
        $connection.WasDisposed | Should -BeFalse
    }

    It 'feeds -FieldDescriptions as it is' {
        $answer = [System.Data.DataTable]::new()
        [void]$answer.Columns.Add('ColumnName', [string])
        [void]$answer.Columns.Add('Description', [string])
        [void]$answer.Rows.Add('LeadHours', 'Hours')
        $descriptions = Get-UDPivotSqlColumnDescription -Connection ([PivotTest.FakeConnection]@{ Answer = $answer }) -Table 'Tickets' -PropertyName 'Caption'
        $d = (New-UDPivotReport -Data @([pscustomobject]@{ LeadHours = 1 }) -FieldDescriptions $descriptions).fieldDefaults | ConvertFrom-Json
        $d.LeadHours.description | Should -Be 'Hours'
    }

    It 'reports a connection string that does not reach a server, with the client it used' {
        { Get-UDPivotSqlColumnDescription -ConnectionString 'Server=tcp:127.0.0.1,1;Database=x;Integrated Security=false;User ID=x;Password=x;Connect Timeout=1' -Table 'dbo.T' } | Should -Throw
    }
}

Describe 'New-UDPivotReportPlaceholder' {
    It 'returns the plugin hashtable for ud-pivot-placeholder with the defaults' {
        $c = New-UDPivotReportPlaceholder -Id 'wait'
        $c.type | Should -Be 'ud-pivot-placeholder'
        $c.assetId | Should -Be 'asset-under-test'
        $c.isPlugin | Should -BeTrue
        $c.id | Should -Be 'wait'
        $c.theme | Should -Be 'auto'
        $c.locale | Should -Be 'en-US'
        foreach ($key in 'height', 'className', 'style') { $c.ContainsKey($key) | Should -BeFalse -Because "$key was not passed" }
    }

    It 'takes -Height, -Theme and -Locale as New-UDPivotReport does' {
        $placeholder = New-UDPivotReportPlaceholder -Height 640 -Theme Dark -Locale de-DE -ClassName 'x' -Style @{ maxWidth = '900px' }
        $report = New-UDPivotReport -Data @() -Height 640 -Theme Dark -Locale de-DE
        foreach ($key in 'height', 'theme', 'locale') { $placeholder[$key] | Should -Be $report[$key] }
        $placeholder.className | Should -Be 'x'
        $placeholder.style.maxWidth | Should -Be '900px'
        (New-UDPivotReportPlaceholder -Height 'clamp(400px, 60vh, 900px)').height | Should -Be 'clamp(400px, 60vh, 900px)'
        { New-UDPivotReportPlaceholder -Height '640px; background: red' } | Should -Throw '*Height*'
        { New-UDPivotReportPlaceholder -Locale 'de_DE;x' } | Should -Throw '*Locale*'
        { New-UDPivotReportPlaceholder -Theme Blue } | Should -Throw
        (New-UDPivotReportPlaceholder -Label 'Tickets').label | Should -Be 'Tickets'
    }

    It 'refuses to run without the bundle, like the report' {
        $saved = & $script:module { $Script:AssetId }
        try {
            & $script:module { $Script:AssetId = $null }
            { New-UDPivotReportPlaceholder } | Should -Throw '*bundle*'
        }
        finally { & $script:module { param($Id) $Script:AssetId = $Id } $saved }
    }
}

Describe 'The pivot module' {
    It 'has a manifest with the PowerShellUniversal tag and exports its commands' {
        $manifest = Import-PowerShellDataFile (Join-Path $script:repo 'modules' 'PowerShellUniversal.Component.Pivot' 'PowerShellUniversal.Component.Pivot.psd1')
        $manifest.PrivateData.PSData.Tags | Should -Contain 'PowerShellUniversal'
        $manifest.FunctionsToExport | Should -Be @('New-UDPivotReport', 'New-UDPivotReportPlaceholder', 'ConvertFrom-UDPivotView', 'ConvertFrom-UDPivotViewFile', 'ConvertTo-UDPivotViewFile', 'New-UDPivotFileTemplateStore', 'New-UDPivotTemplateStore', 'Invoke-UDPivotTemplateRequest', 'Get-UDPivotSqlColumnDescription')
        (Get-Command -Module $script:module.Name).Name | Sort-Object | Should -Be ($manifest.FunctionsToExport | Sort-Object)
        $manifest.ModuleVersion | Should -Be '0.4.0'
    }

    It 'documents every parameter with an example' {
        $manifest = Import-PowerShellDataFile (Join-Path $script:repo 'modules' 'PowerShellUniversal.Component.Pivot' 'PowerShellUniversal.Component.Pivot.psd1')
        foreach ($command in $manifest.FunctionsToExport) {
            $help = Get-Help $command -Full
            @($help.examples.example).Count | Should -BeGreaterThan 0
            foreach ($p in $help.parameters.parameter) {
                ($p.description | Out-String).Trim() | Should -Not -BeNullOrEmpty -Because "$command -$($p.name)"
            }
        }
    }
}
