#Requires -Version 7.4
# Pester tests for Invoke-UDPivotReport: the engines against a stand-in command line (a Node script
# that records what it got) and a stand-in pivotkit-server and token endpoint (an HttpListener on
# loopback), so CI needs neither pivotkit nor a network. With PIVOTKIT_TEST_CLI=1 the Node engine also
# runs the installed pivotkit; with PIVOTKIT_TEST_URL and PIVOTKIT_TEST_TOKEN the REST engine also runs
# against a real pivotkit-server whose caller may send data (policy.data or a profile's data: true).

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

    $script:rows = foreach ($i in 1..6) { [pscustomobject]@{ Team = 'T{0}' -f ($i % 2); Hours = $i * 1.5; Created = [datetime]::new(2026, 1, $i, 8, 0, 0, [DateTimeKind]::Utc) } }
    $script:view = @{ rows = @('Team'); values = @(@{ field = 'Hours'; agg = 'sum' }) }

    # a stand-in for pivotkit's command line: records its arguments, the data and the view it was given,
    # writes the -o file and answers as --json does; FAKE_PIVOTKIT_MODE picks a findings answer
    $script:fakeCli = Join-Path $TestDrive 'fake-pivotkit.js'
    Set-Content -LiteralPath $script:fakeCli -Encoding utf8NoBOM -Value @'
const fs = require("node:fs");
const path = require("node:path");
const args = process.argv.slice(2);
// the module passes every value as --option=value
const at = (flag) => { const a = args.find((x) => x.startsWith(flag + "=")); return a === undefined ? undefined : a.slice(flag.length + 1); };
const record = { args, cwdTmp: path.dirname(at("--output")), mode: fs.statSync(path.dirname(at("--output"))).mode & 0o777 };
const dataPath = at("--data") ?? args[1];
record.data = JSON.parse(fs.readFileSync(dataPath, "utf8"));
if (at("--data")) record.view = JSON.parse(fs.readFileSync(args[1], "utf8"));
fs.writeFileSync(process.env.FAKE_PIVOTKIT_RECORD, JSON.stringify(record));
const mode = process.env.FAKE_PIVOTKIT_MODE || "ok";
if (mode === "errors") {
    console.log(JSON.stringify({ ok: false, exitCode: 1, command: "render", findings: [{ severity: "error", code: "unknownField", path: "rows[0]", message: "unknown field \"Taem\"", suggestion: "Team" }], output: null }));
    process.exit(1);
}
if (mode === "usage") {
    console.log(JSON.stringify({ ok: false, exitCode: 2, command: "render", findings: [], error: { kind: "limit", code: "LIMIT_EXCEEDED", message: "too many rows" } }));
    process.exit(2);
}
if (mode === "nojson") { console.error("pivotkit: unknown option --allow-dir"); process.exit(2); }
fs.writeFileSync(at("--output"), "report:" + at("--format"));
console.log(JSON.stringify({ ok: true, exitCode: 0, command: "render", findings: [{ severity: "warning", code: "noRowsKept", path: "", message: "the filters keep no row" }, { severity: "info", code: "ENCODING", path: "", message: "read as UTF-8" }], output: { file: at("--output"), format: at("--format") } }));
'@
    $script:record = Join-Path $TestDrive 'record.json'
    $env:FAKE_PIVOTKIT_RECORD = $script:record
    function Get-Record { Get-Content -LiteralPath $script:record -Raw | ConvertFrom-Json -Depth 16 }

    # a stand-in pivotkit-server and OAuth token endpoint on loopback. $mock.Render and $mock.Token are
    # queues of answers @{ Status; Body; Headers } (empty: the default answer); $mock.Log has every
    # request: Path, Authorization, Body
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start(); $port = $listener.LocalEndpoint.Port; $listener.Stop()
    $script:base = 'http://127.0.0.1:{0}' -f $port
    $base = $script:base
    $script:mock = [hashtable]::Synchronized(@{
            Render = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
            Token  = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
            Log    = [System.Collections.Concurrent.ConcurrentQueue[pscustomobject]]::new()
            Issued = 0
            Valid  = [System.Collections.Concurrent.ConcurrentDictionary[string, bool]]::new()
        })
    $mock = $script:mock
    $script:mock.Valid['static-token-0123456789'] = $true
    $script:server = Start-ThreadJob -ScriptBlock {
        $Base = $using:base
        $Mock = $using:mock
        $http = [System.Net.HttpListener]::new()
        $http.Prefixes.Add($Base + '/')
        # the same server by another name, for the token cache's per-server test
        $http.Prefixes.Add($Base.Replace('127.0.0.1', 'localhost') + '/')
        $http.Start()
        # AfterAll stops it through $Mock.Http: GetContext then throws and the loop ends
        $Mock.Http = $http
        while ($http.IsListening) {
            try { $context = $http.GetContext() } catch { break }
            $request = $context.Request
            $reader = [System.IO.StreamReader]::new($request.InputStream, [System.Text.Encoding]::UTF8)
            $body = $reader.ReadToEnd()
            $auth = $request.Headers['Authorization']
            $Mock.Log.Enqueue([pscustomobject]@{ Path = $request.Url.AbsolutePath; Authorization = $auth; Body = $body; ContentType = $request.ContentType })
            $answer = $null
            if ($request.Url.AbsolutePath -eq '/token') {
                if (-not $Mock.Token.TryDequeue([ref]$answer)) {
                    $Mock.Issued++
                    $token = 'oauth-token-{0}' -f $Mock.Issued
                    $Mock.Valid[$token] = $true
                    $answer = @{ Status = 200; Body = (@{ access_token = $token; token_type = 'Bearer'; expires_in = 3600 } | ConvertTo-Json) }
                }
            }
            elseif ($request.Url.AbsolutePath -eq '/api/v1/views/render/file') {
                if (-not $Mock.Render.TryDequeue([ref]$answer)) {
                    $ok = $auth -and $auth.StartsWith('Bearer ') -and $Mock.Valid.ContainsKey($auth.Substring(7))
                    $answer = if ($ok) { @{ Status = 200; Body = 'Team,Sum of Hours'; Headers = @{ 'Content-Type' = 'text/csv;charset=utf-8' } } }
                    else { @{ Status = 401; Body = '{"type":"x","title":"Unauthorized","status":401,"code":"INVALID_TOKEN","detail":"unknown token","requestId":"r1"}' } }
                }
            }
            else { $answer = @{ Status = 404; Body = '' } }
            $response = $context.Response
            $response.StatusCode = $answer.Status
            if ($answer.Headers) { foreach ($k in $answer.Headers.Keys) { $response.Headers[$k] = $answer.Headers[$k] } }
            $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$answer.Body)
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.Close()
        }
    }
    # wait until it answers
    foreach ($i in 1..50) {
        if ($script:mock.Http) { break }
        Start-Sleep -Milliseconds 100
    }
    foreach ($i in 1..50) {
        try { $null = Invoke-WebRequest -Uri ($script:base + '/ping') -SkipHttpErrorCheck -TimeoutSec 2; break } catch { Start-Sleep -Milliseconds 100 }
    }
    # the table as Write-UDPivotReportTable writes it into a request, as JSON text
    function ConvertTo-TableJson {
        [CmdletBinding()]
        param([AllowNull()][AllowEmptyCollection()][object]$Data, [long]$MaxBytes = 0)
        & $script:module {
            param($d, $max, $warn)
            $WarningPreference = $warn
            $memory = [System.IO.MemoryStream]::new()
            $writer = New-UDPivotJsonWriter -Stream $memory
            $writer.WriteStartObject()
            Write-UDPivotReportTable -Writer $writer -Data $d -MaxBytes $max -RowCount
            $writer.WriteEndObject()
            $writer.Flush()
            [System.Text.Encoding]::UTF8.GetString($memory.ToArray())
        } $Data $MaxBytes $WarningPreference
    }
    # writes -Data into a fresh writer with -MaxBytes; the bytes the writer held when it stopped, the
    # error id, and which writer wrote (Compiled or PowerShell)
    function Get-StopPoint {
        [CmdletBinding()]
        param([AllowNull()][object]$Data, [long]$MaxBytes)
        & $script:module {
            param($d, $max)
            $memory = [System.IO.MemoryStream]::new()
            $writer = New-UDPivotJsonWriter -Stream $memory
            $writer.WriteStartObject()
            $id = $null
            try { Write-UDPivotReportTable -Writer $writer -Data $d -MaxBytes $max } catch { $id = $_.FullyQualifiedErrorId }
            [pscustomobject]@{ Bytes = $writer.BytesCommitted + $writer.BytesPending; Error = $id; Writer = $Script:LastTableWriter }
        } $Data $MaxBytes
    }
    function Get-Log { $out = @(); $item = $null; while ($script:mock.Log.TryDequeue([ref]$item)) { $out += $item }; $out }
    $script:rest = @{ Engine = 'Rest'; Uri = $script:base + '/api/v1' }
    $script:clientSecret = 'client-secret-that-must-not-leak'
    $script:client = [pscredential]::new('pivot-psu', [System.Net.NetworkCredential]::new('', $script:clientSecret).SecurePassword)
}

AfterAll {
    if ($script:mock.Http) { $script:mock.Http.Stop() }
    if ($script:server) { Stop-Job $script:server -ErrorAction SilentlyContinue; Remove-Job $script:server -Force -ErrorAction SilentlyContinue }
    Remove-Item Env:FAKE_PIVOTKIT_RECORD, Env:FAKE_PIVOTKIT_MODE -ErrorAction SilentlyContinue
}

Describe 'Invoke-UDPivotReport: what goes with which engine' {
    It 'refuses parameters of the other engine and missing inputs, before anything runs' {
        { Invoke-UDPivotReport -Engine Node -Data $rows -View $view -Uri 'https://x.example/api/v1' } | Should -Throw '*-Uri: only with -Engine Rest*'
        { Invoke-UDPivotReport -Engine Node -View $view } | Should -Throw '*-Engine Node needs -Data*'
        { Invoke-UDPivotReport -Engine Rest -Uri 'https://x.example/api/v1' -Token 't' -Data $rows -View $view -Locale de-DE } | Should -Throw '*-Locale: only with -Engine Node*'
        { Invoke-UDPivotReport -Engine Rest -Token 't' -Data $rows -View $view } | Should -Throw '*needs -Uri*'
        { Invoke-UDPivotReport -Engine Rest -Uri 'https://x.example/api/v1' -Token 't' -View $view } | Should -Throw '*either -Data*or -Source*'
        { Invoke-UDPivotReport -Engine Rest -Uri 'https://x.example/api/v1' -Token 't' -Data $rows -Source 'sales' -View $view } | Should -Throw '*either -Data*or -Source*'
        { Invoke-UDPivotReport -Engine Rest -Uri 'https://x.example/api/v1' -Data $rows -View $view } | Should -Throw '*either -Token*or -Credential*'
        { Invoke-UDPivotReport -Engine Rest -Uri 'https://x.example/api/v1' -Token 't' -Credential $client -TokenUri 'https://login.example/token' -Data $rows -View $view } | Should -Throw '*either -Token*or -Credential*'
        { Invoke-UDPivotReport -Engine Rest -Uri 'https://x.example/api/v1' -Credential $client -Data $rows -View $view } | Should -Throw '*-Credential needs -TokenUri*'
        { Invoke-UDPivotReport -Engine Rest -Uri 'https://x.example/api/v1' -Token 't' -Scope 'a' -Data $rows -View $view } | Should -Throw '*-Scope: only with -Credential*'
        { Invoke-UDPivotReport -Engine Rest -Uri 'https://x.example/api/v1' -Token 't' -Data $rows -Parameter @{ a = 1 } -View $view } | Should -Throw '*-Parameter goes with -Source*'
        { Invoke-UDPivotReport -Engine Rest -Uri 'https://x.example/api/v1' -Token 't' -Source 'inline:' -View $view } | Should -Throw '*Source*'
        { Invoke-UDPivotReport -Engine Node -Data $rows -View $view -OutFile (Join-Path $TestDrive 'r.html') -Format csv } | Should -Throw '*-OutFile names a html file, -Format csv*'
        { Invoke-UDPivotReport -Engine Node -Data $rows -Layout @{ rows = 'Team'; colour = 'red' } } | Should -Throw '*-Layout: unknown key "colour"*'
        { Invoke-UDPivotReport -Engine Node -Data $rows -View @{ rows = 'Team' } } | Should -Throw '*-View:*'
    }

    It 'sends a token over https only, or http to this machine; never to another host over http' {
        foreach ($uri in 'http://reports.example.com/api/v1', 'http://192.0.2.10/api/v1', 'ftp://127.0.0.1/api/v1') {
            { Invoke-UDPivotReport -Engine Rest -Uri $uri -Token 't' -Data $rows -View $view } | Should -Throw '*an https address*' -Because $uri
        }
        { Invoke-UDPivotReport -Engine Rest -Uri 'https://x.example/api/v1' -Credential $client -TokenUri 'http://login.example.com/token' -Data $rows -View $view } | Should -Throw '*-TokenUri*https only*'
        & $module { Test-UDPivotLoopbackUri -Uri 'http://localhost:3333/api/v1' } | Should -BeTrue
        & $module { Test-UDPivotLoopbackUri -Uri 'http://[::1]:3333/api/v1' } | Should -BeTrue
        & $module { Test-UDPivotLoopbackUri -Uri 'http://127.0.0.2/api/v1' } | Should -BeTrue
    }
}

Describe 'Invoke-UDPivotReport: the data sent' {
    It 'a DataTable as columns, rows of values and rowCount: DBNull and NaN as null, dates as ISO text, numbers as numbers' {
        $table = [System.Data.DataTable]::new()
        foreach ($c in @(@('Id', [int]), @('When', [datetime]), @('Team', [string]), @('Hours', [double]), @('Done', [bool]))) { [void]$table.Columns.Add($c[0], $c[1]) }
        [void]$table.Rows.Add(1, [datetime]::new(2026, 3, 1, 0, 0, 0, [DateTimeKind]::Utc), 'A', 2.5, $true)
        [void]$table.Rows.Add(2, [DBNull]::Value, [DBNull]::Value, [double]::NaN, $false)
        # read straight from the DataTable's rows, and the same through the DataView
        ConvertTo-TableJson -Data $table | Should -Be '{"columns":["Id","When","Team","Hours","Done"],"rows":[[1,"2026-03-01T00:00:00.0000000","A",2.5,true],[2,null,null,null,false]],"rowCount":2}'
        ConvertTo-TableJson -Data $table.DefaultView | Should -Be (ConvertTo-TableJson -Data $table)
        # text as it is (no \u escapes), TimeSpans as seconds
        $odd = [System.Data.DataTable]::new()
        [void]$odd.Columns.Add('Name', [string]); [void]$odd.Columns.Add('Took', [timespan])
        $greeting = 'Gr{0}{1}e' -f [char]0xFC, [char]0xDF
        [void]$odd.Rows.Add(('{0} "x"' -f $greeting), [timespan]::FromMinutes(1.5))
        ConvertTo-TableJson -Data $odd | Should -Be ('{"columns":["Name","Took"],"rows":[["' + $greeting + ' \"x\"",90]],"rowCount":1}')
        { ConvertTo-TableJson -Data @() } | Should -Throw '*no rows*'
    }

    It 'rows are read by column name: another property order, missing properties and hashtables keep their columns' {
        $mixed = @(
            [pscustomobject]@{ Team = 'A'; Hours = 1; When = 'x' }
            [pscustomobject]@{ When = 'y'; Hours = 2; Team = 'B' }
            [pscustomobject]@{ Hours = 3 }
            @{ Hours = 4; Team = 'D'; When = 'z' }
        )
        ConvertTo-TableJson -Data $mixed | Should -Be '{"columns":["Team","Hours","When"],"rows":[["A",1,"x"],["B",2,"y"],[null,3,null],["D",4,"z"]],"rowCount":4}'
        # a property the first row does not have is left out, said once in a warning
        $extra = @([pscustomobject]@{ Team = 'A' }, [pscustomobject]@{ Team = 'B'; Secret = 's' }, [pscustomobject]@{ Team = 'C'; Secret = 't'; Other = 1 })
        $json = ConvertTo-TableJson -Data $extra -WarningVariable warned -WarningAction SilentlyContinue
        $json | Should -Be '{"columns":["Team"],"rows":[["A"],["B"],["C"]],"rowCount":3}'
        @($warned).Count | Should -Be 1
        "$warned" | Should -BeLike '*left out: Secret, Other*'
    }

    It 'the compiled row writer and the PowerShell one write the same JSON: a DataTable, PSCustomObjects in any order, and over the cap' {
        $table = [System.Data.DataTable]::new()
        foreach ($c in @(@('Id', [int]), @('When', [datetime]), @('Team', [string]), @('Hours', [double]), @('Took', [timespan]), @('Big', [decimal]))) { [void]$table.Columns.Add($c[0], $c[1]) }
        $objects = [System.Collections.Generic.List[object]]::new()
        foreach ($i in 1..1200) {
            [void]$table.Rows.Add($i, [datetime]::new(2026, 1, 1).AddHours($i), $(if ($i % 9) { 'T{0}' -f ($i % 4) } else { [DBNull]::Value }), $(if ($i % 11) { $i / 8 } else { [double]::NaN }), [timespan]::FromSeconds($i), [decimal]$i * 1.25)
            $objects.Add($(if ($i % 2) { [pscustomobject]@{ Team = 'T{0}' -f ($i % 4); Hours = $i / 8; When = [datetime]::new(2026, 1, 1).AddHours($i); List = @(1, 'a', $null); Bytes = [byte[]](1, 2, 3); Nested = [pscustomobject]@{ x = 1; y = 'z' } } } else { [pscustomobject]@{ When = [datetime]::new(2026, 1, 1).AddHours($i); Hours = $i / 8; Team = 'T{0}' -f ($i % 4); Nested = [pscustomobject]@{ x = 1; y = 'z' }; List = @(1, 'a', $null); Bytes = [byte[]](1, 2, 3) } }))
        }
        $objects = $objects.ToArray()
        & $module { $Script:ReportWriterCompiled = $null }
        $compiled = @((ConvertTo-TableJson -Data $table), (& $module { $Script:LastTableWriter }), (ConvertTo-TableJson -Data $objects), (& $module { $Script:LastTableWriter }))
        $compiled[1] | Should -Be 'Compiled' -Because 'from 1,000 rows the compiled class writes a DataTable'
        $compiled[3] | Should -Be 'Compiled' -Because 'and a list of PSCustomObjects'
        $compiled = @($compiled[0], $compiled[2])
        try {
            & $module { $Script:ReportWriterCompiled = $false }
            $plain = @((ConvertTo-TableJson -Data $table), (ConvertTo-TableJson -Data $objects))
            & $module { $Script:LastTableWriter } | Should -Be 'PowerShell'
            { ConvertTo-TableJson -Data $table -MaxBytes 60000 } | Should -Throw -ErrorId 'PivotDataTooLarge'
        }
        finally { & $module { $Script:ReportWriterCompiled = $null } }
        $compiled[0] | Should -Be $plain[0]
        $compiled[1] | Should -Be $plain[1]
        # lists, bytes and objects as PowerShell's [string] writes them, whichever writer wrote the rows
        $compiled[1].StartsWith('{"columns":["Team","Hours","When","List","Bytes","Nested"],"rows":[["T1",0.125,"2026-01-01T01:00:00.0000000","1 a ","1 2 3","@{x=1; y=z}"],["T2",0.25,"2026-01-01T02:00:00.0000000","1 a ","1 2 3","@{x=1; y=z}"]', [System.StringComparison]::Ordinal) | Should -BeTrue
        { ConvertTo-TableJson -Data $table -MaxBytes 60000 } | Should -Throw -ErrorId 'PivotDataTooLarge'
    }

    It 'the estimate refuses before a row is written; while writing the cap is checked every 256 rows and once at the end, in both writers' {
        # 2000 rows x 3 columns: at least 14,000 bytes, so 10,000 is refused before even the columns are written
        $narrow = [System.Data.DataTable]::new()
        foreach ($c in 'A', 'B', 'C') { [void]$narrow.Columns.Add($c, [string]) }
        foreach ($i in 1..2000) { [void]$narrow.Rows.Add('x', 'y', 'z') }
        $stop = Get-StopPoint -Data $narrow -MaxBytes 10000
        $stop.Error | Should -Be 'PivotDataTooLarge'
        $stop.Bytes | Should -BeLessThan 10
        # wide rows (about a kilobyte each), so the stop point shows where the cap was checked
        $wide = { param($n) $t = [System.Data.DataTable]::new(); [void]$t.Columns.Add('Text', [string]); foreach ($i in 1..$n) { [void]$t.Rows.Add('w' * 1000) }; , $t }
        $row = (Get-StopPoint -Data (& $wide 2) -MaxBytes 0).Bytes - (Get-StopPoint -Data (& $wide 1) -MaxBytes 0).Bytes
        $row | Should -BeGreaterThan 1000
        foreach ($mode in $null, $false) {
            try {
                & $module { param($m) $Script:ReportWriterCompiled = $m } $mode
                # 1100 rows over a cap of 300 rows: the check after row 256 passes, the one after row 512 stops
                $stop = Get-StopPoint -Data (& $wide 1100) -MaxBytes (300 * $row)
                $stop.Writer | Should -Be $(if ($null -eq $mode) { 'Compiled' } else { 'PowerShell' })
                $stop.Error | Should -Be 'PivotDataTooLarge'
                $stop.Bytes | Should -BeGreaterThan (512 * $row) -Because "$($stop.Writer): stopped after row 512"
                $stop.Bytes | Should -BeLessThan (513 * $row) -Because "$($stop.Writer): not later than row 512"
            }
            finally { & $module { $Script:ReportWriterCompiled = $null } }
        }
        # 255 rows over the cap: no check after 256 rows, the one at the end stops it
        $stop = Get-StopPoint -Data (& $wide 255) -MaxBytes (100 * $row)
        $stop.Error | Should -Be 'PivotDataTooLarge'
        $stop.Bytes | Should -BeGreaterThan (255 * $row)
        # 256 rows: stopped by the check after row 256, before the end of the list is written
        $stop = Get-StopPoint -Data (& $wide 256) -MaxBytes (100 * $row)
        $stop.Error | Should -Be 'PivotDataTooLarge'
        $stop.Bytes | Should -BeGreaterThan (256 * $row)
    }

    It 'rows deleted but not accepted are left out by both writers (their values cannot be read)' {
        $table = [System.Data.DataTable]::new()
        [void]$table.Columns.Add('Id', [int])
        foreach ($i in 1..1200) { [void]$table.Rows.Add($i) }
        $table.AcceptChanges()
        $table.Rows[1].Delete()
        $table.Rows[5].Delete()
        $compiled = ConvertTo-TableJson -Data $table
        & $module { $Script:LastTableWriter } | Should -Be 'Compiled'
        try {
            & $module { $Script:ReportWriterCompiled = $false }
            $plain = ConvertTo-TableJson -Data $table
        }
        finally { & $module { $Script:ReportWriterCompiled = $null } }
        $compiled | Should -Be $plain
        $compiled.StartsWith('{"columns":["Id"],"rows":[[1],[3],[4],[5],[7],', [System.StringComparison]::Ordinal) | Should -BeTrue
        $compiled.EndsWith('[1200]],"rowCount":1198}', [System.StringComparison]::Ordinal) | Should -BeTrue
        # a small table, PowerShell's writer only
        $small = [System.Data.DataTable]::new(); [void]$small.Columns.Add('Id', [int]); foreach ($i in 1..3) { [void]$small.Rows.Add($i) }
        $small.AcceptChanges(); $small.Rows[0].Delete()
        ConvertTo-TableJson -Data $small | Should -Be '{"columns":["Id"],"rows":[[2],[3]],"rowCount":2}'
    }

    It 'past -MaxBytes it stops with PivotDataTooLarge: from rows x columns before anything is written, or while the rows are written' {
        $big = [System.Data.DataTable]::new()
        foreach ($c in 'A', 'B', 'C') { [void]$big.Columns.Add($c, [string]) }
        foreach ($i in 1..2000) { [void]$big.Rows.Add('x', 'y', 'z') }
        # 2000 rows x 3 columns take at least 14,000 bytes: refused before a row is written
        { ConvertTo-TableJson -Data $big -MaxBytes 10000 } | Should -Throw -ErrorId 'PivotDataTooLarge'
        # few rows of long text pass that estimate and are stopped while they are written
        $long = [System.Data.DataTable]::new()
        [void]$long.Columns.Add('Text', [string])
        foreach ($i in 1..600) { [void]$long.Rows.Add('t' * 200) }
        { ConvertTo-TableJson -Data $long -MaxBytes 50000 } | Should -Throw -ErrorId 'PivotDataTooLarge'
        (ConvertTo-TableJson -Data $long -MaxBytes 200000).Length | Should -BeGreaterThan 120000
    }

    It 'a layout as the command line''s flags, one argument per value' {
        $layout = & $module { ConvertTo-UDPivotReportLayout -Layout @{
                rows = 'Team, East'; cols = @('Prio'); values = @(@{ field = 'Time: start'; agg = 'sum' }, @{ field = 'Id' })
                groups = @(@{ field = 'Created'; by = 'yearMonth' }, @{ field = 'Hours'; by = 'bin'; size = 2.5 })
                filters = @([ordered]@{ field = 'Team'; type = 'in'; items = @('A') }); chart = 'Bar'; map = @{ Old = 'New' }
            } }
        $arguments = & $module { param($l) Get-UDPivotLayoutArgument -Layout $l } $layout
        $arguments | Should -Be @('--rows=Team, East', '--cols=Prio', '--values=sum:Time: start', '--values=Id', '--group=Created:yearMonth', '--group=Hours:bin:2.5', '--filter={"field":"Team","type":"in","items":["A"]}', '--chart-type=bar', '--map=Old=New')
        # a field that starts with a dash stays a value
        & $module { Get-UDPivotLayoutArgument -Layout ([ordered]@{ rows = @('-x'); values = @(@{ field = '-y'; agg = 'sum' }) }) } | Should -Be @('--rows=-x', '--values=sum:-y')
    }
}

Describe 'Invoke-UDPivotReport -Engine Node (a stand-in command line)' {
    BeforeEach { $env:FAKE_PIVOTKIT_MODE = 'ok' }

    It 'runs render with the view file, the data and the options; returns the bytes; removes its folder' {
        $bytes = Invoke-UDPivotReport -Engine Node -CliPath $fakeCli -Data $rows -View $view -Format csv -Title 'Hours per team' -Locale de-DE -TimeZone 'Europe/Berlin' -WarningVariable warned -WarningAction SilentlyContinue
        , $bytes | Should -BeOfType [byte[]]
        [System.Text.Encoding]::UTF8.GetString($bytes) | Should -Be 'report:csv'
        $r = Get-Record
        $r.args[0] | Should -Be 'render'
        $r.args[1] | Should -Match 'view\.pivotkit\.json$'
        $work = $r.cwdTmp
        $r.args | Should -Contain '--json'
        $r.args | Should -Contain "--allow-dir=$work"
        $r.args | Should -Contain '--title=Hours per team'
        $r.args | Should -Contain '--locale=de-DE'
        $r.args | Should -Contain '--time-zone=Europe/Berlin'
        # the folder with the app's rows: only this user (0700) on Unix
        if (-not $IsWindows) { $r.mode | Should -Be 448 }
        $r.view.format | Should -Be 'pivotkit-view'
        $r.view.view.rows | Should -Be @('Team')
        $r.data.columns | Should -Be @('Team', 'Hours', 'Created')
        $r.data.rows.Count | Should -Be 6
        Test-Path -LiteralPath $work | Should -BeFalse -Because 'the folder with the app''s rows is removed'
        # warnings go to the warning stream; a reader's info note does not
        @($warned).Count | Should -Be 1
        "$warned" | Should -Match 'noRowsKept'
    }

    It 'with a layout the data is the argument and the flags follow; -OutFile writes and returns the file' {
        $file = Join-Path $TestDrive 'out.xlsx'
        $result = Invoke-UDPivotReport -Engine Node -CliPath $fakeCli -Data $rows -Layout @{ rows = 'Team'; values = @{ field = 'Hours'; agg = 'sum' } } -OutFile $file -WarningAction SilentlyContinue
        $result | Should -BeOfType [System.IO.FileInfo]
        $result.FullName | Should -Be $file
        Get-Content -LiteralPath $file -Raw | Should -Be 'report:xlsx'
        $r = Get-Record
        $r.args[1] | Should -Match 'data\.json$'
        ($r.args -join '|') | Should -Match ([regex]::Escape('--rows=Team|--values=sum:Hours'))
        $r.args | Should -Contain '--format=xlsx'
    }

    It 'a title and a field that start with a dash reach the command line as values' {
        $dashRows = @([pscustomobject]@{ '-x' = 'A'; Hours = 1 })
        $null = Invoke-UDPivotReport -Engine Node -CliPath $fakeCli -Data $dashRows -Layout @{ rows = '-x'; values = @{ field = 'Hours'; agg = 'sum' } } -Title '-T' -WarningAction SilentlyContinue
        $r = Get-Record
        $r.args | Should -Contain '--rows=-x'
        $r.args | Should -Contain '--title=-T'
        $r.args | Should -Not -Contain '-x'
    }

    It '-WhatIf runs nothing and writes nothing' {
        $file = Join-Path $TestDrive 'whatif.csv'
        Remove-Item -LiteralPath $script:record -ErrorAction SilentlyContinue
        Invoke-UDPivotReport -Engine Node -CliPath $fakeCli -Data $rows -View $view -OutFile $file -WhatIf
        Test-Path -LiteralPath $file | Should -BeFalse
        Test-Path -LiteralPath $script:record | Should -BeFalse
    }

    It 'a view with errors: the findings in the error, nothing written, the folder removed' {
        $env:FAKE_PIVOTKIT_MODE = 'errors'
        $file = Join-Path $TestDrive 'never.csv'
        { Invoke-UDPivotReport -Engine Node -CliPath $fakeCli -Data $rows -View $view -OutFile $file } | Should -Throw '*wrote no report (exit 1)*error unknownField at rows`[0`]: unknown field "Taem" (did you mean Team?)*'
        Test-Path -LiteralPath $file | Should -BeFalse
        Test-Path -LiteralPath (Get-Record).cwdTmp | Should -BeFalse
        $env:FAKE_PIVOTKIT_MODE = 'usage'
        { Invoke-UDPivotReport -Engine Node -CliPath $fakeCli -Data $rows -View $view } | Should -Throw '*limit LIMIT_EXCEEDED: too many rows*'
        $env:FAKE_PIVOTKIT_MODE = 'nojson'
        { Invoke-UDPivotReport -Engine Node -CliPath $fakeCli -Data $rows -View $view } | Should -Throw '*gave no --json answer: pivotkit: unknown option --allow-dir*'
    }

    It 'a missing command line is an error that says how to install it' {
        { Invoke-UDPivotReport -Engine Node -CliPath (Join-Path $TestDrive 'none.js') -Data $rows -View $view } | Should -Throw '*-CliPath*no such file*'
        $path = $env:PATH
        try {
            $env:PATH = $TestDrive
            { Invoke-UDPivotReport -Engine Node -Data $rows -View $view } | Should -Throw '*npm install --global pivotkit-cli*'
        }
        finally { $env:PATH = $path }
    }
}

Describe 'Invoke-UDPivotReport -Engine Rest (a stand-in pivotkit-server)' {
    BeforeEach { $null = Get-Log; & $module { $Script:TokenCache.Clear() } }

    It 'POSTs the rows as inline: data with the view, the format and the static token' {
        $bytes = Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view -Format csv -Title 'Hours' -DataName 'Tickets' -DataAsOf ([datetime]::new(2026, 11, 15, 6, 0, 0, [DateTimeKind]::Utc))
        [System.Text.Encoding]::UTF8.GetString($bytes) | Should -Be 'Team,Sum of Hours'
        $log = @(Get-Log)
        $log.Count | Should -Be 1
        $log[0].Path | Should -Be '/api/v1/views/render/file'
        $log[0].Authorization | Should -Be 'Bearer static-token-0123456789'
        $log[0].ContentType | Should -Match '^application/json'
        $sent = $log[0].Body | ConvertFrom-Json -Depth 16
        $sent.source | Should -Be 'inline:'
        $sent.format | Should -Be 'csv'
        $sent.title | Should -Be 'Hours'
        $sent.data.columns | Should -Be @('Team', 'Hours', 'Created')
        $sent.data.rowCount | Should -Be 6
        # as text: ConvertFrom-Json would read the date back as a DateTime
        $log[0].Body | Should -BeLike '*"rows":`[`["T1",1.5,"2026-01-01T08:00:00.0000000Z"`]*'
        $sent.data.name | Should -Be 'Tickets'
        $log[0].Body | Should -BeLike '*"asOf":"2026-11-15T06:00:00Z"*'
        $sent.view.rows | Should -Be @('Team')
    }

    It 'a SecureString token, a configured source with parameters, a layout' {
        $null = Invoke-UDPivotReport @rest -Token ([System.Net.NetworkCredential]::new('', 'static-token-0123456789').SecurePassword) -Source 'vms' -Parameter @{ customer = 'acme' } -Layout @{ rows = 'Team' }
        $sent = (@(Get-Log)[0]).Body | ConvertFrom-Json -Depth 16
        $sent.source | Should -Be 'vms'
        $sent.params.customer | Should -Be 'acme'
        $sent.layout.rows | Should -Be @('Team')
        $sent.PSObject.Properties.Name | Should -Not -Contain 'data'
        $sent.format | Should -Be 'xlsx'
    }

    It 'a 422 lists the findings and the request id; a 503 says when to try again; a redirect is not followed' {
        $mock.Render.Enqueue(@{ Status = 422; Body = '{"type":"x","title":"View has errors","status":422,"code":"VIEW_HAS_ERRORS","detail":"the view has errors","requestId":"abc123","findings":[{"severity":"error","code":"unknownField","path":"rows[0]","message":"unknown field \"Taem\"","suggestion":"Team"}]}' })
        { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view } | Should -Throw '*VIEW_HAS_ERRORS (422): the view has errors*unknown field "Taem" (did you mean Team?)*Request id for the operator: abc123*'
        $mock.Render.Enqueue(@{ Status = 503; Body = '{"type":"x","title":"Busy","status":503,"code":"BUSY","detail":"another large body is being read","retryable":true}'; Headers = @{ 'Retry-After' = '7' } })
        $caught = $null
        try { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view } catch { $caught = $_ }
        $caught.Exception.Message | Should -BeLike '*BUSY (503)*Try again in 7 seconds*'
        $caught.Exception.Message | Should -Not -BeLike '*Trying again may work*' -Because 'Retry-After says it already'
        $caught.Exception.Data['RetryAfter'] | Should -Be '7'
        $caught.Exception.Data['Status'] | Should -Be 503
        $caught.Exception.Data['Retryable'] | Should -BeTrue
        # retryable without Retry-After, and Retry-After as a date
        $mock.Render.Enqueue(@{ Status = 502; Body = '{"type":"x","title":"t","status":502,"code":"SOURCE_UNAVAILABLE","detail":"the source is not available right now","retryable":true}' })
        $caught = $null
        try { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view } catch { $caught = $_ }
        $caught.Exception.Message | Should -BeLike '*SOURCE_UNAVAILABLE (502)*Trying again may work.*'
        $caught.Exception.Data['Retryable'] | Should -BeTrue
        $mock.Render.Enqueue(@{ Status = 502; Body = '{"type":"x","title":"t","status":502,"code":"SOURCE_UNAVAILABLE","detail":"the source is not set up correctly","retryable":false}' })
        $caught = $null
        try { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view } catch { $caught = $_ }
        $caught.Exception.Message | Should -Not -BeLike '*try*again*'
        $caught.Exception.Data['Retryable'] | Should -BeFalse
        $caught.Exception.Data.Contains('Retryable') | Should -BeTrue
        $mock.Render.Enqueue(@{ Status = 503; Body = '{"type":"x","title":"t","status":503,"code":"NOT_READY","detail":"d"}'; Headers = @{ 'Retry-After' = 'Wed, 21 Oct 2026 07:28:00 GMT' } })
        $caught = $null
        try { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view } catch { $caught = $_ }
        $caught.Exception.Message | Should -BeLike '*Try again after 2026-10-21 07:28:00Z.*'
        $caught.Exception.Data.Contains('Retryable') | Should -BeFalse -Because 'the body did not say'
        $mock.Render.Enqueue(@{ Status = 302; Body = ''; Headers = @{ Location = 'https://elsewhere.example/api/v1/views/render/file' } })
        { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view } | Should -Throw '*redirect (302)*not followed*'
        @(Get-Log | Where-Object Path -NE '/api/v1/views/render/file').Count | Should -Be 0
    }

    It 'no answer (a closed port) and a redirect: an error that says so, and no token or secret left in $Error' {
        $closed = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $closed.Start(); $deadPort = $closed.LocalEndpoint.Port; $closed.Stop()
        $dead = 'http://127.0.0.1:{0}' -f $deadPort
        $dump = { ($global:Error | ForEach-Object { $_ | Format-List * -Force | Out-String; $_.Exception | Format-List * -Force | Out-String; $_.TargetObject | Format-List * -Force | Out-String; ($_.TargetObject.Headers | Out-String) }) -join [Environment]::NewLine }
        $global:Error.Clear()
        $caught = $null
        try { Invoke-UDPivotReport -Engine Rest -Uri ($dead + '/api/v1') -Token 'static-token-NOT-IN-ERRORS' -Data $rows -View $view } catch { $caught = $_ }
        $caught.Exception.Message | Should -BeLike '*pivotkit-server*did not answer*'
        $caught.TargetObject | Should -Not -BeOfType [System.Net.Http.HttpRequestMessage]
        $caught = $null
        try { Invoke-UDPivotReport -Engine Rest -Uri ($dead + '/api/v1') -Credential $client -TokenUri ($dead + '/token') -ClientAuthentication Basic -Data $rows -View $view } catch { $caught = $_ }
        $caught.Exception.Message | Should -BeLike '*Token endpoint*did not answer*'
        $mock.Render.Enqueue(@{ Status = 307; Body = ''; Headers = @{ Location = 'https://elsewhere.example/' } })
        { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view } | Should -Throw '*redirect (307)*'
        $mock.Token.Enqueue(@{ Status = 302; Body = ''; Headers = @{ Location = 'https://elsewhere.example/' } })
        { Invoke-UDPivotReport @rest -Credential $client -TokenUri ($base + '/token') -ClientAuthentication Basic -Data $rows -View $view } | Should -Throw '*Token endpoint*redirect (302)*'
        $text = & $dump
        $basic = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("pivot-psu:$clientSecret"))
        foreach ($secret in 'static-token-NOT-IN-ERRORS', 'static-token-0123456789', $clientSecret, $basic, 'Bearer ') {
            $text | Should -Not -BeLike "*$secret*" -Because 'a request with its headers must not stay in $Error'
        }
    }

    It 'an address with a user name or password is refused, and messages show no user info' {
        { Invoke-UDPivotReport -Engine Rest -Uri 'https://user:pa55word@reports.example.com/api/v1' -Token 't' -Data $rows -View $view } | Should -Throw '-Uri: an absolute address without a user name or password in it*'
        { Invoke-UDPivotReport -Engine Rest -Uri 'https://reports.example.com/api/v1' -Credential $client -TokenUri 'https://id:pa55word@login.example.com/token' -Data $rows -View $view } | Should -Throw '-TokenUri: an absolute address without a user name or password in it.'
        foreach ($bad in 'https://user:pa55word@reports.example.com/api/v1', 'https://id:pa55word@login.example.com/token') {
            $caught = $null
            try { Invoke-UDPivotReport -Engine Rest -Uri $bad -Token 't' -Data $rows -View $view } catch { $caught = $_ }
            "$caught" | Should -Not -BeLike '*pa55word*'
        }
        & $module { Get-UDPivotSafeAddress -Uri 'https://u:p@host.example:8443/api/v1/x?token=abc' } | Should -Be 'https://host.example:8443/api/v1/x'
    }

    It 'with -Debug and -Verbose no token, secret or Basic header reaches any stream' {
        $basic = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("pivot-psu:$clientSecret"))
        $streams = & {
            Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view -Debug -Verbose
            Invoke-UDPivotReport @rest -Credential $client -TokenUri ($base + '/token') -ClientAuthentication Basic -Data $rows -View $view -Debug -Verbose
            Invoke-UDPivotReport @rest -Credential $client -TokenUri ($base + '/token') -Data $rows -View $view -Debug -Verbose
        } *>&1 | Out-String -Width 4096
        foreach ($secret in 'static-token-0123456789', 'oauth-token-', $clientSecret, $basic, [uri]::EscapeDataString($clientSecret)) {
            $streams | Should -Not -BeLike "*$secret*"
        }
    }

    It 'OAuth: the token cache is per client id, secret and server' {
        $oauth = @{ TokenUri = $base + '/token' }
        $tokenCalls = { @(Get-Log | Where-Object Path -EQ '/token').Count }
        $null = Invoke-UDPivotReport @rest @oauth -Credential $client -Data $rows -View $view
        $null = Invoke-UDPivotReport @rest @oauth -Credential $client -Data $rows -View $view
        & $tokenCalls | Should -Be 1
        # another client id
        $other = [pscredential]::new('pivot-other', $client.Password)
        $null = Invoke-UDPivotReport @rest @oauth -Credential $other -Data $rows -View $view
        & $tokenCalls | Should -Be 1
        # the same client id with another secret: checked at the endpoint, not served from the cache
        $wrong = [pscredential]::new('pivot-psu', [System.Net.NetworkCredential]::new('', 'another-secret').SecurePassword)
        $null = Invoke-UDPivotReport @rest @oauth -Credential $wrong -Data $rows -View $view
        & $tokenCalls | Should -Be 1
        # another server (localhost instead of 127.0.0.1): a token of its own
        $null = Invoke-UDPivotReport -Engine Rest -Uri ($base.Replace('127.0.0.1', 'localhost') + '/api/v1') @oauth -Credential $client -Data $rows -View $view
        & $tokenCalls | Should -Be 1
        # and the first combination is still cached
        $null = Invoke-UDPivotReport @rest @oauth -Credential $client -Data $rows -View $view
        & $tokenCalls | Should -Be 0
    }

    It 'OAuth Basic: client id and secret are form-encoded before they are joined (RFC 6749 2.3.1)' {
        $odd = [pscredential]::new('id:with space', [System.Net.NetworkCredential]::new('', 'p@ss w+rd/=:').SecurePassword)
        $null = Invoke-UDPivotReport @rest -Credential $odd -TokenUri ($base + '/token') -ClientAuthentication Basic -Data $rows -View $view
        $request = @(Get-Log | Where-Object Path -EQ '/token')[0]
        $request.Authorization | Should -Be ('Basic ' + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes('id%3Awith%20space:p%40ss%20w%2Brd%2F%3D%3A')))
    }

    It 'a -Uri with a query string or fragment is refused before anything is sent' {
        { Invoke-UDPivotReport @rest -Uri ($base + '/api/v1?tenant=a') -Token 'static-token-0123456789' -Data $rows -View $view } | Should -Throw '-Uri: the REST service''s address without a query string or fragment*'
        { Invoke-UDPivotReport @rest -Uri ($base + '/api/v1#x') -Token 'static-token-0123456789' -Data $rows -View $view } | Should -Throw '-Uri: the REST service''s address without a query string or fragment*'
        @(Get-Log).Count | Should -Be 0
    }

    It 'a request body above the server''s default cap gets a warning first' {
        # the cap lowered for the test: 10 MiB of rows would only make it slow
        $cap = & $module { $Script:ReportDataWarnBytes }
        try {
            & $module { $Script:ReportDataWarnBytes = 200 }
            $null = Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view -WarningVariable warned -WarningAction SilentlyContinue
            "$warned" | Should -BeLike '*pivotkit-server takes at most 10 MiB*rest.data.maxBytes*'
            & $module { $Script:ReportDataWarnBytes = 100MB }
            $null = Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view -WarningVariable quiet -WarningAction SilentlyContinue
            @($quiet).Count | Should -Be 0
        }
        finally { & $module { param($c) $Script:ReportDataWarnBytes = $c } $cap }
    }

    It '-MaxBytes: data over it is refused before anything is sent; the message points to -Source' {
        $many = foreach ($i in 1..3000) { [pscustomobject]@{ Team = 'T{0}' -f ($i % 5); Hours = $i } }
        $caught = $null
        try { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $many -View $view -MaxBytes 20KB } catch { $caught = $_ }
        $caught.FullyQualifiedErrorId | Should -Be 'PivotDataTooLarge'
        $caught.Exception.Message | Should -BeLike '*-MaxBytes*-Source*'
        $caught.Exception.Data['MaxBytes'] | Should -Be 20KB
        @(Get-Log).Count | Should -Be 0
        { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Source 'sales' -View $view -MaxBytes 20KB } | Should -Throw '*-MaxBytes go with -Data*'
        { Invoke-UDPivotReport -Engine Node -Data $rows -View $view -MaxBytes 20KB } | Should -Throw '*-MaxBytes: only with -Engine Rest*'
    }

    It 'every failure has a fixed error id, with the server''s status, code, Retry-After and request id in Data' {
        $id = { param([scriptblock]$Call) try { & $Call; $null } catch { $_ } }
        $mock.Render.Enqueue(@{ Status = 422; Body = '{"type":"x","title":"t","status":422,"code":"VIEW_HAS_ERRORS","detail":"d","requestId":"req-422","findings":[]}' })
        $e = & $id { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view }
        $e.FullyQualifiedErrorId | Should -Be 'PivotViewHasErrors'
        $e.Exception.Data['RequestId'] | Should -Be 'req-422'
        $e.Exception.Data['Status'] | Should -Be 422
        $mock.Render.Enqueue(@{ Status = 503; Body = '{"type":"x","title":"t","status":503,"code":"BUSY","detail":"d","requestId":"req-503"}'; Headers = @{ 'Retry-After' = '3' } })
        $e = & $id { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view }
        $e.FullyQualifiedErrorId | Should -Be 'PivotServerError'
        $e.Exception.Data['Code'] | Should -Be 'BUSY'
        $e.Exception.Data['RetryAfter'] | Should -Be '3'
        $e.Exception.Data['RequestId'] | Should -Be 'req-503'
        $mock.Render.Enqueue(@{ Status = 413; Body = '' })
        (& $id { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view }).FullyQualifiedErrorId | Should -Be 'PivotDataTooLarge'
        # a token without the REST scope: refused, with what to ask for
        $mock.Render.Enqueue(@{ Status = 403; Body = '{"type":"x","title":"t","status":403,"code":"INSUFFICIENT_SCOPE","detail":"the token lacks a required scope"}' })
        $e = & $id { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view }
        $e.FullyQualifiedErrorId | Should -Be 'PivotTokenRefused'
        $e.Exception.Message | Should -BeLike '*INSUFFICIENT_SCOPE (403)*-Scope*pivotkit:rest*'
        $mock.Render.Enqueue(@{ Status = 403; Body = '{"type":"x","title":"t","status":403,"code":"NOT_ALLOWED","detail":"no downloads"}' })
        (& $id { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view }).FullyQualifiedErrorId | Should -Be 'PivotServerError'
        (& $id { Invoke-UDPivotReport @rest -Token 'static-token-WRONG-0000' -Data $rows -View $view }).FullyQualifiedErrorId | Should -Be 'PivotTokenRefused'
        $mock.Token.Enqueue(@{ Status = 400; Body = '{"error":"invalid_client"}' })
        $e = & $id { Invoke-UDPivotReport @rest -Credential $client -TokenUri ($base + '/token') -Data $rows -View $view }
        $e.FullyQualifiedErrorId | Should -Be 'PivotTokenRefused'
        $e.Exception.Data['Code'] | Should -Be 'invalid_client'
        $mock.Render.Enqueue(@{ Status = 302; Body = ''; Headers = @{ Location = 'https://elsewhere.example/' } })
        (& $id { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view }).FullyQualifiedErrorId | Should -Be 'PivotRedirectRefused'
        $closed = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $closed.Start(); $deadPort = $closed.LocalEndpoint.Port; $closed.Stop()
        (& $id { Invoke-UDPivotReport -Engine Rest -Uri ('http://127.0.0.1:{0}/api/v1' -f $deadPort) -Token 't' -Data $rows -View $view }).FullyQualifiedErrorId | Should -Be 'PivotServerUnreachable'
        # the command line
        (& $id { Invoke-UDPivotReport -Engine Node -CliPath (Join-Path $TestDrive 'none.js') -Data $rows -View $view }).FullyQualifiedErrorId | Should -Be 'PivotCliNotFound'
        $env:FAKE_PIVOTKIT_MODE = 'errors'
        (& $id { Invoke-UDPivotReport -Engine Node -CliPath $fakeCli -Data $rows -View $view }).FullyQualifiedErrorId | Should -Be 'PivotViewHasErrors'
        $env:FAKE_PIVOTKIT_MODE = 'usage'
        (& $id { Invoke-UDPivotReport -Engine Node -CliPath $fakeCli -Data $rows -View $view }).FullyQualifiedErrorId | Should -Be 'PivotCliFailed'
        $env:FAKE_PIVOTKIT_MODE = 'nojson'
        (& $id { Invoke-UDPivotReport -Engine Node -CliPath $fakeCli -Data $rows -View $view }).FullyQualifiedErrorId | Should -Be 'PivotCliFailed'
        $env:FAKE_PIVOTKIT_MODE = 'ok'
    }

    It 'a 413 without a problem document says the data is too large' {
        $mock.Render.Enqueue(@{ Status = 413; Body = '' })
        { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view } | Should -Throw '*HTTP 413 (413)*too large for the server*-Source*'
    }

    It 'a 413 picks its hint by code: BODY_TOO_LARGE asks for less data, LIMIT_EXCEEDED for a smaller view' {
        $mock.Render.Enqueue(@{ Status = 413; Body = '{"type":"x","title":"t","status":413,"code":"BODY_TOO_LARGE","detail":"the body is larger than 10 MiB","requestId":"req-big"}' })
        $caught = $null
        try { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view } catch { $caught = $_ }
        $caught.FullyQualifiedErrorId | Should -Be 'PivotDataTooLarge'
        $caught.Exception.Message | Should -BeLike '*BODY_TOO_LARGE (413)*send fewer rows or columns*-Source*'
        $mock.Render.Enqueue(@{ Status = 413; Body = '{"type":"x","title":"t","status":413,"code":"LIMIT_EXCEEDED","detail":"the report is over a limit of the server (limits.maxCells)"}' })
        $caught = $null
        try { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Source 'sales' -View $view } catch { $caught = $_ }
        $caught.FullyQualifiedErrorId | Should -Be 'PivotDataTooLarge'
        $caught.Exception.Message | Should -BeLike '*LIMIT_EXCEEDED (413)*make the view smaller or filter*'
        $caught.Exception.Message | Should -Not -BeLike '*send fewer rows*'
    }

    It 'without a problem document: the request id from X-Request-Id, the 500 of a crashed handler with its error text' {
        # a 400 of the listener itself or a proxy: no JSON, the id only in the header
        $mock.Render.Enqueue(@{ Status = 400; Body = ''; Headers = @{ 'X-Request-Id' = 'hdr-400' } })
        $caught = $null
        try { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view } catch { $caught = $_ }
        $caught.FullyQualifiedErrorId | Should -Be 'PivotServerError'
        $caught.Exception.Message | Should -BeLike '*HTTP 400 (400)*Request id for the operator: hdr-400*'
        $caught.Exception.Data['RequestId'] | Should -Be 'hdr-400'
        # the body's id wins over the header's
        $mock.Render.Enqueue(@{ Status = 404; Body = '{"type":"x","title":"t","status":404,"code":"NOT_FOUND","detail":"d","requestId":"body-404"}'; Headers = @{ 'X-Request-Id' = 'hdr-404' } })
        $caught = $null
        try { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view } catch { $caught = $_ }
        $caught.FullyQualifiedErrorId | Should -Be 'PivotServerError'
        $caught.Exception.Data['RequestId'] | Should -Be 'body-404'
        # pivotkit-server's answer when a handler throws: no code, no detail, the text in "error"
        $mock.Render.Enqueue(@{ Status = 500; Body = '{"error":"internal error","requestId":"req-500"}'; Headers = @{ 'X-Request-Id' = 'req-500' } })
        $caught = $null
        try { Invoke-UDPivotReport @rest -Token 'static-token-0123456789' -Data $rows -View $view } catch { $caught = $_ }
        $caught.FullyQualifiedErrorId | Should -Be 'PivotServerError'
        $caught.Exception.Message | Should -BeLike '*HTTP 500 (500): internal error*Request id for the operator: req-500*'
    }

    It 'a 413 the server sends while the body is still coming, then resets the connection: PivotDataTooLarge with the server''s code and request id' {
        # as pivotkit-server does with a body over its cap: it reads the headers, answers 413 at once
        # and resets the connection while the client still sends
        $early = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $early.Start()
        $earlyPort = $early.LocalEndpoint.Port
        $job = Start-ThreadJob -ScriptBlock {
            $Listener = $using:early
            try {
                $client = $Listener.AcceptTcpClient()
                $stream = $client.GetStream()
                $head = [System.Text.StringBuilder]::new()
                while (-not $head.ToString().Contains("`r`n`r`n")) { $b = $stream.ReadByte(); if ($b -lt 0) { return }; $null = $head.Append([char]$b) }
                if ($head.ToString() -match '(?im)^expect:\s*100-continue') { $c = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 100 Continue`r`n`r`n"); $stream.Write($c, 0, $c.Length) }
                $body = '{"type":"x","title":"Body too large","status":413,"code":"BODY_TOO_LARGE","detail":"the body is larger than 10 MiB, the most this service takes from you","requestId":"req-early"}'
                $answer = [System.Text.Encoding]::ASCII.GetBytes(("HTTP/1.1 413 Payload Too Large`r`ncontent-type: application/problem+json`r`nx-request-id: req-early`r`ncontent-length: {0}`r`n`r`n{1}" -f $body.Length, $body))
                $stream.Write($answer, 0, $answer.Length)
                $stream.Flush()
                Start-Sleep -Milliseconds 50
                $client.Client.LingerState = [System.Net.Sockets.LingerOption]::new($true, 0)
                $client.Close()
            }
            finally { $Listener.Stop() }
        }
        try {
            # larger than the loopback buffers, so the client is still sending when the reset comes
            $big = [byte[]]::new(24MB)
            $caught = $null
            try { & $module { param($u, $b) Invoke-UDPivotRestRender -Uri $u -Body $b -Auth @{ Token = 'static-token-0123456789' } -TimeoutSec 30 -WarningAction SilentlyContinue } ('http://127.0.0.1:{0}/api/v1' -f $earlyPort) $big } catch { $caught = $_ }
            $caught.FullyQualifiedErrorId | Should -Be 'PivotDataTooLarge'
            $caught.Exception.Message | Should -BeLike '*BODY_TOO_LARGE (413): the body is larger than 10 MiB*Request id for the operator: req-early*'
            $caught.Exception.Data['Code'] | Should -Be 'BODY_TOO_LARGE'
            $caught.Exception.Data['RequestId'] | Should -Be 'req-early'
        }
        finally {
            $null = Wait-Job $job -Timeout 10
            Remove-Job $job -Force
            $early.Stop()
        }
    }

    It 'a refused static token: no second try, and the token is in no message' {
        $caught = $null
        try { Invoke-UDPivotReport @rest -Token 'static-token-WRONG-98765' -Data $rows -View $view } catch { $caught = $_ }
        $caught.Exception.Message | Should -BeLike '*INVALID_TOKEN (401)*Check the token*'
        $caught.Exception.Message | Should -Not -BeLike '*static-token-WRONG*'
        @(Get-Log).Count | Should -Be 1
    }

    It 'OAuth client credentials: one token for two reports, sent with the client in the body, never in a message' {
        $oauth = @{ Credential = $client; TokenUri = $base + '/token'; Scope = 'pivotkit:render', 'pivotkit:data'; Resource = $base + '/api/v1' }
        $null = Invoke-UDPivotReport @rest @oauth -Data $rows -View $view
        $null = Invoke-UDPivotReport @rest @oauth -Data $rows -View $view
        $log = @(Get-Log)
        @($log | Where-Object Path -EQ '/token').Count | Should -Be 1 -Because 'the token is kept until it expires'
        $tokenRequest = $log | Where-Object Path -EQ '/token'
        $form = @{}
        foreach ($pair in $tokenRequest.Body -split '&') { $k, $v = $pair -split '=', 2; $form[$k] = [uri]::UnescapeDataString($v) }
        $form['grant_type'] | Should -Be 'client_credentials'
        $form['client_id'] | Should -Be 'pivot-psu'
        $form['client_secret'] | Should -Be $clientSecret
        $form['scope'] | Should -Be 'pivotkit:render pivotkit:data'
        $form['resource'] | Should -Be ($base + '/api/v1')
        $tokenRequest.Authorization | Should -BeNullOrEmpty
        $used = @($log | Where-Object Path -EQ '/api/v1/views/render/file' | ForEach-Object Authorization)
        $used.Count | Should -Be 2
        $used[0] | Should -BeLike 'Bearer oauth-token-*'
        $used[1] | Should -Be $used[0]
        # the cache key holds no part of the secret
        (& $module { @($Script:TokenCache.Keys) }) -join ' ' | Should -Not -BeLike "*$clientSecret*"
    }

    It 'OAuth: a 401 gets one new token and one more try; a second 401 is the error' {
        $oauth = @{ Credential = $client; TokenUri = $base + '/token' }
        $null = Invoke-UDPivotReport @rest @oauth -Data $rows -View $view
        $mock.Render.Enqueue(@{ Status = 401; Body = '{"type":"x","title":"Unauthorized","status":401,"code":"INVALID_TOKEN","detail":"token expired"}' })
        $null = Invoke-UDPivotReport @rest @oauth -Data $rows -View $view
        $log = @(Get-Log)
        @($log | Where-Object Path -EQ '/token').Count | Should -Be 2
        @($log | Where-Object Path -EQ '/api/v1/views/render/file').Count | Should -Be 3
        foreach ($i in 1..2) { $mock.Render.Enqueue(@{ Status = 401; Body = '{"type":"x","title":"Unauthorized","status":401,"code":"INVALID_TOKEN","detail":"wrong audience"}' }) }
        { Invoke-UDPivotReport @rest @oauth -Data $rows -View $view } | Should -Throw '*INVALID_TOKEN (401): wrong audience*'
        @(Get-Log | Where-Object Path -EQ '/api/v1/views/render/file').Count | Should -Be 2
    }

    It 'OAuth: Basic client authentication, a token without expires_in is not kept, a refused client says why without the secret' {
        $oauth = @{ Credential = $client; TokenUri = $base + '/token'; ClientAuthentication = 'Basic'; Audience = 'pivotkit' }
        foreach ($i in 1..2) { $mock.Token.Enqueue(@{ Status = 200; Body = '{"access_token":"static-token-0123456789","token_type":"Bearer"}' }) }
        $null = Invoke-UDPivotReport @rest @oauth -Data $rows -View $view
        $null = Invoke-UDPivotReport @rest @oauth -Data $rows -View $view
        $tokenRequests = @(Get-Log | Where-Object Path -EQ '/token')
        $tokenRequests.Count | Should -Be 2
        $tokenRequests[0].Authorization | Should -Be ('Basic ' + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("pivot-psu:$clientSecret")))
        $tokenRequests[0].Body | Should -Not -BeLike '*client_secret*'
        $tokenRequests[0].Body | Should -BeLike '*audience=pivotkit*'
        $mock.Token.Enqueue(@{ Status = 401; Body = '{"error":"invalid_client","error_description":"Client authentication failed"}' })
        $caught = $null
        try { Invoke-UDPivotReport @rest @oauth -Data $rows -View $view } catch { $caught = $_ }
        $caught.Exception.Message | Should -BeLike '*refused the client credentials (401): invalid_client: Client authentication failed*'
        $caught.Exception.Message | Should -Not -BeLike "*$clientSecret*"
        ($caught | Out-String) | Should -Not -BeLike "*$clientSecret*"
    }
}

Describe 'Invoke-UDPivotReport against the real pivotkit' {
    It 'the installed command line renders a CSV (PIVOTKIT_TEST_CLI=1)' -Skip:($env:PIVOTKIT_TEST_CLI -ne '1') {
        $text = [System.Text.Encoding]::UTF8.GetString((Invoke-UDPivotReport -Engine Node -Data $rows -View $view -Format csv)).TrimStart([char]0xFEFF)
        ($text -split '\r?\n')[0..3] | Should -Be @('Team,Sum of Hours', 'T0,18', 'T1,13.5', 'Grand Total,31.5')
        { Invoke-UDPivotReport -Engine Node -Data $rows -View @{ rows = @('Taem') } -Format csv } | Should -Throw '*unknown field "Taem"*did you mean Team?*'
        # a layout with --map=Squad=Team and --filter=<json>: the layout's name read as the data's, the filter applied
        $layout = @{ rows = 'Squad'; values = @{ field = 'Hours'; agg = 'sum' }; map = @{ Squad = 'Team' }; filters = @([ordered]@{ field = 'Squad'; type = 'in'; items = @('T1') }) }
        $text = [System.Text.Encoding]::UTF8.GetString((Invoke-UDPivotReport -Engine Node -Data $rows -Layout $layout -Format csv)).TrimStart([char]0xFEFF)
        ($text -split '\r?\n')[0..2] | Should -Be @('Team,Sum of Hours', 'T1,13.5', 'Grand Total,13.5')
    }

    It 'a pivotkit-server renders the rows sent (PIVOTKIT_TEST_URL, PIVOTKIT_TEST_TOKEN)' -Skip:(-not $env:PIVOTKIT_TEST_URL) {
        $text = [System.Text.Encoding]::UTF8.GetString((Invoke-UDPivotReport -Engine Rest -Uri $env:PIVOTKIT_TEST_URL -Token $env:PIVOTKIT_TEST_TOKEN -Data $rows -View $view -Format csv)).TrimStart([char]0xFEFF)
        ($text -split '\r?\n')[0..3] | Should -Be @('Team,Sum of Hours', 'T0,18', 'T1,13.5', 'Grand Total,31.5')
        { Invoke-UDPivotReport -Engine Rest -Uri $env:PIVOTKIT_TEST_URL -Token $env:PIVOTKIT_TEST_TOKEN -Data $rows -View @{ rows = @('Taem') } } | Should -Throw '*VIEW_HAS_ERRORS (422)*unknown field "Taem"*'
    }

    It 'a body over the server''s cap is its 413 with code and request id, not a broken connection (PIVOTKIT_TEST_URL, PIVOTKIT_TEST_TOKEN)' -Skip:(-not $env:PIVOTKIT_TEST_URL) {
        # about 12 MiB of rows: over pivotkit-server's default cap of 10 MiB (rest.data.maxBytes)
        $many = foreach ($i in 1..150000) { [pscustomobject]@{ Team = 'Team-{0:D6}-{1}' -f $i, ('x' * 60); Hours = $i } }
        $caught = $null
        try { Invoke-UDPivotReport -Engine Rest -Uri $env:PIVOTKIT_TEST_URL -Token $env:PIVOTKIT_TEST_TOKEN -Data $many -View $view -Format csv -MaxBytes 64MB -WarningAction SilentlyContinue } catch { $caught = $_ }
        $caught.FullyQualifiedErrorId | Should -Be 'PivotDataTooLarge'
        $caught.Exception.Data['Code'] | Should -Be 'BODY_TOO_LARGE'
        $caught.Exception.Data['RequestId'] | Should -Not -BeNullOrEmpty
    }
}
