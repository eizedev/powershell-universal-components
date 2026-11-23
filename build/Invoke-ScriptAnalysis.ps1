#Requires -Version 7.4

<#
.SYNOPSIS
    Runs PSScriptAnalyzer over the repository's PowerShell, as CI does, and fails on a warning or an
    error.

.DESCRIPTION
    PSScriptAnalyzer 1.25.0 runs the rules for a file in parallel. Two of them,
    PSProvideCommentHelp and PSReservedCmdletChar, read the parameters of Export-ModuleMember through
    a runspace that the other rules use at the same time. Now and then that fails the whole call:
    "Object reference not set to an instance of an object", or "You cannot have more than one dynamic
    module in each dynamic assembly", and the process may hang after it
    (https://github.com/PowerShell/PSScriptAnalyzer/issues/2229, open; this repository's #168 and #39).
    So neither runs in the main pass:

    - PSProvideCommentHelp reports Information only, which this check does not count. It is left out.
      The help of every function is checked by the Pester tests and by reading.
    - PSReservedCmdletChar (a Warning) runs in a pass of its own, with no other rule beside it.

    Findings in node_modules, dist (a module's webpack bundle) and output do not count. When the
    analyzer itself fails, the full exception with its stack trace is written before the script stops,
    so the rule that failed is in the log.

.PARAMETER Path
    The folders to analyze, relative to the repository. Default: modules, shared, build and tests.

.EXAMPLE
    pwsh ./build/Invoke-ScriptAnalysis.ps1

.OUTPUTS
    The findings as a table; throws when there is one.
#>
[CmdletBinding()]
param([string[]]$Path = @('modules', 'shared', 'build', 'tests'))

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$isolated = 'PSReservedCmdletChar'
$skipped = 'PSProvideCommentHelp'
$analyze = @{ Recurse = $true; Severity = 'Warning', 'Error' }

# one call per folder: a call per file once failed the same way and hung the job (#39)
$findings = foreach ($folder in $Path) {
    $full = Join-Path $root $folder
    try {
        Invoke-ScriptAnalyzer -Path $full @analyze -ExcludeRule (@($isolated) + $skipped)
        # the rule's own findings: each pass reports the parse errors again
        Invoke-ScriptAnalyzer -Path $full @analyze -IncludeRule $isolated | Where-Object RuleName -EQ $isolated
    }
    catch {
        Write-Information -InformationAction Continue -MessageData ('PSScriptAnalyzer failed on {0}:{1}{2}' -f $folder, [Environment]::NewLine, $_.Exception.ToString())
        throw
    }
}
$findings = @($findings | Where-Object ScriptPath -NotMatch '[\\/](node_modules|dist|output)[\\/]')
$findings | Format-Table RuleName, ScriptName, Line, Message -AutoSize -Wrap
if ($findings) { throw ('PSScriptAnalyzer: {0} finding(s)' -f $findings.Count) }
