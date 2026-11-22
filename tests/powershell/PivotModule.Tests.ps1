#Requires -Version 7.4
# Pester tests for the files of PowerShellUniversal.Component.Pivot: one file per exported command, and
# the helpers that read a public command's parameters (#163). PSU's [Endpoint] type is a stub.

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
        # the helpers get a public command's $PSBoundParameters as -Bound; a misspelled key would read $null
        $names = foreach ($command in Get-Command -Module $script:module.Name) { $command.Parameters.Keys }
        foreach ($file in Get-ChildItem -LiteralPath (Join-Path $script:folder 'Private') -Filter '*.ps1' -File) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $keys = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.IndexExpressionAst] -and $n.Target.Extent.Text -eq '$Bound' -and $n.Index -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object { $_.Index.Value })
            $keys += @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and $n.Expression.Extent.Text -eq '$Bound' -and $n.Member.Extent.Text -eq 'ContainsKey' -and $n.Arguments[0] -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object { $_.Arguments[0].Value })
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
