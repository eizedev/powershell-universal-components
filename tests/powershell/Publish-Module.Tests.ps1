#Requires -Version 7.4
# Tests for build/Publish-Module.ps1 (prepare step) in a throw-away copy of the repository layout.

BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    function Initialize-ReleaseFixture([string]$Changelog, [string]$Version = '1.2.3') {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ('release-{0}' -f [guid]::NewGuid())
        New-Item -ItemType Directory -Path (Join-Path $root 'build'), (Join-Path $root 'modules' 'Demo.Module'), (Join-Path $root 'output' 'Demo.Module' $Version) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $script:repoRoot 'build' 'Publish-Module.ps1') -Destination (Join-Path $root 'build')
        Set-Content -LiteralPath (Join-Path $root 'modules' 'Demo.Module' 'CHANGELOG.md') -Value $Changelog
        Set-Content -LiteralPath (Join-Path $root 'output' 'Demo.Module' $Version 'Demo.Module.psm1') -Value 'function Get-Demo { 1 }'
        @"
@{
    RootModule = 'Demo.Module.psm1'
    ModuleVersion = '$Version'
    GUID = '$([guid]::NewGuid())'
    Author = 'test'
    Description = 'Demo'
    FunctionsToExport = @('Get-Demo')
    PrivateData = @{ PSData = @{ Tags = @('PowerShellUniversal'); LicenseUri = 'https://example.com/license'; ProjectUri = 'https://example.com'; ReleaseNotes = 'https://example.com/changelog' } }
}
"@ | Set-Content -LiteralPath (Join-Path $root 'output' 'Demo.Module' $Version 'Demo.Module.psd1')
        $root
    }
}

Describe 'Publish-Module.ps1 prepare step' {
    It 'writes the CHANGELOG section into the built manifest and packs a zip' {
        $root = Initialize-ReleaseFixture "# Changelog`n`n## [Unreleased]`n`n## [1.2.3] - 2026-11-06`n`n### Added`n`n- It's new.`n`n## [1.0.0]`n`n- Old.`n"
        try {
            $zip = & (Join-Path $root 'build' 'Publish-Module.ps1') -Module Demo.Module -Version 1.2.3 6>$null
            $zip.Name | Should -Be 'Demo.Module-1.2.3.zip'
            $notes = (Import-PowerShellDataFile (Join-Path $root 'output' 'Demo.Module' '1.2.3' 'Demo.Module.psd1')).PrivateData.PSData.ReleaseNotes
            $notes | Should -BeLike "*It's new.*"
            $notes | Should -Not -BeLike '*Old.*'
        }
        finally { Remove-Item -LiteralPath $root -Recurse -Force }
    }
    It 'refuses a version without a CHANGELOG section' {
        $root = Initialize-ReleaseFixture "# Changelog`n`n## [Unreleased]`n`n- Something.`n"
        try { { & (Join-Path $root 'build' 'Publish-Module.ps1') -Module Demo.Module -Version 1.2.3 } | Should -Throw '*no section*1.2.3*' }
        finally { Remove-Item -LiteralPath $root -Recurse -Force }
    }
    It 'refuses a tag that does not match the manifest' {
        $root = Initialize-ReleaseFixture "## [1.2.4]`n`n- x`n" -Version '1.2.3'
        try {
            Rename-Item (Join-Path $root 'output' 'Demo.Module' '1.2.3') '1.2.4'
            { & (Join-Path $root 'build' 'Publish-Module.ps1') -Module Demo.Module -Version 1.2.4 } | Should -Throw '*tag says 1.2.4*manifest says 1.2.3*'
        }
        finally { Remove-Item -LiteralPath $root -Recurse -Force }
    }
}

Describe 'Publish-Module.ps1 release notes' {
    It 'keeps quotes, drops link references and can run twice' {
        $root = Initialize-ReleaseFixture "## [1.2.3]`n`n- It's new, ""quoted"".`n`n[1.2.3]: https://example.com/compare`n"
        try {
            $script = Join-Path $root 'build' 'Publish-Module.ps1'
            & $script -Module Demo.Module -Version 1.2.3 6>$null | Out-Null
            & $script -Module Demo.Module -Version 1.2.3 6>$null | Out-Null
            $notes = (Import-PowerShellDataFile (Join-Path $root 'output' 'Demo.Module' '1.2.3' 'Demo.Module.psd1')).PrivateData.PSData.ReleaseNotes
            $notes | Should -Be "- It's new, ""quoted""."
            Get-Content (Join-Path $root 'output' 'Demo.Module-1.2.3.notes.md') -Raw | Should -BeLike "*It's new*"
        }
        finally { Remove-Item -LiteralPath $root -Recurse -Force }
    }
}
