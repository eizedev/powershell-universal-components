#Requires -Version 7.4
# Pester tests for build/Measure-PowerShellSize.ps1: the code lines the powershell growth guard
# (build/growth.js) compares with its baseline. tests/js/growth.test.js tests the comparison.

BeforeAll {
    $script:measure = Join-Path $PSScriptRoot '..' '..' 'build' 'Measure-PowerShellSize.ps1'
}

Describe 'Measure-PowerShellSize.ps1' {
    BeforeEach {
        $script:dir = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:dir | Out-Null
    }

    It 'counts code lines: blank lines and comment-based help do not count, a here-string counts with all its lines' {
        $text = @(
            'function Get-Thing {'
            '    <#'
            '    .SYNOPSIS'
            '        Help costs nothing.'
            '    #>'
            '    param([string]$Name)'
            ''
            '    # a comment costs nothing'
            '    $text = @"'
            'line one'
            'line two'
            '"@'
            '    $text'
            '}'
            'Get-Thing'
        ) -join "`n"
        Set-Content -LiteralPath (Join-Path $script:dir 'a.ps1') -Value $text
        $result = & $script:measure -Path $script:dir | ConvertFrom-Json
        # function, param, the four lines of the here-string, $text, closing brace; then the call
        $result.functions | Should -HaveCount 1
        $result.functions[0].name | Should -Be 'Get-Thing'
        $result.functions[0].path | Should -Be 'a.ps1'
        $result.functions[0].lines | Should -Be 8
        $result.files[0].lines | Should -Be 9
    }

    It 'counts a nested function in its own entry and in the function around it' {
        $text = "function Outer {`n    function Inner {`n        1`n    }`n    Inner`n}`n"
        Set-Content -LiteralPath (Join-Path $script:dir 'b.psm1') -Value $text
        $result = & $script:measure -Path $script:dir | ConvertFrom-Json
        ($result.functions | Where-Object name -EQ 'Outer').lines | Should -Be 6
        ($result.functions | Where-Object name -EQ 'Inner').lines | Should -Be 3
    }

    It 'skips installed packages and build output, measures Public/, and names files with "/"' {
        foreach ($folder in 'node_modules/x', 'output/M', 'site', 'docs/site', 'modules/M/Public') {
            $path = Join-Path $script:dir $folder
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $path 'c.ps1') -Value '1'
        }
        $result = & $script:measure -Path $script:dir | ConvertFrom-Json
        # public/ (a module's bundle) is not created here: on macOS and Windows it is the folder Public/
        @($result.files.path) | Should -Be @('docs/site/c.ps1', 'modules/M/Public/c.ps1')
    }

    It 'fails on a file that does not parse instead of measuring nothing' {
        Set-Content -LiteralPath (Join-Path $script:dir 'broken.ps1') -Value 'function Broken {'
        { & $script:measure -Path $script:dir } | Should -Throw '*broken.ps1:1*'
    }
}
