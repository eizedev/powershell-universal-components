#Requires -Version 7.4
# Pester tests for PowerShellUniversal.Component.Pivot outside PSU: PSU's [Endpoint] type is a stub,
# the asset id is set by hand.

BeforeAll {
    . (Join-Path $PSScriptRoot '..' '..' 'build' 'Add-EndpointType.ps1')
    $script:repo = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
    $script:module = Import-Module (Join-Path $script:repo 'modules' 'PowerShellUniversal.Component.Pivot' 'PowerShellUniversal.Component.Pivot.psm1') -Force -PassThru
    & $script:module { $Script:AssetId = 'asset-under-test' }
}

Describe 'Pivot output: view files, server times and the files of -Engine Node' {
    It 'ends a view file with a newline, as its help says' {
        (ConvertTo-UDPivotViewFile -View '{"rows":["Team"]}' -Name 'Teams') | Should -Match "\}`n\z"
    }

    It 'reads a server time without an offset as UTC, not as the local time of the server' {
        & $script:module {
            $unspecified = [datetime]::new(2026, 1, 1, 10, 0, 0, [System.DateTimeKind]::Unspecified)
            (ConvertTo-UDPivotTime -Value $unspecified).UtcDateTime | Should -Be ([datetime]::new(2026, 1, 1, 10, 0, 0, [System.DateTimeKind]::Utc))
            (ConvertTo-UDPivotTime -Value '2026-01-01T10:00:00').UtcDateTime.Hour | Should -Be 10
            (ConvertTo-UDPivotTime -Value '2026-01-01T10:00:00+02:00').UtcDateTime.Hour | Should -Be 8
        }
    }

    It 'writes the temporary view file of -Engine Node without $schema, so a path in the default cannot stop it' {
        $before = $env:PSU_COMPONENT_PIVOT_SCHEMA_URL
        $work = Join-Path ([System.IO.Path]::GetTempPath()) ('pivotkit-pester-' + [guid]::NewGuid().ToString('n'))
        $null = New-Item -ItemType Directory -Path $work
        try {
            $env:PSU_COMPONENT_PIVOT_SCHEMA_URL = '/assets/pivot/schema/view-file-2.json'
            & $script:module {
                param($work)
                $report = [pscustomobject]@{ ViewFile = [pscustomobject]@{ View = '{"rows":["Team"]}'; Name = 'Teams'; Source = [pscustomobject]@{ id = 'tickets' } }; Title = $null }
                $output = [pscustomobject]@{ Kind = 'csv' }
                $null = Get-UDPivotCliArgument -Work $work -Report $report -Output $output -Bound @{}
            } $work
            $written = Get-Content -LiteralPath (Join-Path $work 'view.pivotkit.json') -Raw | ConvertFrom-Json
            $written.PSObject.Properties.Name | Should -Not -Contain '$schema'
        }
        finally {
            $env:PSU_COMPONENT_PIVOT_SCHEMA_URL = $before
            Remove-Item -LiteralPath $work -Recurse -Force
        }
    }
}

Describe 'Pivot output: texts cut to a limit' {
    It 'never cuts a surrogate pair in half' {
        & $script:module {
            $emoji = [char]::ConvertFromUtf32(0x1F600)
            # 'abc' + emoji: a cut after 4 characters would keep the emoji's first half only
            $cut = Limit-UDPivotText -Text ('abc' + $emoji + 'defgh') -MaxLength 5
            $cut | Should -Be ('abc' + [char]0x2026)
            [char]::IsHighSurrogate($cut[-2]) | Should -BeFalse
            Limit-UDPivotText -Text ('abcd' + $emoji) -MaxLength 6 | Should -Be ('abcd' + $emoji)
        }
    }
}

Describe 'Pivot output: what pivotkit''s command line needs' {
    It 'names the same Node versions in the help of Invoke-UDPivotReport as in its errors' {
        $requirement = & $script:module { $Script:CliNodeRequirement }
        $help = (Get-Help Invoke-UDPivotReport -Full).description.Text -join ' ' -replace '\s+', ' '
        $help | Should -BeLike ('*{0}*' -f $requirement)
    }
}
