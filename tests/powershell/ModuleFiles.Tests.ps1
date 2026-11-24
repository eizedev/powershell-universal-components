#Requires -Version 7.4
# Pester tests for the files of the split modules (Public/ and Private/, one function per file): one file
# per exported command, and the helpers that read a public command's parameters (#163, #169).
# PSU's [Endpoint] type is a stub.

BeforeDiscovery {
    $script:splitModules = @(
        @{ Name = 'PowerShellUniversal.Component.ECharts' }
        @{ Name = 'PowerShellUniversal.Component.Pivot' }
    )
}

BeforeAll {
    . (Join-Path $PSScriptRoot '..' '..' 'build' 'Add-EndpointType.ps1')
    $script:repo = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
}

Describe 'The files of <Name>' -ForEach $script:splitModules {
    BeforeAll {
        $folder = Join-Path $script:repo 'modules' $Name
        $script:module = Import-Module (Join-Path $folder "$Name.psm1") -Force -PassThru
    }

    It 'has one file in Public/ per exported command and no other' {
        $manifest = Import-PowerShellDataFile (Join-Path $folder "$Name.psd1")
        $files = Get-ChildItem -LiteralPath (Join-Path $folder 'Public') -Filter '*.ps1' -File
        ($files.BaseName | Sort-Object) | Should -Be ($manifest.FunctionsToExport | Sort-Object) -Because 'a file in Public/ is exported only when FunctionsToExport names it'
    }

    It 'a helper reads only parameters the public commands have from -Bound' {
        # the helpers get a public command's $PSBoundParameters as -Bound; a misspelled key would read $null.
        # Checked: literal keys of $Bound['X'], $Bound.ContainsKey('X') and $Bound.Keys -contains 'X', against
        # the parameters of all public commands (not only the caller's); keys in variables are not checked.
        $names = foreach ($command in Get-Command -Module $script:module.Name) { $command.Parameters.Keys }
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $folder 'Private') -Filter '*.ps1' -File) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $keys = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.IndexExpressionAst] -and $n.Target.Extent.Text -eq '$Bound' -and $n.Index -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object { $_.Index.Value })
            $keys += @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Expression.Extent.Text -eq '$Bound' -and $n.Member.Extent.Text -eq 'ContainsKey' -and $n.Arguments[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object { $_.Arguments[0].Value })
            $keys += @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.BinaryExpressionAst] -and $n.Operator -eq 'Icontains' -and $n.Left.Extent.Text -eq '$Bound.Keys' -and $n.Right -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object { $_.Right.Value })
            foreach ($key in $keys) { $names | Should -Contain $key -Because "$($file.Name) reads `$Bound['$key']" }
        }
    }
}
