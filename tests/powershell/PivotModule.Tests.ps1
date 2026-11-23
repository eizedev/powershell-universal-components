#Requires -Version 7.4
# Pester tests for the files of PowerShellUniversal.Component.Pivot and the helpers its commands share:
# one file per exported command, the helpers that read a public command's parameters (#163), and what a
# failed request leaves in $Error. PSU's [Endpoint] type is a stub.

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
    $script:folder = Join-Path $script:repo 'modules' 'PowerShellUniversal.Component.Pivot'
    $script:module = Import-Module (Join-Path $script:folder 'PowerShellUniversal.Component.Pivot.psm1') -Force -PassThru
    & $script:module { $Script:AssetId = 'asset-under-test' }
}

Describe 'The files of the pivot module' {
    It 'has one file in Public/ per exported command and no other' {
        $manifest = Import-PowerShellDataFile (Join-Path $script:folder 'PowerShellUniversal.Component.Pivot.psd1')
        $files = Get-ChildItem -LiteralPath (Join-Path $script:folder 'Public') -Filter '*.ps1' -File
        ($files.BaseName | Sort-Object) | Should -Be ($manifest.FunctionsToExport | Sort-Object) -Because 'a file in Public/ is exported only when FunctionsToExport names it'
    }

    It 'a helper reads only parameters the public commands have from -Bound' {
        # the helpers get a public command's $PSBoundParameters as -Bound; a misspelled key would read $null.
        # Checked: literal keys of $Bound['X'], $Bound.ContainsKey('X') and $Bound.Keys -contains 'X', against
        # the parameters of all public commands (not only the caller's); keys in variables are not checked.
        $names = foreach ($command in Get-Command -Module $script:module.Name) { $command.Parameters.Keys }
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $script:folder 'Private') -Filter '*.ps1' -File) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $keys = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.IndexExpressionAst] -and $n.Target.Extent.Text -eq '$Bound' -and $n.Index -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object { $_.Index.Value })
            $keys += @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Expression.Extent.Text -eq '$Bound' -and $n.Member.Extent.Text -eq 'ContainsKey' -and $n.Arguments[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object { $_.Arguments[0].Value })
            $keys += @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.BinaryExpressionAst] -and $n.Operator -eq 'Icontains' -and $n.Left.Extent.Text -eq '$Bound.Keys' -and $n.Right -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object { $_.Right.Value })
            foreach ($key in $keys) { $names | Should -Contain $key -Because "$($file.Name) reads `$Bound['$key']" }
        }
    }
}

Describe 'New-UDPivotReport: the admin panel' {
    It 'counts the templates the report gets: none, and three' {
        $views = @(foreach ($i in 1..3) { @{ Name = "View $i"; View = @{ rows = @('A') } } })
        foreach ($case in @{ Templates = @(); Count = 0 }, @{ Templates = $views; Count = 3 }) {
            $c = New-UDPivotReport -Data @([pscustomobject]@{ A = 1 }) -Templates $case.Templates -AdminRole 'Admin' -Roles 'Admin'
            $c.admin.templates | Should -Be $case.Count
        }
    }

    It 'takes an empty -Id, as before the split' {
        $c = New-UDPivotReport -Id '' -Data @([pscustomobject]@{ A = 1 })
        $c.id | Should -Be ''
    }
}

Describe 'Remove-UDPivotErrorRecord: what a failed request leaves in $Error' {
    It 'two failed calls in a row: $Error keeps the caller''s records and gains only the two errors thrown' {
        # Remove-UDPivotErrorRecord removes the newest record only when it is the one caught; the
        # caller's own record below it stays, also on the second call
        $closed = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $closed.Start(); $deadPort = $closed.LocalEndpoint.Port; $closed.Stop()
        $global:Error.Clear()
        Write-Error 'the caller''s own error' -ErrorAction SilentlyContinue
        $own = $global:Error[0]
        foreach ($i in 1, 2) {
            try { Invoke-UDPivotReport -Engine Rest -Uri ('http://127.0.0.1:{0}/api/v1' -f $deadPort) -Token 'static-token-0123456789' -Data @([pscustomobject]@{ A = 1 }) -View @{ rows = @('A') } } catch { $null = $_ }
        }
        $global:Error.Count | Should -Be 3
        @($global:Error[0..1].FullyQualifiedErrorId) | Should -Be @('PivotServerUnreachable', 'PivotServerUnreachable')
        [object]::ReferenceEquals($global:Error[2], $own) | Should -BeTrue
        ($global:Error | ForEach-Object { $_ | Format-List * -Force | Out-String }) -join '' | Should -Not -BeLike '*static-token-0123456789*'
    }

    It 'removes the newest record only when it is the error caught' {
        $global:Error.Clear()
        try { throw 'the error caught' } catch { $caught = $_ }
        Write-Error 'an error that came after it' -ErrorAction SilentlyContinue
        & $script:module { param($Record) Remove-UDPivotErrorRecord -ErrorRecord $Record } $caught
        $global:Error.Count | Should -Be 2 -Because 'the newest record is another error'
        try { throw 'the error caught' } catch { & $script:module { param($Record) Remove-UDPivotErrorRecord -ErrorRecord $Record } $_ }
        $global:Error.Count | Should -Be 2 -Because 'the newest record was the error caught'
    }
}
