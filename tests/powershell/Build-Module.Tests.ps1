#Requires -Version 7.4
# Pester tests for build/Build-Module.ps1 with a component module (a JavaScript bundle). They need the
# module's packages (npm ci in its folder) and run webpack, so they are skipped where those are not
# installed (CI's PowerShell job; its build job builds every module). The pivot module's build job runs
# the Describe "Build-Module.ps1 with the pivot module" (ci.yml selects it by that name); it also holds
# the checks against the pivot module's installed packages.

BeforeDiscovery {
    $script:component = 'PowerShellUniversal.Component.Perspective'
    $repo = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $script:installed = Test-Path -LiteralPath (Join-Path $repo 'modules' $script:component 'node_modules' 'webpack')
    # the split modules: those with a Public/ folder, and whether their packages are installed
    $script:splitModules = @(Get-ChildItem -Path (Join-Path $repo 'modules' '*' 'Public') -Directory | ForEach-Object {
            @{ Name = $_.Parent.Name; HasPackages = Test-Path -LiteralPath (Join-Path $_.Parent.FullName 'node_modules' 'webpack') }
        })
    $pivotPackages = Join-Path $repo 'modules' 'PowerShellUniversal.Component.Pivot' 'node_modules'
    $script:pivotInstalled = Test-Path -LiteralPath (Join-Path $pivotPackages 'webpack')
    $script:pivotkitReactInstalled = Test-Path -LiteralPath (Join-Path $pivotPackages 'pivotkit-react')
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

Describe 'Build-Module.ps1 with a split module: <Name>' -ForEach $splitModules {
    It '<Name>: the built module carries its Public/ and Private/ files (the pivot module also its settings and C# sources) and exports the manifest''s commands (#163, #169)' -Skip:(-not $HasPackages) {
        $built = & (Join-Path $script:repo 'build' 'Build-Module.ps1') -Module $Name -OutputPath (Join-Path $TestDrive 'out') -SkipNpmInstall 6>$null
        $source = Join-Path $script:repo 'modules' $Name
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $source 'Public'), (Join-Path $source 'Private') -Include '*.ps1', '*.cs' -File -Recurse) {
            Join-Path $built.FullName ([System.IO.Path]::GetRelativePath($source, $file.FullName)) | Should -Exist
        }
        Join-Path $built.FullName 'Private' 'SHARED.txt' | Should -Exist
        # the built folder loads on its own and exports the manifest's commands (CI's build job runs the
        # same check on every component module it builds)
        { & (Join-Path $script:repo 'build' 'Test-BuiltModule.ps1') -Path $built.FullName } | Should -Not -Throw
    }
}

Describe 'Build-Module.ps1 with the pivot module' {
    BeforeAll {
        $script:pivot = 'PowerShellUniversal.Component.Pivot'
        $script:pivotCore = Join-Path $script:repo 'modules' $script:pivot 'node_modules' 'pivotkit-core'

        # pivotkit-react's TIP_IDS and NOTICE_IDS, read from its bundle: the package does not export them.
        # 0.8 derives both from TIPS (the notices have kind: "notice"), 0.9 writes them as lists.
        function Get-PivotkitTipId {
            param([string]$Package)
            $file = Get-ChildItem -LiteralPath (Join-Path $Package 'dist') -Recurse -Filter '*.js' |
                Where-Object { (Get-Content -LiteralPath $_.FullName -Raw).Contains('var TIP_IDS = ') } | Select-Object -First 1
            if (-not $file) { throw "pivotkit-react's bundle declares no TIP_IDS: update this reader." }
            $text = Get-Content -LiteralPath $file.FullName -Raw
            $strings = { param($List) @([regex]::Matches($List, '"([A-Za-z0-9-]+)"') | ForEach-Object { $_.Groups[1].Value }) }
            $tips = [regex]::Match($text, 'var TIP_IDS = Object\.freeze\(\[([^\]]*)\]\)')
            $notices = [regex]::Match($text, 'var NOTICE_IDS = Object\.freeze\(\[([^\]]*)\]\)')
            if ($tips.Success -and $notices.Success) {
                return [pscustomobject]@{ Tips = & $strings $tips.Groups[1].Value; Notices = & $strings $notices.Groups[1].Value }
            }
            if (-not $text.Contains('var TIP_IDS = Object.freeze(TIPS.filter((t) => t.kind !== "notice")')) { throw "pivotkit-react's TIP_IDS has a shape this reader does not know: update it." }
            $start = $text.IndexOf('var TIPS = Object.freeze([')
            $block = $text.Substring($start, $text.IndexOf('var TIP_IDS = ') - $start)
            # each entry starts with its id; a notice says so in the next line
            $entries = [regex]::Matches($block, '(?m)^    id: "([A-Za-z0-9-]+)",\r?\n(    kind: "notice")?')
            [pscustomobject]@{
                Tips    = @($entries | Where-Object { -not $_.Groups[2].Success } | ForEach-Object { $_.Groups[1].Value })
                Notices = @($entries | Where-Object { $_.Groups[2].Success } | ForEach-Object { $_.Groups[1].Value })
            }
        }
    }

    It '-Tips takes the tip ids of the installed pivotkit-react, and its help lists them and the notices (#154)' -Skip:(-not $pivotkitReactInstalled) {
        $installed = Get-PivotkitTipId -Package (Join-Path $script:repo 'modules' $script:pivot 'node_modules' 'pivotkit-react')
        $installed.Tips.Count | Should -BeGreaterThan 10 -Because 'the reader found the tips'
        $installed.Notices.Count | Should -BeGreaterThan 0 -Because 'the reader found the notices'
        # read from the source: importing the module needs PSU's types
        $settings = Join-Path $script:repo 'modules' $script:pivot 'Private' 'Settings' 'Fields.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($settings, [ref]$null, [ref]$null)
        $assignment = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$Script:TipIds' }, $false)
        $tipIds = $assignment.Right.Expression.SafeGetValue()
        # the same ids in the same spelling; the order does not matter
        ($tipIds | Sort-Object -CaseSensitive) -join ',' | Should -BeExactly (($installed.Tips | Sort-Object -CaseSensitive) -join ',')
        $command = Join-Path $script:repo 'modules' $script:pivot 'Public' 'New-UDPivotReport.ps1'
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($command, [ref]$null, [ref]$null)
        $function = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'New-UDPivotReport' }, $false)
        $help = $function.GetHelpContent().Parameters['TIPS'] -replace '\s+', ' '
        $listed = [regex]::Match($help, 'the ids of the tips allowed \(([^;]+); the notices (.+?) always show\)')
        $listed.Success | Should -BeTrue -Because "the help of -Tips lists the ids: $help"
        (($listed.Groups[1].Value -split ', ') | Sort-Object -CaseSensitive) -join ',' | Should -BeExactly (($installed.Tips | Sort-Object -CaseSensitive) -join ',')
        (($listed.Groups[2].Value -split ', | and ') | Sort-Object -CaseSensitive) -join ',' | Should -BeExactly (($installed.Notices | Sort-Object -CaseSensitive) -join ',')
    }

    It 'the built module carries pivotkit-core''s view-file and view schemas of the version the bundle uses (#138)' -Skip:(-not $pivotInstalled) {
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
