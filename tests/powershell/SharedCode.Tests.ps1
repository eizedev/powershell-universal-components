#Requires -Version 7.4
# Pester tests for build/Copy-SharedCode.ps1: what a built component module carries of shared/.

BeforeAll {
    $script:repo = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $script:shared = Join-Path $script:repo 'shared'
    $script:copy = Join-Path $script:repo 'build' 'Copy-SharedCode.ps1'

    # Private/ of a built module must hold exactly shared/powershell/*.ps1, byte for byte, plus SHARED.txt
    function Assert-PrivateFolder {
        param([string]$Path)
        $expected = @(Get-ChildItem -LiteralPath (Join-Path $script:shared 'powershell') -Filter '*.ps1' -File | ForEach-Object Name | Sort-Object)
        $actual = @(Get-ChildItem -LiteralPath $Path -File | ForEach-Object Name | Sort-Object)
        $actual | Should -Be (@($expected) + 'SHARED.txt' | Sort-Object)
        foreach ($name in $expected) {
            (Get-FileHash -LiteralPath (Join-Path $Path $name)).Hash | Should -Be (Get-FileHash -LiteralPath (Join-Path $script:shared 'powershell' $name)).Hash -Because $name
        }
        @(Get-ChildItem -LiteralPath $Path -Directory).Count | Should -Be 0
    }
}

Describe 'Copy-SharedCode' {
    It 'copies exactly shared/powershell/*.ps1 and records every shared/ file with its SHA-256' {
        $private = Join-Path $TestDrive 'Private'
        $record = & $script:copy -Destination $private
        Assert-PrivateFolder -Path $private
        $lines = @(Get-Content -LiteralPath $record.FullName | Where-Object { $_ -notmatch '^#' })
        $lines[0] | Should -Match '^shared [0-9a-f]{64}$'
        $files = @($lines | Select-Object -Skip 1)
        $sharedFiles = @(Get-ChildItem -LiteralPath $script:shared -Recurse -File | Where-Object Name -NotMatch '^(\._|\.DS_Store$)')
        $files.Count | Should -Be $sharedFiles.Count
        foreach ($file in $sharedFiles) {
            $path = [System.IO.Path]::GetRelativePath($script:shared, $file.FullName).Replace('\', '/')
            $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            $files | Should -Contain ('{0}  {1}' -f $hash, $path)
        }
    }

    It 'gives the same record for the same shared/, and another one when a file changes' {
        $copyOf = Join-Path $TestDrive 'shared'
        Copy-Item -LiteralPath $script:shared -Destination $copyOf -Recurse
        $first = Get-Content -Raw -LiteralPath (& $script:copy -Destination (Join-Path $TestDrive 'a') -SharedPath $copyOf).FullName
        $again = Get-Content -Raw -LiteralPath (& $script:copy -Destination (Join-Path $TestDrive 'b') -SharedPath $copyOf).FullName
        $again | Should -Be $first
        Add-Content -LiteralPath (Join-Path $copyOf 'js' 'columns.js') -Value '// changed'
        $changed = Get-Content -Raw -LiteralPath (& $script:copy -Destination (Join-Path $TestDrive 'c') -SharedPath $copyOf).FullName
        ($changed -split "`n")[2] | Should -Not -Be ($first -split "`n")[2]
    }
}
