#Requires -Version 7.4
# Pester tests for helpers the commands of PowerShellUniversal.Component.Pivot share: the admin panel
# after the split (#163), and what a failed request leaves in $Error. The files of the split modules:
# ModuleFiles.Tests.ps1. PSU's [Endpoint] type is a stub.

BeforeAll {
    . (Join-Path $PSScriptRoot '..' '..' 'build' 'Add-EndpointType.ps1')
    $script:repo = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $script:folder = Join-Path $script:repo 'modules' 'PowerShellUniversal.Component.Pivot'
    $script:module = Import-Module (Join-Path $script:folder 'PowerShellUniversal.Component.Pivot.psm1') -Force -PassThru
    & $script:module { $Script:AssetId = 'asset-under-test' }
}

Describe 'New-UDPivotReport: the admin panel' {
    It 'counts the templates the report gets: none, and three' {
        $views = @(foreach ($i in 1..3) { @{ Name = "View $i"; View = @{ rows = @('A') } } })
        foreach ($case in @{ Templates = @(); Count = 0 }, @{ Templates = $views; Count = 3 }) {
            $c = New-UDPivotReport -Data @([pscustomobject]@{ A = 1 }) -Templates $case.Templates -AdminRole 'Admin' -Roles 'Admin'
            $c.admin.templates | Should -Be $case.Count
        }
    }

    It 'takes an empty -Id' {
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
        try { throw 'a second error caught' } catch { & $script:module { param($Record) Remove-UDPivotErrorRecord -ErrorRecord $Record } $_ }
        $global:Error.Count | Should -Be 2 -Because 'the newest record was the error caught'
    }
}
