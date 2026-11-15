#Requires -Version 7.4
# Pester tests for build/Build-Module.ps1 with a component module (a JavaScript bundle). They need the
# module's packages (npm ci in its folder) and run webpack, so they are skipped where those are not
# installed (CI's PowerShell job; its build job builds every module).

BeforeDiscovery {
    $script:component = 'PowerShellUniversal.Component.Perspective'
    $repo = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $script:installed = Test-Path -LiteralPath (Join-Path $repo 'modules' $script:component 'node_modules' 'webpack')
}

BeforeAll {
    $script:repo = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $script:component = 'PowerShellUniversal.Component.Perspective'
}

Describe 'Build-Module.ps1 with a component module' {
    It 'returns only the built module folder, so $out = ./build/Build-Module.ps1 can be passed on (#94)' -Skip:(-not $installed) {
        $built = & (Join-Path $script:repo 'build' 'Build-Module.ps1') -Module $script:component -OutputPath (Join-Path $TestDrive 'out') -SkipNpmInstall 6>$null
        @($built).Count | Should -Be 1 -Because ('npm and webpack write to the host, not the pipeline: {0}' -f ((@($built) | Where-Object { $_ -isnot [System.IO.DirectoryInfo] } | Select-Object -First 3) -join ' | '))
        $built | Should -BeOfType [System.IO.DirectoryInfo]
        Join-Path $built.FullName "$script:component.psd1" | Should -Exist
    }
}
