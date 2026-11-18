#Requires -Version 7.4
# Pester tests for build/Build-Module.ps1 with a component module (a JavaScript bundle). They need the
# module's packages (npm ci in its folder) and run webpack, so they are skipped where those are not
# installed (CI's PowerShell job; its build job builds every module). The pivot module's build job runs
# the Describe "Build-Module.ps1 with the pivot module" (ci.yml selects it by that name).

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

Describe 'Build-Module.ps1 with the pivot module' {
    BeforeAll {
        $script:pivot = 'PowerShellUniversal.Component.Pivot'
        $script:pivotCore = Join-Path $script:repo 'modules' $script:pivot 'node_modules' 'pivotkit-core'
    }

    It 'the built module carries pivotkit-core''s view-file and view schemas of the version the bundle uses (#138)' -Skip:(-not (Test-Path -LiteralPath (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..' '..')) 'modules' 'PowerShellUniversal.Component.Pivot' 'node_modules' 'webpack'))) {
        $built = & (Join-Path $script:repo 'build' 'Build-Module.ps1') -Module $script:pivot -OutputPath (Join-Path $TestDrive 'out') -SkipNpmInstall 6>$null
        $lock = Get-Content -LiteralPath (Join-Path $script:repo 'modules' $script:pivot 'package-lock.json') -Raw | ConvertFrom-Json -AsHashtable
        $installed = (Get-Content -LiteralPath (Join-Path $script:pivotCore 'package.json') -Raw | ConvertFrom-Json).version
        $installed | Should -Be $lock.packages['node_modules/pivotkit-core'].version
        foreach ($name in 'view-file-1.json', 'view-file-2.json', 'view-2.json') {
            $file = Join-Path $built.FullName 'schema' $name
            $file | Should -Exist
            (Get-FileHash -LiteralPath $file).Hash | Should -Be (Get-FileHash -LiteralPath (Join-Path $script:pivotCore 'schema' $name)).Hash
        }
    }
}
