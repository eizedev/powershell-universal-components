#Requires -Version 7.4
# Pester tests for shared/powershell/ConvertTo-PSUComponentData.ps1, which every component module uses.
# The output must stay exactly what the original per-cell implementation returned (kept in Reference/
# as the oracle): the same rows, property names, value types, PSObject wrappers and JSON, for every kind
# of input the modules promise.

BeforeAll {
    # the implementation and the oracle each in a module of their own, as in a built component module:
    # every call and every change of their state goes into the module (& $module { ... })
    $script:repo = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $load = { param($Path) [scriptblock]::Create(('. ''{0}''; Export-ModuleMember' -f $Path)) }
    $script:subject = New-Module -Name ComponentDataSubject -ScriptBlock (& $load (Join-Path $script:repo 'shared' 'powershell' 'ConvertTo-PSUComponentData.ps1'))
    $script:reference = New-Module -Name ComponentDataReference -ScriptBlock (& $load (Join-Path $PSScriptRoot 'Reference' 'ConvertTo-PSUComponentData.ps1'))
    $script:convert = { param($Data) , (ConvertTo-PSUComponentData -InputObject $Data) }

    if (-not ('ComponentDataProbe' -as [type])) {
        # PowerShell unwraps a PSObject when it passes it to a .NET method, so only C# sees whether a
        # property holds the wrapper or the plain value (the serializer sees the difference too)
        Add-Type -TypeDefinition @'
public static class ComponentDataProbe {
    public static bool IsWrapped(System.Management.Automation.PSObject row, string name) {
        return row.Properties[name].Value is System.Management.Automation.PSObject;
    }
}
'@
    }

    function Get-Shape {
        # a text that differs whenever two outputs differ in anything a serializer can see
        param([AllowNull()][object]$Result)
        if ($null -eq $Result) { return 'null' }
        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add(('result {0} count {1}' -f $Result.GetType().FullName, @($Result).Count))
        foreach ($row in $Result) {
            $lines.Add(('row {0} [{1}]' -f $row.GetType().FullName, ($row.PSObject.TypeNames -join ', ')))
            foreach ($property in $row.PSObject.Properties) {
                $value = $property.Value
                $type = if ($null -eq $value) { 'null' } else { $value.GetType().FullName }
                $text = if ($value -is [double] -or $value -is [single]) { $value.ToString('R', [cultureinfo]::InvariantCulture) }
                elseif ($value -is [System.IFormattable]) { [string]::Format([cultureinfo]::InvariantCulture, '{0}', $value) }
                elseif ($value -is [array]) { 'array of {0}: {1}' -f $value.Count, (($value | ForEach-Object { if ($null -eq $_) { 'null' } else { '{0}:{1}' -f $_.GetType().Name, $_ } }) -join ',') }
                else { [string]$value }
                $lines.Add(('  {0} {1} {2} wrapped={3} = {4}' -f $property.Name, $property.MemberType, $type, [ComponentDataProbe]::IsWrapped($row, $property.Name), $text))
            }
        }
        $lines.Add((ConvertTo-Json -InputObject $Result -Depth 6 -Compress -WarningAction SilentlyContinue))
        $lines -join "`n"
    }

    function Get-TicketTable {
        # the pivot showcase's tickets: what a SQL query returns (dates, numbers, text, DBNull)
        param([int]$Count)
        $rng = [System.Random]::new(11)
        $table = [System.Data.DataTable]::new('Tickets')
        foreach ($column in @(@('Ticket', [int]), @('Created', [datetime]), @('Closed', [datetime]), @('Team', [string]),
                @('Agent', [string]), @('Lead hours', [double]), @('Cost', [decimal]), @('Reopened', [bool]))) {
            [void]$table.Columns.Add($column[0], $column[1])
        }
        $end = [datetime]'2026-10-31'
        foreach ($i in 1..$Count) {
            $created = $end.AddDays(-$rng.Next(0, 540)).AddMinutes($rng.Next(420, 1140))
            $closed = $rng.NextDouble() -lt 0.7
            $lead = [math]::Round(1 + $rng.NextDouble() * 40, 1)
            [void]$table.Rows.Add(40000 + $i, $created, $(if ($closed) { $created.AddHours($lead) } else { [DBNull]::Value }),
                @('Network', 'Server', 'Security')[$rng.Next(0, 3)], $(if ($rng.NextDouble() -lt 0.1) { [DBNull]::Value } else { 'Kim' }),
                $(if ($closed) { $lead } else { [DBNull]::Value }), [decimal][math]::Round(35 + $lead * 20, 2), ($rng.NextDouble() -lt 0.07))
        }
        , $table
    }

    function Get-AllTypesTable {
        # every column type a DataTable can carry, each with a value and with DBNull
        $table = [System.Data.DataTable]::new()
        $columns = [ordered]@{
            Text = [string]; Int = [int]; Long = [long]; Short = [int16]; Byte = [byte]; SByte = [sbyte]; UInt = [uint64]
            Double = [double]; Single = [single]; Decimal = [decimal]; Bool = [bool]; Char = [char]; Guid = [guid]
            Local = [datetime]; Utc = [datetime]; Plain = [datetime]; Offset = [datetimeoffset]; Span = [timespan]
            Bytes = [byte[]]; Day = [System.DayOfWeek]; Any = [object]
        }
        foreach ($name in $columns.Keys) { [void]$table.Columns.Add($name, $columns[$name]) }
        $anyValues = @(
            [datetime]::new(2026, 1, 2, 3, 4, 5, [System.DateTimeKind]::Utc), [timespan]::FromMinutes(90), [System.DayOfWeek]::Friday,
            @(1, 2), @(7), @(), [byte[]](1, 2, 3), @{ a = 1 }, [pscustomobject]@{ b = 2 }, 'text', 42, [DBNull]::Value,
            [System.Collections.Generic.List[int]]::new([int[]](4, 5)), [datetimeoffset]::new(2026, 5, 6, 7, 8, 9, [timespan]::FromHours(2)))
        foreach ($any in $anyValues) {
            [void]$table.Rows.Add('a', 1, 2L, [int16]3, [byte]4, [sbyte]-5, [uint64]6, 1.25, [single]2.5, 3.75d, $true, [char]'x',
                [guid]'d1c4e5f6-0000-4000-8000-000000000001',
                [datetime]::new(2026, 3, 4, 10, 30, 0, [System.DateTimeKind]::Local), [datetime]::new(2026, 3, 4, 10, 30, 0, [System.DateTimeKind]::Utc),
                [datetime]'2026-03-04 10:30:15.1234567', [datetimeoffset]::new(2026, 3, 4, 10, 30, 0, [timespan]::FromHours(-5)),
                [timespan]::FromSeconds(3725.5), [byte[]](9, 8), [System.DayOfWeek]::Monday, $any)
        }
        $nulls = @(foreach ($name in $columns.Keys) { [DBNull]::Value })
        [void]$table.Rows.Add($nulls)
        , $table
    }
}

Describe 'ConvertTo-PSUComponentData returns what the original implementation returned' {
    BeforeDiscovery {
        # name and a script block that builds the input (each implementation gets a fresh copy)
        $script:fixtures = @(
            @{ Name = 'null'; Build = { $null } }
            @{ Name = 'empty array'; Build = { , @() } }
            @{ Name = 'ticket DataTable (300 rows)'; Build = { Get-TicketTable -Count 300 } }
            @{ Name = 'DataTable with every column type'; Build = { Get-AllTypesTable } }
            @{ Name = 'DataTable with TimeSpan and DateTimeOffset columns'; Build = {
                    $t = [System.Data.DataTable]::new()
                    [void]$t.Columns.Add('Span', [timespan]); [void]$t.Columns.Add('Offset', [datetimeoffset]); [void]$t.Columns.Add('Id', [guid]); [void]$t.Columns.Add('F', [single])
                    [void]$t.Rows.Add([timespan]::FromMilliseconds(1500), [datetimeoffset]::new(2026, 3, 4, 10, 30, 0, [timespan]::FromHours(2)), [guid]::Empty, [single]0.1)
                    [void]$t.Rows.Add([DBNull]::Value, [DBNull]::Value, [DBNull]::Value, [DBNull]::Value); , $t
                }
            }
            @{ Name = 'empty DataView'; Build = { $v = [System.Data.DataView]::new((Get-TicketTable -Count 5)); $v.RowFilter = 'Ticket < 0'; , $v } }
            @{ Name = 'DataView with one row'; Build = { $v = [System.Data.DataView]::new((Get-TicketTable -Count 5)); $v.RowFilter = 'Ticket = 40003'; , $v } }
            @{ Name = 'empty DataTable'; Build = { $t = [System.Data.DataTable]::new(); [void]$t.Columns.Add('A'); , $t } }
            @{ Name = 'DataTable with case-different column names'; Build = {
                    $t = [System.Data.DataTable]::new(); $t.CaseSensitive = $true
                    [void]$t.Columns.Add('Name'); [void]$t.Columns.Add('name', [int]); [void]$t.Columns.Add('When', [datetime])
                    [void]$t.Rows.Add('a', 1, [datetime]'2026-01-01'); [void]$t.Rows.Add([DBNull]::Value, 2, [DBNull]::Value); , $t
                }
            }
            @{ Name = 'DataView with filter and sort'; Build = { $v = [System.Data.DataView]::new((Get-TicketTable -Count 50)); $v.RowFilter = 'Team = ''Server'''; $v.Sort = 'Cost DESC'; , $v } }
            @{ Name = 'DataRow array (Select)'; Build = { , (Get-TicketTable -Count 40).Select('Ticket > 40020') } }
            @{ Name = 'DataRowView array'; Build = { , @([System.Data.DataView]::new((Get-AllTypesTable)) | Select-Object -First 3) } }
            @{ Name = 'DataRows of two tables'; Build = { , @(@((Get-TicketTable -Count 3).Rows) + @((Get-AllTypesTable).Rows)) } }
            @{ Name = 'PSCustomObjects'; Build = {
                    , @(foreach ($i in 1..50) {
                            [pscustomobject]@{ Id = $i; Name = "n$i"; When = ([datetime]'2026-01-01').AddHours($i); Ok = ($i % 2 -eq 0); Cost = [decimal]$i / 3; Gone = $null; Db = [DBNull]::Value }
                        })
                }
            }
            @{ Name = 'PSCustomObjects with differing properties'; Build = { , @([pscustomobject]@{ A = 1 }, [pscustomobject]@{ B = 'x'; A = 2 }, [pscustomobject]@{ C = [datetimeoffset]'2026-01-01T00:00:00+01:00' }) } }
            @{ Name = 'Import-Csv'; Build = { , @("Name,Value,When`na,1,2026-01-01`nb,,`n" | ConvertFrom-Csv) } }
            @{ Name = 'ConvertFrom-Json (REST)'; Build = {
                    , @('[{"id":1,"when":"2026-01-01T10:00:00Z","n":null,"arr":[1,2],"one":[3],"none":[],"obj":{"x":1},"f":1.5,"big":12345678901,"b":true},{"id":2}]' | ConvertFrom-Json)
                }
            }
            @{ Name = 'Select-Object with calculated and wrapped values'; Build = {
                    , @(1..5 | ForEach-Object { [pscustomobject]@{ N = $_; T = "t$_" } } | Select-Object N, @{ n = 'Twice'; e = { $_.N * 2 } }, @{ n = 'When'; e = { ([datetime]'2026-02-03').AddDays($_.N) } }, @{ n = 'Text'; e = { $_.T } })
                }
            }
            @{ Name = 'objects with Add-Member and wrapped values'; Build = {
                    $o = [pscustomobject]@{ A = [psobject]5; B = ('x' | Add-Member -NotePropertyName q -NotePropertyValue 1 -PassThru); C = [psobject][datetime]'2026-01-01'; D = [psobject]@(1, 2) }
                    $o | Add-Member -MemberType ScriptProperty -Name Script -Value { 'computed' }
                    $o | Add-Member -MemberType AliasProperty -Name Alias -Value A
                    $o | Add-Member -MemberType ScriptMethod -Name Method -Value { 'never' }
                    , @($o)
                }
            }
            @{ Name = '.NET objects with properties'; Build = { , @([System.Version]'1.2.3.4', [System.Uri]'https://example.com/a?b=1', [System.Net.IPAddress]::Loopback) } }
            @{ Name = 'hashtables and ordered dictionaries'; Build = {
                    , @(@{ A = 1; B = [datetime]'2026-01-01'; C = [DBNull]::Value }, [ordered]@{ Z = 'z'; Y = $null; 5 = 'five'; Span = [timespan]::FromHours(1) },
                        [System.Collections.Generic.Dictionary[string, object]]::new())
                }
            }
            @{ Name = 'scalars'; Build = { , @(1, 'two', 3.5, [datetime]'2026-01-01', [guid]'d1c4e5f6-0000-4000-8000-000000000002', [System.DayOfWeek]::Sunday, [timespan]::FromSeconds(5), $true, [DBNull]::Value, $null) } }
            @{ Name = 'single object'; Build = { [pscustomobject]@{ A = 1; B = [datetime]'2026-01-01' } } }
            @{ Name = 'single DataRow'; Build = { (Get-AllTypesTable).Rows[0] } }
            @{ Name = 'script block'; Build = { { Get-TicketTable -Count 5 } } }
        )
    }

    # every DataTable once through the compiled converter (from the first row on) and once through
    # PowerShell alone; other inputs take the PowerShell path either way
    Context '<_> path' -ForEach 'compiled', 'PowerShell' {
        BeforeAll {
            $script:path = $_
            & $script:subject {
                param($Path)
                $Script:PSUComponentCompileMinRows = if ($Path -eq 'compiled') { 0 } else { 1000 }
                $Script:PSUComponentRowCompiled = if ($Path -eq 'compiled') { $null } else { $false }
            } $_
        }
        AfterAll {
            & $script:subject { $Script:PSUComponentCompileMinRows = 1000; $Script:PSUComponentRowCompiled = $null }
        }

        It '<Name>' -ForEach $script:fixtures {
            $expected = Get-Shape -Result (& $script:reference $script:convert (& $Build))
            $actual = Get-Shape -Result (& $script:subject $script:convert (& $Build))
            $actual | Should -BeExactly $expected
        }

        It 'took the <_> path' {
            $null = & $script:subject $script:convert (Get-TicketTable -Count 3)
            & $script:subject { $Script:PSUComponentRowCompiled } | Should -Be ($script:path -eq 'compiled')
        }
    }
}

Describe 'ConvertTo-PSUComponentData speed' {
    BeforeAll {
        $script:table = Get-TicketTable -Count 3000
        $script:objects = foreach ($row in $script:table.Rows) {
            [pscustomobject]@{ Ticket = $row['Ticket']; Created = $row['Created']; Team = $row['Team']; Cost = $row['Cost']; Reopened = $row['Reopened'] }
        }
        function Measure-Conversion {
            # the median of five runs, after one to warm up (the first call includes compiling the function)
            param([scriptblock]$Script)
            $null = & $Script
            $times = foreach ($i in 1..5) { (Measure-Command $Script).TotalMilliseconds }
            @($times | Sort-Object)[2]
        }
    }
    AfterAll { & $script:subject { $Script:PSUComponentRowCompiled = $null } }

    # The bounds compare with the per-cell original on the same machine, so a slow CI runner does not
    # matter; they only catch a return to a function call per cell (measured: about ten times faster in
    # PowerShell, forty times compiled).
    It 'converts a DataTable several times faster than the original, compiled and in PowerShell alone' {
        $original = Measure-Conversion { $null = & $script:reference $script:convert $script:table }
        & $script:subject { $Script:PSUComponentRowCompiled = $null }
        $compiled = Measure-Conversion { $null = & $script:subject $script:convert $script:table }
        & $script:subject { $Script:PSUComponentRowCompiled } | Should -BeTrue
        & $script:subject { $Script:PSUComponentRowCompiled = $false }
        $powershell = Measure-Conversion { $null = & $script:subject $script:convert $script:table }
        $because = 'original {0:n0} ms, compiled {1:n0} ms, PowerShell {2:n0} ms' -f $original, $compiled, $powershell
        $compiled * 5 | Should -BeLessThan $original -Because $because
        $powershell * 3 | Should -BeLessThan $original -Because $because
    }

    It 'converts PSCustomObjects several times faster than the original' {
        $original = Measure-Conversion { $null = & $script:reference $script:convert $script:objects }
        $fast = Measure-Conversion { $null = & $script:subject $script:convert $script:objects }
        $fast * 3 | Should -BeLessThan $original -Because ('original {0:n0} ms, new {1:n0} ms' -f $original, $fast)
    }
}
