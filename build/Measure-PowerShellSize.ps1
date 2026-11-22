#Requires -Version 7.4

<#
.SYNOPSIS
    Measures the code lines of every PowerShell file and function below a folder, read with the
    PowerShell parser.

.DESCRIPTION
    The PowerShell part of the growth guards (build/growth.js): it measures, growth.js holds the limits
    and compares with the baseline. A code line is a line with at least one token that is not a
    comment or a line break, so blank lines and comment-based help cost nothing; a here-string counts
    with all its lines. A function's lines are the code lines from its "function" keyword to its
    closing brace, functions nested in it included. A file that does not parse fails the measurement:
    a guard that reads nothing must not report nothing.

.PARAMETER Path
    The folder to measure. Default: the repository. Folders named node_modules, public, output and
    .git, and site/ at the top are skipped: they hold installed packages and build output. The names
    are compared case-sensitively: public/ is a module's bundle, Public/ its exported functions.

.EXAMPLE
    ./build/Measure-PowerShellSize.ps1 | ConvertFrom-Json

.OUTPUTS
    System.String: JSON {"files": [{"path", "lines"}], "functions": [{"path", "name", "lines"}]}, paths
    relative to Path with "/", in path order.
#>
[CmdletBinding()]
[OutputType([string])]
param(
    [string]$Path = (Join-Path $PSScriptRoot '..')
)
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $Path).Path
$skipped = '(^|[\\/])(node_modules|public|output|\.git)[\\/]|^site[\\/]'
$notCode = [System.Management.Automation.Language.TokenKind[]]@('Comment', 'NewLine', 'LineContinuation', 'EndOfInput')

$files = [System.Collections.Generic.List[object]]::new()
$functions = [System.Collections.Generic.List[object]]::new()
$all = Get-ChildItem -LiteralPath $root -Recurse -File -Include '*.ps1', '*.psm1' |
    Where-Object { [System.IO.Path]::GetRelativePath($root, $_.FullName) -cnotmatch $skipped } |
    Sort-Object { [System.IO.Path]::GetRelativePath($root, $_.FullName).Replace('\', '/') }
foreach ($file in $all) {
    $relative = [System.IO.Path]::GetRelativePath($root, $file.FullName).Replace('\', '/')
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    if ($errors) { throw ('{0}:{1}: {2}' -f $relative, $errors[0].Extent.StartLineNumber, $errors[0].Message) }

    $code = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($token in $tokens) {
        if ($token.Kind -in $notCode) { continue }
        for ($line = $token.Extent.StartLineNumber; $line -le $token.Extent.EndLineNumber; $line++) { [void]$code.Add($line) }
    }
    $files.Add([ordered]@{ path = $relative; lines = $code.Count })

    $definitions = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
    foreach ($definition in $definitions) {
        $lines = @($code | Where-Object { $_ -ge $definition.Extent.StartLineNumber -and $_ -le $definition.Extent.EndLineNumber }).Count
        $functions.Add([ordered]@{ path = $relative; name = $definition.Name; lines = $lines })
    }
}

ConvertTo-Json -InputObject ([ordered]@{ files = $files; functions = $functions }) -Depth 3 -Compress
