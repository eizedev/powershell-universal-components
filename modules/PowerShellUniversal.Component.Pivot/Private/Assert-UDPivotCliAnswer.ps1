function Assert-UDPivotCliAnswer {
    <#
    .SYNOPSIS
        Reads the answer of pivotkit's command line: its errors as one error (PivotViewHasErrors or
        PivotCliFailed), its warnings to the warning stream, and a report file that must be there.
    .PARAMETER Answer
        The answer of Invoke-UDPivotCli.
    .PARAMETER OutPath
        The report file the command line was asked to write.
    .EXAMPLE
        Assert-UDPivotCliAnswer -Answer $answer -OutPath $outPath
    .OUTPUTS
        None; throws when the command line wrote no report.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param([Parameter(Mandatory)][object]$Answer, [Parameter(Mandatory)][string]$OutPath)
    $findings = @($Answer.findings | Where-Object { $_ -and $_.severity -ne 'info' })
    if (-not $Answer.ok) {
        $lines = @(Get-UDPivotFindingText -Finding @($findings | Where-Object severity -EQ 'error'))
        if ($Answer.error) { $lines += '{0} {1}: {2}' -f $Answer.error.kind, $Answer.error.code, $Answer.error.message }
        $id = if ($Answer.exitCode -eq 1) { 'PivotViewHasErrors' } else { 'PivotCliFailed' }
        throw (New-UDPivotError -Id $id -Category InvalidData -Data @{ Code = if ($Answer.error) { [string]$Answer.error.code } } -Message ('pivotkit''s command line wrote no report (exit {0}):{1}{2}' -f $Answer.exitCode, [Environment]::NewLine, ($lines -join [Environment]::NewLine)))
    }
    foreach ($line in @(Get-UDPivotFindingText -Finding @($findings | Where-Object severity -EQ 'warning'))) { Write-Warning ('pivotkit: {0}' -f $line) }
    if (-not (Test-Path -LiteralPath $OutPath -PathType Leaf)) { throw (New-UDPivotError -Id PivotCliFailed -Message 'pivotkit''s command line said it wrote the report, but the file is not there.') }
}
