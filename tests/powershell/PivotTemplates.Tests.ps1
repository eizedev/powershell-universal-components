#Requires -Version 7.4
# Pester tests for the templates of PowerShellUniversal.Component.Pivot outside PSU: view files,
# -TemplatePath, the template stores, the role checks of their event handlers. PSU's [Endpoint] type is
# a stub, the asset id is set by hand.

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
    $script:rows = @([pscustomobject]@{ Team = 'Ops'; Hours = 2 })
    $script:view = @{ rows = @('Team'); values = @(@{ field = 'Hours'; agg = 'sum' }) }
    # the key the generated handler carries
    $script:keyOf = { param($Endpoint) [regex]::Match($Endpoint.ScriptBlock.ToString(), "'([0-9a-f]{32})'").Groups[1].Value }
    $script:newFolder = { Join-Path ([System.IO.Path]::GetTempPath()) ('pivot-tests-{0}' -f [guid]::NewGuid().ToString('n')) }
}

Describe 'View files' {
    It 'writes pivotkit''s envelope in its key order and reads it back' {
        $json = ConvertTo-UDPivotViewFile -View $script:view -Name ' Per team ' -Description "Two`nlines" -SourceId 'tickets' -SourceName 'Tickets'
        $keys = @(($json | ConvertFrom-Json -AsHashtable).Keys)
        [regex]::Matches($json, '(?m)^  "([^"]+)":') | ForEach-Object { $_.Groups[1].Value } | Should -Be @('$schema', 'format', 'formatVersion', 'name', 'description', 'generator', 'source', 'extensions', 'view')
        $keys | Should -Contain 'view'
        $read = ConvertFrom-UDPivotViewFile -InputObject $json
        $read.Name | Should -Be 'Per team'
        $read.Description | Should -Be 'Two lines'
        $read.Source.id | Should -Be 'tickets'
        $read.View.rows | Should -Be @('Team')
        # without -CreatedAt the same view gives the same bytes
        ConvertTo-UDPivotViewFile -View $script:view -Name 'Per team' | Should -Be (ConvertTo-UDPivotViewFile -View $script:view -Name 'Per team')
        (ConvertTo-UDPivotViewFile -View $script:view -Name 'X' -SchemaUrl '') | Should -Not -Match '\$schema'
    }

    It 'reads { name, view } and a bare view with -Name' {
        (ConvertFrom-UDPivotViewFile -InputObject '{"name":"Saved","view":{"rows":["Team"]}}').Name | Should -Be 'Saved'
        (ConvertFrom-UDPivotViewFile -InputObject '{"rows":["Team"]}' -Name 'From file').Name | Should -Be 'From file'
        { ConvertFrom-UDPivotViewFile -InputObject '{"rows":["Team"]}' } | Should -Throw '*name*'
    }

    It 'refuses newer formats and views, wrong format versions, too large and too deep files' {
        { ConvertFrom-UDPivotViewFile '{"format":"pivotkit-view","formatVersion":2,"name":"N","view":{}}' } | Should -Throw '*newer*'
        { ConvertFrom-UDPivotViewFile '{"format":"pivotkit-view","formatVersion":"1","name":"N","view":{}}' } | Should -Throw '*formatVersion*'
        { ConvertFrom-UDPivotViewFile '{"format":"pivotkit-view","formatVersion":1,"name":"N","view":{"version":2}}' } | Should -Throw '*newer*'
        { ConvertFrom-UDPivotViewFile '{"format":"pivotkit-view","formatVersion":1,"name":"N"}' } | Should -Throw '*no view*'
        { ConvertFrom-UDPivotViewFile ('{"name":"N","view":{"rows":["' + ('x' * 1000001) + '"]}}') } | Should -Throw '*characters*'
        { ConvertFrom-UDPivotViewFile ('{"name":"N","view":' + ('[' * 20) + (']' * 20) + '}') } | Should -Throw
        { ConvertFrom-UDPivotViewFile ('{"name":"' + ('n' * 121) + '","view":{}}') } | Should -Throw '*120*'
    }

    It 'makes names plain text and file names that cannot leave a folder' {
        (ConvertFrom-UDPivotViewFile -InputObject "{`"name`":`"a\u0000b\u202Ec`",`"view`":{}}").Name | Should -Be 'a b c'
        $file = & $script:module { Get-UDPivotViewFileName -Name "../../etc/Gr$([char]0xF6)$([char]0xDF)e passwd" }
        $file | Should -Match '^[a-z0-9-]+-[0-9a-f]{10}\.pivotkit\.json$'
        # as pivotkit-core's viewFileName: accents dropped (NFKD), every other character a dash
        $file | Should -BeLike 'etc-gro-e-passwd-*'
        # names are told apart by case, as pivotkit does: the same name in another case is another file
        (& $script:module { Get-UDPivotViewFileName -Name 'Per Team' }) | Should -Not -Be (& $script:module { Get-UDPivotViewFileName -Name 'per team' })
        # 0.1.0's file names (one per name in any case) never meet this version's
        (& $script:module { Get-UDPivotViewFileName -Name 'Per Team' -Legacy }) | Should -Be (& $script:module { Get-UDPivotViewFileName -Name 'per team' -Legacy })
        (& $script:module { Get-UDPivotViewFileName -Name 'per team' -Legacy }) | Should -Not -Be (& $script:module { Get-UDPivotViewFileName -Name 'per team' })
        (& $script:module { Get-UDPivotViewFileName -Name 'Per team!' }) | Should -Not -Be (& $script:module { Get-UDPivotViewFileName -Name 'Per team' })
    }
}

Describe '-Templates and -TemplatePath' {
    It '-Templates: Scope and File; without Scope a deletable entry is the reader''s own (pivotkit''s rule)' {
        $file = ConvertTo-UDPivotViewFile -View $script:view -Name 'From a file'
        $c = New-UDPivotReport -Data $script:rows -Templates @(
            @{ Name = 'Shared'; View = $script:view }
            @{ File = $file }
            @{ Name = 'Renamed'; File = $file; Scope = 'user'; Deletable = $true }
            @{ Name = 'Saved earlier'; View = $script:view; Deletable = $true }
            @{ Name = 'Admins may delete'; View = $script:view; Scope = 'shared'; Deletable = $true }
        )
        $c.templates | ForEach-Object { '{0}|{1}|{2}' -f $_.name, $_.scope, $_.deletable } | Should -Be @('Shared|shared|False', 'From a file|shared|False', 'Renamed|user|True', 'Saved earlier|user|True', 'Admins may delete|shared|True')
        { New-UDPivotReport -Data $script:rows -Templates @(@{ Name = 'X'; View = $script:view; Scope = 'everyone' }) } | Should -Throw '*Scope*'
        { New-UDPivotReport -Data $script:rows -Templates @(@{ Name = 'X'; File = '{"format":"pivotkit-view","formatVersion":9,"view":{}}' }) } | Should -Throw '*"X"*newer*'
    }

    It '-TemplatePath: view files of the folders as read-only shared views; a broken file is left out with a warning' {
        $folder = & $script:newFolder
        New-Item -ItemType Directory -Path $folder | Out-Null
        try {
            Set-Content -LiteralPath (Join-Path $folder 'b.pivotkit.json') -Value (ConvertTo-UDPivotViewFile -View $script:view -Name 'Second')
            Set-Content -LiteralPath (Join-Path $folder 'a.pivotkit.json') -Value '{"rows":["Team"]}'
            Set-Content -LiteralPath (Join-Path $folder 'c.pivotkit.json') -Value 'not json'
            Set-Content -LiteralPath (Join-Path $folder 'other.json') -Value '{"rows":["Team"]}'
            $c = New-UDPivotReport -Data $script:rows -TemplatePath $folder, (Join-Path $folder 'missing') -WarningVariable warnings -WarningAction SilentlyContinue
            # in the order of the file names; a bare view is named after its file
            $c.templates | ForEach-Object { '{0}|{1}|{2}' -f $_.name, $_.scope, $_.deletable } | Should -Be @('a|shared|False', 'Second|shared|False')
            "$warnings" | Should -BeLike '*c.pivotkit.json*'
        }
        finally { Remove-Item -LiteralPath $folder -Recurse -Force }
    }
}

Describe 'New-UDPivotFileTemplateStore' {
    BeforeEach {
        $script:folder = & $script:newFolder
        $script:store = New-UDPivotFileTemplateStore -Path $script:folder -MaxUserViews 2 -MaxSharedViews 1
        $script:invoke = { param([hashtable]$Arguments) & $script:module { param($a) Invoke-UDPivotTemplateStore @a } $Arguments }
    }
    AfterEach { if (Test-Path $script:folder) { Remove-Item -LiteralPath $script:folder -Recurse -Force } }

    It 'keeps each user''s views apart, as view files, and lists them checked' {
        & $script:invoke @{ Store = $script:store; Action = 'Save'; Scope = 'user'; UserName = 'Alex'; Name = 'Mine'; View = $script:view; SourceId = 'tickets' }
        & $script:invoke @{ Store = $script:store; Action = 'Save'; Scope = 'user'; UserName = 'kim'; Name = 'Kims'; View = $script:view }
        @(& $script:invoke @{ Store = $script:store; Action = 'List'; Scope = 'user'; UserName = 'alex' }).Name | Should -Be @('Mine')
        @(& $script:invoke @{ Store = $script:store; Action = 'List'; Scope = 'user'; UserName = 'Kim' }).Name | Should -Be @('Kims')
        $files = @(Get-ChildItem -LiteralPath $script:folder -Recurse -File)
        $files.Count | Should -Be 2
        # the user's name is not in the path; no temporary file is left
        (Get-ChildItem -LiteralPath (Join-Path $script:folder 'users') -Directory).Name | ForEach-Object { $_ | Should -Match '^[0-9a-f]{24}$' }
        $files.Name | ForEach-Object { $_ | Should -BeLike '*.pivotkit.json' }
        $read = ConvertFrom-UDPivotViewFile -InputObject (Get-Content -LiteralPath ($files | Where-Object Name -Like 'mine-*').FullName -Raw)
        $read.Source.id | Should -Be 'tickets'
    }

    It 'replaces a view of the same name, caps the count, and frees a place on delete' {
        $save = { param($Name) & $script:invoke @{ Store = $script:store; Action = 'Save'; Scope = 'user'; UserName = 'alex'; Name = $Name; View = $script:view } }
        & $save 'One'
        & $save 'Two'
        & $save 'One'
        { & $save 'Three' } | Should -Throw '*At most 2*'
        & $script:invoke @{ Store = $script:store; Action = 'Delete'; Scope = 'user'; UserName = 'alex'; Name = 'One' }
        & $save 'Three'
        @(& $script:invoke @{ Store = $script:store; Action = 'List'; Scope = 'user'; UserName = 'alex' }).Name | Sort-Object | Should -Be @('Three', 'Two')
        # deleting what is not there is no error
        & $script:invoke @{ Store = $script:store; Action = 'Delete'; Scope = 'user'; UserName = 'alex'; Name = 'Never saved' }
    }

    It 'keeps the views of two reports apart: the same name twice, each report lists its own and those of no named data' {
        foreach ($source in 'tickets', 'sales') {
            & $script:invoke @{ Store = $script:store; Action = 'Save'; Scope = 'user'; UserName = 'alex'; Name = 'Overview'; View = $script:view; SourceId = $source }
        }
        $userFolder = (Get-ChildItem -LiteralPath (Join-Path $script:folder 'users') -Directory).FullName
        Set-Content -LiteralPath (Join-Path $userFolder 'plain.pivotkit.json') -Value '{"name":"For any data","view":{"rows":["Team"]}}'
        @(Get-ChildItem -LiteralPath $script:folder -Recurse -File).Count | Should -Be 3
        @(& $script:invoke @{ Store = $script:store; Action = 'List'; Scope = 'user'; UserName = 'alex'; SourceId = 'tickets' }).Name | Sort-Object | Should -Be @('For any data', 'Overview')
        & $script:invoke @{ Store = $script:store; Action = 'Delete'; Scope = 'user'; UserName = 'alex'; Name = 'Overview'; SourceId = 'sales' }
        @(& $script:invoke @{ Store = $script:store; Action = 'List'; Scope = 'user'; UserName = 'alex'; SourceId = 'sales' }).Name | Should -Be @('For any data')
        @(& $script:invoke @{ Store = $script:store; Action = 'List'; Scope = 'user'; UserName = 'alex'; SourceId = 'tickets' }).Name | Sort-Object | Should -Be @('For any data', 'Overview')
    }

    It 'stores the checked view, never the input; refuses names and views that do not pass' {
        & $script:invoke @{ Store = $script:store; Action = 'Save'; Scope = 'user'; UserName = 'alex'; Name = 'Evil'; View = @{ rows = @('Team'); script = '$(rm -rf /)' } }
        Get-Content -LiteralPath (Get-ChildItem -LiteralPath $script:folder -Recurse -File).FullName -Raw | Should -Not -Match 'rm -rf'
        { & $script:invoke @{ Store = $script:store; Action = 'Save'; Scope = 'user'; UserName = 'alex'; Name = ''; View = $script:view } } | Should -Throw '*name*'
        { & $script:invoke @{ Store = $script:store; Action = 'Save'; Scope = 'user'; UserName = 'alex'; Name = 'Bad'; View = 'not json' } } | Should -Throw '*JSON*'
        { & $script:invoke @{ Store = $script:store; Action = 'Save'; Scope = 'user'; UserName = ''; Name = 'X'; View = $script:view } } | Should -Throw '*Sign in*'
    }

    It 'skips a stored file that was broken by hand' {
        & $script:invoke @{ Store = $script:store; Action = 'Publish'; Scope = 'shared'; UserName = 'boss'; Name = 'Good'; View = $script:view }
        Set-Content -LiteralPath (Join-Path $script:folder 'shared' 'broken.pivotkit.json') -Value '{"format":"pivotkit-view","formatVersion":1,"name":"B","view":{"rows":"Team"}}'
        @(& $script:invoke @{ Store = $script:store; Action = 'List'; Scope = 'shared' } -WarningAction SilentlyContinue).Name | Should -Be @('Good')
    }

    It 'defaults to a folder next to $Repository, not inside it' {
        # as PSU sets it for the app script (New-UDPivotFileTemplateStore reads it from its caller)
        Set-Variable -Name Repository -Value (Join-Path ([System.IO.Path]::GetTempPath()) 'psu' 'Repository')
        (New-UDPivotFileTemplateStore).Path | Should -Be ([System.IO.Path]::GetFullPath((Join-Path ([System.IO.Path]::GetTempPath()) 'psu' 'pivot-views')))
    }
}

Describe 'New-UDPivotTemplateStore' {
    It 'hands the script blocks checked requests, applies the limits, and publishes through Save without -Publish' {
        $calls = [System.Collections.Generic.List[object]]::new()
        $data = @{}
        $store = New-UDPivotTemplateStore -MaxUserViews 1 -Get {
            param($Request)
            $calls.Add([pscustomobject]@{ Op = 'Get'; Request = $Request })
            $prefix = if ($Request.Scope -eq 'shared') { 'shared/' } else { 'users/{0}/' -f $Request.UserKey }
            $data.Keys | Where-Object { $_.StartsWith($prefix) } | ForEach-Object { $data[$_] }
        } -Save {
            param($Request)
            $calls.Add([pscustomobject]@{ Op = 'Save'; Request = $Request })
            $data[$Request.Key] = $Request.Json
        } -Delete {
            param($Request)
            $data.Remove($Request.Key)
        }
        $invoke = { param([hashtable]$Arguments) & $script:module { param($a) Invoke-UDPivotTemplateStore @a } $Arguments }
        & $invoke @{ Store = $store; Action = 'Save'; Scope = 'user'; UserName = 'Alex'; Name = 'Mine'; View = $script:view }
        $save = ($calls | Where-Object Op -EQ 'Save')[0].Request
        $save.Scope | Should -Be 'user'
        $save.User | Should -Be 'Alex'
        $save.UserKey | Should -Match '^[0-9a-f]{24}$'
        $save.Key | Should -Be ('users/{0}/{1}' -f $save.UserKey, $save.FileName)
        (ConvertFrom-UDPivotViewFile -InputObject $save.Json).Name | Should -Be 'Mine'
        $save.View.rows | Should -Be @('Team')
        { & $invoke @{ Store = $store; Action = 'Save'; Scope = 'user'; UserName = 'alex'; Name = 'Second'; View = $script:view } } | Should -Throw '*At most 1*'
        # the same name again replaces it
        & $invoke @{ Store = $store; Action = 'Save'; Scope = 'user'; UserName = 'alex'; Name = 'Mine'; View = $script:view }
        & $invoke @{ Store = $store; Action = 'Publish'; Scope = 'user'; UserName = 'boss'; Name = 'For all'; View = $script:view }
        $data.Keys | Where-Object { $_ -like 'shared/*' } | Should -HaveCount 1
        @(& $invoke @{ Store = $store; Action = 'List'; Scope = 'shared' }).Name | Should -Be @('For all')
        & $invoke @{ Store = $store; Action = 'Delete'; Scope = 'shared'; Name = 'For all' }
        @(& $invoke @{ Store = $store; Action = 'List'; Scope = 'shared' }).Count | Should -Be 0
    }

    It 'calls -Publish for shared views when given, and checks what Get returns' {
        $published = [System.Collections.Generic.List[object]]::new()
        $store = New-UDPivotTemplateStore -Get { '{"name":"Ok","view":{"rows":["Team"]}}'; 'not json'; [pscustomobject]@{ Name = 'Obj'; View = @{ rows = @('Team') } } } -Save { throw 'no save' } -Delete { } -Publish { param($Request) $published.Add($Request) }
        $invoke = { param([hashtable]$Arguments) & $script:module { param($a) Invoke-UDPivotTemplateStore @a } $Arguments }
        & $invoke @{ Store = $store; Action = 'Publish'; Scope = 'shared'; UserName = 'boss'; Name = 'P'; View = $script:view }
        $published[0].Scope | Should -Be 'shared'
        $published[0].User | Should -Be 'boss'
        @(& $invoke @{ Store = $store; Action = 'List'; Scope = 'shared' } -WarningAction SilentlyContinue).Name | Should -Be @('Ok', 'Obj')
        { & $invoke @{ Store = $store; Action = 'Save'; Scope = 'user'; UserName = 'alex'; Name = 'S'; View = $script:view } } | Should -Throw '*no save*'
    }
}

# pivotkit 0.2.0's Save sends the name of a stored view (onSaveTemplate, onPublishTemplate): the store
# replaces that view, never adds a second one. Each case runs against the file store, a custom store
# whose Get returns FileName and Json, and one whose Get returns only the Json (the Valkey and S3 sketches).
Describe 'Save over a stored view (upsert by name): <Kind> store' -ForEach @(@{ Kind = 'File' }, @{ Kind = 'Custom' }, @{ Kind = 'CustomJsonOnly' }) {
    BeforeEach {
        $script:folder = & $script:newFolder
        # the custom store keeps view files in memory by Key, and Get returns where each one is stored
        $script:data = [System.Collections.Generic.Dictionary[string, string]]::new()
        $data = $script:data
        $withFileName = $Kind -eq 'Custom'
        $script:store = if ($Kind -eq 'File') { New-UDPivotFileTemplateStore -Path $script:folder } else {
            New-UDPivotTemplateStore -Get {
                param($Request)
                $prefix = if ($Request.Scope -eq 'shared') { 'shared/' } else { 'users/{0}/' -f $Request.UserKey }
                foreach ($k in @($data.Keys | Where-Object { $_.StartsWith($prefix) } | Sort-Object)) {
                    if ($withFileName) { [pscustomobject]@{ FileName = $k.Substring($prefix.Length); Json = $data[$k] } } else { $data[$k] }
                }
            }.GetNewClosure() -Save { param($Request) $data[$Request.Key] = $Request.Json } -Delete { param($Request) $null = $data.Remove($Request.Key) }
        }
        $script:invoke = { param([hashtable]$Arguments) & $script:module { param($a) Invoke-UDPivotTemplateStore @a } $Arguments }
        $script:save = { param($Name, $View = $script:view, $User = 'alex', $SourceId = 'tickets') & $script:invoke @{ Store = $script:store; Action = 'Save'; Scope = 'user'; UserName = $User; Name = $Name; View = $View; SourceId = $SourceId } }
        $script:names = { param($User = 'alex', $SourceId = 'tickets') @(& $script:invoke @{ Store = $script:store; Action = 'List'; Scope = 'user'; UserName = $User; SourceId = $SourceId } | ForEach-Object Name | Sort-Object -CaseSensitive) }
        # what is stored: file names of the file store, keys of the custom store
        $script:stored = {
            if ($Kind -eq 'File') { @(Get-ChildItem -LiteralPath $script:folder -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { [System.IO.Path]::GetRelativePath($script:folder, $_.FullName) -replace '\\', '/' }) }
            else { @($script:data.Keys) }
        }
        $script:readStored = { param($Key) if ($Kind -eq 'File') { Get-Content -LiteralPath (Join-Path $script:folder $Key) -Raw } else { $script:data[$Key] } }
        # puts a view file where an older version or a hand placed it
        $script:place = {
            param($Key, $Json)
            if ($Kind -eq 'File') { $path = Join-Path $script:folder $Key; $null = New-Item -ItemType Directory -Path (Split-Path $path) -Force; Set-Content -LiteralPath $path -Value $Json -NoNewline }
            else { $script:data[$Key] = $Json }
        }
        $script:userKey = { param($User = 'alex') & $script:module { param($u) Get-UDPivotSha256 -Text $u -Length 24 } $User }
        # a view file as version 0.1.0 wrote it, at the key 0.1.0 gave it (a hash of the name in lower case)
        $script:placeLegacy = {
            param($Name, $View = $script:view)
            $key = 'users/{0}/{1}' -f (& $script:userKey), (& $script:module { param($n) Get-UDPivotViewFileName -Name $n -SourceId 'tickets' -Legacy } $Name)
            $json = (ConvertTo-UDPivotViewFile -View $View -Name $Name -SourceId 'tickets') -replace '("generator": \{\s*"name": "PowerShellUniversal\.Component\.Pivot",\s*"version": )"[^"]*"', '$1"0.1.0"'
            $json | Should -Match '"version": "0\.1\.0"'
            & $script:place $key $json
            $key
        }
        $script:other = @{ rows = @('Team'); cols = @('Hours'); values = @(@{ field = 'Hours'; agg = 'count' }) }
    }
    AfterEach { if (Test-Path $script:folder) { Remove-Item -LiteralPath $script:folder -Recurse -Force } }

    It 'saves a new view' {
        & $script:save 'Overview'
        & $script:names | Should -Be @('Overview')
        @(& $script:stored).Count | Should -Be 1
    }

    It 'replaces the reader''s own view of the name in place: one entry, the new view' {
        & $script:save 'Overview'
        $before = @(& $script:stored)
        & $script:save 'Overview' $script:other
        & $script:names | Should -Be @('Overview')
        @(& $script:stored) | Should -Be $before
        (ConvertFrom-UDPivotViewFile -InputObject (& $script:readStored $before[0])).View.cols | Should -Be @('Hours')
    }

    It 'replaces a shared view of the name when an admin publishes over it (Save on a shared view)' {
        $report = New-UDPivotReport -Id 'tickets' -Data $script:rows -TemplateStore $script:store -AdminRole 'Admin' -UserName 'boss' -Roles 'Admin'
        $key = & $script:keyOf $report.onPublishTemplate
        Invoke-UDPivotTemplateRequest -Key $key -Action Publish -EventData @{ name = 'Team view'; view = $script:view } -UserName 'boss' -Roles 'Admin' | Should -BeNullOrEmpty
        # another admin saves over it
        Invoke-UDPivotTemplateRequest -Key $key -Action Publish -EventData @{ name = 'Team view'; view = $script:other } -UserName 'kim' -Roles 'Admin' | Should -BeNullOrEmpty
        $shared = @(& $script:stored | Where-Object { $_ -like 'shared/*' })
        $shared.Count | Should -Be 1
        (ConvertFrom-UDPivotViewFile -InputObject (& $script:readStored $shared[0])).View.cols | Should -Be @('Hours')
        $again = New-UDPivotReport -Id 'tickets' -Data $script:rows -TemplateStore $script:store -AdminRole 'Admin' -UserName 'alex' -Roles 'Reader'
        @($again.templates | ForEach-Object { '{0}|{1}' -f $_.name, $_.scope }) | Should -Be @('Team view|shared')
    }

    It 'keeps two users'' views of the same name apart' {
        & $script:save 'Overview' $script:view 'alex'
        & $script:save 'Overview' $script:view 'kim'
        & $script:save 'Overview' $script:other 'alex'
        & $script:names 'alex' | Should -Be @('Overview')
        & $script:names 'kim' | Should -Be @('Overview')
        @(& $script:stored).Count | Should -Be 2
        $kim = @(& $script:invoke @{ Store = $script:store; Action = 'List'; Scope = 'user'; UserName = 'kim'; SourceId = 'tickets' })
        $kim[0].View.PSObject.Properties.Name | Should -Not -Contain 'cols'
    }

    It 'matches names as pivotkit does: the same characters in the same case, after trimming' {
        & $script:save 'Sales'
        & $script:save 'sales'
        & $script:names | Should -Be @('sales', 'Sales')
        # pivotkit trims a name it saves; the module makes it plain text the same way
        & $script:save ' Sales ' $script:other
        & $script:names | Should -Be @('sales', 'Sales')
        @(& $script:stored).Count | Should -Be 2
        & $script:invoke @{ Store = $script:store; Action = 'Delete'; Scope = 'user'; UserName = 'alex'; Name = 'sales'; SourceId = 'tickets' }
        & $script:names | Should -Be @('Sales')
    }

    It 'replaces a view stored under another file name (version 0.1.0, by hand) and never writes over it with another name' {
        # 0.1.0 named the file after a hash of the name in lower case
        $legacy = & $script:placeLegacy 'Sales'
        & $script:save 'Sales' $script:other
        $stored = @(& $script:stored)
        $stored.Count | Should -Be 1
        # in its place when the store says where that is; a store that does not moves it (and removes the old one)
        if ($Kind -ne 'CustomJsonOnly') { $stored | Should -Be @($legacy) }
        & $script:save 'sales'
        @(& $script:stored).Count | Should -Be 2
        & $script:names | Should -Be @('sales', 'Sales')
        $sales = @(& $script:invoke @{ Store = $script:store; Action = 'List'; Scope = 'user'; UserName = 'alex'; SourceId = 'tickets' } | Where-Object Name -CEQ 'Sales')
        $sales[0].View.cols | Should -Be @('Hours')
    }

    # a store whose Get does not say where a view is cannot replace one stored elsewhere (documented)
    It 'deletes a view of version 0.1.0 whose old key a new view of the name in another case shares' {
        & $script:placeLegacy 'Sales'
        & $script:save 'sales'
        & $script:names | Should -Be @('sales', 'Sales')
        & $script:invoke @{ Store = $script:store; Action = 'Delete'; Scope = 'user'; UserName = 'alex'; Name = 'Sales'; SourceId = 'tickets' }
        & $script:names | Should -Be @('sales')
        @(& $script:stored).Count | Should -Be 1
    }

    It 'replaces a view made for no named data in place, and it stays one; leaves one of a view stored twice' {
        if ($Kind -eq 'CustomJsonOnly') {
            Set-ItResult -Skipped -Because 'a store whose -Get returns no FileName cannot say where a view put there by hand is stored, so it cannot replace it there (documented on docs/pivot/templates.md)'
            return
        }
        $plain = 'users/{0}/plain.pivotkit.json' -f (& $script:userKey)
        & $script:place $plain '{"name":"For any data","view":{"rows":["Team"]}}'
        & $script:save 'For any data' $script:other
        @(& $script:stored) | Should -Be @($plain)
        $read = ConvertFrom-UDPivotViewFile -InputObject (& $script:readStored $plain)
        $read.View.cols | Should -Be @('Hours')
        $read.Source.id | Should -BeNullOrEmpty
        & $script:names 'alex' 'sales' | Should -Be @('For any data')

        # two copies of a view (copied by hand): a save leaves one
        & $script:place ('users/{0}/copy-1.pivotkit.json' -f (& $script:userKey)) (ConvertTo-UDPivotViewFile -View $script:view -Name 'Twice' -SourceId 'tickets')
        & $script:place ('users/{0}/copy-2.pivotkit.json' -f (& $script:userKey)) (ConvertTo-UDPivotViewFile -View $script:view -Name 'Twice' -SourceId 'tickets')
        & $script:save 'Twice' $script:other
        @(& $script:stored | Where-Object { $_ -like '*copy-*' }).Count | Should -Be 1
        & $script:names | Should -Be @('For any data', 'Twice')
    }
}

Describe 'A custom store whose -Delete fails for a missing key' {
    BeforeEach {
        $script:data = [System.Collections.Generic.Dictionary[string, string]]::new()
        $script:refuseAll = $false
        $script:store = New-UDPivotTemplateStore -Get {
            param($Request)
            $prefix = 'users/{0}/' -f $Request.UserKey
            foreach ($k in @($script:data.Keys | Where-Object { $_.StartsWith($prefix) })) { $script:data[$k] }
        } -Save { param($Request) $script:data[$Request.Key] = $Request.Json } -Delete {
            param($Request)
            if ($script:refuseAll -or -not $script:data.ContainsKey($Request.Key)) { throw "no such key: $($Request.Key)" }
            $null = $script:data.Remove($Request.Key)
        }
        $script:run = { param([hashtable]$a) & $script:module { param($x) Invoke-UDPivotTemplateStore @x } (@{ Store = $script:store; Scope = 'user'; UserName = 'alex'; SourceId = 'tickets' } + $a) }
        $script:names = { @(& $script:run @{ Action = 'List' } | ForEach-Object Name | Sort-Object -CaseSensitive) }
        # a view file as version 0.1.0 wrote it, at the key 0.1.0 gave it
        $script:legacy = {
            param($Name)
            $key = 'users/{0}/{1}' -f (& $script:module { Get-UDPivotSha256 -Text 'alex' -Length 24 }), (& $script:module { param($n) Get-UDPivotViewFileName -Name $n -SourceId 'tickets' -Legacy } $Name)
            $script:data[$key] = (ConvertTo-UDPivotViewFile -View $script:view -Name $Name -SourceId 'tickets') -replace '("generator": \{\s*"name": "PowerShellUniversal\.Component\.Pivot",\s*"version": )"[^"]*"', '$1"0.1.0"'
        }
    }

    It 'a save that worked is no error when a cleanup delete fails: a warning' {
        & $script:legacy 'Sales'
        $script:refuseAll = $true
        $warned = @(& $script:run @{ Action = 'Save'; Name = 'Sales'; View = $script:view } 3>&1 | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        "$warned" | Should -BeLike '*could not be removed*'
        & $script:names | Should -Contain 'Sales'
    }

    It 'deletes a view of this version (its one key) and one of 0.1.0 (one of the keys it may be under) without an error' {
        & $script:run @{ Action = 'Save'; Name = 'New one'; View = $script:view }
        $warnedNew = @(& $script:run @{ Action = 'Delete'; Name = 'New one' } 3>&1 | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $warnedNew | Should -BeNullOrEmpty
        & $script:legacy 'Old One'
        $null = & $script:run @{ Action = 'Delete'; Name = 'Old One' } 3>&1
        & $script:names | Should -BeNullOrEmpty
        $script:data.Count | Should -Be 0
    }

    It 'a delete that removed nothing is the error the reader sees' {
        & $script:run @{ Action = 'Save'; Name = 'Kept'; View = $script:view }
        $script:refuseAll = $true
        { & $script:run @{ Action = 'Delete'; Name = 'Kept' } } | Should -Throw '*no such key*'
    }
}

Describe 'New-UDPivotReport -TemplateStore and -AdminRole' {
    BeforeEach {
        $script:folder = & $script:newFolder
        $script:store = New-UDPivotFileTemplateStore -Path $script:folder
    }
    AfterEach { if (Test-Path $script:folder) { Remove-Item -LiteralPath $script:folder -Recurse -Force } }

    It 'a reader: own views on the server, shared views read-only, no publish, no admin panel' {
        $c = New-UDPivotReport -Id 'r' -Data $script:rows -TemplateStore $script:store -AdminRole 'Admin' -UserName 'alex' -Roles 'Reader'
        $c.onSaveTemplate.RegisteredId | Should -Be 'r-onSaveTemplate'
        $c.onDeleteTemplate.RegisteredId | Should -Be 'r-onDeleteTemplate'
        $c.ContainsKey('onPublishTemplate') | Should -BeFalse
        $c.ContainsKey('canPublish') | Should -BeFalse
        $c.ContainsKey('admin') | Should -BeFalse
        $c.ContainsKey('templateStore') | Should -BeFalse
        # the handler is code with the store's key; it loads the module and passes the event's user and roles
        $code = $c.onSaveTemplate.ScriptBlock.ToString()
        $code | Should -Match 'Import-Module PowerShellUniversal\.Component\.Pivot'
        $code | Should -Match 'Invoke-UDPivotTemplateRequest -Key ''[0-9a-f]{32}'' -Action Save'
        $code | Should -Match 'Get-Variable -Name User'
    }

    It 'the event handlers decide on the server: own views for a signed-in user, shared views for -AdminRole only' {
        $reader = New-UDPivotReport -Id 'r' -Data $script:rows -TemplateStore $script:store -AdminRole 'Admin' -UserName 'alex' -Roles 'Reader'
        $key = & $script:keyOf $reader.onSaveTemplate
        Invoke-UDPivotTemplateRequest -Key $key -Action Save -EventData @{ name = 'Mine'; view = $script:view } -UserName 'alex' -Roles 'Reader' | Should -BeNullOrEmpty
        (Invoke-UDPivotTemplateRequest -Key $key -Action Save -EventData @{ name = 'Mine'; view = $script:view } -UserName '' -Roles @()).error | Should -BeLike '*Sign in*'
        # a reader who sends a publish or a delete of a shared view anyway is refused
        (Invoke-UDPivotTemplateRequest -Key $key -Action Publish -EventData @{ name = 'Mine'; view = $script:view } -UserName 'alex' -Roles 'Reader').error | Should -Be 'Only admins can change shared views.'
        Invoke-UDPivotTemplateRequest -Key $key -Action Publish -EventData @{ name = 'Team view'; view = $script:view } -UserName 'boss' -Roles 'admin' | Should -BeNullOrEmpty
        (Invoke-UDPivotTemplateRequest -Key $key -Action Delete -EventData @{ name = 'Team view'; scope = 'shared' } -UserName 'alex' -Roles 'Reader').error | Should -Be 'Only admins can change shared views.'
        Test-Path (Join-Path $script:folder 'shared') | Should -BeTrue
        @(Get-ChildItem (Join-Path $script:folder 'shared')).Count | Should -Be 1
        # a broken view comes back as the error the reader sees
        (Invoke-UDPivotTemplateRequest -Key $key -Action Save -EventData @{ name = 'Bad'; view = 'not json' } -UserName 'alex' -Roles 'Reader').error | Should -BeLike '*JSON*'
        (Invoke-UDPivotTemplateRequest -Key ('0' * 32) -Action Save -EventData @{ name = 'X'; view = $script:view } -UserName 'alex').error | Should -BeLike '*reload*'

        # the next render lists them, the shared ones deletable for admins only
        $again = New-UDPivotReport -Id 'r' -Data $script:rows -TemplateStore $script:store -AdminRole 'Admin' -UserName 'alex' -Roles 'Reader'
        $again.templates | ForEach-Object { '{0}|{1}|{2}' -f $_.name, $_.scope, $_.deletable } | Should -Be @('Team view|shared|False', 'Mine|user|True')
        $admin = New-UDPivotReport -Id 'r' -Data $script:rows -TemplateStore $script:store -AdminRole 'Admin' -UserName 'boss' -Roles 'ADMIN'
        $admin.templates | ForEach-Object { '{0}|{1}|{2}' -f $_.name, $_.scope, $_.deletable } | Should -Be @('Team view|shared|True')
        $admin.canPublish | Should -BeTrue
        $admin.onPublishTemplate.RegisteredId | Should -Be 'r-onPublishTemplate'
        $admin.admin.store | Should -Be 'File'
        $admin.admin.rows | Should -Be 1
        $admin.admin.templates | Should -Be 1
        Invoke-UDPivotTemplateRequest -Key (& $script:keyOf $admin.onDeleteTemplate) -Action Delete -EventData @{ name = 'Team view'; scope = 'shared' } -UserName 'boss' -Roles 'Admin' | Should -BeNullOrEmpty
        @(Get-ChildItem (Join-Path $script:folder 'shared')).Count | Should -Be 0
    }

    It 'without a signed-in user: own views in the browser, shared views from the store' {
        $c = New-UDPivotReport -Id 'anon' -Data $script:rows -TemplateStore $script:store -AdminRole 'Admin' -UserName '' -Roles @()
        $c.templateStore | Should -Be 'browser'
        $c.ContainsKey('onSaveTemplate') | Should -BeFalse
        $c.ContainsKey('onDeleteTemplate') | Should -BeFalse
        $c.templates.Count | Should -Be 0
    }

    It 'reads $User and $Roles of the caller when they are not passed' {
        # as PSU sets them for page code
        Set-Variable -Name User -Value 'alex'
        Set-Variable -Name Roles -Value @('Admin')
        $c = New-UDPivotReport -Id 'caller' -Data $script:rows -TemplateStore $script:store -AdminRole 'Admin'
        $c.canPublish | Should -BeTrue
        $c.ContainsKey('templateStore') | Should -BeFalse
    }

    It 'a shared view of the store wins over a -TemplatePath file of the same name, so a published change shows' {
        $files = & $script:newFolder
        New-Item -ItemType Directory -Path $files | Out-Null
        try {
            $shipped = @{ rows = @('Team'); values = @(@{ field = 'Hours'; agg = 'count' }) }
            Set-Content -LiteralPath (Join-Path $files 'a.pivotkit.json') -Value (ConvertTo-UDPivotViewFile -View $shipped -Name 'Team view')
            Set-Content -LiteralPath (Join-Path $files 'b.pivotkit.json') -Value (ConvertTo-UDPivotViewFile -View $shipped -Name 'team view')
            Set-Content -LiteralPath (Join-Path $files 'c.pivotkit.json') -Value (ConvertTo-UDPivotViewFile -View $shipped -Name 'Only in the file')
            $render = { New-UDPivotReport -Id 'r' -Data $script:rows -TemplatePath $files -TemplateStore $script:store -AdminRole 'Admin' -UserName 'boss' -Roles 'Admin' }
            $before = & $render
            $before.templates | ForEach-Object { '{0}|{1}|{2}' -f $_.name, $_.scope, $_.deletable } | Should -Be @('Team view|shared|False', 'team view|shared|False', 'Only in the file|shared|False')

            # an admin publishes a change of the shipped view under its name (Save on a shared view)
            Invoke-UDPivotTemplateRequest -Key (& $script:keyOf $before.onPublishTemplate) -Action Publish -EventData @{ name = 'Team view'; view = $script:view } -UserName 'boss' -Roles 'Admin' | Should -BeNullOrEmpty
            $after = & $render
            # one entry of the name, the store's in the file's place (deletable for the admin, with the
            # published view); names compare as in pivotkit's Views menu, so "team view" is another view
            $after.templates | ForEach-Object { '{0}|{1}|{2}' -f $_.name, $_.scope, $_.deletable } | Should -Be @('Team view|shared|True', 'team view|shared|False', 'Only in the file|shared|False')
            $published = @($after.templates | Where-Object name -CEQ 'Team view')
            $published.view.values[0].agg | Should -Be 'sum'
            # a reader sees the same single entry, read-only
            $reader = New-UDPivotReport -Id 'r' -Data $script:rows -TemplatePath $files -TemplateStore $script:store -AdminRole 'Admin' -UserName 'alex' -Roles 'Reader'
            @($reader.templates | Where-Object name -CEQ 'Team view').Count | Should -Be 1
            # once the admin deletes the store's view, the shipped file is offered again
            Invoke-UDPivotTemplateRequest -Key (& $script:keyOf $after.onDeleteTemplate) -Action Delete -EventData @{ name = 'Team view'; scope = 'shared' } -UserName 'boss' -Roles 'Admin' | Should -BeNullOrEmpty
            (& $render).templates | ForEach-Object { '{0}|{1}|{2}' -f $_.name, $_.scope, $_.deletable } | Should -Be @('Team view|shared|False', 'team view|shared|False', 'Only in the file|shared|False')
        }
        finally { Remove-Item -LiteralPath $files -Recurse -Force }
    }

    It 'a shared view the store keeps for other data does not hide a -TemplatePath file of the same name' {
        $files = & $script:newFolder
        New-Item -ItemType Directory -Path $files | Out-Null
        try {
            Set-Content -LiteralPath (Join-Path $files 'a.pivotkit.json') -Value (ConvertTo-UDPivotViewFile -View $script:view -Name 'Team view')
            $sales = New-UDPivotReport -Id 'sales' -Data $script:rows -TemplateStore $script:store -AdminRole 'Admin' -UserName 'boss' -Roles 'Admin'
            Invoke-UDPivotTemplateRequest -Key (& $script:keyOf $sales.onPublishTemplate) -Action Publish -EventData @{ name = 'Team view'; view = $script:view } -UserName 'boss' -Roles 'Admin' | Should -BeNullOrEmpty
            $tickets = New-UDPivotReport -Id 'tickets' -Data $script:rows -TemplatePath $files -TemplateStore $script:store -AdminRole 'Admin' -UserName 'boss' -Roles 'Admin'
            $tickets.templates | ForEach-Object { '{0}|{1}|{2}' -f $_.name, $_.scope, $_.deletable } | Should -Be @('Team view|shared|False')
        }
        finally { Remove-Item -LiteralPath $files -Recurse -Force }
    }

    It '-TemplateStore Browser, and the combinations it refuses' {
        (New-UDPivotReport -Data $script:rows -TemplateStore Browser).templateStore | Should -Be 'browser'
        { New-UDPivotReport -Data $script:rows -TemplateStore 'Disk' } | Should -Throw '*TemplateStore*'
        { New-UDPivotReport -Data $script:rows -TemplateStore $script:store -UserName 'a' -OnSaveTemplate ([Endpoint]::new({ 1 })) } | Should -Throw '*-OnSaveTemplate*'
        { New-UDPivotReport -Data $script:rows -OnPublishTemplate ([Endpoint]::new({ 1 })) } | Should -Throw '*-AdminRole*'
        # custom events with -AdminRole: publish only for the role
        $own = New-UDPivotReport -Id 'own' -Data $script:rows -AdminRole 'Admin' -UserName 'boss' -Roles 'Admin' -OnSaveTemplate ([Endpoint]::new({ 1 })) -OnPublishTemplate ([Endpoint]::new({ 2 }))
        $own.canPublish | Should -BeTrue
        $own.onPublishTemplate.RegisteredId | Should -Be 'own-onPublishTemplate'
        $none = New-UDPivotReport -Id 'own' -Data $script:rows -AdminRole 'Admin' -UserName 'alex' -Roles 'Reader' -OnSaveTemplate ([Endpoint]::new({ 1 })) -OnPublishTemplate ([Endpoint]::new({ 2 }))
        $none.ContainsKey('canPublish') | Should -BeFalse
    }
}

Describe 'New-UDPivotReport: source, view files and switches' {
    It '-SourceId, -SourceName (default -Id and -Label) and -SchemaUrl' {
        $c = New-UDPivotReport -Id 'tickets' -Data $script:rows -Label 'Tickets per team'
        $c.source.id | Should -Be 'tickets'
        $c.source.name | Should -Be 'Tickets per team'
        $c.ContainsKey('schemaUrl') | Should -BeFalse
        $c = New-UDPivotReport -Id 'tickets' -Data $script:rows -SourceId 'sales' -SourceName 'Sales 2026' -SchemaUrl ''
        $c.source.id | Should -Be 'sales'
        $c.source.name | Should -Be 'Sales 2026'
        $c.schemaUrl | Should -Be ''
        (New-UDPivotReport -Data $script:rows -SchemaUrl 'https://example.org/view-file-1.json').schemaUrl | Should -Be 'https://example.org/view-file-1.json'
        { New-UDPivotReport -Data $script:rows -SchemaUrl 'http://example.org/s.json' } | Should -Throw '*SchemaUrl*'
        { New-UDPivotReport -Data $script:rows -SchemaUrl 'javascript:alert(1)' } | Should -Throw '*SchemaUrl*'
    }

    It '-SettingInfo, -FieldList and -Grow' {
        $c = New-UDPivotReport -Data $script:rows -SettingInfo Off -FieldList Collapsed -Grow On
        $c.settingInfo | Should -Be 'off'
        $c.fieldList | Should -Be 'collapsed'
        $c.grow | Should -Be 'on'
        $plain = New-UDPivotReport -Data $script:rows
        foreach ($key in 'settingInfo', 'fieldList', 'grow', 'templateStore', 'canPublish', 'admin') { $plain.ContainsKey($key) | Should -BeFalse -Because $key }
        { New-UDPivotReport -Data $script:rows -FieldList Hidden } | Should -Throw
    }
}

Describe 'How ids and names are built (docs/pivot/templates.md#ids)' {
    BeforeAll {
        $script:idsDoc = Get-Content -Raw -LiteralPath (Join-Path $script:repo 'docs' 'pivot' 'templates.md')
    }

    It 'the snippet that finds a reader''s folder names the folder the file store writes' {
        $code = [regex]::Match($script:idsDoc, '(?s)To find a reader''s folder.*?```powershell\r?\n(.*?)```').Groups[1].Value
        $code | Should -Match 'CONTOSO\\Alex'
        $store = New-UDPivotFileTemplateStore -Path (& $script:newFolder)
        try {
            # the same user in another case and with spaces around it: one folder
            & $script:module { param($s, $v) Invoke-UDPivotTemplateStore -Store $s -Action Save -Scope user -UserName ' contoso\ALEX ' -Name 'Per team' -View $v } $store $script:view | Out-Null
            $written = @(Get-ChildItem -LiteralPath (Join-Path $store.Path 'users') -Directory)
            $written.Count | Should -Be 1
            $shown = & ([scriptblock]::Create($code))
            $shown | Should -Be (Join-Path $store.Path 'users' $written[0].Name)
            $written[0].Name | Should -Match '^[0-9a-f]{24}$'
            $script:idsDoc | Should -Match ([regex]::Escape(('users/{0}` for `CONTOSO\Alex`' -f $written[0].Name)))
        }
        finally { Remove-Item -LiteralPath $store.Path -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'the file names in the table are the ones the store gives' {
        $names = & $script:module {
            Get-UDPivotViewFileName -Name ("Umsatz je Region ({0})" -f [char]0xDC) -SourceId 'tickets'
            Get-UDPivotViewFileName -Name ("Umsatz je Region ({0})" -f [char]0xDC) -SourceId 'tickets' -Attempt 1
            Get-UDPivotViewFileName -Name ("Umsatz je Region ({0})" -f [char]0xDC) -SourceId 'tickets' -Legacy
        }
        foreach ($name in $names) { $script:idsDoc | Should -Match ([regex]::Escape($name)) }
    }
}
